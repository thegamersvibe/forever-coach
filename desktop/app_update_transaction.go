package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"time"
)

type appTransaction struct {
	Schema                                          int
	ID, Target, OldVersion, Version, OldSHA, NewSHA string
	ParentPID                                       int
	ParentStarted                                   string
	Args                                            []string
}

func appRoot(target string) string {
	return filepath.Join(filepath.Dir(target), "."+filepath.Base(target)+".updates")
}
func (t appTransaction) root() string            { return appRoot(t.Target) }
func (t appTransaction) path(name string) string { return filepath.Join(t.root(), t.ID, name) }

type appChild interface {
	Healthy(context.Context, appTransaction) error
	Stop() error
}
type appWorkerOps struct {
	waitParent func(context.Context) error
	start      func(string, []string, string) (appChild, error)
	move       func(string, string) error
}

func appDigest(data []byte) string { sum := sha256.Sum256(data); return hex.EncodeToString(sum[:]) }
func appReadFile(path string, limit int64) ([]byte, error) {
	if err := appPlainDirectory(filepath.Dir(path)); err != nil {
		return nil, err
	}
	before, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !before.Mode().IsRegular() || before.Size() > limit {
		return nil, errors.New("refusing linked, oversized or non-regular app update file")
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	if err = appSingleLink(f); err != nil {
		return nil, err
	}
	info, err := f.Stat()
	if err != nil {
		return nil, err
	}
	if !os.SameFile(before, info) {
		return nil, errors.New("app update file changed while opening")
	}
	data, err := io.ReadAll(io.LimitReader(f, limit+1))
	if err != nil {
		return nil, err
	}
	after, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !os.SameFile(before, after) || int64(len(data)) > limit || after.Size() != before.Size() || !after.ModTime().Equal(before.ModTime()) {
		return nil, errors.New("app update file changed while reading")
	}
	return data, nil
}
func appPlainDirectory(path string) error {
	if err := addonPlainDirectory(path); err != nil {
		return err
	}
	for {
		if err := appRejectReparse(path); err != nil {
			return err
		}
		parent := filepath.Dir(path)
		if parent == path {
			return nil
		}
		path = parent
	}
}
func appWriteNew(path string, data []byte) error {
	if err := appPlainDirectory(filepath.Dir(path)); err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0700)
	if err != nil {
		return err
	}
	_, err = f.Write(data)
	if err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err == nil {
		err = closeErr
	}
	return err
}
func appVerify(path, want string) error {
	data, err := appReadFile(path, appMaxExecutable)
	if err != nil {
		return err
	}
	if appDigest(data) != want {
		return fmt.Errorf("app update file changed: %s", filepath.Base(path))
	}
	return nil
}
func prepareAppTransaction(target, oldVersion, version string, data []byte, args []string, pid int, started string) (appTransaction, error) {
	var t appTransaction
	if !filepath.IsAbs(target) || filepath.Clean(target) != target {
		return t, errors.New("app executable path must be absolute and clean")
	}
	local, e1 := parseAddonVersion(oldVersion)
	remote, e2 := parseAddonVersion(version)
	if e1 != nil || e2 != nil || !remote.newerThan(local) {
		return t, errors.New("app transaction requires a newer stable version")
	}
	args, err := appGUIArgs(args)
	if err != nil {
		return t, err
	}
	old, err := appReadFile(target, appMaxExecutable)
	if err != nil {
		return t, err
	}
	if err = validateAppPE(data); err != nil {
		return t, err
	}
	var nonce [16]byte
	if _, err = rand.Read(nonce[:]); err != nil {
		return t, err
	}
	t = appTransaction{1, hex.EncodeToString(nonce[:]), target, oldVersion, version, appDigest(old), appDigest(data), pid, started, append([]string(nil), args...)}
	if err = appPrivateDirectory(t.root()); err != nil && !os.IsExist(err) {
		return t, err
	}
	if err = appWriteOwned(filepath.Join(t.root(), "active.lock"), []byte(t.ID), nil); err != nil {
		return t, fmt.Errorf("another app update or unfinished recovery holds the adjacent update lock: %w", err)
	}
	ok := false
	defer func() {
		if !ok {
			_ = t.unlock()
		}
	}()
	if err = appPrivateDirectory(filepath.Dir(t.path("transaction.json"))); err != nil {
		return t, err
	}
	for _, f := range []struct {
		name string
		data []byte
	}{{"worker.exe", old}, {"candidate.exe", data}} {
		if err = appWriteNew(t.path(f.name), f.data); err != nil {
			return t, err
		}
	}
	raw, err := json.Marshal(t)
	if err != nil {
		return t, err
	}
	if len(raw) > 16384 {
		return t, errors.New("app transaction record exceeds its size limit")
	}
	if err = appWriteNew(t.path("transaction.json"), raw); err != nil {
		return t, err
	}
	if err = t.verifyInitial(); err != nil {
		return t, err
	}
	ok = true
	return t, nil
}
func (t appTransaction) fingerprint() string { b, _ := json.Marshal(t); return appDigest(b) }
func readAppTransaction(dir string) (appTransaction, error) {
	var t appTransaction
	raw, err := appReadFile(filepath.Join(dir, "transaction.json"), 16384)
	if err != nil {
		return t, err
	}
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	dec.DisallowUnknownFields()
	if err = dec.Decode(&t); err != nil {
		return t, err
	}
	if dec.Decode(new(any)) != io.EOF {
		return t, errors.New("trailing transaction data")
	}
	local, e1 := parseAddonVersion(t.OldVersion)
	remote, e2 := parseAddonVersion(t.Version)
	args, e3 := appGUIArgs(t.Args)
	if t.Schema != 1 || !appHex(t.ID, 32) || !appHex(t.OldSHA, 64) || !appHex(t.NewSHA, 64) || t.OldSHA == t.NewSHA || !filepath.IsAbs(t.Target) || filepath.Clean(t.Target) != t.Target || !strings.EqualFold(filepath.Ext(t.Target), ".exe") || filepath.Dir(t.path("transaction.json")) != dir || e1 != nil || e2 != nil || !remote.newerThan(local) || e3 != nil || !reflect.DeepEqual(args, t.Args) || t.ParentPID <= 0 || t.ParentStarted == "" || len(t.ParentStarted) > 128 {
		return t, errors.New("invalid fixed-layout app transaction")
	}
	return t, nil
}
func (t appTransaction) verifyScope() error {
	now, err := readAppTransaction(filepath.Dir(t.path("transaction.json")))
	if err != nil {
		return err
	}
	if now.fingerprint() != t.fingerprint() {
		return errors.New("app transaction record changed")
	}
	lock, err := appReadFile(filepath.Join(t.root(), "active.lock"), 64)
	if err != nil {
		return err
	}
	if string(lock) != t.ID {
		return errors.New("app transaction no longer owns its lock")
	}
	return nil
}
func (t appTransaction) verifyInitial() error {
	if err := t.verifyScope(); err != nil {
		return err
	}
	for _, f := range []struct{ path, sum string }{{t.Target, t.OldSHA}, {t.path("worker.exe"), t.OldSHA}, {t.path("candidate.exe"), t.NewSHA}} {
		if err := appVerify(f.path, f.sum); err != nil {
			return err
		}
	}
	return nil
}
func (t appTransaction) unlock() error {
	p := filepath.Join(t.root(), "active.lock")
	b, err := appReadFile(p, 64)
	if err != nil {
		return err
	}
	if string(b) != t.ID {
		return errors.New("app update lock ownership changed")
	}
	return os.Remove(p)
}
func (t appTransaction) status(state, message string) error {
	return t.statusWithRename(state, message, os.Rename)
}

func (t appTransaction) statusWithRename(state, message string, rename func(string, string) error) error {
	backup := ""
	if appVerify(t.path("backup.exe"), t.OldSHA) == nil {
		backup = t.path("backup.exe")
	}
	raw, err := json.Marshal(struct {
		ID, State, Message, Backup string
		Time                       time.Time
	}{t.ID, state, message, backup, time.Now().UTC()})
	if err != nil {
		return err
	}
	publish := func() error {
		if state != "committed" && state != "rolled-back" && state != "failed" && state != "recovery" {
			return nil
		}
		last := filepath.Join(t.root(), "last-result.json")
		if _, err = appReadFile(last, 16384); err != nil && !os.IsNotExist(err) {
			return err
		}
		tmp := t.path("last-result.tmp")
		return appWriteOwned(tmp, raw, func() error { return rename(tmp, last) })
	}
	if state == "committed" {
		// Publication failure still requires rollback, so do not retain this
		// transaction's provisional commit marker on that path.
		return appWriteOwned(t.path(state+".json"), raw, publish)
	}
	if err = appWriteNew(t.path(state+".json"), raw); err != nil {
		return err
	}
	return publish()
}
func (t appTransaction) verifySwap(targetSum string, backup, candidate bool) error {
	if err := t.verifyScope(); err != nil {
		return err
	}
	if err := appVerify(t.path("worker.exe"), t.OldSHA); err != nil {
		return err
	}
	if targetSum != "" {
		if err := appVerify(t.Target, targetSum); err != nil {
			return err
		}
	} else if _, err := os.Lstat(t.Target); !os.IsNotExist(err) {
		return errors.New("app target is no longer absent")
	}
	if backup {
		if err := appVerify(t.path("backup.exe"), t.OldSHA); err != nil {
			return err
		}
	}
	if candidate {
		if err := appVerify(t.path("candidate.exe"), t.NewSHA); err != nil {
			return err
		}
	}
	return nil
}
func runAppTransaction(ctx context.Context, t appTransaction, ops appWorkerOps) (err error) {
	if err = t.verifyInitial(); err != nil {
		return err
	}
	defer func() {
		if err == nil {
			return
		}
		for _, state := range []string{"committed", "rolled-back", "recovery", "failed"} {
			if _, e := os.Lstat(t.path(state + ".json")); e == nil {
				return
			}
		}
		_ = t.status("recovery", "App update stopped before it could finish. The executable was not safely replaceable. Recovery files were retained at "+filepath.Dir(t.path("transaction.json"))+"; close other Relax Coach instances and inspect them before retrying.")
	}()
	if err = ctx.Err(); err != nil {
		_ = t.status("failed", "App update canceled before replacement.")
		_ = t.unlock()
		return err
	}
	if err = ops.waitParent(ctx); err != nil {
		_ = t.status("failed", "App update stopped while waiting for the original app to close. No replacement was made.")
		_ = t.unlock()
		return err
	}
	if err = t.verifyInitial(); err != nil {
		return err
	}
	if err = ctx.Err(); err != nil {
		return err
	}
	lockPath := filepath.Join(t.root(), "active.lock")
	lockFile, lockErr := os.Open(lockPath)
	if lockErr != nil {
		return lockErr
	}
	// File.Stat captures the actual handle identity now. Windows Lstat may
	// otherwise defer looking up the file ID until after the path is replaced.
	lockOwner, lockErr := lockFile.Stat()
	lockErr = errors.Join(lockErr, lockFile.Close())
	if lockErr != nil {
		return lockErr
	}
	if err = ops.move(t.Target, t.path("backup.exe")); err != nil {
		verifyUnchanged := func() error {
			if e := t.verifyInitial(); e != nil {
				return e
			}
			now, e := os.Lstat(lockPath)
			if e != nil {
				return e
			}
			if !os.SameFile(lockOwner, now) {
				return errors.New("app update lock ownership changed")
			}
			return nil
		}
		if verifyErr := verifyUnchanged(); verifyErr != nil {
			return errors.Join(err, fmt.Errorf("cannot verify unchanged app after backup failure: %w", verifyErr))
		}
		message := "App update failed before replacement; the original app is unchanged."
		if _, restartErr := ops.start(t.Target, t.Args, ""); restartErr != nil {
			err = errors.Join(err, fmt.Errorf("unchanged old app restart failed: %w", restartErr))
			message += " It could not be relaunched; open it manually."
		}
		if verifyErr := verifyUnchanged(); verifyErr != nil {
			return errors.Join(err, fmt.Errorf("cannot release recovery lock: %w", verifyErr))
		}
		if statusErr := t.status("failed", message); statusErr != nil {
			err = errors.Join(err, fmt.Errorf("cannot record backup failure: %w", statusErr))
		}
		if verifyErr := verifyUnchanged(); verifyErr != nil {
			return errors.Join(err, fmt.Errorf("cannot release recovery lock: %w", verifyErr))
		}
		if unlockErr := appRemoveOwned(lockPath, lockOwner); unlockErr != nil {
			err = errors.Join(err, fmt.Errorf("release recovery lock: %w", unlockErr))
		}
		return err
	}
	installed, committed := false, false
	var child appChild
	defer func() {
		if err == nil || committed {
			return
		}
		cause := err
		if child != nil {
			if stopErr := child.Stop(); stopErr != nil {
				_ = t.status("recovery", "App update needs manual recovery: could not stop its child. Backup retained.")
				err = fmt.Errorf("%w; cannot stop owned child: %v", cause, stopErr)
				return
			}
		}
		if rollbackErr := t.rollback(ops, installed); rollbackErr != nil {
			_ = t.status("recovery", "Automatic rollback refused or failed. An update file changed or is locked. Backup retained; inspect the adjacent update folder.")
			err = fmt.Errorf("%w; rollback requires manual recovery: %v; backup: %s", cause, rollbackErr, t.path("backup.exe"))
			return
		}
		message := "App update rolled back to " + t.OldVersion + " because the update could not be completed."
		if statusErr := t.status("rolled-back", message); statusErr != nil {
			err = errors.Join(err, fmt.Errorf("restored old app, but cannot record recovery: %w", statusErr))
		}
		// Reporting is secondary to relaunching the verified restored executable.
		if _, restartErr := ops.start(t.Target, t.Args, ""); restartErr != nil {
			err = errors.Join(err, fmt.Errorf("old app restored but restart failed: %w", restartErr))
			if statusErr := t.status("recovery", message+" The old executable was restored but could not be relaunched; open it manually."); statusErr != nil {
				err = errors.Join(err, fmt.Errorf("cannot record restart failure: %w", statusErr))
			}
		}
		if unlockErr := t.unlock(); unlockErr != nil {
			err = fmt.Errorf("%w; release recovery lock: %v", err, unlockErr)
		}
	}()
	if err = t.status("backed-up", "Original app backed up."); err != nil {
		return err
	}
	if err = t.verifySwap("", true, true); err != nil {
		return err
	}
	if err = ops.move(t.path("candidate.exe"), t.Target); err != nil {
		return err
	}
	installed = true
	if err = t.verifySwap(t.NewSHA, true, false); err != nil {
		return err
	}
	if err = t.status("installed", "Waiting for native startup health."); err != nil {
		return err
	}
	if err = ctx.Err(); err != nil {
		return err
	}
	child, err = ops.start(t.Target, t.Args, t.ID)
	if err != nil {
		return err
	}
	healthCtx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	if err = child.Healthy(healthCtx, t); err != nil {
		return err
	}
	if err = healthCtx.Err(); err != nil {
		return err
	}
	if err = t.verifySwap(t.NewSHA, true, false); err != nil {
		return err
	}
	if err = t.status("committed", "Relax Coach updated to "+t.Version+"; startup verified."); err != nil {
		return err
	}
	// The healthy child owns its normal lifetime from this point onward.
	child = nil
	committed = true
	return t.unlock()
}
func (t appTransaction) rollback(ops appWorkerOps, installed bool) error {
	sum := ""
	if installed {
		sum = t.NewSHA
	}
	if err := t.verifySwap(sum, true, false); err != nil {
		return err
	}
	if installed {
		if err := ops.move(t.Target, t.path("failed.exe")); err != nil {
			return err
		}
	}
	data, err := appReadFile(t.path("backup.exe"), appMaxExecutable)
	if err != nil {
		return err
	}
	if appDigest(data) != t.OldSHA {
		return errors.New("backup changed")
	}
	if err = appWriteNew(t.path("restore.exe"), data); err != nil {
		return err
	}
	if err = t.verifySwap("", true, false); err != nil {
		return err
	}
	if err = appVerify(t.path("restore.exe"), t.OldSHA); err != nil {
		return err
	}
	if err = ops.move(t.path("restore.exe"), t.Target); err != nil {
		return err
	}
	return t.verifySwap(t.OldSHA, true, false)
}
func appLastResult(target string) string {
	raw, err := appReadFile(filepath.Join(appRoot(target), "last-result.json"), 16384)
	if os.IsNotExist(err) {
		return ""
	}
	if err != nil {
		return "Could not read last app update result; inspect adjacent recovery files."
	}
	var result struct{ Message, Backup string }
	if json.Unmarshal(raw, &result) != nil {
		return "Last app update result is unreadable; inspect adjacent recovery files."
	}
	message := strings.TrimSpace(result.Message)
	if result.Backup != "" {
		message += " Backup: " + result.Backup
	}
	return message
}

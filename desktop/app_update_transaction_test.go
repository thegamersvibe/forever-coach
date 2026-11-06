package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type appFakeChild struct {
	healthy  error
	stopped  bool
	onHealth func()
	stopErr  error
}

func (c *appFakeChild) Healthy(context.Context, appTransaction) error {
	if c.onHealth != nil {
		c.onHealth()
	}
	return c.healthy
}
func (c *appFakeChild) Stop() error { c.stopped = true; return c.stopErr }
func TestAppTransactionEarlyFailureReportsRecovery(t *testing.T) {
	tx, old, _ := appFixture(t)
	ops := appWorkerOps{waitParent: func(context.Context) error { return nil }, move: func(string, string) error { return errors.New("backup sharing denied") }, start: func(path string, args []string, id string) (appChild, error) {
		assertAppBytes(t, path, old)
		return &appFakeChild{}, nil
	}}
	if err := runAppTransaction(context.Background(), tx, ops); err == nil {
		t.Fatal("failed backup succeeded")
	}
	assertAppBytes(t, tx.Target, old)
	if appLastResult(tx.Target) == "" {
		t.Fatal("early worker failure has no discoverable result")
	}
}
func TestAppRollbackMoveFailureRetainsBackupAndUnrelatedFiles(t *testing.T) {
	tx, old, newBytes := appFixture(t)
	child := &appFakeChild{healthy: errors.New("no health")}
	ops := appWorkerOps{waitParent: func(context.Context) error { return nil }, move: func(a, b string) error {
		if b == tx.path("failed.exe") {
			return errors.New("cannot move unhealthy target")
		}
		return appMoveNew(a, b)
	}, start: func(string, []string, string) (appChild, error) { return child, nil }}
	if err := runAppTransaction(context.Background(), tx, ops); err == nil {
		t.Fatal("failed rollback succeeded")
	}
	assertAppBytes(t, tx.path("backup.exe"), old)
	assertAppBytes(t, tx.Target, newBytes)
	if !child.stopped || !strings.Contains(appLastResult(tx.Target), "rollback") {
		t.Fatal("missing retained recovery")
	}
}

func TestAppTransactionRollback(t *testing.T) {
	for _, name := range []string{"health timeout", "start failure", "install failure", "restart failure", "cancel after swap"} {
		t.Run(name, func(t *testing.T) {
			tx, old, _ := appFixture(t)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			child := &appFakeChild{healthy: errors.New("no native startup health")}
			if name == "cancel after swap" {
				child.onHealth = cancel
				child.healthy = context.Canceled
			}
			launched, restored := false, false
			ops := appWorkerOps{waitParent: func(context.Context) error { return nil }, move: func(a, b string) error {
				if name == "install failure" && a == tx.path("candidate.exe") {
					return errors.New("sharing denied")
				}
				return appMoveNew(a, b)
			}, start: func(path string, args []string, id string) (appChild, error) {
				if id != "" {
					launched = true
					if name == "start failure" {
						return nil, errors.New("cannot start candidate")
					}
					return child, nil
				}
				assertAppBytes(t, path, old)
				restored = true
				if name == "restart failure" {
					return nil, errors.New("cannot restart old app")
				}
				return &appFakeChild{}, nil
			}}
			if err := runAppTransaction(ctx, tx, ops); err == nil {
				t.Fatal("failed update reported success")
			}
			assertAppBytes(t, tx.Target, old)
			assertAppBytes(t, tx.path("backup.exe"), old)
			if !restored {
				t.Fatal("old app not relaunched")
			}
			if launched && name != "start failure" && !child.stopped {
				t.Fatal("unhealthy owned child not stopped")
			}
			if got := appLastResult(tx.Target); !strings.Contains(got, "rolled back") {
				t.Fatalf("missing rollback result: %s", got)
			}
		})
	}
}
func TestAppTransactionRefusesInterveningModification(t *testing.T) {
	for _, name := range []string{"target before exit", "candidate before exit", "worker before exit", "target during health", "backup during health", "cannot stop child"} {
		t.Run(name, func(t *testing.T) {
			tx, old, newBytes := appFixture(t)
			changed := []byte("user modification")
			var modified string
			child := &appFakeChild{healthy: errors.New("not healthy")}
			ops := appWorkerOps{move: appMoveNew, waitParent: func(context.Context) error {
				switch name {
				case "target before exit":
					modified = tx.Target
				case "candidate before exit":
					modified = tx.path("candidate.exe")
				case "worker before exit":
					modified = tx.path("worker.exe")
				}
				if modified != "" {
					return os.WriteFile(modified, changed, 0600)
				}
				return nil
			}, start: func(path string, args []string, id string) (appChild, error) {
				if id == "" {
					t.Error("must not restart untrusted executable")
				}
				return child, nil
			}}
			child.onHealth = func() {
				switch name {
				case "target during health":
					modified = tx.Target
				case "backup during health":
					modified = tx.path("backup.exe")
				}
				if modified != "" {
					os.WriteFile(modified, changed, 0600)
				}
			}
			if name == "cannot stop child" {
				child.stopErr = errors.New("cannot terminate owned child")
			}
			if err := runAppTransaction(context.Background(), tx, ops); err == nil {
				t.Fatal("tampered transaction succeeded")
			}
			if modified != "" {
				assertAppBytes(t, modified, changed)
			}
			if strings.Contains(name, "during health") || name == "cannot stop child" {
				if modified != tx.Target {
					assertAppBytes(t, tx.Target, newBytes)
				}
				if modified != tx.path("backup.exe") {
					assertAppBytes(t, tx.path("backup.exe"), old)
				}
				if _, err := os.Stat(filepath.Join(tx.root(), "active.lock")); err != nil {
					t.Fatal("unsafe recovery lock discarded")
				}
			} else if modified != tx.Target {
				assertAppBytes(t, tx.Target, old)
			}
		})
	}
}
func TestAppTransactionCancellationBeforeParentExit(t *testing.T) {
	tx, old, _ := appFixture(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	ops := appWorkerOps{waitParent: func(c context.Context) error { return c.Err() }, move: func(string, string) error { t.Fatal("canceled update moved executable"); return nil }, start: func(string, []string, string) (appChild, error) {
		t.Fatal("canceled update launched app")
		return nil, nil
	}}
	if err := runAppTransaction(ctx, tx, ops); !errors.Is(err, context.Canceled) {
		t.Fatalf("cancellation: %v", err)
	}
	assertAppBytes(t, tx.Target, old)
}
func appFixture(t *testing.T) (appTransaction, []byte, []byte) {
	t.Helper()
	target := filepath.Join(t.TempDir(), "RelaxCoach.exe")
	old := appTestPE()
	old[513] = 1
	newBytes := appTestPE()
	newBytes[513] = 2
	if err := os.WriteFile(target, old, 0700); err != nil {
		t.Fatal(err)
	}
	tx, err := prepareAppTransaction(target, "1.4.1", "1.5.0", newBytes, []string{"-game", filepath.Join(filepath.Dir(target), "Game with spaces")}, os.Getpid(), "parent-identity")
	if err != nil {
		t.Fatal(err)
	}
	return tx, old, newBytes
}
func assertAppBytes(t *testing.T, path string, want []byte) {
	t.Helper()
	got, err := os.ReadFile(path)
	if err != nil || !bytes.Equal(got, want) {
		t.Fatalf("unexpected file bytes %s: %v (sha=%x want=%x)", path, err, sha256.Sum256(got), sha256.Sum256(want))
	}
}
func TestAppTransactionSuccessRetainsBackupAndOnlyOwnedFiles(t *testing.T) {
	tx, old, newBytes := appFixture(t)
	unrelated := filepath.Join(filepath.Dir(tx.Target), "other.txt")
	os.WriteFile(unrelated, []byte("untouched"), 0600)
	child := &appFakeChild{}
	waited := false
	ops := appWorkerOps{waitParent: func(context.Context) error { waited = true; return nil }, start: func(path string, args []string, id string) (appChild, error) {
		if !waited || path != tx.Target || id != tx.ID {
			return nil, fmt.Errorf("wrong startup binding")
		}
		assertAppBytes(t, path, newBytes)
		assertAppBytes(t, tx.path("backup.exe"), old)
		return child, nil
	}, move: appMoveNew}
	if err := runAppTransaction(context.Background(), tx, ops); err != nil {
		t.Fatal(err)
	}
	assertAppBytes(t, tx.Target, newBytes)
	assertAppBytes(t, tx.path("backup.exe"), old)
	assertAppBytes(t, unrelated, []byte("untouched"))
	if child.stopped {
		t.Fatal("healthy child killed")
	}
	if _, err := os.Lstat(filepath.Join(tx.root(), "active.lock")); !os.IsNotExist(err) {
		t.Fatalf("successful update kept active lock: %v", err)
	}
	if got := appLastResult(tx.Target); !bytes.Contains([]byte(got), []byte("updated")) {
		t.Fatalf("missing success result: %s", got)
	}
}

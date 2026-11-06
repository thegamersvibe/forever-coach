package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAppTransactionRefusesChangedRecordAndLinkedFiles(t *testing.T) {
	for _, name := range []string{"record", "lock", "hardlink", "symlink"} {
		t.Run(name, func(t *testing.T) {
			tx, old, _ := appFixture(t)
			switch name {
			case "record":
				raw, _ := json.Marshal(tx)
				os.WriteFile(tx.path("transaction.json"), append(raw, []byte(" {}")...), 0600)
			case "lock":
				os.WriteFile(filepath.Join(tx.root(), "active.lock"), []byte(strings.Repeat("a", 32)), 0600)
			case "hardlink":
				if err := os.Link(tx.path("candidate.exe"), filepath.Join(filepath.Dir(tx.Target), "other.exe")); err != nil {
					t.Fatal(err)
				}
			case "symlink":
				os.Remove(tx.path("candidate.exe"))
				if err := os.Symlink(tx.Target, tx.path("candidate.exe")); err != nil {
					t.Fatal(err)
				}
			}
			ops := appWorkerOps{move: appMoveNew, waitParent: func(context.Context) error { return nil }, start: func(string, []string, string) (appChild, error) {
				t.Error("unsafe transaction launched a process")
				return &appFakeChild{}, nil
			}}
			if err := runAppTransaction(context.Background(), tx, ops); err == nil {
				t.Fatal("unsafe scope accepted")
			}
			assertAppBytes(t, tx.Target, old)
		})
	}
}
func TestAppTransactionNeverWritesOversizeRecord(t *testing.T) {
	target := filepath.Join(t.TempDir(), "RelaxCoach.exe")
	old := appTestPE()
	os.WriteFile(target, old, 0700)
	candidate := appTestPE()
	candidate[513] = 2
	_, err := prepareAppTransaction(target, "1.4.1", "1.5.0", candidate, []string{"-game", strings.Repeat("\x01", 4096)}, os.Getpid(), "p")
	if err == nil {
		t.Fatal("oversize record accepted")
	}
	entries, _ := os.ReadDir(appRoot(target))
	for _, entry := range entries {
		if entry.IsDir() {
			p := filepath.Join(appRoot(target), entry.Name(), "transaction.json")
			if info, e := os.Stat(p); e == nil && info.Size() > 16384 {
				t.Fatal("oversize transaction record written")
			}
		}
	}
}

func TestAppPrepareRejectsConcurrentAndInvalidVersions(t *testing.T) {
	tx, old, data := appFixture(t)
	if _, err := prepareAppTransaction(tx.Target, tx.OldVersion, tx.Version, data, nil, os.Getpid(), "p"); err == nil {
		t.Fatal("concurrent transaction accepted")
	}
	assertAppBytes(t, tx.Target, old)
	for _, version := range []string{"1.4.1", "1.3.9", "1.5.0-beta"} {
		target := filepath.Join(t.TempDir(), "RelaxCoach.exe")
		os.WriteFile(target, old, 0700)
		if _, err := prepareAppTransaction(target, "1.4.1", version, data, nil, 1, "p"); err == nil {
			t.Fatalf("invalid version %s accepted", version)
		}
	}
}
func TestAppInternalModeScopeAndGUIArguments(t *testing.T) {
	id := strings.Repeat("a", 32)
	for _, args := range [][]string{{"-app-update-worker", id, "extra"}, {"-app-update-worker", "../bad"}, {"-app-update-start", id, "-once"}, {"-game", "x", "-app-update-worker", id}, {"-headless"}, {"-game", "x", "-game", "y"}} {
		if _, err := appGUIArgs(args); err == nil {
			t.Fatalf("unsafe GUI args: %q", args)
		}
	}
	args, err := appGUIArgs([]string{"-game=C:\\Game with spaces", "-no-update"})
	if err != nil || len(args) != 3 || args[1] != "C:\\Game with spaces" {
		t.Fatalf("preserved args: %q %v", args, err)
	}
	for _, args := range [][]string{{"-app-update-worker", id}, {"-app-update-start", id, "-game", "C:\\Game"}} {
		mode, got, _, err := parseAppMode(args)
		if err != nil || mode == "" || got != id {
			t.Fatalf("internal mode: %q %v", args, err)
		}
	}
}

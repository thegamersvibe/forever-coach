package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAppBackupMoveFailureRelaunchesAndAllowsRetry(t *testing.T) {
	for _, name := range []string{"relaunch", "restart-failure", "status-failure", "restart-and-status-failure"} {
		t.Run(name, func(t *testing.T) {
			tx, old, candidate := appFixture(t)
			moveErr, restartErr := errors.New("backup sharing denied"), errors.New("old app launch denied")
			statusFails := strings.Contains(name, "status-failure")
			restartFails := strings.HasPrefix(name, "restart-")
			if statusFails {
				if err := os.Mkdir(filepath.Join(tx.root(), "last-result.json"), 0700); err != nil {
					t.Fatal(err)
				}
			}
			restarts := 0
			ops := appWorkerOps{
				waitParent: func(context.Context) error { return nil },
				move:       func(string, string) error { return moveErr },
				start: func(path string, args []string, id string) (appChild, error) {
					if id != "" {
						t.Fatal("candidate launched after backup refusal")
					}
					restarts++
					assertAppBytes(t, path, old)
					if restartFails {
						return nil, restartErr
					}
					return &appFakeChild{}, nil
				},
			}
			err := runAppTransaction(context.Background(), tx, ops)
			if !errors.Is(err, moveErr) || (restartFails && !errors.Is(err, restartErr)) {
				t.Errorf("move/relaunch failure lost: %v", err)
			}
			if statusFails && (err == nil || !strings.Contains(err.Error(), "record")) {
				t.Errorf("publication error lost: %v", err)
			}
			if restarts != 1 {
				t.Errorf("old restarts=%d", restarts)
			}
			assertAppBytes(t, tx.Target, old)
			assertAppBytes(t, tx.path("candidate.exe"), candidate)
			assertAppBytes(t, tx.path("worker.exe"), old)
			if _, err := os.Stat(tx.path("failed.json")); err != nil {
				t.Errorf("missing terminal failure marker: %v", err)
			}
			if !statusFails {
				got := appLastResult(tx.Target)
				if !strings.Contains(got, "unchanged") || (restartFails && !strings.Contains(got, "manually")) {
					t.Errorf("wrong recovery instructions: %s", got)
				}
			}
			next, retryErr := prepareAppTransaction(tx.Target, tx.OldVersion, tx.Version, candidate, nil, os.Getpid(), "test-parent")
			if retryErr != nil {
				t.Errorf("verified unchanged executable cannot retry: %v", retryErr)
			} else if err := next.unlock(); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestAppBackupMoveFailureRetainsUncertainState(t *testing.T) {
	for _, name := range []string{"target", "candidate", "worker", "record", "lock", "replaced-lock", "target-after-restart"} {
		t.Run(name, func(t *testing.T) {
			tx, old, _ := appFixture(t)
			lock := filepath.Join(tx.root(), "active.lock")
			modified := map[string]string{"target": tx.Target, "candidate": tx.path("candidate.exe"), "worker": tx.path("worker.exe"), "record": tx.path("transaction.json"), "lock": lock}[name]
			changed := []byte("intervening user file")
			moveErr := errors.New("backup refused")
			restarts := 0
			ops := appWorkerOps{
				waitParent: func(context.Context) error { return nil },
				move: func(string, string) error {
					if modified != "" {
						if err := os.WriteFile(modified, changed, 0600); err != nil {
							t.Fatal(err)
						}
					}
					if name == "replaced-lock" {
						if err := os.Rename(lock, lock+".saved"); err != nil {
							t.Fatal(err)
						}
						if err := os.WriteFile(lock, []byte(tx.ID), 0600); err != nil {
							t.Fatal(err)
						}
					}
					return moveErr
				},
				start: func(path string, args []string, id string) (appChild, error) {
					restarts++
					if name != "target-after-restart" {
						t.Errorf("uncertain recovery launched a process: %s", name)
					}
					assertAppBytes(t, path, old)
					if err := os.WriteFile(tx.Target, changed, 0600); err != nil {
						t.Fatal(err)
					}
					return &appFakeChild{}, nil
				},
			}
			if err := runAppTransaction(context.Background(), tx, ops); !errors.Is(err, moveErr) {
				t.Errorf("original error lost: %v", err)
			}
			if _, err := os.Lstat(lock); err != nil {
				t.Errorf("uncertain lock discarded: %v", err)
			}
			if modified != "" {
				assertAppBytes(t, modified, changed)
			}
			if name == "replaced-lock" {
				assertAppBytes(t, lock, []byte(tx.ID))
			}
			if name == "target-after-restart" {
				if restarts != 1 {
					t.Errorf("restarts=%d", restarts)
				}
				assertAppBytes(t, tx.Target, changed)
			}
		})
	}
}

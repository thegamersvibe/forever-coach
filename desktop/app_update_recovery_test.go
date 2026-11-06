package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAppHealthyStartupStatusFailureRollsBackWithoutCommitMarker(t *testing.T) {
	tx, old, candidate := appFixture(t)
	if err := os.Mkdir(filepath.Join(tx.root(), "last-result.json"), 0700); err != nil {
		t.Fatal(err)
	}
	child := &appFakeChild{}
	restarts := 0
	ops := appWorkerOps{
		waitParent: func(context.Context) error { return nil },
		move:       appMoveNew,
		start: func(path string, args []string, id string) (appChild, error) {
			if id != "" {
				assertAppBytes(t, path, candidate)
				return child, nil
			}
			restarts++
			assertAppBytes(t, path, old)
			return &appFakeChild{}, nil
		},
	}
	if err := runAppTransaction(context.Background(), tx, ops); err == nil {
		t.Fatal("failed status publication reported success")
	}
	assertAppBytes(t, tx.Target, old)
	assertAppBytes(t, tx.path("backup.exe"), old)
	if !child.stopped || restarts != 1 {
		t.Errorf("healthy child must roll back after publication failure: stopped=%v restarts=%d", child.stopped, restarts)
	}
	if _, err := os.Lstat(tx.path("committed.json")); !os.IsNotExist(err) {
		t.Errorf("restored filesystem must not claim commitment: %v", err)
	}
	if raw, err := os.ReadFile(tx.path("rolled-back.json")); err != nil {
		t.Errorf("missing filesystem rollback record: %v", err)
	} else if strings.Contains(string(raw), "did not complete verified native startup") {
		t.Errorf("healthy startup incorrectly blamed for publication failure: %s", raw)
	}
	if _, err := os.Lstat(filepath.Join(tx.root(), "active.lock")); !os.IsNotExist(err) {
		t.Errorf("verified rollback left active lock: %v", err)
	}
}

func TestAppRollbackRelaunchSurvivesJournalFailures(t *testing.T) {
	tx, old, _ := appFixture(t)
	for _, name := range []string{"rolled-back.json", "recovery.json"} {
		if err := os.Mkdir(tx.path(name), 0700); err != nil {
			t.Fatal(err)
		}
	}
	startupErr, restartErr := errors.New("native startup failed"), errors.New("old app launch failed")
	child := &appFakeChild{healthy: startupErr}
	restarts := 0
	ops := appWorkerOps{
		waitParent: func(context.Context) error { return nil },
		move:       appMoveNew,
		start: func(path string, args []string, id string) (appChild, error) {
			if id != "" {
				return child, nil
			}
			restarts++
			assertAppBytes(t, path, old)
			return nil, restartErr
		},
	}
	err := runAppTransaction(context.Background(), tx, ops)
	if !errors.Is(err, startupErr) || !errors.Is(err, restartErr) ||
		!strings.Contains(err.Error(), "cannot record recovery") || !strings.Contains(err.Error(), "cannot record restart failure") {
		t.Errorf("startup, restart or journal failure was lost: %v", err)
	}
	if !child.stopped || restarts != 1 {
		t.Errorf("recovery skipped: stopped=%v restarts=%d", child.stopped, restarts)
	}
	assertAppBytes(t, tx.Target, old)
	assertAppBytes(t, tx.path("backup.exe"), old)
	if _, err := os.Lstat(filepath.Join(tx.root(), "active.lock")); !os.IsNotExist(err) {
		t.Errorf("verified recovery left lock: %v", err)
	}
	for _, name := range []string{"rolled-back.json", "recovery.json"} {
		if info, err := os.Stat(tx.path(name)); err != nil || !info.IsDir() {
			t.Errorf("foreign journal obstruction removed: %s %v", name, err)
		}
	}
}

func TestAppRollbackRelaunchSurvivesStatusFailure(t *testing.T) {
	for _, restartFails := range []bool{false, true} {
		name := "relaunch-success"
		if restartFails {
			name = "relaunch-failure"
		}
		t.Run(name, func(t *testing.T) {
			tx, old, candidate := appFixture(t)
			// Refuse display-result publication without modifying the trust chain.
			if err := os.Mkdir(filepath.Join(tx.root(), "last-result.json"), 0700); err != nil {
				t.Fatal(err)
			}
			startupErr := errors.New("candidate failed native startup")
			restartErr := errors.New("old app launch refused")
			child := &appFakeChild{healthy: startupErr}
			restarts := 0
			ops := appWorkerOps{
				waitParent: func(context.Context) error { return nil },
				move:       appMoveNew,
				start: func(path string, args []string, id string) (appChild, error) {
					if id != "" {
						assertAppBytes(t, path, candidate)
						return child, nil
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
			if !errors.Is(err, startupErr) || !strings.Contains(err.Error(), "cannot record recovery") {
				t.Errorf("startup/reporting errors lost: %v", err)
			}
			if restartFails && !errors.Is(err, restartErr) {
				t.Errorf("relaunch error lost: %v", err)
			}
			assertAppBytes(t, tx.Target, old)
			assertAppBytes(t, tx.path("backup.exe"), old)
			if !child.stopped || restarts != 1 {
				t.Errorf("recovery skipped: stopped=%v restarts=%d", child.stopped, restarts)
			}
			if _, err := os.Lstat(filepath.Join(tx.root(), "active.lock")); !os.IsNotExist(err) {
				t.Errorf("verified rollback left active lock: %v", err)
			}
			if _, err := os.Stat(tx.path("rolled-back.json")); err != nil {
				t.Errorf("missing filesystem rollback record: %v", err)
			}
		})
	}
}

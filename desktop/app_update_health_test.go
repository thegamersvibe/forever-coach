package main

import (
	"context"
	"errors"
	"os"
	"testing"
)

func TestAppStartupHealthBindsVersionTargetAndTransaction(t *testing.T) {
	for _, name := range []string{"valid", "wrong version", "wrong target", "changed executable", "wrong transaction", "no health"} {
		t.Run(name, func(t *testing.T) {
			tx, _, candidate := appFixture(t)
			os.Remove(tx.Target)
			os.WriteFile(tx.Target, candidate, 0700)
			rt := appRuntimeState{Target: tx.Target, SHA: tx.NewSHA, Version: tx.Version, PID: os.Getpid()}
			if name == "wrong version" {
				rt.Version = "9.0.0"
			}
			if name == "wrong target" {
				rt.Target = tx.path("candidate.exe")
			}
			if name == "changed executable" {
				os.WriteFile(tx.Target, []byte("changed"), 0600)
			}
			if name == "wrong transaction" {
				tx.ID = "ffffffffffffffffffffffffffffffff"
			}
			sent := 0
			s := appStartupState{transaction: tx, runtime: rt, send: func(context.Context, appTransaction) error {
				sent++
				if name == "no health" {
					return errors.New("startup timeout")
				}
				return nil
			}}
			err := s.ack(context.Background())
			if name == "valid" {
				if err != nil || sent != 1 {
					t.Fatalf("real health not sent: %v", err)
				}
				if err = s.ack(context.Background()); err != nil || sent != 1 {
					t.Fatal("duplicate health")
				}
			} else if err == nil {
				t.Fatal("unbound health accepted")
			}
		})
	}
}
func TestAppHealthMessageRejectsWrongOrAbsentOwnedProcess(t *testing.T) {
	tx, _, _ := appFixture(t)
	good := appHealthMessage(tx, 123)
	for _, tc := range []struct {
		msg  string
		pid  int
		live bool
	}{{"", 123, true}, {good, 124, true}, {good, 123, false}, {good + "x", 123, true}} {
		if err := validateAppHealth(tx, tc.msg, tc.pid, tc.live); err == nil {
			t.Fatal("wrong health accepted")
		}
	}
	if err := validateAppHealth(tx, good, 123, true); err != nil {
		t.Fatal(err)
	}
}

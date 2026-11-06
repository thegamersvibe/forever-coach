package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type appStartupState struct {
	transaction appTransaction
	runtime     appRuntimeState
	send        func(context.Context, appTransaction) error
	mu          sync.Mutex
	acked       bool
}

var appStartup *appStartupState

func initAppStartup(id string) error {
	if appRuntime == nil {
		return errors.New("cannot establish update startup identity")
	}
	t, err := readAppTransaction(filepath.Join(appRoot(appRuntime.Target), id))
	if err != nil {
		return err
	}
	if t.ID != id {
		return errors.New("startup transaction mismatch")
	}
	appStartup = &appStartupState{transaction: t, runtime: *appRuntime, send: appPlatformReady}
	return appStartup.validate()
}
func (s *appStartupState) validate() error {
	t, rt := s.transaction, s.runtime
	if rt.Target != t.Target || rt.Version != t.Version || rt.SHA != t.NewSHA || rt.PID != os.Getpid() {
		return errors.New("startup executable/version/process does not match its transaction")
	}
	if err := t.verifyScope(); err != nil {
		return err
	}
	return appVerify(rt.Target, t.NewSHA)
}
func (s *appStartupState) ack(ctx context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.acked {
		return nil
	}
	if err := s.validate(); err != nil {
		return err
	}
	deadline, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	if err := s.send(deadline, s.transaction); err != nil {
		return err
	}
	s.acked = true
	return nil
}
func acknowledgeAppStartup(ctx context.Context) error {
	if appStartup == nil {
		return nil
	}
	return appStartup.ack(ctx)
}
func appHealthMessage(t appTransaction, pid int) string {
	return fmt.Sprintf("healthy %s %s %s %d", t.fingerprint(), t.Version, t.NewSHA, pid)
}
func validateAppHealth(t appTransaction, msg string, pid int, live bool) error {
	if !live || pid <= 0 || msg != appHealthMessage(t, pid) {
		return errors.New("wrong or absent owned native startup acknowledgement")
	}
	return nil
}

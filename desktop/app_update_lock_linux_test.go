//go:build linux

package main

import (
	"errors"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
	"testing"
)

func TestAppPartialLockWriteAllowsRetry(t *testing.T) {
	// A subprocess keeps the real kernel fault isolated from parallel tests.
	if os.Getenv("RELAX_TEST_FSIZE_CHILD") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestAppPartialLockWriteAllowsRetry$", "-test.v")
		cmd.Env = append(os.Environ(), "RELAX_TEST_FSIZE_CHILD=1")
		out, err := cmd.CombinedOutput()
		t.Logf("file-size-limit child:\n%s", out)
		if err != nil {
			t.Fatalf("partial-lock regression: %v", err)
		}
		return
	}
	target := filepath.Join(t.TempDir(), "RelaxCoach.exe")
	old, candidate := appTestPE(), appTestPE()
	old[513], candidate[513] = 1, 2
	if err := os.WriteFile(target, old, 0700); err != nil {
		t.Fatal(err)
	}
	var original syscall.Rlimit
	if err := syscall.Getrlimit(syscall.RLIMIT_FSIZE, &original); err != nil {
		t.Fatal(err)
	}
	short := original
	short.Cur = 16
	signal.Ignore(syscall.SIGXFSZ)
	defer signal.Reset(syscall.SIGXFSZ)
	if err := syscall.Setrlimit(syscall.RLIMIT_FSIZE, &short); err != nil {
		t.Fatal(err)
	}
	defer syscall.Setrlimit(syscall.RLIMIT_FSIZE, &original)
	_, firstErr := prepareAppTransaction(target, "1.4.1", "1.5.0", candidate, nil, os.Getpid(), "test-parent")
	if err := syscall.Setrlimit(syscall.RLIMIT_FSIZE, &original); err != nil {
		t.Fatal(err)
	}
	if !errors.Is(firstErr, syscall.EFBIG) {
		t.Fatalf("real partial write not triggered: %v", firstErr)
	}
	lock, lockErr := os.ReadFile(filepath.Join(appRoot(target), "active.lock"))
	next, retryErr := prepareAppTransaction(target, "1.4.1", "1.5.0", candidate, nil, os.Getpid(), "test-parent")
	if retryErr == nil {
		if err := next.unlock(); err != nil {
			t.Fatal(err)
		}
	}
	assertAppBytes(t, target, old)
	t.Logf("firstErr=%v lockBytes=%d lockReadError=%v retry=%v", firstErr, len(lock), lockErr, retryErr)
	if !os.IsNotExist(lockErr) {
		t.Errorf("incomplete owned lock retained: %v (%d bytes)", lockErr, len(lock))
	}
	if retryErr != nil {
		t.Errorf("cleared I/O fault still blocks retry: %v", retryErr)
	}
}

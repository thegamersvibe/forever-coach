package main

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type appFaultFile struct {
	*os.File
	fault      string
	failure    error
	afterClose func()
}

func (f *appFaultFile) Write(data []byte) (int, error) {
	switch f.fault {
	case "partial-write", "short-write":
		n, err := f.File.Write(data[:16])
		if err != nil || f.fault == "short-write" {
			return n, err
		}
		return n, f.failure
	case "full-write":
		n, err := f.File.Write(data)
		return n, errors.Join(err, f.failure)
	}
	return f.File.Write(data)
}
func (f *appFaultFile) Sync() error {
	if f.fault == "sync" {
		return f.failure
	}
	return f.File.Sync()
}
func (f *appFaultFile) Close() error {
	err := f.File.Close()
	if f.afterClose != nil {
		f.afterClose()
	}
	if f.fault == "close" {
		err = errors.Join(err, f.failure)
	}
	return err
}

func TestAppOwnedLockIOFailuresAllowRetry(t *testing.T) {
	for _, fault := range []string{"partial-write", "short-write", "full-write", "sync", "close"} {
		t.Run(fault, func(t *testing.T) {
			tx, old, candidate := appFixture(t)
			if err := tx.unlock(); err != nil {
				t.Fatal(err)
			}
			lock := filepath.Join(tx.root(), "active.lock")
			failure := errors.New("injected " + fault)
			err := appWriteOwnedWith(lock, []byte(tx.ID), nil, func(path string) (appWritableFile, error) {
				f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0700)
				if err != nil {
					return nil, err
				}
				return &appFaultFile{File: f, fault: fault, failure: failure, afterClose: func() {
					want := []byte(tx.ID)
					if fault == "partial-write" || fault == "short-write" {
						want = want[:16]
					}
					assertAppBytes(t, lock, want)
				}}, nil
			})
			wantErr := failure
			if fault == "short-write" {
				wantErr = io.ErrShortWrite
			}
			if !errors.Is(err, wantErr) {
				t.Fatalf("lost I/O failure: %v", err)
			}
			if _, err := os.Lstat(lock); !os.IsNotExist(err) {
				t.Errorf("incomplete owned lock retained: %v", err)
			}
			next, err := prepareAppTransaction(tx.Target, tx.OldVersion, tx.Version, candidate, tx.Args, os.Getpid(), "test-parent")
			if err != nil {
				t.Fatalf("fault still blocks actual preparation: %v", err)
			}
			if err := next.unlock(); err != nil {
				t.Fatal(err)
			}
			assertAppBytes(t, tx.Target, old)
		})
	}
}

func TestAppOwnedLockFailurePreservesForeignFile(t *testing.T) {
	for _, fault := range []string{"partial-write", "full-write", "sync", "close", "existing"} {
		t.Run(fault, func(t *testing.T) {
			tx, old, candidate := appFixture(t)
			lock := filepath.Join(tx.root(), "active.lock")
			before, err := os.Lstat(lock)
			if err != nil {
				t.Fatal(err)
			}
			if fault != "existing" {
				if err := tx.unlock(); err != nil {
					t.Fatal(err)
				}
			}
			failure := errors.New("injected " + fault)
			err = appWriteOwnedWith(lock, []byte(tx.ID), nil, func(path string) (appWritableFile, error) {
				f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0700)
				if err != nil {
					return nil, err
				}
				return &appFaultFile{File: f, fault: fault, failure: failure, afterClose: func() {
					// Retain the inode while installing a different one with identical
					// contents: a token comparison alone cannot prove creation ownership.
					if err := os.Rename(lock, lock+".saved"); err != nil {
						t.Fatal(err)
					}
					if err := os.WriteFile(lock, []byte(tx.ID), 0600); err != nil {
						t.Fatal(err)
					}
					before, err = os.Lstat(lock)
					if err != nil {
						t.Fatal(err)
					}
				}}, nil
			})
			if err == nil {
				t.Fatal("fault succeeded")
			}
			if fault != "existing" && (!errors.Is(err, failure) || !strings.Contains(err.Error(), "ownership changed")) {
				t.Errorf("lost fault or cleanup uncertainty: %v", err)
			}
			assertAppBytes(t, lock, []byte(tx.ID))
			after, err := os.Lstat(lock)
			if err != nil || !os.SameFile(before, after) {
				t.Fatalf("foreign lock replaced: %v", err)
			}
			if _, err := prepareAppTransaction(tx.Target, tx.OldVersion, tx.Version, candidate, nil, os.Getpid(), "test-parent"); err == nil {
				t.Fatal("foreign lock did not block another transaction")
			}
			assertAppBytes(t, tx.Target, old)
		})
	}
}

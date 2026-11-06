package main

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAppStatusRenameFailureCleansOnlyOwnedTemp(t *testing.T) {
	for _, name := range []string{"owned", "existing-temp", "replaced-temp", "replaced-marker"} {
		t.Run(name, func(t *testing.T) {
			tx, old, _ := appFixture(t)
			tmp := tx.path("last-result.tmp")
			marker := tx.path("committed.json")
			foreign := []byte("another owner's file")
			if name == "existing-temp" {
				if err := os.WriteFile(tmp, foreign, 0600); err != nil {
					t.Fatal(err)
				}
			}
			var renameErr error
			err := tx.statusWithRename("committed", "updated", func(from, to string) error {
				if from != tmp || to != filepath.Join(tx.root(), "last-result.json") {
					t.Fatalf("unexpected publication: %s -> %s", from, to)
				}
				if err := os.Mkdir(to, 0700); err != nil {
					t.Fatal(err)
				}
				renameErr = os.Rename(from, to) // real filesystem refusal
				if renameErr == nil {
					t.Fatal("file publication over directory unexpectedly succeeded")
				}
				if err := os.Remove(to); err != nil {
					t.Fatal(err)
				}
				replace := ""
				if name == "replaced-temp" {
					replace = tmp
				} else if name == "replaced-marker" {
					replace = marker
				}
				if replace != "" {
					if err := os.Rename(replace, replace+".saved"); err != nil {
						t.Fatal(err)
					}
					if err := os.WriteFile(replace, foreign, 0600); err != nil {
						t.Fatal(err)
					}
				}
				return renameErr
			})
			if err == nil || (renameErr != nil && !errors.Is(err, renameErr)) {
				t.Fatalf("publication error lost: %v", err)
			}
			if name == "existing-temp" || name == "replaced-temp" {
				assertAppBytes(t, tmp, foreign)
			} else if _, e := os.Lstat(tmp); !os.IsNotExist(e) {
				t.Errorf("failed publication leaked its owned temporary file: %v", e)
			}
			if name == "replaced-marker" {
				assertAppBytes(t, marker, foreign)
				if !strings.Contains(err.Error(), "ownership changed") {
					t.Errorf("uncertain cleanup not reported: %v", err)
				}
			} else if _, e := os.Lstat(marker); !os.IsNotExist(e) {
				t.Errorf("failed publication left a commit marker: %v", e)
			}
			if name == "owned" {
				if err := tx.status("rolled-back", "rolled back"); err != nil {
					t.Errorf("publication cannot recover after rename refusal: %v", err)
				}
				if got := appLastResult(tx.Target); got != "rolled back" {
					t.Errorf("wrong terminal result: %s", got)
				}
			}
			assertAppBytes(t, tx.Target, old)
		})
	}
}

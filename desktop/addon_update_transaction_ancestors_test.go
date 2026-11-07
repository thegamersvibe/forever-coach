package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestAddonTransactionRollbackAncestors(t *testing.T) {
	payload := guildZip(t, guildEntries(), nil)
	for _, mode := range []string{"live link", "live replacement", "backup replacement", "quarantine replacement"} {
		t.Run(mode, func(t *testing.T) {
			game, outside := guildGame(t), t.TempDir()
			addonPut(t, outside, "sentinel.txt", "external sentinel must be unchanged")
			outsideBefore := addonTreeHashes(t, outside)
			originals := map[string]map[string]string{}
			for _, root := range guildFixtureRoots {
				originals[root] = addonTreeHashes(t, filepath.Join(game, filepath.FromSlash(root)))
			}
			u := guildUpdater(t, payload)
			journey := filepath.Join(game, filepath.FromSlash(guildFixtureRoots[1]))
			content := filepath.Join(game, filepath.FromSlash(guildFixtureRoots[2]))
			backups := map[string]string{}
			changed, movesAfterChange := false, 0
			var replaced string
			u.rename = func(a, b string) error {
				if changed {
					movesAfterChange++
				}
				if b == content && strings.Contains(a, string(filepath.Separator)+"staged"+string(filepath.Separator)) {
					return errors.New("third component install failed")
				}
				if err := os.Rename(a, b); err != nil {
					return err
				}
				if strings.Contains(b, string(filepath.Separator)+"previous"+string(filepath.Separator)) {
					backups[a] = b
				}
				if a == journey && strings.Contains(b, string(filepath.Separator)+"failed"+string(filepath.Separator)) {
					replaced = filepath.Dir(journey)
					if mode == "backup replacement" {
						replaced = filepath.Dir(backups[journey])
					} else if mode == "quarantine replacement" {
						replaced = filepath.Dir(b)
					}
					if err := os.Rename(replaced, replaced+"-displaced"); err != nil {
						t.Fatal(err)
					}
					if mode == "live link" {
						if err := os.Symlink(outside, replaced); err != nil {
							t.Skipf("symlink unavailable: %v", err)
						}
					} else if err := os.Mkdir(replaced, 0700); err != nil {
						t.Fatal(err)
					}
					changed = true
				}
				return nil
			}
			got, err := u.apply(context.Background(), game, guildInfo())
			if !changed {
				t.Fatal("did not reach the completed quarantine boundary")
			}
			if !reflect.DeepEqual(outsideBefore, addonTreeHashes(t, outside)) {
				t.Error("rollback wrote through the replaced live ancestor")
			}
			if movesAfterChange != 0 || err == nil || !strings.Contains(err.Error(), "rollback failed") || got.Version != "" || got.BackupPath != "" {
				t.Errorf("unsafe recovery: moves after replacement=%d result=%+v err=%v", movesAfterChange, got, err)
			}
			lock, readErr := os.ReadFile(filepath.Join(game, "RelaxCoachBackups", ".addon-update.lock"))
			if readErr != nil || err == nil || !strings.Contains(err.Error(), strings.TrimSpace(string(lock))) {
				t.Fatalf("recovery evidence/lock missing: %q %v %v", lock, readErr, err)
			}
			for _, root := range guildFixtureRoots[:2] {
				backup := backups[filepath.Join(game, filepath.FromSlash(root))]
				if mode == "backup replacement" {
					backup = filepath.Join(replaced+"-displaced", filepath.Base(backup))
				}
				if !reflect.DeepEqual(originals[root], addonTreeHashes(t, backup)) {
					t.Errorf("original backup moved or lost: %s", root)
				}
			}
			if !reflect.DeepEqual(originals[guildFixtureRoots[2]], addonTreeHashes(t, content)) {
				t.Error("independently completed Content recovery lost")
			}
		})
	}
}

func TestAddonTransactionAbsentLeafRejectsLinkedAncestors(t *testing.T) {
	root, outside := t.TempDir(), t.TempDir()
	parent := filepath.Join(root, "linked")
	if err := os.Symlink(outside, parent); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	for _, leaf := range []string{"missing", "missing/nested"} {
		if err := addonSameDirectory(filepath.Join(parent, filepath.FromSlash(leaf)), nil); err == nil {
			t.Errorf("absent %s accepted through a linked ancestor", leaf)
		}
	}
}

func TestAddonTransactionRollbackFinalAncestorCheck(t *testing.T) {
	game := guildGame(t)
	u := guildUpdater(t, guildZip(t, guildEntries(), nil))
	coach := filepath.Join(game, filepath.FromSlash(guildFixtureRoots[0]))
	content := filepath.Join(game, filepath.FromSlash(guildFixtureRoots[2]))
	changed := false
	u.rename = func(a, b string) error {
		if b == content && strings.Contains(a, string(filepath.Separator)+"staged"+string(filepath.Separator)) {
			return errors.New("third component install failed")
		}
		if err := os.Rename(a, b); err != nil {
			return err
		}
		if b == coach && strings.Contains(a, string(filepath.Separator)+"previous"+string(filepath.Separator)) {
			parent := filepath.Dir(a)
			if err := os.Rename(parent, parent+"-displaced"); err != nil {
				t.Fatal(err)
			}
			if err := os.Mkdir(parent, 0700); err != nil {
				t.Fatal(err)
			}
			changed = true
		}
		return nil
	}
	got, err := u.apply(context.Background(), game, guildInfo())
	if !changed || err == nil || !strings.Contains(err.Error(), "automatic rollback failed") || got.Version != "" {
		t.Fatalf("unverified recovery advertised as restored: changed=%v result=%+v err=%v", changed, got, err)
	}
	lock, readErr := os.ReadFile(filepath.Join(game, "RelaxCoachBackups", ".addon-update.lock"))
	if readErr != nil || !strings.Contains(err.Error(), strings.TrimSpace(string(lock))) {
		t.Fatalf("missing retained evidence: %q %v", lock, readErr)
	}
}

package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestGuildRollbackRestoresAbsentTreesAndContentParent(t *testing.T) {
	payload := guildZip(t, guildEntries(), nil)
	for failAt := 1; failAt <= 3; failAt++ {
		t.Run(fmt.Sprint(failAt), func(t *testing.T) {
			game := guildGame(t)
			for _, root := range guildFixtureRoots {
				if err := os.RemoveAll(filepath.Join(game, filepath.FromSlash(root))); err != nil {
					t.Fatal(err)
				}
			}
			if err := os.RemoveAll(filepath.Join(game, "Interface", "Content")); err != nil {
				t.Fatal(err)
			}
			before := addonTreeHashes(t, game)
			u := guildUpdater(t, payload)
			calls := 0
			u.rename = func(a, b string) error {
				calls++
				if calls == failAt {
					return errors.New("injected first-install failure")
				}
				return os.Rename(a, b)
			}
			if _, err := u.apply(context.Background(), game, guildInfo()); err == nil || !strings.Contains(err.Error(), "restored") {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(before, addonTreeHashes(t, game)) {
				t.Fatal("first-install rollback left files")
			}
			for _, root := range append([]string{"Interface/Content"}, guildFixtureRoots...) {
				if _, err := os.Stat(filepath.Join(game, filepath.FromSlash(root))); !os.IsNotExist(err) {
					t.Fatalf("absent tree not restored: %s %v", root, err)
				}
			}
		})
	}
}

func TestGuildFinalVerificationRechecksEarlierTrees(t *testing.T) {
	game := guildGame(t)
	before := addonTreeHashes(t, game)
	u := guildUpdater(t, guildZip(t, guildEntries(), nil))
	calls := 0
	u.rename = func(a, b string) error {
		calls++
		if err := os.Rename(a, b); err != nil {
			return err
		}
		if calls == 6 {
			addonPut(t, game, guildFixtureRoots[0]+"/Core.lua", "tampered after its own verification")
		}
		return nil
	}
	if _, err := u.apply(context.Background(), game, guildInfo()); err == nil {
		t.Fatal("accepted corrupt earlier component")
	}
	if !reflect.DeepEqual(before, addonTreeHashes(t, game)) {
		t.Fatal("final verification did not restore all trees")
	}
}

func TestGuildCommitAncestorReplacementRetainsRecovery(t *testing.T) {
	game := guildGame(t)
	outside := t.TempDir()
	addonPut(t, outside, "sentinel.txt", "untouched")
	u := guildUpdater(t, guildZip(t, guildEntries(), nil))
	calls := 0
	u.rename = func(a, b string) error {
		calls++
		if err := os.Rename(a, b); err != nil {
			return err
		}
		if calls == 4 {
			parent := filepath.Join(game, "Interface", "Content")
			if err := os.Rename(parent, parent+"-original"); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(outside, parent); err != nil {
				t.Skipf("symlink unavailable: %v", err)
			}
		}
		return nil
	}
	if _, err := u.apply(context.Background(), game, guildInfo()); err == nil || !strings.Contains(err.Error(), "recovery location") {
		t.Fatal("unsafe commit not held for recovery", err)
	}
	if len(addonTreeHashes(t, outside)) != 1 {
		t.Fatal("wrote through replaced Content ancestor")
	}
	lock, err := os.ReadFile(filepath.Join(game, "RelaxCoachBackups", ".addon-update.lock"))
	if err != nil {
		t.Fatal(err)
	}
	for _, root := range guildFixtureRoots[:2] {
		if _, err := os.Stat(filepath.Join(strings.TrimSpace(string(lock)), "previous", filepath.FromSlash(root))); err != nil {
			t.Fatal("original lost", root, err)
		}
	}
}

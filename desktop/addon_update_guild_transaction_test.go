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

func TestGuildRollsBackEveryMoveAndVerification(t *testing.T) {
	payload := guildZip(t, guildEntries(), nil)
	for _, kind := range []string{"move failure", "cancel after move", "corrupt installed"} {
		for failAt := 1; failAt <= 6; failAt++ {
			if kind == "corrupt installed" && failAt%2 != 0 {
				continue
			}
			t.Run(fmt.Sprintf("%s/%d", kind, failAt), func(t *testing.T) {
				game := guildGame(t)
				before := addonTreeHashes(t, game)
				u := guildUpdater(t, payload)
				ctx, cancel := context.WithCancel(context.Background())
				defer cancel()
				calls := 0
				u.rename = func(from, to string) error {
					calls++
					if calls == failAt && kind == "move failure" {
						return os.ErrPermission
					}
					if err := os.Rename(from, to); err != nil {
						return err
					}
					if calls == failAt {
						if kind == "cancel after move" {
							cancel()
						}
						if kind == "corrupt installed" {
							addonPut(t, to, "corrupt.txt", "injected corruption")
						}
					}
					return nil
				}
				result, err := u.apply(ctx, game, guildInfo())
				if err == nil || result.Version != "" || !strings.Contains(err.Error(), "restored") {
					t.Fatalf("not rolled back: %+v %v", result, err)
				}
				if kind == "cancel after move" && !errors.Is(err, context.Canceled) {
					t.Fatalf("cancellation lost: %v", err)
				}
				if !reflect.DeepEqual(before, addonTreeHashes(t, game)) {
					t.Fatal("mixed release or original bytes lost")
				}
			})
		}
	}
}

func TestGuildPartialAndAbsentTargetsInstall(t *testing.T) {
	for mask := 0; mask < 8; mask++ {
		t.Run(fmt.Sprint(mask), func(t *testing.T) {
			game := guildGame(t)
			for i, root := range guildFixtureRoots {
				if mask&(1<<i) != 0 {
					if err := os.RemoveAll(filepath.Join(game, filepath.FromSlash(root))); err != nil {
						t.Fatal(err)
					}
				}
			}
			if mask&4 != 0 {
				if err := os.RemoveAll(filepath.Join(game, "Interface", "Content")); err != nil {
					t.Fatal(err)
				}
			}
			u := guildUpdater(t, guildZip(t, guildEntries(), nil))
			result, err := u.apply(context.Background(), game, guildInfo())
			if err != nil {
				t.Fatal(err)
			}
			if result.Version != "1.4.2" {
				t.Fatal(result)
			}
			for _, root := range guildFixtureRoots {
				if info, err := os.Stat(filepath.Join(game, filepath.FromSlash(root))); err != nil || !info.IsDir() {
					t.Fatalf("missing tree %s: %v", root, err)
				}
			}
			if mask == 7 && result.BackupPath != "" {
				t.Fatal("invented backup")
			}
		})
	}
}

func TestGuildRollbackFailureRetainsEvidenceAndLock(t *testing.T) {
	payload := guildZip(t, guildEntries(), nil)
	for _, blocked := range []string{"remove installed", "restore original"} {
		t.Run(blocked, func(t *testing.T) {
			game := guildGame(t)
			u := guildUpdater(t, payload)
			originals := []map[string]string{}
			for _, root := range guildFixtureRoots {
				originals = append(originals, addonTreeHashes(t, filepath.Join(game, filepath.FromSlash(root))))
			}
			backups := map[string]string{}
			calls := 0
			u.rename = func(from, to string) error {
				calls++
				if calls == 6 {
					return errors.New("third component install failed")
				}
				if strings.Contains(from, string(filepath.Separator)+"previous"+string(filepath.Separator)) && blocked == "restore original" {
					return os.ErrPermission
				}
				if strings.Contains(to, string(filepath.Separator)+"failed"+string(filepath.Separator)) && blocked == "remove installed" {
					return os.ErrPermission
				}
				if err := os.Rename(from, to); err != nil {
					return err
				}
				for _, root := range guildFixtureRoots {
					if from == filepath.Join(game, filepath.FromSlash(root)) && strings.Contains(to, string(filepath.Separator)+"previous"+string(filepath.Separator)) {
						backups[root] = to
					}
				}
				return nil
			}
			result, err := u.apply(context.Background(), game, guildInfo())
			if err == nil || !strings.Contains(err.Error(), "rollback failed") || result.Version != "" {
				t.Fatalf("false success: %+v %v", result, err)
			}
			b, readErr := os.ReadFile(filepath.Join(game, "RelaxCoachBackups", ".addon-update.lock"))
			if readErr != nil {
				t.Fatal("recovery lock removed", readErr)
			}
			tx := strings.TrimSpace(string(b))
			if tx == "" || !strings.Contains(err.Error(), tx) {
				t.Fatalf("missing recovery location: %v %q", err, b)
			}
			for i, root := range guildFixtureRoots {
				backup := backups[root]
				if _, e := os.Stat(backup); os.IsNotExist(e) {
					backup = filepath.Join(game, filepath.FromSlash(root))
				}
				if !reflect.DeepEqual(originals[i], addonTreeHashes(t, backup)) {
					t.Fatal("original backup lost: " + root)
				}
			}
			// Even a new updater cannot erase evidence or continue a mixed install.
			before := addonTreeHashes(t, game)
			if _, err := guildUpdater(t, payload).apply(context.Background(), game, guildInfo()); err == nil {
				t.Fatal("unfinished transaction admitted another install")
			}
			if !reflect.DeepEqual(before, addonTreeHashes(t, game)) {
				t.Fatal("retry changed recovery evidence")
			}
		})
	}
}

func TestGuildRechecksStageIdentityAfterBackup(t *testing.T) {
	game := guildGame(t)
	before := addonTreeHashes(t, game)
	u := guildUpdater(t, guildZip(t, guildEntries(), nil))
	calls := 0
	installedStale := false
	u.rename = func(from, to string) error {
		calls++
		if calls == 1 {
			if err := os.Rename(from, to); err != nil {
				return err
			}
			tx := strings.Split(to, string(filepath.Separator)+"previous"+string(filepath.Separator))[0]
			stage := filepath.Join(tx, "staged", filepath.FromSlash(guildFixtureRoots[0]))
			if err := os.Rename(stage, stage+"-stale"); err != nil {
				t.Fatal(err)
			}
			addonPut(t, stage, "Core.lua", "replacement source must never be installed")
			return nil
		}
		if strings.Contains(from, string(filepath.Separator)+"staged"+string(filepath.Separator)) {
			installedStale = true
		}
		return os.Rename(from, to)
	}
	_, err := u.apply(context.Background(), game, guildInfo())
	if err == nil || installedStale {
		t.Fatalf("stale source installed: %v", err)
	}
	if !reflect.DeepEqual(before, addonTreeHashes(t, game)) {
		t.Fatal("old runtime not restored after source replacement")
	}
}

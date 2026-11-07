package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestAddonTransactionRetainedBackupBoundaries(t *testing.T) {
	payload := guildZip(t, guildEntries(), nil)
	for replaceAfter := 1; replaceAfter <= 6; replaceAfter++ {
		t.Run(fmt.Sprint(replaceAfter), func(t *testing.T) {
			game := guildGame(t)
			originals := map[string]map[string]string{}
			for _, root := range guildFixtureRoots {
				originals[root] = addonTreeHashes(t, filepath.Join(game, filepath.FromSlash(root)))
			}
			coach := filepath.Join(game, filepath.FromSlash(guildFixtureRoots[0]))
			identity, err := addonDirectoryIdentity(coach)
			if err != nil {
				t.Fatal(err)
			}
			u := guildUpdater(t, payload)
			forward, changed := 0, false
			var backup string
			u.rename = func(a, b string) error {
				isForward := strings.Contains(a, string(filepath.Separator)+"staged"+string(filepath.Separator)) || strings.Contains(b, string(filepath.Separator)+"previous"+string(filepath.Separator))
				if isForward {
					forward++
				}
				if err := os.Rename(a, b); err != nil {
					return err
				}
				if forward == 1 && isForward {
					backup = b
				}
				if isForward && forward == replaceAfter {
					if err := os.Rename(backup, backup+"-displaced"); err != nil {
						t.Fatal(err)
					}
					addonPut(t, backup, "replacement.txt", "not the original backup")
					changed = true
				}
				return nil
			}
			got, err := u.apply(context.Background(), game, guildInfo())
			if !changed || forward != replaceAfter || err == nil || !strings.Contains(err.Error(), "recovery location") || got.Version != "" || got.BackupPath != "" {
				t.Errorf("continued with replaced backup: changed=%v forward=%d result=%+v err=%v", changed, forward, got, err)
			}
			if err := addonSameDirectory(backup+"-displaced", identity); err != nil || !reflect.DeepEqual(originals[guildFixtureRoots[0]], addonTreeHashes(t, backup+"-displaced")) {
				t.Errorf("displaced original lost: %v", err)
			}
			b, e := os.ReadFile(filepath.Join(backup, "replacement.txt"))
			if e != nil || string(b) != "not the original backup" {
				t.Errorf("foreign backup changed: %q %v", b, e)
			}
			for _, root := range guildFixtureRoots[1:] {
				if !reflect.DeepEqual(originals[root], addonTreeHashes(t, filepath.Join(game, filepath.FromSlash(root)))) {
					t.Errorf("independent safe original not restored: %s", root)
				}
			}
			lock, e := os.ReadFile(filepath.Join(game, "RelaxCoachBackups", ".addon-update.lock"))
			if e != nil || err == nil || !strings.Contains(err.Error(), strings.TrimSpace(string(lock))) {
				t.Errorf("recovery evidence/lock lost: %q %v %v", lock, e, err)
			}
		})
	}
}

func TestAddonTransactionRetainedBackupDuringRecovery(t *testing.T) {
	payload := guildZip(t, guildEntries(), nil)
	for _, boundary := range []string{"after Content restore", "after Journey quarantine", "after final Coach restore"} {
		t.Run(boundary, func(t *testing.T) {
			game := guildGame(t)
			coach := filepath.Join(game, filepath.FromSlash(guildFixtureRoots[0]))
			journey := filepath.Join(game, filepath.FromSlash(guildFixtureRoots[1]))
			content := filepath.Join(game, filepath.FromSlash(guildFixtureRoots[2]))
			beforeCoach, beforeJourney, beforeContent := addonTreeHashes(t, coach), addonTreeHashes(t, journey), addonTreeHashes(t, content)
			u := guildUpdater(t, payload)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			var backup string
			changed, invalidTreeMoves := false, 0
			u.rename = func(a, b string) error {
				if b == content && strings.Contains(a, string(filepath.Separator)+"staged"+string(filepath.Separator)) {
					cancel()
					return context.Canceled
				}
				if changed && (a == journey || a == backup) {
					invalidTreeMoves++
				}
				if boundary == "after final Coach restore" && a == backup {
					return os.ErrPermission
				}
				if err := os.Rename(a, b); err != nil {
					return err
				}
				if a == journey && strings.Contains(b, string(filepath.Separator)+"previous"+string(filepath.Separator)) {
					backup = b
				}
				if !changed && ((boundary == "after Content restore" && b == content) ||
					(boundary == "after Journey quarantine" && a == journey && strings.Contains(b, string(filepath.Separator)+"failed"+string(filepath.Separator))) ||
					(boundary == "after final Coach restore" && b == coach && strings.Contains(a, string(filepath.Separator)+"previous"+string(filepath.Separator)))) {
					if err := os.Rename(backup, backup+"-displaced"); err != nil {
						t.Fatal(err)
					}
					addonPut(t, backup, "replacement.txt", "foreign backup")
					changed = true
				}
				return nil
			}
			got, err := u.apply(ctx, game, guildInfo())
			if !changed || invalidTreeMoves != 0 || err == nil || !strings.Contains(err.Error(), "retained original backup changed") || !strings.Contains(err.Error(), "recovery location") || got.Version != "" || got.BackupPath != "" {
				t.Errorf("unverified recovery: changed=%v invalid tree moves=%d result=%+v err=%v", changed, invalidTreeMoves, got, err)
			}
			if !reflect.DeepEqual(beforeCoach, addonTreeHashes(t, coach)) || !reflect.DeepEqual(beforeContent, addonTreeHashes(t, content)) {
				t.Error("cancellation or a bad backup prevented independently safe restorations")
			}
			if !reflect.DeepEqual(beforeJourney, addonTreeHashes(t, backup+"-displaced")) {
				t.Error("displaced original backup lost")
			}
			if b, e := os.ReadFile(filepath.Join(backup, "replacement.txt")); e != nil || string(b) != "foreign backup" {
				t.Errorf("foreign backup modified: %q %v", b, e)
			}
			if _, e := os.Stat(filepath.Join(game, "RelaxCoachBackups", ".addon-update.lock")); e != nil {
				t.Errorf("incomplete recovery released lock: %v", e)
			}
		})
	}
}

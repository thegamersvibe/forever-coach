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

func TestAddonTransactionLockOwnershipBoundaries(t *testing.T) {
	payload := guildZip(t, guildEntries(), nil)
	boundaries := []string{"before commit"}
	for i := 1; i <= 6; i++ {
		boundaries = append(boundaries, fmt.Sprintf("forward %d", i))
	}
	boundaries = append(boundaries, "restore Content", "quarantine Journey", "final restore Coach")
	for _, boundary := range boundaries {
		for _, mode := range []string{"missing", "replacement identical bytes", "rewritten owner bytes"} {
			t.Run(boundary+"/"+mode, func(t *testing.T) {
				game := guildGame(t)
				u := guildUpdater(t, payload)
				lockPath := filepath.Join(game, "RelaxCoachBackups", ".addon-update.lock")
				lost, moves, movesAfterLoss := false, 0, 0
				var transaction string
				var atLoss map[string]string
				loseLock := func() {
					t.Helper()
					b, err := os.ReadFile(lockPath)
					if err != nil {
						t.Fatal(err)
					}
					transaction = strings.TrimSpace(string(b))
					if transaction == "" {
						t.Fatal("missing transaction ownership bytes")
					}
					if mode == "rewritten owner bytes" {
						if err := os.WriteFile(lockPath, []byte("foreign transaction\n"), 0600); err != nil {
							t.Fatal(err)
						}
					} else {
						if err := os.Rename(lockPath, lockPath+".displaced"); err != nil {
							t.Fatal(err)
						}
						if mode == "replacement identical bytes" {
							if err := os.WriteFile(lockPath, b, 0600); err != nil {
								t.Fatal(err)
							}
						}
					}
					lost = true
					atLoss = addonTreeHashes(t, game)
				}
				checks := 0
				u.running = func(context.Context) (bool, error) {
					checks++
					if boundary == "before commit" && checks == 2 {
						loseLock()
					}
					return false, nil
				}
				recovery := boundary == "restore Content" || boundary == "quarantine Journey" || boundary == "final restore Coach"
				u.rename = func(a, b string) error {
					moves++
					if lost {
						movesAfterLoss++
					}
					if recovery && moves == 6 {
						return errors.New("third component install failed")
					}
					if err := os.Rename(a, b); err != nil {
						return err
					}
					if !lost && (boundary == fmt.Sprintf("forward %d", moves) ||
						(boundary == "restore Content" && moves == 7) ||
						(boundary == "quarantine Journey" && moves == 8) ||
						(boundary == "final restore Coach" && moves == 11)) {
						loseLock()
					}
					return nil
				}
				got, err := u.apply(context.Background(), game, guildInfo())
				if !lost {
					t.Fatal("did not reach the selected completed-operation boundary")
				}
				if err == nil || !strings.Contains(err.Error(), "lock") || !strings.Contains(err.Error(), transaction) || got.Version != "" || got.BackupPath != "" || movesAfterLoss != 0 {
					t.Errorf("continued without owned lock: moves after loss=%d result=%+v err=%v", movesAfterLoss, got, err)
				}
				if err != nil && strings.Contains(err.Error(), "backup lock retained") {
					t.Error("reported retention of a lock no longer owned by this transaction")
				}
				if !reflect.DeepEqual(atLoss, addonTreeHashes(t, game)) {
					t.Error("changed live trees, foreign lock or recovery evidence after lock ownership was lost")
				}
				if info, e := os.Stat(transaction); e != nil || !info.IsDir() {
					t.Errorf("recovery evidence removed: %v", e)
				}
			})
		}
	}
}

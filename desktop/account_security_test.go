package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAccountRejectsTraversalAndNonEnumeratedIdentity(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	a, b := accountApp(t, game)
	before, err := os.ReadFile(configPath())
	if err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"", "A#1/..", "../A#1", `..\A#1`, ".", "SavedVariables", "A#1 ", "a#1", "MISSING", game, "C:\\outside", "A#1\x00"} {
		if _, err := b.Call("selectAccount", nativeArgs(id)); err == nil {
			t.Errorf("accepted %q", id)
		}
		assertAccountCharacter(t, a, "Alpha")
	}
	for _, args := range [][]json.RawMessage{nil, nativeArgs(1), nativeArgs(map[string]string{"id": "A#1"}), nativeArgs("A#1", "extra")} {
		if _, err := b.Call("selectAccount", args); err == nil {
			t.Error("accepted invalid native argument shape")
		}
	}
	after, err := os.ReadFile(configPath())
	if err != nil {
		t.Fatal(err)
	}
	if string(after) != string(before) {
		t.Fatal("invalid input mutated configuration")
	}
}

func TestAccountEnumerationRejectsSymlinkEscapeAtEveryLayer(t *testing.T) {
	for _, layer := range []string{"WTF", "Account", "identity", "SavedVariables", "file"} {
		t.Run(layer, func(t *testing.T) {
			accountConfigEnv(t)
			game := filepath.Join(t.TempDir(), "_forever_")
			p := accountSave(t, game, "A#1", "SecretOutside")
			var target string
			switch layer {
			case "WTF":
				target = filepath.Join(game, "WTF")
			case "Account":
				target = filepath.Join(game, "WTF", "Account")
			case "identity":
				target = filepath.Dir(filepath.Dir(p))
			case "SavedVariables":
				target = filepath.Dir(p)
			default:
				target = p
			}
			outside := filepath.Join(t.TempDir(), "outside")
			if err := os.Rename(target, outside); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(outside, target); err != nil {
				t.Fatal(err)
			}
			a, b := accountApp(t, game)
			if v := a.snapshot(); len(v.Accounts) != 0 || len(v.Chars) != 0 {
				t.Fatalf("followed %s symlink outside installation", layer)
			}
			if _, err := b.Call("selectAccount", nativeArgs("A#1")); err == nil {
				t.Fatal("selected symlinked output")
			}
		})
	}
}

func TestAccountSelectedSaveReplacedWithSymlinkRetainsOnlyLastGood(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	p := accountSave(t, game, "A#1", "Alpha")
	a, _ := accountApp(t, game)
	outside := accountSave(t, t.TempDir(), "OTHER", "Outside")
	if err := os.Remove(p); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, p); err != nil {
		t.Fatal(err)
	}
	a.refresh()
	assertAccountCharacter(t, a, "Alpha")
	if a.snapshot().Warning == "" {
		t.Fatal("symlinked replacement did not mark report stale")
	}
}

func TestAccountTamperedRememberedTraversalCannotLoadSave(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	accountSave(t, game, "../ESCAPE", "Escaped")
	if err := os.MkdirAll(filepath.Dir(configPath()), 0700); err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(map[string]any{"accounts": map[string]string{installationKey(game): "../ESCAPE"}})
	if err := os.WriteFile(configPath(), data, 0600); err != nil {
		t.Fatal(err)
	}
	a, _ := accountApp(t, game)
	if v := a.snapshot(); len(v.Chars) != 0 || v.ConfigWarning == "" {
		t.Fatal("tampered preference read a non-account or silently fell back")
	}
}

func TestAccountZeroOutputsAndReservedRootRetainGuidance(t *testing.T) {
	accountConfigEnv(t)
	a, _ := accountApp(t, "")
	if !a.snapshot().NoGame || !strings.Contains(a.snapshot().Error, "Choose or paste") {
		t.Fatal("no-game guidance lost")
	}
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "SavedVariables", "ReservedRoot")
	a.setGame(game)
	a.refresh()
	if v := a.snapshot(); len(v.Accounts) != 0 || len(v.Chars) != 0 || !strings.Contains(v.Error, "Install the addon, log in, then /reload") {
		t.Fatal("reserved root treated as account or zero-save guidance lost")
	}
}

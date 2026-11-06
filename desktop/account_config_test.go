package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAccountRestartAndFolderReturnRememberExactIdentity(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	other := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	accountSave(t, game, "B#2", "Beta")
	accountSave(t, other, "A#1", "OtherAlpha")
	accountSave(t, other, "C#3", "Gamma")
	a, b := accountApp(t, game)
	if _, err := b.Call("selectAccount", nativeArgs("B#2")); err != nil {
		t.Fatal(err)
	}
	restarted, _ := accountApp(t, game)
	assertAccountCharacter(t, restarted, "Beta")
	if _, err := b.Call("setGame", nativeArgs(other)); err != nil {
		t.Fatal(err)
	}
	if len(a.snapshot().Chars) != 0 {
		t.Fatal("account identity leaked to another installation")
	}
	if _, err := b.Call("selectAccount", nativeArgs("C#3")); err != nil {
		t.Fatal(err)
	}
	assertAccountCharacter(t, a, "Gamma")
	if _, err := b.Call("setGame", nativeArgs(filepath.Join(game, "WTF"))); err != nil {
		t.Fatal(err)
	}
	assertAccountCharacter(t, a, "Beta")
	if _, err := b.Call("setGame", nativeArgs(other)); err != nil {
		t.Fatal(err)
	}
	assertAccountCharacter(t, a, "Gamma")
}

func TestAccountMissingRememberedNeverFallsBack(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	selected := accountSave(t, game, "A#1", "Alpha")
	// A sole output auto-selects AND is persisted, before another output appears.
	a, _ := accountApp(t, game)
	assertAccountCharacter(t, a, "Alpha")
	accountSave(t, game, "B#2", "Beta")
	if err := os.Remove(selected); err != nil {
		t.Fatal(err)
	}
	restarted, _ := accountApp(t, game)
	if v := restarted.snapshot(); len(v.Chars) != 0 || v.Account != "A#1" || v.Error == "" {
		t.Fatalf("remembered missing identity fell back: account=%q chars=%d error=%q", v.Account, len(v.Chars), v.Error)
	}
	a.refresh()
	assertAccountCharacter(t, a, "Alpha")
	if a.snapshot().Warning == "" {
		t.Fatal("last-good report is not visibly stale")
	}
}

func TestAccountConfigMigrationPreservesOtherFieldsAndGame(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	accountSave(t, game, "B#2", "Beta")
	if err := os.MkdirAll(filepath.Dir(configPath()), 0700); err != nil {
		t.Fatal(err)
	}
	original := []byte(`{"game":"legacy-folder","unknown":{"nested":[1,true,"keep"]},"accounts":{"unrelated-installation":"DO#NOTCHANGE"}}`)
	if err := os.WriteFile(configPath(), original, 0600); err != nil {
		t.Fatal(err)
	}
	_, b := accountApp(t, game)
	if _, err := b.Call("selectAccount", nativeArgs("B#2")); err != nil {
		t.Fatal(err)
	}
	if savedGame() != "legacy-folder" {
		t.Fatal("account selection changed game preference")
	}
	if _, err := b.Call("setGame", nativeArgs(game)); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(configPath())
	if err != nil {
		t.Fatal(err)
	}
	var config map[string]json.RawMessage
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	if string(config["unknown"]) != `{"nested":[1,true,"keep"]}` {
		t.Fatalf("unknown fields lost: %s", data)
	}
	var accounts map[string]string
	if err := json.Unmarshal(config["accounts"], &accounts); err != nil {
		t.Fatal(err)
	}
	if accounts["unrelated-installation"] != "DO#NOTCHANGE" || len(accounts) != 2 {
		t.Fatalf("other preferences lost: %s", data)
	}
	restarted, _ := accountApp(t, game)
	assertAccountCharacter(t, restarted, "Beta")
	files, err := os.ReadDir(filepath.Dir(configPath()))
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 1 || files[0].Name() != "config.json" {
		t.Fatal("temporary config files leaked")
	}
}

func TestAccountGameOnlyConfigMigratesWithoutLosingPreference(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	if err := os.MkdirAll(filepath.Dir(configPath()), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(configPath(), []byte(`{"Game":"legacy-folder","future":9007199254740993}`), 0600); err != nil {
		t.Fatal(err)
	}
	a, _ := accountApp(t, game)
	assertAccountCharacter(t, a, "Alpha")
	if savedGame() != "legacy-folder" {
		t.Fatal("legacy game preference was replaced on account auto-selection")
	}
	data, err := os.ReadFile(configPath())
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), `"future":9007199254740993`) {
		t.Fatal("unknown numeric field lost precision")
	}
}

func TestAccountCorruptConfigFailsClosedWithoutOverwriting(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	if err := os.MkdirAll(filepath.Dir(configPath()), 0700); err != nil {
		t.Fatal(err)
	}
	broken := `{"game":"keep-me",`
	if err := os.WriteFile(configPath(), []byte(broken), 0600); err != nil {
		t.Fatal(err)
	}
	a, b := accountApp(t, game)
	if v := a.snapshot(); v.Account != "" || len(v.Chars) != 0 || v.ConfigWarning == "" {
		t.Fatal("unreadable preferences silently fell back")
	}
	if _, err := b.Call("selectAccount", nativeArgs("A#1")); err == nil {
		t.Fatal("overwrote corrupt configuration")
	}
	data, err := os.ReadFile(configPath())
	if err != nil || string(data) != broken {
		t.Fatal("corrupt configuration bytes changed")
	}
}

func TestAccountRememberedIdentityNeverCaseFolds(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	p := accountSave(t, game, "A#1", "Alpha")
	accountApp(t, game)
	dir := filepath.Dir(filepath.Dir(p))
	// Use an intermediate name so case-insensitive filesystems also rename it.
	intermediate := filepath.Join(filepath.Dir(dir), "TEMP")
	if err := os.Rename(dir, intermediate); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(intermediate, filepath.Join(filepath.Dir(dir), "a#1")); err != nil {
		t.Fatal(err)
	}
	a, _ := accountApp(t, game)
	if v := a.snapshot(); v.Account != "A#1" || len(v.Chars) != 0 || v.Error == "" {
		t.Fatal("remembered identity was case-folded into a different account")
	}
}

func TestAccountConfigWriteFailureIsNotReportedAsRemembered(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	accountSave(t, game, "B#2", "Beta")
	a, b := accountApp(t, game)
	// Deterministic even when tests run as root: parent path is a file.
	if err := os.WriteFile(filepath.Dir(configPath()), []byte("blocked"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := b.Call("selectAccount", nativeArgs("B#2")); err == nil || !strings.Contains(strings.ToLower(err.Error()), "remember") {
		t.Fatalf("write failure falsely reported success: %v", err)
	}
	if a.snapshot().Account != "" || len(a.snapshot().Chars) != 0 {
		t.Fatal("failed selection partially committed")
	}
	if _, err := b.Call("setGame", nativeArgs(game)); err == nil {
		t.Fatal("folder persistence failure ignored")
	}
}

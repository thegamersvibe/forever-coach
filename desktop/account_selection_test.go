package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func accountConfigEnv(t *testing.T) {
	t.Helper()
	d := t.TempDir()
	t.Setenv("APPDATA", d)
	t.Setenv("XDG_CONFIG_HOME", d)
}

func accountSave(t *testing.T, game, account, name string) string {
	t.Helper()
	p := filepath.Join(game, "WTF", "Account", account, "SavedVariables", "ForeverCoach.lua")
	if err := os.MkdirAll(filepath.Dir(p), 0755); err != nil {
		t.Fatal(err)
	}
	data := `ForeverCoachDB = { ["schema"] = 1, ["chars"] = { ["Same-Realm"] = { ["snapshot"] = { ["name"] = "` + name + `", ["realm"] = "Realm", ["class"] = "WARRIOR", ["level"] = 20 }, ["updated"] = 1700000000 } } }`
	if err := os.WriteFile(p, []byte(data), 0644); err != nil {
		t.Fatal(err)
	}
	return p
}

func accountApp(t *testing.T, game string) (*App, *nativeBridge) {
	t.Helper()
	a := &App{}
	a.setGame(game)
	a.refresh()
	b := newNativeBridge(a, true, nativeServices{})
	t.Cleanup(b.Close)
	return a, b
}

func assertAccountCharacter(t *testing.T, a *App, name string) {
	t.Helper()
	v := a.snapshot()
	if len(v.Chars) != 1 || v.Chars[0].Name != name || v.Chars[0].Key != "Same-Realm" {
		t.Fatalf("expected only %q at shared character key, got %+v", name, v.Chars)
	}
}

func TestAccountMultipleOutputsRequireChoice(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	accountSave(t, game, "B#2", "Beta")
	a, b := accountApp(t, game)
	if v := a.snapshot(); len(v.Chars) != 0 || !strings.Contains(strings.ToLower(v.Error), "account") {
		t.Fatalf("multiple outputs require explicit account choice, not newest report: chars=%+v error=%q", v.Chars, v.Error)
	}
	if _, err := b.Call("selectAccount", nativeArgs("A#1")); err != nil {
		t.Fatal(err)
	}
	assertAccountCharacter(t, a, "Alpha")
	if _, err := b.Call("selectAccount", nativeArgs("B#2")); err != nil {
		t.Fatal(err)
	}
	assertAccountCharacter(t, a, "Beta")
}

func TestAccountAmbiguousLaunchDoesNotAutoChooseWhenOtherDisappears(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	other := accountSave(t, game, "B#2", "Beta")
	a, _ := accountApp(t, game)
	if err := os.Remove(other); err != nil {
		t.Fatal(err)
	}
	a.refresh()
	if v := a.snapshot(); v.Account != "" || len(v.Chars) != 0 {
		t.Fatal("an initially ambiguous installation still requires explicit choice")
	}
}

func TestAccountRefreshNeverFollowsNewerOtherSave(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	first := accountSave(t, game, "A#1", "Alpha")
	a, _ := accountApp(t, game)
	assertAccountCharacter(t, a, "Alpha")
	other := accountSave(t, game, "B#2", "Beta")
	future := time.Now().Add(time.Hour)
	if err := os.Chtimes(other, future, future); err != nil {
		t.Fatal(err)
	}
	a.refresh()
	assertAccountCharacter(t, a, "Alpha")
	if a.snapshot().SVPath != first {
		t.Fatal("refresh changed selected source")
	}
}

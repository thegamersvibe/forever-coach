package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func accountProjection(t *testing.T, b *nativeBridge) map[string]any {
	t.Helper()
	value, err := b.Call("reportRefresh", nil)
	if err != nil {
		t.Fatal(err)
	}
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	var result map[string]any
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	return result
}

func TestAccountNativeProjectionTracksMalformedMissingAndSwitch(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	p := accountSave(t, game, "A#1", "Alpha")
	a, b := accountApp(t, game)
	initial := accountProjection(t, b)
	if initial["Account"] != "A#1" || initial["SVPath"] != p || initial["SaveTime"] == nil || initial["SaveTime"] == "" {
		t.Fatalf("native report omits selected identity/source/time: account=%v path=%v time=%v", initial["Account"], initial["SVPath"], initial["SaveTime"])
	}
	if err := os.WriteFile(p, []byte("ForeverCoachDB = {"), 0644); err != nil {
		t.Fatal(err)
	}
	stale := accountProjection(t, b)
	assertAccountCharacter(t, a, "Alpha")
	if stale["Stale"] != true || stale["SaveTime"] != initial["SaveTime"] || !strings.Contains(stale["HTML"].(string), "previous one") {
		t.Fatal("malformed selected save lost visible last-good provenance")
	}
	if err := os.Remove(p); err != nil {
		t.Fatal(err)
	}
	missing := accountProjection(t, b)
	assertAccountCharacter(t, a, "Alpha")
	if missing["Account"] != "A#1" || missing["Stale"] != true {
		t.Fatal("missing save changed selected identity or hid staleness")
	}
	bad := accountSave(t, game, "B#2", "Beta")
	if err := os.WriteFile(bad, []byte("ForeverCoachDB = {"), 0644); err != nil {
		t.Fatal(err)
	}
	value, err := b.Call("selectAccount", nativeArgs("B#2"))
	if err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(value)
	var badReport map[string]any
	if err := json.Unmarshal(data, &badReport); err != nil {
		t.Fatal(err)
	}
	if badReport["SaveTime"] == "" {
		t.Fatal("malformed selected output still needs its file modification time")
	}
	if v := a.snapshot(); v.Account != "B#2" || len(v.Chars) != 0 || v.Error == "" || v.Warning != "" || strings.Contains(string(data), "Alpha") {
		t.Fatal("switch to malformed account leaked the old report")
	}
	accountSave(t, game, "B#2", "Beta")
	a.refresh()
	assertAccountCharacter(t, a, "Beta")
	if a.snapshot().Warning != "" {
		t.Fatal("successful read did not clear staleness")
	}
}

func TestAccountUnreadableOutputRetainsOnlySameAccount(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	p := accountSave(t, game, "A#1", "Alpha")
	a, b := accountApp(t, game)
	initial := accountProjection(t, b)
	accountSave(t, game, "B#2", "Beta")
	if err := os.Remove(p); err != nil {
		t.Fatal(err)
	}
	// A directory at the save path is deterministically unreadable as a file,
	// including in root-run test environments where chmod cannot deny reads.
	if err := os.Mkdir(p, 0755); err != nil {
		t.Fatal(err)
	}
	result := accountProjection(t, b)
	assertAccountCharacter(t, a, "Alpha")
	if result["Stale"] != true || result["SaveTime"] != initial["SaveTime"] || result["Account"] != "A#1" {
		t.Fatal("unreadable selected save changed account or last-good provenance")
	}
	if _, err := b.Call("selectAccount", nativeArgs("B#2")); err != nil {
		t.Fatal(err)
	}
	assertAccountCharacter(t, a, "Beta")
}

func TestAccountSelectionAndRefreshNeverWriteSavedVariables(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	p := accountSave(t, game, "A#1", "Alpha")
	q := accountSave(t, game, "B#2", "Beta")
	original := map[string]string{}
	for _, path := range []string{p, q} {
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		original[path] = string(data)
	}
	_, b := accountApp(t, game)
	for _, id := range []string{"A#1", "B#2", "A#1"} {
		if _, err := b.Call("selectAccount", nativeArgs(id)); err != nil {
			t.Fatal(err)
		}
		accountProjection(t, b)
	}
	for path, want := range original {
		data, err := os.ReadFile(path)
		if err != nil || string(data) != want {
			t.Fatalf("changed save %s: %v", path, err)
		}
	}
}

func TestAccountNativeProjectionExposesPersistenceWarning(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	if err := os.WriteFile(filepath.Dir(configPath()), []byte("blocked"), 0600); err != nil {
		t.Fatal(err)
	}
	_, b := accountApp(t, game)
	p := accountProjection(t, b)
	if warning, ok := p["ConfigWarning"].(string); !ok || warning == "" {
		t.Fatal("native UI cannot surface configuration failure")
	}
}

//go:build windows

package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"golang.org/x/sys/windows"
)

// These fixtures live entirely under t.TempDir. They never access the installed game.
func TestAccountWindowsJunctionsRejectedAtEveryDirectory(t *testing.T) {
	for _, layer := range []string{"WTF", "Account", "identity", "SavedVariables"} {
		t.Run(layer, func(t *testing.T) {
			accountConfigEnv(t)
			game := filepath.Join(t.TempDir(), "_forever_")
			p := accountSave(t, game, "A#1", "Alpha")
			a, _ := accountApp(t, game)
			assertAccountCharacter(t, a, "Alpha")
			target := filepath.Dir(p)
			switch layer {
			case "WTF":
				target = filepath.Join(game, "WTF")
			case "Account":
				target = filepath.Join(game, "WTF", "Account")
			case "identity":
				target = filepath.Dir(filepath.Dir(p))
			}
			parked := target + ".parked"
			if err := os.Rename(target, parked); err != nil {
				t.Fatal(err)
			}
			cmd := filepath.Join(os.Getenv("SystemRoot"), "System32", "cmd.exe")
			if output, err := exec.Command(cmd, "/d", "/c", "mklink", "/J", target, parked).CombinedOutput(); err != nil {
				t.Fatalf("junction fixture failed (not skipped): %v: %s", err, output)
			}
			t.Cleanup(func() {
				if err := os.Remove(target); err != nil {
					t.Errorf("junction cleanup: %v", err)
				}
			})
			a.refresh()
			assertAccountCharacter(t, a, "Alpha")
			v := a.snapshot()
			if v.Account != "A#1" || v.Warning == "" {
				t.Fatalf("junction replacement did not retain selected stale identity: %+v", v)
			}
			for _, choice := range v.Accounts {
				if choice.ID == "A#1" {
					t.Fatal("junction output was enumerated as local account")
				}
			}
			if _, _, err := a.readSelectedSave(); err == nil {
				t.Fatal("read selected output through directory junction")
			}
		})
	}
}

func TestAccountWindowsConfigSharingDenialKeepsOldSelection(t *testing.T) {
	accountConfigEnv(t)
	game := filepath.Join(t.TempDir(), "_forever_")
	accountSave(t, game, "A#1", "Alpha")
	accountSave(t, game, "B#2", "Beta")
	a, b := accountApp(t, game)
	if _, err := b.Call("selectAccount", nativeArgs("A#1")); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(configPath())
	if err != nil {
		t.Fatal(err)
	}
	path, err := windows.UTF16PtrFromString(configPath())
	if err != nil {
		t.Fatal(err)
	}
	// Read sharing permits inspection but denies deletion/replacement of this file.
	handle, err := windows.CreateFile(path, windows.GENERIC_READ, windows.FILE_SHARE_READ, nil, windows.OPEN_EXISTING, windows.FILE_ATTRIBUTE_NORMAL, 0)
	if err != nil {
		t.Fatal(err)
	}
	defer windows.CloseHandle(handle)
	if _, err := b.Call("selectAccount", nativeArgs("B#2")); err == nil || !strings.Contains(err.Error(), "remember") {
		t.Fatalf("sharing-denied replace falsely succeeded: %v", err)
	}
	assertAccountCharacter(t, a, "Alpha")
	if a.snapshot().Account != "A#1" {
		t.Fatal("failed replace changed selected identity")
	}
	after, err := os.ReadFile(configPath())
	if err != nil || !bytes.Equal(before, after) {
		t.Fatalf("failed replace changed config bytes: %v", err)
	}
	files, err := os.ReadDir(filepath.Dir(configPath()))
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 1 || files[0].Name() != "config.json" {
		t.Fatal("failed replace leaked temporary config")
	}
}

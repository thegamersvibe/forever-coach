package main

import (
	"reflect"
	"strings"
	"testing"
)

func TestAppModePreservesGamePathsContainingReservedSubstring(t *testing.T) {
	paths := []string{`C:\Games\app-update-archive\_forever_`, "/games/relax-app-update-test/_forever_", "app-update-start", `C:\Game with spaces\app-update-worker`}
	for _, path := range paths {
		for _, flag := range []string{"-game", "--game"} {
			for _, args := range [][]string{{flag, path, "-no-update"}, {flag + "=" + path, "-once"}} {
				mode, id, got, err := parseAppMode(args)
				if err != nil || mode != "" || id != "" || !reflect.DeepEqual(got, args) {
					t.Errorf("ordinary arguments changed: %q -> %q %q %q %v", args, mode, id, got, err)
				}
			}
			id := strings.Repeat("a", 32)
			args := []string{"-app-update-start", id, flag + "=" + path, "-no-update"}
			mode, gotID, got, err := parseAppMode(args)
			want := []string{"-game", path, "-no-update"}
			if err != nil || mode != "start" || gotID != id || !reflect.DeepEqual(got, want) {
				t.Errorf("restart arguments changed: %q -> %q %q %q %v", args, mode, gotID, got, err)
			}
		}
	}
}

func TestAppModeRejectsMisplacedNestedAndUnsafeFlags(t *testing.T) {
	id := strings.Repeat("a", 32)
	for _, args := range [][]string{
		{"-game", "x", "-app-update-worker", id},
		{"-game=x", "--app-update-worker=" + id},
		{"-no-update", "-app-update-start=" + id},
		{"--app-update-start", id},
		{"-app-update-worker", id, "-game=x"},
		{"-app-update-start", id, "-game=x", "-app-update-start", id},
		{"-app-update-start", id, "--app-update-worker=" + id},
		{"-app-update-start", id, "-once"},
		{"-app-update-start", id, "-game", "x", "-game=y"},
		{"-app-update-start", id, "-game", "bad\x00path"},
		{"-app-update-start", "../bad", "-game=x"},
	} {
		if _, _, _, err := parseAppMode(args); err == nil {
			t.Errorf("unsafe internal invocation accepted: %q", args)
		}
	}
}

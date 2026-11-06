package main

import (
	"errors"
	"strings"
)

func appHex(s string, n int) bool {
	if len(s) != n {
		return false
	}
	for _, c := range s {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

// Only GUI arguments understood by the installed application survive a restart.
// No arbitrary executable, command, internal mode, or diagnostic server argument.
func appGUIArgs(args []string) ([]string, error) {
	var out []string
	game, disabled := false, false
	bad := errors.New("unsupported or duplicate GUI restart argument")
	if len(args) > 6 {
		return nil, bad
	}
	for i := 0; i < len(args); i++ {
		a := args[i]
		if strings.HasPrefix(a, "--") {
			a = a[1:]
		}
		switch {
		case a == "-game" || strings.HasPrefix(a, "-game="):
			if game {
				return nil, bad
			}
			game = true
			var value string
			if a == "-game" {
				i++
				if i >= len(args) {
					return nil, bad
				}
				value = args[i]
			} else {
				value = strings.TrimPrefix(a, "-game=")
			}
			if len(value) > 4096 || strings.IndexByte(value, 0) >= 0 {
				return nil, bad
			}
			out = append(out, "-game", value)
		case a == "-no-update" || a == "-no-update=true" || a == "-no-update=false":
			if disabled {
				return nil, bad
			}
			disabled = true
			out = append(out, a)
		default:
			return nil, bad
		}
	}
	return out, nil
}
func parseAppMode(args []string) (string, string, []string, error) {
	bad := errors.New("invalid internal app update invocation")
	if len(args) > 0 && (args[0] == "-app-update-worker" || args[0] == "-app-update-start") {
		if len(args) < 2 || !appHex(args[1], 32) {
			return "", "", nil, bad
		}
		mode := strings.TrimPrefix(args[0], "-app-update-")
		if mode == "worker" && len(args) != 2 {
			return "", "", nil, bad
		}
		gui, err := appGUIArgs(args[2:])
		if err != nil {
			return "", "", nil, err
		}
		return mode, args[1], gui, nil
	}
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if arg == "-game" || arg == "--game" {
			// The next token is a path, not an internal mode. The ordinary
			// flag parser still owns missing-value and unsupported-flag errors.
			i++
			continue
		}
		name, _, _ := strings.Cut(arg, "=")
		switch name {
		case "-app-update-worker", "--app-update-worker", "-app-update-start", "--app-update-start":
			return "", "", nil, bad
		}
	}
	return "", "", args, nil
}

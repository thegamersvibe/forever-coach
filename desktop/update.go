package main

// Rules auto-update from the upstream public GitHub repo only when the schema matches.
// App release checks are deliberately disabled: upstream binaries are not this private Relax bundle.
// Never advertise or install upstream addon/helper code.

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

var client = &http.Client{Timeout: 10 * time.Second}

func get(url string) ([]byte, error) {
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("User-Agent", "RelaxCoach/"+Version)
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("%s: HTTP %d", url, resp.StatusCode)
	}
	return io.ReadAll(io.LimitReader(resp.Body, 2<<20))
}

var rulesVersionRe = regexp.MustCompile(`\["version"\]\s*=\s*"([^"]+)"`)

func installedRulesVersion(addonDir string) string {
	b, err := os.ReadFile(filepath.Join(addonDir, "Rules.lua"))
	if err != nil {
		return ""
	}
	if m := rulesVersionRe.FindSubmatch(b); m != nil {
		return string(m[1])
	}
	return ""
}

func semverLess(a, b string) bool {
	pa, pb := strings.Split(strings.TrimPrefix(a, "v"), "."), strings.Split(strings.TrimPrefix(b, "v"), ".")
	for i := 0; i < 3; i++ {
		var x, y int
		if i < len(pa) {
			x, _ = strconv.Atoi(pa[i])
		}
		if i < len(pb) {
			y, _ = strconv.Atoi(pb[i])
		}
		if x != y {
			return x < y
		}
	}
	return false
}

// Returns a human note for the report (empty when nothing to say).
func (a *App) updateRules() string {
	if _, err := os.Stat(a.addonDir); err != nil {
		return "Addon not found at " + a.addonDir
	}
	b, err := get("https://raw.githubusercontent.com/" + Repo + "/main/rules/rules.json")
	if err != nil {
		return ""
	}
	var rules map[string]any
	if err := json.Unmarshal(b, &rules); err != nil {
		return "Rules update skipped: bad JSON"
	}
	if N(rules["schema"]) != RulesSchema {
		return "Rules update skipped: incompatible schema for Relax Coach; update the private bundle"
	}
	remote, local := S(rules["version"]), installedRulesVersion(a.addonDir)
	if local != "" && !semverLess(local, remote) {
		return ""
	}
	dst := filepath.Join(a.addonDir, "Rules.lua")
	tmp := dst + ".new"
	if err := os.WriteFile(tmp, []byte(RulesToLua(rules)), 0o644); err != nil {
		return "Rules update failed: " + err.Error() + " (game folder may need write access)"
	}
	if err := os.Rename(tmp, dst); err != nil {
		os.Remove(tmp)
		return "Rules update failed: " + err.Error()
	}
	return fmt.Sprintf("Rules updated %s → %s. /reload in game to apply.", orNone(local), remote)
}

func orNone(s string) string {
	if s == "" {
		return "none"
	}
	return s
}

// RulesToLua mirrors scripts/build_rules_lua.py (keys sorted here; order doesn't matter to Lua).
func RulesToLua(v any) string {
	return "-- Generated from rules.json. Do not edit; edit rules.json.\nForeverCoach_Rules = " + toLua(v, 0) + "\n"
}

func toLua(v any, ind int) string {
	p := strings.Repeat("  ", ind)
	switch t := v.(type) {
	case nil:
		return "nil"
	case bool:
		return strconv.FormatBool(t)
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case string:
		return luaString(t)
	case []any:
		var sb strings.Builder
		sb.WriteString("{\n")
		for _, x := range t {
			sb.WriteString(p + "  " + toLua(x, ind+1) + ",\n")
		}
		return sb.String() + p + "}"
	case map[string]any:
		keys := make([]string, 0, len(t))
		for k := range t {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		var sb strings.Builder
		sb.WriteString("{\n")
		for _, k := range keys {
			sb.WriteString(p + "  [" + luaString(k) + "] = " + toLua(t[k], ind+1) + ",\n")
		}
		return sb.String() + p + "}"
	}
	return "nil"
}

// Lua 5.1 string literal: UTF-8 bytes kept as-is (Lua has no \u escapes); only quotes, backslash and controls escaped.
func luaString(s string) string {
	var sb strings.Builder
	sb.WriteByte('"')
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case c == '\\':
			sb.WriteString(`\\`)
		case c == '"':
			sb.WriteString(`\"`)
		case c == '\n':
			sb.WriteString(`\n`)
		case c == '\r':
			sb.WriteString(`\r`)
		case c < 32 || c == 127:
			fmt.Fprintf(&sb, "\\%03d", c)
		default:
			sb.WriteByte(c)
		}
	}
	sb.WriteByte('"')
	return sb.String()
}

func jsonUnmarshal(b []byte, v any) error { return json.Unmarshal(b, v) }

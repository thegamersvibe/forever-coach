package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

// Where the chosen game folder is remembered: %AppData%\ForeverCoach\config.json
func configPath() string {
	d, err := os.UserConfigDir()
	if err != nil {
		return ""
	}
	return filepath.Join(d, "ForeverCoach", "config.json")
}

func savedGame() string {
	p := configPath()
	if p == "" {
		return ""
	}
	b, err := os.ReadFile(p)
	if err != nil {
		return ""
	}
	var c struct{ Game string }
	if json.Unmarshal(b, &c) != nil {
		return ""
	}
	return c.Game
}

func saveGame(game string) {
	p := configPath()
	if p == "" {
		return
	}
	os.MkdirAll(filepath.Dir(p), 0o755)
	b, _ := json.Marshal(map[string]string{"game": game})
	os.WriteFile(p, b, 0o644)
}

// isForeverDir: a WoW client folder (has Interface or WTF or a Wow*.exe).
func isGameDir(p string) bool {
	if st, err := os.Stat(p); err != nil || !st.IsDir() {
		return false
	}
	for _, sub := range []string{"WTF", "Interface"} {
		if st, err := os.Stat(filepath.Join(p, sub)); err == nil && st.IsDir() {
			return true
		}
	}
	m, _ := filepath.Glob(filepath.Join(p, "Wow*.exe"))
	return len(m) > 0
}

// NormalizeGame accepts what a user pastes: the _forever_ folder, the World of Warcraft folder,
// a subfolder (Interface\AddOns, WTF...) or the path of Wow.exe, with or without quotes.
func NormalizeGame(in string) string {
	p := strings.TrimSpace(strings.Trim(strings.TrimSpace(in), `"'`))
	if p == "" {
		return ""
	}
	if strings.HasSuffix(strings.ToLower(p), ".exe") {
		p = filepath.Dir(p)
	}
	p = filepath.Clean(p)
	for i := 0; i < 4 && p != "" && p != filepath.Dir(p); i++ {
		if strings.Contains(strings.ToLower(filepath.Base(p)), "forever") && isGameDir(p) {
			return p
		}
		if f := foreverIn(p); f != "" {
			return f
		}
		p = filepath.Dir(p)
	}
	return ""
}

// foreverIn: the Forever client folder inside a World of Warcraft install folder.
func foreverIn(wow string) string {
	ents, err := os.ReadDir(wow)
	if err != nil {
		return ""
	}
	for _, e := range ents {
		if e.IsDir() && strings.Contains(strings.ToLower(e.Name()), "forever") && isGameDir(filepath.Join(wow, e.Name())) {
			return filepath.Join(wow, e.Name())
		}
	}
	return ""
}

// Candidate World of Warcraft folders: Blizzard's registry entries, then common paths on every drive.
func wowCandidates() []string {
	var out []string
	if runtime.GOOS == "windows" {
		for _, key := range []string{
			`HKLM\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft`,
			`HKLM\SOFTWARE\Blizzard Entertainment\World of Warcraft`,
			`HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft`,
		} {
			b, err := exec.Command("reg", "query", key).Output()
			if err != nil {
				continue
			}
			re := regexp.MustCompile(`(?i)(InstallPath|InstallLocation)\s+REG_SZ\s+(.+)`)
			for _, m := range re.FindAllStringSubmatch(string(b), -1) {
				p := filepath.Clean(strings.TrimSpace(m[2]))
				out = append(out, p, filepath.Dir(p)) // InstallPath often points at _retail_
			}
		}
		for c := 'C'; c <= 'Z'; c++ {
			d := string(c) + `:\`
			if _, err := os.Stat(d); err != nil {
				continue
			}
			for _, sub := range []string{`Program Files (x86)\World of Warcraft`, `Program Files\World of Warcraft`,
				`World of Warcraft`, `Games\World of Warcraft`, `Blizzard\World of Warcraft`, `Battle.net\World of Warcraft`,
				`Program Files (x86)\Battle.net\World of Warcraft`, `Games\Blizzard\World of Warcraft`} {
				out = append(out, filepath.Join(d, sub))
			}
		}
	}
	return out
}

func findGame() string {
	if g := os.Getenv("FOREVER_COACH_GAME"); g != "" {
		if n := NormalizeGame(g); n != "" {
			return n
		}
	}
	if g := savedGame(); g != "" && isGameDir(g) {
		return g
	}
	if exe, err := os.Executable(); err == nil { // helper placed inside the game folder
		if n := NormalizeGame(filepath.Dir(exe)); n != "" {
			return n
		}
	}
	for _, w := range wowCandidates() {
		if f := foreverIn(w); f != "" {
			return f
		}
		if strings.Contains(strings.ToLower(filepath.Base(w)), "forever") && isGameDir(w) {
			return w
		}
	}
	return ""
}

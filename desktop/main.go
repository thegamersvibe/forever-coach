// Forever Coach desktop helper.
// Reads ONLY ForeverCoach's own SavedVariables (written by the game on /reload or logout),
// serves a report on http://127.0.0.1:<port>, and keeps the addon's rules up to date
// from the public GitHub repo. No memory reading, no input automation, no login.
package main

import (
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"html/template"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"sync"
	"time"
)

const Version = "1.0.2"
const Repo = "thegamersvibe/forever-coach"
const RulesSchema = 1

//go:embed report.html logo.png
var assets embed.FS

type Finding struct {
	Impact float64
	Area   string
	Text   string
	Fix    string
}

type CharView struct {
	Key, Name, Realm, Class, Race, Faction, Spec, SpecSource string
	Level                                                    int
	XPPct, RestedPct                                         int
	XPPerHour                                                int
	Updated                                                  time.Time
	Findings                                                 []Finding
	Sessions                                                 int
	Deaths                                                   []string
	Money                                                    string
	ClassColor                                               string
	Slots                                                    []SlotView
	Talents                                                  []TalentView
	Procs                                                    []ProcView
	Stats                                                    StatView
	Counts                                                   map[string]int
	GearScorePct                                             int
	GearNote                                                 string
}

type SlotView struct {
	Name, Item, BestName, BestHow, BestSource string
	Equipped, Weapon                          bool
	GapPct                                    int
}

type TalentView struct {
	Name  string
	Spent int
	Pct   int
}

type ProcView struct {
	Name          string
	Used, Windows int
	UsedPct       int
}

type StatView struct {
	PlayMin, CombatPct, DowntimePct, DeadPct, Deaths, Kills int
	DeathsPerHour                                           string
	XPToLevel, MinToLevel                                   int
	HasData                                                 bool
}

type View struct {
	Chars                       []CharView
	SVPath, Error, RulesVersion string
	UpdateNote, AppVersion      string
	Loaded                      time.Time
}

type App struct {
	game, svPath, addonDir string
	mu                     sync.Mutex
	view                   View
	modTime                time.Time
}

func main() {
	gameFlag := flag.String("game", "", `game folder, default C:\Program Files (x86)\World of Warcraft\_forever_`)
	port := flag.Int("port", 47321, "local port")
	noOpen := flag.Bool("no-open", false, "don't open the browser")
	noUpdate := flag.Bool("no-update", false, "skip the rules update check")
	once := flag.Bool("once", false, "print the report to the console and exit")
	flag.Parse()

	game := *gameFlag
	if game == "" {
		game = findGame()
	}
	app := &App{game: game, addonDir: filepath.Join(game, "Interface", "AddOns", "ForeverCoach")}
	app.view.AppVersion = Version
	app.svPath = findSavedVariables(game)
	app.reload()

	checkUpdates := func() {
		note := app.updateRules()
		app.mu.Lock()
		app.view.UpdateNote = note
		app.view.Loaded = time.Now() // page auto-refreshes to show the note
		app.mu.Unlock()
	}
	if *once {
		if !*noUpdate {
			checkUpdates()
		}
		printConsole(app.snapshot())
		return
	}
	go app.watch()
	if !*noUpdate {
		go checkUpdates() // never delay the page on a slow network
	}

	ln, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", *port))
	if err != nil {
		log.Fatalf("port %d busy (already running?): %v", *port, err)
	}
	url := fmt.Sprintf("http://127.0.0.1:%d/", *port)
	tpl := template.Must(template.New("report.html").Funcs(funcs).ParseFS(assets, "report.html"))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if err := tpl.Execute(w, app.snapshot()); err != nil {
			http.Error(w, err.Error(), 500)
		}
	})
	http.HandleFunc("/logo.png", func(w http.ResponseWriter, r *http.Request) {
		b, _ := assets.ReadFile("logo.png")
		w.Header().Set("Content-Type", "image/png")
		w.Header().Set("Cache-Control", "max-age=86400")
		w.Write(b)
	})
	http.HandleFunc("/stamp", func(w http.ResponseWriter, r *http.Request) {
		v := app.snapshot()
		fmt.Fprint(w, v.Loaded.UnixNano())
	})
	fmt.Println("Forever Coach", Version, "-", url)
	fmt.Println("Game:", game)
	fmt.Println("Reading:", app.svPath)
	if !*noOpen {
		openBrowser(url)
	}
	log.Fatal(http.Serve(ln, nil))
}

func (a *App) snapshot() View {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.view
}

func (a *App) watch() {
	for {
		time.Sleep(2 * time.Second)
		if a.svPath == "" {
			a.svPath = findSavedVariables(a.game)
		}
		if st, err := os.Stat(a.svPath); err == nil && st.ModTime() != a.modTime {
			a.reload()
		}
	}
}

func (a *App) reload() {
	v := View{SVPath: a.svPath, AppVersion: Version, Loaded: time.Now()}
	a.mu.Lock()
	v.UpdateNote = a.view.UpdateNote
	a.mu.Unlock()
	v.RulesVersion = installedRulesVersion(a.addonDir)
	if a.svPath == "" {
		v.Error = "No ForeverCoach data yet. Install the addon, log in, then /reload."
	} else if st, err := os.Stat(a.svPath); err != nil {
		v.Error = "Can't read " + a.svPath + ": " + err.Error()
	} else {
		a.modTime = st.ModTime()
		b, err := os.ReadFile(a.svPath)
		if err == nil {
			var vars map[string]any
			vars, err = ParseSavedVariables(string(b))
			if err == nil {
				v.Chars = buildChars(M(vars["ForeverCoachDB"]))
			}
		}
		if err != nil {
			v.Error = err.Error()
		}
	}
	a.mu.Lock()
	a.view = v
	a.mu.Unlock()
}

func buildChars(db map[string]any) []CharView {
	var out []CharView
	for key, raw := range M(db["chars"]) {
		c := M(raw)
		s := M(c["snapshot"])
		g := M(c["gear"])
		cv := CharView{
			Key: key, Name: S(s["name"]), Realm: S(s["realm"]), Class: S(s["class"]), Race: S(s["race"]),
			Faction: S(s["faction"]), Level: int(N(s["level"])), Spec: S(g["spec"]), SpecSource: S(g["specSource"]),
			XPPerHour: int(N(c["xpPerHour"])), Updated: time.Unix(int64(N(c["updated"])), 0),
		}
		if mx := N(s["xpMax"]); mx > 0 {
			cv.XPPct = int(N(s["xp"]) / mx * 100)
			cv.RestedPct = int(N(s["rested"]) / mx * 100)
		}
		for _, f := range List(c["findings"]) {
			fm := M(f)
			cv.Findings = append(cv.Findings, Finding{N(fm["impact"]), S(fm["area"]), S(fm["text"]), S(fm["fix"])})
		}
		sess := List(c["sessions"])
		cv.Sessions = len(sess)
		for i := len(sess) - 1; i >= 0 && len(cv.Deaths) < 8; i-- {
			for _, d := range List(M(sess[i])["deaths"]) {
				dm := M(d)
				line := fmt.Sprintf("Level %s, %s", S(dm["level"]), S(dm["zone"]))
				if by := S(dm["by"]); by != "" {
					line += " — " + by
					if sp := S(dm["spell"]); sp != "" && sp != "melee" {
						line += " (" + sp + ")"
					}
				}
				cv.Deaths = append(cv.Deaths, line)
			}
		}
		enrich(&cv, c, s, g, sess)
		out = append(out, cv)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Updated.After(out[j].Updated) })
	return out
}

func findGame() string {
	for _, p := range []string{
		`C:\Program Files (x86)\World of Warcraft\_forever_`,
		`C:\Program Files\World of Warcraft\_forever_`,
		`D:\World of Warcraft\_forever_`,
		`D:\Program Files (x86)\World of Warcraft\_forever_`,
	} {
		if st, err := os.Stat(p); err == nil && st.IsDir() {
			return p
		}
	}
	if exe, err := os.Executable(); err == nil { // helper placed inside the game folder
		dir := filepath.Dir(exe)
		for i := 0; i < 4; i++ {
			if _, err := os.Stat(filepath.Join(dir, "WTF")); err == nil {
				return dir
			}
			dir = filepath.Dir(dir)
		}
	}
	return `C:\Program Files (x86)\World of Warcraft\_forever_`
}

// Newest ForeverCoach.lua under WTF\Account\*\SavedVariables (multiple accounts possible).
func findSavedVariables(game string) string {
	matches, _ := filepath.Glob(filepath.Join(game, "WTF", "Account", "*", "SavedVariables", "ForeverCoach.lua"))
	best, bestT := "", time.Time{}
	for _, m := range matches {
		if st, err := os.Stat(m); err == nil && st.ModTime().After(bestT) {
			best, bestT = m, st.ModTime()
		}
	}
	return best
}

func ago(t time.Time) string {
	if t.Unix() <= 0 {
		return "never"
	}
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		return fmt.Sprintf("%d min ago", int(d.Minutes()))
	case d < 48*time.Hour:
		return fmt.Sprintf("%d h ago", int(d.Hours()))
	}
	return t.Format("2006-01-02")
}

func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	_ = cmd.Start()
}

func printConsole(v View) {
	if v.Error != "" {
		fmt.Println(v.Error)
	}
	for _, c := range v.Chars {
		fmt.Printf("\n%s (%s %s %s, level %d, spec %s) updated %s\n", c.Key, c.Race, c.Class, c.Faction, c.Level, c.Spec, ago(c.Updated))
		for i, f := range c.Findings {
			if i >= 10 {
				break
			}
			fmt.Printf("  [%s] %s\n      %s\n", f.Area, f.Text, f.Fix)
		}
	}
	if v.UpdateNote != "" {
		fmt.Println("\n" + v.UpdateNote)
	}
	b, _ := json.Marshal(struct{ Rules string }{v.RulesVersion})
	fmt.Println(string(b))
}

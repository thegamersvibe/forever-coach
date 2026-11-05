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
	"sync/atomic"
	"time"
)

const Version = "1.2.0"
const Repo = "thegamersvibe/forever-coach"
const RulesSchema = 1

//go:embed report.html logo.png
var assets embed.FS

type Finding struct {
	Impact   float64
	Area     string
	Text     string
	Fix      string
	Where    string
	Estimate bool
}

type CharView struct {
	Key, Name, Realm, Class, Race, Faction, Spec, SpecSource string
	Level                                                    int
	MaxLevel                                                 bool
	XPPct, RestedPct                                         int
	XPPerHour                                                int
	Updated                                                  time.Time
	Findings                                                 []Finding
	Sessions                                                 int
	Deaths                                                   []string
	Money                                                    string
	ClassColor                                               string
	Zone, Guide, GuideStep                                   string
	AddonError                                               string
	Stale                                                    []string
	Slots                                                    []SlotView
	GearStatus, GearNote                                     string
	GearAssessed, GearUnknown, GearEmpty, GearUpgrades       int
	Owned                                                    []OwnedView
	Talents                                                  []TalentView
	TalentSteps                                              []TalentStep
	TalentSource, TalentURL                                  string
	Dungeons                                                 []DungeonView
	Procs                                                    []ProcView
	Stats                                                    StatView
	Counts                                                   map[string]int
}

type SlotView struct {
	Name, Item, BestName, BestHow, BestSource string
	BestWhere, Status, Note                   string
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
	PlayMin, ActiveMin, Deaths                                 int
	CombatPct, DowntimePct, DeadPct, AFKPct, TaxiPct, OtherPct int
	DeathsPerHour                                              string
	XPToLevel, MinToLevel                                      int
	HasData                                                    bool
}

type View struct {
	Chars                       []CharView
	SVPath, Error, RulesVersion string
	Warning                     string
	UpdateNote, AppVersion      string
	Loaded                      time.Time
}

var lastPing atomic.Int64

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

	url := fmt.Sprintf("http://127.0.0.1:%d/", *port)
	ln, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", *port))
	if err != nil {
		// Already running: just show the existing report.
		if !*noOpen {
			openBrowser(url)
		}
		return
	}
	// No console window: the app quits on its own once the report tab has been closed for a while.
	// (Chrome slows timers in background tabs to ~1/min, so the timeout must be well above that.)
	if !*noOpen {
		go func() {
			time.Sleep(3 * time.Minute)
			for {
				time.Sleep(15 * time.Second)
				if time.Since(time.Unix(0, lastPing.Load())) > 3*time.Minute {
					os.Exit(0)
				}
			}
		}()
	}
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
	lastPing.Store(time.Now().UnixNano())
	http.HandleFunc("/stamp", func(w http.ResponseWriter, r *http.Request) {
		lastPing.Store(time.Now().UnixNano())
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
			time.Sleep(700 * time.Millisecond) // let the game finish writing
			a.reload()
		}
		// pick up another account's newer save
		if p := findSavedVariables(a.game); p != "" && p != a.svPath {
			a.svPath = p
			a.reload()
		}
	}
}

func (a *App) reload() {
	a.mu.Lock()
	prev := a.view
	a.mu.Unlock()
	v := View{SVPath: a.svPath, AppVersion: Version, Loaded: time.Now(), UpdateNote: prev.UpdateNote}
	v.RulesVersion = installedRulesVersion(a.addonDir)
	if a.svPath == "" {
		v.Error = "No ForeverCoach data yet. Install the addon, log in, then /reload."
	} else if st, err := os.Stat(a.svPath); err != nil {
		v.Error = "Can't read " + a.svPath + ": " + err.Error()
	} else {
		b, err := os.ReadFile(a.svPath)
		var vars map[string]any
		if err == nil {
			vars, err = ParseSavedVariables(string(b))
		}
		db := M(vars["ForeverCoachDB"])
		if err == nil && db == nil {
			err = fmt.Errorf("no ForeverCoachDB in %s", a.svPath)
		}
		if err == nil && N(db["schema"]) > 1 {
			err = fmt.Errorf("this save was written by a newer Forever Coach addon; update the app")
		}
		if err != nil {
			// keep showing the last good data; the game may still be writing the file
			if len(prev.Chars) > 0 {
				prev.Warning = "Latest save couldn't be read yet, showing the previous one (" + err.Error() + ")"
				prev.Loaded = time.Now()
				a.mu.Lock()
				a.view = prev
				a.mu.Unlock()
				return
			}
			v.Error = err.Error()
		} else {
			a.modTime = st.ModTime() // only accept the file once it parsed
			v.Chars = buildChars(db)
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
			cv.Findings = append(cv.Findings, Finding{N(fm["impact"]), S(fm["area"]), S(fm["text"]), S(fm["fix"]), S(fm["where"]), fm["estimate"] == true})
		}
		sess := List(c["sessions"])
		cv.Sessions = len(sess)
		for i := len(sess) - 1; i >= 0 && len(cv.Deaths) < 8; i-- {
			for _, d := range List(M(sess[i])["deaths"]) {
				dm := M(d)
				line := fmt.Sprintf("Level %s, %s", S(dm["level"]), S(dm["zone"]))
				if t := int64(N(dm["time"])); t > 0 {
					line += " · " + ago(time.Unix(t, 0))
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

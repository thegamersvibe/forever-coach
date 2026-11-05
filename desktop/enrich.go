package main

import (
	"fmt"
	"sort"
	"strconv"
)

var classColors = map[string]string{
	"WARRIOR": "#C69B6D", "PALADIN": "#F48CBA", "HUNTER": "#AAD372", "ROGUE": "#FFF468", "PRIEST": "#E6E6E6",
	"SHAMAN": "#0070DD", "MAGE": "#3FC7EB", "WARLOCK": "#8788EE", "DRUID": "#FF7C0A",
}

// Paper-doll order: left column, right column, weapons.
var slotOrder = []int{1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18}
var slotNames = map[int]string{1: "Head", 2: "Neck", 3: "Shoulder", 15: "Back", 5: "Chest", 9: "Wrist", 10: "Hands",
	6: "Waist", 7: "Legs", 8: "Feet", 11: "Ring 1", 12: "Ring 2", 13: "Trinket 1", 14: "Trinket 2", 16: "Main Hand", 17: "Off Hand", 18: "Ranged"}

func money(c float64) string {
	g, s, cp := int(c)/10000, int(c)/100%100, int(c)%100
	if g > 0 {
		return fmt.Sprintf("%dg %ds %dc", g, s, cp)
	}
	if s > 0 {
		return fmt.Sprintf("%ds %dc", s, cp)
	}
	return fmt.Sprintf("%dc", cp)
}

func enrich(cv *CharView, c, s, g map[string]any, sess []any) {
	cv.ClassColor = classColors[cv.Class]
	if cv.ClassColor == "" {
		cv.ClassColor = "#c9a227"
	}
	cv.Money = money(N(s["money"]))
	cv.Counts = map[string]int{}
	for _, f := range cv.Findings {
		cv.Counts[f.Area]++
	}

	// Gear paper-doll
	slots := M(g["slots"])
	eq := M(s["equipped"])
	totalGap, n := 0, 0
	for _, inv := range slotOrder {
		k := strconv.Itoa(inv)
		e := M(slots[k])
		sv := SlotView{Name: slotNames[inv], GapPct: -1, Weapon: inv >= 16}
		if eq[k] != nil {
			sv.Equipped = true
			sv.Item = itemName(S(M(eq[k])["link"]))
		}
		if b := M(e["best"]); b != nil {
			sv.BestName, sv.BestHow, sv.BestSource = S(b["name"]), S(b["how"]), S(b["source"])
			sv.GapPct = int(N(e["gapPct"]))
			if sv.GapPct < 0 {
				sv.GapPct = 0
			}
			if sv.GapPct > 100 {
				sv.GapPct = 100
			}
			totalGap += sv.GapPct
			n++
		}
		cv.Slots = append(cv.Slots, sv)
	}
	if n > 0 {
		cv.GearScorePct = 100 - totalGap/n
	}
	switch S(g["status"]) {
	case "missing":
		cv.GearNote = "Install GearQuest Forever to turn on gear checks."
	case "classdata":
		cv.GearNote = "Enable your class's GearQuest Forever module, then /reload."
	}

	// Talents
	tabs := List(M(s["talents"])["tabs"])
	for _, t := range tabs {
		sp := int(N(M(t)["spent"]))
		tv := TalentView{Name: S(M(t)["name"]), Spent: sp}
		if avail := cv.Level - 9; avail > 0 {
			tv.Pct = sp * 100 / avail
		}
		cv.Talents = append(cv.Talents, tv)
	}

	// Sessions: last 5
	var secs, combat, recov, dead float64
	procs := map[string]*ProcView{}
	for i := len(sess) - 1; i >= 0 && i >= len(sess)-5; i-- {
		ss := M(sess[i])
		secs += N(ss["seconds"])
		combat += N(ss["combat"])
		recov += N(ss["recovery"])
		dead += N(ss["dead"])
		cv.Stats.Deaths += len(List(ss["deaths"]))
		cv.Stats.Kills += int(N(ss["kills"]))
		for name, p := range M(ss["procs"]) {
			pv := procs[name]
			if pv == nil {
				pv = &ProcView{Name: name}
				procs[name] = pv
			}
			pv.Used += int(N(M(p)["used"]))
			pv.Windows += int(N(M(p)["windows"]))
		}
	}
	if secs > 60 {
		st := &cv.Stats
		st.HasData = true
		st.PlayMin = int(secs / 60)
		st.CombatPct = int(combat / secs * 100)
		st.DowntimePct = int(recov / secs * 100)
		st.DeadPct = int(dead / secs * 100)
		st.DeathsPerHour = fmt.Sprintf("%.1f", float64(st.Deaths)/(secs/3600))
	}
	if mx := N(s["xpMax"]); mx > 0 {
		cv.Stats.XPToLevel = int(mx - N(s["xp"]))
		if cv.XPPerHour > 0 {
			cv.Stats.MinToLevel = cv.Stats.XPToLevel * 60 / cv.XPPerHour
		}
	}
	for _, p := range procs {
		if p.Windows > 0 {
			p.UsedPct = p.Used * 100 / p.Windows
			cv.Procs = append(cv.Procs, *p)
		}
	}
	sort.Slice(cv.Procs, func(i, j int) bool { return cv.Procs[i].Name < cv.Procs[j].Name })
}

// "|cff...|Hitem:123::|h[Name]|h|r" -> "Name"
func itemName(link string) string {
	for i := 0; i < len(link); i++ {
		if link[i] == '[' {
			for j := i + 1; j < len(link); j++ {
				if link[j] == ']' {
					return link[i+1 : j]
				}
			}
		}
	}
	return "Equipped"
}

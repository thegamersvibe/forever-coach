package main

import (
	"html/template"
	"os"
	"strings"
	"testing"
)

const sample = `
ForeverCoachDB = {
	["schema"] = 1,
	["chars"] = {
		["Willtank-Test"] = {
			["snapshot"] = { ["name"] = "Willtank", ["level"] = 20, ["class"] = "WARRIOR", ["race"] = "Dwarf", ["xp"] = 500, ["xpMax"] = 10000, ["rested"] = 0 },
			["gear"] = { ["spec"] = "protection", ["specSource"] = "talents" },
			["findings"] = {
				{ ["impact"] = 80, ["area"] = "Build", ["text"] = "2 unspent talent points", ["fix"] = "Open talents" }, -- [1]
				{ ["impact"] = 50.5, ["area"] = "Play", ["text"] = "Quote \"x\" and \\ slash", ["fix"] = "a\nb" }, -- [2]
			},
			["sessions"] = { { ["deaths"] = { { ["level"] = 19, ["zone"] = "Redridge", ["by"] = "Brute" } } } },
			["updated"] = 1700000000,
			["flag"] = true, ["nothing"] = nil, ["hex"] = 0x10, ["neg"] = -1.5e2,
		},
	},
}
Other = "x"
`

func TestParse(t *testing.T) {
	v, err := ParseSavedVariables(sample)
	if err != nil {
		t.Fatal(err)
	}
	cs := buildChars(M(v["ForeverCoachDB"]))
	if len(cs) != 1 {
		t.Fatalf("chars %d", len(cs))
	}
	c := cs[0]
	if c.Level != 20 || c.Spec != "protection" || len(c.Findings) != 2 || c.Findings[1].Text != `Quote "x" and \ slash` || c.Findings[1].Fix != "a\nb" {
		t.Fatalf("bad %+v", c)
	}
	if len(c.Deaths) != 1 || !strings.Contains(c.Deaths[0], "Brute") {
		t.Fatalf("deaths %v", c.Deaths)
	}
	ch := M(M(M(v["ForeverCoachDB"])["chars"])["Willtank-Test"])
	if N(ch["hex"]) != 16 || N(ch["neg"]) != -150 || ch["flag"] != true || S(v["Other"]) != "x" {
		t.Fatalf("scalars %v", ch)
	}
}

func TestRealFile(t *testing.T) {
	p := os.Getenv("SV_FILE")
	if p == "" {
		t.Skip()
	}
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ParseSavedVariables(string(b)); err != nil {
		t.Fatal(err)
	}
}

func TestRulesToLuaRoundTrip(t *testing.T) {
	b, err := os.ReadFile("../rules/rules.json")
	if err != nil {
		t.Fatal(err)
	}
	var r map[string]any
	if err := jsonUnmarshal(b, &r); err != nil {
		t.Fatal(err)
	}
	lua := RulesToLua(r)
	v, err := ParseSavedVariables(strings.Replace(lua, "-- Generated", "--", 1))
	if err != nil {
		t.Fatal(err)
	}
	if S(M(v["ForeverCoach_Rules"])["version"]) != S(r["version"]) || int(N(M(v["ForeverCoach_Rules"])["schema"])) != RulesSchema {
		t.Fatal("round trip")
	}
	if !semverLess("1.0.0", "v1.0.1") || semverLess("1.10.0", "1.9.9") || semverLess("1.0.0", "1.0.0") {
		t.Fatal("semver")
	}
}

func TestRender(t *testing.T) {
	p := os.Getenv("SV_FILE")
	if p == "" {
		t.Skip()
	}
	b, _ := os.ReadFile(p)
	v, err := ParseSavedVariables(string(b))
	if err != nil {
		t.Fatal(err)
	}
	tpl := template.Must(template.New("report.html").Funcs(funcs).ParseFS(assets, "report.html"))
	var sb strings.Builder
	if err := tpl.Execute(&sb, View{Chars: buildChars(M(v["ForeverCoachDB"])), AppVersion: Version, RulesVersion: "1.0.0"}); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(sb.String(), "ZgotmplZ") {
		t.Fatal("unsafe css placeholder in output")
	}
	os.WriteFile(os.Getenv("HTML_OUT"), []byte(sb.String()), 0o644)
}

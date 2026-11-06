package main

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Redirect upstream requests to a local HTTP server; never query GitHub in tests.
type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestPrivateBundleUpdatesRulesOnly(t *testing.T) {
	const original = "ForeverCoach_Rules = { [\"schema\"] = 1, [\"version\"] = \"1.3.1\" }\n"
	for _, tc := range []struct {
		name, response, wantNote string
		status                   int
		updated, noAddon         bool
	}{
		{"compatible", `{"schema":1,"version":"1.3.2","probe":"retained"}`, "Rules updated 1.3.1 → 1.3.2", 200, true, false},
		{"current", `{"schema":1,"version":"1.3.1"}`, "", 200, false, false},
		{"older", `{"schema":1,"version":"1.2.0"}`, "", 200, false, false},
		{"new schema", `{"schema":2,"version":"9.0.0"}`, "Rules update skipped: incompatible schema for Relax Coach; update the private bundle", 200, false, false},
		{"fractional schema", `{"schema":1.5,"version":"9.0.0"}`, "Rules update skipped: incompatible schema for Relax Coach; update the private bundle", 200, false, false},
		{"missing schema", `{"version":"9.0.0"}`, "Rules update skipped: incompatible schema for Relax Coach; update the private bundle", 200, false, false},
		{"invalid JSON", `{`, "Rules update skipped: bad JSON", 200, false, false},
		{"network failure", `unavailable`, "", 503, false, false},
		{"no addon", `{"schema":1,"version":"1.3.2"}`, "Addon not found at ", 200, false, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			addon := filepath.Join(t.TempDir(), "ForeverCoach")
			if !tc.noAddon {
				if err := os.MkdirAll(addon, 0o755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(addon, "Rules.lua"), []byte(original), 0o644); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(addon, "Core.lua"), []byte("-- Relax Coach"), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if strings.Contains(r.URL.Path, "/releases/") {
					fmt.Fprint(w, `{"tag_name":"v99.0.0","html_url":"https://github.com/thegamersvibe/relax-coach/releases/tag/v99.0.0"}`)
					return
				}
				w.WriteHeader(tc.status)
				io.WriteString(w, tc.response)
			}))
			defer server.Close()
			local, err := url.Parse(server.URL)
			if err != nil {
				t.Fatal(err)
			}
			var requests []string
			upstream := client
			t.Cleanup(func() { client = upstream })
			transport := server.Client().Transport
			client = &http.Client{Timeout: 5 * time.Second, Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
				requests = append(requests, r.URL.String())
				if got := r.Header.Get("User-Agent"); got != "RelaxCoach/"+Version {
					t.Errorf("user agent = %q", got)
				}
				redirected := r.Clone(r.Context())
				redirected.URL.Scheme = local.Scheme
				redirected.URL.Host = local.Host
				return transport.RoundTrip(redirected)
			})}
			note := (&App{addonDir: addon}).updateRules()
			if tc.wantNote == "" && note != "" || tc.wantNote != "" && !strings.Contains(note, tc.wantNote) {
				t.Errorf("note = %q, want %q", note, tc.wantNote)
			}
			if strings.Contains(note, "Forever Coach") || strings.Contains(note, "https://github.com/") || strings.Contains(note, "is available") {
				t.Errorf("upstream app advertised by private helper: %q", note)
			}
			if tc.noAddon {
				if len(requests) != 0 {
					t.Errorf("requests without an installed addon: %v", requests)
				}
				return
			}
			wantURL := "https://raw.githubusercontent.com/thegamersvibe/relax-coach/main/rules/rules.json"
			if len(requests) != 1 || requests[0] != wantURL {
				t.Errorf("only compatible rules may be fetched, got %v", requests)
			}
			data, err := os.ReadFile(filepath.Join(addon, "Rules.lua"))
			if err != nil {
				t.Fatal(err)
			}
			if tc.updated {
				vars, err := ParseSavedVariables(string(data))
				if err != nil {
					t.Fatal(err)
				}
				rules := M(vars["ForeverCoach_Rules"])
				if S(rules["version"]) != "1.3.2" || S(rules["probe"]) != "retained" || N(rules["schema"]) != RulesSchema {
					t.Fatalf("compatible rules did not retain the legacy global/data: %v", rules)
				}
			} else if string(data) != original {
				t.Error("skipped update changed installed rules")
			}
			if _, err := os.Stat(filepath.Join(addon, "Rules.lua.new")); !os.IsNotExist(err) {
				t.Errorf("temporary rules file left behind: %v", err)
			}
			core, err := os.ReadFile(filepath.Join(addon, "Core.lua"))
			if err != nil || string(core) != "-- Relax Coach" {
				t.Error("rules update changed branded addon code")
			}
		})
	}
}

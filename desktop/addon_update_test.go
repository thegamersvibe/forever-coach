package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

// Legacy Coach-only fixtures deliberately stay below the Guild policy floor.
const testAddonDownload = "https://github.com/thegamersvibe/relax-coach/releases/download/v1.5.0/" // Shared app-only fixtures.
const testAddonTag = "v1.4.1"
const testAddonAsset = "RelaxCoach-1.4.1.zip"
const legacyAddonDownload = "https://github.com/thegamersvibe/relax-coach/releases/download/" + testAddonTag + "/"

// Route genuinely trusted URLs through a real local HTTP server. Production URL
// validation and redirect policy stay enabled; no insecure runtime flag exists.
type addonTestTransport struct {
	server *url.URL
	base   http.RoundTripper
}

func (t addonTestTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	copy := req.Clone(req.Context())
	u := *req.URL
	u.Scheme, u.Host = t.server.Scheme, t.server.Host
	copy.URL = &u
	return t.base.RoundTrip(copy)
}

func addonTestRelease(tag string) map[string]any {
	version := strings.TrimPrefix(tag, "v")
	prefix := "https://github.com/thegamersvibe/relax-coach/releases/download/" + tag + "/"
	return map[string]any{
		"tag_name": tag, "name": "Relax Coach " + version, "body": "Release notes.",
		"html_url": "https://github.com/thegamersvibe/relax-coach/releases/tag/" + tag,
		"draft":    false, "prerelease": false,
		"assets": []map[string]any{
			{"name": "RelaxCoach-" + version + ".zip", "browser_download_url": prefix + "RelaxCoach-" + version + ".zip"},
			{"name": "SHA256SUMS.txt", "browser_download_url": prefix + "SHA256SUMS.txt"},
		},
	}
}

func addonTestUpdater(t *testing.T, handler http.HandlerFunc) *addonUpdater {
	t.Helper()
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	u := newAddonUpdater()
	serverURL, _ := url.Parse(server.URL)
	transport := http.DefaultTransport.(*http.Transport).Clone()
	t.Cleanup(transport.CloseIdleConnections)
	u.client.Transport = addonTestTransport{server: serverURL, base: transport}
	u.running = func(context.Context) (bool, error) { return false, nil }
	return u
}

func TestAddonCheckStableNewRelease(t *testing.T) {
	u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/repos/thegamersvibe/relax-coach/releases/latest" {
			t.Errorf("unexpected endpoint: %s", r.URL.Path)
		}
		if r.Header.Get("User-Agent") == "" {
			t.Error("missing GitHub user agent")
		}
		json.NewEncoder(w).Encode(addonTestRelease(testAddonTag))
	})
	got, err := u.check(context.Background(), "1.4.0")
	if err != nil {
		t.Fatal(err)
	}
	if !got.Available || got.Version != "1.4.1" || got.AssetName != testAddonAsset || got.AssetURL != legacyAddonDownload+testAddonAsset || got.ChecksumURL != legacyAddonDownload+"SHA256SUMS.txt" {
		t.Fatalf("bad release: %+v", got)
	}
	b, err := json.Marshal(got)
	if err != nil {
		t.Fatal(err)
	}
	var fields map[string]any
	json.Unmarshal(b, &fields)
	for _, key := range []string{"version", "name", "notes", "htmlUrl", "assetName", "assetUrl", "checksumUrl", "available"} {
		if _, ok := fields[key]; !ok {
			t.Errorf("missing JSON field %s: %s", key, b)
		}
	}
	if len(fields) != 8 {
		t.Fatalf("unexpected API fields: %s", b)
	}
}

func TestAddonCheckNeverAdvertisesOlderOrIncompatibleRelease(t *testing.T) {
	for _, tc := range []struct {
		tag, current string
		mutate       func(map[string]any)
	}{
		{"v1.3.1", "1.4.0", func(r map[string]any) { r["assets"] = []any{map[string]any{"name": "ForeverCoach-1.3.1.zip"}} }},
		{"v1.4.0", "1.4.0", nil},
		{"v1.4.1", "1.5.1", nil},
		{"v1.4.1-rc.1", "1.4.0", nil},
		{"v01.4.1", "1.4.0", nil},
		{"v1.5", "1.4.0", nil},
		{"v1.4.1", "1.4.0", func(r map[string]any) { r["draft"] = true }},
		{"v1.4.1", "1.4.0", func(r map[string]any) { r["prerelease"] = true }},
		{"v1.4.1", "1.4.0", func(r map[string]any) { r["assets"] = []any{} }},
		{"v1.4.0+build.2", "1.4.0+build.1", nil},
	} {
		t.Run(fmt.Sprintf("%s_from_%s", tc.tag, tc.current), func(t *testing.T) {
			u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
				release := addonTestRelease(tc.tag)
				if tc.mutate != nil {
					tc.mutate(release)
				}
				json.NewEncoder(w).Encode(release)
			})
			got, err := u.check(context.Background(), tc.current)
			if err != nil {
				t.Fatal(err)
			}
			if got.Available {
				t.Fatalf("advertised unsafe release: %+v", got)
			}
			if !strings.Contains(strings.ToLower(got.Notes), "no compatible new addon update") {
				t.Fatalf("unclear no-update message: %q", got.Notes)
			}
		})
	}
}

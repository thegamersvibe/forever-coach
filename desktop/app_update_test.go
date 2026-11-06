package main

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
)

func appTestRelease(tag string) map[string]any {
	r := addonTestRelease(tag)
	r["assets"].([]map[string]any)[0] = map[string]any{"name": "RelaxCoach.exe", "browser_download_url": addonReleasePrefix + "download/" + tag + "/RelaxCoach.exe"}
	return r
}
func appTestUpdater(t *testing.T, handler http.HandlerFunc) *appUpdater {
	u := newAppUpdater()
	u.transport = addonTestUpdater(t, handler)
	return u
}
func TestAppReleaseRejectsUnsafeOffers(t *testing.T) {
	for _, tc := range []struct {
		name, tag, current string
		mutate             func(map[string]any)
		bad                bool
	}{
		{"equal", "v1.5.0", "1.5.0", nil, false},
		{"older", "v1.5.0", "1.6.0", nil, false},
		{"metadata", "v1.5.0+new", "1.5.0+old", nil, false},
		{"prerelease tag", "v1.5.0-rc.1", "1.4.1", nil, false},
		{"draft", "v1.5.0", "1.4.1", func(r map[string]any) { r["draft"] = true }, false},
		{"prerelease", "v1.5.0", "1.4.1", func(r map[string]any) { r["prerelease"] = true }, false},
		{"missing", "v1.5.0", "1.4.1", func(r map[string]any) { r["assets"] = []any{} }, false},
		{"duplicate exe", "v1.5.0", "1.4.1", func(r map[string]any) { a := r["assets"].([]map[string]any); r["assets"] = append(a, a[0]) }, true},
		{"duplicate checksum", "v1.5.0", "1.4.1", func(r map[string]any) { a := r["assets"].([]map[string]any); r["assets"] = append(a, a[1]) }, true},
		{"wrong channel", "v1.5.0", "1.4.1", func(r map[string]any) {
			r["assets"].([]map[string]any)[0]["browser_download_url"] = "https://github.com/evil/app/releases/download/v1.5.0/RelaxCoach.exe"
		}, true},
		{"wrong checksum release", "v1.5.0", "1.4.1", func(r map[string]any) {
			r["assets"].([]map[string]any)[1]["browser_download_url"] = addonReleasePrefix + "download/v1.4.1/SHA256SUMS.txt"
		}, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			u := appTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
				body := appTestRelease(tc.tag)
				if tc.mutate != nil {
					tc.mutate(body)
				}
				json.NewEncoder(w).Encode(body)
			})
			got, err := u.check(context.Background(), tc.current)
			if tc.bad {
				if err == nil {
					t.Fatalf("unsafe offer accepted: %+v", got)
				}
				return
			}
			if err != nil || got.Available || got.AssetURL != "" || got.ChecksumURL != "" || got.Notes == "" {
				t.Fatalf("invalid no-update: %+v %v", got, err)
			}
		})
	}
}

func TestAppReleaseSelectsExactExecutable(t *testing.T) {
	u := appTestUpdater(t, func(w http.ResponseWriter, r *http.Request) { json.NewEncoder(w).Encode(appTestRelease("v1.5.0")) })
	got, err := u.check(context.Background(), "1.4.1")
	if err != nil {
		t.Fatal(err)
	}
	if !got.Available || got.Version != "1.5.0" || got.AssetName != "RelaxCoach.exe" || got.AssetURL != testAddonDownload+"RelaxCoach.exe" || got.ChecksumURL != testAddonDownload+"SHA256SUMS.txt" {
		t.Fatalf("wrong executable offer: %+v", got)
	}
}

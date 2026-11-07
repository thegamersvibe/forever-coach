package main

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
)

func TestRelaxRepositoryEndpoints(t *testing.T) {
	if addonLatestURL != "https://api.github.com/repos/thegamersvibe/relax-coach/releases/latest" {
		t.Fatalf("updater still uses pre-rename repository: %s", addonLatestURL)
	}
	if addonReleasePrefix != "https://github.com/thegamersvibe/relax-coach/releases/" {
		t.Fatalf("release allowlist still uses pre-rename repository: %s", addonReleasePrefix)
	}
}

func TestRelaxGuildReleaseKeepsCoachUpdaterScoped(t *testing.T) {
	const prefix = "https://github.com/thegamersvibe/relax-coach/releases/download/v1.4.1/"
	release := map[string]any{
		"tag_name": "v1.4.1", "name": "Relax Coach guild bundle", "body": "Guild release",
		"html_url": "https://github.com/thegamersvibe/relax-coach/releases/tag/v1.4.1",
		"draft":    false, "prerelease": false,
		"assets": []map[string]any{
			{"name": "RelaxCoach-Guild-1.4.1.zip", "browser_download_url": prefix + "RelaxCoach-Guild-1.4.1.zip"},
			{"name": "RelaxCoach-1.4.1.zip", "browser_download_url": prefix + "RelaxCoach-1.4.1.zip"},
			{"name": "SHA256SUMS.txt", "browser_download_url": prefix + "SHA256SUMS.txt"},
		},
	}
	u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/repos/thegamersvibe/relax-coach/releases/latest" {
			t.Errorf("wrong renamed endpoint: %s", r.URL.Path)
		}
		json.NewEncoder(w).Encode(release)
	})
	info, err := u.check(context.Background(), "1.4.0")
	if err != nil {
		t.Fatal(err)
	}
	if !info.Available || info.AssetName != "RelaxCoach-1.4.1.zip" || info.AssetURL != prefix+"RelaxCoach-1.4.1.zip" {
		t.Fatalf("guild release must select the Coach-only update asset: %+v", info)
	}
}

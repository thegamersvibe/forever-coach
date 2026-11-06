package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"testing"
)

func TestAddonInstalledVersionAndFirstPublicRelease(t *testing.T) {
	for _, fresh := range []bool{false, true} {
		t.Run(fmt.Sprintf("fresh=%v", fresh), func(t *testing.T) {
			game := addonTestGame(t)
			target := filepath.Join(game, "Interface", "AddOns", "ForeverCoach")
			if fresh {
				if err := os.RemoveAll(target); err != nil {
					t.Fatal(err)
				}
			} else {
				addonPut(t, target, "ForeverCoach.toc", "## Title: Forever Coach\n## Version: 1.3.1\n## SavedVariables: ForeverCoachDB\n")
			}
			current := InstalledCoachVersion(game)
			wantVersion := "1.3.1"
			if fresh {
				wantVersion = "0.0.0"
			}
			if current != wantVersion {
				t.Fatalf("installed version = %q; want %q", current, wantVersion)
			}
			payload := addonZip(t, addonFixtureEntries("1.4.0"))
			sum := sha256.Sum256(payload)
			u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
				switch r.URL.Path {
				case "/repos/thegamersvibe/relax-coach/releases/latest":
					json.NewEncoder(w).Encode(addonTestRelease("v1.4.0"))
				case "/thegamersvibe/relax-coach/releases/download/v1.4.0/RelaxCoach-1.4.0.zip":
					w.Write(payload)
				case "/thegamersvibe/relax-coach/releases/download/v1.4.0/SHA256SUMS.txt":
					fmt.Fprintf(w, "%x  RelaxCoach-1.4.0.zip\n", sum)
				default:
					t.Errorf("unexpected path %s", r.URL.Path)
					http.NotFound(w, r)
				}
			})
			release, err := u.check(context.Background(), current)
			if err != nil || !release.Available {
				t.Fatalf("first public Relax release not offered: %+v, %v", release, err)
			}
			result, err := u.apply(context.Background(), game, release)
			if err != nil {
				t.Fatal(err)
			}
			if result.Version != "1.4.0" || InstalledCoachVersion(game) != "1.4.0" {
				t.Fatalf("bad first release install: %+v", result)
			}
			if fresh && result.BackupPath != "" {
				t.Fatalf("invented backup for missing addon: %s", result.BackupPath)
			}
		})
	}
}

func TestAddonInstalledVersionIgnoresOtherMetadata(t *testing.T) {
	game := addonTestGame(t)
	addonPut(t, game, "Interface/AddOns/ForeverCoach/ForeverCoach.toc", "## X-Rules-Version: 9.9.9\n# ## Version: 8.8.8\n## Version: 1.3.1\n")
	if got := InstalledCoachVersion(game); got != "1.3.1" {
		t.Fatalf("wrong metadata: %q", got)
	}
	if got := InstalledCoachVersion(""); got != "0.0.0" {
		t.Fatalf("absent game version: %q", got)
	}
}

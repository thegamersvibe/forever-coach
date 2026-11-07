package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestAddonRejectsUnsafeArchivesWithoutChangingAnyFile(t *testing.T) {
	for _, name := range []string{
		"../outside.lua", "/absolute.lua", "C:/outside.lua", "ForeverCoach/../outside.lua",
		"ForeverCoach\\Core.lua", "ForeverCoach/Core.lua:evil", "ForeverCoach/CON.lua",
		"ForeverCoach/LPT1.txt", "ForeverCoach/Core.lua.", "ForeverCoach/Core.lua ",
		"ForeverCoach//Core.lua", "ForeverCoach/./Core.lua", "ForeverCoach/core.lua",
		"ForeverCoach/Core.lua", "ForeverCoach/Evil.lua", "ForeverCoach/install.bat",
		"Journey/private.lua", "Interface/Content/private.bin", "ForeverCoach/Content/private.bin",
		"ForeverCoach/Journey/private.lua", "WTF/Account/test/SavedVariables/ForeverCoach.lua",
		"ForeverCoach/\u202eevil.lua", "README.MD", "run.ps1",
	} {
		t.Run(name, func(t *testing.T) {
			entries := addonFixtureEntries("1.4.1")
			entries = append(entries, addonZipEntry{name, "hostile bytes", 0o644})
			assertAddonPayloadRejected(t, entries, "")
		})
	}
	t.Run("symlink", func(t *testing.T) {
		entries := addonFixtureEntries("1.4.1")
		entries[1].mode = os.ModeSymlink | 0o777
		entries[1].body = "../../WTF/Account/test/SavedVariables/ForeverCoach.lua"
		assertAddonPayloadRejected(t, entries, "symlink")
	})
	t.Run("named pipe", func(t *testing.T) {
		entries := addonFixtureEntries("1.4.1")
		entries[1].mode = os.ModeNamedPipe | 0o600
		assertAddonPayloadRejected(t, entries, "special")
	})
	t.Run("missing module", func(t *testing.T) {
		assertAddonPayloadRejected(t, addonFixtureEntries("1.4.1")[:len(addonFixtureFiles)-1], "missing")
	})
}

func assertAddonPayloadRejected(t *testing.T, entries []addonZipEntry, contains string) {
	t.Helper()
	u := addonPayloadUpdater(t, addonZip(t, entries), "")
	game := addonTestGame(t)
	before := addonTreeHashes(t, game)
	_, err := u.apply(context.Background(), game, addonTestInfo())
	if err == nil {
		t.Fatal("unsafe addon installed")
	}
	if contains != "" && !strings.Contains(strings.ToLower(err.Error()), strings.ToLower(contains)) {
		t.Fatalf("wrong error, want %q in %v", contains, err)
	}
	if after := addonTreeHashes(t, game); !reflect.DeepEqual(before, after) {
		t.Fatalf("files changed on unsafe package refusal: %v", after)
	}
}

func TestAddonRejectsIncompatibleTOC(t *testing.T) {
	for _, tc := range []struct{ name, old, replacement, errorText string }{
		{"old brand", "## Title: Relax Coach", "## Title: Forever Coach", "Title"},
		{"mismatched version", "## Version: 1.4.1", "## Version: 1.4.0", "version"},
		{"renamed saved variables", "## SavedVariables: ForeverCoachDB", "## SavedVariables: RelaxCoachDB", "SavedVariables"},
		{"additional saved variables", "## SavedVariables: ForeverCoachDB", "## SavedVariables: ForeverCoachDB, JourneyDB", "SavedVariables"},
		{"per-character variables", "## SavedVariables: ForeverCoachDB", "## SavedVariables: ForeverCoachDB\n## SavedVariablesPerCharacter: ForeverCoachDB", "SavedVariables"},
		{"required Journey", "## OptionalDeps: Journey", "## Dependencies: Journey", "Journey"},
		{"required Journey alias", "## OptionalDeps: Journey", "## RequiredDeps: GearQuestForever, JOURNEY", "Journey"},
		{"TOC load escape", "Core.lua", "../Journey/Core.lua", "path"},
		{"duplicate version", "## Version: 1.4.1", "## Version: 1.4.1\n## Version: 1.4.1", "duplicate"},
		{"missing loaded module", "Core.lua\n", "", "module"},
		{"inexact Version field", "## Version: 1.4.1", "## version: 1.4.1", "Version"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			entries := addonFixtureEntries("1.4.1")
			entries[0].body = strings.Replace(entries[0].body, tc.old, tc.replacement, 1)
			assertAddonPayloadRejected(t, entries, tc.errorText)
		})
	}
}

func TestAddonChecksumFailureLeavesGameUnchanged(t *testing.T) {
	for _, checksum := range []string{
		strings.Repeat("0", 64) + "  " + testAddonAsset + "\n",
		strings.Repeat("a", 64) + "  Wrong.zip\n",
		strings.Repeat("a", 64) + "  " + testAddonAsset + "\n" + strings.Repeat("b", 64) + "  " + testAddonAsset + "\n",
		"not a checksum\n",
		strings.Repeat("a", 64) + "  ../" + testAddonAsset + "\n",
	} {
		u := addonPayloadUpdater(t, addonZip(t, addonFixtureEntries("1.4.1")), checksum)
		game := addonTestGame(t)
		before := addonTreeHashes(t, game)
		if _, err := u.apply(context.Background(), game, addonTestInfo()); err == nil {
			t.Fatal("accepted invalid checksum")
		}
		if after := addonTreeHashes(t, game); !reflect.DeepEqual(before, after) {
			t.Fatal("checksum failure changed files")
		}
	}
}

func TestAddonArchiveLimitsBoundDownloadsAndExpansion(t *testing.T) {
	for _, which := range []string{"download", "checksum", "entry count", "expanded total", "individual file"} {
		t.Run(which, func(t *testing.T) {
			u := addonPayloadUpdater(t, addonZip(t, addonFixtureEntries("1.4.1")), "")
			switch which {
			case "download":
				u.limits.archive = 30
			case "checksum":
				u.limits.checksum = 10
			case "entry count":
				u.limits.entries = 3
			case "expanded total":
				u.limits.expanded = 40
			case "individual file":
				u.limits.file = 30
			}
			game := addonTestGame(t)
			before := addonTreeHashes(t, game)
			if _, err := u.apply(context.Background(), game, addonTestInfo()); err == nil || !strings.Contains(err.Error(), "limit") {
				t.Fatalf("unbounded %s: %v", which, err)
			}
			if after := addonTreeHashes(t, game); !reflect.DeepEqual(before, after) {
				t.Fatal("limit failure changed files")
			}
		})
	}
}

func TestAddonUntrustedReleaseURLsNeverReachNetwork(t *testing.T) {
	for _, bad := range []string{
		"http://github.com/thegamersvibe/relax-coach/releases/download/v1.4.1/RelaxCoach-1.4.1.zip",
		"https://github.com.evil.example/thegamersvibe/relax-coach/releases/download/v1.4.1/RelaxCoach-1.4.1.zip",
		"https://github.com/other/forever-coach/releases/download/v1.4.1/RelaxCoach-1.4.1.zip",
		"https://user:pass@github.com/thegamersvibe/relax-coach/releases/download/v1.4.1/RelaxCoach-1.4.1.zip",
		legacyAddonDownload + testAddonAsset + "?evil=1", legacyAddonDownload + testAddonAsset + "#evil", legacyAddonDownload + "%52elaxCoach-1.4.1.zip",
		"https://github.com:443/thegamersvibe/relax-coach/releases/download/v1.4.1/RelaxCoach-1.4.1.zip",
		"https://release-assets.githubusercontent.com/forged.zip",
	} {
		t.Run(bad, func(t *testing.T) {
			u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) { t.Error("untrusted apply reached network") })
			info := addonTestInfo()
			info.AssetURL = bad
			if _, err := u.apply(context.Background(), addonTestGame(t), info); err == nil {
				t.Fatal("accepted untrusted asset URL")
			}
		})
	}
	t.Run("checksum from another tag", func(t *testing.T) {
		u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) { t.Error("wrong checksum tag reached network") })
		info := addonTestInfo()
		info.ChecksumURL = strings.Replace(info.ChecksumURL, "v1.4.1", "v1.4.0", 1)
		if _, err := u.apply(context.Background(), addonTestGame(t), info); err == nil {
			t.Fatal("accepted checksum from different release")
		}
	})
}

func TestAddonDownloadRedirectPolicy(t *testing.T) {
	for _, tc := range []struct {
		destination string
		allowed     bool
	}{
		{"https://release-assets.githubusercontent.com/signed.zip?sig=abc", true},
		{"https://objects.githubusercontent.com/signed.zip?sig=abc", true},
		{"https://github-releases.githubusercontent.com/signed.zip", true},
		{"http://release-assets.githubusercontent.com/signed.zip", false},
		{"https://release-assets.githubusercontent.com.evil.test/signed.zip", false},
		{"https://evil.test/steal", false},
		{"https://github.com/another-owner/archive.zip", false},
		{"http://127.0.0.1/private", false},
	} {
		t.Run(tc.destination, func(t *testing.T) {
			hits := 0
			u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
				hits++
				if hits == 1 {
					http.Redirect(w, r, tc.destination, http.StatusFound)
					return
				}
				fmt.Fprint(w, "ok")
			})
			b, err := u.fetch(context.Background(), legacyAddonDownload+testAddonAsset, 100, "test archive")
			if tc.allowed {
				if err != nil || string(b) != "ok" || hits != 2 {
					t.Fatalf("allowed CDN rejected: %q %v %d", b, err, hits)
				}
			} else if err == nil || hits != 1 {
				t.Fatalf("untrusted redirect was followed: err=%v hits=%d", err, hits)
			}
		})
	}
}

func TestAddonRateLimitsAndNetworkCancellation(t *testing.T) {
	for _, status := range []int{http.StatusForbidden, http.StatusTooManyRequests} {
		u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("X-RateLimit-Remaining", "0")
			w.WriteHeader(status)
		})
		if _, err := u.check(context.Background(), "1.4.0"); err == nil || !strings.Contains(strings.ToLower(err.Error()), "rate limit") {
			t.Fatalf("unclear rate-limit error: %v", err)
		}
	}
	u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) { <-r.Context().Done() })
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Millisecond)
	defer cancel()
	start := time.Now()
	_, err := u.check(ctx, "1.4.0")
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("lost request cancellation: %v", err)
	}
	if time.Since(start) > time.Second {
		t.Fatal("network cancellation was not bounded")
	}
}

func TestAddonCheckRejectsUntrustedAssets(t *testing.T) {
	u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
		release := addonTestRelease(testAddonTag)
		release["assets"].([]map[string]any)[0]["browser_download_url"] = "https://evil.test/malware.zip"
		json.NewEncoder(w).Encode(release)
	})
	if _, err := u.check(context.Background(), "1.4.0"); err == nil {
		t.Fatal("advertised an untrusted asset URL")
	}
}

func TestAddonRejectsLinkedFilesystemTargets(t *testing.T) {
	for _, relative := range []string{"Interface", "Interface/AddOns", "Interface/AddOns/ForeverCoach", "RelaxCoachBackups"} {
		t.Run(relative, func(t *testing.T) {
			game := addonTestGame(t)
			external := t.TempDir()
			addonPut(t, external, "sentinel.txt", "must not change")
			link := filepath.Join(game, filepath.FromSlash(relative))
			if err := os.RemoveAll(link); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(external, link); err != nil {
				t.Skipf("symlink unavailable: %v", err)
			}
			u := addonPayloadUpdater(t, addonZip(t, addonFixtureEntries("1.4.1")), "")
			before := addonTreeHashes(t, external)
			if _, err := u.apply(context.Background(), game, addonTestInfo()); err == nil {
				t.Fatal("installed through a symlink")
			}
			if after := addonTreeHashes(t, external); !reflect.DeepEqual(before, after) {
				t.Fatal("external linked target changed")
			}
		})
	}
}

package main

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

var addonFixtureFiles = []string{"ForeverCoach.toc", "Core.lua", "Rules.lua", "Route.lua", "Session.lua", "Gear.lua", "Talents.lua", "Dungeons.lua", "Audit.lua", "Macros.lua", "UI.lua", "ForeverCoach.tga"}

type addonZipEntry struct {
	name, body string
	mode       os.FileMode
}

func addonFixtureEntries(version string) []addonZipEntry {
	entries := []addonZipEntry{}
	for _, name := range addonFixtureFiles {
		body := "-- new addon module\n"
		if name == "ForeverCoach.toc" {
			body = "## Interface: 16001\n## Title: Relax Coach\n## Version: " + version + "\n## SavedVariables: ForeverCoachDB\n## OptionalDeps: Journey\n"
			for _, file := range addonFixtureFiles {
				if strings.HasSuffix(file, ".lua") {
					body += file + "\n"
				}
			}
		}
		entries = append(entries, addonZipEntry{"ForeverCoach/" + name, body, 0o644})
	}
	return entries
}

func addonZip(t *testing.T, entries []addonZipEntry) []byte {
	t.Helper()
	var out bytes.Buffer
	w := zip.NewWriter(&out)
	for _, entry := range entries {
		h := &zip.FileHeader{Name: entry.name, Method: zip.Deflate}
		h.SetMode(entry.mode)
		file, err := w.CreateHeader(h)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := file.Write([]byte(entry.body)); err != nil {
			t.Fatal(err)
		}
	}
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return out.Bytes()
}

func addonPayloadUpdater(t *testing.T, payload []byte, checksumOverride string) *addonUpdater {
	t.Helper()
	sum := sha256.Sum256(payload)
	checksum := hex.EncodeToString(sum[:]) + "  " + testAddonAsset + "\n"
	if checksumOverride != "" {
		checksum = checksumOverride
	}
	return addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/repos/thegamersvibe/relax-coach/releases/latest":
			json.NewEncoder(w).Encode(addonTestRelease(testAddonTag))
		case "/thegamersvibe/relax-coach/releases/download/" + testAddonTag + "/" + testAddonAsset:
			w.Write(payload)
		case "/thegamersvibe/relax-coach/releases/download/" + testAddonTag + "/SHA256SUMS.txt":
			fmt.Fprint(w, checksum)
		default:
			t.Errorf("unexpected download %s", r.URL.Path)
			http.NotFound(w, r)
		}
	})
}

func addonTestInfo() AddonReleaseInfo {
	return AddonReleaseInfo{Version: "1.5.0", Name: "Relax Coach", AssetName: testAddonAsset, AssetURL: testAddonDownload + testAddonAsset, ChecksumURL: testAddonDownload + "SHA256SUMS.txt", Available: true}
}

func addonPut(t *testing.T, root, name, body string) {
	t.Helper()
	p := filepath.Join(root, filepath.FromSlash(name))
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func addonTestGame(t *testing.T) string {
	t.Helper()
	game := t.TempDir()
	addonPut(t, game, "Interface/AddOns/ForeverCoach/ForeverCoach.toc", "## Title: Relax Coach\n## Version: 1.4.0\n## SavedVariables: ForeverCoachDB\nCore.lua\n")
	addonPut(t, game, "Interface/AddOns/ForeverCoach/Core.lua", "-- old addon bytes\n")
	addonPut(t, game, "Interface/AddOns/ForeverCoach/old-only.txt", "preserve this in backup")
	addonPut(t, game, "Interface/AddOns/Journey/private.lua", "private Journey content\x00\xff")
	addonPut(t, game, "Interface/Content/secret.bin", "private Interface Content")
	addonPut(t, game, "WTF/Account/test/SavedVariables/ForeverCoach.lua", "ForeverCoachDB = { history = 'do not touch' }")
	addonPut(t, game, "WTF/Account/test/SavedVariables/Journey.lua", "private Journey saved variables")
	addonPut(t, game, "RelaxCoach.exe", "existing running helper")
	return game
}

func addonTreeHashes(t *testing.T, root string) map[string]string {
	t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(root, p)
		h := sha256.Sum256(b)
		out[filepath.ToSlash(rel)] = hex.EncodeToString(h[:])
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func TestAddonApplyRealDownloadPreservesPrivateData(t *testing.T) {
	entries := addonFixtureEntries("1.5.0")
	entries = append(entries, addonZipEntry{"RelaxCoach.exe", "never install or execute this", 0o755}, addonZipEntry{"README.md", "docs", 0o644}, addonZipEntry{"LICENSE", "license", 0o644}, addonZipEntry{"manifest.json", "{}", 0o644})
	u := addonPayloadUpdater(t, addonZip(t, entries), "")
	game := addonTestGame(t)
	before := addonTreeHashes(t, game)
	release, err := u.check(context.Background(), "1.4.0")
	if err != nil {
		t.Fatal(err)
	}
	result, err := u.apply(context.Background(), game, release)
	if err != nil {
		t.Fatal(err)
	}
	if result.Version != "1.5.0" || result.UpdatedFiles != len(addonFixtureFiles) || result.BackupPath == "" || !strings.Contains(result.Message, "helper") {
		t.Fatalf("bad result: %+v", result)
	}
	installed := addonTreeHashes(t, filepath.Join(game, "Interface", "AddOns", "ForeverCoach"))
	if len(installed) != len(addonFixtureFiles) {
		t.Fatalf("wrong installed files: %v", installed)
	}
	for _, entry := range entries {
		if !strings.HasPrefix(entry.name, "ForeverCoach/") {
			continue
		}
		sum := sha256.Sum256([]byte(entry.body))
		if installed[strings.TrimPrefix(entry.name, "ForeverCoach/")] != hex.EncodeToString(sum[:]) {
			t.Errorf("file not verified: %s", entry.name)
		}
	}
	backup := addonTreeHashes(t, result.BackupPath)
	for name, hash := range before {
		if strings.HasPrefix(name, "Interface/AddOns/ForeverCoach/") {
			if backup[strings.TrimPrefix(name, "Interface/AddOns/ForeverCoach/")] != hash {
				t.Errorf("old bytes not preserved: %s", name)
			}
			continue
		}
		b, err := os.ReadFile(filepath.Join(game, filepath.FromSlash(name)))
		if err != nil {
			t.Fatal(err)
		}
		sum := sha256.Sum256(b)
		if hex.EncodeToString(sum[:]) != hash {
			t.Errorf("private/helper file changed: %s", name)
		}
	}
	b, _ := json.Marshal(result)
	var fields map[string]any
	json.Unmarshal(b, &fields)
	if !reflect.DeepEqual(sortedAddonKeys(fields), []string{"backupPath", "message", "updatedFiles", "version"}) {
		t.Fatalf("bad result JSON: %s", b)
	}
}

func sortedAddonKeys(m map[string]any) []string {
	// Fixed order makes assertions independent of Go map iteration.
	out := []string{}
	for _, name := range []string{"backupPath", "message", "updatedFiles", "version"} {
		if _, ok := m[name]; ok {
			out = append(out, name)
		}
	}
	if len(out) != len(m) {
		return nil
	}
	return out
}

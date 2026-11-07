package main

import (
	"context"
	"os"
	"reflect"
	"strings"
	"testing"
)

func assertGuildRejected(t *testing.T, entries []addonZipEntry, manifest map[string]any, contains string) {
	t.Helper()
	game := guildGame(t)
	before := addonTreeHashes(t, game)
	u := guildUpdater(t, guildZip(t, entries, manifest))
	result, err := u.apply(context.Background(), game, guildInfo())
	if err == nil || result.Version != "" || !strings.Contains(strings.ToLower(err.Error()), strings.ToLower(contains)) {
		t.Fatalf("expected %q refusal, got %+v %v", contains, result, err)
	}
	if !reflect.DeepEqual(before, addonTreeHashes(t, game)) {
		t.Fatal("invalid bundle changed runtime or saves")
	}
}

func TestGuildRejectsImplicitDirectoryCaseCollisions(t *testing.T) {
	entries := guildEntries()
	entries = append(entries, addonZipEntry{"Interface/AddOns/Journey/Lib/other.lua", "must not merge on Windows", 0644})
	assertGuildRejected(t, entries, nil, "collid")
}

func TestGuildRejectsSpecialFilesWithDirectorySuffix(t *testing.T) {
	for _, mode := range []os.FileMode{os.ModeSymlink | 0777, os.ModeNamedPipe | 0600} {
		entries := guildEntries()
		manifest := guildManifest(entries)
		entries = append(entries, addonZipEntry{"Interface/AddOns/Journey/linked/", "", mode})
		assertGuildRejected(t, entries, manifest, "special")
	}
}

func TestAddonRejectsSymlinkMarkedDirectory(t *testing.T) {
	entries := append(addonFixtureEntries("1.4.1"), addonZipEntry{"ForeverCoach/", "", os.ModeSymlink | 0777})
	assertAddonPayloadRejected(t, entries, "symlink")
}

func TestGuildKeepsJourneyIndependentOfCoach(t *testing.T) {
	for _, key := range []string{"Dependencies", "RequiredDeps", "RequiredDependencies", "Deps", "Required-Dependencies", "Required-Deps"} {
		t.Run(key, func(t *testing.T) {
			entries := guildEntries()
			entries[len(addonFixtureFiles)].body += "## " + key + ": Blizzard_BattlefieldMap, ForeverCoach\n"
			assertGuildRejected(t, entries, nil, "dependency")
		})
	}
}

func TestGuildManifestAndArchiveFailClosed(t *testing.T) {
	for _, name := range []string{"missing manifest file", "extra manifest file", "duplicate row", "hash mismatch", "size mismatch", "project", "kind", "version", "missing guides", "empty guides", "Journey identity", "Journey save identity", "Coach save identity", "unexpected root", "traversal", "ADS", "special", "symlink"} {
		t.Run(name, func(t *testing.T) {
			entries := guildEntries()
			m := guildManifest(entries)
			rows := m["files"].([]map[string]any)
			switch name {
			case "missing manifest file":
				m["files"] = rows[1:]
			case "extra manifest file":
				m["files"] = append(rows, map[string]any{"path": "WTF/evil", "sha256": strings.Repeat("0", 64), "bytes": 1})
			case "duplicate row":
				rows[1] = rows[0]
			case "hash mismatch":
				rows[1]["sha256"] = strings.Repeat("0", 64)
			case "size mismatch":
				rows[1]["bytes"] = 999
			case "project", "kind", "version":
				m[name] = "wrong"
			case "missing guides":
				for i, e := range entries {
					if strings.HasSuffix(e.name, "/guides.html") {
						entries = append(entries[:i], entries[i+1:]...)
						break
					}
				}
				m = nil
			case "empty guides":
				for i, e := range entries {
					if strings.HasSuffix(e.name, "/guides.html") {
						entries[i].body = ""
					}
				}
				m = nil
			case "Journey identity":
				entries[len(addonFixtureFiles)].body = strings.Replace(entries[len(addonFixtureFiles)].body, "Relax Journey", "Other", 1)
				m = nil
			case "Journey save identity":
				entries[len(addonFixtureFiles)].body = strings.Replace(entries[len(addonFixtureFiles)].body, "Journey_Character", "RenamedSave", 1)
				m = nil
			case "Coach save identity":
				entries[0].body = strings.Replace(entries[0].body, "ForeverCoachDB", "RenamedSave", 1)
				m = nil
			case "unexpected root":
				entries = append(entries, addonZipEntry{"Interface/AddOns/Other/evil.lua", "bad", 0644})
				m = nil
			case "traversal":
				entries = append(entries, addonZipEntry{"Interface/AddOns/Journey/../evil.lua", "bad", 0644})
				m = nil
			case "ADS":
				entries = append(entries, addonZipEntry{"Interface/AddOns/Journey/Main.xml:evil", "bad", 0644})
				m = nil
			case "special":
				entries[1].mode = os.ModeNamedPipe | 0644
				m = nil
			case "symlink":
				entries[1].mode = os.ModeSymlink | 0777
				m = nil
			}
			assertGuildRejected(t, entries, m, "")
		})
	}
}

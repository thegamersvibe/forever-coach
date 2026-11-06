package main

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestAddonRollbackFailureRetainsOriginalBackup(t *testing.T) {
	u := addonPayloadUpdater(t, addonZip(t, addonFixtureEntries("1.5.0")), "")
	game := addonTestGame(t)
	target := filepath.Join(game, "Interface", "AddOns", "ForeverCoach")
	before := addonTreeHashes(t, target)
	backup := ""
	calls := 0
	u.rename = func(from, to string) error {
		calls++
		if calls == 1 {
			backup = to
			return os.Rename(from, to)
		}
		return os.ErrPermission
	}
	result, err := u.apply(context.Background(), game, addonTestInfo())
	if err == nil || !strings.Contains(err.Error(), "rollback failed") || !strings.Contains(err.Error(), backup) {
		t.Fatalf("missing manual recovery information: %+v %v", result, err)
	}
	if backup == "" || !reflect.DeepEqual(before, addonTreeHashes(t, backup)) {
		t.Fatal("original backup was lost")
	}
	if result.Version != "" || result.UpdatedFiles != 0 {
		t.Fatalf("reported failed install as success: %+v", result)
	}
}

func TestAddonBackupLockAndInvalidInstalledVersionFailClosed(t *testing.T) {
	for _, mode := range []string{"backup lock", "invalid version", "same version", "newer installed"} {
		t.Run(mode, func(t *testing.T) {
			u := addonPayloadUpdater(t, addonZip(t, addonFixtureEntries("1.5.0")), "")
			game := addonTestGame(t)
			switch mode {
			case "backup lock":
				addonPut(t, game, "RelaxCoachBackups/.addon-update.lock", "another process")
			case "invalid version":
				addonPut(t, game, "Interface/AddOns/ForeverCoach/ForeverCoach.toc", "## Version: broken\n")
			case "same version":
				addonPut(t, game, "Interface/AddOns/ForeverCoach/ForeverCoach.toc", "## Version: 1.5.0\n")
			case "newer installed":
				addonPut(t, game, "Interface/AddOns/ForeverCoach/ForeverCoach.toc", "## Version: 1.6.0\n")
			}
			before := addonTreeHashes(t, game)
			if _, err := u.apply(context.Background(), game, addonTestInfo()); err == nil {
				t.Fatal("unsafe concurrent/downgrade install allowed")
			}
			if after := addonTreeHashes(t, game); !reflect.DeepEqual(before, after) {
				t.Fatal("refused install changed files")
			}
		})
	}
}

func TestAddonDetectsCorruptZIPMemberAfterAuthenticChecksum(t *testing.T) {
	payload := addonZip(t, addonFixtureEntries("1.5.0"))
	// Corrupt the central-directory CRC (not the complete ZIP hash served by
	// the fixture). This proves extraction checks member integrity too.
	at := bytes.Index(payload, []byte{'P', 'K', 1, 2})
	if at < 0 {
		t.Fatal("fixture has no central directory")
	}
	binary.LittleEndian.PutUint32(payload[at+16:at+20], 0)
	u := addonPayloadUpdater(t, payload, "")
	game := addonTestGame(t)
	before := addonTreeHashes(t, game)
	if _, err := u.apply(context.Background(), game, addonTestInfo()); !errors.Is(err, zip.ErrChecksum) {
		t.Fatalf("bad member CRC not rejected: %v", err)
	}
	if after := addonTreeHashes(t, game); !reflect.DeepEqual(before, after) {
		t.Fatal("corrupt extraction changed game")
	}
}

func TestAddonDownloadCancellationDuringArchiveBody(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "partial")
		w.(http.Flusher).Flush()
		cancel()
		<-r.Context().Done()
	})
	_, err := u.fetch(ctx, testAddonDownload+testAddonAsset, 100, "addon archive")
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("archive body did not honor cancellation: %v", err)
	}
}

func TestAddonCheckMalformedAndBoundedResponses(t *testing.T) {
	for _, mode := range []string{"invalid JSON", "oversized JSON", "duplicate assets", "invalid current", "duplicate checksum"} {
		t.Run(mode, func(t *testing.T) {
			u := addonTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
				switch mode {
				case "invalid JSON":
					fmt.Fprint(w, "not JSON")
				case "oversized JSON":
					fmt.Fprint(w, strings.Repeat(" ", (1<<20)+1))
				case "invalid current":
					t.Error("invalid current version reached network")
				default:
					release := addonTestRelease(testAddonTag)
					assets := release["assets"].([]map[string]any)
					index := 0
					if mode == "duplicate checksum" {
						index = 1
					}
					release["assets"] = append(assets, assets[index])
					json.NewEncoder(w).Encode(release)
				}
			})
			current := "1.4.0"
			if mode == "invalid current" {
				current = "banana"
			}
			if _, err := u.check(context.Background(), current); err == nil {
				t.Fatal("invalid check accepted")
			}
		})
	}
}

func TestAddonStableSemanticVersionPrecedence(t *testing.T) {
	for _, tc := range []struct{ newer, older string }{
		{"1.10.0", "1.9.9"}, {"2.0.0", "1.99.99"}, {"1.4.10", "1.4.9"}, {"v1.4.1+build.1", "1.4.0+build.99"},
	} {
		a, err := parseAddonVersion(tc.newer)
		if err != nil {
			t.Fatal(err)
		}
		b, err := parseAddonVersion(tc.older)
		if err != nil {
			t.Fatal(err)
		}
		if !a.newerThan(b) || b.newerThan(a) || a.newerThan(a) {
			t.Errorf("incorrect semver comparison: %s, %s", tc.newer, tc.older)
		}
	}
	for _, value := range []string{"1.4.0-rc.1", "1.4", "1.4.0.0", " 1.4.0", "1.04.0", "1.4.0+", "1.4.0+build..1", "v1.4.0\n", "1.4.0/evil"} {
		if _, err := parseAddonVersion(value); err == nil {
			t.Errorf("accepted malformed/prerelease version %q", value)
		}
	}
}

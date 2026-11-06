package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAppApplyReadinessAndOriginalBinding(t *testing.T) {
	for _, name := range []string{"success", "worker failed", "cancel", "changed during download", "changed since startup"} {
		t.Run(name, func(t *testing.T) {
			target := filepath.Join(t.TempDir(), "RelaxCoach.exe")
			old := appTestPE()
			old[513] = 1
			candidate := appTestPE()
			candidate[513] = 2
			os.WriteFile(target, old, 0700)
			rt := appRuntimeState{Target: target, SHA: appDigest(old), Version: "1.4.1", PID: os.Getpid(), Started: "start"}
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			if name == "cancel" {
				cancel()
			}
			if name == "changed since startup" {
				os.WriteFile(target, []byte("changed"), 0600)
			}
			u := appTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
				switch {
				case strings.HasSuffix(r.URL.Path, "latest"):
					json.NewEncoder(w).Encode(appTestRelease("v1.5.0"))
				case strings.HasSuffix(r.URL.Path, "SHA256SUMS.txt"):
					fmt.Fprintf(w, "%s  RelaxCoach.exe\n", appDigest(candidate))
				default:
					if name == "changed during download" {
						os.WriteFile(target, []byte("changed"), 0600)
					}
					w.Write(candidate)
				}
			})
			handed := false
			handoff := func(ctx context.Context, tx appTransaction) error {
				handed = true
				assertAppBytes(t, target, old)
				assertAppBytes(t, tx.path("worker.exe"), old)
				assertAppBytes(t, tx.path("candidate.exe"), candidate)
				if name == "worker failed" {
					return errors.New("failed to acquire parent handle")
				}
				return nil
			}
			r := AppReleaseInfo{Version: "1.5.0", Available: true, AssetName: "RelaxCoach.exe", AssetURL: testAddonDownload + "RelaxCoach.exe", ChecksumURL: testAddonDownload + "SHA256SUMS.txt"}
			result, err := u.apply(ctx, r, rt, handoff)
			if name == "success" {
				if err != nil || !result.RestartReady || !handed {
					t.Fatalf("handoff: %+v %v", result, err)
				}
			} else {
				if err == nil || result.RestartReady {
					t.Fatalf("unsafe restart-ready: %+v %v", result, err)
				}
				if name != "worker failed" && handed {
					t.Fatal("invalid apply started worker")
				}
			}
			if !strings.HasPrefix(name, "changed") {
				assertAppBytes(t, target, old)
			}
		})
	}
}

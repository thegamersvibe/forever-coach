package main

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"
)

// A small genuine PE32+ executable layout, not an executable launch fixture.
func appTestPE() []byte {
	b := make([]byte, 1024)
	copy(b, "MZ")
	binary.LittleEndian.PutUint32(b[0x3c:], 128)
	copy(b[128:], "PE\x00\x00")
	binary.LittleEndian.PutUint16(b[132:], 0x8664)
	binary.LittleEndian.PutUint16(b[134:], 1)
	binary.LittleEndian.PutUint16(b[148:], 240)
	binary.LittleEndian.PutUint16(b[150:], 0x22)
	o := b[152:]
	binary.LittleEndian.PutUint16(o, 0x20b)
	binary.LittleEndian.PutUint32(o[16:], 0x1000)
	binary.LittleEndian.PutUint32(o[32:], 0x1000)
	binary.LittleEndian.PutUint32(o[36:], 512)
	binary.LittleEndian.PutUint32(o[56:], 0x2000)
	binary.LittleEndian.PutUint32(o[60:], 512)
	binary.LittleEndian.PutUint16(o[68:], 2)
	binary.LittleEndian.PutUint32(o[108:], 16)
	s := b[392:]
	copy(s, ".text")
	binary.LittleEndian.PutUint32(s[8:], 512)
	binary.LittleEndian.PutUint32(s[12:], 0x1000)
	binary.LittleEndian.PutUint32(s[16:], 512)
	binary.LittleEndian.PutUint32(s[20:], 512)
	binary.LittleEndian.PutUint32(s[36:], 0x60000020)
	b[512] = 0xc3
	return b
}
func TestAppDownloadVerifiesChannelChecksumAndPE(t *testing.T) {
	for _, name := range []string{"valid", "hash mismatch", "duplicate checksum", "wrong filename", "not PE", "x86", "dll", "truncated section", "oversize", "stale", "cancel", "timeout"} {
		t.Run(name, func(t *testing.T) {
			data := appTestPE()
			release := appTestRelease("v1.5.0")
			switch name {
			case "not PE":
				data = []byte("script")
			case "x86":
				binary.LittleEndian.PutUint16(data[132:], 0x14c)
			case "dll":
				binary.LittleEndian.PutUint16(data[150:], 0x2022)
			case "truncated section":
				data = data[:600]
			case "stale":
				release = appTestRelease("v1.6.0")
			}
			sum := fmt.Sprintf("%x  RelaxCoach.exe\n", sha256.Sum256(data))
			switch name {
			case "hash mismatch":
				sum = strings.Repeat("0", 64) + "  RelaxCoach.exe\n"
			case "duplicate checksum":
				sum += sum
			case "wrong filename":
				sum = strings.ReplaceAll(sum, "RelaxCoach.exe", "Other.exe")
			}
			u := appTestUpdater(t, func(w http.ResponseWriter, r *http.Request) {
				if name == "timeout" {
					<-r.Context().Done()
					return
				}
				switch {
				case strings.HasSuffix(r.URL.Path, "/latest"):
					json.NewEncoder(w).Encode(release)
				case strings.HasSuffix(r.URL.Path, "SHA256SUMS.txt"):
					fmt.Fprint(w, sum)
				default:
					if name == "oversize" {
						w.Header().Set("Content-Length", "999999999")
					}
					w.Write(data)
				}
			})
			ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
			defer cancel()
			if name == "cancel" {
				cancel()
			}
			offered := AppReleaseInfo{Version: "1.5.0", Available: true, AssetName: "RelaxCoach.exe", AssetURL: testAddonDownload + "RelaxCoach.exe", ChecksumURL: testAddonDownload + "SHA256SUMS.txt"}
			got, err := u.download(ctx, offered, "1.4.1")
			if name == "valid" {
				if err != nil || sha256.Sum256(got) != sha256.Sum256(data) {
					t.Fatalf("valid executable: %v", err)
				}
			} else if err == nil {
				t.Fatal("unsafe download accepted")
			}
		})
	}
}

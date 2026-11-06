package main

import (
	"encoding/base64"
	"strings"
	"testing"
)

// Windows WebView2 156 reports NavigateToString's NavigationStarting URI as
// a UTF-8/base64 data URI, even though the resulting document is about:blank.
func TestNativeNavigationAcceptsExactRenderedPageURI(t *testing.T) {
	app, _ := nativeTestApp(t)
	html, err := renderNativeShell(app.snapshot(), false, "navigation-test-token")
	if err != nil {
		t.Fatal(err)
	}
	uri := "data:text/html;charset=utf-8;base64," + base64.StdEncoding.EncodeToString([]byte(html))
	gate := newNativeNavigationGate(html)
	if gate.Allow(uri, true) {
		t.Fatal("trusted page was allowed in an iframe")
	}
	if !gate.Allow(uri, false) {
		t.Fatal("WebView2's exact generated-page data URI was blocked: native window would stay blank")
	}
	for _, next := range []string{uri, "about:blank", "https://github.com/" + Repo} {
		if gate.Allow(next, false) {
			t.Fatal("second navigation acquired the privileged view")
		}
	}
}

func TestNativeNavigationRejectsUntrustedDataWithoutConsumingInitialLoad(t *testing.T) {
	html := "<!doctype html><title>Relax Coach</title><p>شاي ☕</p>"
	prefix := "data:text/html;charset=utf-8;base64,"
	uri := prefix + base64.StdEncoding.EncodeToString([]byte(html))
	for _, other := range []string{
		prefix + base64.StdEncoding.EncodeToString([]byte(html+"<script>bad()</script>")),
		"data:text/html,<h1>Relax Coach</h1>",
		strings.Replace(uri, "text/html", "text/javascript", 1),
		uri + "#fragment",
		uri + " ",
		"data:text/html;charset=utf-8;base64,",
	} {
		t.Run(other[:min(len(other), 55)], func(t *testing.T) {
			gate := newNativeNavigationGate(html)
			if gate.Allow(other, false) {
				t.Fatal("untrusted data URI allowed")
			}
			if !gate.Allow(uri, false) {
				t.Fatal("rejected navigation consumed trusted initial load")
			}
		})
	}
}

func TestNativeNavigationKeepsLegacyBlankCompatibility(t *testing.T) {
	gate := newNativeNavigationGate("<html>trusted</html>")
	if !gate.Allow("about:blank", false) {
		t.Fatal("legacy NavigateToString URI blocked")
	}
	if gate.Allow("about:blank", false) {
		t.Fatal("second blank navigation allowed")
	}
}

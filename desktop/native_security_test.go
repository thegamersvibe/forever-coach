package main

import "testing"

func TestNativeNavigationOnlyAllowsInitialEmbeddedDocument(t *testing.T) {
	var gate nativeNavigationGate
	for _, url := range []string{"https://github.com/" + Repo, "file:///C:/", "data:text/html,<script>", "about:blank#other", "javascript:alert(1)"} {
		if gate.Allow(url, false) {
			t.Fatalf("navigation allowed: %s", url)
		}
	}
	if gate.Allow("about:blank", true) {
		t.Fatal("iframe navigation allowed")
	}
	if !gate.Allow("about:blank", false) {
		t.Fatal("initial embedded document denied")
	}
	if gate.Allow("about:blank", false) {
		t.Fatal("second navigation allowed")
	}
	if gate.Allow("https://github.com/"+Repo, false) {
		t.Fatal("remote page acquired privileged view")
	}
}

package main

import "testing"

func TestAppPrivateACLRejectsExtraGrantsButAllowsControlMetadata(t *testing.T) {
	want := "O:S-1-5-21-123D:P(A;OICI;FA;;;S-1-5-21-123)"
	for _, tc := range []struct {
		actual, owner   string
		protected, want bool
	}{
		{want, "S-1-5-21-123", true, true},
		{"O:S-1-5-21-123D:PAI(A;OICI;FA;;;S-1-5-21-123)", "S-1-5-21-123", true, true},
		{want + "(A;OICI;FA;;;WD)", "S-1-5-21-123", true, false},
		{want, "S-1-5-21-456", true, false},
		{want, "S-1-5-21-123", false, false},
		{"D:P", "S-1-5-21-123", true, false},
	} {
		if got := appPrivateACLMatches(tc.actual, want, tc.owner, "S-1-5-21-123", tc.protected); got != tc.want {
			t.Fatalf("ACL %q: %v want %v", tc.actual, got, tc.want)
		}
	}
}

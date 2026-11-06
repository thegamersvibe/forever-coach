package main

import "strings"

// Compare canonical ACEs and owner, not the OS-added auto-inheritance metadata.
// The DACL must still be protected, with exactly the single expected user grant.
func appPrivateACLMatches(actual, want, owner, wantOwner string, protected bool) bool {
	a, w := strings.IndexByte(actual, '('), strings.IndexByte(want, '(')
	return protected && owner != "" && owner == wantOwner && a >= 0 && w >= 0 && actual[a:] == want[w:]
}

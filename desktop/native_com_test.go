package main

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// Exercise the actual Windows wrapper with a stack-growing Go ABI shim in place
// of SyscallN. This is pointer-lifetime regression coverage, not a Windows GUI test.
func TestNativeCOMCallPreservesOutputAcrossStackGrowth(t *testing.T) {
	source, err := os.ReadFile("native_windows.go")
	if err != nil {
		t.Fatal(err)
	}
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, "native_windows.go", source, parser.ParseComments)
	if err != nil {
		t.Fatal(err)
	}
	var wrapper string
	for _, decl := range file.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok || fn.Name.Name != "call" || fn.Recv == nil {
			continue
		}
		start := fn.Pos()
		if fn.Doc != nil {
			start = fn.Doc.Pos() // Preserve compiler directives on the production method.
		}
		wrapper = string(source[fset.Position(start).Offset:fset.Position(fn.End()).Offset])
	}
	if strings.Count(wrapper, "syscall.SyscallN") != 1 {
		t.Fatal("could not extract the production COM wrapper")
	}
	wrapper = strings.Replace(wrapper, "syscall.SyscallN", "syscallN", 1)
	probe := `package main
import ("fmt"; "os"; "runtime"; "unsafe")
type nativeCOM struct { VTable *[128]uintptr }
` + wrapper + `
//go:noinline
func grow(depth int) {
    var padding [1024]byte
    padding[0] = byte(depth)
    if depth > 0 { grow(depth - 1) }
    runtime.KeepAlive(&padding)
}
//go:uintptrescapes
func syscallN(_ uintptr, args ...uintptr) (uintptr, uintptr, uintptr) {
    grow(128)
    *(*uintptr)(unsafe.Pointer(args[1])) = 0x12345678
    return 0, 0, 0
}
//go:noinline
func probe(c *nativeCOM) uintptr {
    var result uintptr
    _, _ = c.call(3, uintptr(unsafe.Pointer(&result)))
    return result
}
func main() {
    c := &nativeCOM{VTable: new([128]uintptr)}
    results := make(chan uintptr)
    go func() { results <- probe(c) }()
    result := <-results
    fmt.Printf("nativeCOM.call ABI shim output=0x%x expected=0x12345678\n", result)
    if result != 0x12345678 { os.Exit(1) }
}
`
	path := filepath.Join(t.TempDir(), "probe.go")
	if err := os.WriteFile(path, []byte(probe), 0600); err != nil {
		t.Fatal(err)
	}
	output, err := exec.Command("go", "run", path).CombinedOutput()
	if err != nil {
		t.Fatalf("production COM wrapper lost the output pointer across stack growth: %v\n%s", err, output)
	}
	t.Log(strings.TrimSpace(string(output)))
}

//go:build windows

package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

func TestAppWindowsVisibilityChildFixture(t *testing.T) {
	if os.Getenv("RELAX_TEST_VISIBILITY_CHILD") != "1" {
		return
	}
	var startup windows.StartupInfo
	// GetStartupInfoW returns void; do not interpret a syscall return register.
	appKernel.NewProc("GetStartupInfoW").Call(uintptr(unsafe.Pointer(&startup)))
	if startup.Flags&windows.STARTF_USESHOWWINDOW != 0 && startup.ShowWindow == windows.SW_HIDE {
		t.Fatal("owned GUI child was launched with SW_HIDE")
	}
	fmt.Println("GUI_STARTUP_VISIBLE")
}

func TestAppWindowsOwnedLaunchDoesNotHideNativeGUI(t *testing.T) {
	cmd := exec.Command(os.Args[0], "-test.run=^TestAppWindowsVisibilityChildFixture$")
	cmd.Env = append(os.Environ(), "RELAX_TEST_VISIBILITY_CHILD=1")
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	p, err := appStartOwned(cmd)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = p.stop() })
	select {
	case <-p.done:
		if !cmd.ProcessState.Success() || !strings.Contains(output.String(), "GUI_STARTUP_VISIBLE") {
			t.Fatalf("child startup visibility failed: %s", output.String())
		}
	case <-time.After(5 * time.Second):
		t.Fatal("visibility fixture did not finish")
	}
}

func TestAppWindowsHealthChildFixture(t *testing.T) {
	dir := os.Getenv("RELAX_TEST_HEALTH_TX")
	if dir == "" {
		return
	}
	tx, err := readAppTransaction(dir)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err = appPlatformReady(ctx, tx); err != nil {
		t.Fatal(err)
	}
	time.Sleep(time.Minute)
}
func TestAppWindowsHealthRoundTripKeepsOwnedChildLive(t *testing.T) {
	tx, _, _ := appFixture(t)
	if err := appMoveNew(tx.Target, tx.path("backup.exe")); err != nil {
		t.Fatal(err)
	}
	if err := appMoveNew(tx.path("candidate.exe"), tx.Target); err != nil {
		t.Fatal(err)
	}
	pipe, err := appListenPipe(tx.ID + "-health")
	if err != nil {
		t.Fatal(err)
	}
	defer pipe.close()
	cmd := exec.Command(os.Args[0], "-test.run=^TestAppWindowsHealthChildFixture$")
	cmd.Env = append(os.Environ(), "RELAX_TEST_HEALTH_TX="+filepath.Dir(tx.path("transaction.json")))
	p, err := appStartOwned(cmd)
	if err != nil {
		t.Fatal(err)
	}
	defer p.stop()
	child := &appWindowsChild{p, pipe}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err = child.Healthy(ctx, tx); err != nil {
		t.Fatal(err)
	}
	time.Sleep(100 * time.Millisecond)
	if !p.live() {
		t.Fatal("health client failed after its acknowledgement")
	}
}

func TestAppWindowsPipeBindsActualClient(t *testing.T) {
	for _, wrong := range []bool{false, true} {
		id, _ := nativeToken()
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		server, err := appListenPipe(id)
		if err != nil {
			cancel()
			t.Fatal(err)
		}
		done := make(chan error, 1)
		go func() {
			client, e := appDialPipe(ctx, id, os.Getpid())
			if e == nil {
				defer client.close()
				e = client.write(ctx, "native-health")
			}
			done <- e
		}()
		pid := os.Getpid()
		if wrong {
			pid++
		}
		err = server.accept(ctx, pid)
		if wrong {
			if err == nil {
				t.Error("wrong client PID accepted")
			}
		} else {
			if err != nil {
				t.Fatal(err)
			}
			msg, e := server.read(ctx)
			if e != nil || msg != "native-health" {
				t.Fatalf("pipe message: %q %v", msg, e)
			}
		}
		server.close()
		cancel()
		<-done
	}
}
func TestAppWindowsOwnedChildFixture(t *testing.T) {
	if os.Getenv("RELAX_TEST_CHILD") != "1" {
		return
	}
	time.Sleep(time.Minute)
}
func TestAppWindowsStopsOnlyOwnedProcess(t *testing.T) {
	create := func() *appOwnedProcess {
		cmd := exec.Command(os.Args[0], "-test.run=^TestAppWindowsOwnedChildFixture$")
		cmd.Env = append(os.Environ(), "RELAX_TEST_CHILD=1")
		p, err := appStartOwned(cmd)
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = p.stop() })
		return p
	}
	a, b := create(), create()
	if err := a.stop(); err != nil {
		t.Fatal(err)
	}
	select {
	case <-a.done:
	default:
		t.Error("owned child not reaped")
	}
	select {
	case <-b.done:
		t.Error("unrelated child stopped")
	default:
	}
}
func TestAppWindowsParentIdentityAndJunctions(t *testing.T) {
	started, err := appPlatformIdentity()
	if err != nil || started == "" {
		t.Fatalf("identity: %s %v", started, err)
	}
	dir := t.TempDir()
	real := filepath.Join(dir, "real")
	linked := filepath.Join(dir, "linked")
	os.Mkdir(real, 0700)
	cmd := exec.Command(filepath.Join(os.Getenv("SystemRoot"), "System32", "cmd.exe"), "/d", "/c", "mklink", "/J", linked, real)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("junction fixture: %v %s", err, output)
	}
	defer os.Remove(linked)
	if err := appPlainDirectory(linked); err == nil {
		t.Fatal("junction accepted")
	}
}

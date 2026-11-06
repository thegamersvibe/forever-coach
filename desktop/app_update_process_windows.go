//go:build windows

package main

// The only IPC is a bounded, owner-only local named pipe. Its peers are checked
// with GetNamedPipe{Client,Server}ProcessId while owned process handles stay live.
// No port, shell, downloaded worker, PID-based termination or elevation is used.
import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

var appKernel = windows.NewLazySystemDLL("kernel32.dll")

//go:uintptrescapes
func appWinBool(proc string, args ...uintptr) error {
	r, _, e := syscall.SyscallN(appKernel.NewProc(proc).Addr(), args...)
	if r == 0 {
		if e != 0 {
			return e
		}
		return errors.New(proc + " failed")
	}
	return nil
}
func appPause(ctx context.Context) error {
	timer := time.NewTimer(20 * time.Millisecond)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}
func appProcessIdentity(h windows.Handle) (string, string, error) {
	var created, exited, kernel, user windows.Filetime
	if err := windows.GetProcessTimes(h, &created, &exited, &kernel, &user); err != nil {
		return "", "", err
	}
	var buf [32768]uint16
	n := uint32(len(buf))
	if err := appWinBool("QueryFullProcessImageNameW", uintptr(h), 0, uintptr(unsafe.Pointer(&buf[0])), uintptr(unsafe.Pointer(&n))); err != nil {
		return "", "", err
	}
	return windows.UTF16ToString(buf[:n]), fmt.Sprintf("%08x%08x", created.HighDateTime, created.LowDateTime), nil
}
func appPlatformIdentity() (string, error) {
	_, stamp, err := appProcessIdentity(windows.CurrentProcess())
	return stamp, err
}
func appWaitProcess(ctx context.Context, h windows.Handle) error {
	for {
		state, err := windows.WaitForSingleObject(h, 0)
		if err != nil {
			return err
		}
		if state == windows.WAIT_OBJECT_0 {
			return nil
		}
		if state != uint32(windows.WAIT_TIMEOUT) {
			return errors.New("unexpected parent wait state")
		}
		if err = appPause(ctx); err != nil {
			return err
		}
	}
}

type appPipe struct{ h windows.Handle }

func appPipeName(id string) string { return `\\.\pipe\RelaxCoach-update-` + id }
func appListenPipe(id string) (*appPipe, error) {
	name, err := windows.UTF16PtrFromString(appPipeName(id))
	if err != nil {
		return nil, err
	}
	sd, err := appPrivateSecurity(false)
	if err != nil {
		return nil, err
	}
	sa := windows.SecurityAttributes{Length: uint32(unsafe.Sizeof(windows.SecurityAttributes{})), SecurityDescriptor: sd}
	// Duplex, first instance, message mode, nonblocking, local clients only.
	h, _, e := appKernel.NewProc("CreateNamedPipeW").Call(uintptr(unsafe.Pointer(name)), 3|windows.FILE_FLAG_FIRST_PIPE_INSTANCE, 0x4|0x2|0x1|0x8, 1, 4096, 4096, 0, uintptr(unsafe.Pointer(&sa)))
	runtime.KeepAlive(sd)
	if windows.Handle(h) == windows.InvalidHandle {
		return nil, e
	}
	p := &appPipe{windows.Handle(h)}
	// Nonblocking ConnectNamedPipe puts this instance into the listening state.
	err = appWinBool("ConnectNamedPipe", h, 0)
	if err != nil && err != windows.ERROR_PIPE_LISTENING && err != windows.ERROR_PIPE_CONNECTED {
		p.close()
		return nil, err
	}
	return p, nil
}
func (p *appPipe) close() {
	if p != nil && p.h != 0 {
		windows.CloseHandle(p.h)
		p.h = 0
	}
}
func (p *appPipe) peer(server bool) (int, error) {
	name := "GetNamedPipeClientProcessId"
	if server {
		name = "GetNamedPipeServerProcessId"
	}
	var pid uint32
	err := appWinBool(name, uintptr(p.h), uintptr(unsafe.Pointer(&pid)))
	return int(pid), err
}
func (p *appPipe) accept(ctx context.Context, want int) error {
	for {
		pid, err := p.peer(false)
		if err == nil && pid != 0 {
			if pid != want {
				return errors.New("app update pipe client is not the owned process")
			}
			return nil
		}
		if err = appPause(ctx); err != nil {
			return err
		}
	}
}
func appDialPipe(ctx context.Context, id string, wantServer int) (*appPipe, error) {
	name, err := windows.UTF16PtrFromString(appPipeName(id))
	if err != nil {
		return nil, err
	}
	for {
		h, e := windows.CreateFile(name, windows.GENERIC_READ|windows.GENERIC_WRITE, 0, nil, windows.OPEN_EXISTING, 0, 0)
		if e == nil {
			p := &appPipe{h}
			pid, e := p.peer(true)
			if e != nil || pid != wantServer {
				p.close()
				return nil, errors.New("app update pipe server is not the owned worker")
			}
			mode := uint32(0x2 | 0x1)
			if e = appWinBool("SetNamedPipeHandleState", uintptr(h), uintptr(unsafe.Pointer(&mode)), 0, 0); e != nil {
				p.close()
				return nil, e
			}
			return p, nil
		}
		if e != windows.ERROR_FILE_NOT_FOUND && e != windows.ERROR_PIPE_BUSY {
			return nil, e
		}
		if err = appPause(ctx); err != nil {
			return nil, err
		}
	}
}
func (p *appPipe) read(ctx context.Context) (string, error) {
	var buf [4096]byte
	for {
		if err := ctx.Err(); err != nil {
			return "", err
		}
		var n uint32
		err := windows.ReadFile(p.h, buf[:], &n, nil)
		if err == nil && n > 0 {
			return string(buf[:n]), nil
		}
		if err != nil && err != windows.ERROR_NO_DATA && err != windows.ERROR_PIPE_LISTENING {
			return "", err
		}
		if err = appPause(ctx); err != nil {
			return "", err
		}
	}
}
func (p *appPipe) write(ctx context.Context, msg string) error {
	if len(msg) == 0 || len(msg) > 4096 {
		return errors.New("invalid app update pipe message length")
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	var n uint32
	err := windows.WriteFile(p.h, []byte(msg), &n, nil)
	if err != nil {
		return err
	}
	if int(n) != len(msg) {
		return errors.New("incomplete app update pipe message")
	}
	return nil
}

type appOwnedProcess struct {
	cmd  *exec.Cmd
	done chan struct{}
}

func appStartOwned(cmd *exec.Cmd) (*appOwnedProcess, error) {
	// All production children use the GUI-subsystem app executable. Do not set
	// HideWindow: STARTF_USESHOWWINDOW/SW_HIDE overrides the relaunched app's
	// first ShowWindow call, preventing visible native startup and rollback UI.
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	p := &appOwnedProcess{cmd: cmd, done: make(chan struct{})}
	go func() { _ = cmd.Wait(); close(p.done) }()
	return p, nil
}
func (p *appOwnedProcess) live() bool {
	select {
	case <-p.done:
		return false
	default:
		return true
	}
}
func (p *appOwnedProcess) stop() error {
	if !p.live() {
		return nil
	}
	// Go's Windows os.Process.Kill duplicates the retained process HANDLE; it
	// never opens a process by PID. Wait owns and reaps this exact child as well.
	if err := p.cmd.Process.Kill(); err != nil && p.live() {
		return err
	}
	select {
	case <-p.done:
		return nil
	case <-time.After(10 * time.Second):
		return errors.New("owned update process did not exit")
	}
}

func appPlatformHandoff(ctx context.Context, t appTransaction) (err error) {
	if err = t.verifyInitial(); err != nil {
		return err
	}
	p, err := appStartOwned(exec.Command(t.path("worker.exe"), "-app-update-worker", t.ID))
	if err != nil {
		return err
	}
	handed := false
	defer func() {
		if !handed {
			if stopErr := p.stop(); stopErr != nil {
				err = fmt.Errorf("%w; cannot stop unready owned worker: %v", err, stopErr)
			}
		}
	}()
	readyCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	pipe, err := appDialPipe(readyCtx, t.ID, p.cmd.Process.Pid)
	if err != nil {
		return err
	}
	defer pipe.close()
	msg, err := pipe.read(readyCtx)
	if err != nil {
		return err
	}
	if !p.live() || msg != "ready "+t.fingerprint() {
		return errors.New("worker did not validate the original transaction and parent")
	}
	if err = t.verifyInitial(); err != nil {
		return err
	}
	if err = pipe.write(readyCtx, "arm "+t.fingerprint()); err != nil {
		return err
	}
	msg, err = pipe.read(readyCtx)
	if err != nil {
		return err
	}
	if msg != "armed "+t.fingerprint() || !p.live() {
		return errors.New("worker did not acknowledge restart readiness")
	}
	if err = readyCtx.Err(); err != nil {
		return err
	}
	handed = true
	return nil
}
func appPlatformWorker(id string) error {
	self, err := os.Executable()
	if err != nil {
		return err
	}
	t, err := readAppTransaction(filepath.Dir(self))
	if err != nil {
		return err
	}
	if id != t.ID || !strings.EqualFold(self, t.path("worker.exe")) || Version != t.OldVersion {
		return errors.New("worker executable or version does not match the transaction")
	}
	if err = t.verifyInitial(); err != nil {
		return err
	}
	pipe, err := appListenPipe(id)
	if err != nil {
		return err
	}
	defer pipe.close()
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err = pipe.accept(ctx, t.ParentPID); err != nil {
		return err
	}
	if os.Getppid() != t.ParentPID {
		return errors.New("update worker was not launched by its declared parent")
	}
	parent, err := windows.OpenProcess(windows.SYNCHRONIZE|windows.PROCESS_QUERY_LIMITED_INFORMATION, false, uint32(t.ParentPID))
	if err != nil {
		return err
	}
	defer windows.CloseHandle(parent)
	path, stamp, err := appProcessIdentity(parent)
	if err != nil {
		return err
	}
	if !strings.EqualFold(path, t.Target) || stamp != t.ParentStarted {
		return errors.New("actual parent handle does not match the original executable and creation time")
	}
	if err = t.verifyInitial(); err != nil {
		return err
	}
	if err = pipe.write(ctx, "ready "+t.fingerprint()); err != nil {
		return err
	}
	msg, err := pipe.read(ctx)
	if err != nil {
		return err
	}
	if msg != "arm "+t.fingerprint() {
		return errors.New("parent did not authorize this transaction")
	}
	if err = t.verifyInitial(); err != nil {
		return err
	}
	if err = pipe.write(ctx, "armed "+t.fingerprint()); err != nil {
		return err
	}
	// After this point the parent's normal UI-thread close is expected. The
	// worker outlives it; network/RPC cancellation cannot interrupt rollback.
	workCtx, workCancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer workCancel()
	return runAppTransaction(workCtx, t, appWorkerOps{
		waitParent: func(ctx context.Context) error {
			wait, cancel := context.WithTimeout(ctx, 60*time.Second)
			defer cancel()
			return appWaitProcess(wait, parent)
		},
		start: appStartCandidate, move: appMoveNew,
	})
}

type appWindowsChild struct {
	process *appOwnedProcess
	pipe    *appPipe
}

func appStartCandidate(target string, args []string, id string) (appChild, error) {
	var pipe *appPipe
	var err error
	if id != "" {
		pipe, err = appListenPipe(id + "-health")
		if err != nil {
			return nil, err
		}
		args = append([]string{"-app-update-start", id}, args...)
	}
	p, err := appStartOwned(exec.Command(target, args...))
	if err != nil {
		pipe.close()
		return nil, err
	}
	return &appWindowsChild{p, pipe}, nil
}
func (c *appWindowsChild) Stop() error { c.pipe.close(); return c.process.stop() }
func (c *appWindowsChild) Healthy(ctx context.Context, t appTransaction) error {
	defer c.pipe.close()
	if c.pipe == nil {
		return errors.New("no startup health channel")
	}
	if err := c.pipe.accept(ctx, c.process.cmd.Process.Pid); err != nil {
		return err
	}
	msg, err := c.pipe.read(ctx)
	if err != nil {
		return err
	}
	if err = validateAppHealth(t, msg, c.process.cmd.Process.Pid, c.process.live()); err != nil {
		return err
	}
	if err = t.verifySwap(t.NewSHA, true, false); err != nil {
		return err
	}
	if err = c.pipe.write(ctx, "accepted "+t.fingerprint()); err != nil {
		return err
	}
	// Do not close the server while its reply is still buffered/unread.
	receipt, err := c.pipe.read(ctx)
	if err != nil {
		return err
	}
	if receipt != "received "+t.fingerprint() || !c.process.live() {
		return errors.New("startup health receipt missing")
	}
	return nil
}
func appPlatformReady(ctx context.Context, t appTransaction) error {
	pipe, err := appDialPipe(ctx, t.ID+"-health", os.Getppid())
	if err != nil {
		return err
	}
	defer pipe.close()
	if err = pipe.write(ctx, appHealthMessage(t, os.Getpid())); err != nil {
		return err
	}
	msg, err := pipe.read(ctx)
	if err != nil {
		return err
	}
	if msg != "accepted "+t.fingerprint() {
		return errors.New("startup acknowledgement was not accepted by the worker")
	}
	if err = pipe.write(ctx, "received "+t.fingerprint()); err != nil {
		return err
	}
	// Retain the client endpoint until the worker has consumed the receipt and
	// closed its endpoint. All waits remain bounded by the startup context.
	_, err = pipe.read(ctx)
	if errors.Is(err, windows.ERROR_BROKEN_PIPE) || errors.Is(err, windows.ERROR_PIPE_NOT_CONNECTED) {
		return nil
	}
	if err == nil {
		return errors.New("unexpected trailing startup health message")
	}
	return err
}

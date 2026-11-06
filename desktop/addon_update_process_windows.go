//go:build windows

package main

import (
	"bytes"
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
)

type addonProcessOutput struct{ bytes.Buffer }

func (b *addonProcessOutput) Write(p []byte) (int, error) {
	if b.Len()+len(p) > 4<<20 {
		return 0, errors.New("tasklist output exceeded the safety limit")
	}
	return b.Buffer.Write(p)
}

func addonGameRunning(ctx context.Context) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	system := os.Getenv("SystemRoot")
	if !filepath.IsAbs(system) {
		return false, errors.New("Windows SystemRoot is unavailable")
	}
	// An absolute System32 path avoids executing tasklist.exe from the game
	// directory or a downloaded archive. No shell or downloaded code is run.
	cmd := exec.CommandContext(ctx, filepath.Join(system, "System32", "tasklist.exe"), "/FO", "CSV", "/NH")
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	cmd.WaitDelay = time.Second
	var output addonProcessOutput
	cmd.Stdout = &output
	if err := cmd.Run(); err != nil {
		return false, err
	}
	if err := ctx.Err(); err != nil {
		return false, err
	}
	return addonTasklistRunning(output.Bytes())
}

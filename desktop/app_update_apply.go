package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"
)

type AppUpdateResult struct {
	Version      string `json:"version"`
	Message      string `json:"message"`
	RestartReady bool   `json:"restartReady"`
}
type appRuntimeState struct {
	Target, SHA, Version, Started string
	PID                           int
	Args                          []string
}

// Set once on the main thread before the window and all RPC work are created.
var appRuntime *appRuntimeState
var appRuntimeError error
var appApplyMutex sync.Mutex

func initAppUpdateRuntime(args []string) {
	rt := appRuntimeState{Version: Version, PID: os.Getpid()}
	var err error
	rt.Args, err = appGUIArgs(args)
	if err == nil {
		rt.Target, err = os.Executable()
	}
	if err == nil {
		var data []byte
		data, err = appReadFile(rt.Target, appMaxExecutable)
		rt.SHA = appDigest(data)
	}
	if err == nil {
		rt.Started, err = appPlatformIdentity()
	}
	if err != nil {
		appRuntimeError = err
		return
	}
	appRuntime = &rt
}
func currentAppUpdateStatus() string {
	target, err := os.Executable()
	if err != nil {
		return ""
	}
	return appLastResult(target)
}
func ApplyAppRelease(ctx context.Context, r AppReleaseInfo) (AppUpdateResult, error) {
	if appRuntime == nil {
		return AppUpdateResult{}, fmt.Errorf("app self-update unavailable: %v", appRuntimeError)
	}
	return newAppUpdater().apply(ctx, r, *appRuntime, appPlatformHandoff)
}
func (u *appUpdater) apply(ctx context.Context, r AppReleaseInfo, rt appRuntimeState, handoff func(context.Context, appTransaction) error) (AppUpdateResult, error) {
	var result AppUpdateResult
	if !appApplyMutex.TryLock() {
		return result, errors.New("another app update is already running")
	}
	defer appApplyMutex.Unlock()
	if err := ctx.Err(); err != nil {
		return result, err
	}
	if err := validateAppRelease(r, rt.Version); err != nil {
		return result, err
	}
	if err := appVerify(rt.Target, rt.SHA); err != nil {
		return result, err
	}
	data, err := u.download(ctx, r, rt.Version)
	if err != nil {
		return result, err
	}
	if err = ctx.Err(); err != nil {
		return result, err
	}
	if err = appVerify(rt.Target, rt.SHA); err != nil {
		return result, err
	}
	tx, err := prepareAppTransaction(rt.Target, rt.Version, r.Version, data, rt.Args, rt.PID, rt.Started)
	if err != nil {
		return result, err
	}
	if tx.OldSHA != rt.SHA {
		_ = tx.unlock()
		return result, errors.New("running executable changed before staging")
	}
	if err = ctx.Err(); err == nil {
		err = handoff(ctx, tx)
	}
	if err != nil {
		_ = tx.status("failed", "App update could not hand off to its trusted worker. The original app was not replaced.")
		_ = tx.unlock()
		return result, err
	}
	// Handoff returns only after a verified worker acquired the actual parent
	// handle, validated the immutable transaction and acknowledged it is armed.
	return AppUpdateResult{r.Version, "Verified update ready. Relax Coach is restarting…", true}, nil
}

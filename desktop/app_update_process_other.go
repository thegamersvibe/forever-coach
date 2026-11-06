//go:build !windows

package main

import (
	"context"
	"errors"
)

func appPlatformIdentity() (string, error) { return "", errors.New("app self-update requires Windows") }
func appPlatformHandoff(context.Context, appTransaction) error {
	return errors.New("app self-update requires Windows")
}
func appPlatformWorker(string) error { return errors.New("app update worker requires Windows") }
func appPlatformReady(context.Context, appTransaction) error {
	return errors.New("native startup health requires Windows")
}

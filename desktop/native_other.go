//go:build !windows

package main

import "fmt"

func runNative(_ *App, _ bool) error {
	return fmt.Errorf("the Relax Coach application window requires Windows and Microsoft WebView2; use -once or -headless for diagnostics")
}

func showNativeError(_ error) {}

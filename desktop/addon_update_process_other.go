//go:build !windows

package main

import (
	"context"
	"errors"
)

func addonGameRunning(ctx context.Context) (bool, error) {
	if err := ctx.Err(); err != nil {
		return false, err
	}
	return false, errors.New("automatic addon installation requires Windows process detection; reports remain usable offline")
}

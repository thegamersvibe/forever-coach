package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

type appWritableFile interface {
	Write([]byte) (int, error)
	Sync() error
	Close() error
	Stat() (os.FileInfo, error)
}

// appWriteOwned retains an exclusively created file only if the write and its
// optional publication finish. Cleanup is bound to the created file's identity,
// not merely its name or contents.
func appWriteOwned(path string, data []byte, publish func() error) error {
	return appWriteOwnedWith(path, data, publish, func(path string) (appWritableFile, error) {
		return os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0700)
	})
}

// The opener is an internal test seam; production always uses exclusive creation.
func appWriteOwnedWith(path string, data []byte, publish func() error, open func(string) (appWritableFile, error)) (err error) {
	if err = appPlainDirectory(filepath.Dir(path)); err != nil {
		return err
	}
	f, err := open(path)
	if err != nil {
		return err
	}
	var owned os.FileInfo
	closed, keep := false, false
	defer func() {
		if !closed {
			err = errors.Join(err, f.Close())
		}
		if !keep && owned != nil {
			if cleanupErr := appRemoveOwned(path, owned); cleanupErr != nil {
				err = errors.Join(err, fmt.Errorf("remove incomplete app update file: %w", cleanupErr))
			}
		}
	}()
	owned, err = f.Stat()
	if err != nil {
		return err
	}
	n, err := f.Write(data)
	if err == nil && n != len(data) {
		err = io.ErrShortWrite
	}
	if err == nil {
		err = f.Sync()
	}
	err = errors.Join(err, f.Close())
	closed = true
	if err != nil {
		return err
	}
	if publish != nil {
		if err = publish(); err != nil {
			return err
		}
	}
	keep = true
	return nil
}

func appRemoveOwned(path string, owned os.FileInfo) error {
	if err := appPlainDirectory(filepath.Dir(path)); err != nil {
		return err
	}
	now, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if !now.Mode().IsRegular() || !os.SameFile(owned, now) {
		return errors.New("app update file ownership changed")
	}
	return os.Remove(path)
}

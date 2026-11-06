package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
)

// Read/modify/write is serialized across the game and account preferences.
// RawMessage keeps fields owned by other versions of the application intact.
var configMu sync.Mutex

func installationKey(game string) string {
	p, err := filepath.Abs(game)
	if err != nil {
		p = filepath.Clean(game)
	}
	if resolved, err := filepath.EvalSymlinks(p); err == nil {
		p = resolved
	}
	if runtime.GOOS == "windows" {
		p = strings.ToLower(p)
	}
	return p
}

func readCoachConfig() (map[string]json.RawMessage, error) {
	p := configPath()
	if p == "" {
		return nil, errors.New("configuration directory is unavailable")
	}
	data, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]json.RawMessage{}, nil
	}
	if err != nil {
		return nil, err
	}
	var c map[string]json.RawMessage
	if err := json.Unmarshal(data, &c); err != nil {
		return nil, err
	}
	if c == nil {
		return nil, errors.New("configuration must be a JSON object")
	}
	return c, nil
}

func writeCoachConfig(change func(map[string]json.RawMessage) error) error {
	configMu.Lock()
	defer configMu.Unlock()
	c, err := readCoachConfig()
	if err != nil {
		return err
	}
	if err := change(c); err != nil {
		return err
	}
	data, err := json.Marshal(c)
	if err != nil {
		return err
	}
	p := configPath()
	if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(p), ".config-*")
	if err != nil {
		return err
	}
	temp := f.Name()
	defer os.Remove(temp)
	if _, err = f.Write(data); err != nil {
		f.Close()
		return err
	}
	if err = f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	// Write and sync the complete temporary document before replacing the old file.
	// Rename atomicity is platform-dependent; replacement failures reach the caller.
	return os.Rename(temp, p)
}

func savedAccount(game string) (string, error) {
	if game == "" {
		return "", nil
	}
	configMu.Lock()
	defer configMu.Unlock()
	c, err := readCoachConfig()
	if err != nil {
		return "", err
	}
	if len(c["accounts"]) == 0 {
		return "", nil
	}
	var accounts map[string]json.RawMessage
	if err := json.Unmarshal(c["accounts"], &accounts); err != nil {
		return "", err
	}
	var id string
	if raw := accounts[installationKey(game)]; len(raw) != 0 {
		if err := json.Unmarshal(raw, &id); err != nil {
			return "", err
		}
	}
	if id != "" && !validAccountID(id) {
		return "", errors.New("remembered account identity is invalid; choose an available account")
	}
	return id, nil
}

func saveAccount(game, id string) error {
	err := writeCoachConfig(func(c map[string]json.RawMessage) error {
		accounts := map[string]json.RawMessage{}
		if raw := c["accounts"]; len(raw) != 0 {
			if err := json.Unmarshal(raw, &accounts); err != nil {
				return err
			}
			if accounts == nil {
				accounts = map[string]json.RawMessage{}
			}
		}
		accounts[installationKey(game)], _ = json.Marshal(id)
		c["accounts"], _ = json.Marshal(accounts)
		return nil
	})
	if err != nil {
		return fmt.Errorf("could not remember the account selection: %w", err)
	}
	return nil
}

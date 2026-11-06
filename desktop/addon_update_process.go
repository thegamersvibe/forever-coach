package main

import (
	"bytes"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
)

// /FO CSV /NH has five columns independent of display localization. Malformed,
// empty or diagnostic output is NOT evidence that the game is stopped.
func addonTasklistRunning(output []byte) (bool, error) {
	r := csv.NewReader(bytes.NewReader(output))
	r.FieldsPerRecord = 5
	rows, running := 0, false
	for {
		row, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return false, fmt.Errorf("invalid tasklist CSV: %w", err)
		}
		if row[0] == "" {
			return false, errors.New("tasklist returned an empty process name")
		}
		if _, err := strconv.ParseUint(row[1], 10, 32); err != nil {
			return false, errors.New("tasklist returned an invalid process ID")
		}
		rows++
		name := strings.ToLower(row[0])
		// Includes Wow.exe, Wow-64.exe, WowClassic.exe and test/Forever
		// variants. A standalone voice proxy does not keep the game open.
		if strings.HasPrefix(name, "wow") && strings.HasSuffix(name, ".exe") && name != "wowvoiceproxy.exe" && name != "wowvoiceproxy-64.exe" {
			running = true
		}
	}
	if rows == 0 {
		return false, errors.New("tasklist returned no process records")
	}
	return running, nil
}

package main

import (
	"context"
	"encoding/json"
	"fmt"
)

// App offers are independent of addon versions and never sent to JavaScript.
type AppReleaseInfo AddonReleaseInfo

type appUpdater struct{ transport *addonUpdater }

func newAppUpdater() *appUpdater { return &appUpdater{transport: newAddonUpdater()} }
func CheckAppRelease(ctx context.Context, current string) (AppReleaseInfo, error) {
	return newAppUpdater().check(ctx, current)
}
func (u *appUpdater) check(ctx context.Context, current string) (AppReleaseInfo, error) {
	var info AppReleaseInfo
	local, err := parseAddonVersion(current)
	if err != nil {
		return info, fmt.Errorf("invalid installed app version: %w", err)
	}
	body, err := u.transport.fetch(ctx, addonLatestURL, 1<<20, "app release information")
	if err != nil {
		return info, err
	}
	var r struct {
		Tag        string `json:"tag_name"`
		Name       string `json:"name"`
		Body       string `json:"body"`
		Draft      bool   `json:"draft"`
		Prerelease bool   `json:"prerelease"`
		Assets     []struct {
			Name string `json:"name"`
			URL  string `json:"browser_download_url"`
		} `json:"assets"`
	}
	if err = json.Unmarshal(body, &r); err != nil {
		return info, err
	}
	info.Name, info.Notes = r.Name, r.Body
	v, err := parseAddonVersion(r.Tag)
	if err != nil || r.Draft || r.Prerelease {
		return appNoUpdate(info, "The public release is not stable."), nil
	}
	info.Version = v.text
	info.HTMLURL = addonReleasePrefix + "tag/" + r.Tag
	if !v.newerThan(local) {
		return appNoUpdate(info, "The installed app will not be reinstalled or downgraded."), nil
	}
	seen := map[string]bool{}
	for _, a := range r.Assets {
		if a.Name != "RelaxCoach.exe" && a.Name != "SHA256SUMS.txt" {
			continue
		}
		if seen[a.Name] {
			return AppReleaseInfo{}, fmt.Errorf("duplicate app release asset: %s", a.Name)
		}
		seen[a.Name] = true
		if err := validateAddonAssetURL(a.URL, r.Tag, a.Name); err != nil {
			return AppReleaseInfo{}, err
		}
		if a.Name == "RelaxCoach.exe" {
			info.AssetName, info.AssetURL = a.Name, a.URL
		} else {
			info.ChecksumURL = a.URL
		}
	}
	if !seen["RelaxCoach.exe"] || !seen["SHA256SUMS.txt"] {
		return appNoUpdate(info, "The release must include RelaxCoach.exe and SHA256SUMS.txt."), nil
	}
	info.Available = true
	return info, nil
}
func appNoUpdate(info AppReleaseInfo, reason string) AppReleaseInfo {
	info.Available = false
	info.AssetName, info.AssetURL, info.ChecksumURL = "", "", ""
	info.Notes = "No compatible new app update is available. " + reason
	return info
}

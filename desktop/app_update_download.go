package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"debug/pe"
	"errors"
	"strings"
)

const appMaxExecutable = 128 << 20

func validateAppRelease(r AppReleaseInfo, current string) error {
	local, e1 := parseAddonVersion(current)
	remote, e2 := parseAddonVersion(r.Version)
	if e1 != nil || e2 != nil || remote.text != r.Version || !remote.newerThan(local) || !r.Available || r.AssetName != "RelaxCoach.exe" {
		return errors.New("check for a strictly newer stable app release again")
	}
	parts := strings.Split(strings.TrimPrefix(r.AssetURL, addonReleasePrefix+"download/"), "/")
	if len(parts) != 2 {
		return errors.New("invalid app release URL")
	}
	tag, err := parseAddonVersion(parts[0])
	if err != nil || tag.text != r.Version {
		return errors.New("app release tag mismatch")
	}
	if err = validateAddonAssetURL(r.AssetURL, parts[0], "RelaxCoach.exe"); err != nil {
		return err
	}
	return validateAddonAssetURL(r.ChecksumURL, parts[0], "SHA256SUMS.txt")
}
func (u *appUpdater) download(ctx context.Context, r AppReleaseInfo, current string) ([]byte, error) {
	if err := validateAppRelease(r, current); err != nil {
		return nil, err
	}
	fresh, err := u.check(ctx, current)
	if err != nil {
		return nil, err
	}
	if !fresh.Available || fresh.Version != r.Version || fresh.AssetURL != r.AssetURL || fresh.ChecksumURL != r.ChecksumURL {
		return nil, errors.New("the public app release changed; check again")
	}
	sums, err := u.transport.fetch(ctx, r.ChecksumURL, 64<<10, "app checksum")
	if err != nil {
		return nil, err
	}
	want, err := addonExpectedChecksum(sums, "RelaxCoach.exe")
	if err != nil {
		return nil, err
	}
	data, err := u.transport.fetch(ctx, r.AssetURL, appMaxExecutable, "app executable")
	if err != nil {
		return nil, err
	}
	if sha256.Sum256(data) != want {
		return nil, errors.New("app SHA256 checksum mismatch; nothing was installed")
	}
	if err = validateAppPE(data); err != nil {
		return nil, err
	}
	return data, ctx.Err()
}
func validateAppPE(data []byte) error {
	bad := errors.New("release is not a valid Windows amd64 GUI executable")
	if len(data) < 512 || len(data) > appMaxExecutable || !bytes.Equal(data[:2], []byte("MZ")) {
		return bad
	}
	f, err := pe.NewFile(bytes.NewReader(data))
	if err != nil {
		return bad
	}
	defer f.Close()
	h, ok := f.OptionalHeader.(*pe.OptionalHeader64)
	if !ok || f.Machine != pe.IMAGE_FILE_MACHINE_AMD64 || f.Characteristics&pe.IMAGE_FILE_EXECUTABLE_IMAGE == 0 || f.Characteristics&pe.IMAGE_FILE_DLL != 0 || h.Magic != 0x20b || h.Subsystem != pe.IMAGE_SUBSYSTEM_WINDOWS_GUI || h.AddressOfEntryPoint == 0 || len(f.Sections) == 0 || len(f.Sections) > 96 {
		return bad
	}
	entry := false
	for _, s := range f.Sections {
		if uint64(s.Offset)+uint64(s.Size) > uint64(len(data)) {
			return bad
		}
		if s.Characteristics&pe.IMAGE_SCN_MEM_EXECUTE != 0 && h.AddressOfEntryPoint >= s.VirtualAddress && uint64(h.AddressOfEntryPoint) < uint64(s.VirtualAddress)+uint64(s.Size) {
			entry = true
		}
	}
	if !entry {
		return bad
	}
	return nil
}

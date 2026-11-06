//go:build windows

package main

import (
	"errors"
	"os"
	"runtime"
	"unsafe"

	"golang.org/x/sys/windows"
)

func appSingleLink(f *os.File) error {
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(windows.Handle(f.Fd()), &info); err != nil {
		return err
	}
	if info.NumberOfLinks != 1 || info.FileAttributes&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
		return errors.New("refusing linked/reparse app update file")
	}
	return nil
}
func appRejectReparse(path string) error {
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return err
	}
	attr, err := windows.GetFileAttributes(p)
	if err != nil {
		return err
	}
	if attr&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
		return errors.New("refusing reparse app update path")
	}
	return nil
}
func appPrivateSecurity(directory bool) (*windows.SECURITY_DESCRIPTOR, error) {
	user, err := windows.GetCurrentProcessToken().GetTokenUser()
	if err != nil {
		return nil, err
	}
	flags := ""
	if directory {
		flags = "OICI"
	}
	return windows.SecurityDescriptorFromString("O:" + user.User.Sid.String() + "D:P(A;" + flags + ";FA;;;" + user.User.Sid.String() + ")")
}
func appPrivateDirectory(path string) error {
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return err
	}
	sd, err := appPrivateSecurity(true)
	if err != nil {
		return err
	}
	sa := windows.SecurityAttributes{Length: uint32(unsafe.Sizeof(windows.SecurityAttributes{})), SecurityDescriptor: sd}
	err = windows.CreateDirectory(p, &sa)
	runtime.KeepAlive(sd)
	if err != nil && err != windows.ERROR_ALREADY_EXISTS {
		return err
	}
	if err = appPlainDirectory(path); err != nil {
		return err
	}
	actual, err := windows.GetNamedSecurityInfo(path, windows.SE_FILE_OBJECT, windows.DACL_SECURITY_INFORMATION|windows.OWNER_SECURITY_INFORMATION)
	if err != nil {
		return err
	}
	owner, _, err := actual.Owner()
	if err != nil {
		return err
	}
	wantOwner, _, err := sd.Owner()
	if err != nil {
		return err
	}
	control, _, err := actual.Control()
	if err != nil {
		return err
	}
	if owner == nil || wantOwner == nil || !appPrivateACLMatches(actual.String(), sd.String(), owner.String(), wantOwner.String(), control&windows.SE_DACL_PROTECTED != 0) {
		return errors.New("app staging directory is not private to the current user")
	}
	return nil
}
func appMoveNew(from, to string) error {
	a, err := windows.UTF16PtrFromString(from)
	if err != nil {
		return err
	}
	b, err := windows.UTF16PtrFromString(to)
	if err != nil {
		return err
	}
	// Deliberately no MOVEFILE_REPLACE_EXISTING: an intervening file is never overwritten.
	return windows.MoveFileEx(a, b, windows.MOVEFILE_WRITE_THROUGH)
}

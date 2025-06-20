# SAI WebDAV Setup

This repository contains a single PowerShell script used to configure a basic WebDAV setup for an IIS website. It installs required Windows features, creates the physical folder, configures a virtual directory and sets up authentication and firewall rules.

## Requirements

- Windows Server with IIS installed
- Administrator privileges in PowerShell

## Usage

```powershell
# Example: configure WebDAV under "Archives" for everyone
./sai.ps1 -SiteName "SAI" -VirtualPath "/Archives" -PhysicalPath "C:\SAI\Archives" -AuthUserGroup "Everyone"
```

Arguments:

- **SiteName**: existing IIS site where the application will be created. Defaults to `SAI`.
- **VirtualPath**: path of the WebDAV application. Defaults to `/Archives`.
- **PhysicalPath**: local folder path to serve. Defaults to `C:\SAI\Archives`.
- **AuthUserGroup**: user or group granted access. Defaults to `Everyone`.
- **UseBasicAuth**: switch to enable Basic Authentication in addition to Windows Authentication.

Run the script from an elevated PowerShell session. After execution, WebDAV will be accessible at `http://<server>/<VirtualPath>`.

## Notes

- The script requires a restart if new IIS features are installed.
- For production use, enable SSL when using Basic Authentication to protect credentials.
- Review NTFS permissions to ensure only authorized users can access the directory.


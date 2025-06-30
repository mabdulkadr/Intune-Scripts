
# Adobe Flash Player Removal

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

This repository contains PowerShell scripts for detecting and remediating the presence of Adobe Flash Player on Windows systems. These scripts are designed for deployment via Microsoft Intune as part of a remediation process.

## Overview

The detection script checks if Adobe Flash Player is installed on a system by verifying file locations and registry entries. If detected, the remediation script is triggered to uninstall Flash Player, remove leftover files, and clean registry entries.

The remediation process
1. Terminates all known browser and Flash-related processes.
2. Downloads and runs the Adobe Flash Player uninstaller silently.
3. Cleans up leftover Flash Player files and directories from system and browser data locations.
4. Removes registry entries associated with Adobe Flash Player.

## Files

- Detect-FlashPlayer.ps1 A script that detects the presence of Adobe Flash Player on the system by checking file locations and registry entries.
- Remove-FlashPlayer.ps1 A script that uninstalls Flash Player, removes leftover files, and deletes registry keys.

## Prerequisites

- Microsoft Intune Used for deployment and management of scripts on target devices.
- Windows PowerShell Scripts are compatible with PowerShell 5.1 and higher.
- Internet Connection Required to download the Adobe Flash uninstaller from Adobe's official site.

## Detection Script (`Detect-FlashPlayer.ps1`)

### Purpose
Detects if Adobe Flash Player is installed by checking common file paths and registry entries.

### Usage
The script returns `Detected` if Flash Player is found, causing the remediation script to run. If Flash Player is not detected, the script exits with `Compliant` status.

### Example Output
- `Detected` Flash Player is installed.
- `Compliant` Flash Player is not installed.

## Remediation Script (`Remove-FlashPlayer.ps1`)

### Purpose
Uninstalls Adobe Flash Player and performs cleanup tasks.

### Actions
1. Terminates browser processes that may be using Flash.
2. Downloads the official Adobe Flash Player uninstaller and executes it silently.
3. Removes leftover Flash Player files from system directories and browser-specific locations.
4. Deletes registry keys related to Flash Player.

### Example Output
- `Uninstaller executed` Indicates that the uninstaller has been triggered.
- `Removed folder path` Indicates that a leftover folder was successfully removed.
- `Deleted registry key path` Indicates that a Flash-related registry key was deleted.

## How to Use

### Step 1 Deployment via Intune
1. Upload Scripts to Intune
   - Go to Intune Admin Center → Devices → Scripts → Remediations.
   - Click + Create script package.
   - Upload both `Detect-FlashPlayer.ps1` and `Remove-FlashPlayer.ps1`.

2. Configure Remediation
   - Assign these scripts to your target devices.
   - Monitor the script execution and results under Remediations.

### Step 2 Monitoring
- Once deployed, Intune will use the detection script to check for the presence of Adobe Flash Player. If Flash is found, the remediation script will be triggered to remove it from the device.
- Logs are written to `CIntuneflash_uninstall.log` and `CIntuneflash_uninstall_error.log`.

## Logging
- All actions performed by the remediation script are logged in `CIntuneflash_uninstall.log`.
- Any errors encountered during the uninstallation process are logged in `CIntuneflash_uninstall_error.log`.

## References
- [Adobe Flash Player Uninstallation Guide](httpshelpx.adobe.comflash-playerkbuninstall-flash-player-windows.html)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

### Notes
- Important Adobe Flash Player has been officially discontinued, and this script helps in removing it from systems to prevent potential security vulnerabilities.

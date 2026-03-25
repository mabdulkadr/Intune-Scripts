# 💽 Get-DiskCleanupStatus – Low Disk Space Detection and CleanMgr Remediation

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Disk%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-DiskCleanupStatus** checks how much free space is available on the `C:` drive and runs Windows Disk Cleanup when free space drops below the configured threshold.

The detection script reads the free space reported by `Get-PSDrive` for drive `C` and compares it to a threshold of `15 GB`. If the device has less free space than that, detection exits with code `1`. The remediation script then enables a small set of Disk Cleanup handlers in the registry and launches `CleanMgr.exe /sagerun:1`.

This package is a simpler variant of the more fully documented `CleanUpDisk` package in the repository. It uses the same Windows cleanup mechanism but with a shorter implementation.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-DiskCleanupStatus
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-DiskCleanupStatus
│
├── Get-DiskCleanupStatus--Detect.ps1
├── Get-DiskCleanupStatus--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-DiskCleanupStatus--Detect.ps1
```

### Purpose

Checks whether free space on `C:` is above the package threshold.

### Logic

1. Reads free space on `C:` with `Get-PSDrive`
2. Compares the result to `15 GB`
3. Returns success when free space is greater than the threshold
4. Returns failure when free space is below the threshold

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Free space is above the configured threshold |
| 1    | Free space is below the configured threshold |

### Example

```powershell
.\Get-DiskCleanupStatus--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-DiskCleanupStatus--Remediate.ps1
```

### Purpose

Configures selected Disk Cleanup handlers and runs `CleanMgr.exe`.

### Actions

The script performs the following steps:

1. Writes `StateFlags0001 = 2` for the selected cleanup handlers
2. Starts `CleanMgr.exe /sagerun:1`
3. Waits for Disk Cleanup to finish

### Example

```powershell
.\Get-DiskCleanupStatus--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* `Get-PSDrive`
* Windows Registry
* `CleanMgr.exe`

### Permissions

* Administrative rights are required to write the cleanup handler registry values

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Get-DiskCleanupStatus--Detect.ps1
```

### Remediation Script

```powershell
Get-DiskCleanupStatus--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks free space on `C:`
3. If the device has less than `15 GB` free, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation enables the configured cleanup handlers and runs Disk Cleanup

---

# 🛡 Operational Notes

* The package only checks the `C:` drive.
* The threshold is hard-coded at `15 GB`.
* The remediation script relies on the legacy Disk Cleanup utility being available on the device.
* This package does not clear custom temporary folders outside the handlers configured in the registry.

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.2**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-%E2%98%95-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

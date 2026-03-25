# 🔔 Show-LowDiskSpaceAlert – Disk Space Analysis and User Toast Report

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Low%20Disk%20Space%20Notification-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Show-LowDiskSpaceAlert** is a user-notification remediation package that checks free space on `C:` and, when the device drops below a configured threshold, generates a detailed disk usage report and shows a Windows toast notification.

The detection script reads `Win32_LogicalDisk` for drive `C:` and compares the calculated free-space percentage to `$Percent_Alert`. The remediation script is much larger: it gathers disk usage details, evaluates large folders and large files, inspects OneDrive redirection and on-disk usage, generates HTML and chart images, registers a custom notification app under `HKCU`, and finally displays a Windows toast that links the user to a locally generated disk report.

This package is aimed at end-user awareness rather than automatic cleanup. It helps the user see why the disk is full and where the main storage consumers are located.

---

# ✨ Core Features

### 🔹 Free Space Threshold Detection

* Checks drive `C:` through `Win32_LogicalDisk`
* Calculates free-space percentage
* Triggers remediation only when free space is at or below the configured alert value

### 🔹 User-Facing HTML Report

* Builds an HTML report under `%TEMP%`
* Creates CSS and embedded chart images
* Summarizes local data, temp files, downloads, OneDrive usage, and large folders/files

### 🔹 OneDrive and Profile Analysis

* Inspects OneDrive redirection for known folders
* Calculates OneDrive total size and size on disk
* Highlights downloads and temp content as large local consumers

### 🔹 Toast Notification Workflow

* Registers a custom toast app ID in `HKCU`
* Can use either a Base64 image or a downloaded image
* Displays a Windows toast with buttons that open guidance or the local report

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Show-LowDiskSpaceAlert
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Show-LowDiskSpaceAlert
│
├── README.md
├── Show-LowDiskSpaceAlert--Detect.ps1
└── Show-LowDiskSpaceAlert--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Show-LowDiskSpaceAlert--Detect.ps1
```

### Purpose

Checks whether the free-space percentage on `C:` is below the configured alert threshold.

### Logic

1. Reads `Win32_LogicalDisk` for `C:`
2. Calculates the free-space percentage
3. Compares that percentage to `$Percent_Alert`
4. Returns exit code `1` when free space is low enough to show the user notification

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Free space is above the configured alert threshold |
| 1    | Free space is at or below the configured alert threshold |

### Key References

* CIM Class: `Win32_LogicalDisk`
* Drive: `C:`
* Variable: `$Percent_Alert`

### Example

```powershell
.\Show-LowDiskSpaceAlert--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Show-LowDiskSpaceAlert--Remediate.ps1
```

### Purpose

Builds a local disk usage report and shows a Windows toast notification to help the user understand what is consuming storage.

### Actions

1. Calculates disk usage, free space, downloads size, temp size, and other local storage usage
2. Evaluates large folders and files
3. Measures OneDrive content size and on-disk footprint
4. Builds HTML, CSS, and chart image files under `%TEMP%`
5. Registers a custom notification app in `HKCU:\Software\Classes\AppUserModelId`
6. Displays a Windows toast with buttons that open the report and optional guidance

### Key References

* Registry: `HKCU:\Software\Classes\AppUserModelId`
* Registry: `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings`
* Path: `%TEMP%\DiskSize_Report.html`
* APIs: `Windows.UI.Notifications.ToastNotificationManager`, `System.Windows.Forms.DataVisualization`

### Example

```powershell
.\Show-LowDiskSpaceAlert--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* User context is the natural fit because the script writes under `HKCU` and `%TEMP%`
* The user session must support toast notifications for the notification step to be meaningful

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Show-LowDiskSpaceAlert`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Show-LowDiskSpaceAlert--Detect.ps1
```

### Remediation Script

```powershell
Show-LowDiskSpaceAlert--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Yes   |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks the free-space percentage on `C:`
3. If free space is low, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation builds the local report, registers the notification app, and displays the toast

---

# 🛡 Operational Notes

* The package is highly configurable, but the script depends on several variables in the "Variables to fill" section being set correctly
* This is a user-guidance workflow, not an automatic cleanup routine
* The remediation script is large and multi-purpose, so test carefully before broad rollout
* Because the report and charts are generated under `%TEMP%`, content is per-user and session-dependent

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

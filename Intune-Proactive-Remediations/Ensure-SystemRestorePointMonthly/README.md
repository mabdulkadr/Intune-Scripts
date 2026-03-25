# 💽 Ensure-SystemRestorePointMonthly – Monthly Restore Point Maintenance

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-System%20Restore-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Ensure-SystemRestorePointMonthly** checks whether the device already has a valid restore point for the current month and creates one when it does not.

The detection script reads restore points from two sources: `Get-ComputerRestorePoint` and the `root/default:SystemRestore` CIM provider. It then looks for a restore point whose description matches one of the accepted monthly naming patterns. The remediation script enables System Protection if needed, temporarily clears the restore-point creation throttle in the registry, and creates a new restore point for the current month.

This package is a practical fit when you want a predictable monthly restore point without relying on users or ad hoc maintenance tasks.

---

# ✨ Core Features

### 🔹 Dual Restore Point Discovery

The detection script collects restore points from:

* `Get-ComputerRestorePoint`
* `Get-CimInstance -Namespace root/default -ClassName SystemRestore`

That reduces the chance of missing a valid restore point because only one provider returned data.

---

### 🔹 Description-Based Monthly Matching

The scripts look for descriptions that match one of these prefixes:

* `Monthly System Restore Point`
* `Intune Monthly Restore Point`
* `System Safety Restore Point`

They also accept a month tag in the form:

```text
(yyyy-MM)
```

---

### 🔹 Automatic System Protection Enablement

If System Restore is not available on the OS drive, remediation attempts to enable it with:

```powershell
Enable-ComputerRestore
```

This allows the package to recover on devices where System Protection is disabled but still supported.

---

### 🔹 Throttle Bypass for Restore Point Creation

Windows normally limits how often restore points can be created. The remediation script temporarily sets:

```text
HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore\SystemRestorePointCreationFrequency
```

to `0`, creates the restore point, then restores or removes that value afterward.

---

### 🔹 Script-Specific Logging

Both scripts write logs under:

```text
<SystemDrive>\IntuneLogs\Ensure-SystemRestorePointMonthly
```

This makes it easy to review the restore-point decision path and the remediation result on each device.

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Ensure-SystemRestorePointMonthly
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Ensure-SystemRestorePointMonthly
│
├── Ensure-SystemRestorePointMonthly--Detect.ps1
├── Ensure-SystemRestorePointMonthly--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Ensure-SystemRestorePointMonthly--Detect.ps1
```

### Purpose

Determines whether a valid restore point already exists for the current month.

### Logic

1. Collects restore points from the PowerShell and CIM providers
2. Normalizes the restore point timestamps
3. Removes duplicate entries returned by both providers
4. Looks for a restore point that matches the accepted prefixes or current month tag
5. Returns `0` when a valid monthly restore point is found
6. Returns `1` when no valid restore point is available

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | A valid restore point for the current month exists |
| 1    | No valid monthly restore point was found |

### Example

```powershell
.\Ensure-SystemRestorePointMonthly--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Ensure-SystemRestorePointMonthly--Remediate.ps1
```

### Purpose

Creates a monthly restore point when the current month does not already have one.

### Actions

The script performs the following steps:

1. Rechecks whether a valid monthly restore point already exists
2. Detects the OS drive used for System Protection
3. Enables System Protection if required
4. Temporarily removes the restore-point creation throttle
5. Creates a restore point using `Checkpoint-Computer`
6. Restores the throttle registry setting

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Restore point already existed or was created successfully |
| 2    | System Protection could not be enabled or verified |
| 3    | Restore point creation failed |
| 4    | Unexpected remediation error |

### Example

```powershell
.\Ensure-SystemRestorePointMonthly--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrative rights are typically required for `Enable-ComputerRestore` and `Checkpoint-Computer`
* Access to the `SystemRestore` registry path under `HKLM`

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Ensure-SystemRestorePointMonthly--Detect.ps1
```

### Remediation Script

```powershell
Ensure-SystemRestorePointMonthly--Remediate.ps1
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
2. Detection checks both restore point providers for a valid current-month restore point
3. If none is found, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation enables System Protection if needed and creates the missing restore point
6. Subsequent detections return compliant for the rest of the month

---

# 🛡 Operational Notes

* The package relies on System Restore being supported and available on the device. Some environments disable it by policy.
* Detection accepts several naming prefixes, so older restore points created by previous naming conventions can still satisfy the monthly check.
* The remediation script only changes the throttle value temporarily and attempts to restore the previous registry state afterward.
* If restore points exist but neither provider returns them cleanly, detection can still report the device as non-compliant.

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

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

# 💽 Invoke-WindowsUpdateScan – Filtered Windows Update Installation

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Windows%20Update-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Invoke-WindowsUpdateScan** uses the `PSWindowsUpdate` module to detect and optionally install pending Windows updates based on configurable filters.

The detection script validates the filter configuration, ensures the module is available, and queries Windows Update or Microsoft Update for matching updates. If one or more matching updates are available, it signals remediation. The remediation script uses the same filter model, installs matching updates with `Install-WindowsUpdate`, and then checks a small set of registry locations to report whether a reboot is pending.

This package is useful when you want to target a subset of updates such as specific categories, severities, or KB articles rather than installing everything unconditionally.

---

# ✨ Core Features

### 🔹 PSWindowsUpdate-Based Detection

The package depends on the `PSWindowsUpdate` module for both detection and remediation. If the module is missing, the scripts attempt to install it automatically.

---

### 🔹 Configurable Update Scope

The scripts can be limited by:

* update source: `MicrosoftUpdate` or `WindowsUpdate`
* `UpdateType`
* category
* severity
* included KB article IDs
* excluded KB article IDs

If those arrays are left empty, the scripts target all available updates from the selected source.

---

### 🔹 Shared Detection and Install Filters

Detection and remediation use the same filter model, which makes the remediation behavior predictable. If detection reports pending matching updates, remediation will attempt to install that same matching set.

---

### 🔹 Pending Reboot Check

After installation, the remediation script checks common reboot markers under `HKLM`, including:

* `Component Based Servicing\RebootPending`
* `WindowsUpdate\Auto Update\RebootRequired`
* `Session Manager\PendingFileRenameOperations`

The script reports the reboot state in its log output but does not force a restart unless you extend it.

---

### 🔹 Intune Log Files

Both scripts write logs under:

```text
<SystemDrive>\IntuneLogs\Invoke-WindowsUpdateScanScan
```

This captures module installation, update filtering, matching update counts, and reboot status.

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Invoke-WindowsUpdateScan
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Invoke-WindowsUpdateScan
│
├── Invoke-WindowsUpdateScan--Detect.ps1
├── Invoke-WindowsUpdateScan--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Invoke-WindowsUpdateScanScan--Detect.ps1
```

### Purpose

Checks whether matching Windows updates are currently pending.

### Logic

1. Validates the configured update filters
2. Ensures the `PSWindowsUpdate` module is installed and imported
3. Queries the selected update source for matching updates
4. Returns `1` when one or more matching updates are available
5. Returns `0` when no matching updates are found

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No matching pending updates were found |
| 1    | One or more matching updates are pending |
| 2    | Detection failed |

### Example

```powershell
.\Invoke-WindowsUpdateScanScan--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Invoke-WindowsUpdateScanScan--Remediate.ps1
```

### Purpose

Installs matching Windows updates using the same filter configuration as detection.

### Actions

The script performs the following steps:

1. Validates the configured update filters
2. Ensures the `PSWindowsUpdate` module is installed and imported
3. Queries the selected update source for matching updates
4. Runs `Install-WindowsUpdate` for the matching set
5. Checks whether the system is left in a pending reboot state

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Remediation completed |
| 1    | Remediation failed |

### Example

```powershell
.\Invoke-WindowsUpdateScanScan--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to install PowerShell modules if `PSWindowsUpdate` is missing
* Permission to query and install Windows updates

### Dependencies

* `PSWindowsUpdate`
* Access to either Windows Update or Microsoft Update, depending on configuration

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Invoke-WindowsUpdateScanScan--Detect.ps1
```

### Remediation Script

```powershell
Invoke-WindowsUpdateScanScan--Remediate.ps1
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
2. Detection checks the selected update source for matching updates
3. If matching updates are pending, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation installs the matching updates through `PSWindowsUpdate`
6. The script logs whether a reboot is still pending afterward

---

# 🛡 Operational Notes

* The scripts can install `PSWindowsUpdate` at runtime. In locked-down environments, that may fail or require repository trust decisions.
* The remediation script does not restart the device unless you change `AutoRebootAfterInstall`.
* Because the filter arrays are empty by default, the package targets all available updates unless you narrow it.
* A pending reboot reported after remediation does not necessarily mean installation failed; it may simply mean Windows still needs a restart to finish applying updates.

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

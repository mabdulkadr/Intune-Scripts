# 🔌 Test-PnPDeviceStatus – Error-State Plug and Play Device Re-Detection

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-PnP%20Device%20Recovery-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Test-PnPDeviceStatus** is an Intune remediation package that looks for present Plug and Play devices currently reporting `Status ERROR` and then forces a remove-and-rescan cycle for those devices.

The detection script uses `Get-PnpDevice -PresentOnly -Status ERROR` and supports optional include/exclude filters for PnP class and device ID. If matching devices are found, it outputs a short summary and returns exit code `1`. The remediation script uses the same filters, removes each matched device instance with `pnputil.exe /remove-device`, and then immediately triggers `pnputil.exe /scan-devices` to let Windows detect hardware again.

This package is useful for transient PnP enumeration issues where a remove-and-rescan cycle can be enough to recover the device.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Test-PnPDeviceStatus
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Test-PnPDeviceStatus
│
├── README.md
├── Test-PnPDeviceStatus--Detect.ps1
└── Test-PnPDeviceStatus--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Test-PnPDeviceStatus--Detect.ps1
```

### Purpose

Checks whether any present Plug and Play devices are currently reporting `Status ERROR`.

### Logic

1. Queries `Get-PnpDevice -PresentOnly -Status ERROR`
2. Applies optional class and device ID filters
3. Builds a short summary of matched devices
4. Returns exit code `1` when one or more matching devices are found

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No matching PnP devices with errors were found |
| 1    | One or more matching PnP devices with errors were found |

### Key References

* Command: `Get-PnpDevice -PresentOnly -Status ERROR`
* Filters: `PNPClass`, `PNPDeviceID`

### Example

```powershell
.\Test-PnPDeviceStatus--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Test-PnPDeviceStatus--Remediate.ps1
```

### Purpose

Removes present PnP devices in an error state and immediately asks Windows to detect hardware again.

### Actions

1. Queries the same error-state PnP devices used by detection
2. Applies the same optional filters
3. Runs `pnputil.exe /remove-device <PNPDeviceID>` for each match
4. Runs `pnputil.exe /scan-devices` after each removal

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Remediation completed without a terminating error |
| 1    | A terminating error occurred during remediation |

### Key References

* Command: `pnputil.exe /remove-device`
* Command: `pnputil.exe /scan-devices`

### Example

```powershell
.\Test-PnPDeviceStatus--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to query PnP device state
* Permission to remove device instances with `pnputil.exe`

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Test-PnPDeviceStatus`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Test-PnPDeviceStatus--Detect.ps1
```

### Remediation Script

```powershell
Test-PnPDeviceStatus--Remediate.ps1
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
2. Detection checks present PnP devices for `Status ERROR`
3. If matching devices are found, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation removes each affected device instance and triggers a hardware rescan

---

# 🛡 Operational Notes

* The current default filters are broad and will include all present devices in an error state unless you narrow them
* Remove-and-rescan recovery is useful for some device classes, but not all hardware problems are resolved this way
* Test carefully before broad rollout on devices with sensitive USB, docking, storage, or specialty hardware

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

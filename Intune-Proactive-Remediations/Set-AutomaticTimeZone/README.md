# 🌍 Set-AutomaticTimeZone – Enable Windows Automatic Time Zone Updates

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Time%20Zone%20Configuration-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Set-AutomaticTimeZone** configures the Windows settings that allow the OS to update the device time zone automatically.

The detection script checks two specific registry settings:

* Location consent under the Windows Capability Access Manager key
* The startup configuration of the `tzautoupdate` service

If either setting is not in the required state, the remediation script writes both values back to the expected configuration.

---

# ✨ Core Features

### 🔹 Registry-Based Detection

The detection script works entirely through registry reads:

* Checks `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location`
* Checks `HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate`
* Returns remediation when either value does not match the configured target

---

### 🔹 Direct Configuration Repair

The remediation script does not call external tools or services:

* Sets location consent to `Allow`
* Sets `tzautoupdate\Start` to `3`
* Uses `New-ItemProperty -Force` for both values

---

### 🔹 Standardized Intune Logging

Both scripts initialize the shared local log path:

```text
<SystemDrive>\IntuneLogs\Set-AutomaticTimeZone
```

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Set-AutomaticTimeZone
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Set-AutomaticTimeZone
│
├── image.png
├── README.md
├── Set-AutomaticTimeZone--Detect.ps1
└── Set-AutomaticTimeZone--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Set-AutomaticTimeZone--Detect.ps1
```

### Purpose

Checks whether Windows has the required registry settings for automatic time zone updates.

### Logic

1. Reads the location consent value from the Capability Access Manager key
2. Reads the `Start` value for the `tzautoupdate` service
3. Returns `0` only when both values match the configured targets
4. Returns `1` when one or both settings do not match

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Required location and `tzautoupdate` values are already set |
| 1    | One or more required settings are missing or different |

### Example

```powershell
.\Set-AutomaticTimeZone--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Set-AutomaticTimeZone--Remediate.ps1
```

### Purpose

Writes the registry values required for automatic time zone detection.

### Actions

1. Sets `ConsentStore\location\Value` to `Allow`
2. Sets `Services\tzautoupdate\Start` to `3`
3. Returns `0` only if both write operations succeed

### Example

```powershell
.\Set-AutomaticTimeZone--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrative rights are required because the package writes to `HKLM`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Set-AutomaticTimeZone--Detect.ps1
```

### Remediation Script

```powershell
Set-AutomaticTimeZone--Remediate.ps1
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
2. Detection reads the location consent and `tzautoupdate` registry values
3. If either value is not set correctly, detection exits with code **1**
4. Intune runs the **Remediation Script**
5. Remediation writes the required registry settings back to `HKLM`

---

# 🛡 Operational Notes

* The package configures registry state only. It does not verify that Windows can successfully geolocate the device afterwards.
* The detection script compares the service startup value against the configured target used in the script, so keep detection and remediation aligned if you change that value later.
* Because the settings live in `HKLM`, this package is best suited to system-context execution.

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

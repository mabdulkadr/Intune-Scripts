# 💽 Get-DefenderPUAProtectionStatus – Enforce Defender PUA Protection

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Defender%20Hardening-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-DefenderPUAProtectionStatus** checks whether Microsoft Defender Potentially Unwanted Application protection is enabled and turns it on when it is not.

The detection script reads `PUAProtection` from `Get-MpPreference` and expects the value `1`. The remediation script calls `Set-MpPreference -PUAProtection Enabled` and reports whether the change succeeded.

This package is a small Defender hardening workflow for environments that want to block or warn on potentially unwanted applications.

---

# ✨ Core Features

### 🔹 Defender Preference Check

Detection reads the current Defender configuration through:

```powershell
Get-MpPreference
```

and evaluates the `PUAProtection` property.

---

### 🔹 Direct Defender Remediation

Remediation enables the setting with:

```powershell
Set-MpPreference -PUAProtection Enabled
```

---

### 🔹 Local Script Logging

The package writes logs under:

```text
<SystemDrive>\IntuneLogs\Get-DefenderPUAProtectionStatus
```

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-DefenderPUAProtectionStatus
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-DefenderPUAProtectionStatus
│
├── Get-DefenderPUAProtectionStatus--Detect.ps1
├── Get-DefenderPUAProtectionStatus--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-DefenderPUAProtectionStatus--Detect.ps1
```

### Purpose

Checks whether Defender PUA protection is enabled.

### Logic

1. Calls `Get-MpPreference`
2. Reads the `PUAProtection` property
3. Returns `0` when the value is `1`
4. Returns `1` otherwise

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | PUA protection is enabled |
| 1    | PUA protection is disabled or could not be verified |

### Example

```powershell
.\Get-DefenderPUAProtectionStatus--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-DefenderPUAProtectionStatus--Remediate.ps1
```

### Purpose

Enables Microsoft Defender PUA protection.

### Actions

The script performs one action:

1. Runs `Set-MpPreference -PUAProtection Enabled`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | PUA protection was enabled successfully |
| 1    | The Defender setting change failed |

### Example

```powershell
.\Get-DefenderPUAProtectionStatus--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Microsoft Defender must be available on the device
* Permission to read and modify Defender preferences

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Get-DefenderPUAProtectionStatus--Detect.ps1
```

### Remediation Script

```powershell
Get-DefenderPUAProtectionStatus--Remediate.ps1
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
2. Detection checks `Get-MpPreference().PUAProtection`
3. If the value is not enabled, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation enables Defender PUA protection

---

# 🛡 Operational Notes

* The detection script expects the raw value `1`.
* The script does not distinguish between Audit and Block modes beyond the current simple equality check.
* If Defender settings are controlled by another management layer, remediation may fail or be reverted later.

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

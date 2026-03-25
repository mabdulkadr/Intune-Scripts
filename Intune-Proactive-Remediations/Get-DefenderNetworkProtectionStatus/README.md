# 🛡 Get-DefenderNetworkProtectionStatus – Microsoft Defender Network Protection Enforcement

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Defender%20Hardening-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-DefenderNetworkProtectionStatus** enforces the Microsoft Defender Network Protection setting by reading and writing Defender preferences with `Get-MpPreference` and `Set-MpPreference`.

The detection script checks whether `EnableNetworkProtection` is set to `1`. The remediation script enables the same setting by running `Set-MpPreference -EnableNetworkProtection Enabled`.

The current script files still contain duplicated scaffolding from earlier edits, but the effective detection and remediation logic is centered on this single Defender setting.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-DefenderNetworkProtectionStatus
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-DefenderNetworkProtectionStatus
│
├── Get-DefenderNetworkProtectionStatus--Detect.ps1
├── Get-DefenderNetworkProtectionStatus--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-DefenderNetworkProtectionStatus--Detect.ps1
```

### Purpose

Checks whether Microsoft Defender Network Protection is enabled.

### Logic

1. Runs `Get-MpPreference`
2. Reads `EnableNetworkProtection`
3. Returns `0` when the value is `1`
4. Returns `1` when the value is different

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Network Protection is enabled |
| 1    | Network Protection is not enabled |

### Example

```powershell
.\Get-DefenderNetworkProtectionStatus--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-DefenderNetworkProtectionStatus--Remediate.ps1
```

### Purpose

Enables Microsoft Defender Network Protection.

### Actions

1. Runs `Set-MpPreference -EnableNetworkProtection Enabled`
2. Returns success when the command completes
3. Returns failure if the Defender cmdlet throws an error

### Example

```powershell
.\Get-DefenderNetworkProtectionStatus--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrator privileges are required to change Defender preferences

### Dependencies

* Microsoft Defender PowerShell cmdlets

---

# 🧭 Intune Deployment

This package is suitable for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Get-DefenderNetworkProtectionStatus--Detect.ps1
```

### Remediation Script

```powershell
Get-DefenderNetworkProtectionStatus--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the detection script
2. Detection checks `EnableNetworkProtection`
3. If the setting is not enabled, detection exits with code `1`
4. Intune triggers remediation
5. Remediation enables Network Protection through Defender cmdlets

---

# 🛡 Operational Notes

* The effective logic is valid, but both script files still contain duplicated generated scaffolding around the core commands.
* Detection compares against the numeric value `1`, while remediation sets the preference through the named value `Enabled`.
* Test Defender cmdlet availability on the target device class before broad rollout.

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

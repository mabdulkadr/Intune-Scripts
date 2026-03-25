# ☁️ Get-DefenderCloudProtectionStatus – Microsoft Defender Cloud Protection Settings

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Defender%20Cloud%20Protection-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-DefenderCloudProtectionStatus** enforces two Microsoft Defender settings that control cloud-delivered protection: `MAPSReporting` and `SubmitSamplesConsent`.

Detection reads the current Defender configuration with `Get-MpPreference`. Remediation applies the required values with `Set-MpPreference`, enabling advanced MAPS reporting and automatic sample submission.

---

# ✨ Core Features

### 🔹 Two-Setting Validation

The detection script checks that:

* `MAPSReporting` equals `2`
* `SubmitSamplesConsent` equals `3`

Both values must match for the device to be considered compliant.

---

### 🔹 Defender-Based Remediation

The remediation script applies:

* `Set-MpPreference -MAPSReporting Advanced`
* `Set-MpPreference -SubmitSamplesConsent SendAllSamples`

---

### 🔹 Versioned Output

The scripts preserve the original version markers:

* `C1 COMPLIANT` / `C1 NON-COMPLIANT`
* `R1 Remediated` / `R1 Failed`

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-DefenderCloudProtectionStatus
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-DefenderCloudProtectionStatus
│
├── Get-DefenderCloudProtectionStatus--Detect.ps1
├── Get-DefenderCloudProtectionStatus--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-DefenderCloudProtectionStatus--Detect.ps1
```

### Purpose

Checks whether Microsoft Defender cloud-delivered protection is configured with the expected MAPS and sample-submission values.

### Logic

1. Calls `Get-MpPreference`
2. Reads `MAPSReporting`
3. Reads `SubmitSamplesConsent`
4. Returns `0` only when both values match the required state

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Both Defender settings already match |
| 1    | One or both settings need remediation |

### Example

```powershell
.\Get-DefenderCloudProtectionStatus--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-DefenderCloudProtectionStatus--Remediate.ps1
```

### Purpose

Applies the Microsoft Defender settings required for cloud-delivered protection.

### Actions

1. Enables advanced MAPS reporting
2. Enables automatic sample submission
3. Returns exit code `0` if both writes succeed

### Example

```powershell
.\Get-DefenderCloudProtectionStatus--Remediate.ps1
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
Get-DefenderCloudProtectionStatus--Detect.ps1
```

### Remediation Script

```powershell
Get-DefenderCloudProtectionStatus--Remediate.ps1
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
2. Detection reads the two relevant Defender preferences
3. If either value is incorrect, detection exits with code `1`
4. Intune triggers remediation
5. Remediation applies both Defender settings

---

# 🛡 Operational Notes

* This package targets only two cloud protection settings. It does not modify other Defender protections such as Network Protection or PUA protection.
* Detection fails closed: if `Get-MpPreference` throws an error, the script returns non-compliant.

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

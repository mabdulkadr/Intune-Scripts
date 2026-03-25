# 💽 Get-OfficeTelemetryStatus – Disable Office Client Telemetry for the Current User

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Office%20Policy-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-OfficeTelemetryStatus** checks whether Office client telemetry is disabled for the current user and creates the required policy registry key when it is missing.

The detection script looks for `DisableTelemetry=1` under `HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry`. The remediation script creates the `clienttelemetry` subkey and writes the `DisableTelemetry` DWORD value.

This package is a per-user Office policy script. It does not modify device-wide Office policy under `HKLM`.

---

# ✨ Core Features

### 🔹 HKCU Policy Detection

Detection checks this user-scoped policy path:

```text
HKCU\Software\Policies\Microsoft\office\common\clienttelemetry
```

and expects:

```text
DisableTelemetry = 1
```

---

### 🔹 Per-User Remediation

Remediation creates the missing key and writes the DWORD policy value under the current user's hive.

---

### 🔹 Local Script Logging

The package writes logs under:

```text
<SystemDrive>\IntuneLogs\Get-OfficeTelemetryStatusStatus
```

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-OfficeTelemetryStatus
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-OfficeTelemetryStatus
│
├── Get-OfficeTelemetryStatus--Detect.ps1
├── Get-OfficeTelemetryStatus--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-OfficeTelemetryStatusStatus--Detect.ps1
```

### Purpose

Checks whether Office client telemetry is disabled for the current user.

### Logic

1. Reads `DisableTelemetry` from the `clienttelemetry` policy key under `HKCU`
2. Returns `0` when the value is `1`
3. Returns `1` if the key or value is missing or set differently

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Office telemetry is disabled for the current user |
| 1    | The required user policy is missing or not set correctly |

### Example

```powershell
.\Get-OfficeTelemetryStatusStatus--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-OfficeTelemetryStatusStatus--Remediate.ps1
```

### Purpose

Creates the Office policy key and disables telemetry for the current user.

### Actions

The script performs the following steps:

1. Creates `HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry`
2. Creates `DisableTelemetry` as a DWORD with the value `1`

### Example

```powershell
.\Get-OfficeTelemetryStatusStatus--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to write under the current user's `HKCU` policy hive

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Get-OfficeTelemetryStatusStatus--Detect.ps1
```

### Remediation Script

```powershell
Get-OfficeTelemetryStatusStatus--Remediate.ps1
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
2. Detection checks the current user's Office telemetry policy
3. If the policy is missing or wrong, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation creates the policy key and disables telemetry

---

# 🛡 Operational Notes

* This is a user-context policy script. Running it in system context will not update the intended user's `HKCU` hive.
* The remediation script uses `New-Item` and `New-ItemProperty` directly and does not guard against duplicate key creation beyond normal PowerShell behavior.
* The package only targets the Office telemetry policy shown in the script; it does not apply broader Office privacy settings.

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

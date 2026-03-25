# 🧠 Get-DefenderRealtimeBehaviorMonitoring – Re-enable Microsoft Defender Behavior Monitoring

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Microsoft%20Defender-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-DefenderRealtimeBehaviorMonitoring** checks whether Microsoft Defender behavior monitoring is enabled and turns it back on if it is disabled.

The detection script uses `Get-MpComputerStatus` and evaluates `BehaviorMonitorEnabled`. The remediation script uses `Set-MpPreference -DisableBehaviorMonitoring $false` to restore the feature.

This package is specifically about Defender behavior monitoring. It does not validate other protection layers such as cloud protection, real-time monitoring, or PUA protection.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-DefenderRealtimeBehaviorMonitoring
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-DefenderRealtimeBehaviorMonitoring
│
├── Get-DefenderRealtimeBehaviorMonitoring--Detect.ps1
├── Get-DefenderRealtimeBehaviorMonitoring--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-DefenderRealtimeBehaviorMonitoring--Detect.ps1
```

### Purpose

Checks whether Microsoft Defender currently reports behavior monitoring as enabled.

### Logic

1. Runs `Get-MpComputerStatus`
2. Reads `BehaviorMonitorEnabled`
3. Compares the result to `True`
4. Returns success only when behavior monitoring is active

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Behavior monitoring is enabled |
| 1    | Behavior monitoring is disabled or unreadable |

### Example

```powershell
.\Get-DefenderRealtimeBehaviorMonitoring--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-DefenderRealtimeBehaviorMonitoring--Remediate.ps1
```

### Purpose

Re-enables Microsoft Defender behavior monitoring when it has been disabled.

### Actions

The script performs the following step:

1. Runs `Set-MpPreference -DisableBehaviorMonitoring $false`

### Example

```powershell
.\Get-DefenderRealtimeBehaviorMonitoring--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* Microsoft Defender PowerShell module
* `Get-MpComputerStatus`
* `Set-MpPreference`

### Permissions

* Administrative rights are required to modify Defender settings

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Get-DefenderRealtimeBehaviorMonitoring--Detect.ps1
```

### Remediation Script

```powershell
Get-DefenderRealtimeBehaviorMonitoring--Remediate.ps1
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
2. Detection checks `BehaviorMonitorEnabled`
3. If the value is not `True`, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation re-enables Defender behavior monitoring

---

# 🛡 Operational Notes

* Detection uses the current runtime Defender state, while remediation sets the configuration preference.
* If another management source disables behavior monitoring again, the remediation may not persist.
* This package is limited to behavior monitoring only.

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

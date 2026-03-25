# ⚡ Get-DefenderRealtimeProtectionStatus – Re-enable Microsoft Defender Real-Time Monitoring

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Microsoft%20Defender-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-DefenderRealtimeProtectionStatus** checks whether Microsoft Defender real-time protection is currently enabled and turns it back on if it is disabled.

The detection script uses `Get-MpComputerStatus` and evaluates the `RealTimeProtectionEnabled` property. The remediation script uses `Set-MpPreference -DisableRealtimeMonitoring $false` to re-enable real-time monitoring.

This package is useful when Defender has been locally disabled and you want Intune to restore that setting. It does not validate other Defender protection layers such as cloud protection, PUA protection, or network protection.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-DefenderRealtimeProtectionStatus
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-DefenderRealtimeProtectionStatus
│
├── Get-DefenderRealtimeProtectionStatus--Detect.ps1
├── Get-DefenderRealtimeProtectionStatus--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-DefenderRealtimeProtectionStatus--Detect.ps1
```

### Purpose

Checks whether Microsoft Defender reports real-time protection as currently enabled.

### Logic

1. Runs `Get-MpComputerStatus`
2. Reads `RealTimeProtectionEnabled`
3. Compares the result to `True`
4. Returns success only when real-time protection is active

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Real-time protection is enabled |
| 1    | Real-time protection is disabled or unreadable |

### Example

```powershell
.\Get-DefenderRealtimeProtectionStatus--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-DefenderRealtimeProtectionStatus--Remediate.ps1
```

### Purpose

Re-enables Microsoft Defender real-time monitoring when it has been disabled.

### Actions

The script performs the following step:

1. Runs `Set-MpPreference -DisableRealtimeMonitoring $false`

### Example

```powershell
.\Get-DefenderRealtimeProtectionStatus--Remediate.ps1
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
Get-DefenderRealtimeProtectionStatus--Detect.ps1
```

### Remediation Script

```powershell
Get-DefenderRealtimeProtectionStatus--Remediate.ps1
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
2. Detection reads the current Defender runtime status
3. If `RealTimeProtectionEnabled` is not `True`, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation re-enables real-time monitoring through Defender preferences

---

# 🛡 Operational Notes

* Detection uses current Defender status, while remediation changes Defender preference.
* If another policy source is disabling Defender, the remediation may not persist.
* This package does not validate related settings such as tamper protection or passive mode.

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

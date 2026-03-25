# 🖥️ Enable-RemoteDesktop – Remote Desktop Enablement and Group Membership Change

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-RDP%20Enablement-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Enable-RemoteDesktop** is an Intune remediation package that enables Remote Desktop on the local device and adjusts Remote Desktop Users group membership.

The detection script checks two conditions:

* `fDenyTSConnections` under the Terminal Server registry key
* Whether the **Everyone** SID (`S-1-1-0`) is already a member of the local **Remote Desktop Users** group (`S-1-5-32-555`)

The remediation script enables RDP by setting `fDenyTSConnections` to `0`, disables Network Level Authentication by calling `SetUserAuthenticationRequired(0)` on the Terminal Services WMI class, and adds **Everyone** to the **Remote Desktop Users** local group if that membership is missing.

This package is operationally sensitive because it opens Remote Desktop access broadly. It should be reviewed very carefully before deployment.

---

# ✨ Core Features

### 🔹 RDP Registry Detection

* Reads `fDenyTSConnections`
* Uses the Terminal Server registry key
* Treats a non-zero value as "RDP disabled"

### 🔹 Group Membership Detection

* Checks local group SID `S-1-5-32-555`
* Looks specifically for member SID `S-1-1-0`
* Requires both RDP enablement and that group membership to report success

### 🔹 Remote Desktop Enablement

* Sets `fDenyTSConnections` to `0`
* Uses WMI to set `UserAuthenticationRequired(0)`
* Adds **Everyone** to the local Remote Desktop Users group if missing

### 🔹 Broad Access Change

* Expands remote logon scope significantly
* Changes both connection availability and authorization membership
* Does not configure firewall rules explicitly in the current script

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Enable-RemoteDesktop
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Enable-RemoteDesktop
│
├── Enable-RemoteDesktop--Detect.ps1
├── Enable-RemoteDesktop--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Enable-RemoteDesktop--Detect.ps1
```

### Purpose

Checks whether RDP is enabled and whether the local Remote Desktop Users group already contains the **Everyone** SID.

### Logic

1. Reads `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\fDenyTSConnections`
2. If the value indicates RDP is disabled, returns exit code `1`
3. If RDP is enabled, checks whether `S-1-1-0` is a member of group `S-1-5-32-555`
4. Returns exit code `0` only when both conditions are satisfied

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | RDP is enabled and the Remote Desktop Users group contains Everyone |
| 1    | RDP is disabled or the expected group membership is missing |

### Key References

* Registry: `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server`
* Value: `fDenyTSConnections`
* Group SID: `S-1-5-32-555`
* Member SID: `S-1-1-0`

### Example

```powershell
.\Enable-RemoteDesktop--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Enable-RemoteDesktop--Remediate.ps1
```

### Purpose

Enables Remote Desktop, disables NLA, and adds **Everyone** to the local Remote Desktop Users group if needed.

### Actions

1. Sets `fDenyTSConnections` to `0`
2. Calls `Win32_TSGeneralSetting.SetUserAuthenticationRequired(0)` for `RDP-tcp`
3. Checks whether `S-1-1-0` is already in `S-1-5-32-555`
4. Adds **Everyone** to the Remote Desktop Users group when missing

### Key References

* Registry: `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server`
* WMI Namespace: `root\cimv2\terminalservices`
* WMI Class: `Win32_TSGeneralSetting`
* Group SID: `S-1-5-32-555`

### Example

```powershell
.\Enable-RemoteDesktop--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to modify the Terminal Server registry key
* Permission to change local group membership
* Permission to call the Terminal Services WMI provider

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Enable-RemoteDesktop`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Enable-RemoteDesktop--Detect.ps1
```

### Remediation Script

```powershell
Enable-RemoteDesktop--Remediate.ps1
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
2. Detection checks RDP registry state and group membership
3. If either requirement is missing, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation enables RDP, disables NLA, and adds Everyone to the Remote Desktop Users group

---

# 🛡 Operational Notes

* This package materially widens remote access to the device
* The remediation script disables Network Level Authentication, which lowers the security posture of RDP
* Adding **Everyone** to the Remote Desktop Users group is a very broad authorization decision
* This package should be reviewed carefully before any production use

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

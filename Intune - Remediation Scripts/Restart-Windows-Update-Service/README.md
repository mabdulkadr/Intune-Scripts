# 🔄 Restart Windows Update Service

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Service](https://img.shields.io/badge/Service-Windows%20Update-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Restart Windows Update Service** is a PowerShell remediation solution designed to detect and resolve issues related to the **Windows Update service (wuauserv)**.

In enterprise environments, Windows Update may stop functioning correctly due to:

* Windows Update service being stopped
* Service stuck in a hung state
* Update agent synchronization issues
* System maintenance interruptions

This project provides **Detection + Remediation scripts** that automatically verify the Windows Update service status and restart it when required.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**.

---

# ✨ Core Features

### 🔹 Windows Update Service Detection

The detection script checks whether the **Windows Update service** is operating correctly.

It evaluates the service state using:

```powershell
Get-Service wuauserv
```

If the service is not running or in an unexpected state, the device is marked as **non-compliant**.

---

### 🔹 Automatic Service Restart

If a problem is detected, the remediation script performs the following actions:

* Restart the **Windows Update service**
* Validate the service status after restart
* Return appropriate exit codes for Intune compliance reporting

Typical command used:

```powershell
Restart-Service wuauserv -Force
```

---

# 📂 Project Structure

```
Restart-Windows-Update-Service
│
├── RestartWindowsUpdateService--Detect.ps1
├── RestartWindowsUpdateService--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```
RestartWindowsUpdateService--Detect.ps1
```

### Purpose

Detects whether the Windows Update service is functioning properly.

### Logic

The script performs the following checks:

1. Query the Windows Update service
2. Evaluate service status
3. Determine compliance state

### Exit Codes

| Code | Status                                      |
| ---- | ------------------------------------------- |
| 0    | Windows Update service healthy              |
| 1    | Windows Update service requires remediation |

---

# 🛠 Remediation Script

**File**

```
RestartWindowsUpdateService--Remediate.ps1
```

### Purpose

Restarts the Windows Update service to restore update functionality.

### Actions

The remediation script performs the following operations:

1. Restart Windows Update service

```powershell
Restart-Service wuauserv -Force
```

2. Validate service status

3. Return exit code based on operation result

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Permissions

Administrator privileges required.

When deployed through Intune, scripts typically run in **SYSTEM context**.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```
RestartWindowsUpdateService--Detect.ps1
```

### Remediation Script

```
RestartWindowsUpdateService--Remediate.ps1
```

### Recommended Settings

| Setting                                | Value |
| -------------------------------------- | ----- |
| Run script in 64-bit PowerShell        | Yes   |
| Run script using logged-on credentials | No    |
| Enforce script signature check         | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Script checks Windows Update service state
3. If issue detected → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script restarts the service
6. Windows Update resumes normal operation

---

# 🛡 Operational Notes

* Windows Update service interruptions can block patch deployment.
* Restarting the service resolves many temporary update issues.
* This remediation is **safe and non-disruptive** for most environments.
* Always test scripts on **pilot devices** before large-scale deployment.

---

## 📜 License

This project is licensed under the **MIT License**

https://opensource.org/licenses/MIT

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.1**

---

## ☕ Support

If this project helps you, consider supporting it:

https://www.buymeacoffee.com/mabdulkadrx

---

## ⚠ Disclaimer

This project is provided **as-is**.

- Always test scripts before production deployment.
- Validate restart policies and user experience.
- Ensure compatibility with your organization’s device management policies.

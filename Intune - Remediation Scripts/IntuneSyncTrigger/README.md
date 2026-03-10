# 🔄 Intune Management Extension Hourly Sync

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Service](https://img.shields.io/badge/Service-Intune%20Management%20Extension-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Intune Management Extension Hourly Sync** is a PowerShell automation solution designed to ensure that the **Intune Management Extension (IME)** performs regular synchronization with Microsoft Intune.

In some environments, devices may stop syncing with Intune due to stalled IME processes or missed scheduled sync events. This can cause:

* Applications not installing
* Policies not applying
* Remediation scripts not executing
* Compliance status not updating

This project provides **Detection + Remediation scripts** that automatically detect when the Intune Management Extension has not synchronized recently and enforce regular synchronization.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**.

---

# ✨ Core Features

### 🔹 IME Sync Detection

The detection script verifies whether an **IME synchronization event** has occurred within the past hour.

It analyzes **Windows Event Logs** and searches for:

```text
Event ID 208
```

Which indicates that the **Intune Management Extension completed a sync cycle**.

---

### 🔹 Automatic IME Sync Trigger

If no sync event is detected within the expected timeframe, the remediation script will:

* Trigger an **immediate IME sync**
* Create a **scheduled task** that runs every hour
* Maintain regular synchronization automatically

---

### 🔹 Enterprise Automation Ready

Designed for deployment through:

**Microsoft Intune → Devices → Scripts and Remediations**

Provides:

* Detection logic
* Automated remediation
* Exit-code based compliance reporting

---

# 📂 Project Structure

```text
Intune-IME-Sync
│
├── IntuneIMESync--Detect.ps1
├── IntuneIMESync--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
IntuneIMESync--Detect.ps1
```

### Purpose

Checks whether the **Intune Management Extension** has synchronized within the past hour.

### Logic

The script performs the following checks:

1. Query Windows Event Logs
2. Search for **Event ID 208** from IME
3. Determine whether a recent sync occurred

### Exit Codes

| Code | Status                                 |
| ---- | -------------------------------------- |
| 0    | IME sync detected within the last hour |
| 1    | No IME sync detected                   |

### Example

```powershell
.\IntuneIMESync--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
IntuneIMESync--Remediate.ps1
```

### Purpose

Forces an Intune Management Extension sync and ensures hourly synchronization.

### Actions

The remediation script performs the following operations:

### 1. Trigger Immediate IME Sync

```powershell
(New-Object -ComObject Shell.Application).Open("intunemanagementextension://syncapp")
```

### 2. Create Scheduled Task

The script creates a scheduled task with the following configuration:

| Property  | Value                     |
| --------- | ------------------------- |
| Task Name | `Trigger-IME-Sync-Hourly` |
| Account   | SYSTEM                    |
| Trigger   | Every 1 hour              |

This ensures the IME sync runs automatically on a regular basis.

### Example

```powershell
.\IntuneIMESync--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Device Enrollment

Devices must be enrolled in **Microsoft Intune**.

### Permissions

Administrator privileges required.
When deployed via Intune, scripts run in **SYSTEM context**.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
IntuneIMESync--Detect.ps1
```

### Remediation Script

```powershell
IntuneIMESync--Remediate.ps1
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
2. Script checks Event Logs for IME sync events
3. If no recent sync detected → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script forces IME sync and creates scheduled task
6. Device maintains hourly synchronization

---

# 🛡 Operational Notes

* IME normally syncs automatically, but this script ensures regular synchronization.
* The scheduled task ensures the device remains compliant with Intune policy updates.
* Always test deployment on **pilot devices** before organization-wide rollout.

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.1**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

This project is provided **as-is**.

- Always test scripts before production deployment.
- Validate restart policies and user experience.
- Ensure compatibility with your organization’s device management policies.

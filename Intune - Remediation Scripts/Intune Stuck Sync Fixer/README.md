# 🔄 Intune Stuck Sync Fixer

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Service](https://img.shields.io/badge/Service-Intune%20Management%20Extension-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Intune Stuck Sync Fixer** is a PowerShell remediation solution designed to detect and repair devices that are stuck or failing to synchronize with **Microsoft Intune**.

In some environments, devices may stop syncing due to issues with:

* Intune Management Extension (IME)
* Windows MDM scheduled tasks
* Device Management services
* Stalled policy or application sync processes

This project provides **Detection + Remediation scripts** that automatically identify devices experiencing synchronization problems and trigger corrective actions.

The solution is designed for **Microsoft Intune Proactive Remediations**, allowing administrators to automatically recover devices that fail to sync properly.

---

# ✨ Core Features

### 🔹 Sync Health Detection

The detection script checks the device synchronization health by verifying:

* Intune Management Extension status
* Device management scheduled tasks
* MDM sync task availability

It determines whether the device is able to trigger a synchronization process successfully.

---

### 🔹 Automatic Sync Recovery

If synchronization issues are detected, the remediation script performs corrective actions such as:

* Restarting **Intune Management Extension service**
* Ensuring **DmWapPushService** is running
* Triggering **Enterprise MDM scheduled tasks**
* Logging remediation activity

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
Intune-Stuck-Sync-Fixer
│
├── IntuneStuckSyncFixer--Detect.ps1
├── IntuneStuckSyncFixer--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
IntuneStuckSyncFixer--Detect.ps1
```

### Purpose

Checks whether the device is able to perform an Intune synchronization.

### Logic

The script verifies:

1. Intune Management Extension service status
2. Device management scheduled tasks
3. Sync task execution capability

### Exit Codes

| Code | Status              |
| ---- | ------------------- |
| 0    | Device sync healthy |
| 1    | Sync issue detected |

### Example

```powershell
.\IntuneStuckSyncFixer--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
IntuneStuckSyncFixer--Remediate.ps1
```

### Purpose

Fixes synchronization issues affecting Intune-managed devices.

### Actions

The remediation script performs the following operations:

1. Validate and start **Device Management Push Service**

```powershell
Start-Service DmWapPushService
```

2. Restart **Intune Management Extension**

```powershell
Restart-Service IntuneManagementExtension
```

3. Trigger all **Enterprise MDM scheduled tasks**

4. Log remediation activity to:

```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\HealthScripts.log
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Device Enrollment

Devices must be enrolled in **Microsoft Intune / MDM**.

### Permissions

Administrator privileges required.
When deployed via Intune, scripts run in **SYSTEM context**.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
IntuneStuckSyncFixer--Detect.ps1
```

### Remediation Script

```powershell
IntuneStuckSyncFixer--Remediate.ps1
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
2. Script checks device sync status
3. If sync issue detected → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script restarts services and triggers sync tasks
6. Device resumes normal Intune synchronization

---

# 🛡 Operational Notes

* This solution helps recover devices stuck in **Intune sync failure state**.
* The remediation script restarts services and triggers scheduled sync tasks.
* Logs are written to the **IME HealthScripts log** for troubleshooting.
* Always test scripts on **pilot devices** before broad deployment.

---

# 📜 License

This project is licensed under the
MIT License

[https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)

---

# 👤 Author

**Mohammad Abdelkader Omar**
Website: **momar.tech**

Version: **1.0**
Date: **2026-03-09**

---

# ☕ Support

If this project helps you, consider supporting it:

[https://www.buymeacoffee.com/mabdulkadrx](https://www.buymeacoffee.com/mabdulkadrx)

---

# ⚠ Disclaimer

This project is provided **as-is**.

* Always test scripts before production deployment
* Validate Intune management policies
* Ensure compliance with organizational device management standards

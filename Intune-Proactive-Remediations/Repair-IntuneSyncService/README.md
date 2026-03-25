# 💽 Repair-IntuneSyncService – Recover Intune Transport and Sync Tasks

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Intune%20Sync%20Repair-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Repair-IntuneSyncService** checks whether the local Intune management stack looks healthy and, when it does not, restarts the core services and triggers the EnterpriseMgmt scheduled tasks that drive device sync activity.

The detection script inspects `DmWapPushService`, the `IntuneManagementExtension` service, and the freshness of recent Intune Management Extension log activity under `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`. The remediation script makes sure the transport service is running, restarts or starts the Intune Management Extension service, and then triggers the scheduled tasks under `\Microsoft\Windows\EnterpriseMgmt\`.

This package is aimed at devices that appear stuck in Intune even though the management components are still installed.

---

# ✨ Core Features

### 🔹 Service Health Inspection

Detection queries service state through `Win32_Service` and checks:

* `DmWapPushService`
* `IntuneManagementExtension`

It can also enforce stricter expectations for service start mode through script parameters.

---

### 🔹 IME Log Freshness Check

The detection script reviews recent timestamps from several Intune Management Extension log files, including:

* `IntuneManagementExtension.log`
* `HealthIntune-Management-Scripts.log`
* `AgentExecutor.log`
* `AppWorkload.log`

If the newest activity is older than the configured threshold, the device is treated as unhealthy.

---

### 🔹 EnterpriseMgmt Task Triggering

The remediation script discovers scheduled tasks under:

```text
\Microsoft\Windows\EnterpriseMgmt\
```

It attempts to trigger them with `Start-ScheduledTask` and falls back to `schtasks.exe` if needed.

---

### 🔹 IME Service Restart Workflow

When remediation runs, it restarts or starts the `IntuneManagementExtension` service, waits briefly, and then confirms that the service returned to the running state before moving on.

---

### 🔹 Local Health Log

Remediation writes its operational output into:

```text
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\HealthIntune-Management-Scripts.log
```

This keeps the recovery log next to the other IME operational logs.

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Repair-IntuneSyncService
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Repair-IntuneSyncService
│
├── README.md
├── Repair-IntuneSyncService--Detect.ps1
└── Repair-IntuneSyncService--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Repair-IntuneSyncService--Detect.ps1
```

### Purpose

Checks whether the Intune transport path, IME service state, and recent IME log activity look healthy.

### Logic

1. Reads service state and start mode for `DmWapPushService`
2. Optionally validates `IntuneManagementExtension`
3. Parses timestamps from recent IME logs
4. Compares the newest activity against the configured age threshold
5. Returns `1` when the device appears unhealthy or stale

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Intune transport baseline looks healthy |
| 1    | One or more service or IME activity checks failed |

### Example

```powershell
.\Repair-IntuneSyncService--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Repair-IntuneSyncService--Remediate.ps1
```

### Purpose

Restarts the core Intune sync services and triggers EnterpriseMgmt sync tasks to recover a stalled management state.

### Actions

The script performs the following steps:

1. Confirms `DmWapPushService` exists and starts it if needed
2. Starts or restarts the `IntuneManagementExtension` service
3. Discovers EnterpriseMgmt scheduled tasks
4. Triggers those tasks with `Start-ScheduledTask` or `schtasks.exe`
5. Fails the remediation if no EnterpriseMgmt task can be triggered successfully

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | At least one EnterpriseMgmt sync task was triggered successfully |
| 1    | Required services or tasks could not be recovered |

### Example

```powershell
.\Repair-IntuneSyncService--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to query and manage Windows services
* Permission to query and trigger scheduled tasks
* Access to `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Repair-IntuneSyncService--Detect.ps1
```

### Remediation Script

```powershell
Repair-IntuneSyncService--Remediate.ps1
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
2. Detection checks `DmWapPushService`, IME state, and IME log freshness
3. If the management stack appears stale or unhealthy, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation starts the transport service, restarts IME, and runs EnterpriseMgmt sync tasks
6. A later detection run confirms whether activity has recovered

---

# 🛡 Operational Notes

* Detection can be tuned with parameters such as `ThresholdHours`, `RequireIME`, and `StrictStartMode`.
* The remediation script does not reinstall the Intune Management Extension. If the service is missing entirely, the package exits with failure.
* The recovery path depends on EnterpriseMgmt scheduled tasks being present on the device. If none exist, remediation cannot complete successfully.
* Detection parses CMTrace-style timestamps when possible and falls back to file write time when it cannot parse recent log lines.

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

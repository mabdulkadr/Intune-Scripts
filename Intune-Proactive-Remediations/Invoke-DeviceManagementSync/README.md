# 🔄 Invoke-DeviceManagementSync – Trigger Intune PushLaunch Sync When Stale

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Intune%20Sync-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Invoke-DeviceManagementSync** checks how long it has been since the `PushLaunch` scheduled task last ran and triggers that task when the last recorded run is older than two days.

The detection script reads scheduled task metadata for `PushLaunch`, calculates the time difference between `LastRunTime` and the current time, and exits with code `1` when the gap exceeds two days. The remediation script then starts the same scheduled task with `Start-ScheduledTask`.

This package is intended for devices where Intune or MDM-related scheduled task activity has gone stale and you want to nudge the built-in sync trigger.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Invoke-DeviceManagementSync
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Invoke-DeviceManagementSync
│
├── Invoke-DeviceManagementSync--Detect.ps1
├── Invoke-DeviceManagementSync--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Invoke-DeviceManagementSync--Detect.ps1
```

### Purpose

Checks whether the `PushLaunch` scheduled task has gone more than two days without running.

### Logic

1. Reads the `PushLaunch` scheduled task info
2. Captures `LastRunTime`
3. Calculates the age of the last run
4. Returns exit code `1` when the last run is older than two days
5. Returns exit code `0` when the task ran within the last two days

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | `PushLaunch` ran within the last 2 days |
| 1    | `PushLaunch` last ran more than 2 days ago |

### Example

```powershell
.\Invoke-DeviceManagementSync--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Invoke-DeviceManagementSync--Remediate.ps1
```

### Purpose

Starts the `PushLaunch` scheduled task to force a sync attempt.

### Actions

1. Locates the scheduled task named `PushLaunch`
2. Runs `Start-ScheduledTask` against that task

### Example

```powershell
.\Invoke-DeviceManagementSync--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* Task Scheduler
* `Get-ScheduledTask`
* `Get-ScheduledTaskInfo`
* `Start-ScheduledTask`

### Permissions

* The script must be able to read and start the `PushLaunch` scheduled task

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Invoke-DeviceManagementSync--Detect.ps1
```

### Remediation Script

```powershell
Invoke-DeviceManagementSync--Remediate.ps1
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
2. Detection checks the `PushLaunch` task's `LastRunTime`
3. If the last run is older than two days, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation starts the `PushLaunch` scheduled task

---

# 🛡 Operational Notes

* The package assumes a scheduled task named `PushLaunch` exists on the device.
* It measures task age, not whether the previous sync was actually successful.
* If the task name differs across device builds or management configurations, this workflow will fail.

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

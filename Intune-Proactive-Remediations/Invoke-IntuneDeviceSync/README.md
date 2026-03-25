# 💽 Invoke-IntuneDeviceSync – Intune Management Extension Sync Trigger Workflow

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Intune%20Sync%20Trigger-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Invoke-IntuneDeviceSync** is an Intune remediation package that checks whether Intune Management Extension sync activity has occurred recently and, if not, triggers a sync immediately and schedules recurring hourly sync.

The detection script searches the `Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational` event log for Event ID `208` within the configured lookback window. If that event is missing, it accepts the presence of the fallback scheduled task `Trigger-IME-Sync-Hourly` as an alternate healthy state. The remediation script triggers the `intunemanagementextension://syncapp` URI through `Shell.Application` and then creates or updates an hourly scheduled task that repeats the same action.

This folder is useful when the device needs a more aggressive Intune sync trigger than the default background cadence.

---

# ✨ Core Features

### 🔹 Event-Based Detection

* Reads the Intune diagnostics event log
* Looks for Event ID `208` within the configured lookback window
* Treats recent IME sync activity as compliant

### 🔹 Scheduled Task Fallback

* Checks whether `Trigger-IME-Sync-Hourly` exists and is enabled
* Accepts the scheduled task as an alternate healthy state when a recent event is not present
* Avoids triggering remediation repeatedly when the recurring sync task is already configured

### 🔹 Immediate IME Sync Trigger

* Uses `Shell.Application` to open `intunemanagementextension://syncapp`
* Forces an immediate Intune Management Extension sync attempt
* Runs before the recurring task is created or updated

### 🔹 Recurring Hourly Sync

* Creates or updates a scheduled task running as `SYSTEM`
* Uses `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, and `Register-ScheduledTask`
* Repeats the IME sync action every hour

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Invoke-IntuneDeviceSync
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Invoke-IntuneDeviceSync
│
├── Invoke-IntuneDeviceSync--Detect.ps1
├── Invoke-IntuneDeviceSync--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Invoke-IntuneDeviceSync--Detect.ps1
```

### Purpose

Checks whether Intune Management Extension sync activity occurred recently enough to avoid running remediation.

### Logic

1. Reads the `Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational` log
2. Filters for Event ID `208` within the last configured hour
3. If no recent event is found, checks whether `Trigger-IME-Sync-Hourly` exists and is enabled
4. Returns exit code `1` only when neither the recent event nor the fallback scheduled task is present

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Recent IME sync activity was found, or the fallback task already exists |
| 1    | No recent IME sync activity was found and the fallback task is missing or disabled |

### Key References

* Event Log: `Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational`
* Event ID: `208`
* Scheduled Task: `Trigger-IME-Sync-Hourly`

### Example

```powershell
.\Invoke-IntuneDeviceSync--Detect.ps1
```

---

## 🛠️ Remediation Script

**File**

```powershell
Invoke-IntuneDeviceSync--Remediate.ps1
```

### Purpose

Triggers Intune Management Extension sync immediately and ensures a recurring hourly sync task exists on the device.

### Actions

1. Opens `intunemanagementextension://syncapp` by using `Shell.Application`
2. Builds a hidden PowerShell scheduled task action that repeats the same URI launch
3. Creates or updates `Trigger-IME-Sync-Hourly`
4. Registers the task to run as `SYSTEM` with the highest run level

### Key References

* URI: `intunemanagementextension://syncapp`
* Scheduled Task: `Trigger-IME-Sync-Hourly`
* Log Path: `<SystemDrive>\Intune\Invoke-Invoke-IntuneDeviceSync`

### Example

```powershell
.\Invoke-IntuneDeviceSync--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to read the target event log
* Permission to create or update Scheduled Tasks
* Permission to instantiate `Shell.Application`

### Runtime Dependencies

* Intune Management Extension installed on the device
* `Shell.Application` COM automation available
* Scheduled Tasks infrastructure available and healthy

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Invoke-IntuneDeviceSync--Detect.ps1
```

### Remediation Script

```powershell
Invoke-IntuneDeviceSync--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Review script context |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks the IME event log for recent sync activity
3. If no recent event is found, detection checks for the fallback scheduled task
4. If neither condition is satisfied, detection exits with code `1`
5. Intune runs the **Remediation Script**
6. Remediation triggers IME sync immediately and then creates or updates the hourly sync task

---

# 🛡️ Operational Notes

* The package uses an event-log signal and a scheduled-task fallback instead of checking an Intune API response
* The remediation log path is `<SystemDrive>\Intune\Invoke-Invoke-IntuneDeviceSync` because that is how the script currently defines `$SolutionName`
* The sync trigger relies on the IME URI handler being available on the device
* Test the scheduled task behavior on pilot devices before broad rollout

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

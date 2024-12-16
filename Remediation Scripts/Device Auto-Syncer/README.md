# Detect and Remediate AutoSync Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview
This repository contains two PowerShell scripts designed to detect and remediate synchronization issues related to the "PushLaunch" scheduled task in Intune.

### Scripts Included
1. **Detect_AutoSync.ps1**
   - Detects if the "PushLaunch" scheduled task has synced within the last 2 days.
2. **Remediate_AutoSync.ps1**
   - Forces the "PushLaunch" scheduled task to sync if the last sync exceeds the acceptable time window.

---

## Scripts Details

### 1. Detect_AutoSync.ps1

#### Purpose
This script retrieves the last run time of the "PushLaunch" scheduled task and compares it to the current date and time. It flags the task if the last sync was more than 2 days ago.

#### How to Run
```powershell
.\Detect_AutoSync.ps1
```

#### Outputs
- **Sync is up to date.**: Indicates the sync occurred within the last 2 days.
- **Last sync was more than 2 days ago.**: Indicates the task needs remediation.

---

### 2. Remediate_AutoSync.ps1

#### Purpose
This script starts the "PushLaunch" scheduled task to trigger a sync operation, ensuring the task is executed manually.

#### How to Run
```powershell
.\Remediate_AutoSync.ps1
```

#### Outputs
- **Success**: The scheduled task started successfully.
- **Error**: Details any issues encountered while attempting to start the task.

---

## Notes
- Ensure you have administrative privileges to run these scripts.
- Designed for environments using Intune and "PushLaunch" scheduled tasks for synchronization.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.

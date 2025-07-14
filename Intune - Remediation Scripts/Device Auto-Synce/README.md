# Detect and Remediate AutoSync Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.1-green.svg)

## Overview
These two PowerShell scripts are designed to troubleshoot and resolve synchronization issues for devices enrolled in Microsoft Intune. Devices that fail to sync for more than 2 days can fall out of compliance and miss important updates or policies. These scripts detect such issues and initiate corrective actions by working with the "PushLaunch" scheduled task.

### Scripts Included
1. **Detect_AutoSync.ps1**
   - Checks the last synchronization time of Intune-managed devices and identifies devices that haven't synced within the past 2 days.
2. **Remediate_AutoSync.ps1**
   - Starts or creates the "PushLaunch" scheduled task to force an immediate synchronization for non-compliant devices.

---

## Scripts Details

### 1. Detect_AutoSync.ps1

#### Purpose
This script ensures that Intune-managed devices stay in compliance by checking the "PushLaunch" scheduled task's last run time. It calculates the time difference between the last synchronization and the current time to determine if action is required.

#### How to Run
```powershell
.\Detect_AutoSync.ps1
```

#### Outputs
- **Sync is up to date.**: Indicates the device synchronized successfully within the last 2 days.
- **Last sync was more than 2 days ago.**: Alerts that the device is overdue for a sync.

#### Use Cases
- Identify devices that are not synchronizing with Intune on schedule.
- Proactively prevent compliance and update delays.

---

### 2. Remediate_AutoSync.ps1

#### Purpose
This script addresses detected synchronization issues by starting the "PushLaunch" scheduled task. If the task is missing, it creates the task to ensure synchronization with Intune is forced immediately.

#### How to Run
```powershell
.\Remediate_AutoSync.ps1
```

#### Outputs
- **Success**: Confirms that the task was started or created successfully.
- **Error**: Logs details of any issues encountered during execution.

#### Use Cases
- Quickly restore synchronization functionality for out-of-compliance devices.
- Automate remediation for Intune-enrolled devices with sync issues.

---

## Notes
- **Administrative Privileges**: Both scripts require administrative permissions to execute.
- **Intune-Specific**: These scripts are specifically designed for environments using Intune's "PushLaunch" task for device management.
- **Standalone Tools**: The scripts are not part of a repository but serve as individual troubleshooting tools.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.


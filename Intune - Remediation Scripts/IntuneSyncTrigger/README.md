# Intune Management Extension Sync Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
This Project contains two PowerShell scripts designed to detect and remediate issues related to **Intune Management Extension (IME) sync**. 

- **Detection Script**: Checks if IME sync has occurred within the last hour using Event Logs.
- **Remediation Script**: Triggers the IME sync immediately and creates a scheduled task to ensure the sync runs every hour.

---

## Scripts Included

1. **Detect_HourlyIMESync.ps1**  
   - Detects if the Intune Management Extension sync occurred in the past hour.

2. **Remediate_HourlyIMESync.ps1**  
   - Triggers IME sync immediately and sets up an hourly scheduled task to maintain compliance.

---

## Script Details

### 1. Detect_HourlyIMESync.ps1

#### Purpose
Detects whether the Intune Management Extension has synchronized within the past hour by scanning Event Logs for **Event ID 208**.

#### How to Run
```powershell
.\Detect_HourlyIMESync.ps1
```

#### Outputs
- **Compliance**: "Intune Management Extension Sync detected within the last hour." (Exit Code: `0`)
- **Non-Compliance**: "No Intune Management Extension Sync detected within the last hour." (Exit Code: `1`)

---

### 2. Remediate_HourlyIMESync.ps1

#### Purpose
Forces an immediate IME sync and creates a scheduled task to trigger the sync every hour for consistent compliance.

#### How to Run
```powershell
.\Remediate_HourlyIMESync.ps1
```

#### Key Actions
1. Triggers IME Sync using the `Shell.Application` COM object:
   ```powershell
   (New-Object -ComObject Shell.Application).Open("intunemanagementextension://syncapp")
   ```
2. Creates a scheduled task named **"Trigger-IME-Sync-Hourly"**:
   - Runs every hour using the SYSTEM account.

#### Outputs
- Immediate IME Sync triggered.
- Scheduled Task created:
  - **Name**: `Trigger-IME-Sync-Hourly`
  - **Trigger**: Runs hourly.

---

## How to Deploy via Intune

### Detection Script
1. Upload `Detect_HourlyIMESync.ps1` as a **Detection Script** in Intune:
   - **Purpose**: Evaluate IME sync status.
   - Exit Code `0` = Compliance.
   - Exit Code `1` = Non-compliance.

### Remediation Script
1. Upload `Remediate_HourlyIMESync.ps1` as a **Remediation Script**:
   - Triggers IME sync.
   - Sets up an hourly scheduled task to enforce regular IME sync.

---

## Notes
- These scripts require administrative privileges.
- Intended for Windows 10/11 devices managed by Microsoft Intune.

## License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**:  
These scripts are provided as-is. Test in a staging environment before deploying to production. The author is not responsible for any unintended outcomes resulting from their use.


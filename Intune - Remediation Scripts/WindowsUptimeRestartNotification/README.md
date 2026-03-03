# Windows Uptime Restart Notification

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)
![Intune](https://img.shields.io/badge/Microsoft%20Intune-Proactive%20Remediations-green.svg)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-lightgrey.svg)

## Overview
This solution detects devices that should be restarted, then shows an Arabic WPF restart prompt through Intune Proactive Remediations.

The device is marked **Not Compliant** when either condition is true:
- Pending reboot required by Windows updates
- Device uptime is greater than or equal to the configured threshold

## Files
- `Detect_WindowsUptimeRestartNotification.ps1`
- `Remediate_WindowsUptimeRestartNotification.ps1`

## Detection Logic
`Detect_WindowsUptimeRestartNotification.ps1` checks:
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired`
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`
- Uptime using `Win32_OperatingSystem.LastBootUpTime`

Exit codes:
- `0` = Compliant
- `1` = Not Compliant

## Remediation Behavior
`Remediate_WindowsUptimeRestartNotification.ps1` shows a custom **WPF** dialog (not toast) in Arabic with:
- Restart now
- Restart after 1 hour
- Restart after 2 hours
- Close

Default behavior:
- Shows notice when update reboot is pending or uptime threshold is reached
- Does not force restart unless configured

## Key Settings
Update these values based on your policy:

- In `Detect_WindowsUptimeRestartNotification.ps1`:
  - `$MaxUptimeDays` (current default: `10`)
- In `Remediate_WindowsUptimeRestartNotification.ps1`:
  - `$MaxUptimeDays` (current default: `10`)
  - `$ForceRestartWhenPending` (`$false` by default)
  - `$GraceSeconds` (restart grace period when force mode is enabled)
  - Branding/text variables (`$Txt_*`, `$Brand_LogoFile`, `$LogoBase64`)

Keep `$MaxUptimeDays` aligned in both scripts.

## Intune Deployment
1. Go to **Intune Admin Center** > **Devices** > **Scripts and remediations**.
2. Create a new **Proactive remediation** package.
3. Upload:
   - Detection: `Detect_WindowsUptimeRestartNotification.ps1`
   - Remediation: `Remediate_WindowsUptimeRestartNotification.ps1`
4. Recommended script settings:
   - Run script using logged-on credentials: `Yes`
   - Run script in 64-bit PowerShell: `Yes`
5. Assign to a pilot group first, then expand.

## Operational Notes
- Save scripts as **UTF-8 with BOM** to preserve Arabic text in Windows PowerShell 5.1.
- Remediation UI requires an interactive user session.
- If detection is triggered too frequently, adjust schedule cadence or threshold.

## Quick Local Validation
```powershell
# Detection
.\Detect_WindowsUptimeRestartNotification.ps1

# Remediation (run in user session)
.\Remediate_WindowsUptimeRestartNotification.ps1
```

## Troubleshooting
- No window appears:
  - Verify remediation runs in user context.
  - Confirm device has an interactive logged-on session.
- Non-compliant devices not remediating:
  - Check proactive remediation assignment and run history.
  - Ensure detection and remediation scripts were both uploaded from this folder.

---
Use in pilot first and validate behavior before broad production rollout.

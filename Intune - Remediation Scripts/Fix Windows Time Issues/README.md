
# Fix Windows Time and Time Zone Issues Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview

This Project contains two PowerShell scripts designed to detect and remediate time-related issues on Windows devices. These scripts ensure that the system is compliant with proper time synchronization settings, automatic time zone detection, and the Windows Time service configuration.

---

## Scripts Included

1. **Detect-TimeIssues.ps1**
   - Detects compliance for time-related settings, including:
     - Windows Time service status.
     - Automatic time synchronization.
     - Automatic time zone detection.

2. **Remediate-TimeIssues.ps1**
   - Fixes non-compliance issues by:
     - Starting and configuring the Windows Time service.
     - Enabling automatic time synchronization with a specified time server.
     - Enabling automatic time zone detection.

---

## Scripts Details

### 1. Detect-TimeIssues.ps1

#### Purpose
This script checks if:
- The Windows Time service is running.
- Automatic time synchronization is configured.
- Automatic time zone detection is enabled.

#### How to Run
```powershell
.\Detect-TimeIssues.ps1
```

#### Outputs
- **Compliant**: All time-related settings are configured correctly.
- **NonCompliant**: Displays which settings are non-compliant and exits with code `1`.
- **Error**: Logs any errors encountered during execution and exits with code `2`.

---

### 2. Remediate-TimeIssues.ps1

#### Purpose
This script remediates time-related issues by:
- Ensuring the Windows Time service is running and set to start automatically.
- Configuring time synchronization with `time.windows.com`.
- Enabling automatic time zone detection.

#### How to Run
```powershell
.\Remediate-TimeIssues.ps1
```

#### Outputs
- Provides step-by-step logs of actions taken, including:
  - Starting the Windows Time service.
  - Configuring and forcing time synchronization.
  - Enabling automatic time zone detection.
  - Restarting the Location service if applicable.

---

## Usage

1. Run the **Detect-TimeIssues.ps1** script to check compliance:
   ```powershell
   .\Detect-TimeIssues.ps1
   ```

2. If non-compliance is detected, run the **Remediate-TimeIssues.ps1** script to fix the issues:
   ```powershell
   .\Remediate-TimeIssues.ps1
   ```

---

## Notes

- These scripts must be run with administrative privileges to modify system settings.
- The remediation script uses `time.windows.com` as the default NTP server. You can update this value in the script if needed.
- The scripts are designed for environments where Group Policy does not enforce conflicting settings.

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.

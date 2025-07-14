# Windows Update Troubleshooting Proactive Remediation

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
This project includes two PowerShell scripts designed to detect and remediate Windows Update issues using **Microsoft Intune Proactive Remediations**. The scripts ensure that Windows Update components are functioning correctly and address common issues automatically.

### Scripts Included
1. **Detect_Windows_Update_Troubleshooting.ps1**
   - Detects issues with Windows Updates, such as outdated OS versions and delays in updates.
2. **Remediate_Windows_Update_Troubleshooting.ps1**
   - Attempts to resolve detected Windows Update issues by troubleshooting, repairing, and resetting relevant components.

---

## Scripts Details

### 1. Detect_Windows_Update_Troubleshooting.ps1

#### Purpose
The detection script checks the following:
- The OS version to ensure it meets the required build for Windows 10 or Windows 11.
- The time since the last Windows update was installed.
- Any registry keys indicating paused or deferred updates.

#### How to Run
```powershell
.\Detect_Windows_Update_Troubleshooting.ps1
```

#### Outputs
- **Exit Code 1**: Issue detected (e.g., outdated OS version, updates delayed).
- **Exit Code 0**: No issues found.

---

### 2. Remediate_Windows_Update_Troubleshooting.ps1

#### Purpose
The remediation script automatically fixes issues detected by the detection script. It performs the following tasks:
- Runs the Windows Update Troubleshooter.
- Repairs the system image using **DISM**.
- Resets Windows Update components.
- Removes paused or deferred update configurations from the registry.
- Ensures required PowerShell modules are installed.
- Checks for pending Windows updates and installs them.

#### How to Run
```powershell
.\Remediate_Windows_Update_Troubleshooting.ps1
```

#### Outputs
- Logs are saved at:
  - **C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\#Windows_Updates_Health_Check.log**
  - **C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\#DISM.log**
- **Exit Code 0**: Remediation successful.
- **Exit Code 1**: Remediation failed or encountered an error.

---

## Deployment via Microsoft Intune Proactive Remediation
1. Navigate to **Intune Admin Center**:
   - Go to **Devices > Scripts and Remediations**.
2. Create a new Proactive Remediation package:
   - **Detection Script**: Upload `Detect_Windows_Update_Troubleshooting.ps1`.
   - **Remediation Script**: Upload `Remediate_Windows_Update_Troubleshooting.ps1`.
3. Assign the package to the target devices or groups.
4. Monitor the results in the Intune portal.

---

## Notes
- Ensure both scripts are tested in a controlled environment before deploying to production.
- Scripts require administrative privileges to execute correctly.
- Logs are saved for troubleshooting purposes.

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.


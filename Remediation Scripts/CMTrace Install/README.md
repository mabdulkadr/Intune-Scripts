
# CMTrace Installation and Compliance Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)

## Overview
This repository contains two PowerShell scripts designed to manage and monitor the installation and compliance of CMTrace.exe on Windows systems. CMTrace is a useful tool for analyzing log files in SCCM (System Center Configuration Manager) environments.

### Scripts Included
1. **Remediate-cmtrace.ps1**
   - Installs CMTrace.exe to the `C:\Windows\System32` directory from a specified repository URL.
2. **Detect-cmtrace.ps1**
   - Detects whether CMTrace.exe is present on the system and outputs compliance status.

---

## Scripts Details

### 1. `Remediate-cmtrace.ps1`

#### Purpose
Downloads CMTrace.exe from a repository and installs it into the `C:\Windows\System32` directory.

#### How to Run
```powershell
.\Remediate-cmtrace.ps1.ps1
```

#### Outputs
- **Log Output**: Provides timestamped logs about the installation process.
- **Success Message**: Confirms successful installation of CMTrace.exe.
- **Error Message**: Indicates errors during the installation process.

---

### 2. `Detect-cmtrace.ps1`

#### Purpose
Checks if CMTrace.exe exists in the `C:\Windows\System32` directory and reports the compliance status.

#### How to Run
```powershell
.\detect-cmtrace.ps1
```

#### Outputs
- **Compliant**: Outputs "Compliant" if CMTrace.exe is found and exits with code 0.
- **Not Compliant**: Outputs "Not Compliant" if CMTrace.exe is not found and exits with code 1.
- **Log Output**: Provides timestamped logs about the compliance check.

---

## Notes
- Ensure you have administrative privileges to run these scripts.
- Verify internet connectivity before running the installation script to download CMTrace.exe.

## License
This project is licensed under the [MIT License](LICENSE).

---

**Disclaimer**: Use these scripts at your own risk. Always test scripts in a lab environment before deploying them in production.

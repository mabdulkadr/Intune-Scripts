# Disable IPv6 on All Network Interfaces
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-7.0%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

This repository contains two PowerShell scripts designed to manage IPv6 settings on Windows systems:

- **Detection Script**: Checks if IPv6 is disabled on all network interfaces.
- **Remediation Script**: Disables IPv6 on all network interfaces and updates the system registry to ensure IPv6 components are disabled.

A system restart is required after running the remediation script for the changes to take full effect.

## Contents

- `Detect-IPv6Disabled.ps1`: Detection script.
- `Remediate-DisableIPv6.ps1`: Remediation script.

## Prerequisites

- Windows PowerShell (Run scripts with administrative privileges).
- Windows operating system with network interfaces supporting IPv6.

## Scripts Details

### Detection Script: `Detect-IPv6Disabled.ps1`

#### Synopsis

Detects whether IPv6 is disabled on all network interfaces.

#### Description

This PowerShell script checks if IPv6 is currently disabled on all network adapters. If any network adapter still has IPv6 enabled, the script will return a non-compliant state.

#### Example

```powershell
.\Detect-IPv6Disabled.ps1
```

### Remediation Script: `Remediate-DisableIPv6.ps1`

#### Synopsis

Disables IPv6 on all network interfaces and updates the system registry.

#### Description

This PowerShell script automates the process of disabling IPv6 bindings on all network interfaces and updates the registry to disable IPv6 components. The changes will take effect after a system restart.

#### Example

```powershell
.\Remediate-DisableIPv6.ps1
```

## Usage Instructions

### Running the Detection Script

1. Open PowerShell with administrative privileges.
2. Navigate to the directory containing the scripts.
3. Execute the detection script:

   ```powershell
   .\Detect-IPv6Disabled.ps1
   ```

4. The script will output whether the system is compliant (IPv6 disabled on all interfaces) or non-compliant.

### Running the Remediation Script

1. Open PowerShell with administrative privileges.
2. Navigate to the directory containing the scripts.
3. Execute the remediation script:

   ```powershell
   .\Remediate-DisableIPv6.ps1
   ```

4. The script will disable IPv6 on all network interfaces and update the registry.
5. Restart the system to apply the changes fully.

## Script Outputs

- **Detection Script**:
  - Outputs "Compliant" if IPv6 is disabled on all interfaces.
  - Outputs "Non-compliant" if IPv6 is enabled on one or more interfaces.
- **Remediation Script**:
  - Outputs the status of each interface as IPv6 is disabled.
  - Notifies if the registry is updated successfully.
  - Prompts for a system restart to apply changes.

## Error Handling

Both scripts include basic error handling:

- The detection script will inform you if an unexpected error occurs.
- The remediation script uses `try-catch` blocks to handle exceptions when disabling IPv6 on interfaces or updating the registry.

## Important Notes

- **Administrative Privileges**: Both scripts must be run as an administrator to make the necessary system changes.
- **System Restart**: A restart is required after running the remediation script to ensure all changes take effect.
- **Impact on Applications**: Disabling IPv6 may affect applications or services that rely on IPv6 connectivity.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.


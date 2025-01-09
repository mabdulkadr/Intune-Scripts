# Secure Channel Detection and Remediation Scripts for Intune
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)

## Overview

These scripts are designed to detect and remediate the **"Trust relationship between this workstation and the primary domain failed"** error. This issue occurs when a computer's secure channel with the domain controller is broken. The scripts are optimized for deployment via **Microsoft Intune Proactive Remediations**.

### What Causes This Issue?
This error typically occurs when:
1. A computer account password on the domain controller and the local computer are out of sync.
2. The computer is restored from an old system image or snapshot.
3. A long period of disconnection between the device and the domain.

### Key Features
- **Detection Script**: Identifies if the computer's secure channel with the domain is intact.
- **Remediation Script**: Repairs the secure channel automatically using the current session credentials.

---

## Scripts Included

### 1. `Detect-DomainConnectivity.ps1`

#### Purpose
Detects if the computer's secure channel with the domain is functional, preventing the **trust relationship error**.

#### How It Works
- Uses the `Test-ComputerSecureChannel` cmdlet to check the secure channel's status.
- If the secure channel is intact, the script exits with code `0`.
- If the secure channel is broken, the script exits with code `1`, triggering remediation.

---

### 2. `Remediate-SecureChannel.ps1`

#### Purpose
Repairs the computer's secure channel with the domain, fixing the **trust relationship error**.

#### How It Works
- Uses the `Test-ComputerSecureChannel -Repair` cmdlet to reset the secure channel between the computer and the domain.
- Automatically uses the current session credentials, avoiding manual credential input.

---

## How to Use in Intune Proactive Remediations

1. **Create a Proactive Remediation**:
   - Navigate to **Microsoft Intune Admin Center** > **Devices** > **Scripts and remediations**.
   - Click **+ Create**.

2. **Upload Scripts**:
   - **Detection Script**: Upload `Detect-DomainConnectivity.ps1`.
   - **Remediation Script**: Upload `Remediate-SecureChannel.ps1`.

3. **Assign**:
   - Target the remediation package to the relevant device groups.

---

## Example Outputs

### Detection Script
- **Success**:
  ```
  Secure channel with the domain is intact.
  Exit Code: 0
  ```
- **Failure**:
  ```
  Secure channel with the domain is broken.
  Exit Code: 1
  ```

### Remediation Script
- **Success**:
  ```
  Secure channel repaired successfully.
  Exit Code: 0
  ```
- **Failure**:
  ```
  Error while repairing the secure channel: [Error Details]
  Exit Code: 1
  ```

---

## Notes
- Ensure the script runs with sufficient permissions (e.g., SYSTEM account in Intune).
- These scripts are designed for **Windows devices** joined to a domain.
- For large-scale deployments, consider testing the scripts in a staging environment first.

### Alternative Solutions
- Rejoin the computer to the domain manually or via PowerShell.
- Use third-party tools for repairing trust relationships.

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.





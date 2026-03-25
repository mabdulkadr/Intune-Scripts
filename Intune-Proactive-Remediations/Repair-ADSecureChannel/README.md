# 🔗 Repair-ADSecureChannel – Domain Trust Detection and Repair

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Domain%20Trust%20Repair-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Repair-ADSecureChannel** is an Intune remediation package for domain-joined devices that have lost a healthy computer trust relationship with Active Directory.

The detection script first checks whether the device is actually domain-joined by using `Get-CimInstance Win32_ComputerSystem`. If the device is not joined to a domain, the package exits successfully because the secure channel test is not applicable. For domain-joined devices, it runs `Test-ComputerSecureChannel` and flags the device for remediation only when that trust check fails.

The remediation script follows the same domain-join check, then runs `Test-ComputerSecureChannel -Repair` to repair the broken machine secure channel. A reboot toggle exists in the script, but it is disabled by default.

This package is appropriate when you need to repair stale or broken domain trust from Intune without rejoining the device manually.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Repair-ADSecureChannel
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Repair-ADSecureChannel
│
├── README.md
├── Repair-ADSecureChannel--Detect.ps1
└── Repair-ADSecureChannel--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Repair-ADSecureChannel--Detect.ps1
```

### Purpose

Checks whether the device is domain-joined and whether its computer secure channel is healthy.

### Logic

1. Reads `Win32_ComputerSystem`
2. Exits successfully if the device is not domain-joined
3. Runs `Test-ComputerSecureChannel` on domain-joined devices
4. Returns exit code `1` only when the secure channel test fails or detection errors out

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Secure channel is healthy, or the device is not domain-joined |
| 1    | Secure channel is broken or detection failed |

### Key References

* CIM Class: `Win32_ComputerSystem`
* Command: `Test-ComputerSecureChannel`

### Example

```powershell
.\Repair-ADSecureChannel--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Repair-ADSecureChannel--Remediate.ps1
```

### Purpose

Repairs the machine secure channel for domain-joined devices by using the built-in PowerShell repair command.

### Actions

1. Confirms the device is domain-joined
2. Exits successfully if secure channel repair is not applicable
3. Runs `Test-ComputerSecureChannel -Repair`
4. Optionally supports a delayed reboot through a script flag, though that flag is currently disabled

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Repair completed successfully, or the device was not domain-joined |
| 1    | Repair failed |

### Key References

* CIM Class: `Win32_ComputerSystem`
* Command: `Test-ComputerSecureChannel -Repair`

### Example

```powershell
.\Repair-ADSecureChannel--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* The scripts are intended to run as `System`
* The device must be able to contact domain services for a meaningful repair

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Repair-ADSecureChannel`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Repair-ADSecureChannel--Detect.ps1
```

### Remediation Script

```powershell
Repair-ADSecureChannel--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks whether the machine is domain-joined
3. If the device is joined, detection tests the secure channel
4. If the trust is broken, detection exits with code `1`
5. Intune runs the **Remediation Script**
6. Remediation repairs the secure channel by using `Test-ComputerSecureChannel -Repair`

---

# 🛡 Operational Notes

* This package is intentionally no-op on non-domain devices
* It repairs the secure channel but does not perform a domain rejoin
* The reboot option exists in the script but is disabled by default
* Test carefully on pilot devices, especially if machine account passwords or domain connectivity are already under investigation

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

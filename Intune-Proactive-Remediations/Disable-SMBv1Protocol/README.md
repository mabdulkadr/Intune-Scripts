# 🚫 Disable-SMBv1Protocol – SMBv1 Server Protocol Disablement

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-SMBv1%20Disablement-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Disable-SMBv1Protocol** is an Intune remediation package that checks whether the SMBv1 server protocol is enabled and disables it when necessary.

The detection script reads the current SMB server configuration by using `Get-SmbServerConfiguration` and checks the `EnableSMB1Protocol` property. The remediation script then disables SMBv1 by running:

```powershell
Set-SmbServerConfiguration -EnableSMB1Protocol 0
```

This package is useful as a baseline hardening measure for devices that should not expose legacy SMBv1 support.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Disable-SMBv1Protocol
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Disable-SMBv1Protocol
│
├── Disable-SMBv1Protocol--Detect.ps1
├── Disable-SMBv1Protocol--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Disable-SMBv1ProtocolProtocol--Detect.ps1
```

### Purpose

Checks whether the SMBv1 server protocol is already disabled.

### Logic

1. Reads `EnableSMB1Protocol` from `Get-SmbServerConfiguration`
2. Returns exit code `0` when the value is `$false`
3. Returns exit code `1` when SMBv1 is enabled

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | SMBv1 is disabled |
| 1    | SMBv1 is enabled |

### Key References

* Command: `Get-SmbServerConfiguration`
* Property: `EnableSMB1Protocol`

### Example

```powershell
.\Disable-SMBv1ProtocolProtocol--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Disable-SMBv1ProtocolProtocol--Remediate.ps1
```

### Purpose

Disables the SMBv1 server protocol on the local device.

### Actions

1. Runs `Set-SmbServerConfiguration`
2. Sets `EnableSMB1Protocol` to `0`

### Key References

* Command: `Set-SmbServerConfiguration -EnableSMB1Protocol 0`

### Example

```powershell
.\Disable-SMBv1ProtocolProtocol--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to query and modify SMB server configuration

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Disable-SMBv1ProtocolProtocol`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Disable-SMBv1ProtocolProtocol--Detect.ps1
```

### Remediation Script

```powershell
Disable-SMBv1ProtocolProtocol--Remediate.ps1
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
2. Detection checks `EnableSMB1Protocol`
3. If SMBv1 is enabled, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation disables SMBv1 through the SMB server configuration cmdlet

---

# 🛡 Operational Notes

* The current script files still contain duplicated generated blocks, but the effective behavior is the SMB configuration check and disable action described above
* Disabling SMBv1 can affect legacy applications or devices that still depend on it
* Test on pilot devices before broad deployment in mixed or older network environments

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

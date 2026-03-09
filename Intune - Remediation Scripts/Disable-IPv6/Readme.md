# 🌐 Disable IPv6 on Windows Devices

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Network](https://img.shields.io/badge/Network-IPv6-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Disable IPv6 on Windows Devices** is a PowerShell automation solution designed to detect and disable IPv6 across all network interfaces on Windows systems.

In some enterprise environments, IPv6 may not be required or may conflict with legacy applications, internal services, or network policies. In such cases, administrators may choose to disable IPv6 to ensure consistent network behavior.

This project provides **Detection + Remediation scripts** that automatically verify the IPv6 configuration and disable it when necessary.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**, allowing organizations to enforce IPv6 configuration across managed endpoints.

---

# ✨ Core Features

### 🔹 Automatic IPv6 Detection

The detection script verifies whether IPv6 is currently disabled across all network adapters.

It evaluates adapter bindings and determines whether remediation is required.

---

### 🔹 Automatic IPv6 Remediation

If IPv6 is enabled on any interface:

* IPv6 bindings are disabled on all network adapters
* Registry settings are updated to disable IPv6 components
* System configuration is aligned with the desired network policy

---

### 🔹 Enterprise Automation Ready

Designed for deployment through:

**Microsoft Intune → Devices → Scripts and Remediations**

Provides:

* Detection logic
* Automated remediation
* Exit-code based compliance reporting

---

# 📂 Project Structure

```text
Disable-IPv6
│
├── DisableIPv6--Detect.ps1
├── DisableIPv6--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
DisableIPv6--Detect.ps1
```

### Purpose

Checks whether IPv6 is disabled on all network interfaces.

### Logic

1. Enumerate all network adapters
2. Check IPv6 binding status
3. Determine compliance state

### Exit Codes

| Code | Status                       |
| ---- | ---------------------------- |
| 0    | Compliant (IPv6 disabled)    |
| 1    | Non-compliant (IPv6 enabled) |

### Example

```powershell
.\DisableIPv6--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
DisableIPv6--Remediate.ps1
```

### Purpose

Disables IPv6 across all network adapters and updates the system configuration.

### Actions

The remediation script performs the following steps:

1. Detect available network adapters
2. Disable IPv6 binding on each adapter
3. Update system registry configuration
4. Confirm IPv6 components are disabled

Example execution:

```powershell
.\DisableIPv6--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Permissions

Administrator privileges are required to modify network adapter settings and registry configuration.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
DisableIPv6--Detect.ps1
```

### Remediation Script

```powershell
DisableIPv6--Remediate.ps1
```

### Recommended Settings

| Setting                                | Value |
| -------------------------------------- | ----- |
| Run script in 64-bit PowerShell        | Yes   |
| Run script using logged-on credentials | No    |
| Enforce script signature check         | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Script checks IPv6 configuration
3. If IPv6 enabled → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script disables IPv6 on all adapters
6. System configuration becomes compliant

---

# 🛡 Operational Notes

* A **system restart may be required** for all changes to fully apply.
* Some applications or services may require IPv6 connectivity.
* Test the configuration in **pilot environments** before full deployment.
* Ensure network policies allow IPv6 to be disabled.

---

# 📜 License

This project is licensed under the
MIT License

[https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)

---

# 👤 Author

**Mohammad Abdelkader Omar**
Website: **momar.tech**

Version: **1.0**
Date: **2026-03-09**

---

# ☕ Support

If this project helps you, consider supporting it:

[https://www.buymeacoffee.com/mabdulkadrx](https://www.buymeacoffee.com/mabdulkadrx)

---

# ⚠ Disclaimer

This tool is provided **as-is**.

* Always test scripts before production deployment
* Verify network configuration impact
* Ensure compliance with organizational networking policies 

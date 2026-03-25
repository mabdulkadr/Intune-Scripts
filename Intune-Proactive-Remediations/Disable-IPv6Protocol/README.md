# 🌐 Disable-IPv6Protocol – Disable IPv6 on Adapters and at System Level

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Network%20Configuration-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Disable-IPv6Protocol** checks whether the IPv6 binding is still enabled on any network adapter and, when required, disables IPv6 both at the adapter level and through the system-wide `DisabledComponents` registry value.

The detection script enumerates `ms_tcpip6` bindings with `Get-NetAdapterBinding` and returns success only when IPv6 is disabled on every detected adapter. The remediation script disables the IPv6 binding on adapters where it is still enabled, then writes `DisabledComponents = 255` under the TCP/IPv6 parameters key.

This package combines adapter-level configuration with a registry-based global setting. A restart is still required before the full system effect is guaranteed.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Disable-IPv6Protocol
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Disable-IPv6Protocol
│
├── Disable-IPv6Protocol--Detect.ps1
├── Disable-IPv6Protocol--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Disable-IPv6ProtocolProtocol--Detect.ps1
```

### Purpose

Checks whether IPv6 is disabled on every detected network adapter binding.

### Logic

1. Queries all `ms_tcpip6` bindings
2. Counts enabled and disabled adapter bindings
3. Returns exit code `0` only when all detected bindings are disabled
4. Returns exit code `1` when IPv6 is enabled on any adapter or the query fails

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | IPv6 is disabled on all detected adapters |
| 1    | IPv6 is still enabled or detection failed |

### Example

```powershell
.\Disable-IPv6ProtocolProtocol--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Disable-IPv6ProtocolProtocol--Remediate.ps1
```

### Purpose

Disables IPv6 bindings on active adapters and applies the system-wide IPv6 disable registry value.

### Actions

The script performs the following steps:

1. Enumerates all `ms_tcpip6` bindings
2. Disables the binding on adapters where IPv6 is still enabled
3. Writes `DisabledComponents = 255` under the TCP/IPv6 registry key
4. Returns success only when the registry update succeeds and no adapter operations fail

### Example

```powershell
.\Disable-IPv6ProtocolProtocol--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* `Get-NetAdapterBinding`
* `Disable-NetAdapterBinding`
* Windows Registry

### Permissions

* Administrative rights are required

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Disable-IPv6ProtocolProtocol--Detect.ps1
```

### Remediation Script

```powershell
Disable-IPv6ProtocolProtocol--Remediate.ps1
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
2. Detection checks the IPv6 binding state on all detected adapters
3. If IPv6 is still enabled anywhere, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation disables adapter bindings and writes the global IPv6 registry setting
6. A restart is required for full effect

---

# 🛡 Operational Notes

* The remediation applies both adapter-level and registry-level changes.
* A restart is still needed before the full system behavior is consistent.
* Disabling IPv6 can affect modern Windows networking assumptions and should be validated carefully.

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

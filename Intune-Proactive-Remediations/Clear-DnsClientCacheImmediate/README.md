# 🧹 Clear-DnsClientCacheImmediate – Always Flush the DNS Client Cache

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-DNS%20Maintenance-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Clear-DnsClientCacheImmediate** is an always-run package that flushes the Windows DNS client cache whenever remediation executes.

The detection script always returns exit code `1`, which forces the remediation script to run. The remediation script then calls `Clear-DnsClientCache`.

This package is intended for direct maintenance rather than state-based remediation.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Clear-DnsClientCacheImmediate
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Clear-DnsClientCacheImmediate
│
├── Clear-DnsClientCacheImmediate--Detect.ps1
├── Clear-DnsClientCacheImmediate--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Clear-DnsClientCacheImmediate--Detect.ps1
```

### Purpose

Always triggers the DNS cache clear operation.

### Logic

1. Writes a message that the script will always be triggered
2. Exits with code `1`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 1    | Always trigger remediation |

### Example

```powershell
.\Clear-DnsClientCacheImmediate--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Clear-DnsClientCacheImmediate--Remediate.ps1
```

### Purpose

Flushes the local Windows DNS client cache.

### Actions

1. Runs `Clear-DnsClientCache`

### Example

```powershell
.\Clear-DnsClientCacheImmediate--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* `Clear-DnsClientCache`

### Permissions

* Administrative rights may be required depending on execution context

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Clear-DnsClientCacheImmediate--Detect.ps1
```

### Remediation Script

```powershell
Clear-DnsClientCacheImmediate--Remediate.ps1
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
2. Detection always exits with code **1**
3. Intune triggers the **Remediation Script**
4. The remediation script flushes the DNS client cache

---

# 🛡 Operational Notes

* This package is unconditional and does not check whether the DNS cache actually needs to be cleared.
* It is best treated as a maintenance action rather than a compliance workflow.

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

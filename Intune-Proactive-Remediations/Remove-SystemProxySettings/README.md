# 🌐 Remove-SystemProxySettings – Disable the Current User's WinINET Proxy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Proxy%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Remove-SystemProxySettings** checks whether the current user has a WinINET proxy server configured and, if so, disables the proxy and clears the proxy server string.

The detection script reads `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings` and pipes the result to `findstr` in an attempt to identify proxy configuration. The remediation script then sets `ProxyEnable` to `0` and clears the `ProxyServer` value.

This package is scoped to the current user's Internet Settings and does not manage machine-wide WinHTTP proxy configuration.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Remove-SystemProxySettings
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Remove-SystemProxySettings
│
├── README.md
├── Remove-SystemProxySettings--Detect.ps1
└── Remove-SystemProxySettings--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Remove-SystemProxySettings--Detect.ps1
```

### Purpose

Checks whether a proxy server appears to be configured in the current user's Internet Settings registry hive.

### Logic

1. Reads `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings`
2. Pipes the result to `findstr`
3. Returns exit code `1` when a proxy server appears to be present
4. Returns exit code `0` when no proxy server is detected

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No proxy server detected |
| 1    | Proxy server detected |

### Example

```powershell
.\Remove-SystemProxySettings--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Remove-SystemProxySettings--Remediate.ps1
```

### Purpose

Disables WinINET proxy use for the current user and clears the proxy server string.

### Actions

The script performs the following steps:

1. Sets `ProxyEnable` to `0`
2. Sets `ProxyServer` to an empty string

### Example

```powershell
.\Remove-SystemProxySettings--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* Windows Registry
* `Set-ItemProperty`
* `findstr`

### Permissions

* The package should run in the target user's context to modify the intended `HKCU` hive

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Remove-SystemProxySettings--Detect.ps1
```

### Remediation Script

```powershell
Remove-SystemProxySettings--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Yes   |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks the current user's Internet Settings registry values
3. If a proxy is detected, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation disables the proxy and clears the proxy server string

---

# 🛡 Operational Notes

* The detection logic uses `findstr ProxyServerv`, which looks incorrect and should be reviewed.
* The package does not clear related proxy settings such as `AutoConfigURL`.
* This workflow does not touch WinHTTP proxy state.

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

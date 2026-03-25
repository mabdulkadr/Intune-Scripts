# 🔐 Enable-WinRMService – WinRM Availability Check and Remoting Configuration

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-WinRM%20Enablement-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Enable-WinRMService** is an Intune remediation package that checks whether **WinRM** is responding locally and, when needed, enables PowerShell Remoting on the device.

The detection script uses `Test-WSMan` as the health check. If WinRM is already available, the package returns success. If the local WSMan test fails, remediation starts the `WinRM` service, runs `Enable-PSRemoting -Force -SkipNetworkProfileCheck`, changes the service startup type to `Automatic`, and finishes with `winrm quickconfig -quiet` verification.

This package is useful when remote management features that depend on WinRM or classic PowerShell remoting need to be enforced consistently across managed devices.

---

# ✨ Core Features

### 🔹 WSMan-Based Detection

* Uses `Test-WSMan` against the local device
* Treats a valid WSMan response as a healthy WinRM state
* Returns remediation only when WinRM is unavailable or not responding

### 🔹 Service and Remoting Configuration

* Ensures the `WinRM` service exists
* Starts the service if it is not already running
* Enables remoting with `Enable-PSRemoting -Force -SkipNetworkProfileCheck`

### 🔹 Startup Persistence

* Sets the `WinRM` service startup type to `Automatic`
* Keeps remoting available after reboot
* Performs a final `winrm quickconfig -quiet` verification step

### 🔹 Explicit Administrative Requirement

* Checks for administrative privileges before making changes
* Fails early when the script does not have enough rights to configure remoting

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Enable-WinRMService
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Enable-WinRMService
│
├── Enable-WinRMService--Detect.ps1
├── Enable-WinRMService--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Enable-WinRMServiceService--Detect.ps1
```

### Purpose

Checks whether WinRM is already enabled and responding on the local device.

### Logic

1. Runs `Test-WSMan`
2. Returns exit code `0` when WinRM responds successfully
3. Returns exit code `1` when the WSMan call fails or returns no usable result

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | WinRM is enabled and responding |
| 1    | WinRM is unavailable or detection failed |

### Key References

* Service: `WinRM`
* Command: `Test-WSMan`

### Example

```powershell
.\Enable-WinRMServiceService--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Enable-WinRMServiceService--Remediate.ps1
```

### Purpose

Enables PowerShell remoting and configures the WinRM service so the device responds to local WSMan requests.

### Actions

1. Verifies the script is running with administrative rights
2. Checks that the `WinRM` service exists
3. Starts the service if it is stopped
4. Runs `Enable-PSRemoting -Force -SkipNetworkProfileCheck`
5. Sets the service startup type to `Automatic`
6. Verifies the final configuration with `winrm quickconfig -quiet`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | WinRM and PowerShell remoting were configured successfully |
| 1    | Administrative rights were missing, the service was unavailable, or configuration failed |

### Key References

* Service: `WinRM`
* Command: `Enable-PSRemoting -Force -SkipNetworkProfileCheck`
* Command: `winrm quickconfig -quiet`

### Example

```powershell
.\Enable-WinRMServiceService--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrative privileges are required for remediation
* Permission to manage services and WinRM configuration

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Enable-WinRMServiceService`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Enable-WinRMServiceService--Detect.ps1
```

### Remediation Script

```powershell
Enable-WinRMServiceService--Remediate.ps1
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
2. Detection tests local WSMan connectivity
3. If WinRM is not responding, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation starts the WinRM service, enables remoting, and validates the final configuration

---

# 🛡 Operational Notes

* The remediation script relies on administrative rights and will stop early without them
* `Enable-PSRemoting -SkipNetworkProfileCheck` changes the local remoting configuration even when the network profile is not private
* Detection checks whether WinRM responds, not whether every remoting policy setting matches a specific baseline
* Test on pilot devices before broad deployment, especially where firewall or hardening policy already manages WinRM

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

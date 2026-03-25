# 🔧 Reset-WindowsUpdateComponents – Full SoftwareDistribution and Catroot2 Reset

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Windows%20Update%20Reset-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Reset-WindowsUpdateComponents** is an always-run remediation package for rebuilding the main local Windows Update cache locations.

The detection script does not evaluate device state. It deliberately exits with code `1` every time so that Intune always invokes remediation. The remediation script then stops the Windows Update-related services, renames both **SoftwareDistribution** and **catroot2** to `.bak`, restarts the services, and finally calls `wuauclt /updatenow`.

This is a broader repair action than simply renaming `SoftwareDistribution`, because it also resets the cryptographic catalog folder and preserves the previous directories as backups.

---

# ✨ Core Features

### 🔹 Always-Trigger Detection

The detection stage is intentionally unconditional:

* Writes a status message
* Exits with code `1` on every run
* Forces Intune to execute remediation each time the package is assigned

---

### 🔹 Windows Update Service Reset

The remediation script performs a service-aware reset sequence:

* Captures started services that depend on `cryptsvc`
* Stops those dependent services first
* Stops `wuauserv`, `cryptsvc`, and `bits`
* Renames `SoftwareDistribution` and `catroot2` to `.bak`
* Starts the services again in the reverse direction

---

### 🔹 Immediate Scan Trigger

After the reset completes, the script runs:

```text
wuauclt /updatenow
```

That asks Windows Update to begin a new update detection cycle.

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Reset-WindowsUpdateComponents
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Reset-WindowsUpdateComponents
│
├── README.md
├── Reset-WindowsUpdateComponents--Detect.ps1
└── Reset-WindowsUpdateComponents--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Reset-WindowsUpdateComponents--Detect.ps1
```

### Purpose

Forces Intune to run remediation every time the package executes.

### Logic

1. Writes `Script will always be triggered`
2. Exits with code `1`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 1    | Always trigger remediation |

### Example

```powershell
.\Reset-WindowsUpdateComponents--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Reset-WindowsUpdateComponents--Remediate.ps1
```

### Purpose

Resets the local Windows Update working folders and restarts the related services.

### Actions

1. Collects started services dependent on `cryptsvc`
2. Stops dependent services, `wuauserv`, `cryptsvc`, and `bits`
3. Removes any existing `SoftwareDistribution.bak` and renames `SoftwareDistribution`
4. Removes any existing `catroot2.bak` and renames `catroot2`
5. Starts `cryptsvc`, `bits`, `wuauserv`, and any previously running dependent services
6. Runs `wuauclt /updatenow`

### Example

```powershell
.\Reset-WindowsUpdateComponents--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrative rights are required
* The script must be able to stop system services and rename folders under `%windir%`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Reset-WindowsUpdateComponents--Detect.ps1
```

### Remediation Script

```powershell
Reset-WindowsUpdateComponents--Remediate.ps1
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
3. Intune immediately runs the **Remediation Script**
4. Remediation resets `SoftwareDistribution` and `catroot2`
5. Windows Update services are started again
6. The script triggers a fresh update scan with `wuauclt /updatenow`

---

# 🛡 Operational Notes

* This package is intentionally aggressive. It does not wait for a health check before resetting the Windows Update cache.
* Existing `.bak` folders are deleted before new ones are created, so only one backup generation is retained.
* The script assumes the target folders exist. If either folder is already missing, the rename step can fail.
* `wuauclt /updatenow` is legacy behavior and may not produce identical results across all modern Windows builds.

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

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.


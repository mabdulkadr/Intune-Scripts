# 📦 Winget Update All

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Tool](https://img.shields.io/badge/Tool-Winget-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Winget Update All** is a PowerShell automation solution that detects and installs available updates for applications managed by **Windows Package Manager (winget)**.

Keeping third-party applications updated is critical for maintaining device security and stability. This solution automatically identifies devices with pending application updates and installs them silently.

The project includes **Detection + Remediation scripts** designed to work with **Microsoft Intune Proactive Remediations**.

---

# ✨ Core Features

### 🔹 Detect Applications with Available Updates

The detection script checks whether any applications installed via **winget** have updates available.

It performs the following steps:

1. Dynamically resolves the Winget executable path.
2. Executes:

```powershell
winget upgrade
```

3. Evaluates the command output to determine whether updates exist.

If updates are detected, the device is marked **Not Compliant**.

---

### 🔹 Automatic Application Updates

The remediation script upgrades all supported applications automatically using:

```powershell
winget upgrade --all --force --silent
```

Parameters used:

| Parameter  | Purpose                                         |
| ---------- | ----------------------------------------------- |
| `--all`    | Upgrade all applications with available updates |
| `--force`  | Reinstall or override version checks            |
| `--silent` | Run without user interaction                    |

All upgrades run silently in **SYSTEM context**.

---

# 📂 Project Structure

```
WingetUpdateAll
│
├── WingetUpdateAll--Detect.ps1
├── WingetUpdateAll--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```
WingetUpdateAll--Detect.ps1
```

### Purpose

Detects whether applications installed via winget have available updates.

### Detection Logic

The script:

1. Locates the **Winget executable**
2. Executes `winget upgrade`
3. Parses the output to detect pending upgrades

### Exit Codes

| Code | Status               |
| ---- | -------------------- |
| 0    | No updates available |
| 1    | Updates available    |

---

# 🛠 Remediation Script

**File**

```
WingetUpdateAll--Remediate.ps1
```

### Purpose

Upgrades all applications with available updates.

### Actions

The remediation script performs:

1. Resolve Winget executable path
2. Execute upgrade command

```powershell
winget upgrade --all --force --silent
```

3. Return exit code based on operation result

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Required Component

* **Windows Package Manager (winget)**
* Package: `Microsoft.DesktopAppInstaller`

### Execution Context

Scripts are intended to run in **SYSTEM context**.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```
WingetUpdateAll--Detect.ps1
```

### Remediation Script

```
WingetUpdateAll--Remediate.ps1
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
2. Script checks for winget updates
3. If updates available → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script installs application updates silently
6. Device returns to compliant state

---

# 🛡 Operational Notes

* Not all applications support silent upgrades.
* Winget source configuration must be healthy.
* Some Microsoft Store applications may require additional servicing.
* Always validate updates on **pilot devices** before wide deployment.

Logs can typically be found under:

```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs
```

---

## 📜 License

This project is licensed under the **MIT License**

https://opensource.org/licenses/MIT

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.1**

---

## ☕ Support

If this project helps you, consider supporting it:

https://www.buymeacoffee.com/mabdulkadrx

---

## ⚠ Disclaimer

This project is provided **as-is**.

- Always test scripts before production deployment.
- Validate restart policies and user experience.
- Ensure compatibility with your organization’s device management policies.

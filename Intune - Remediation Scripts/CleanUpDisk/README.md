
# 💽 CleanUpDisk – Automated Disk Space Remediation

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Disk%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**CleanUpDisk** is an enterprise-ready PowerShell automation designed to monitor system disk space and automatically execute cleanup operations when available storage drops below a defined threshold.

The solution consists of **two scripts** designed for integration with **Microsoft Intune Proactive Remediations**, enabling automated monitoring and remediation of low disk space conditions across managed endpoints.

When disk space becomes critically low, the remediation script configures and runs **Windows Disk Cleanup (CleanMgr.exe)** with predefined cleanup categories to remove unnecessary files safely.

This helps maintain healthy endpoint performance and prevents issues caused by insufficient storage.

---

# ✨ Core Features

### 🔹 Disk Space Monitoring

The detection script continuously evaluates the available space on the system drive:

* Checks **C:\ free disk space**
* Compares against a defined **minimum threshold**
* Returns compliance status

---

### 🔹 Automated Disk Cleanup

If free space falls below the threshold:

* Disk Cleanup configuration is written to the registry
* Windows **CleanMgr.exe** is executed silently
* Temporary files and other removable items are deleted

---

### 🔹 Intune Proactive Remediation Ready

Designed to work directly with:

**Microsoft Intune → Devices → Scripts and Remediations**

Provides:

* Detection logic
* Automated remediation
* Exit-code based compliance status

---

### 🔹 Safe Cleanup Categories

The remediation script enables selected Disk Cleanup categories such as:

* Temporary files
* Recycle Bin
* Windows Update cleanup
* Temporary Sync Files

Only supported Windows cleanup handlers are used.

---

### 🔹 Silent Execution

Cleanup runs using the Windows mechanism:

```
CleanMgr.exe /sagerun:1
```

Allowing background execution without user interaction.

---

# 📂 Project Structure

```
CleanUpDisk
│
├── CleanUpDisk--Detect.ps1
├── CleanUpDisk--Remediate.ps1
├── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```
CleanUpDisk--Detect.ps1
```

### Purpose

Determines whether disk cleanup is required.

### Logic

1. Retrieve free space from **C:\ drive**
2. Compare against the defined threshold
3. Return compliance status

### Exit Codes

| Code | Status                     |
| ---- | -------------------------- |
| 0    | Compliant                  |
| 1    | Disk space below threshold |

### Example

```powershell
.\CleanUpDisk--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```
CleanUpDisk--Remediate.ps1
```

### Purpose

Performs disk cleanup automatically when triggered by detection.

### Actions

The script performs the following steps:

1. Enables selected cleanup handlers in registry
2. Configures Disk Cleanup settings
3. Executes cleanup silently

```
CleanMgr.exe /sagerun:1
```

### Example

```powershell
.\CleanUpDisk--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrator privileges required

### Architecture

* 64-bit environment

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```
CleanUpDisk--Detect.ps1
```

### Remediation Script

```
CleanUpDisk--Remediate.ps1
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
2. Script checks available disk space
3. If space is below threshold → exit code **1**
4. Intune triggers **Remediation Script**
5. Script runs Disk Cleanup automatically
6. Disk space is reclaimed

---

# 🛡 Operational Notes

* Always test scripts on **pilot devices** before production rollout.
* Cleanup categories should be validated to avoid removing required data.
* Disk Cleanup depends on available Windows cleanup handlers.

---

# 📜 License

This project is licensed under the
[MIT License](https://opensource.org/licenses/MIT).

---

# 👤 Author

**Mohammad Abdelkader Omar**
Website: **momar.tech**

Version: **1.0**
Date: **2026-03-09**

---

# ☕ Donate

If this project helps you, consider supporting it:

[https://www.buymeacoffee.com/mabdulkadrx](https://www.buymeacoffee.com/mabdulkadrx)

---

# ⚠ Disclaimer

This tool is provided **as-is**.

* Always test scripts before deployment
* Validate cleanup policies
* Ensure compliance with organizational standards



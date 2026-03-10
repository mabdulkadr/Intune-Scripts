# 🩺 Windows System Health Check

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Feature](https://img.shields.io/badge/Feature-System%20Health-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Windows System Health Check** is a PowerShell automation solution designed to detect and repair common **Windows operating system health issues**.

Over time, Windows devices may experience system health problems due to:

* Corrupted system files
* Disk integrity issues
* Windows component corruption
* System configuration problems

This project provides **Detection + Remediation scripts** that evaluate the system health status and automatically apply corrective actions when problems are detected.

The solution is designed for **Microsoft Intune Proactive Remediations**.

---

# ✨ Core Features

### 🔹 System Health Detection

The detection script checks the operating system for signs of corruption or configuration issues.

Typical checks include:

* Windows system file integrity
* OS component health
* General system health status

If a health issue is detected, the device is marked as **non-compliant**.

---

### 🔹 Automatic System Repair

When issues are detected, the remediation script performs automated repair operations including:

* System file integrity repair using **SFC**
* Windows component repair using **DISM**
* Verification of system health after repair

Typical commands used:

```powershell
sfc /scannow
```

```powershell
DISM /Online /Cleanup-Image /RestoreHealth
```

---

# 📂 Project Structure

```
WindowsSystemHealth
│
├── WindowsSystemHealth--Detect.ps1
├── WindowsSystemHealth--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```
WindowsSystemHealth--Detect.ps1
```

### Purpose

Detects potential Windows system health issues.

### Checks Performed

The script evaluates:

* Windows system file integrity
* System component health
* Operating system condition

### Exit Codes

| Code | Status                       |
| ---- | ---------------------------- |
| 0    | System health OK             |
| 1    | System health issue detected |

---

# 🛠 Remediation Script

**File**

```
WindowsSystemHealth--Remediate.ps1
```

### Purpose

Attempts to repair system health issues detected by the detection script.

### Repair Actions

The remediation script performs:

1. System File Checker scan

```
sfc /scannow
```

2. Windows component repair

```
DISM /Online /Cleanup-Image /RestoreHealth
```

3. Verification of repair results

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Permissions

Administrator privileges required.

When deployed through Intune, scripts usually run in **SYSTEM context**.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```
WindowsSystemHealth--Detect.ps1
```

### Remediation Script

```
WindowsSystemHealth--Remediate.ps1
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
2. Script checks Windows system health
3. If issue detected → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script repairs system files and components
6. Device returns to healthy state

---

# 🛡 Operational Notes

* System corruption may affect application stability and updates.
* Automated repair helps maintain device reliability.
* Always validate remediation scripts on **pilot devices** before full deployment.

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.1**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.
# 🛡 Monthly System Restore Point Compliance

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Feature](https://img.shields.io/badge/Feature-System%20Restore-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Monthly System Restore Point Compliance** is a PowerShell automation solution designed to ensure that Windows devices maintain at least one **recent system restore point**.

System restore points provide a recovery mechanism that allows administrators and users to revert system configuration changes if updates, drivers, or software installations cause system instability.

This project provides **Detection + Remediation scripts** that automatically verify whether a restore point exists for the current month and create one if it does not.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**, enabling organizations to maintain a consistent restore-point policy across managed endpoints.

---

# ✨ Core Features

### 🔹 Restore Point Compliance Detection

The detection script evaluates whether a **system restore point exists for the current month**.

It checks existing restore points using:

```powershell
Get-ComputerRestorePoint
```

If no restore point exists within the defined timeframe, the device is marked as **non-compliant**.

---

### 🔹 Automatic Restore Point Creation

If a restore point is missing, the remediation script will:

* Ensure **System Protection** is enabled
* Verify restore point configuration
* Create a new restore point automatically

Typical command used:

```powershell
Checkpoint-Computer -Description "Monthly Restore Point" -RestorePointType MODIFY_SETTINGS
```

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
Monthly-System-Restore-Point
│
├── MonthlyRestorePoint--Detect.ps1
├── MonthlyRestorePoint--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
MonthlyRestorePoint--Detect.ps1
```

### Purpose

Checks whether a system restore point exists within the current month.

### Logic

The script performs the following checks:

1. Retrieve all restore points using `Get-ComputerRestorePoint`
2. Parse restore point creation dates
3. Verify whether a restore point exists within the defined time window

### Exit Codes

| Code | Status                |
| ---- | --------------------- |
| 0    | Restore point exists  |
| 1    | Restore point missing |

### Example

```powershell
.\MonthlyRestorePoint--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
MonthlyRestorePoint--Remediate.ps1
```

### Purpose

Creates a system restore point when one is not present for the current month.

### Actions

The remediation script performs the following operations:

1. Ensure **System Protection** is enabled

```powershell
Enable-ComputerRestore -Drive "C:\"
```

2. Verify restore point configuration

3. Create a new restore point

```powershell
Checkpoint-Computer -Description "Monthly Restore Point" -RestorePointType MODIFY_SETTINGS
```

4. Log restore point creation status

### Example

```powershell
.\MonthlyRestorePoint--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Permissions

Administrator privileges are required to manage restore points and system protection.

When deployed via Intune, scripts typically run in **SYSTEM context**.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
MonthlyRestorePoint--Detect.ps1
```

### Remediation Script

```powershell
MonthlyRestorePoint--Remediate.ps1
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
2. Script checks existing restore points
3. If restore point missing → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script enables System Protection if needed
6. Script creates a new monthly restore point

---

# 🛡 Operational Notes

* Restore points provide a fallback mechanism for system recovery.
* Windows may automatically remove older restore points depending on disk space.
* Ensure **System Protection** is enabled on the system drive.
* Always validate restore-point policies in pilot deployments.

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
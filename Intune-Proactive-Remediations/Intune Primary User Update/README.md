# 👤 Intune Primary User Update Automation

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Feature](https://img.shields.io/badge/Feature-Primary%20User-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Intune Primary User Update Automation** is a PowerShell remediation solution designed to detect and update the **Primary User** assigned to a Windows device in **Microsoft Intune**.

In many enterprise environments, devices are reassigned between users, shared among teams, or deployed without correctly assigning the primary user. This can cause issues such as:

* Incorrect device ownership
* Incorrect application targeting
* Conditional access misalignment
* Inaccurate device usage reporting

This project provides **Detection + Remediation scripts** that automatically identify when the Intune device primary user does not match the expected user and correct the assignment.

The solution is designed for **Microsoft Intune Proactive Remediations**.

---

# ✨ Core Features

### 🔹 Primary User Detection

The detection script evaluates the current **Primary User assignment** for the device.

It determines whether the device primary user aligns with the expected user context.

---

### 🔹 Automatic Primary User Correction

If a mismatch is detected, the remediation script performs corrective actions such as:

* Identifying the currently logged-on user
* Validating the user account
* Updating the device **Primary User** in Intune

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
Intune-Primary-User-Update
│
├── IntunePrimaryUserUpdate--Detect.ps1
├── IntunePrimaryUserUpdate--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
IntunePrimaryUserUpdate--Detect.ps1
```

### Purpose

Checks whether the device primary user matches the currently logged-on user.

### Logic

The script performs the following checks:

1. Identify the current logged-on user
2. Retrieve device information from Intune
3. Compare with the assigned primary user

### Exit Codes

| Code | Status                |
| ---- | --------------------- |
| 0    | Primary user correct  |
| 1    | Primary user mismatch |

### Example

```powershell
.\IntunePrimaryUserUpdate--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
IntunePrimaryUserUpdate--Remediate.ps1
```

### Purpose

Updates the device **Primary User** assignment in Intune.

### Actions

The remediation script performs the following operations:

1. Identify current logged-on user
2. Validate the user account
3. Connect to Microsoft Intune
4. Update device primary user assignment

Typical action performed:

```powershell
Update Intune device primary user assignment
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Device Enrollment

Devices must be enrolled in **Microsoft Intune**.

### Permissions

Required permissions:

* Intune device management permissions
* Microsoft Graph API access (if used)

Scripts typically run in **SYSTEM context** when deployed via Intune.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
IntunePrimaryUserUpdate--Detect.ps1
```

### Remediation Script

```powershell
IntunePrimaryUserUpdate--Remediate.ps1
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
2. Script evaluates current device primary user
3. If mismatch detected → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script updates primary user assignment
6. Device becomes compliant

---

# 🛡 Operational Notes

* Primary user assignment affects **application targeting and reporting** in Intune.
* Shared or kiosk devices may not require a primary user.
* Validate assignment policies before automatic updates.
* Test deployment in **pilot groups** before large-scale rollout.

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
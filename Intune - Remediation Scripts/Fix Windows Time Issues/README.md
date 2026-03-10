# ⏱ Fix Windows Time & Time Zone Issues

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Service](https://img.shields.io/badge/Service-Windows%20Time-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Fix Windows Time & Time Zone Issues** is a PowerShell remediation solution designed to detect and correct common time synchronization problems on Windows devices.

Incorrect system time or time zone configuration can lead to several operational issues, including:

* Authentication failures
* Kerberos ticket errors
* Certificate validation problems
* Application synchronization failures
* Domain connectivity issues

This project provides **Detection + Remediation scripts** that verify time-related configuration and automatically correct misconfigured settings.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**, enabling automated enforcement of correct time configuration across managed devices.

---

# ✨ Core Features

### 🔹 Time Configuration Detection

The detection script verifies several critical time settings:

* Windows Time service status
* Time synchronization configuration
* Automatic time zone detection

It determines whether the device is compliant with expected time configuration policies.

---

### 🔹 Automatic Time Remediation

If configuration issues are detected, the remediation script performs corrective actions such as:

* Starting the **Windows Time (W32Time)** service
* Setting the service startup type to **Automatic**
* Configuring the system to synchronize time with an NTP server
* Enabling automatic time zone detection

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
Fix-Windows-Time
│
├── TimeIssues--Detect.ps1
├── TimeIssues--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
TimeIssues--Detect.ps1
```

### Purpose

Checks whether Windows time configuration is correctly configured.

### Logic

The script verifies:

1. Windows Time service status
2. Time synchronization configuration
3. Automatic time zone detection settings

### Exit Codes

| Code | Status        |
| ---- | ------------- |
| 0    | Compliant     |
| 1    | Non-compliant |
| 2    | Script error  |

### Example

```powershell
.\TimeIssues--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
TimeIssues--Remediate.ps1
```

### Purpose

Fixes time-related configuration issues detected on the device.

### Actions

The remediation script performs the following operations:

1. Start the **Windows Time service**

```powershell
Start-Service W32Time
```

2. Configure service startup to **Automatic**

3. Configure time synchronization using:

```
time.windows.com
```

4. Force time synchronization

5. Enable automatic time zone detection

6. Restart required services if needed

### Example

```powershell
.\TimeIssues--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Permissions

Administrator privileges are required to modify system services and time configuration.

When deployed via Intune, scripts typically run in **SYSTEM context**, which satisfies this requirement.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
TimeIssues--Detect.ps1
```

### Remediation Script

```powershell
TimeIssues--Remediate.ps1
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
2. Script evaluates system time configuration
3. If issues detected → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script corrects time configuration
6. Device becomes compliant

---

# 🛡 Operational Notes

* Incorrect time configuration can break domain authentication.
* Ensure domain policies do not conflict with remediation settings.
* If devices are domain-joined, time synchronization may be controlled by **Active Directory**.
* Test deployment on **pilot devices** before organization-wide rollout.

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

This project is provided **as-is**.

- Always test scripts before production deployment.
- Validate restart policies and user experience.
- Ensure compatibility with your organization’s device management policies.

# 🧩 Enable .NET Framework 3.5 on Windows Devices

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Feature](https://img.shields.io/badge/Feature-.NET%203.5-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Enable .NET Framework 3.5** is a PowerShell-based remediation solution designed to detect and enable the **.NET Framework 3.5** Windows feature on managed devices.

Some enterprise applications, legacy systems, and internal tools require **.NET Framework 3.5** to function correctly. However, this feature is not enabled by default on modern versions of Windows.

This project provides **Detection + Remediation scripts** that automatically verify whether the feature is installed and enable it if missing.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**, allowing organizations to ensure that required application dependencies are installed across managed endpoints.

---

# ✨ Core Features

### 🔹 Automatic Feature Detection

The detection script verifies whether **.NET Framework 3.5** is enabled on the system.

It evaluates Windows optional features and determines whether remediation is required.

---

### 🔹 Automatic Feature Installation

If the feature is not installed:

* Windows feature installation is triggered
* Required components are downloaded from Windows Update
* Installation status is returned to Intune

---

### 🔹 Enterprise Deployment Ready

Designed for deployment through:

**Microsoft Intune → Devices → Scripts and Remediations**

Provides:

* Detection logic
* Automatic remediation
* Exit-code based compliance reporting

---

# 📂 Project Structure

```text
Enable-dotNet3.5
│
├── dotNet3.5_Feature_Installed--Detect.ps1
├── dotNet3.5_Feature--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
dotNet3.5_Feature_Installed--Detect.ps1
```

### Purpose

Checks whether **.NET Framework 3.5** is enabled on the device.

### Logic

1. Query Windows optional features
2. Check installation status of **.NET Framework 3.5**
3. Determine compliance state

### Exit Codes

| Code | Status            |
| ---- | ----------------- |
| 0    | Feature installed |
| 1    | Feature missing   |

### Example

```powershell
.\dotNet3.5_Feature_Installed--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
dotNet3.5_Feature--Remediate.ps1
```

### Purpose

Installs **.NET Framework 3.5** when the feature is not enabled.

### Actions

The remediation script performs the following steps:

1. Detect whether the feature is already installed
2. Trigger Windows feature installation
3. Monitor installation status
4. Return success or error message

Typical command used internally:

```powershell
Add-WindowsCapability -Online -Name NetFx3~~~~
```

### Example

```powershell
.\dotNet3.5_Feature--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Permissions

Administrator privileges are required to install Windows features.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
dotNet3.5_Feature_Installed--Detect.ps1
```

### Remediation Script

```powershell
dotNet3.5_Feature--Remediate.ps1
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
2. Script checks whether .NET Framework 3.5 is installed
3. If feature missing → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script installs the required Windows feature
6. Device becomes compliant

---

# 🛡 Operational Notes

* Internet access may be required to download the feature from **Windows Update**.
* If devices use **WSUS**, a local installation source may be required.
* Some legacy applications depend on .NET Framework 3.5 to run correctly.
* Test deployment on **pilot devices** before large-scale rollout.

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

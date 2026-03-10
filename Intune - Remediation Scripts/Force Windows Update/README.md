# 🔄 Force Windows Updates on Managed Devices

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Updates](https://img.shields.io/badge/Windows-Updates-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Force Windows Updates** is a PowerShell remediation solution designed to detect and install pending Windows updates on managed devices.

Keeping Windows devices fully updated is essential for:

* Security patch compliance
* System stability
* Application compatibility
* Endpoint protection

This project provides **Detection + Remediation scripts** that automatically detect pending updates and trigger installation when required.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**, enabling administrators to maintain consistent update compliance across managed endpoints.

---

# ✨ Core Features

### 🔹 Pending Updates Detection

The detection script scans the system for available Windows updates.

It determines whether updates are pending and returns the compliance state accordingly.

Firmware updates can be excluded depending on script configuration.

---

### 🔹 Automatic Update Installation

If pending updates are detected, the remediation script will:

* Install the **PSWindowsUpdate module** if required
* Scan the system for updates
* Install all pending updates silently
* Check if a reboot is required

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
Force-Windows-Updates
│
├── ForceWindowsUpdate--Detect.ps1
├── ForceWindowsUpdate--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
ForceWindowsUpdate--Detect.ps1
```

### Purpose

Checks whether Windows updates are pending on the device.

### Logic

The script performs the following checks:

1. Verify that the **PSWindowsUpdate module** is available
2. Query Windows Update service for available updates
3. Determine whether updates need to be installed

### Exit Codes

| Code | Status             |
| ---- | ------------------ |
| 0    | No updates pending |
| 1    | Updates available  |

### Example

```powershell
.\ForceWindowsUpdate--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
ForceWindowsUpdate--Remediate.ps1
```

### Purpose

Installs all pending Windows updates on the device.

### Actions

The remediation script performs the following steps:

1. Ensure **PSWindowsUpdate module** is installed
2. Scan for available updates
3. Install updates silently

Typical command used internally:

```powershell
Install-WindowsUpdate -AcceptAll -AutoReboot
```

4. Check if a system restart is required
5. Log the update installation results

### Example

```powershell
.\ForceWindowsUpdate--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Module

Required module:

```
PSWindowsUpdate
```

The remediation script installs the module automatically if it is not present.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
ForceWindowsUpdate--Detect.ps1
```

### Remediation Script

```powershell
ForceWindowsUpdate--Remediate.ps1
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
2. Script checks for pending updates
3. If updates found → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script installs pending updates
6. Device becomes compliant

---

# 🛡 Operational Notes

* The remediation script may trigger a **system restart** if required.
* Update installation time depends on the number and size of updates.
* Ensure Windows Update services are accessible.
* In environments using **WSUS or Windows Update for Business**, ensure compatibility with update policies.

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
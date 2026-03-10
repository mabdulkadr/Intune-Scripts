# 🖥 Enable WinRM on Windows Devices

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Service](https://img.shields.io/badge/Service-WinRM-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Enable WinRM** is a PowerShell remediation solution designed to ensure that **Windows Remote Management (WinRM)** and **PowerShell Remoting** remain enabled and operational on managed Windows devices.

WinRM is required for many enterprise administration tasks including:

* Remote PowerShell management
* Configuration management tools
* Automation platforms
* Remote troubleshooting
* Infrastructure orchestration

This project provides **Detection + Remediation scripts** that automatically verify whether WinRM is operational and configure it if it is not.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**.

---

# ✨ Core Features

### 🔹 WinRM Health Detection

The detection script verifies whether **WinRM is operational** using the native command:

```powershell
Test-WSMan
```

If the command fails, remediation will be triggered.

---

### 🔹 Automatic WinRM Configuration

When WinRM is disabled or not properly configured, the remediation script:

* Enables **PowerShell Remoting**
* Starts the **WinRM service**
* Sets the service startup type to **Automatic**
* Configures the required WinRM listeners

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
Enable-WinRM
│
├── EnableWinRM--Detect.ps1
├── EnableWinRM--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
EnableWinRM--Detect.ps1
```

### Purpose

Checks whether **WinRM is enabled and responding** on the device.

### Logic

1. Execute `Test-WSMan`
2. Verify WinRM response
3. Determine compliance state

### Exit Codes

| Code | Status                           |
| ---- | -------------------------------- |
| 0    | WinRM operational                |
| 1    | WinRM disabled or not responding |

### Example

```powershell
.\EnableWinRM--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```powershell
EnableWinRM--Remediate.ps1
```

### Purpose

Enables and configures **WinRM** and **PowerShell Remoting**.

### Actions

The remediation script performs the following operations:

1. Enable PowerShell remoting

```powershell
Enable-PSRemoting -Force
```

2. Configure WinRM service startup

3. Start WinRM service if stopped

4. Validate configuration using:

```powershell
winrm quickconfig
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11
* Windows Server 2016 or newer

### PowerShell

PowerShell **5.1 or later**

### Permissions

Administrator privileges required.

When deployed via Intune, scripts run in **SYSTEM context**, which satisfies this requirement.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```powershell
EnableWinRM--Detect.ps1
```

### Remediation Script

```powershell
EnableWinRM--Remediate.ps1
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
2. Script checks WinRM availability
3. If WinRM disabled → Exit Code **1**
4. Intune runs **Remediation Script**
5. Script configures WinRM and PowerShell Remoting
6. Device becomes compliant

---

# 🛡 Operational Notes

* WinRM is required for many enterprise automation tools.
* The remediation script configures the service automatically.
* Always validate remote management policies before enabling WinRM across devices.
* Test deployment on **pilot devices** before organization-wide rollout.

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


# 🌐 Disable Local Network Access Checks (Chrome & Edge)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Browser](https://img.shields.io/badge/Browser-Chrome%20%7C%20Edge-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Disable Local Network Access Checks** is a PowerShell remediation solution designed to remove browser restrictions that prevent websites from accessing local network resources.

Modern Chromium-based browsers such as **Google Chrome** and **Microsoft Edge** enforce **Local Network Access (LNA) security checks**, which can block internal services from communicating with devices on the local network.

This project provides **Detection + Remediation scripts** designed for **Microsoft Intune Proactive Remediations** to automatically detect the restriction and apply the required configuration to disable it.

The solution is particularly useful in environments where internal services such as **Blackboard or internal portals** must communicate with local endpoints.

---

# ✨ Core Features

### 🔹 Automatic Detection

The detection script verifies whether **Local Network Access checks** are enabled in supported browsers.

It evaluates the current configuration and determines if remediation is required.

---

### 🔹 Automatic Remediation

When restrictions are detected:

* Browser processes are stopped if necessary
* Required configuration flags are applied
* Browsers are restarted when needed

---

### 🔹 Chrome & Edge Support

Supported browsers:

* Google Chrome
* Microsoft Edge (Chromium)

Supported installation paths:

```
C:\Program Files\Google\Chrome\Application\chrome.exe
C:\Program Files (x86)\Google\Chrome\Application\chrome.exe

C:\Program Files\Microsoft\Edge\Application\msedge.exe
C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
```

---

# 📂 Project Structure

```
Disable-Local-Network-Access-Checks
│
├── DisableLocalNetworkAccessChecks--Detect.ps1
├── DisableLocalNetworkAccessChecks--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```
DisableLocalNetworkAccessChecks--Detect.ps1
```

### Purpose

Checks whether Local Network Access restrictions are enabled.

### Logic

1. Detect installed Chromium browsers
2. Evaluate Local Network Access configuration
3. Determine if remediation is required

### Exit Codes

| Code | Status               |
| ---- | -------------------- |
| 0    | Compliant            |
| 1    | Remediation required |

### Example

```powershell
.\DisableLocalNetworkAccessChecks--Detect.ps1
```

---

# 🛠 Remediation Script

**File**

```
DisableLocalNetworkAccessChecks--Remediate.ps1
```

### Purpose

Applies the configuration required to disable Local Network Access restrictions.

### Actions

The remediation script performs the following steps:

1. Detect installed browsers
2. Stop running browser processes
3. Apply configuration changes
4. Restart browsers if necessary

### Example

```powershell
.\DisableLocalNetworkAccessChecks--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Browsers

Supported:

* Google Chrome
* Microsoft Edge

### Permissions

Depending on deployment method:

* Local Administrator (recommended)
* Intune System context

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```
DisableLocalNetworkAccessChecks--Detect.ps1
```

### Remediation Script

```
DisableLocalNetworkAccessChecks--Remediate.ps1
```

### Recommended Settings

| Setting                                | Value |
| -------------------------------------- | ----- |
| Run script in 64-bit PowerShell        | Yes   |
| Run script using logged-on credentials | Yes   |
| Enforce script signature check         | No    |

---

# 🔧 Typical Workflow

1. Intune runs **Detection Script**
2. Script checks browser configuration
3. If restriction detected → Exit Code **1**
4. Intune runs **Remediation Script**
5. Script applies configuration
6. Browser restrictions are removed

---

# 🛡 Operational Notes

* Browser processes may restart during remediation.
* Test scripts on **pilot devices** before full deployment.
* Some browser updates may revert configuration changes.
* Remediation can be scheduled periodically through Intune.

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
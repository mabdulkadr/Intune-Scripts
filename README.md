# 🚀 Intune Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Microsoft Graph](https://img.shields.io/badge/API-Microsoft%20Graph-orange.svg)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

# 📖 Overview

**Intune Scripts** is a curated collection of **PowerShell automation scripts for Microsoft Intune and Microsoft Graph**.

The repository provides ready-to-use scripts that help IT administrators automate common device management tasks such as:

* Device configuration
* Compliance enforcement
* Automated remediation
* Reporting and monitoring
* Intune management automation

The scripts are designed to work in modern **Microsoft Endpoint Management environments** and follow a **Detection + Remediation pattern** where applicable.

---

# 📂 Repository Structure

```
Intune-Scripts
│
├── Intune - Compliance Policy
│   └── Scripts related to compliance settings and validation
│
├── Intune - Remediation Scripts
│   └── Detection + Remediation scripts for Intune Proactive Remediations
│
├── Intune - Scripts
│   └── General automation scripts for Intune administration
│
└── Intune Community Tools
    └── Helpful utilities inspired by community solutions
```

---

# ✨ Features

This repository includes scripts covering multiple Intune management scenarios:

### 🖥 Device Management

* Device configuration automation
* System configuration checks
* Restore point management

### 🔄 Proactive Remediations

* Detection + Remediation script patterns
* Automated issue recovery
* Scheduled health checks

### 📊 Reporting & Monitoring

* Device health checks
* Compliance verification
* System configuration validation

### 🔐 Security & Configuration

* WinRM configuration
* Secure channel repair
* Network configuration scripts

### ⚙ Automation

* Windows update automation
* System maintenance scripts
* Device sync fixes

---

# ⚙ Requirements

Most scripts require:

* **Windows PowerShell 5.1 or later**
* **Administrator privileges**
* **Microsoft Graph PowerShell SDK** (for Graph-related scripts)

Install Microsoft Graph module:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

---

# 🚀 Getting Started

Clone the repository:

```bash
git clone https://github.com/mabdulkadr/Intune-Scripts.git
```

Navigate to the desired script folder and run a script:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\<Folder>\<ScriptName>.ps1
```

---

# 🧭 Recommended Usage

These scripts are commonly used with:

* **Microsoft Intune Proactive Remediations**
* **Device management automation**
* **Endpoint health monitoring**
* **Enterprise device troubleshooting**

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

## ⚠️ Disclaimer

This script is provided **as-is** without warranty.
The author is **not responsible** for unintended modifications or data loss.
Always test thoroughly before deploying in production.
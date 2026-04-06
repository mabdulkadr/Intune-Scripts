
# 🚀 Intune Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Microsoft Graph](https://img.shields.io/badge/API-Microsoft%20Graph-orange.svg)

![Stars](https://img.shields.io/github/stars/mabdulkadr/Intune-Scripts?style=social)
![Forks](https://img.shields.io/github/forks/mabdulkadr/Intune-Scripts?style=social)
![Last Commit](https://img.shields.io/github/last-commit/mabdulkadr/Intune-Scripts)

[![Buy Me A Coffee](https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

# 📖 Overview

**Intune Scripts** is a production-ready repository of **PowerShell 5.1 automation scripts for Microsoft Intune and Microsoft Graph**.

The repository is designed for enterprise environments where scalability, automation, and reliability are critical. It provides structured solutions for managing endpoints, enforcing compliance, and automating operational workflows.

---

# 🔹 Enterprise Intune Automation Toolkit

This repository enables:

- Automated endpoint configuration  
- Proactive issue detection and remediation  
- Compliance validation and enforcement  
- Tenant-level administrative automation  
- Standardized device management operations  

Built with focus on:

- Stability in production environments  
- Compatibility with Intune execution model  
- Minimal dependencies  
- Scalable automation across thousands of devices  

---

# 🧩 Real-World Coverage

This repository reflects real enterprise use cases:

- Managing large-scale Intune environments  
- Automating compliance drift correction  
- Supporting hybrid identity (Active Directory + Entra ID)  
- Reducing manual IT operational overhead  
- Enforcing standardized configurations across endpoints  

---

# 🏗 Architecture Pattern

Most scripts follow a structured execution model:

```

Detection → Evaluation → Remediation → Compliance

```

Aligned with:

- Microsoft Intune Proactive Remediations  
- Enterprise self-healing strategies  
- Automated endpoint lifecycle management  

---

# 📂 Repository Structure

```

Intune-Scripts
│
├── Intune Community Tools
│   └── Community-driven utilities and advanced tools
│
├── Intune-Compliance-Policies
│   └── Custom compliance detection and validation scripts
│
├── Intune-Configuration-Profiles
│   └── Device configuration and restriction automation
│
├── Intune-Management-Scripts
│   └── Administrative and tenant-level automation scripts
│
├── Intune-Proactive-Remediations
│   └── Detection and remediation script pairs
│
└── README.md

````

---

# ⚙ Requirements

### Environment
- Windows PowerShell **5.1 or later**  
- Administrator privileges  
- Microsoft Intune tenant  

### Modules
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
````

Optional (depending on script):

```powershell
Install-Module Microsoft.Graph.Authentication
```

---

# 🚀 Getting Started

Clone the repository:

```bash
git clone https://github.com/mabdulkadr/Intune-Scripts.git
```

Run a script:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\<Folder>\<ScriptName>.ps1
```

---

# 🚀 Intune Deployment (Recommended)

Use with:

* Microsoft Intune
* Proactive Remediations

Deployment model:

1. Upload Detection script
2. Upload Remediation script
3. Assign to device group
4. Configure schedule

---

# 🔁 Operational Workflow

* Detection script evaluates device state
* Exit code determines compliance
* Remediation script executes only if required
* Device returns to compliant state

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.2**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.





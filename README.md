
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

# ✨ Core Capabilities

## 🖥 Device Management
- Configuration enforcement  
- System validation checks  
- Device state normalization  

## 🔄 Proactive Remediations
- Detection scripts with proper exit codes  
- Automated remediation workflows  
- Scheduled self-healing operations  

## 📊 Reporting & Monitoring
- Device health assessment  
- Compliance verification  
- Configuration drift detection  

## 🔐 Security & Configuration
- Secure channel repair  
- WinRM and connectivity fixes  
- Network and identity validation  

## ⚙ Automation
- Windows Update orchestration  
- System maintenance automation  
- Device sync and recovery operations  

---

# 🧠 Design Principles

- Graph-first approach (no legacy dependencies)  
- PowerShell 5.1 compatibility (Intune-safe)  
- Idempotent execution logic  
- Modular and reusable script design  
- Optimized for enterprise scale  

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

# 📊 Use Cases

* Enterprise endpoint standardization
* Automated troubleshooting at scale
* Compliance enforcement automation
* Device health monitoring
* IT operations optimization

---

# 📁 Structure Philosophy

Each folder represents a functional domain:

| Folder          | Purpose                         |
| --------------- | ------------------------------- |
| Compliance      | Policy validation               |
| Configuration   | Device settings enforcement     |
| Management      | Administrative automation       |
| Remediations    | Self-healing logic              |
| Community Tools | Advanced and experimental tools |

---

# 📈 Why This Repository

* Built for real enterprise environments
* Designed for large-scale deployments
* Based on Microsoft Graph best practices
* Avoids deprecated modules (MSOnline / AzureAD)
* Fully compatible with Intune execution model

---

# ⭐ Support & Contribution

If this repository supports your work:

* Star the repository
* Fork for customization
* Share within your IT team

---

# 📌 Contribution

Contributions are accepted for:

* New automation scenarios
* Performance improvements
* Enhancements using Microsoft Graph

---

# 📜 License

Licensed under the MIT License:
[https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)

---

# 👤 Author

**Mohammad Abdulkader Omar**
Senior System Engineer | Microsoft 365 | Intune | Azure

🌐 [https://momar.tech](https://momar.tech)
💻 [https://github.com/mabdulkadr](https://github.com/mabdulkadr)

Version: **1.2**

---

# ⚠️ Disclaimer

This repository is provided **as-is** without warranty.
Test all scripts in a staging environment before production use.
The author is not responsible for any unintended impact.




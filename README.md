ضع هذه النسخة الاحترافية الجديدة لملف Intune-Scripts README.md:

# 🚀 Intune Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Microsoft Graph](https://img.shields.io/badge/Auth-Graph%20API-orange.svg)
![Automation](https://img.shields.io/badge/Mode-Automation-brightgreen.svg)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## 📖 Overview

**Intune Scripts** is a centralized collection of enterprise-grade PowerShell tools and automation resources built to simplify and standardize Microsoft Intune operations.

The repository focuses on:

- Endpoint lifecycle automation
- Compliance and policy management
- Reporting and visibility
- Remediation and operational control
- Microsoft Graph–based integrations

Designed for modern IT operations teams managing large-scale environments.

---

## 🎯 Purpose

This repository helps administrators:

- Reduce manual configuration tasks
- Standardize Intune deployment models
- Automate repetitive administrative workflows
- Improve security posture
- Maintain scalable endpoint governance

---

## 📂 Repository Structure

Intune-Scripts │ ├── Autopilot Importer ├── Intune - Compliance Policy ├── Intune - Remediation Scripts ├── Intune - Scripts ├── Intune Community Tools └── README.md

Each directory contains focused tools aligned with a specific operational domain.

---

## ✨ Core Capabilities

### 📦 Application Deployment
- Win32 app deployment automation
- Bulk deployment handling
- Upgrade and maintenance workflows

### 🛡 Device Compliance
- Compliance validation scripts
- Health state enforcement
- Configuration audits

### ⚙ Policy Management
- Automated policy creation
- Assignment standardization
- Configuration deployment support

### 🔄 Remediation Scripts
- Detection + correction logic
- Automated drift remediation
- Proactive issue resolution

### 📊 Reporting & Monitoring
- Device inventory exports
- Compliance reporting
- Primary user updates
- Graph-powered data extraction

---

## 🔐 Authentication Model

Scripts support secure connection methods including:

- Microsoft Graph Interactive authentication
- App-only authentication (Client Secret / Certificate)
- Modern Graph SDK patterns

All implementations follow Microsoft security best practices.

---

## ⚙ Requirements

- Windows PowerShell 5.1+
- Microsoft Intune Administrator role
- Microsoft Graph permissions
- Test environment recommended before production

---

## 🚀 Getting Started

Clone the repository:

```bash
git clone https://github.com/mabdulkadr/Intune-Scripts.git

Install required modules:

Install-Module Microsoft.Graph -Scope CurrentUser

Review individual folder documentation before execution.


---

📜 License

This project is licensed under the MIT License.


---

👤 Author

Mohammad Abdelkader
Website: https://momar.tech


---

☕ Support

If this repository supports your operational workflow, consider supporting its development:

https://www.buymeacoffee.com/mabdulkadrx


---

⚠ Disclaimer

All scripts are provided as-is.

Validate in staging before production

Ensure correct RBAC permissions

Confirm compliance with organizational policy

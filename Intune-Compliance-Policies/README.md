# 💽 Intune-Compliance-Policies – Intune Custom Compliance Script Library

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Automation-Intune%20Custom%20Compliance-brightgreen.svg)
![Mode](https://img.shields.io/badge/Mode-Compliance%20Validation-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

This folder contains PowerShell-based **Microsoft Intune custom compliance** content.

Unlike proactive remediations, the projects in this area are designed to **report state** back to Intune rather than change it. Most packages return JSON that matches a companion compliance rule file so Intune can evaluate application presence, application version, or other device conditions.

Each subfolder is documented separately and usually contains:

* A PowerShell detection or reporting script
* A JSON compliance rule when applicable
* A project-specific `README.md`

---

# ✨ Core Features

### 🔹 Intune-Compatible JSON Output

The scripts in this area are built around the output format expected by **Intune custom compliance policies**.

---

### 🔹 Registry and App State Reporting

Most packages inspect installed software or device state through local Windows data sources such as uninstall registry entries.

---

### 🔹 Project-Level Packaging

Each compliance scenario is isolated in its own folder so the script, rule file, and documentation stay together.

---

# 📂 Project Structure

```text
Intune-Compliance-Policies
│
├── App Presence Compliance
├── App Version Compliance
├── CustomeCompliancePolicyGeneratorGUI
└── README.md
```

---

# 🚀 Projects Included

## 📦 Compliance Packages

This folder currently contains:

* `App Presence Compliance`
* `App Version Compliance`
* `CustomeCompliancePolicyGeneratorGUI`

Each package has its own `README.md` explaining the exact workflow and files included.

---

# ⚙️ Requirements

### Platform

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Service Requirement

* Microsoft Intune with **custom compliance policy** support

---

# 🧭 Usage Model

1. Open the target project folder
2. Review the included `README.md`
3. Adjust any package-specific configuration values
4. Upload the PowerShell script and JSON rule to Intune as needed

---

# 🛡 Operational Notes

* These projects are primarily **reporting/compliance** assets, not remediation packages.
* Exact matching logic, JSON shape, and supported conditions vary by project.
* Always test the returned JSON against the intended Intune compliance rule before production use.

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

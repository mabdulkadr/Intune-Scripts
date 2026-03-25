# 💽 Intune-Proactive-Remediations – Intune Proactive Remediation Library

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Automation-Intune%20Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Mode-Detection%20and%20Remediation-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

This folder contains the repository's **Microsoft Intune proactive remediation** content.

The packages here are organized as standalone remediation projects, each with its own detection script, remediation script, logging pattern, and project-specific `README.md`. The structure and writing standard in this area are also used as the baseline for the rest of the repository.

This folder includes:

* The main remediation collections
* The style and documentation standard used across the library

---

# ✨ Core Features

### 🔹 Project-Based Remediation Packages

Each remediation scenario lives in its own folder so detection logic, remediation logic, and documentation stay together.

---

### 🔹 Unified Script Structure

Packages in this area follow a common structure for:

* `Configuration`
* `Functions`
* `Detection Logic` or `Remediation Logic`
* Logging to the `IntuneLogs\<SolutionName>` path on the system drive

---

### 🔹 Standardized Documentation

Every remediation package includes a `README.md` that explains what the package checks, what it changes, and how it should be deployed.

---

### 🔹 Local Logging

* Uses the standardized Intune-style logging pattern under <SystemDrive>\IntuneLogs\<PackageName>
* Describes the local logging convention used across the remediation package folders

---

# 🚀 Folders Included

## 📁 Main Collections

* `Remediation package folders grouped by scenario`
* Supporting documentation and search utilities

## 📘 Reference Standard

* `_CleanUpDisk-Style-Standard.md`

This markdown file defines the formatting and writing style used to keep remediation packages consistent.

---

# ⚙️ Requirements

### Platform

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Service Requirement

* Microsoft Intune with **Proactive Remediations**

---

# 🧭 Usage Model

1. Open the remediation collection you need
2. Review the package-level `README.md`
3. Validate detection and remediation behavior
4. Deploy the package through Intune Scripts and Remediations

---

# 🛡 Operational Notes

* This folder contains many independent remediation packages with different scopes and prerequisites.
* Some packages are cleanup tools, some are repair workflows, and some are notification or hardening packages.
* Use the package-level `README.md` as the authoritative deployment guide for each remediation.

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




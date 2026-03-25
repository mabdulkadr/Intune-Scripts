# 💽 Intune-Configuration-Profiles – Configuration Baseline Reference Area

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Automation-Configuration%20Reference-brightgreen.svg)
![Mode](https://img.shields.io/badge/Mode-Configuration%20Baseline-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Intune-Configuration-Profiles** is currently a reference area rather than a deployable script package collection.

The folder points to configuration baseline guidance, with the current focus on **OpenIntuneBaseline** as an external reference for practical Microsoft Intune security baselines. At this stage, the folder works more as a documentation landing area than as a source of standalone endpoint scripts.

If additional configuration packages are added later, this location is already suited to hold baseline notes, profile references, and implementation guidance.

---

# ✨ Core Features

### 🔹 Baseline Reference Area

The current content is aimed at helping administrators discover and review Intune configuration baseline material before translating it into production profiles.

---

### 🔹 Future Configuration Workspace

The folder structure is also suitable for future configuration-related content such as:

* Profile design notes
* Baseline documentation
* Security configuration guidance
* Tenant implementation references

---

# 📂 Project Structure

```text
Intune-Configuration-Profiles
│
└── README.md
```

---

# 🚀 Content Included

## 🔎 Reference

**OpenIntuneBaseline**

### Website

```text
https://openintunebaseline.com/
```

### Purpose

Provides community-maintained Microsoft Intune baseline guidance with a focus on usable security settings for managed Windows devices.

---

# ⚙️ Requirements

### Current Requirement

* Review the external baseline guidance and map only the settings that fit your tenant standards and operational model

---

# 🔧 Workflow

1. Review the OpenIntuneBaseline guidance
2. Compare the recommendations with your tenant requirements
3. Convert the relevant settings into Intune configuration profiles, security baselines, or policy documentation

---

# 🛡 Operational Notes

* This folder does not currently contain endpoint PowerShell packages.
* Treat this area as a curated reference location rather than a deployable toolset.
* Validate all recommended settings in a test group before applying them broadly.

---

## ⚠ Disclaimer

These references are provided as-is. Review and test any suggested settings before applying them to production devices.

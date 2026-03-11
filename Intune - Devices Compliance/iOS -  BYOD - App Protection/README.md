
# 🍏 iOS BYOD App Protection – Intune App Protection Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-iOS-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Security](https://img.shields.io/badge/App%20Protection-MAM-green.svg)
![BYOD](https://img.shields.io/badge/BYOD-Policy-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**iOS BYOD App Protection** is a **Microsoft Intune App Protection Policy (MAM)** designed to protect corporate data on **personally owned iOS devices** without requiring full device enrollment.

This policy secures organizational data within managed applications such as Outlook, Teams, OneDrive, and Microsoft Office apps while keeping personal data private.

Key protection mechanisms include:

- Application-level PIN protection
- Data transfer restrictions between managed and unmanaged apps
- Secure storage of corporate files
- Prevention of data backup to personal storage
- Conditional access enforcement

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Designed for **iOS Bring Your Own Device (BYOD)** environments  
- Uses **Microsoft Intune App Protection (MAM)**  
- Protects corporate data without full device enrollment  
- Enforces **application PIN authentication**  
- Restricts corporate data sharing to managed applications only  
- Supports **selective wipe of corporate data**

---

# 📂 Project Structure

```

iOS-BYOD-AppProtection
│
├── iOS - BYOD - App Protection.json
└── README.md

```

---

# ⚙ How It Works

The App Protection Policy enforces security rules directly inside **managed applications** installed on iOS devices.

Typical protected applications include:

- Microsoft Outlook
- Microsoft Teams
- Microsoft OneDrive
- Microsoft Word
- Microsoft Excel
- Microsoft PowerPoint
- Microsoft Edge

Security controls apply **only to corporate data**, leaving personal device usage unaffected.

If policy requirements are not met:

```

Corporate Data → Blocked

```

If security conditions are satisfied:

```

Corporate Data → Accessible

```

---

# 🧾 Policy Details

## iOS - BYOD - App Protection.json

### Purpose

Defines an **iOS App Protection Policy** that protects corporate data on personally owned iPhones and iPads.

### Policy Name

```

iOS - BYOD - App Protection

```

### Platform

```

iOS / iPadOS

```

### Policy Type

```

Microsoft Intune Mobile Application Management (MAM)

```

### Ownership Model

```

BYOD (Bring Your Own Device)

```

### Targeted Applications

The policy targets **Microsoft managed applications** including:

- Outlook
- Teams
- OneDrive
- Word
- Excel
- PowerPoint
- SharePoint
- Planner
- To Do
- Microsoft Edge

---

# 🔐 Security Controls

The policy enforces multiple protection mechanisms to prevent corporate data leakage.

| Security Control | Configuration |
|---|---|
| App PIN Required | Enabled |
| Minimum PIN Length | 6 |
| Simple PIN Blocked | Enabled |
| Maximum PIN Retries | 5 |
| Clipboard Sharing | Managed apps only |
| Data Backup | Blocked |
| Save As | Blocked |
| Printing | Blocked |
| Managed Browser | Microsoft Edge required |

---

# 📁 Data Protection Rules

Corporate data is restricted to approved locations.

Allowed storage locations include:

```

OneDrive for Business
SharePoint

```

Corporate files cannot be exported to:

- Personal storage
- Unmanaged applications
- Unapproved cloud services

---

# 🔗 Managed Link Handling

Corporate links automatically open in **Microsoft Edge** using managed universal links.

Examples include:

- SharePoint
- OneDrive
- Microsoft Teams
- Power BI
- PowerApps
- ServiceNow

This ensures corporate links remain inside protected applications.

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import the Policy

Upload the configuration file:

```

iOS - BYOD - App Protection.json

```

Using:

- Microsoft Graph API
- Intune automation scripts
- Configuration backup / restore tools

---

### 2️⃣ Configure App Protection Policy

Navigate to:

```

Microsoft Intune
Apps → App Protection Policies → iOS/iPadOS

```

Create or import the policy.

---

### 3️⃣ Assign the Policy

Assign the policy to:

- User groups
- Azure AD groups
- BYOD users

App protection policies apply **per user rather than per device**.

---

### 4️⃣ Monitor Compliance

Monitor policy application from:

```

Microsoft Intune
Apps → Monitor → App protection status

```

---

# 💡 Example Use Cases

### Secure BYOD Workforce

Allow employees to securely access corporate email and documents on personal iPhones without exposing company data.

---

### Data Loss Prevention

Prevent sensitive corporate data from being copied to:

- Personal applications
- Personal cloud storage
- Unmanaged apps

---

### Enterprise Data Isolation

Ensure that corporate data stays inside approved Microsoft applications.

---

# 🛠 Customization

Administrators can modify the policy to enforce additional protections such as:

- Stronger PIN requirements
- Offline access restrictions
- Conditional launch controls
- Jailbreak detection rules
- Advanced data transfer restrictions

All modifications can be managed through **Microsoft Intune App Protection Policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune App Protection (MAM)**  
- Suitable for **BYOD environments**  
- Does not require full device enrollment  
- Works with **Microsoft managed applications**  
- Always test policies in a **pilot environment before production deployment**

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.0**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These configurations are provided as-is. Always test policies in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.


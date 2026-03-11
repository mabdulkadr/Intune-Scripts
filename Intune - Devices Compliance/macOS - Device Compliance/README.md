
# 🍏 macOS Device Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/macOS-Security%20Policy-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**macOS - Device Compliance** is a **Microsoft Intune macOS Device Compliance Policy** designed to enforce security requirements on managed macOS devices before they are allowed to access organizational resources.

This compliance policy ensures that Mac devices meet enterprise security standards by enforcing key macOS security controls such as:

- System Integrity Protection (SIP)
- FileVault disk encryption
- macOS firewall protection
- Secure application installation sources

Devices that do not meet these security requirements are marked **non-compliant** and can be restricted from accessing enterprise services through **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Enforces **macOS device security baseline**
- Requires **System Integrity Protection (SIP)**
- Requires **disk encryption (FileVault)**
- Enforces **macOS firewall**
- Restricts application installation sources
- Integrates with **Conditional Access policies**

---

# 📂 Project Structure

```

macOS-Device-Compliance
│
├── macOS - Device Compliance.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates macOS devices against defined security controls.

Devices are checked for:

- System Integrity Protection status
- FileVault disk encryption
- macOS firewall configuration
- Application installation sources
- System security configuration

If all requirements are satisfied:

```

Device → Compliant

```

If any requirement fails:

```

Device → Non-Compliant

```

Non-compliant devices can automatically be blocked from accessing corporate resources using **Microsoft Entra Conditional Access**.

---

# 🧾 Policy Details

## macOS - Device Compliance.json

### Policy Name

```

macOS - Device Compliance

```

### Platform

```

macOS

```

### Policy Type

```

Microsoft Intune macOS Compliance Policy

```

---

# 🛡 Device Security Controls

The compliance policy enforces several macOS security protections.

| Security Setting | Configuration |
|---|---|
| System Integrity Protection (SIP) | Required |
| FileVault Disk Encryption | Required |
| Firewall | Enabled |
| Firewall Block All Incoming | Disabled |
| Firewall Stealth Mode | Disabled |
| Allowed Application Sources | Mac App Store + Identified Developers |

These controls ensure that the macOS device is protected against system tampering, unauthorized applications, and network attacks.

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import the Policy

Upload the configuration file:

```

macOS - Device Compliance.json

```

Using:

- Microsoft Graph API
- Intune configuration automation
- Intune policy backup and restore tools

---

### 2️⃣ Configure Compliance Policy

Navigate to:

```

Microsoft Intune
Devices → Compliance Policies → macOS

```

Create or import the compliance policy.

---

### 3️⃣ Assign the Policy

Assign the policy to:

- macOS device groups
- Azure AD groups
- Managed Mac users

---

### 4️⃣ Monitor Compliance

Compliance status can be monitored from:

```

Microsoft Intune
Devices → Monitor → Compliance

```

---

# 💡 Example Use Cases

### macOS Enterprise Security

Ensure all macOS devices accessing corporate resources meet security standards.

---

### Conditional Access Enforcement

Block insecure macOS devices from accessing:

- Microsoft 365
- Exchange Online
- SharePoint
- Corporate SaaS applications

---

### macOS Device Governance

Maintain a consistent security baseline across all managed Mac devices.

---

# 🛠 Customization

Administrators can enhance this compliance policy with additional controls such as:

- Minimum macOS version enforcement
- Stronger password policies
- Threat protection integration
- Advanced firewall configurations

These settings can be configured through **Microsoft Intune Compliance Policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune macOS Compliance Policies**
- Works with **macOS managed devices**
- Integrates with **Microsoft Entra Conditional Access**
- Always test compliance policies in **pilot groups before production deployment**

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

These configurations are provided as-is. Always test compliance policies in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.


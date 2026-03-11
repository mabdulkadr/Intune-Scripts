
# 🍎 macOS Device Health Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/macOS-Device%20Health-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**macOS Device Health Compliance** is a **Microsoft Intune macOS Compliance Policy** designed to verify that managed macOS devices meet basic system integrity and security requirements before accessing organizational resources.

The policy focuses on validating core macOS security posture, particularly the **System Integrity Protection (SIP)** mechanism.

System Integrity Protection is a built-in Apple security technology that prevents malicious software from modifying protected system files and directories.

If the device does not meet the defined requirements, it is marked **non-compliant**, and access to enterprise resources can be restricted using **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Validates **macOS System Integrity Protection (SIP)**
- Built for **Microsoft Intune macOS Compliance Policies**
- Supports **enterprise macOS device management**
- Integrates with **Conditional Access**
- Ensures macOS devices maintain **system integrity protections**

---

# 📂 Project Structure

```

macOS-DeviceHealth-Compliance
│
├── MacOS - Device Health.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates the macOS device configuration and validates that critical system protections are enabled.

The following checks are applied:

- System Integrity Protection (SIP)

If the device security requirement is satisfied:

```

Device → Compliant

```

If the security requirement is not satisfied:

```

Device → Non-Compliant

```

After the evaluation, **Conditional Access policies** determine whether the device can access enterprise services.

---

# 🧾 Policy Details

## MacOS - Device Health.json

### Purpose

Defines a macOS compliance policy that verifies **system integrity protection status** on managed devices.

### Policy Name

```

MacOS - Device Health

```

### Policy ID

```

5f3ba962-c068-4162-a14c-2a7917d0c0cd

```
---
# 📄 Security Settings

The policy validates the following security configuration.

| Setting | Requirement |
|------|------|
| System Integrity Protection (SIP) | Enabled |

Other security options such as firewall, encryption, and Gatekeeper remain **not configured** in this policy and can be enforced through additional compliance or endpoint security policies.

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import Compliance Policy

Import the JSON file:

```

MacOS - Device Health.json

```

Using:

- Microsoft Graph API
- Intune configuration documentation tools
- PowerShell automation

---

### 2️⃣ Configure Compliance Policy

Navigate to:

```

Microsoft Intune
Devices → Compliance policies → macOS

```

Create or import the compliance policy.

---

### 3️⃣ Assign Policy

Assign the compliance policy to:

- macOS device groups
- user groups
- dynamic device groups

---

### 4️⃣ Monitor Compliance

Monitor device compliance status in:

```

Microsoft Intune
Devices → Monitor → Compliance

```

---

# 💡 Example Use Cases

### macOS Security Baseline

Ensure all managed macOS devices maintain **System Integrity Protection** enabled.

---

### Conditional Access Enforcement

Block access to corporate services if macOS system protection has been disabled.

---

### Enterprise macOS Governance

Maintain a minimal macOS security baseline for managed Apple devices.

---

# 🛠 Customization

Administrators can extend the compliance policy to enforce additional macOS security requirements such as:

- FileVault disk encryption
- macOS Firewall
- Gatekeeper restrictions
- Threat protection integration
- Minimum macOS version

These settings can be implemented through **Intune compliance policies** or **endpoint security policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune macOS Compliance Policies**
- Works best when integrated with **Conditional Access**
- macOS security settings depend on device capabilities
- Always validate policies in a **pilot environment** before production deployment

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


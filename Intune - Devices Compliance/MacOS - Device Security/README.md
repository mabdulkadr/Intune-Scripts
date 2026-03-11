
# 🔐 macOS Device Security Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/macOS-Device%20Security-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**macOS Device Security Compliance** is a **Microsoft Intune macOS Compliance Policy** designed to enforce essential security protections on managed macOS devices.

The policy validates several macOS security controls to ensure devices meet enterprise security requirements before accessing organizational resources.

Security protections enforced by this policy include:

- Disk encryption
- macOS firewall configuration
- Application source restrictions (Gatekeeper)

If a device fails these security requirements, it becomes **non-compliant**, and access to corporate services can be restricted through **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Enforces **macOS device security baseline**
- Validates **FileVault disk encryption**
- Enforces **macOS Firewall protection**
- Restricts applications to **App Store and Identified Developers**
- Designed for **Microsoft Intune macOS Compliance Policies**
- Integrates with **Microsoft Entra Conditional Access**

---

# 📂 Project Structure

```

macOS-DeviceSecurity-Compliance
│
├── MacOS - Device Security.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates device configuration and verifies that required security settings are enabled.

The following protections are validated:

- FileVault disk encryption enabled
- macOS Firewall enabled
- Block all incoming connections
- Gatekeeper configured to allow only trusted applications

If all requirements are satisfied:

```

Device → Compliant

```

If any requirement is not satisfied:

```

Device → Non-Compliant

```

After evaluation, **Conditional Access policies** determine whether the device can access enterprise resources.

---

# 🧾 Policy Details

## MacOS - Device Security.json

### Purpose

Defines a macOS compliance policy enforcing **core device security protections**.

### Policy Name

```

MacOS - Device Security

```

### Policy ID

```

d95ee62e-8813-4f29-89aa-758ec869fb21

```

---

### Compliance Action

| Action | Grace Period |
|------|------|
| Block Access | 12 Hours |

Devices that become non-compliant will be blocked from accessing corporate resources after the grace period.

---

# 📄 Security Settings

The policy enforces the following macOS security configuration.

| Setting | Requirement |
|------|------|
| Storage Encryption | Enabled |
| macOS Firewall | Enabled |
| Block All Incoming Connections | Enabled |
| Gatekeeper | Mac App Store and Identified Developers |

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import Compliance Policy

Import the JSON configuration file:

```

MacOS - Device Security.json

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

Ensure all managed macOS devices enforce encryption and firewall protections.

---

### Conditional Access Enforcement

Block devices that do not meet security requirements such as:

- Disk encryption disabled
- Firewall disabled
- Untrusted application sources enabled

---

### Enterprise Apple Device Governance

Provide a consistent macOS security baseline for managed corporate devices.

---

# 🛠 Customization

Administrators can extend this compliance policy to include additional macOS protections such as:

- System Integrity Protection
- Minimum macOS version
- Threat protection integration
- Advanced endpoint security policies

These configurations can be implemented using **Intune Compliance Policies** or **Endpoint Security policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune macOS Compliance Policies**
- Works best with **Conditional Access**
- Security settings must align with device capabilities
- Always validate policies in a **pilot environment** before production rollout

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


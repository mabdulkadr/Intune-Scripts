
# 💻 Device Health Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/Windows-Device%20Health-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**Device Health Compliance** is a **Microsoft Intune Windows Device Compliance Policy** designed to ensure that managed Windows devices meet essential platform security requirements before accessing corporate resources.

The policy validates several Windows device health protections including:

- BitLocker encryption
- Secure Boot
- Code Integrity enforcement

These checks ensure that devices maintain a **trusted boot chain and system integrity**, which is essential for protecting enterprise environments.

If a device does not meet the required health conditions, it becomes **non-compliant** and may be blocked from accessing corporate resources through **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Enforces **Windows device health requirements**
- Built for **Microsoft Intune Device Compliance**
- Integrates with **Microsoft Entra Conditional Access**
- Ensures devices use **trusted boot and disk protection**
- Provides baseline **endpoint security posture enforcement**

---

# 📂 Project Structure

```

Device-Health-Compliance
│
├── Win - Device Health.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates device security posture based on several Windows platform protections.

The following security conditions are checked:

- BitLocker encryption enabled
- Secure Boot enabled
- Code Integrity enabled

If all required protections are active:

```

Device → Compliant

```

If any required protection is missing:

```

Device → Non-Compliant

```

After compliance evaluation, **Conditional Access policies** determine whether the device is allowed to access corporate services.

---

# 🧾 Policy Details

## Win - Device Health.json

### Purpose

Defines a Windows compliance policy that verifies the **device health state and core security protections**.

### Policy Name

```

Win - Device Health

```

### Policy ID

```

e87d2b39-75a0-4eca-8729-db419a7551fc

```
---
### Compliance Action

| Action | Grace Period |
|------|------|
| Block Access | 12 Hours |

If a device becomes non-compliant, access to corporate resources will be blocked after the grace period.

---

# 📄 Security Settings

The policy enforces the following security requirements.

| Setting | Requirement |
|------|------|
| BitLocker Encryption | Required |
| Secure Boot | Required |
| Code Integrity | Required |

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import Compliance Policy

Import the JSON file:

```

Win - Device Health.json

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
Devices → Compliance policies → Windows

```

Create or import the compliance policy.

---

### 3️⃣ Assign Policy

Assign the policy to:

- Device groups
- User groups
- Dynamic device groups
- Autopilot device groups

---

### 4️⃣ Monitor Compliance

View device compliance status in:

```

Microsoft Intune
Devices → Monitor → Compliance

```

---

# 💡 Example Use Cases

### Endpoint Security Baseline

Ensure all corporate devices maintain required **hardware-backed security protections**.

---

### Conditional Access Enforcement

Block devices that do not meet basic security conditions such as:

- Disk encryption disabled
- Secure boot disabled
- System integrity protection disabled

---

### Enterprise Compliance Governance

Provide baseline security requirements before devices can access:

- Microsoft 365
- SharePoint Online
- Exchange Online
- Corporate SaaS platforms

---

# 🛠 Customization

Administrators can extend this policy by enabling additional security checks such as:

- TPM requirement
- Firewall enforcement
- Microsoft Defender health
- Kernel DMA protection
- Virtualization-based security

These settings can be configured through **Intune Compliance Policies** or **Endpoint Security policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune Device Compliance Policies**
- Works best when integrated with **Conditional Access**
- Hardware security features must be supported by the device
- Always test policies in a **pilot group** before production deployment

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

These configurations are provided as-is. Test compliance policies in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.


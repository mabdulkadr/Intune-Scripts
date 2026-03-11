
# 🔐 Device Security Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/Windows-Device%20Security-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**Device Security Compliance** is a **Microsoft Intune Windows Device Compliance Policy** that ensures managed Windows devices meet core security requirements before accessing organizational resources.

The policy enforces a minimum **endpoint security baseline** by validating critical security protections such as:

- Firewall protection
- Antivirus presence
- Anti-spyware protection
- TPM hardware security

These checks help ensure devices maintain a secure configuration aligned with enterprise security standards.

If a device fails these requirements, it becomes **non-compliant** and access to corporate services may be restricted through **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Validates **core Windows device security settings**
- Built for **Microsoft Intune Device Compliance Policies**
- Integrates with **Microsoft Entra Conditional Access**
- Ensures devices maintain required **security protections**
- Supports enterprise **endpoint compliance enforcement**

---

# 📂 Project Structure

```

Device-Security-Compliance
│
├── Win - Device Security.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates the device security posture based on several Windows security protections.

The following protections are validated:

- Windows Firewall enabled
- Antivirus protection present
- Anti-spyware protection active
- TPM hardware security available

If all required protections are active:

```

Device → Compliant

```

If any required protection is missing:

```

Device → Non-Compliant

```

After evaluation, **Conditional Access policies** determine whether the device can access corporate resources.

---

# 🧾 Policy Details

## Win - Device Security.json

### Purpose

Defines a Windows compliance policy that verifies **core device security protections**.

### Policy Name

```

Win - Device Security

```

### Policy ID

```

09decce4-cd10-4a00-891f-d9bccf2cc097

```
---
### Compliance Action

| Action | Grace Period |
|------|------|
| Block Access | 6 Hours |

If a device becomes non-compliant, access to corporate resources will be blocked after the grace period.

---

# 📄 Security Settings

The policy enforces the following security checks.

| Setting | Requirement |
|------|------|
| Firewall Required | Enabled |
| Antivirus Required | Enabled |
| Anti-Spyware Required | Enabled |
| TPM Required | Enabled |

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import Compliance Policy

Import the JSON file:

```

Win - Device Security.json

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

Ensure all corporate devices maintain required security protections before accessing enterprise services.

---

### Conditional Access Enforcement

Block devices that do not meet security standards such as:

- Firewall disabled
- Antivirus missing
- Anti-spyware protection disabled
- TPM not present

---

### Enterprise Device Compliance

Provide baseline device security before allowing access to:

- Microsoft 365
- Exchange Online
- SharePoint Online
- Corporate SaaS platforms

---

# 🛠 Customization

Administrators can extend this compliance policy with additional security checks such as:

- BitLocker encryption
- Secure Boot
- Microsoft Defender health
- Kernel DMA protection
- Virtualization-based security

These settings can be configured using **Intune Compliance Policies** or **Endpoint Security policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune Device Compliance Policies**
- Works best with **Conditional Access policies**
- Security features must be supported by the device hardware
- Always test compliance policies in a **pilot environment** before production deployment

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



# 🛡 Defender for Endpoint Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/Microsoft-Defender%20for%20Endpoint-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**Defender for Endpoint Compliance** is a configuration designed for **Microsoft Intune Device Compliance Policies**.

This policy ensures that Windows devices meet the required **Microsoft Defender security requirements** before they are allowed to access corporate resources.

The compliance policy validates key Defender protections such as:

- Microsoft Defender enabled
- Real-time protection enabled
- Security signature status monitoring

If a device does not meet these requirements, it becomes **non-compliant** and may be blocked from accessing corporate services through **Microsoft Entra Conditional Access**.

The project contains the exported **Intune Compliance Policy JSON configuration**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Validates **Microsoft Defender protection status**
- Built for **Microsoft Intune Device Compliance**
- Integrates with **Microsoft Entra Conditional Access**
- Detects devices with inactive or unhealthy Defender protection
- Automatically enforces **access restrictions**
- Supports **enterprise security compliance enforcement**

---

# 📂 Project Structure

```

Defender-Endpoint-Compliance
│
├── Win - Defender for Endpoint.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy checks the Defender security posture on managed Windows devices.

The following security signals are evaluated:

- Microsoft Defender enabled
- Real-time protection status
- Defender signature update status

If Defender protection is **active and healthy**:

```

Device → Compliant

```

If Defender protection is **disabled or outdated**:

```

Device → Non-Compliant

```

After the compliance evaluation, **Conditional Access policies** determine whether the device can access corporate resources.

---

# 🧾 Policy Details

## Win - Defender for Endpoint.json

### Purpose

Defines a Windows device compliance policy that verifies the health of **Microsoft Defender protection**.

### Policy Name

```

Win - Defender for Endpoint

```

### Policy ID

```

19214506-43ca-4284-a782-2aad6e8f12d7

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
| Microsoft Defender Enabled | Required |
| Real-Time Protection | Required |
| Signature Status | Monitored |

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import Compliance Policy

Import the JSON file:

```

Win - Defender for Endpoint.json

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

### Endpoint Security Enforcement

Ensure that all corporate devices maintain active **Microsoft Defender protection**.

---

### Conditional Access Security

Block devices with:

- Disabled Defender
- Outdated antivirus signatures
- Disabled real-time protection

---

### Enterprise Device Compliance

Provide a baseline security requirement before allowing devices to access:

- Microsoft 365
- SharePoint Online
- Exchange Online
- Corporate SaaS platforms

---

# 🛠 Customization

Administrators can extend the compliance policy by enabling additional security checks such as:

- BitLocker encryption
- Secure Boot
- TPM requirement
- Firewall enforcement
- Kernel DMA protection

These settings can be configured through **Intune Compliance Policies** or **Endpoint Security Policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune Device Compliance Policies**
- Works best when integrated with **Conditional Access**
- Defender must be active for the device to remain compliant
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

These configurations are provided as-is. Always test compliance policies in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.


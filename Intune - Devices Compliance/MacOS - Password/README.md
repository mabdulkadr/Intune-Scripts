
# 🔑 macOS Password Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/macOS-Password%20Policy-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**macOS Password Compliance** is a **Microsoft Intune macOS Compliance Policy** that enforces password security standards on managed macOS devices.

The policy ensures that users configure secure passwords before devices are considered compliant and allowed to access enterprise resources.

Security requirements enforced include:

- Password required for device access  
- Blocking simple passwords  
- Minimum password length enforcement  
- Automatic device lock after inactivity  
- Password complexity requirements  

If a device does not meet the required password configuration, it is marked **non-compliant**, and access to corporate services can be restricted through **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Enforces **macOS password security policies**
- Requires **alphanumeric passwords**
- Blocks weak or simple passwords
- Enforces **automatic screen lock**
- Supports **enterprise compliance enforcement**
- Integrates with **Conditional Access policies**

---

# 📂 Project Structure

```

macOS-Password-Compliance
│
├── MacOS - Password.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates macOS password configuration settings.

The following security conditions are validated:

- Password required for device access
- Simple passwords blocked
- Minimum password length
- Password complexity requirements
- Automatic lock after inactivity

If all password requirements are satisfied:

```

Device → Compliant

```

If any password requirement is not satisfied:

```

Device → Non-Compliant

```

Conditional Access policies then determine whether the device can access enterprise resources.

---

# 🧾 Policy Details

## MacOS - Password.json

### Purpose

Defines a macOS compliance policy enforcing **password security requirements** for managed Apple devices.

### Policy Name

```

MacOS - Password

```

### Policy ID

```

59c110d2-ebaf-47ea-8e1a-2606e46ca99c

```

---

### Compliance Action

| Action | Grace Period |
|------|------|
| Block Access | Immediate |

Devices that become non-compliant will be blocked from accessing enterprise resources immediately.

---

# 📄 Password Security Settings

The policy enforces the following password configuration.

| Setting | Requirement |
|------|------|
| Password Required | Enabled |
| Password Type | Alphanumeric |
| Minimum Password Length | 8 |
| Block Simple Passwords | Enabled |
| Password History | 1 Previous Password |
| Minimum Character Set Count | 1 |
| Lock After Inactivity | 15 Minutes |

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import Compliance Policy

Import the JSON configuration file:

```

MacOS - Password.json

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

Assign the policy to:

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

### Enterprise Authentication Security

Ensure all macOS devices enforce strong password policies before accessing corporate services.

---

### Conditional Access Enforcement

Block devices that do not enforce password protection or use weak passwords.

---

### Apple Device Governance

Maintain a consistent password policy across all managed macOS devices.

---

# 🛠 Customization

Administrators can extend this compliance policy with additional password controls such as:

- Password expiration rules  
- Stronger complexity requirements  
- Increased password history  
- Minimum OS version enforcement  

These settings can be modified within **Microsoft Intune Compliance Policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune macOS Compliance Policies**
- Works best when integrated with **Conditional Access**
- Password policies should align with organizational security standards
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

These configurations are provided as-is. Always test compliance policies in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.


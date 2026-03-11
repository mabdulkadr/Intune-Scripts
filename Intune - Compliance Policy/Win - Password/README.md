
# 🔑 Password Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/Windows-Password%20Policy-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**Password Compliance** is a **Microsoft Intune Windows Device Compliance Policy** designed to enforce password security requirements on managed Windows devices.

The policy ensures that devices meet basic authentication requirements before they are considered compliant and allowed to access organizational resources.

The configuration enforces password protection rules including:

- Password required for device access
- Minimum password length
- Simple password blocking
- Automatic lock after inactivity

If the device does not meet these requirements, it becomes **non-compliant**, and access to corporate resources can be restricted through **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Enforces **password security requirements**
- Built for **Microsoft Intune Device Compliance Policies**
- Prevents weak or simple passwords
- Supports **automatic device lock enforcement**
- Integrates with **Conditional Access policies**
- Helps enforce **enterprise authentication standards**

---

# 📂 Project Structure

```

Password-Compliance
│
├── Win - Password.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates device password configuration settings.

The following security conditions are checked:

- Password required for device access
- Minimum password length requirement
- Simple passwords blocked
- Automatic device lock after inactivity

If the password configuration meets requirements:

```

Device → Compliant

```

If the password configuration does not meet requirements:

```

Device → Non-Compliant

```

Conditional Access policies then determine whether the device can access corporate resources.

---

# 🧾 Policy Details

## Win - Password.json

### Purpose

Defines a Windows compliance policy that enforces **password security standards**.

### Policy Name

```

Win - Password

```

### Policy ID

```

f201b86e-ce93-4543-9278-3840544bb010

```
---
### Compliance Action

| Action | Grace Period |
|------|------|
| Block Access | Immediate |

If a device becomes non-compliant, access to corporate resources is blocked immediately.

---

# 📄 Password Security Settings

The policy enforces the following password configuration.

| Setting | Requirement |
|------|------|
| Password Required | Enabled |
| Block Simple Passwords | Enabled |
| Minimum Password Length | 8 |
| Password Type | Numeric |
| Lock After Inactivity | 15 Minutes |

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import Compliance Policy

Import the JSON file:

```

Win - Password.json

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

Monitor device compliance in:

```

Microsoft Intune
Devices → Monitor → Compliance

```

---

# 💡 Example Use Cases

### Enterprise Authentication Security

Ensure all managed Windows devices enforce password protection before accessing corporate services.

---

### Conditional Access Enforcement

Block devices that do not enforce password protection policies.

---

### Device Security Baseline

Maintain minimum authentication requirements across enterprise endpoints.

---

# 🛠 Customization

Administrators can modify this compliance policy to enforce additional password requirements such as:

- Alphanumeric password type
- Password expiration
- Password history enforcement
- Additional lock rules

These configurations can be adjusted directly within **Microsoft Intune Compliance Policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune Device Compliance Policies**
- Works best when integrated with **Conditional Access**
- Password settings should align with organizational security policies
- Always test compliance policies in a **pilot group** before production deployment

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



# 🍎 iOS Device Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-iOS-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/iOS-Security%20Policy-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**iOS - Device Compliance** is a **Microsoft Intune iOS Device Compliance Policy** designed to enforce security requirements on managed Apple devices before they can access corporate resources.

This policy ensures that iPhones and iPads meet organizational security standards such as:

- Enforcing device passcodes  
- Blocking jailbroken devices  
- Requiring password expiration  
- Enforcing inactivity lock settings  
- Integrating with threat protection requirements  

Devices that fail these security requirements are marked **non-compliant** and can be blocked from accessing enterprise services through **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Enforces **iOS device security baseline**
- Requires **device passcode**
- Blocks **jailbroken devices**
- Enforces **password expiration**
- Requires **automatic screen lock**
- Integrates with **Conditional Access policies**

---

# 📂 Project Structure

```

iOS-Device-Compliance
│
├── iOS - Device Compliance.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates iOS devices against defined security requirements.

The device must satisfy:

- Passcode configuration rules  
- Jailbreak detection checks  
- Password expiration rules  
- Screen lock timeout configuration  
- Threat protection policy settings  

If all requirements are satisfied:

```

Device → Compliant

```

If any requirement fails:

```

Device → Non-Compliant

```

Non-compliant devices can be blocked from accessing corporate resources using **Microsoft Entra Conditional Access**.

---

# 🧾 Policy Details

## iOS - Device Compliance.json

### Policy Name

```

iOS - Device Compliance

```

### Platform

```

iOS / iPadOS

```

### Policy Type

```

Microsoft Intune iOS Compliance Policy

```

---

# 🔐 Password Requirements

The compliance policy enforces the following password configuration.

| Setting | Requirement |
|------|------|
| Passcode Required | Enabled |
| Passcode Type | Numeric |
| Minimum Passcode Length | 4 |
| Simple Passcodes | Blocked |
| Passcode Expiration | 180 Days |
| Passcode History | 3 Previous Passcodes |

---

# 🛡 Device Security Controls

Additional device security protections enforced by the policy.

| Security Setting | Configuration |
|---|---|
| Jailbroken Devices | Blocked |
| Threat Protection Required Level | Medium |
| Inactivity Screen Lock | 2 Minutes |
| Device Lock Requirement | Immediate |

These checks ensure that devices accessing corporate resources are secure and not compromised.

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import the Policy

Upload the configuration file:

```

iOS - Device Compliance.json

```

Using:

- Microsoft Graph API  
- Intune configuration automation  
- Policy backup / restore tools  

---

### 2️⃣ Configure Compliance Policy

Navigate to:

```

Microsoft Intune
Devices → Compliance Policies → iOS/iPadOS

```

Create or import the policy.

---

### 3️⃣ Assign the Policy

Assign the policy to:

- iOS device groups  
- Azure AD groups  
- Managed Apple users  

---

### 4️⃣ Monitor Compliance

Monitor device compliance status from:

```

Microsoft Intune
Devices → Monitor → Compliance

```

---

# 💡 Example Use Cases

### Enterprise iOS Security

Ensure all iOS devices accessing corporate resources meet security standards.

---

### Conditional Access Enforcement

Prevent insecure or compromised devices from accessing:

- Microsoft 365  
- Exchange Online  
- SharePoint  
- Corporate applications  

---

### Mobile Device Governance

Maintain consistent security policies across all managed iPhones and iPads.

---

# 🛠 Customization

Administrators can extend this compliance policy with additional controls such as:

- Minimum iOS version enforcement  
- Stronger passcode complexity  
- Restricted applications  
- Advanced threat protection integration  

All settings can be configured through **Microsoft Intune Compliance Policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune iOS Compliance Policies**
- Works with **iPhone and iPad devices**
- Integrates with **Microsoft Entra Conditional Access**
- Always test policies with **pilot device groups before production deployment**

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


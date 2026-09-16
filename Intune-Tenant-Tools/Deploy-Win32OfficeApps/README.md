<div align="center">

# 📦 Deploy-Win32OfficeApps

**Intune Win32 deployment packages for Office LTSC 2024, Project 2024 and Visio 2024 — silent, volume-licensed, auto-detects the OS language (English/Arabic).**

Central collection of Office Deployment Tool (ODT) packages for Intune Win32 apps. Each package ships with four configuration variants (64/32-bit × English/Arabic), PowerShell install/uninstall wrappers with dedicated logging, and a registry-driven custom detection script. The default `-Language Auto` picks English or Arabic from the device's UI culture.

[![Intune](https://img.shields.io/badge/Intune-Win32%20App-10B981?style=for-the-badge)](#%EF%B8%8F-quick-reference)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)

[Packages](#-packages-in-this-collection) • [Quick Reference](#%EF%B8%8F-quick-reference) • [Deployment](#%EF%B8%8F-deployment-pattern) • [Requirements](#%EF%B8%8F-requirements)</div>

---

# 📖 Overview

Each subfolder is a self-contained Intune Win32 app package:

| Package | Product | Volume Channel |
| --- | --- | --- |
| [office-ltsc-2024-intune-deploy](./office-ltsc-2024-intune-deploy) | Office LTSC Professional Plus 2024 (`ProPlus2024Volume`) | `PerpetualVL2024` |
| [microsoft-project-2024-intune-deploy](./microsoft-project-2024-intune-deploy) | Microsoft Project Professional 2024 (`ProjectPro2024Volume`) | `PerpetualVL2024` |
| [microsoft-visio-2024-intune-deploy](./microsoft-visio-2024-intune-deploy) | Microsoft Visio Professional 2024 (`VisioPro2024Volume`) | `PerpetualVL2024` |

Every package follows the same pattern so deployments scale consistently across the fleet.

---

# 📂 Packages In This Collection

## 1. Office LTSC Professional Plus 2024
Silent install of Office LTSC Professional Plus 2024 on `PerpetualVL2024`, language auto-detected from the OS UI culture, with auto-detected architecture and four XML variants.

- **Readme**: [office-ltsc-2024-intune-deploy/README.md](./office-ltsc-2024-intune-deploy/README.md)
- **Files**: `Install-ProPlus2024-<arch>-<lang>.xml` ×4, `Uninstall-ProPlus2024.xml`, `Install-OfficeLTSC2024.ps1` (v1.5.0), `Uninstall-OfficeLTSC2024.ps1` (v1.2.0), `Detect-OfficeLTSC2024.ps1` (v1.2.0)

## 2. Microsoft Project Professional 2024
Silent install of Project Pro 2024 on `PerpetualVL2024` (project/portfolio features only — no Word/Excel), language auto-detected from the OS UI culture, four XML variants.

- **Readme**: [microsoft-project-2024-intune-deploy/README.md](./microsoft-project-2024-intune-deploy/README.md)
- **Files**: `Install-ProjectPro2024-<arch>-<lang>.xml` ×4, `Uninstall-ProjectPro2024.xml`, `Install-ProjectPro2024.ps1` (v1.4.0), `Uninstall-ProjectPro2024.ps1` (v1.2.0), `Detect-ProjectPro2024.ps1` (v1.2.0)

## 3. Microsoft Visio Professional 2024
Silent install of Visio Pro 2024 on `PerpetualVL2024`, language auto-detected from the OS UI culture, four XML variants.

- **Readme**: [microsoft-visio-2024-intune-deploy/README.md](./microsoft-visio-2024-intune-deploy/README.md)
- **Files**: `Install-VisioPro2024-<arch>-<lang>.xml` ×4, `Uninstall-VisioPro2024.xml`, `Install-VisioPro2024.ps1` (v1.4.0), `Uninstall-VisioPro2024.ps1` (v1.2.0), `Detect-VisioPro2024.ps1` (v1.2.0)

---

# 🧭 XML Variant Matrix

Each install script resolves `Install-<Product>-<arch>-<lang>.xml` automatically:

| Language | `x64` | `x86` | Content |
| --- | --- | --- | --- |
| `Auto` (default) | auto: OS UI culture → `x64-English` or `x64-Arabic` | auto: OS UI culture → `x86-English` or `x86-Arabic` | `InstalledUICulture` `^ar` → Arabic, else English |
| `English` | `<Product>-x64-English.xml` | `<Product>-x86-English.xml` | `en-us` only |
| `Arabic` | `<Product>-x64-Arabic.xml` | `<Product>-x86-Arabic.xml` | `ar-sa` + Arabic ProofingTools |

**By default** `-Language Auto` installs in the device's OS UI language (Arabic if the culture starts with `ar`, otherwise English). Override per app by passing `-Language English|Arabic` in the Intune install command — or upload a separate app per variant.

---

# ⚙️ Deployment Pattern

Each package is deployed the same way:

1. **Package**: `IntuneWinAppUtil.exe -c "<package-folder>" -s setup.exe -o "<output>"` — or use the GUI-friendly [IntuneWin-Utility](https://github.com/mabdulkadr/IntuneWin-Utility)
2. **Install command**: `powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-<Product>.ps1"`
3. **Uninstall command**: `powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Uninstall-<Product>.ps1"`
4. **Install behavior**: System · **Restart**: Intune will restart
5. **Detection**: upload the matching `Detect-<Product>.ps1` as a custom detection script (run as 64-bit) — or a registry rule on `ProductReleaseIds` contains the product ID
6. **Logs**: `C:\IntuneLogs\<SolutionName>\` (`OfficeLTSC2024`, `ProjectPro2024`, `VisioPro2024`)

> ⚠ **GVLK placeholder**: XML files ship with `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` as PIDKEY. Replace with your organization's KMS GVLK — see [Microsoft KMS Client Setup Keys](https://learn.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys) — before packaging.

> ⚠ **Legacy `.intunewin`**: a stale `Visio.intunewin` from an earlier build remains in the Visio folder (`Install_MS_project.intunewin` and `Install_MS_Visio.intunewin` were removed). Regenerate packages with `IntuneWinAppUtil.exe` or [IntuneWin-Utility](https://github.com/mabdulkadr/IntuneWin-Utility) so they include the current variant set.

---

# ✅ Requirements

| Item | Requirement |
| --- | --- |
| OS | Windows 10 / Windows 11 |
| Architecture | 64-bit and 32-bit (auto-detected by install scripts) |
| PowerShell | 5.1+ (detection runs under the Intune Management Extension) |
| Permissions | Local SYSTEM via Intune (no Graph scopes) |
| Activation | Valid volume license agreement + KMS GVLK in the XML PIDKEY |
| Network | Internet access to the Office CDN on first install (unless offline payload prepared) |

---

## 👤 Author

**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)  

---

## 📜 License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## ⚠ Disclaimer

This skill and every script it generates are provided as-is with no warranty of any kind. Test generated tools in a staging environment before deploying to production. The authors assume no liability for any damage or data loss resulting from their use.

---

<div align="center">

⭐ **If this skill saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) · [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>
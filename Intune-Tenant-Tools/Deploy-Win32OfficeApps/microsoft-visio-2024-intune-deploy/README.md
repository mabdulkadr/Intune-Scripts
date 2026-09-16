<div align="center">

# 🛡️ Microsoft Visio Professional 2024 - Intune Win32 Deployment

**[Silent, volume-licensed deployment package for Microsoft Visio Professional 2024 via Intune Win32 apps.]**

Packages the Office Deployment Tool with a silent 64-bit/32-bit Visio volume configuration, PowerShell install/uninstall scripts with dedicated logging, and a custom Intune detection script for Enterprise enrollment.

[![Intune](https://img.shields.io/badge/Intune-Win32%20App-10B981?style=for-the-badge)](#%EF%B8%8F-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.4.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Structure](#-project-structure) • [Scripts](#-scripts-included) • [Deployment](#%EF%B8%8F-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements)</div>

---

# 📖 Overview

**Microsoft Visio Professional 2024 - Intune Win32 Deployment** deploys Visio Professional 2024 (volume licensed, `VisioPro2024Volume`) to Intune-managed Windows devices using the official Microsoft Office Deployment Tool.

The bundle contains three layers:

- **Configuration**: four XML variants covering every combination of architecture (`x64`/`x86`) and language (`English` en-us, `Arabic` ar-sa) — `Install-VisioPro2024-<arch>-<lang>.xml`. `Uninstall-VisioPro2024.xml` describes what to remove.
- **PowerShell scripts**: `Install-VisioPro2024.ps1` / `Uninstall-VisioPro2024.ps1` auto-detect the installed Office architecture (x64/x86) with an `-Architecture` override, accept a `-Language` variant (`Auto` default / `English`/`Arabic`), anchor every path to their own folder (dot-source safe), verify an elevated context, write a dedicated transcript to `<SystemDrive>\IntuneLogs\VisioPro2024\`, and forward the true ODT exit code.
- **Detection**: `Detect-VisioPro2024.ps1` is the Intune Win32 custom detection rule that marks the app *Installed* only when the Click-to-Run configuration truly reports `VisioPro2024Volume` with a version, and `VISIO.EXE` exists on disk.

A Win32 app uploaded from this folder installs completely silently (no UI, EULA auto-accepted) under the local SYSTEM account.

---

# ✨ Core Features

### 🔹 Silent Volume Deployment
* `Display Level="None" AcceptEULA="TRUE"` — no UI, no prompts, EULA auto-accepted; safe for Task Scheduler and Intune.
* `Channel="PerpetualVL2024"` — the correct channel for Office 2024 volume licenses.
* KMS GVLK activation via `PIDKEY` + `AUTOACTIVATE=1`. Replace the placeholder key with your organization's KMS GVLK — see [Microsoft KMS Client Setup Keys](https://learn.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys).

### 🔹 Auto-Detect Architecture + Language
* `Install-VisioPro2024.ps1` reads the installed Office Click-to-Run `Platform` registry value to select `Install-VisioPro2024-x64-*.xml` or `Install-VisioPro2024-x86-*.xml` automatically.
* `-Architecture x64|x86` override for fresh machines with no prior Office install (defaults to x64).
* `-Language Auto|English|Arabic` selects the language variant (default Auto — installs in the OS UI language via `InstalledUICulture`).

### 🔹 PowerShell Install / Uninstall Scripts
* Every reference is absolute (`$PSScriptRoot` fallback), independent of the caller's working directory and dot-source safe.
* Elevation check fails fast with a clear message if not running as administrator/SYSTEM.
* Dedicated transcript log per operation under `C:\IntuneLogs\VisioPro2024\`.
* Propagates the real `setup.exe` exit code instead of swallowing it.

### 🔹 Intune-Ready Detection
* Registry-driven (`HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration`) with disk-level hardening (`VISIO.EXE`).
* Canonical exit contract: `0` installed / `1` not installed / `2` script error.
* No Graph permissions and no network dependency — pure local SYSTEM check.

---

# 📂 Project Structure

```text
microsoft-visio-2024-intune-deploy
│
├── setup.exe                           Office Deployment Tool (16.0.17830.20162)
├── Install-VisioPro2024-x64-English.xml    Silent install - VisioPro2024Volume / en-us / x64
├── Install-VisioPro2024-x64-Arabic.xml     Silent install - VisioPro2024Volume / ar-sa / x64
├── Install-VisioPro2024-x86-English.xml    Silent install - VisioPro2024Volume / en-us / x86
├── Install-VisioPro2024-x86-Arabic.xml     Silent install - VisioPro2024Volume / ar-sa / x86
├── Uninstall-VisioPro2024.xml     Product removal config
├── Install-VisioPro2024.ps1       PowerShell installer - logging + auto-arch + lang + ODT /configure
├── Uninstall-VisioPro2024.ps1     PowerShell uninstaller - logging + ODT /configure
├── Detect-VisioPro2024.ps1        Intune Win32 App custom detection script
└── README.md
```

> **Legacy file:** `Visio.intunewin` is the original `.intunewin` package from a prior build; `Install_MS_Visio.intunewin` has been removed from this folder. The remaining file is kept for reference only and **must be re-packaged** from this folder using [IntuneWin-Utility](https://github.com/mabdulkadr/IntuneWin-Utility) or `IntuneWinAppUtil.exe` before deployment — the old package contains outdated scripts and a wrong GVLK.

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**
```powershell
Detect-VisioPro2024.ps1
```

### Purpose
Reads the authoritative Click-to-Run registry and reports whether Visio Professional 2024 is genuinely present. Read-only apart from the run transcript; never modifies the system.

### Logic
1. Reads `HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration` (exit `2` if missing/failed).
2. Confirms `ProductReleaseIds` contains `VisioPro2024Volume` (exit `1` if not).
3. Confirms `VersionToReport` is populated (exit `1` if empty — partial install).
4. Confirms `VISIO.EXE` exists under `InstallPath\root\Office16\` (exit `1` if missing).

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Installed (compliant) |
| 1    | Not installed (Intune re-evaluates on next assignment) |
| 2    | Script error |

> In an Intune **Win32 app detection rule**, exit `0` = detected; any non-zero = not detected.

## 🛠 Remediation Script

**File**
```text
Not applicable (N/A)
```

This is a Win32 **installation** package, not a Proactive Remediation pair, so no remediate script exists. If an enrolled device falls out of compliance after install, Intune enforces the existing assignment (re-install/repair) during the next device check-in cycle.

## 🔧 Install / Uninstall PowerShell Scripts

**Files**
```powershell
Install-VisioPro2024.ps1      →  & setup.exe /configure Install-VisioPro2024-<arch>-<lang>.xml
Uninstall-VisioPro2024.ps1    →  & setup.exe /configure Uninstall-VisioPro2024.xml
```

### Install Behavior
1. Fails fast if `setup.exe` or the matching `.xml` is missing next to the script.
2. Enforces elevation (`Test-IsElevated`) — passes automatically under the Intune SYSTEM context.
3. Reads the installed Office architecture from the ClickToRun registry (x64/x86); defaults to x64 for fresh installs or when `-Architecture` is specified.
4. Selects the language variant via `-Language` (default `Auto` — OS UI culture; Arabic if it starts with `ar`, else English).
5. Invokes ODT synchronously and exits with ODT's real return code (`0` = success).
6. Logs the full run (banner + every step + result) to `C:\IntuneLogs\VisioPro2024\`.

### Install-VisioPro2024-x64-English.xml Highlights
| Setting | Value | Purpose |
| --- | --- | --- |
| Channel | `PerpetualVL2024` | Volume channel for Office 2024 |
| Product / PIDKEY | `VisioPro2024Volume` + placeholder GVLK | Volume activation, `AUTOACTIVATE=1` |
| Architecture | 64-bit | Office Client Edition |
| Language | `en-us` | English installation |
| Display | `Level="None" AcceptEULA="TRUE"` | Silent install, no interaction |
| AppSettings | default save formats | Excel `.xlsx`, PowerPoint `.pptx`, Word default |

### Uninstall-VisioPro2024.xml
Removes `VisioPro2024Volume` only — leaves other Office products untouched.

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### Architecture
* Supports both 64-bit and 32-bit Office — install script auto-detects from registry.

### PowerShell
* Windows PowerShell **5.1 or later** (detection script runs under the Intune Management Extension)

### Permissions
* Runs in the local **SYSTEM** context via Intune — no Graph scopes, no Entra ID permission.
* Local administrator rights required for manual runs (checked by the PowerShell scripts).

### Logging
* Install/Uninstall transcripts: `C:\IntuneLogs\VisioPro2024\`.
* ODT setup logs: `%temp%` (redirect with `/log <path>`).
* Intune Management Extension logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

---

# 🧭 Intune Deployment

### Win32 Packaging
Download [IntuneWinAppUtil](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management) — or use the GUI-friendly [IntuneWin-Utility](https://github.com/mabdulkadr/IntuneWin-Utility) — and run:

```powershell
IntuneWinAppUtil.exe -c "C:\microsoft-visio-2024-intune-deploy" -s setup.exe -o "C:\intune-output"
```

### App Fields
| Setting | Value |
| ------- | ----- |
| Name | Microsoft Visio Professional 2024 (Volume) |
| Install command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-VisioPro2024.ps1"` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Uninstall-VisioPro2024.ps1"` |
| Install behavior | System |
| Device restart behavior | Intune will restart |

### Return Codes
| Code | Action |
| ---- | ------ |
| 0 | Success |
| 3010 | Soft reboot |
| 1641 | Hard reboot |
| 1618 | Fail (another install in progress) |

### Detection Rules
Upload `Detect-VisioPro2024.ps1` as a **custom detection script**:

| Setting | Value |
| ------- | ----- |
| Run this script as **64-bit** | Yes (required — the ClickToRun hive must not be redirected) |
| Run this script using logged-on credentials | No (SYSTEM context) |

**Alternative (no script):** Registry rule → `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\ClickToRun\Configuration` → value `ProductReleaseIds` → **contains** `VisioPro2024Volume`.

### Requirements Rules
| Rule | Value |
| ---- | ----- |
| Operating system architecture | 64-bit |
| Minimum OS version | Windows 10 21H2 (`10.0.19044.0`) |

---

# 🔧 Typical Workflow
1. Package the folder with `IntuneWinAppUtil.exe` and upload the `.intunewin` as a Win32 app.
2. Assign the app to a device group (install behavior System).
3. The Intune Management Extension downloads, extracts, and runs `Install-VisioPro2024.ps1` as SYSTEM (elevation probe passes).
4. The install script reads the current Office architecture and selects the matching XML.
5. ODT executes `setup.exe /configure Install-VisioPro2024-{arch}-{lang}.xml` silently.
6. On the next check-in, `Detect-VisioPro2024.ps1` runs; exit `0` marks the app **Installed**.

---

# 🔍 Troubleshooting

| Symptom | Likely Cause / Action |
| --- | --- |
| Install returns `0x80070002` | ODT cannot find the config/source — confirm the folder was packaged whole (`setup.exe` + the four `Install-VisioPro2024-<arch>-<lang>.xml` files beside `Install-VisioPro2024.ps1`) |
| Script fails before ODT runs | Check `C:\IntuneLogs\VisioPro2024\` — the transcript records elevation, missing-file, and invocation errors with exit codes |
| Detection marks *Not installed* right after a successful run | Check `ProductReleaseIds` and `VersionToReport` in the ClickToRun hive; exit `2` means the script itself failed (see `%temp%`) |
| Wrong product installed or activation fails | Verify the correct GVLK is in the XML — this package ships a placeholder `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` that must be replaced before deployment |
| `VISIO.EXE` not found after install | Office was installed to a non-default path — the detection script reads `InstallPath` from the ClickToRun registry |

---

# ❓ FAQ

**Can I install Visio alongside Office LTSC 2024?**
Yes — Visio 2024 volume installs independently alongside other Office products. All products share the same Click-to-Run configuration, but each has its own `ProductReleaseIds` entry.

**Can I use this with Microsoft 365 Apps?**
No. This configuration is Visio 2024-only (`VisioPro2024Volume`, `PerpetualVL2024`). For Visio Plan 2 (M365), generate a retail config via [config.office.com](https://config.office.com).

**Why auto-detect architecture?**
Office products on a device must share one architecture (32-bit or 64-bit). The install script reads the current architecture from the ClickToRun registry to avoid mismatched installs. For fresh devices with no Office, it defaults to x64.

---

# 🛡 Operational Notes
* **GVLK placeholder:** the XML files ship with a placeholder PIDKEY (`XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`). Replace it with your organization's KMS GVLK before deployment. Refer to [Microsoft KMS Client Setup Keys](https://learn.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys) for the correct key for Visio Professional 2024.
* **Uninstall XML fix:** the uninstall XML previously targeted `VisioProRetail` (a Microsoft 365 product ID) and included `<Language>` elements. It now correctly targets `VisioPro2024Volume` and is language-agnostic.
* **Offline first-install:** the packaged folder contains only `setup.exe` — the first `/configure` streams the payload from the Office CDN. For a self-contained package, run `setup.exe /download Install-VisioPro2024-x64-English.xml` first, then repackage with `IntuneWinAppUtil.exe` or [IntuneWin-Utility](https://github.com/mabdulkadr/IntuneWin-Utility).
* **Channel is a hard contract:** `PerpetualVL2024` is the only correct channel for Office 2024 volume licenses. Using `MonthlyEnterprise` or `Current` installs Microsoft 365 Apps instead.
* **Legacy `.intunewin` file:** `Visio.intunewin` in this folder is a stale package from a prior build (`Install_MS_Visio.intunewin` was removed). It must be re-packaged using `IntuneWinAppUtil.exe` or [IntuneWin-Utility](https://github.com/mabdulkadr/IntuneWin-Utility) before any production deployment.
* **Architecture selection:** if no prior Office Click-to-Run product is installed, the script defaults to `x64`. Override with `-Architecture x86` in the Intune install command if needed.

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
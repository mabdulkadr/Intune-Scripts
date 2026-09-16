<div align="center">

# 🛡️ Office LTSC 2024 - Intune Win32 Deployment

**[Office LTSC Professional Plus 2024 — silent, volume-licensed deployment package for Intune Win32 apps.]**

Packages the Office Deployment Tool with silent English/Arabic 64-bit and 32-bit configurations, PowerShell install/uninstall scripts with dedicated logging, and a custom Intune detection script for Enterprise enrollment.

[![Intune](https://img.shields.io/badge/Intune-Win32%20App-10B981?style=for-the-badge)](#%EF%B8%8F-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.5.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Structure](#-project-structure) • [Scripts](#-scripts-included) • [Deployment](#%EF%B8%8F-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements)</div>

---

# 📖 Overview

**Office LTSC 2024 - Intune Win32 Deployment** deploys Office LTSC Professional Plus 2024 (volume licensed, `ProPlus2024Volume`) to Intune-managed Windows devices using the official Microsoft Office Deployment Tool, matching the configuration generated on [config.office.com](https://config.office.com).

The bundle contains three layers:

- **Configuration**: four XML variants covering every combination of architecture (64-bit / 32-bit) and language (English `en-us`, Arabic `ar-sa`) — `Install-ProPlus2024-<arch>-<lang>.xml`. `Uninstall-ProPlus2024.xml` describes what to remove.
- **PowerShell scripts**: `Install-OfficeLTSC2024.ps1` / `Uninstall-OfficeLTSC2024.ps1` anchor every path to their own folder (dot-source safe), auto-detect the installed Office architecture (x64/x86) with an `-Architecture` override, accept a `-Language` variant (`Auto` default / `English`/`Arabic`), verify an elevated context, write a dedicated transcript to `<SystemDrive>\IntuneLogs\OfficeLTSC2024\`, and forward the true ODT exit code.
- **Detection**: `Detect-OfficeLTSC2024.ps1` is the Intune Win32 custom detection rule that marks the app *Installed* only when the Click-to-Run configuration truly reports `ProPlus2024Volume` with a version, and a core binary exists on disk.

A Win32 app uploaded from this folder installs completely silently (no UI, EULA auto-accepted) under the local SYSTEM account.

---

# ✨ Core Features

### 🔹 Silent Volume Deployment
* `Display Level="None" AcceptEULA="TRUE"` — no UI, no prompts, EULA auto-accepted; safe for Task Scheduler and Intune.
* `Channel="PerpetualVL2024"` — the only correct channel for Office LTSC 2024 volume licenses.
* KMS GVLK activation via `PIDKEY` + `AUTOACTIVATE=1` (placeholder key replaced by your organization's GVLK before deployment).
* `ProofingTools` with `ar-sa` included for Arabic spell-check on the Arabic variant.

### 🔹 PowerShell Install / Uninstall Scripts
* Every reference is absolute (`$PSScriptRoot` fallback), independent of the caller's working directory and dot-source safe.
* Auto-detects architecture from the ClickToRun registry and selects the matching XML; `-Architecture x64/x86` override.
* `-Language Auto|English|Arabic` selects the language variant (default Auto — installs in the OS UI language via `InstalledUICulture`).
* Elevation check fails fast with a clear message if not running as administrator/SYSTEM.
* Dedicated transcript log per operation under `C:\IntuneLogs\OfficeLTSC2024\`.
* Propagates the real `setup.exe` exit code instead of swallowing it.

### 🔹 Intune-Ready Detection
* Registry-driven (`HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration`) with disk-level hardening (`WINWORD.EXE`).
* Canonical exit contract: `0` installed / `1` not installed / `2` script error.
* No Graph permissions and no network dependency — pure local SYSTEM check.

---

# 📂 Project Structure

```text
office-ltsc-2024-intune-deploy
│
├── setup.exe                           Office Deployment Tool (16.0.17830.20162)
├── Install-ProPlus2024-x64-English.xml     Silent install - ProPlus2024Volume / en-us / 64-bit
├── Install-ProPlus2024-x64-Arabic.xml      Silent install - ProPlus2024Volume / ar-sa / 64-bit
├── Install-ProPlus2024-x86-English.xml     Silent install - ProPlus2024Volume / en-us / 32-bit
├── Install-ProPlus2024-x86-Arabic.xml      Silent install - ProPlus2024Volume / ar-sa / 32-bit
├── Uninstall-ProPlus2024.xml               Product removal config
├── Install-OfficeLTSC2024.ps1              PowerShell installer - logging + auto-arch + lang + ODT /configure
├── Uninstall-OfficeLTSC2024.ps1            PowerShell uninstaller - logging + ODT /configure
├── Detect-OfficeLTSC2024.ps1               Intune Win32 App custom detection script
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**
```powershell
Detect-OfficeLTSC2024.ps1
```

### Purpose
Reads the authoritative Click-to-Run registry and reports whether Office LTSC Professional Plus 2024 is genuinely present. Read-only — never modifies the system.

### Logic
1. Reads `HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration` (`ErrorAction Stop` → exit `2` if missing/failed).
2. Confirms `ProductReleaseIds` contains `ProPlus2024Volume` (exit `1` if not).
3. Confirms `VersionToReport` is populated (exit `1` if empty — partial install).
4. Confirms `WINWORD.EXE` exists under `InstallPath\root\Office16\` (exit `1` if missing).

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
Install-OfficeLTSC2024.ps1   →  & setup.exe /configure Install-ProPlus2024-<arch>-<lang>.xml
Uninstall-OfficeLTSC2024.ps1 →  & setup.exe /configure Uninstall-ProPlus2024.xml
```

### Install Behavior
1. Fails fast if `setup.exe` or the matching `.xml` is missing next to the script.
2. Enforces elevation (`Test-IsElevated`) — passes automatically under the Intune SYSTEM context.
3. Reads the installed Office architecture from the ClickToRun registry (x64/x86); defaults to x64 for fresh installs or when `-Architecture` is specified.
4. Selects the language variant via `-Language` (default `Auto` — OS UI culture; Arabic if it starts with `ar`, else English).
5. Invokes ODT synchronously and exits with ODT's real return code (`0` = success).
6. Logs the full run (banner + every step + result) to `C:\IntuneLogs\OfficeLTSC2024\`.

### Install-ProPlus2024-x64-English.xml Highlights
| Setting | Value | Purpose |
| --- | --- | --- |
| Channel | `PerpetualVL2024` | Volume channel for Office LTSC 2024 |
| Product / PIDKEY | `ProPlus2024Volume` + placeholder KMS GVLK | Volume activation, `AUTOACTIVATE=1` |
| Language | `en-us` | English installation |
| AppSettings | default save formats | Excel `.xlsx`, PowerPoint `.pptx`, Word default |
| Display | `Level="None" AcceptEULA="TRUE"` | Silent install, no interaction |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 (see Operational Notes for the official support matrix nuance)

### Architecture
* Supports both 64-bit and 32-bit Office — the install script auto-detects from registry and selects the matching XML.

### PowerShell
* Windows PowerShell **5.1 or later** (detection script runs under the Intune Management Extension)

### Permissions
* Runs in the local **SYSTEM** context via Intune — no Graph scopes, no Entra ID permission.
* Local administrator rights required for manual runs (checked by the PowerShell scripts).

### Logging
* Install/Uninstall transcripts: `C:\IntuneLogs\OfficeLTSC2024\`.
* ODT setup logs: `%temp%` (redirect with `/log <path>`).
* Intune Management Extension logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

---

# 🧭 Intune Deployment

### Win32 Packaging
Download [IntuneWinAppUtil](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management) — or use the GUI-friendly [IntuneWin-Utility](https://github.com/mabdulkadr/IntuneWin-Utility) — and run:

```powershell
IntuneWinAppUtil.exe -c "C:\office-ltsc-2024-intune-deploy" -s setup.exe -o "C:\intune-output"
```

### App Fields
| Setting | Value |
| ------- | ----- |
| Name | Office LTSC Professional Plus 2024 (Volume) |
| Install command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-OfficeLTSC2024.ps1"` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Uninstall-OfficeLTSC2024.ps1"` |
| Install behavior | System |
| Device restart behavior | Intune will restart |

> To pin a specific architecture/language, append the parameters: `... -Architecture x86 -Language Arabic`.

### Return Codes
| Code | Action |
| ---- | ------ |
| 0 | Success |
| 3010 | Soft reboot |
| 1641 | Hard reboot |
| 1618 | Fail (another install in progress) |

### Detection Rules
Upload `Detect-OfficeLTSC2024.ps1` as a **custom detection script**:

| Setting | Value |
| ------- | ----- |
| Run this script as **64-bit** | Yes (required — the ClickToRun hive must not be redirected) |
| Run this script using logged-on credentials | No (SYSTEM context) |

**Alternative (no script):** Registry rule → `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\ClickToRun\Configuration` → value `ProductReleaseIds` → **contains** `ProPlus2024Volume`.

### Requirements Rules
| Rule | Value |
| ---- | ----- |
| Operating system architecture | 64-bit |
| Minimum OS version | Windows 10 21H2 (`10.0.19044.0`) |

---

# 🔧 Typical Workflow
1. Package the folder with `IntuneWinAppUtil.exe` and upload the `.intunewin` as a Win32 app.
2. Assign the app to a device group (install behavior System).
3. The Intune Management Extension downloads, extracts, and runs `Install-OfficeLTSC2024.ps1` as SYSTEM (elevation probe passes).
4. The install script reads the current Office architecture (or uses `-Architecture` / `-Language`) and selects the matching XML.
5. ODT executes `setup.exe /configure Install-ProPlus2024-<arch>-<lang>.xml` silently (`Display None`, EULA accepted).
6. On the next check-in, `Detect-OfficeLTSC2024.ps1` runs; exit `0` marks the app **Installed**.

---

# 🔍 Troubleshooting

| Symptom | Likely Cause / Action |
| --- | --- |
| Install returns `0x80070002` | ODT cannot find the config/source — confirm the folder was packaged whole (`setup.exe` + the selected `Install-ProPlus2024-*.xml` beside the install script) |
| Script fails before ODT runs | Check `C:\IntuneLogs\OfficeLTSC2024\` — the transcript records elevation, missing-file, architecture, and invocation errors with exit codes |
| Detection marks *Not installed* right after a successful run | Check `ProductReleaseIds` and `VersionToReport` in the ClickToRun hive; exit `2` means the script itself failed (see `%temp%`) |
| Setup shows UI / waits for EULA | Device ran an XML without the `Display Level="None" AcceptEULA="TRUE"` element — redeploy with the current package |
| Wrong product installed (`O365ProPlusRetail` shows in registry) | Channel/Product IDs from an earlier config — only `PerpetualVL2024` / `ProPlus2024Volume` produce Office LTSC Professional Plus 2024 |
| Activation fails after install | The PIDKEY is a placeholder — replace `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` with your organization's KMS GVLK |
| Install stalls with no progress | First run is downloading the payload from the CDN (needs internet) — see Operational Notes |

---

# ❓ FAQ

**Is internet access required?**
Only for the first install — ODT streams the package from the Office CDN unless you pre-download. See Operational Notes for the offline option.

**Can I use this with Microsoft 365 Apps?**
No. This configuration is LTSC-2024-only (`ProPlus2024Volume`). For M365 Apps, generate a retail config, e.g. via [config.office.com](https://config.office.com).

**Why auto-detect architecture?**
Office products on a device must share one architecture (32-bit or 64-bit). The install script reads the current architecture from the ClickToRun registry to avoid mismatched installs. For fresh devices with no Office, it defaults to x64.

**How do I pick a language variant?**
Pass `-Language English` or `-Language Arabic` in the Intune install command, or package a separate app per variant. Default is `Auto` — the script reads the OS UI culture (`InstalledUICulture`) and installs Arabic when it starts with `ar`, otherwise English.

---

# 🛡 Operational Notes
* **Update behavior:** `<Updates Enabled="TRUE" />` uses the Office CDN (Microsoft recommended). For offline fleets, add `UpdatePath="\\server\share"` to the Updates element and replicate the payload monthly.
* **Offline first-install:** the packaged folder contains only `setup.exe` — the first `/configure` streams the payload from the CDN. For a self-contained package, run `setup.exe /download Install-ProPlus2024-x64-English.xml` first, then repackage with `IntuneWinAppUtil.exe` or [IntuneWin-Utility](https://github.com/mabdulkadr/IntuneWin-Utility).
* **Support matrix nuance:** Microsoft officially supports LTSC 2024 on Windows 11, Windows 11 LTSC 2024, Windows 10 LTSC 2021/2019, and Windows Server 2025/2022. Regular Windows 10 21H2+ works in practice; verify against your fleet policy.
* **Channel is a hard contract:** any config that does not use `PerpetualVL2024` installs Microsoft 365 Apps instead of retail-free LTSC 2024.
* **GVLK placeholder:** the XML files ship with `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` as PIDKEY. Replace it with your organization's KMS GVLK before deployment — see [Microsoft KMS Client Setup Keys](https://learn.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys).
* **AppSettings:** the empty Word `defaultformat` value is Microsoft's own ODT Configurator default and is intentionally kept.

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
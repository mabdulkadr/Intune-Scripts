<div align="center">

# 🍎 Check XProtect and Security Status

**Intune custom attribute that reports XProtect, MRT, SIP, Gatekeeper, and FileVault posture on macOS.**

Reads XProtect bundle versions via PlistBuddy and queries `csrutil`, `spctl`, and `fdesetup` to emit a single pipe-delimited security line for Intune compliance.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![Shell](https://img.shields.io/badge/Shell-Bash-5391FE?style=for-the-badge&logo=gnu-bash&logoColor=white)](#-overview)
[![Platform](https://img.shields.io/badge/Platform-macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Check XProtect and Security Status** is a bash shell script for Intune-managed macOS. This script inventories macOS platform security: it reads `CFBundleShortVersionString` from `XProtect.bundle`, `XProtect.app`, and `MRT.app` via `/usr/libexec/PlistBuddy`, then checks `csrutil status` (SIP), `spctl --status` (Gatekeeper), and `fdesetup status` (FileVault). Output is `macOS: X | XProtect: vY | XProtect Remediator: vZ | MRT: vW | Security: SIP:Enabled,GK:Enabled,FV:Enabled` — one line for Intune custom attributes.

Designed as an **Intune custom attribute** (single-line stdout) and as an **Intune macOS shell script profile**; it is read-only and exits 0 via `output_result` for reliable inventory.

---

# ✨ Features

* **Bundle version reads** — `get_plist_value` helper wraps PlistBuddy with `Print :CFBundleShortVersionString` and fallback to `Unknown`.
* **OS security checks** — parses `csrutil status`, `spctl --status`, and `fdesetup status` into compact `SIP/GK/FV` tokens.
* **Root-guarded** — `check_root` fails fast with `Error: Root access required` when not running as root (required for `csrutil`/`fdesetup`).

Additional details:

* * Plists: `/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist`, `XProtect.app/...`, `MRT.app/...`
* * Tools: `PlistBuddy`, `csrutil`, `spctl`, `fdesetup`, `sw_vers`
* * Intune pattern: `output_result` + `trap ERR` + `check_root`

---

# 📂 Project Structure

```text
check-xprotect-status
│
├── check-xprotect-status.sh
└── README.md
```

---

# 🚀 Usage

### Lint with shellcheck

```bash
shellcheck ./check-xprotect-status.sh
```

### Syntax check

```bash
bash -n ./check-xprotect-status.sh && echo "syntax OK"
```

### Run locally

```bash
chmod +x ./check-xprotect-status.sh
./check-xprotect-status.sh
```

### Run all checks (category-level)

```bash
for s in ./*.sh; do echo "== $s =="; chmod +x "$s"; "$s"; echo; done
```

### Deploy via Intune

**Shell script profile**

1. **Devices → macOS → Shell scripts** → Add → Upload `check-xprotect-status.sh`.
2. **Run script as signed-in user:** No for system checks, Yes only where the script notes user-context is required.
3. **Script frequency:** Daily (or per compliance cadence).
4. Assign to a macOS device group.

**Custom attribute (inventory)**

1. **Devices → macOS → Custom attributes** → Add → Attribute type **String**.
2. Upload `check-xprotect-status.sh` as the attribute script.
3. Output appears under device properties as a single line.

---

---

# ⚙️ Parameters

This script has **no parameters** — it is a read-only check with no configuration flags.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| — | — | — | — | No parameters |

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Success — single-line output via `output_result` (Intune custom attribute) |
| 1    | Handled internally via `output_result` with error message; script still exits 0 for Intune |

---

# ⚙️ Requirements

### Operating System

* macOS **10.15 (Catalina) or later**

### Shell

* `bash` **3.2+** (system bash) or `zsh` — all scripts use POSIX-compatible syntax and standard macOS utilities

### Intune

* Microsoft Intune tenant with **macOS shell script profile** or **Custom Attributes for macOS** support
* Devices managed via Company Portal / Intune MDM channel

### Permissions

* Requires **root** (`EUID 0`) via Intune SYSTEM context; SIP/Gatekeeper/FileVault queries need elevation.

### Dependencies

* No external modules — uses only macOS system tools (`sw_vers`, `defaults`, `dscl`, `sysctl`, `nc`, `PlistBuddy`, `csrutil`, `spctl`, `fdesetup`) and `msupdate` where noted

### Logging

* Not applicable — read-only check with single-line stdout for Intune; `trap ERR` routes failures to `output_result` so inventory is never empty

---

# 🛡 Operational Notes

* Apple Silicon vs Intel: runs identically; `csrutil`/`spctl`/`fdesetup` are universal.
* Rosetta: not required.
* FileVault: reported as `FV:Enabled/Disabled` — script does not modify FileVault state.
* Single-line contract: `macOS: ... | XProtect: ... | Security: ...`.
* Idempotent & read-only: rerunning never modifies system state.
* Test in staging: validate on both Intel and Apple Silicon devices in a pilot group before tenant-wide assignment.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)
## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## ⚠ Disclaimer

This skill and every script it generates are provided as-is with no warranty of any kind. Test generated tools in a staging environment before deploying to production. The authors assume no liability for any damage or data loss resulting from their use.

---
<div align="center">

⭐ **If this skill saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) • [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>

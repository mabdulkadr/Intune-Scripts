<div align="center">

# 🍎 Intune macOS Tools

**macOS endpoint checks for FileVault, updates, and hygiene**

Lightweight bash checks for Intune-managed Macs — deployed as shell script profiles or custom attributes to surface FileVault, update, and security posture without agents.

[![Shell](https://img.shields.io/badge/Shell-Bash-5391FE?style=for-the-badge&logo=gnu-bash&logoColor=white)](#-overview)
[![Platform](https://img.shields.io/badge/Platform-macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-📜-scripts) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Intune macOS Tools** is a set of **7 bash/zsh shell scripts for Intune macOS remediations and compliance** focused on endpoint hygiene.

Each script is single-file, dependency-light, and designed to run as an **Intune macOS shell script profile** or **custom attribute** — emitting a single line suitable for Intune reporting. They cover warranty lifecycle, Microsoft AutoUpdate health, network prerequisites, platform security, uptime, and privileged access.

---

# ✨ Core Features

### 🔹 Agentless macOS Hygiene
* FileVault, XProtect, SIP, and Gatekeeper posture checks without MDM agents
* Microsoft AutoUpdate (MAU) channel and pending-update visibility
* Local admin membership auditing for privileged-access hygiene

### 🔹 Intune-Native Output
* Single-line stdout for custom attributes and shell script profiles
* Exit-code friendly for remediation wrappers
* No external dependencies beyond standard macOS tooling (`sysctl`, `dscl`, `sw_vers`, `nc`, `msupdate`)

### 🔹 Production Ready
* Tested on macOS 10.15+ (Catalina and later)
* Runs as root or logged-in user where appropriate
* Safe read-only checks — no system modification

---

# 📂 Project Structure

```text
Intune-macOS
│
├── check-applecare-warranty-status.sh      # AppleCare / warranty coverage check
├── check-available-msupdate-updates.sh     # Pending Microsoft AutoUpdate updates
├── check-msupdate-status.sh                # MAU version / channel / last-check status
├── check-network-requirements.sh           # Apple security + update endpoint reachability
├── check-xprotect-status.sh                # XProtect / MRT / SIP / Gatekeeper / FileVault status
├── last-reboot.sh                          # Last system boot time
├── local-admins.sh                         # Local administrator group members
└── README.md
```

---

# 📜 Scripts Included

| Script | Purpose | macOS context |
| ------ | ------- | ------------- |
| `check-applecare-warranty-status.sh` | Reads local warranty coverage end date from `com.apple.NewDeviceOutreach` and reports expiry | Lifecycle / inventory via Intune custom attribute; sources `~/Library/Application Support/com.apple.NewDeviceOutreach` |
| `check-available-msupdate-updates.sh` | Lists pending updates via Microsoft AutoUpdate `msupdate --list` | Office / Microsoft app patch compliance; requires MAU at `/Library/Application Support/Microsoft/MAU2.0/.../msupdate` and runs as logged-in user |
| `check-msupdate-status.sh` | Reports MAU version, update channel, and last update-check timestamp | MAU agent health; parses `msupdate --config` output for compliance reporting |
| `check-network-requirements.sh` | Tests TCP 443 reachability to Apple OCSP/CRL/PPQ and software-update endpoints via `nc` | Network / firewall prerequisite; validates security and update services are reachable behind corporate proxies |
| `check-xprotect-status.sh` | Reports XProtect, XProtect Remediator, MRT versions plus SIP, Gatekeeper, and FileVault status | Platform security posture; uses `sw_vers`, `csrutil status`, `spctl --status`, `fdesetup status` |
| `last-reboot.sh` | Returns last reboot time from `sysctl kern.boottime` in `YYYY-MM-DD HH:MM:SS` local time | Uptime / compliance; no dependencies, works in any context |
| `local-admins.sh` | Lists members of the local `admin` group via `dscl . -read /Groups/admin GroupMembership` | Privileged-access hygiene; surfaces drift from least-privilege baselines |

---

# 🧭 Usage

## Run locally

```bash
chmod +x check-xprotect-status.sh
./check-xprotect-status.sh
```

```bash
chmod +x local-admins.sh
./local-admins.sh
```

Loop all checks:

```bash
for s in ./*.sh; do echo "== $s =="; chmod +x "$s"; "$s"; echo; done
```

## Lint with shellcheck

```bash
shellcheck ./*.sh
```

```bash
bash -n ./check-network-requirements.sh && echo "syntax OK"
```

## Deploy via Intune

1. **Devices > macOS > Shell scripts** → Add new profile → Upload `.sh` as script file (or paste content).
2. Set **Run script as signed-in user** to **No** for system checks (`check-xprotect-status.sh`, `local-admins.sh`, `last-reboot.sh`) and **Yes** where the script notes user-context (`check-available-msupdate-updates.sh`).
3. Assign to a macOS device group and set cadence (e.g., daily).
4. For **custom attributes** (inventory): **Devices > macOS > Custom attributes** → Attribute type `String` → Upload single script → output appears under device properties.

---

# ⚙️ Requirements

### Operating System
* macOS **10.15 (Catalina) or later**

### Shell
* `bash` **3.2+** (system bash) or `zsh` — all scripts use POSIX-compatible syntax and standard macOS utilities (bash 3.2+/zsh)

### Intune
* Microsoft Intune tenant with **macOS shell script profile** or **Custom Attributes for macOS** support
* Devices managed via Company Portal / Intune MDM channel

### Permissions
* Most checks run as **root (SYSTEM via Intune)**; `check-available-msupdate-updates.sh` resolves the console user via `stat -f "%Su" /dev/console` and invokes `msupdate` in that user context where required
* No Microsoft Graph modules or Azure dependencies

---

# 🛡 Operational Notes

* **Apple Silicon vs Intel:** All scripts use universal macOS tooling (`sysctl`, `dscl`, `sw_vers`, `nc`, `csrutil`, `spctl`, `fdesetup`) and run identically on Apple Silicon and Intel. No architecture-specific branches.
* **Rosetta:** Not required. Scripts are pure shell — no x86-only binaries are invoked. `msupdate`-based checks call the native Microsoft AutoUpdate binary installed for the host architecture.
* **Idempotent & read-only:** Every script is a read-only check; rerunning never modifies system state.
* **Output contract:** Single-line stdout for Intune custom attributes; non-zero handling is left to the caller/remediation wrapper.
* **Network checks:** `check-network-requirements.sh` uses `nc` with a 2-second timeout per endpoint on TCP 443 — allow `*.apple.com` and `*.cdn-apple.com` families through firewalls/proxies for meaningful results.
* **Test in staging:** Validate on both Intel and Apple Silicon devices in a pilot group before tenant-wide assignment.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)
## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

### Attribution

Monitoring shells adapted from ugurkocde/IntuneAutomation monitoring pack (MIT) — see THIRD-PARTY-NOTICES.md.

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

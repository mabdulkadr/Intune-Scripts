<div align="center">

# 🍎 Get Last Reboot Time

**Intune custom attribute that reports the last macOS reboot time with relative uptime.**

Queries `sysctl kern.boottime`, formats the epoch as `YYYY-MM-DD HH:MM:SS` local time, and appends human-readable uptime for Intune device hygiene.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![Shell](https://img.shields.io/badge/Shell-Bash-5391FE?style=for-the-badge&logo=gnu-bash&logoColor=white)](#-overview)
[![Platform](https://img.shields.io/badge/Platform-macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Last Reboot Time** is a bash shell script for Intune-managed macOS. Uptime is a proxy for patch compliance and pending restarts. This script reads `sysctl -n kern.boottime`, extracts the `sec` field with `awk`, validates it is numeric, converts it with `date -r "<epoch>" "+%Y-%m-%d %H:%M:%S"`, then computes `current_time - timestamp` to show `(Xd Yh ago)` or `(Xh ago)`. Output is `Last Reboot: 2025-06-04 09:12:03 (3d 4h ago)` — one line for Intune.

Designed as an **Intune custom attribute** (single-line stdout) and as an **Intune macOS shell script profile**; it is read-only and exits 0 via `output_result` for reliable inventory.

---

# ✨ Features

* **Kernel boot time** — `sysctl -n kern.boottime` is authoritative; no `last`/`who` parsing.
* **Validated epoch** — regex `^[0-9]+$` guard and `date -r` error handling with `output_result` on failure.
* **Uptime context** — computes days/hours from `date +%s` for quick Intune triage.

Additional details:

* * Source: `sysctl -n kern.boottime` (sec field)
* * Format: `date -r "$timestamp" "+%Y-%m-%d %H:%M:%S"` (local timezone)
* * Prereq check: `command -v sysctl`

---

# 📂 Project Structure

```text
last-reboot
│
├── last-reboot.sh
└── README.md
```

---

# 🚀 Usage

### Lint with shellcheck

```bash
shellcheck ./last-reboot.sh
```

### Syntax check

```bash
bash -n ./last-reboot.sh && echo "syntax OK"
```

### Run locally

```bash
chmod +x ./last-reboot.sh
./last-reboot.sh
```

### Run all checks (category-level)

```bash
for s in ./*.sh; do echo "== $s =="; chmod +x "$s"; "$s"; echo; done
```

### Deploy via Intune

**Shell script profile**

1. **Devices → macOS → Shell scripts** → Add → Upload `last-reboot.sh`.
2. **Run script as signed-in user:** No for system checks, Yes only where the script notes user-context is required.
3. **Script frequency:** Daily (or per compliance cadence).
4. Assign to a macOS device group.

**Custom attribute (inventory)**

1. **Devices → macOS → Custom attributes** → Add → Attribute type **String**.
2. Upload `last-reboot.sh` as the attribute script.
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

* Runs as **root or user**; `sysctl` needs no elevation. Safe in any Intune context.

### Dependencies

* No external modules — uses only macOS system tools (`sw_vers`, `defaults`, `dscl`, `sysctl`, `nc`, `PlistBuddy`, `csrutil`, `spctl`, `fdesetup`) and `msupdate` where noted

### Logging

* Not applicable — read-only check with single-line stdout for Intune; `trap ERR` routes failures to `output_result` so inventory is never empty

---

# 🛡 Operational Notes

* Apple Silicon vs Intel: `sysctl` is universal.
* Rosetta: not required.
* FileVault: unrelated; reads kernel boottime only.
* Time is local system timezone; compare with `date +%s` for UTC correlation.
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

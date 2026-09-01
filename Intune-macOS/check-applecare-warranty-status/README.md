<div align="center">

# 🍎 Check AppleCare Warranty Status

**Intune custom attribute that surfaces AppleCare warranty coverage expiry on macOS.**

Reads the local `com.apple.NewDeviceOutreach` warranty cache for every user home and reports the coverage end date as a single line for Intune inventory — built for fleet lifecycle tracking.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![Shell](https://img.shields.io/badge/Shell-Bash-5391FE?style=for-the-badge&logo=gnu-bash&logoColor=white)](#-overview)
[![Platform](https://img.shields.io/badge/Platform-macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Check AppleCare Warranty Status** is a bash shell script for Intune-managed macOS. macOS caches warranty coverage information under `~/Library/Application Support/com.apple.NewDeviceOutreach`. This script scans the logged-in user and all `/Users/*` homes, picks the newest `*_Warranty*` plist, reads `coverageEndDate` via `defaults`, and outputs `Expires: YYYY-MM-DD`, `Expired: YYYY-MM-DD`, or `No warranty information`. Designed as a read-only Intune custom attribute; it never modifies the system.

Designed as an **Intune custom attribute** (single-line stdout) and as an **Intune macOS shell script profile**; it is read-only and exits 0 via `output_result` for reliable inventory.

---

# ✨ Features

* **Warranty cache scan** — enumerates `com.apple.NewDeviceOutreach` in the console user home first, then every local user home; handles missing directories gracefully.
* **Date-normalized output** — converts epoch `coverageEndDate` to `YYYY-MM-DD` via `date -r` and flags expired vs active coverage.
* **Intune-native** — single-line stdout with `output_result` helper and `trap ERR` so custom attributes always return a usable string and exit 0.

Additional details:

* * Source store: `~/Library/Application Support/com.apple.NewDeviceOutreach/*_Warranty*`
* * Tools used: `stat`, `dscl`, `defaults`, `date`, `find`, `ls` — no external dependencies
* * Context: runs as root or user; successfully reads per-user caches

---

# 📂 Project Structure

```text
check-applecare-warranty-status
│
├── check-applecare-warranty-status.sh
└── README.md
```

---

# 🚀 Usage

### Lint with shellcheck

```bash
shellcheck ./check-applecare-warranty-status.sh
```

### Syntax check

```bash
bash -n ./check-applecare-warranty-status.sh && echo "syntax OK"
```

### Run locally

```bash
chmod +x ./check-applecare-warranty-status.sh
./check-applecare-warranty-status.sh
```

### Run all checks (category-level)

```bash
for s in ./*.sh; do echo "== $s =="; chmod +x "$s"; "$s"; echo; done
```

### Deploy via Intune

**Shell script profile**

1. **Devices → macOS → Shell scripts** → Add → Upload `check-applecare-warranty-status.sh`.
2. **Run script as signed-in user:** No for system checks, Yes only where the script notes user-context is required.
3. **Script frequency:** Daily (or per compliance cadence).
4. Assign to a macOS device group.

**Custom attribute (inventory)**

1. **Devices → macOS → Custom attributes** → Add → Attribute type **String**.
2. Upload `check-applecare-warranty-status.sh` as the attribute script.
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

* Runs as **root or user** via Intune; reads per-user warranty caches without elevation. No system modification.

### Dependencies

* No external modules — uses only macOS system tools (`sw_vers`, `defaults`, `dscl`, `sysctl`, `nc`, `PlistBuddy`, `csrutil`, `spctl`, `fdesetup`) and `msupdate` where noted

### Logging

* Not applicable — read-only check with single-line stdout for Intune; `trap ERR` routes failures to `output_result` so inventory is never empty

---

# 🛡 Operational Notes

* Apple Silicon vs Intel: pure shell with `defaults`/`date`; identical on both architectures.
* Rosetta: not required — no x86-only binaries.
* FileVault: independent; reads user homes even when FileVault is enabled (caches are on the boot volume).
* Single-line contract: always prints one line (`Expires: ...`, `Expired: ...`, or `No warranty information`).
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

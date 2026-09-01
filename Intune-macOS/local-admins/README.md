<div align="center">

# 🍎 List Local Admin Users

**Intune custom attribute that audits local administrator group members on macOS.**

Queries the `admin` group via `dscl` and reports privileged users as `Admin Users (N): user1 user2` for least-privilege hygiene.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![Shell](https://img.shields.io/badge/Shell-Bash-5391FE?style=for-the-badge&logo=gnu-bash&logoColor=white)](#-overview)
[![Platform](https://img.shields.io/badge/Platform-macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**List Local Admin Users** is a bash shell script for Intune-managed macOS. Excess local admins is a common drift on macOS fleets. This script runs `dscl . -read /Groups/admin GroupMembership`, strips the `GroupMembership:` prefix, handles `eDSPermissionError`, validates non-empty output, then counts members with `wc -w` and reports `Admin Users (N): ...`. Single-line output is ideal for Intune custom attributes and compliance queries.

Designed as an **Intune custom attribute** (single-line stdout) and as an **Intune macOS shell script profile**; it is read-only and exits 0 via `output_result` for reliable inventory.

---

# ✨ Features

* **DSCL query** — `dscl . -read /Groups/admin GroupMembership` is the authoritative source for admin membership.
* **Error-aware** — distinguishes `eDSPermissionError` vs empty/invalid output with distinct `output_result` messages.
* **Count + list** — `wc -w` count plus space-delimited user list for quick fleet assessment.

Additional details:

* * Group: `/Groups/admin` via `dscl . -read`
* * Count: `echo "$admin_users" | wc -w | tr -d ' '`
* * Prereq: `command -v dscl`

---

# 📂 Project Structure

```text
local-admins
│
├── local-admins.sh
└── README.md
```

---

# 🚀 Usage

### Lint with shellcheck

```bash
shellcheck ./local-admins.sh
```

### Syntax check

```bash
bash -n ./local-admins.sh && echo "syntax OK"
```

### Run locally

```bash
chmod +x ./local-admins.sh
./local-admins.sh
```

### Run all checks (category-level)

```bash
for s in ./*.sh; do echo "== $s =="; chmod +x "$s"; "$s"; echo; done
```

### Deploy via Intune

**Shell script profile**

1. **Devices → macOS → Shell scripts** → Add → Upload `local-admins.sh`.
2. **Run script as signed-in user:** No for system checks, Yes only where the script notes user-context is required.
3. **Script frequency:** Daily (or per compliance cadence).
4. Assign to a macOS device group.

**Custom attribute (inventory)**

1. **Devices → macOS → Custom attributes** → Add → Attribute type **String**.
2. Upload `local-admins.sh` as the attribute script.
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

* Runs as **root or user**; `dscl . -read /Groups/admin` typically succeeds without elevation, but Intune SYSTEM guarantees read.

### Dependencies

* No external modules — uses only macOS system tools (`sw_vers`, `defaults`, `dscl`, `sysctl`, `nc`, `PlistBuddy`, `csrutil`, `spctl`, `fdesetup`) and `msupdate` where noted

### Logging

* Not applicable — read-only check with single-line stdout for Intune; `trap ERR` routes failures to `output_result` so inventory is never empty

---

# 🛡 Operational Notes

* Apple Silicon vs Intel: identical; `dscl` is universal.
* Rosetta: not required.
* FileVault: independent; only queries directory services.
* Output contract: `Admin Users (N): ...` or `Admin Users: None found`.
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

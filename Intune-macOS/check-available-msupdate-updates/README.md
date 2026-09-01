<div align="center">

# 🍎 Check Available Microsoft Updates

**Intune custom attribute that lists pending Microsoft AutoUpdate (MAU) updates on macOS.**

Invokes `msupdate --list` in the logged-in user context and reports pending Office and Microsoft app updates as a single line for Intune patch compliance.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![Shell](https://img.shields.io/badge/Shell-Bash-5391FE?style=for-the-badge&logo=gnu-bash&logoColor=white)](#-overview)
[![Platform](https://img.shields.io/badge/Platform-macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Check Available Microsoft Updates** is a bash shell script for Intune-managed macOS. Microsoft AutoUpdate exposes its CLI at `/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate`. This script validates MAU is installed and executable, resolves the console user via `stat -f "%Su" /dev/console`, then runs `msupdate --list` through `launchctl asuser` in that user context. Output is collapsed to a single line (`No updates available` or `Updates available: ...`) suitable for Intune custom attributes.

Designed as an **Intune custom attribute** (single-line stdout) and as an **Intune macOS shell script profile**; it is read-only and exits 0 via `output_result` for reliable inventory.

---

# ✨ Features

* **User-context execution** — resolves `loggedInUser` with `stat`/`id -u` and uses `launchctl asuser` + `sudo -u` so MAU reports user-specific updates.
* **MAU health checks** — validates `msupdate` exists and is executable before probing; surfaces `Microsoft AutoUpdate not installed` clearly.
* **Collapsed single-line reporting** — `grep`/`tr`/`sed` pipeline turns multi-line `msupdate --list` into a space-delimited list for Intune.

Additional details:

* * MAU path: `/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate`
* * User detection: `stat -f "%Su" /dev/console` + `id -u`
* * Intune pattern: `output_result` + `trap ERR` ensures custom attribute always exits 0 with one line

---

# 📂 Project Structure

```text
check-available-msupdate-updates
│
├── check-available-msupdate-updates.sh
└── README.md
```

---

# 🚀 Usage

### Lint with shellcheck

```bash
shellcheck ./check-available-msupdate-updates.sh
```

### Syntax check

```bash
bash -n ./check-available-msupdate-updates.sh && echo "syntax OK"
```

### Run locally

```bash
chmod +x ./check-available-msupdate-updates.sh
./check-available-msupdate-updates.sh
```

### Run all checks (category-level)

```bash
for s in ./*.sh; do echo "== $s =="; chmod +x "$s"; "$s"; echo; done
```

### Deploy via Intune

**Shell script profile**

1. **Devices → macOS → Shell scripts** → Add → Upload `check-available-msupdate-updates.sh`.
2. **Run script as signed-in user:** No for system checks, Yes only where the script notes user-context is required.
3. **Script frequency:** Daily (or per compliance cadence).
4. Assign to a macOS device group.

**Custom attribute (inventory)**

1. **Devices → macOS → Custom attributes** → Add → Attribute type **String**.
2. Upload `check-available-msupdate-updates.sh` as the attribute script.
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

* Requires **logged-in user** (fails with `No user logged in` when run at login window). Deploy as Intune shell script profile with **Run as signed-in user = No** but script internally impersonates the user; for custom attributes the Intune agent runs as root and the script handles impersonation.

### Dependencies

* No external modules — uses only macOS system tools (`sw_vers`, `defaults`, `dscl`, `sysctl`, `nc`, `PlistBuddy`, `csrutil`, `spctl`, `fdesetup`) and `msupdate` where noted

### Logging

* Not applicable — read-only check with single-line stdout for Intune; `trap ERR` routes failures to `output_result` so inventory is never empty

---

# 🛡 Operational Notes

* Apple Silicon vs Intel: calls the native MAU binary for the host architecture; no arch-specific logic.
* Rosetta: not required; MAU is universal.
* FileVault: unaffected; script only reads MAU state.
* Requires Microsoft AutoUpdate installed; otherwise reports `Microsoft AutoUpdate not installed`.
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

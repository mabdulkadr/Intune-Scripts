<div align="center">

# 🍎 Check Microsoft AutoUpdate Status

**Intune custom attribute that reports Microsoft AutoUpdate version, channel, and last check time on macOS.**

Parses `msupdate --config` and emits `MAU Version: X | Channel: Y | Last Update Check: Z` as a single line for fleet update-health visibility.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![Shell](https://img.shields.io/badge/Shell-Bash-5391FE?style=for-the-badge&logo=gnu-bash&logoColor=white)](#-overview)
[![Platform](https://img.shields.io/badge/Platform-macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Check Microsoft AutoUpdate Status** is a bash shell script for Intune-managed macOS. This script probes the MAU CLI (`/Library/Application Support/Microsoft/MAU2.0/.../msupdate`) for its configuration dump via `msupdate --config`. It extracts `AutoUpdateVersion`, `ChannelName`, and `LastCheckForUpdates` with `grep`/`awk`/`sed` and formats them into one pipe-delimited line for Intune custom attributes. Missing MAU is reported as `Microsoft AutoUpdate not installed`.

Designed as an **Intune custom attribute** (single-line stdout) and as an **Intune macOS shell script profile**; it is read-only and exits 0 via `output_result` for reliable inventory.

---

# ✨ Features

* **Config parsing** — extracts `AutoUpdateVersion`, `ChannelName`, `LastCheckForUpdates` from `msupdate --config` output.
* **Graceful degradation** — reports `Unknown`/`Never` when fields are absent and `Error: Unable to retrieve MAU configuration` on failure.
* **Intune-ready** — `output_result` + `trap ERR` guarantees a single line and exit 0 for custom attribute ingestion.

Additional details:

* * MAU path: `/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate`
* * Parsing: `grep "AutoUpdateVersion =" | awk -F'"'`, `ChannelName`, `LastCheckForUpdates`
* * No user-context impersonation needed; runs as root

---

# 📂 Project Structure

```text
check-msupdate-status
│
├── check-msupdate-status.sh
└── README.md
```

---

# 🚀 Usage

### Lint with shellcheck

```bash
shellcheck ./check-msupdate-status.sh
```

### Syntax check

```bash
bash -n ./check-msupdate-status.sh && echo "syntax OK"
```

### Run locally

```bash
chmod +x ./check-msupdate-status.sh
./check-msupdate-status.sh
```

### Run all checks (category-level)

```bash
for s in ./*.sh; do echo "== $s =="; chmod +x "$s"; "$s"; echo; done
```

### Deploy via Intune

**Shell script profile**

1. **Devices → macOS → Shell scripts** → Add → Upload `check-msupdate-status.sh`.
2. **Run script as signed-in user:** No for system checks, Yes only where the script notes user-context is required.
3. **Script frequency:** Daily (or per compliance cadence).
4. Assign to a macOS device group.

**Custom attribute (inventory)**

1. **Devices → macOS → Custom attributes** → Add → Attribute type **String**.
2. Upload `check-msupdate-status.sh` as the attribute script.
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

* Runs as **root (SYSTEM via Intune)**; no logged-in user required. Read-only; no system modification.

### Dependencies

* No external modules — uses only macOS system tools (`sw_vers`, `defaults`, `dscl`, `sysctl`, `nc`, `PlistBuddy`, `csrutil`, `spctl`, `fdesetup`) and `msupdate` where noted

### Logging

* Not applicable — read-only check with single-line stdout for Intune; `trap ERR` routes failures to `output_result` so inventory is never empty

---

# 🛡 Operational Notes

* Apple Silicon vs Intel: parses MAU config identically on both; no binary arch dependency.
* Rosetta: not required.
* FileVault: unrelated; no disk-state dependency.
* Output contract: single line `MAU Version: ... | Channel: ... | Last Update Check: ...`.
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

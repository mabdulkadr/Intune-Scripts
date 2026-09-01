<div align="center">

# 🍎 Check Network Requirements

**Intune custom attribute that validates TCP 443 reachability to Apple security and software update endpoints.**

Probes OCSP, CRL, PPQ, CloudKit, OS recovery, and software-update hosts with `nc` and reports unreachable services as a single line for firewall and proxy diagnostics.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![Shell](https://img.shields.io/badge/Shell-Bash-5391FE?style=for-the-badge&logo=gnu-bash&logoColor=white)](#-overview)
[![Platform](https://img.shields.io/badge/Platform-macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Check Network Requirements** is a bash shell script for Intune-managed macOS. Corporate proxies and firewalls often block Apple services needed for XProtect, OCSP, and OS updates. This script tests TCP connectivity to 11 Apple hosts on port 443 using `nc -zw2` with a 2-second timeout. It groups failures into *Security services* (`ocsp.apple.com`, `crl.apple.com`, `ppq.apple.com`, `api.apple-cloudkit.com`) and *Update services* (`osrecovery`, `oscdn`, `swcdn`, `swdist`, `swdownload`, `swscan`, `updates.cdn-apple.com`) and emits `Security services: All reachable | Update services: All reachable` or lists unreachable hosts.

Designed as an **Intune custom attribute** (single-line stdout) and as an **Intune macOS shell script profile**; it is read-only and exits 0 via `output_result` for reliable inventory.

---

# ✨ Features

* **Two-category reporting** — separates security vs update endpoints for faster triage.
* **Fast TCP probes** — `nc -zw2` with 2-second timeout per host; `check_prerequisites` validates `nc` exists.
* **Single-line Intune output** — `output_result` + `trap ERR` collapses multi-host results into one line for custom attributes.

Additional details:

* * Security hosts: `ocsp.apple.com`, `crl.apple.com`, `ppq.apple.com`, `api.apple-cloudkit.com`
* * Update hosts: `osrecovery.apple.com`, `oscdn.apple.com`, `swcdn.apple.com`, `swdist.apple.com`, `swdownload.apple.com`, `swscan.apple.com`, `updates.cdn-apple.com`
* * Tool: `nc` (netcat) only; no curl or external dependencies

---

# 📂 Project Structure

```text
check-network-requirements
│
├── check-network-requirements.sh
└── README.md
```

---

# 🚀 Usage

### Lint with shellcheck

```bash
shellcheck ./check-network-requirements.sh
```

### Syntax check

```bash
bash -n ./check-network-requirements.sh && echo "syntax OK"
```

### Run locally

```bash
chmod +x ./check-network-requirements.sh
./check-network-requirements.sh
```

### Run all checks (category-level)

```bash
for s in ./*.sh; do echo "== $s =="; chmod +x "$s"; "$s"; echo; done
```

### Deploy via Intune

**Shell script profile**

1. **Devices → macOS → Shell scripts** → Add → Upload `check-network-requirements.sh`.
2. **Run script as signed-in user:** No for system checks, Yes only where the script notes user-context is required.
3. **Script frequency:** Daily (or per compliance cadence).
4. Assign to a macOS device group.

**Custom attribute (inventory)**

1. **Devices → macOS → Custom attributes** → Add → Attribute type **String**.
2. Upload `check-network-requirements.sh` as the attribute script.
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

* Runs as **root or user**; `nc` needs no elevation. Intune SYSTEM context is fine. Requires `nc` on PATH.

### Dependencies

* No external modules — uses only macOS system tools (`sw_vers`, `defaults`, `dscl`, `sysctl`, `nc`, `PlistBuddy`, `csrutil`, `spctl`, `fdesetup`) and `msupdate` where noted

### Logging

* Not applicable — read-only check with single-line stdout for Intune; `trap ERR` routes failures to `output_result` so inventory is never empty

---

# 🛡 Operational Notes

* Apple Silicon vs Intel: identical; uses universal `nc`.
* Rosetta: not required.
* FileVault: independent; network probe only.
* Allow `*.apple.com` and `*.cdn-apple.com` on TCP 443 through enterprise firewalls for clean results.
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

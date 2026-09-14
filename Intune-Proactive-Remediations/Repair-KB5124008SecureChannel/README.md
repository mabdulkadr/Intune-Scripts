<div align="center">

# 🛡️ Repair KB5124008 Secure Channel

**Intune Proactive Remediation package that applies the KB5124008 workaround - clearing the Lsa `MachineIdentityIsolation` flag and repairing the computer secure channel - on affected domain-joined devices.**

Detection flags devices that are domain-joined, have KB5124008 installed, AND show the KB5124008 regression indicator (a non-zero Lsa `MachineIdentityIsolation` value or a broken secure channel); remediation clears `MachineIdentityIsolation = 0`, repairs the secure channel via a native `Test-ComputerSecureChannel -Repair` that falls back automatically to `nltest /sc_reset`, and verifies the result — isolated from the generic `Repair-ADSecureChannel` package so it can be retired once Microsoft ships an official fix.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.2-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Repair KB5124008 Secure Channel** is an Intune remediation package that targets the KB5124008 secure channel regression on shared, domain-joined endpoints.

The detection script is deliberately narrow: it flags a device only when it is in scope — domain-joined **and** KB5124008 installed — and at least one regression indicator is present: a non-zero `MachineIdentityIsolation` value under the Lsa key (the workaround flag this package clears) **or** `Test-ComputerSecureChannel` reports a broken secure channel. Anything else (not domain-joined, or no KB5124008) is compliant by design, so remediation never fires for unrelated broken-trust cases. When in scope, the paired remediation first sets `MachineIdentityIsolation = 0` under the Lsa key, then repairs the secure channel through a fallback chain (`Test-ComputerSecureChannel -Repair`, and `nltest /sc_reset:<Domain>` when the native reset is denied), and finally re-verifies both the registry value and the secure channel before reporting success.

---

# ✨ Core Features

### 🔹 Narrow, Version-Specific Detection
* Flags devices only when domain-joined AND KB5124008 installed AND at least one regression indicator (non-zero `MachineIdentityIsolation` or a broken secure channel)
* Read-only — never modifies the system during detection
* Non-compliant scenarios are isolated from the generic `Repair-ADSecureChannel` package

### 🔹 Verified Remediation
* Pre-check → per-target fix → post-verify flow with structured JSON result output for Intune diagnostics
* Sets `MachineIdentityIsolation = 0` (DWORD, created when missing), then repairs the secure channel via `Test-ComputerSecureChannel -Repair` with an automatic `nltest /sc_reset` fallback
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Repair-KB5124008SecureChannel\`

---

# 📂 Project Structure

```text
Repair-KB5124008SecureChannel
│
├── detect-Repair-KB5124008SecureChannel.ps1
├── remediate-Repair-KB5124008SecureChannel.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Repair-KB5124008SecureChannel.ps1
```

### Purpose
Detects devices affected by the KB5124008 secure channel regression. Strictly read-only.

### Logic
1. Query `Win32_ComputerSystem` — if the device is **not** domain-joined, mark compliant (not applicable)
2. Query the hotfix inventory — if **KB5124008 is not installed**, mark compliant (not applicable)
3. Non-compliant only when at least one regression indicator is present:
   - `MachineIdentityIsolation` exists under the Lsa key and is **not 0**, and/or
   - `Test-ComputerSecureChannel` reports a **broken** secure channel

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Repair-KB5124008SecureChannel.ps1
```

### Purpose
Applies the KB5124008 workaround and repairs the secure channel, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the device is domain-joined and the Lsa key is reachable
2. Fix 1: set `MachineIdentityIsolation = 0` under `HKLM:\SYSTEM\CurrentControlSet\Control\Lsa` (DWORD, created when missing)
3. Fix 2: repair the secure channel with `Test-ComputerSecureChannel -Repair`, falling back automatically to `nltest.exe /sc_reset:<Domain>` when the native reset is denied
4. Post-verify: re-read `MachineIdentityIsolation` (0) and re-test the secure channel (healthy)

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (verification failed) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Repair-KB5124008SecureChannel\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Repair-KB5124008SecureChannel.ps1
```

### Remediation Script
```powershell
remediate-Repair-KB5124008SecureChannel.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` only when the device is domain-joined, KB5124008 is installed, and at least one regression indicator is present (non-zero `MachineIdentityIsolation` and/or a broken secure channel)
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation clears `MachineIdentityIsolation = 0`, repairs the secure channel (native repair with `nltest /sc_reset` fallback), verifies them, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* **Scope discipline:** this package targets the KB5124008 regression only. Generic broken-trust cases belong to the `Repair-ADSecureChannel` package.
* **Lifecycle:** retire this package from Intune once Microsoft ships an official fix for the KB5124008 regression.
* Requires line-of-sight to a writable domain controller while the secure channel is repaired.
* A sign-out, restart, or policy refresh may be required before the change is fully effective.
* Detection errors deliberately exit `2` so Intune never treats a crashed detection as non-compliance.
* **Intune "Failed" status is expected while non-compliant.** In Proactive Remediations, detection exit `1` is shown as *Failed (non-compliant)* — that is the designed trigger for the paired remediation. The device clears to *Succeeded* once a remediation run verifies the fix on a subsequent detection cycle.
* **A device that stays *Failed* after remediation means the secure channel re-tests unhealthy.** Check the remediation log's `PostCheckStatus` entries: a persistent broken channel usually means no writable DC line-of-sight during the PR run, a pending restart, or a machine-account password that needs `netdom resetpwd` / `nltest /sc_reset` and possibly a domain rejoin.
* **Access denied (0x80070005) during the password reset means the computer account lacks the AD 'Reset password' right.** Grant that right on the computer object, run `netdom resetpwd /server:<DC> /userd:<admin> /passwordd:*` once from the console, or rejoin to a fresh machine account — then re-run remediation. The script logs exactly which method was denied (`Test-ComputerSecureChannel -Repair` vs `nltest /sc_reset`).

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
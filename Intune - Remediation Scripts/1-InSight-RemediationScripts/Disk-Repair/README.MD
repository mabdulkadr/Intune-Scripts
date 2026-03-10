This folder now includes a paired detection and remediation script.

- `DiskRepair--Detect.ps1` checks the system drive health by reading `Get-Volume`
  and evaluating `HealthStatus`.
- `DiskRepair--Remediate.ps1` runs `Repair-Volume -Scan` against the system drive.

Any reported issues will be visible in the Proactive Remediation console and in
the script log files.

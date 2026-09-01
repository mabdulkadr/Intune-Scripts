<#
.TITLE
    Local Admin Drift Detection Script

.SYNOPSIS
    Detects unauthorized members of the local Administrators group.

.DESCRIPTION
    Enumerates the local Administrators group and compares every member against an
    allowlist of approved accounts and well-known SIDs (built-in Administrator, the
    Entra-joined device admin roles, and configurable extra entries). Returns exit
    code 1 when unauthorized members are present, triggering the paired remediation
    that removes them. This catches technician accounts, self-elevation leftovers,
    and helpdesk additions that were never cleaned up. This script NEVER modifies
    the system.

    Exit contract:
    Exit 0 = compliant (only approved members present)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Repair-LocalAdminDrift.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - enumerates local Administrators group membership via ADSI.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.1

.CHANGELOG
    1.0.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Repair-LocalAdminDrift.ps1
    Returns exit 0 when only approved members are present; exit 1 otherwise.

.EXAMPLE
    .\detect-Repair-LocalAdminDrift.ps1
    Returns exit 2 if the group cannot be enumerated.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Keep $AllowedNames in sync with the remediation script; add your LAPS-managed admin account name there
    - The built-in Administrator (RID 500) and the Entra device administrator role SIDs (S-1-12-1-...) are always allowed
    - Uses ADSI enumeration because Get-LocalGroupMember fails on orphaned SIDs
    - Logs: <SystemDrive>\IntuneLogs\local-admin-drift\local-admin-drift-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Repair-LocalAdminDrift'
$ScriptMode   = 'Detection'

# Account names that are allowed local admins (keep in sync with remediation script)
$AllowedNames = @(
    "LocalAdmin"
)

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the Intune log folder/file and reports readiness.
function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}

# ============================================================================
# DETECTION LOGIC
# Return a list of reason strings so operators see every failure at once.
# Empty list = compliant. Never modify the system here.
# ============================================================================

# ADSI enumeration handles orphaned SIDs that break Get-LocalGroupMember.
function Get-AdministratorsGroupMember {
    $adminGroupSid = "S-1-5-32-544"
    $group = [ADSI]"WinNT://./$((Get-LocalGroup -SID $adminGroupSid).Name),group"

    $members = @($group.Invoke("Members")) | ForEach-Object {
        $path = ([ADSI]$_).InvokeGet("AdsPath")
        $name = ([ADSI]$_).InvokeGet("Name")
        $sid = $null
        try {
            $sidBytes = ([ADSI]$_).InvokeGet("objectSID")
            $sid = (New-Object System.Security.Principal.SecurityIdentifier($sidBytes, 0)).Value
        }
        catch {
            # Orphaned entries may not expose a SID - fall back to the path
        }
        [PSCustomObject]@{ Name = $name; Path = $path; Sid = $sid }
    }

    return @($members)
}

# Returns $true when the member is on the allowlist or a well-known admin SID.
function Test-AllowedMember {
    param([object]$Member)

    # Built-in Administrator account (RID 500) is always allowed
    if ($Member.Sid -and $Member.Sid -match "-500$") { return $true }

    # Entra role SIDs (Global Administrator / Entra ID Joined Device Local Admin)
    # are provisioned by the join process and always allowed
    if ($Member.Sid -and $Member.Sid -like "S-1-12-1-*") { return $true }

    # Domain Admins / Enterprise Admins for hybrid-joined devices
    if ($Member.Sid -and ($Member.Sid -match "-512$" -or $Member.Sid -match "-519$")) { return $true }

    if ($AllowedNames -contains $Member.Name) { return $true }

    return $false
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    $members = Get-AdministratorsGroupMember
    $unauthorized = @($members | Where-Object { -not (Test-AllowedMember -Member $_) })

    if ($unauthorized.Count -eq 0) {
        return @($reasons)
    }

    foreach ($member in $unauthorized) {
        $reasons.Add("Unauthorized member in local Administrators group: $($member.Name)")
    }

    return @($reasons)
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> compliance checks -> exit 0 compliant / 1 non-compliant / 2 error.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started" -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Write-Output "Local Administrators group contains only approved members."
        Finish-Script -ExitCode 0 -Message "Compliant - no unauthorized local administrators found" -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}



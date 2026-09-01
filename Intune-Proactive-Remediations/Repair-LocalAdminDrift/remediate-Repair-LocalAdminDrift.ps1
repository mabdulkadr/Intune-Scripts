<#
.TITLE
    Local Admin Drift Remediation Script

.SYNOPSIS
    Removes unauthorized members from the local Administrators group.

.DESCRIPTION
    Paired remediation for local-admin-drift. Runs only when
    detect-Repair-LocalAdminDrift.ps1 returns exit 1. Enumerates the local
    Administrators group and removes every member that is not on the allowlist:
    the built-in Administrator (RID 500), the Entra device administrator role SIDs,
    Domain/Enterprise Admins for hybrid devices, and the configurable allowed
    account names. Performs: (1) pre-remediation validation, (2) per-member removal
    with failure tracking, (3) post-remediation verification by re-enumerating the
    group, (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (group verified clean after removal)
    Exit 1 = failure (removal or verification failed)
    Exit 2 = script error

.TAGS
    Remediation,Action

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Repair-LocalAdminDrift.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - removes members from the local Administrators group.

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
    .\remediate-Repair-LocalAdminDrift.ps1
    Removes all unauthorized members and verifies the group is clean afterwards.

.EXAMPLE
    .\remediate-Repair-LocalAdminDrift.ps1
    Exits 1 if a member could not be removed or verification failed, exit 2 on script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Keep $AllowedNames identical to the detection script or the pair will fight each other
    - Removal uses the group's Remove method via ADSI, which also handles orphaned SIDs
    - Test on a pilot group first: removing an account that users rely on locks them out of admin tasks
    - Logs: <SystemDrive>\IntuneLogs\local-admin-drift\local-admin-drift-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Repair-LocalAdminDrift'
$ScriptMode   = 'Remediation'

# Account names that are allowed local admins (keep in sync with detection script)
$script:AllowedNames = @(
    "LocalAdmin"
)

$remediationResult = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
}

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

# Appends structured per-target remediation entries to the audit trail.
function Write-RemediationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    # Console/file via canonical Write-Log + structured record for JSON output.
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:RemediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Returns the ADSI COM object for the local Administrators group.
function Get-AdministratorsGroup {
    $adminGroupSid = "S-1-5-32-544"
    $groupName = (Get-LocalGroup -SID $adminGroupSid).Name
    return [ADSI]"WinNT://./$groupName,group"
}

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # The group must be enumerable before any member can be removed.
        $script:AdminGroup = Get-AdministratorsGroup
        $null = @($script:AdminGroup.Invoke("Members"))
        Write-RemediationLog "Pre-remediation validation completed successfully" -Level 'Info'
        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# REMEDIATION ACTION (per-target pattern)
# ============================================================================

# Returns $true when the member is on the allowlist or a well-known admin SID.
function Test-AllowedMember {
    param([object]$Member)

    if ($Member.Sid -and $Member.Sid -match "-500$") { return $true }
    if ($Member.Sid -and $Member.Sid -like "S-1-12-1-*") { return $true }
    if ($Member.Sid -and ($Member.Sid -match "-512$" -or $Member.Sid -match "-519$")) { return $true }
    if ($script:AllowedNames -contains $Member.Name) { return $true }

    return $false
}

# Applies the fix to ONE target and returns a structured success/failure object.
function Invoke-FixTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][scriptblock]$Fix
    )
    # Returns $true when the fix was applied AND verified for this target.
    try {
        & $Fix
        return $true
    }
    catch {
        $script:FailedCount++
        Write-RemediationLog "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
# Re-enumerates the group; verification passes only when no unauthorized member remains.
function Test-FixApplied {
    try {
        $members = @($script:AdminGroup.Invoke("Members")) | ForEach-Object {
            $adsiMember = [ADSI]$_
            $sid = $null
            try {
                $sidBytes = $adsiMember.InvokeGet("objectSID")
                $sid = (New-Object System.Security.Principal.SecurityIdentifier($sidBytes, 0)).Value
            }
            catch {
                # Orphaned entries may not expose a SID
            }
            [PSCustomObject]@{
                Name    = $adsiMember.InvokeGet("Name")
                AdsPath = $adsiMember.InvokeGet("AdsPath")
                Sid     = $sid
            }
        }

        $stillUnauthorized = @($members | Where-Object { -not (Test-AllowedMember -Member $_) })

        if ($stillUnauthorized.Count -eq 0) {
            Write-RemediationLog "Verification passed - no unauthorized members remain" -Level 'Info'
            $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"
            return $true
        }

        Write-RemediationLog "Verification found unauthorized members still present: $(($stillUnauthorized | ForEach-Object { $_.Name }) -join ', ')" -Level 'Error'
        $script:RemediationResult.PostCheckStatus += "Unauthorized members still present after remediation"
        return $false
    }
    catch {
        Write-RemediationLog "Verification could not enumerate the group: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> per-target fix -> post-verify -> exit 0 / 1 / 2.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-RemediationLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    $script:FailedCount = 0
    $targetCount        = 0
    $removed            = [System.Collections.Generic.List[string]]::new()
    $failed             = [System.Collections.Generic.List[string]]::new()

    $members = @($script:AdminGroup.Invoke("Members")) | ForEach-Object {
        $adsiMember = [ADSI]$_
        $sid = $null
        try {
            $sidBytes = $adsiMember.InvokeGet("objectSID")
            $sid = (New-Object System.Security.Principal.SecurityIdentifier($sidBytes, 0)).Value
        }
        catch {
            # Orphaned entries may not expose a SID
        }
        [PSCustomObject]@{
            Name    = $adsiMember.InvokeGet("Name")
            AdsPath = $adsiMember.InvokeGet("AdsPath")
            Sid     = $sid
        }
    }

    # --- Fix (per-target failure tracking) ---
    $mutationApproved = $PSCmdlet.ShouldProcess('local Administrators group', 'Remove unauthorized members')

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    if ($mutationApproved) {
        foreach ($member in @($members)) {
            if (Test-AllowedMember -Member $member) { continue }

            $targetCount++
            $adsPath = $member.AdsPath
            $result = Invoke-FixTarget -TargetName $member.Name -Fix {
                $script:AdminGroup.Remove($adsPath)
            }

            if ($result) {
                $removed.Add($member.Name)
                Write-RemediationLog "Removed from local Administrators: $($member.Name)" -Level 'Info'
            }
            else {
                $failed.Add($member.Name)
            }
        }
    }
    else {
        Write-RemediationLog "WhatIf mode - removal actions skipped" -Level 'Warning'
    }

    if ($removed.Count -gt 0) {
        Write-Output "Removed from local Administrators: $($removed -join ', ')"
    }
    else {
        Write-Output "No unauthorized members needed removal."
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    if (-not $mutationApproved) {
        $script:RemediationResult.PostCheckStatus += "WhatIf mode - actions were not applied, verification skipped"
        $verificationPassed = $false
    }
    else {
        $verificationPassed = Test-FixApplied
    }

    if ($failed.Count -gt 0) {
        $verificationPassed = $false
        Write-Output "Failed to remove: $($failed -join ' | ')"
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"

        Write-Output "Targets processed: $targetCount (failed: $($failed.Count))"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        if (-not $mutationApproved) {
            Write-Output "WhatIf mode - changes were not applied (verification skipped)"
        }
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
    }
}
catch {
    $script:RemediationResult.Status = "Error"
    $script:RemediationResult.Error = @{
        Message    = $_.Exception.Message
        Type       = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
    }
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally {
    Write-Log -Message "Cleanup complete." -Level 'DEBUG'
}



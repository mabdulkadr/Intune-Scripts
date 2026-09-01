<#
.TITLE
    Remediation - Disable IPv6 Protocol

.SYNOPSIS
    Disables the ms_tcpip6 binding on enabled adapters and writes the system-wide IPv6 registry setting.

.DESCRIPTION
    Paired remediation for Disable-IPv6Protocol. Runs only when detect-Disable-IPv6Protocol.ps1
    returns exit 1. Disables the ms_tcpip6 binding on every adapter that still has it enabled, then
    writes HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\DisabledComponents as a DWORD
    with value 255 to disable IPv6 components at the system level. A restart is required before all
    changes fully take effect. Performs: (1) pre-remediation validation, (2) per-target disable and
    registry write with failure tracking, (3) post-remediation verification, (4) structured JSON
    result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Network,IPv6,Adapters

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Disable-IPv6Protocol.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - disables adapter bindings and writes one HKLM registry value.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.x - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Disable-IPv6Protocol.ps1
    Disables IPv6 bindings, writes DisabledComponents=255, and verifies; exits 0 on success.

.EXAMPLE
    .\remediate-Disable-IPv6Protocol.ps1
    Exits 1 if any adapter change or verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - A restart is required before the full system-level effect.
    - Idempotent: already-disabled bindings are skipped and the registry write is force-overwritten.
    - Logs: <SystemDrive>\IntuneLogs\Disable-IPv6Protocol\Disable-IPv6Protocol-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Disable-IPv6Protocol'
$ScriptMode   = 'Remediation'

$BindingComponentId = 'ms_tcpip6'
$RegistryPath       = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
$RegistryName       = 'DisabledComponents'
$DesiredValue       = 255

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

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # The Tcpip6 Parameters key must exist before New-ItemProperty can write to it.
        if (-not (Test-Path -LiteralPath $RegistryPath)) {
            throw "Required registry key not found: $RegistryPath"
        }

        # Capture the current adapter bindings so per-target fixes have their targets.
        $script:AllBindings = @(Get-NetAdapterBinding -ComponentID $BindingComponentId -ErrorAction Stop)
        $script:EnabledBindings = @($script:AllBindings | Where-Object { $_.Enabled })

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
function Test-FixApplied {
    try {
        # Re-check the same value the legacy script read back after writing.
        $currentValue = Get-ItemPropertyValue -Path $RegistryPath -Name $RegistryName -ErrorAction Stop
        Write-Log -Message ("Verified {0}\\{1} = {2}" -f $RegistryPath, $RegistryName, $currentValue) -Level 'DEBUG'
        return ($currentValue -eq $DesiredValue)
    }
    catch {
        Write-RemediationLog "Verification could not read ${RegistryName}: $($_.Exception.Message)" -Level 'Error'
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
    Write-RemediationLog ("Querying adapter bindings for component: {0}" -f $BindingComponentId) -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # Legacy behavior preserved: no bindings returned blocks remediation with exit 1.
    if ($script:AllBindings.Count -eq 0) {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation cannot proceed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message ("No adapter bindings were returned for component '{0}'." -f $BindingComponentId) -Level 'ERROR'
    }

    Write-Log -Message ("Total adapters checked: {0}" -f $script:AllBindings.Count) -Level 'INFO'
    Write-Log -Message ("Adapters with IPv6 enabled: {0}" -f $script:EnabledBindings.Count) -Level 'INFO'

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0
    $adapterFailures    = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    foreach ($binding in $script:EnabledBindings) {
        $targetCount++
        $fixed = Invoke-FixTarget -TargetName "Adapter: $($binding.Name)" -Fix {
            Disable-NetAdapterBinding -Name $binding.Name -ComponentID $BindingComponentId -Confirm:$false -ErrorAction Stop | Out-Null
        }
        if ($fixed) {
            Write-RemediationLog ("IPv6 was disabled on adapter: {0}" -f $binding.Name) -Level 'Info'
        }
        else {
            $adapterFailures++
        }
    }

    $targetCount++
    Invoke-FixTarget -TargetName "$RegistryName=$DesiredValue" -Fix {
        New-ItemProperty -Path $RegistryPath -Name $RegistryName -PropertyType DWord -Value $DesiredValue -Force -ErrorAction Stop | Out-Null
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # Legacy behavior preserved: partial adapter failures fail the run even when the
    # registry value was written correctly.
    if ($adapterFailures -gt 0) {
        Write-RemediationLog ("IPv6 registry setting was applied, but adapter-level disable failed on {0} adapter(s)." -f $adapterFailures) -Level 'Warning'
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "IPv6 was disabled successfully. A restart is required for the full system effect." -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
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

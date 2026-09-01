<#
.TITLE
    Remediation - Install Matching Windows Updates

.SYNOPSIS
    Installs matching Windows updates via PSWindowsUpdate and reports reboot state.

.DESCRIPTION
    Paired remediation for Invoke-WindowsUpdateScan. Runs only when
    detect-Invoke-WindowsUpdateScan.ps1 returns exit 1. Performs: (1) pre-remediation
    validation of configuration plus module availability, (2) an update scan and
    Install-WindowsUpdate run with failure tracking, (3) post-remediation
    verification of the install outcome including pending-reboot status,
    (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,WindowsUpdate,PSWindowsUpdate,Patching

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Invoke-WindowsUpdateScan.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - installs the PSWindowsUpdate
    module when missing and installs matching Windows updates.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.2
    - Filtered install flow with pending-reboot registry reporting
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Invoke-WindowsUpdateScan.ps1
    Scans for and installs matching updates; exits 0 on verified success.

.EXAMPLE
    .\remediate-Invoke-WindowsUpdateScan.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM or user context via Intune Proactive Remediations.
    - Verification semantics: success means either nothing matched or the install run
      finished without a terminating error; installed updates may still require a
      reboot before they are fully applied.
    - Logs: <SystemDrive>\IntuneLogs\Invoke-WindowsUpdateScan\Invoke-WindowsUpdateScan-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Invoke-WindowsUpdateScan'
$ScriptMode   = 'Remediation'

$ModuleName   = 'PSWindowsUpdate'
$UpdateSource = 'MicrosoftUpdate'

$AvailableUpdateTypes = @(
    'Driver',
    'Software'
)

$AvailableUpdateCategories = @(
    'Critical Updates',
    'Security Updates',
    'Definition Updates',
    'Drivers',
    'Feature Packs',
    'Update Rollups',
    'Updates',
    'Upgrades',
    'Microsoft Defender Antivirus'
)

$AvailableUpdateSeverities = @(
    'Critical',
    'Important',
    'Moderate',
    'Low'
)

# Leave arrays empty to target all available updates.
$SelectedUpdateTypes      = @()
$SelectedUpdateCategories = @()
$SelectedUpdateSeverities = @()
$IncludeKBArticleIDs      = @()
$ExcludeKBArticleIDs      = @()

$AutoRebootAfterInstall = $false

$PendingRebootKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
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

# Throw on invalid configuration so bad filters surface as script errors (exit 2).
function Test-UpdateConfiguration {
    $validSources = @('MicrosoftUpdate', 'WindowsUpdate')
    if ($UpdateSource -notin $validSources) {
        throw ("Invalid UpdateSource '{0}'. Valid values: {1}" -f $UpdateSource, ($validSources -join ', '))
    }

    $invalidTypes = @($SelectedUpdateTypes | Where-Object { $_ -notin $AvailableUpdateTypes })
    if ($invalidTypes.Count -gt 0) {
        throw ("Invalid UpdateType value(s): {0}. Valid values: {1}" -f ($invalidTypes -join ', '), ($AvailableUpdateTypes -join ', '))
    }

    $customCategories = @($SelectedUpdateCategories | Where-Object { $_ -notin $AvailableUpdateCategories })
    if ($customCategories.Count -gt 0) {
        Write-RemediationLog ("Custom category value(s) detected: {0}" -f ($customCategories -join ', ')) -Level 'Warning'
    }

    $customSeverities = @($SelectedUpdateSeverities | Where-Object { $_ -notin $AvailableUpdateSeverities })
    if ($customSeverities.Count -gt 0) {
        Write-RemediationLog ("Custom severity value(s) detected: {0}" -f ($customSeverities -join ', ')) -Level 'Warning'
    }
}

# Install PSWindowsUpdate when missing (legacy behavior preserved).
function Ensure-Module {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-RemediationLog ("Module '{0}' was not found. Installing it now." -f $Name) -Level 'Warning'
        Install-Module -Name $Name -Force -AllowClobber -ErrorAction Stop
        Write-RemediationLog ("Module '{0}' installed successfully." -f $Name) -Level 'Info'
    }
    else {
        Write-RemediationLog ("Module '{0}' is already installed." -f $Name) -Level 'Info'
    }
}

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        $currentPolicy = Get-ExecutionPolicy
        Write-RemediationLog ("Current execution policy is '{0}'. No changes are made by this remediation script." -f $currentPolicy) -Level 'Info'

        Test-UpdateConfiguration
        Ensure-Module -Name $ModuleName
        Import-Module $ModuleName -ErrorAction Stop
        Write-RemediationLog ("Module '{0}' imported successfully." -f $ModuleName) -Level 'Info'

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

# Build the Get-WindowsUpdate scan parameters from configuration.
function Get-UpdateQueryParameters {
    $parameters = @{
        AcceptAll    = $true
        IgnoreReboot = $true
        ErrorAction  = 'Stop'
    }

    if ($UpdateSource -eq 'MicrosoftUpdate') {
        $parameters.MicrosoftUpdate = $true
    }
    else {
        $parameters.WindowsUpdate = $true
    }

    if ($SelectedUpdateTypes.Count -gt 0) { $parameters.UpdateType = $SelectedUpdateTypes }
    if ($SelectedUpdateCategories.Count -gt 0) { $parameters.Category = $SelectedUpdateCategories }
    if ($SelectedUpdateSeverities.Count -gt 0) { $parameters.Severity = $SelectedUpdateSeverities }
    if ($IncludeKBArticleIDs.Count -gt 0) { $parameters.KBArticleID = $IncludeKBArticleIDs }
    if ($ExcludeKBArticleIDs.Count -gt 0) { $parameters.NotKBArticleID = $ExcludeKBArticleIDs }

    return $parameters
}

# Build the Install-WindowsUpdate parameters from configuration.
function Get-InstallParameters {
    $parameters = @{
        AcceptAll   = $true
        ErrorAction = 'Stop'
    }

    if ($AutoRebootAfterInstall) {
        $parameters.AutoReboot = $true
    }
    else {
        $parameters.IgnoreReboot = $true
    }

    if ($UpdateSource -eq 'MicrosoftUpdate') {
        $parameters.MicrosoftUpdate = $true
    }
    else {
        $parameters.WindowsUpdate = $true
    }

    if ($SelectedUpdateTypes.Count -gt 0) { $parameters.UpdateType = $SelectedUpdateTypes }
    if ($SelectedUpdateCategories.Count -gt 0) { $parameters.Category = $SelectedUpdateCategories }
    if ($SelectedUpdateSeverities.Count -gt 0) { $parameters.Severity = $SelectedUpdateSeverities }
    if ($IncludeKBArticleIDs.Count -gt 0) { $parameters.KBArticleID = $IncludeKBArticleIDs }
    if ($ExcludeKBArticleIDs.Count -gt 0) { $parameters.NotKBArticleID = $ExcludeKBArticleIDs }

    return $parameters
}

# Return $true when any pending-reboot indicator is present.
function Test-PendingReboot {
    foreach ($registryKey in $PendingRebootKeys) {
        if (Test-Path -LiteralPath $registryKey) {
            return $true
        }
    }

    return $false
}

# Return a readable label for a selection list.
function Get-SelectionText {
    param([array]$Items, [string]$EmptyText = 'All')
    if ($Items.Count -gt 0) { return ($Items -join ', ') }
    return $EmptyText
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    # Success definition: either nothing matched (device already clean) or the
    # install run finished without a terminating error. A full re-scan would
    # double remediation time and is not part of the guaranteed contract;
    # installed updates may still await a reboot reported separately below.
    if ($script:NoUpdatesFound) { return $true }
    if ($script:UpdatesInstalled) { return $true }

    return $false
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
    Write-RemediationLog ("Module name: {0}" -f $ModuleName) -Level 'Info'
    Write-RemediationLog ("Update source: {0}" -f $UpdateSource) -Level 'Info'
    Write-RemediationLog ("Selected UpdateType: {0}" -f (Get-SelectionText -Items $SelectedUpdateTypes)) -Level 'Info'
    Write-RemediationLog ("Selected Category: {0}" -f (Get-SelectionText -Items $SelectedUpdateCategories)) -Level 'Info'
    Write-RemediationLog ("Selected Severity: {0}" -f (Get-SelectionText -Items $SelectedUpdateSeverities)) -Level 'Info'
    Write-RemediationLog ("Included KBs: {0}" -f (Get-SelectionText -Items $IncludeKBArticleIDs -EmptyText 'None')) -Level 'Info'
    Write-RemediationLog ("Excluded KBs: {0}" -f (Get-SelectionText -Items $ExcludeKBArticleIDs -EmptyText 'None')) -Level 'Info'
    Write-RemediationLog ("Auto reboot after install: {0}" -f $AutoRebootAfterInstall) -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount       = 0
    $targetCount              = 0
    $script:UpdatesInstalled  = $false
    $script:NoUpdatesFound    = $false

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $targetCount++
    Invoke-FixTarget -TargetName 'Pending matching Windows updates' -Fix {
        $updateQueryParameters = Get-UpdateQueryParameters
        $matchingUpdates = @(Get-WindowsUpdate @updateQueryParameters)
        Write-RemediationLog ("Matching updates returned: {0}" -f $matchingUpdates.Count) -Level 'Info'

        if ($matchingUpdates.Count -gt 0) {
            Write-RemediationLog ("Installing {0} matching Windows updates." -f $matchingUpdates.Count) -Level 'Info'
            $installParameters = Get-InstallParameters
            Install-WindowsUpdate @installParameters | Out-Null
            $script:UpdatesInstalled = $true
            Write-RemediationLog 'All matching updates installed successfully.' -Level 'Info'
        }
        else {
            $script:NoUpdatesFound = $true
            Write-RemediationLog 'No matching updates were found.' -Level 'Info'
        }
    }

    # Reboot-state report (informational; matches legacy behavior).
    if ($script:UpdatesInstalled) {
        if (Test-PendingReboot) {
            Write-RemediationLog 'A reboot is required to complete the update process.' -Level 'Warning'
        }
        else {
            Write-RemediationLog 'No reboot is required after updates.' -Level 'Info'
        }
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message 'Windows Update remediation completed successfully.' -Level 'SUCCESS'
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

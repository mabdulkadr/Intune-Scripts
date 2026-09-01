<#
.TITLE
    Detection - Pending Windows Updates Scan

.SYNOPSIS
    Detects matching pending Windows updates via the PSWindowsUpdate module.

.DESCRIPTION
    Evaluates update compliance by scanning the local device with Get-WindowsUpdate.
    Update types, categories, severities, and KB article IDs can optionally be
    targeted through the configuration block; empty selections mean all available
    updates. One or more matching pending updates means non-compliant so the paired
    remediation installs them.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,WindowsUpdate,PSWindowsUpdate,Patching

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Invoke-WindowsUpdateScan.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - queries the update services;
    may install the PSWindowsUpdate module from the PowerShell Gallery when missing
    (legacy behavior preserved).

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.2
    - PSWindowsUpdate scan with type/category/severity/KB filters and exit 2 error contract
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Invoke-WindowsUpdateScan.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Invoke-WindowsUpdateScan.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM or user context via Intune Proactive Remediations.
    - Installs PSWindowsUpdate from the PowerShell Gallery when missing (legacy behavior).
    - Keep detection fast when feasible; the update scan duration depends
      on the device's update backlog.
    - Logs: <SystemDrive>\IntuneLogs\Invoke-WindowsUpdateScan\Invoke-WindowsUpdateScan-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Invoke-WindowsUpdateScan'
$ScriptMode   = 'Detection'

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

# Install PSWindowsUpdate when missing (legacy behavior preserved).
function Ensure-Module {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Log -Message ("Module '{0}' was not found. Installing it now." -f $Name) -Level 'WARNING'
        Install-Module -Name $Name -Force -AllowClobber -ErrorAction Stop
        Write-Log -Message ("Module '{0}' installed successfully." -f $Name) -Level 'SUCCESS'
    }
    else {
        Write-Log -Message ("Module '{0}' is already installed." -f $Name) -Level 'DEBUG'
    }
}

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
        Write-Log -Message ("Custom category value(s) detected: {0}" -f ($customCategories -join ', ')) -Level 'WARNING'
    }

    $customSeverities = @($SelectedUpdateSeverities | Where-Object { $_ -notin $AvailableUpdateSeverities })
    if ($customSeverities.Count -gt 0) {
        Write-Log -Message ("Custom severity value(s) detected: {0}" -f ($customSeverities -join ', ')) -Level 'WARNING'
    }
}

# Build the Get-WindowsUpdate query parameters from configuration.
function Get-UpdateQueryParameters {
    $parameters = @{
        ComputerName = 'localhost'
        AcceptAll    = $true
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

# Return a readable label for a selection list.
function Get-SelectionText {
    param([array]$Items, [string]$EmptyText = 'All')
    if ($Items.Count -gt 0) { return ($Items -join ', ') }
    return $EmptyText
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        $currentPolicy = Get-ExecutionPolicy
        Write-Log -Message ("Current execution policy is '{0}'. No changes are made by this detection script." -f $currentPolicy) -Level 'DEBUG'

        Test-UpdateConfiguration
        Ensure-Module -Name $ModuleName
        Import-Module $ModuleName -ErrorAction Stop
        Write-Log -Message ("Module '{0}' imported successfully." -f $ModuleName) -Level 'SUCCESS'

        $updateQueryParameters = Get-UpdateQueryParameters
        $matchingUpdates = @(Get-WindowsUpdate @updateQueryParameters)
        Write-Log -Message ("Matching updates returned: {0}" -f $matchingUpdates.Count) -Level 'DEBUG'

        if ($matchingUpdates.Count -gt 0) {
            $reasons.Add("There are $($matchingUpdates.Count) pending matching Windows update(s)")
        }
    }
    catch {
        throw "Failed to scan Windows Update state: $($_.Exception.Message)"
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
    Write-Log -Message ("Module name: {0}" -f $ModuleName) -Level 'DEBUG'
    Write-Log -Message ("Update source: {0}" -f $UpdateSource) -Level 'DEBUG'
    Write-Log -Message ("Selected UpdateType: {0}" -f (Get-SelectionText -Items $SelectedUpdateTypes)) -Level 'DEBUG'
    Write-Log -Message ("Selected Category: {0}" -f (Get-SelectionText -Items $SelectedUpdateCategories)) -Level 'DEBUG'
    Write-Log -Message ("Selected Severity: {0}" -f (Get-SelectionText -Items $SelectedUpdateSeverities)) -Level 'DEBUG'
    Write-Log -Message ("Included KBs: {0}" -f (Get-SelectionText -Items $IncludeKBArticleIDs -EmptyText 'None')) -Level 'DEBUG'
    Write-Log -Message ("Excluded KBs: {0}" -f (Get-SelectionText -Items $ExcludeKBArticleIDs -EmptyText 'None')) -Level 'DEBUG'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message 'No pending matching Windows updates were found.' -Level 'SUCCESS'
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

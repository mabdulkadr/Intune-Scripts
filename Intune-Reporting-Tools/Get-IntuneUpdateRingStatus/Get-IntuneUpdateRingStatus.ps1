<#
.TITLE
    Windows Update Ring Status Report

.SYNOPSIS
    Compares all Windows Update ring configurations and their deployment status.

.DESCRIPTION
    Lists every Windows Update for Business ring with its deferral periods, deadlines, active hours, delivery optimization, and restart settings. Shows assignment counts and compares rings side by side so you can spot misconfigured or inconsistent rings.

.TAGS
    Update,Ring,Windows,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,Group.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    1.0.0
    - Initial Toolkit import

.LASTUPDATE
    2026-08-26

 .EXAMPLE
    .\Get-IntuneUpdateRingStatus.ps1

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intuneupdateringstatus\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param([Parameter()][string]$ExportPath)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intuneupdateringstatus'
$ScriptMode   = 'run'

$scriptBasePath = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if ($ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = Join-Path -Path $scriptBasePath -ChildPath $ExportPath
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
        [Parameter(Mandatory = $true)]
        [string]$Message,
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
        [Parameter(Mandatory = $true)]
        [string]$Message,
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
# MAIN ENTRY LOGGING INITIALIZATION
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started" -Level 'INFO'



function Write-Status { param([string]$Msg,[string]$Color='Cyan'); Write-Log -Message "  [$((Get-Date).ToString('HH:mm:ss'))] $Msg" -Level 'INFO' }
function Write-Section { param([string]$Msg); Write-Log -Message "`n$('='*60)" -Level 'WARNING'; Write-Log -Message "  $Msg" -Level 'WARNING'; Write-Log -Message "$('='*60)" -Level 'WARNING' }

function Get-MgGraphAllPages {
    param([string]$Uri,[string]$Method='GET')
    try {
        $response = Invoke-MgGraphRequest -Uri $Uri -Method $Method -ErrorAction Stop
        $results = @()
        if ($null -ne $response.value) { $results += $response.value }
        elseif ($response) { $results += $response }
        while ($response.'@odata.nextLink') {
            $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -ErrorAction Stop
            if ($null -ne $response.value) { $results += $response.value }
        }
        return ,$results
    } catch [System.Exception] { Write-Verbose "Graph call failed: $_"; return @() }
}

Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All','Group.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

Write-Section "WINDOWS UPDATE RINGS"
$rings = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')"
Write-Status "Found $($rings.Count) update rings" "Green"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($ring in ($rings | Sort-Object displayName)) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  $($ring.displayName)" -Level 'INFO'
    Write-Log -Message "  $('-' * $ring.displayName.Length)" -Level 'DEBUG'

    # Get assignment count
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($ring.id)/assignments"
    $groupCount = ($assignments | Where-Object { $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' }).Count
    $hasAllDevices = ($assignments | Where-Object { $_.target.'@odata.type' -like '*allDevices*' }).Count -gt 0

    $qualityDefer = if ($null -ne $ring.qualityUpdatesDeferralPeriodInDays) { $ring.qualityUpdatesDeferralPeriodInDays } else { 'Not set' }
    $featureDefer = if ($null -ne $ring.featureUpdatesDeferralPeriodInDays) { $ring.featureUpdatesDeferralPeriodInDays } else { 'Not set' }
    $qualityPaused = $ring.qualityUpdatesPaused
    $featurePaused = $ring.featureUpdatesPaused
    $autoRestart = $ring.autoRestartNotificationDismissal
    $deadlineQuality = $ring.qualityUpdatesDeadlineInDays
    $deadlineFeature = $ring.featureUpdatesDeadlineInDays
    $graceQuality = $ring.qualityUpdatesGracePeriodInDays
    $graceFeature = $ring.featureUpdatesGracePeriodInDays
    $activeHoursStart = $ring.activeHoursStart
    $activeHoursEnd = $ring.activeHoursEnd
    $deliveryOpt = $ring.deliveryOptimizationMode
    $driversExcluded = $ring.driversExcluded
    $autoInstallBehavior = $ring.automaticUpdateMode

    Write-Log -Message "    Quality deferral    : ${qualityDefer} days$(if($qualityPaused){' [PAUSED]'})" -Level 'INFO'
    Write-Log -Message "    Feature deferral    : ${featureDefer} days$(if($featurePaused){' [PAUSED]'})" -Level 'INFO'
    Write-Log -Message "    Quality deadline    : $deadlineQuality days (grace: $graceQuality)" -Level 'DEBUG'
    Write-Log -Message "    Feature deadline    : $deadlineFeature days (grace: $graceFeature)" -Level 'DEBUG'
    Write-Log -Message "    Active hours        : $activeHoursStart - $activeHoursEnd" -Level 'DEBUG'
    Write-Log -Message "    Drivers excluded    : $driversExcluded" -Level 'DEBUG'
    Write-Log -Message "    Delivery opt mode   : $deliveryOpt" -Level 'DEBUG'
    Write-Log -Message "    Auto-install mode   : $autoInstallBehavior" -Level 'DEBUG'
    Write-Log -Message "    Assigned groups     : $groupCount$(if($hasAllDevices){' + All Devices'})" -Level 'INFO'

    $report.Add([PSCustomObject]@{
        RingName              = $ring.displayName
        QualityDeferralDays   = $qualityDefer
        FeatureDeferralDays   = $featureDefer
        QualityPaused         = $qualityPaused
        FeaturePaused         = $featurePaused
        QualityDeadlineDays   = $deadlineQuality
        FeatureDeadlineDays   = $deadlineFeature
        QualityGraceDays      = $graceQuality
        FeatureGraceDays      = $graceFeature
        ActiveHoursStart      = $activeHoursStart
        ActiveHoursEnd        = $activeHoursEnd
        DeliveryOptMode       = $deliveryOpt
        DriversExcluded       = $driversExcluded
        AutoInstallMode       = $autoInstallBehavior
        AssignedGroups        = $groupCount
        HasAllDevices         = $hasAllDevices
    })
}

# Alerts
Write-Section "UPDATE RING ALERTS"
$paused = $report | Where-Object { $_.QualityPaused -or $_.FeaturePaused }
if ($paused.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  PAUSED RINGS ($($paused.Count)):" -Level 'ERROR'
    foreach ($p in $paused) {
        $which = @()
        if ($p.QualityPaused) { $which += 'Quality' }
        if ($p.FeaturePaused) { $which += 'Feature' }
        Write-Log -Message "    $($p.RingName) - $($which -join ' + ') updates paused" -Level 'WARNING'
    }
}

$zeroDeferral = $report | Where-Object { $_.QualityDeferralDays -eq 0 -or $_.FeatureDeferralDays -eq 0 }
if ($zeroDeferral.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  ZERO DEFERRAL RINGS ($($zeroDeferral.Count)):" -Level 'WARNING'
    foreach ($z in $zeroDeferral) {
        Write-Log -Message "    $($z.RingName) - Quality: $($z.QualityDeferralDays)d, Feature: $($z.FeatureDeferralDays)d" -Level 'WARNING'
    }
}

$noDeadline = $report | Where-Object { -not $_.QualityDeadlineDays -and $_.AssignedGroups -gt 0 }
if ($noDeadline.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  NO DEADLINE SET ($($noDeadline.Count)):" -Level 'WARNING'
    foreach ($nd in $noDeadline) {
        Write-Log -Message "    $($nd.RingName) - no quality deadline enforced" -Level 'DEBUG'
    }
}

if ($paused.Count -eq 0 -and $zeroDeferral.Count -eq 0) {
    Write-Log -Message "  No alerts. All rings look healthy." -Level 'SUCCESS'
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "UpdateRings_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'



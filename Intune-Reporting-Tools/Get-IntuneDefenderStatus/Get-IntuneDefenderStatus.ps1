<#
.TITLE
    Intune Defender Status

.SYNOPSIS
    Reports Microsoft Defender health status across all Intune managed Windows devices.

.DESCRIPTION
    Pulls Windows protection state from all managed devices and reports signature age, real-
    time protection status, last scan dates, devices with active threats, devices with
    outdated signatures, and devices in which Defender is disabled or unhealthy.

.TAGS
    Intune,Defender,Security,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.1.0

.CHANGELOG
    1.1.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, banner, ErrorActionPreference, full cmdlet names, typed catches)
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Get-IntuneDefenderStatus.ps1
    Reports Defender health for all Windows devices

.EXAMPLE
    .\Get-IntuneDefenderStatus.ps1 -SignatureAgeDays 7
    Flags devices with signatures older than 7 days

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Logs: %ProgramData%\get-intune-defender-status\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()][int]$SignatureAgeDays = 3,
    [Parameter()][string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-defender-status'
$ScriptMode   = 'run'

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
# MAIN ENTRY LOGGING INITIALIZATION
# Flow: init -> banner -> modules -> Graph connection -> report generation.
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started" -Level 'INFO'
# ============================================================================
# REPORT OUTPUT ANCHORING
# Anchor relative output paths beside the script so CSV exports land in a
# predictable location regardless of the caller's current directory.
# Fallback chain: $PSScriptRoot -> $PSCommandPath -> $MyInvocation -> Get-Location.
# ============================================================================

$scriptDirectory = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

if ($ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = [System.IO.Path]::GetFullPath((Join-Path $scriptDirectory $ExportPath))
}

function Write-Status { param([string]$Msg,[string]$Color='Cyan'); $level = switch ($Color) { 'Red'{'ERROR'} 'Yellow'{'WARNING'} 'Green'{'SUCCESS'} 'DarkYellow'{'WARNING'} 'DarkGray'{'DEBUG'} default{'INFO'} }; Write-Log -Message $Msg -Level $level }
function Write-Section { param([string]$Msg); Write-Log -Message "=== $Msg ===" -Level 'INFO' }

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
    Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

Write-Section "COLLECTING DEFENDER STATUS"
Write-Status "Fetching Windows managed devices..."

$devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,deviceName,userPrincipalName,osVersion,complianceState,lastSyncDateTime"
Write-Status "Found $($devices.Count) Windows devices" "Green"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()
$healthyCount = 0; $unhealthyCount = 0; $outdatedSigCount = 0; $threatCount = 0; $rtpDisabledCount = 0; $noDataCount = 0

$deviceIndex = 0
foreach ($d in $devices) {
    $deviceIndex++
    if ($deviceIndex % 25 -eq 0) { Write-Progress -Activity "Fetching Defender status" -Status "$deviceIndex of $($devices.Count)" -PercentComplete (($deviceIndex/$devices.Count)*100) }

    $protState = $null
    try {
        $protState = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($d.id)/windowsProtectionState" -Method GET -ErrorAction Stop
    } catch [System.Exception] { }

    if (-not $protState) {
        $noDataCount++
        $report.Add([PSCustomObject]@{
            DeviceName=$d.deviceName; User=$d.userPrincipalName; OSVersion=$d.osVersion
            RealTimeProtection='No data'; EngineVersion='-'; SignatureVersion='-'
            SignatureLastUpdated='-'; SignatureAgeDays=-1; LastQuickScan='-'; LastFullScan='-'
            MalwareProtection='No data'; NetworkInspection='No data'
            ActiveThreats=0; ThreatStatus='-'; ComplianceState=$d.complianceState
            HealthStatus='No Data'; LastSync=$d.lastSyncDateTime
        })
        continue
    }

    $rtpEnabled = $protState.realTimeProtectionEnabled
    $engineVer = $protState.engineVersion
    $sigVer = $protState.antiVirusSignatureVersion
    $sigUpdated = $protState.antiVirusSignatureLastUpdateDateTime
    $lastQuick = $protState.lastQuickScanDateTime
    $lastFull = $protState.lastFullScanDateTime
    $malwareProt = $protState.malwareProtectionEnabled
    $networkInsp = $protState.networkInspectionSystemEnabled
    $productStatus = $protState.productStatus
    $isVm = $protState.isVirtualMachine

    $sigAge = if ($sigUpdated) { [math]::Round(((Get-Date) - [datetime]$sigUpdated).TotalDays, 1) } else { 999 }
    $isSigOutdated = $sigAge -gt $SignatureAgeDays

    # Get detected threats
    $threats = @()
    try {
        $threats = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($d.id)/windowsProtectionState/detectedMalwareState"
    } catch [System.Exception] { }
    $activeThreatCount = ($threats | Where-Object { $_.state -ne 'fullyStopped' -and $_.state -ne 'cleaned' }).Count

    # Determine health
    $healthStatus = 'Healthy'
    $issues = @()
    if (-not $rtpEnabled) { $issues += 'RTP disabled'; $rtpDisabledCount++ }
    if ($isSigOutdated) { $issues += "Signatures $([math]::Round($sigAge))d old"; $outdatedSigCount++ }
    if ($activeThreatCount -gt 0) { $issues += "$activeThreatCount active threat(s)"; $threatCount++ }
    if (-not $malwareProt) { $issues += 'Malware protection off' }

    if ($issues.Count -gt 0) { $healthStatus = 'Unhealthy'; $unhealthyCount++ } else { $healthyCount++ }

    $report.Add([PSCustomObject]@{
        DeviceName            = $d.deviceName
        User                  = $d.userPrincipalName
        OSVersion             = $d.osVersion
        RealTimeProtection    = $rtpEnabled
        EngineVersion         = $engineVer
        SignatureVersion      = $sigVer
        SignatureLastUpdated   = $sigUpdated
        SignatureAgeDays      = [math]::Round($sigAge, 1)
        LastQuickScan         = $lastQuick
        LastFullScan          = $lastFull
        MalwareProtection     = $malwareProt
        NetworkInspection     = $networkInsp
        ActiveThreats         = $activeThreatCount
        ThreatStatus          = if ($threats.Count -gt 0) { ($threats | ForEach-Object { "$($_.displayName):$($_.state)" }) -join '; ' } else { 'Clean' }
        ComplianceState       = $d.complianceState
        HealthStatus          = $healthStatus
        Issues                = if ($issues.Count -gt 0) { $issues -join '; ' } else { '-' }
        LastSync              = $d.lastSyncDateTime
    })
}
Write-Progress -Activity "Fetching Defender status" -Completed

Write-Section "DEFENDER HEALTH SUMMARY"
Write-Log -Message "" -Level 'INFO'
$totalReporting = $devices.Count - $noDataCount
Write-Log -Message "  Total Windows devices    : $($devices.Count)" -Level 'INFO'
Write-Log -Message "  Reporting Defender data  : $totalReporting" -Level 'INFO'
Write-Log -Message "  No Defender data         : $noDataCount" -Level 'WARNING'
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Healthy                  : $healthyCount" -Level 'SUCCESS'
Write-Log -Message "  Unhealthy                : $unhealthyCount" -Level 'WARNING'
Write-Log -Message "  RTP disabled             : $rtpDisabledCount" -Level 'WARNING'
Write-Log -Message "  Outdated signatures (>$SignatureAgeDays d): $outdatedSigCount" -Level 'WARNING'
Write-Log -Message "  Active threats           : $threatCount device(s)" -Level 'WARNING'

if ($totalReporting -gt 0) {
    $healthPct = [math]::Round(($healthyCount / $totalReporting) * 100, 1)
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Defender health rate     : $healthPct%" -Level 'WARNING'
}

# Show unhealthy devices
$unhealthy = $report | Where-Object { $_.HealthStatus -eq 'Unhealthy' } | Sort-Object { $_.ActiveThreats } -Descending
if ($unhealthy.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Unhealthy Devices ---" -Level 'ERROR'
    foreach ($u in ($unhealthy | Select-Object -First 20)) {
        Write-Log -Message "    $($u.DeviceName) | $($u.Issues)" -Level 'WARNING'
    }
    Write-Log -Message "    ... and $($unhealthy.Count - 20) more" -Level 'DEBUG'
}

# Signature version distribution
$sigVersions = $report | Where-Object { $_.SignatureVersion -ne '-' } | Group-Object SignatureVersion | Sort-Object Count -Descending | Select-Object -First 5
if ($sigVersions.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Top Signature Versions ---" -Level 'WARNING'
    foreach ($sv in $sigVersions) {
        Write-Log -Message "    $($sv.Name) : $($sv.Count) device(s)" -Level 'INFO'
    }
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "DefenderStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'

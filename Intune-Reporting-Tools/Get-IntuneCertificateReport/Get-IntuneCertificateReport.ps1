<#
.TITLE
    Intune Certificate Report

.SYNOPSIS
    Reports certificate deployment status across Intune managed devices.

.DESCRIPTION
    Lists all certificate profiles (SCEP, PKCS, trusted root) and their deployment status.
    Identifies profiles with failures and shows overall certificate health.

.TAGS
    Intune,Certificate,SCEP,PKCS,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All

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
    .\Get-IntuneCertificateReport.ps1
    Reports certificate deployment status

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Logs: %ProgramData%\get-intune-certificate-report\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding()]
param([Parameter()][string]$ExportPath)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-certificate-report'
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
    Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

Write-Section "CERTIFICATE PROFILES"
$allConfigs = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"

# Filter to certificate-related profiles
$certProfiles = $allConfigs | Where-Object {
    $_.'@odata.type' -like '*certificate*' -or
    $_.'@odata.type' -like '*scep*' -or
    $_.'@odata.type' -like '*pkcs*' -or
    $_.'@odata.type' -like '*trustedRoot*' -or
    $_.displayName -like '*cert*' -or
    $_.displayName -like '*SCEP*' -or
    $_.displayName -like '*PKCS*' -or
    $_.displayName -like '*root*CA*'
}

Write-Status "Found $($certProfiles.Count) certificate-related profiles" "Green"

if ($certProfiles.Count -eq 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  No certificate profiles found. Checking Settings Catalog for cert settings..." -Level 'DEBUG'
    $catalogPolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$select=id,name"
    $certCatalog = $catalogPolicies | Where-Object { $_.name -like '*cert*' -or $_.name -like '*SCEP*' -or $_.name -like '*PKCS*' }
    if ($certCatalog.Count -gt 0) {
        Write-Log -Message "  Found $($certCatalog.Count) certificate-related Settings Catalog policies" -Level 'WARNING'
        Write-Log -Message "    $($cc.name)" -Level 'INFO'
    } else {
        Write-Log -Message "  No certificate configurations found in this tenant." -Level 'DEBUG'
    }
    return
}

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($cp in ($certProfiles | Sort-Object displayName)) {
    $cpName = $cp.displayName
    $cpType = ($cp.'@odata.type' -replace '#microsoft.graph.','')

    try {
        $summary = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($cp.id)/deviceStatusOverview" -Method GET -ErrorAction Stop
    } catch [System.Exception] { $summary = $null }

    $succeeded = 0; $failed = 0; $error_ = 0; $pending = 0; $conflict = 0
    if ($summary) {
        $succeeded = if ($summary.configurationAppliedDeviceCount) { $summary.configurationAppliedDeviceCount } elseif ($summary.successCount) { $summary.successCount } else { 0 }
        $failed = if ($summary.failedCount) { $summary.failedCount } else { 0 }
        $error_ = if ($summary.errorCount) { $summary.errorCount } else { 0 }
        $conflict = if ($summary.conflictCount) { $summary.conflictCount } else { 0 }
        $pending = if ($summary.pendingCount) { $summary.pendingCount } else { 0 }
    }
    $total = $succeeded + $failed + $error_ + $pending
    $healthPct = if ($total -gt 0) { [math]::Round(($succeeded / $total) * 100, 1) } else { 0 }
    $hasIssues = ($failed + $error_) -gt 0
    $nameColor = if ($hasIssues) { 'Red' } else { 'Green' }

    Write-Log -Message "    $cpName [$cpType]" -Level 'INFO'
    Write-Log -Message "      OK: $succeeded | Failed: $failed | Error: $error_ | Pending: $pending | Health: $healthPct%" -Level 'WARNING'

    $report.Add([PSCustomObject]@{
        ProfileName=$cpName; ProfileType=$cpType; Succeeded=$succeeded
        Failed=$failed; Error=$error_; Conflict=$conflict; Pending=$pending
        TotalTargeted=$total; SuccessRate=$healthPct
    })
}

Write-Section "CERTIFICATE HEALTH SUMMARY"
$totalProfiles = $report.Count
$failingProfiles = ($report | Where-Object { ($_.Failed + $_.Error) -gt 0 }).Count
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Total cert profiles    : $totalProfiles" -Level 'INFO'
Write-Log -Message "  Healthy                : $($totalProfiles - $failingProfiles)" -Level 'SUCCESS'
Write-Log -Message "  With failures          : $failingProfiles" -Level 'WARNING'

if ($failingProfiles -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Failing Certificate Profiles ---" -Level 'ERROR'
    foreach ($fp in ($report | Where-Object { ($_.Failed + $_.Error) -gt 0 } | Sort-Object { $_.Failed + $_.Error } -Descending)) {
        Write-Log -Message "    $($fp.ProfileName) : $($fp.Failed + $fp.Error) failure(s)" -Level 'WARNING'
    }
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "CertificateReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'

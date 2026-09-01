<#
.TITLE
    Application Installation Status Report

.SYNOPSIS
    Generate a comprehensive application installation status report for all managed applications in Intune.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves all managed applications and their installation status
    across all devices, and generates detailed reports in both CSV and HTML formats. The report includes
    installation state (installed, pending, failed, not applicable), error codes, device details,
    and summary statistics to help identify and troubleshoot application deployment issues.

    Supports workstation dual-mode: interactive sign-in (auto-installs Microsoft.Graph.Authentication if missing; WAM-free via MgGraphCommunity when available) and optional app-only authentication via -TenantId/-ClientId with -ClientSecret or -CertificateThumbprint.

.TAGS
    Apps,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementApps.Read.All,DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.5.1

.CHANGELOG
    1.5.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.5 - Handle the installation-status report as the downloadable JSON payload returned by Microsoft Graph and preserve single-app result arrays
    1.4 - Added contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 -     1.2 - Preserve single-element arrays in the paging helper (Count was returning hashtable key count), -MaxApps now truly caps processed apps instead of only setting page size, genuinely retry an app after a 429 with max 3 attempts (continue was skipping it), request only needed app fields (via `$select)
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing); report auto-open failures no longer abort the script; app install status now read via deviceManagement/reports (mobileApps deviceStatuses was retired from the Graph service)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-app-installation-status-report.ps1
    Generates application installation status report for all applications

.EXAMPLE
    .\get-app-installation-status-report.ps1 -FilterByInstallState "failed"
    Generates report showing only failed application installations

.EXAMPLE
    .\get-app-installation-status-report.ps1 -FilterByPlatform "Windows" -OutputPath "C:\Reports"
    Generates report for Windows applications and saves to specified directory

.EXAMPLE
    .\get-app-installation-status-report.ps1 -FilterByAppName "Microsoft 365" -OpenReport "true"
    Generates report filtered by application name and opens the HTML report

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Requires appropriate permissions in Entra ID
    - Large tenants may take considerable time to complete due to API rate limits
    - Reports are saved in both CSV and HTML formats
    - Uses beta endpoint for comprehensive installation status data
    - Supports filtering by install state (installed, pending, failed, notApplicable)
    - Supports filtering by platform (Windows, iOS, Android, macOS)
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("all", "installed", "failed", "pending", "notApplicable", "error")]
    [string]$FilterByInstallState = "all",

    [Parameter(Mandatory = $false)]
    [ValidateSet("all", "Windows", "iOS", "Android", "macOS")]
    [string]$FilterByPlatform = "all",

    [Parameter(Mandatory = $false)]
    [string]$FilterByAppName = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$OpenReport,

    [Parameter(Mandatory = $false)]
    [int]$MaxApps = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall
)

$ErrorActionPreference = 'Stop'

# Normalize the local module-install override for string parameter binding.
$forceModuleInstallRaw = [string]$ForceModuleInstall
Remove-Variable -Name ForceModuleInstall
if ([string]::IsNullOrWhiteSpace($forceModuleInstallRaw)) {
    $ForceModuleInstall = $false
}
elseif ($forceModuleInstallRaw.Trim().ToLowerInvariant() -in @("true", "1", '$true')) {
    $ForceModuleInstall = $true
}
elseif ($forceModuleInstallRaw.Trim().ToLowerInvariant() -in @("false", "0", '$false')) {
    $ForceModuleInstall = $false
}
else {
    throw "Parameter 'ForceModuleInstall' accepts only true, false, 1, 0, $true, or $false."
}

# String parameter values are normalized to booleans.

foreach ($runbookBooleanParameter in @('OpenReport')) {
    $runbookBooleanRaw = [string](Get-Variable -Name $runbookBooleanParameter -ValueOnly)
    Remove-Variable -Name $runbookBooleanParameter

    if ([string]::IsNullOrWhiteSpace($runbookBooleanRaw)) {
        Set-Variable -Name $runbookBooleanParameter -Value $false
        continue
    }

    switch ($runbookBooleanRaw.Trim().ToLowerInvariant()) {
        { $_ -in @("true", "1", '$true') } {
            Set-Variable -Name $runbookBooleanParameter -Value $true
        }
        { $_ -in @("false", "0", '$false') } {
            Set-Variable -Name $runbookBooleanParameter -Value $false
        }
        default {
            throw "Parameter '$runbookBooleanParameter' accepts only true, false, 1, 0, $true, or $false."
        }
    }
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


# ============================================================================
# Get-StandardHtmlHead - emits <head> with Carbon design tokens + base styles.
# ============================================================================
function Get-StandardHtmlHead {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter()][string]$Subtitle = ''
    )

    return @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$Title $Subtitle</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@300;400;500;600&display=swap');

:root {
    --cds-background: #161616;
    --cds-layer-01: #262626;
    --cds-layer-02: #353535;
    --cds-border-strong-01: #4d4d4d;
    --cds-border-subtle-01: #393939;
    --cds-text-primary: #f4f4f4;
    --cds-text-secondary: #c6c6c6;
    --cds-text-helper: #8d8d8d;
    --cds-link: #78a9ff;
    --cds-blue: #0f62fe;
    --cds-purple: #8a3ffc;
    --cds-magenta: #d02670;
    --cds-support-success: #24a148;
    --cds-support-warning: #f1c21b;
    --cds-support-error: #da1e28;
    --cds-support-info: #0043ce;
}

* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background-color: var(--cds-background);
    color: var(--cds-text-primary);
    line-height: 1.4;
    padding: 32px;
    -webkit-font-smoothing: antialiased;
}

.header {
    margin-bottom: 40px;
    padding-bottom: 24px;
    border-bottom: 1px solid var(--cds-border-strong-01);
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    flex-wrap: wrap;
    gap: 16px;
}

.header-left h1 {
    font-size: 28px;
    font-weight: 300;
    letter-spacing: 0.5px;
    color: var(--cds-text-primary);
    margin-bottom: 4px;
}

.header-left h1 strong { font-weight: 600; }

.header .subtitle {
    color: var(--cds-text-secondary);
    font-size: 14px;
    font-family: 'IBM Plex Mono', monospace;
}

.header-right {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 12px;
    color: var(--cds-text-helper);
    text-align: right;
}

.kpi-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 2px;
    background-color: var(--cds-border-subtle-01);
    border: 1px solid var(--cds-border-subtle-01);
    margin-bottom: 40px;
}

.kpi-card {
    background-color: var(--cds-layer-01);
    padding: 20px;
    display: flex;
    flex-direction: column-reverse;
    justify-content: space-between;
    min-height: 120px;
    transition: background-color 0.15s ease;
}

.kpi-card:hover { background-color: var(--cds-layer-02); }

.kpi-value {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 38px;
    font-weight: 400;
    line-height: 1.1;
    color: var(--cds-text-primary);
}

.kpi-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--cds-text-secondary);
    letter-spacing: 0.2px;
    margin-bottom: 12px;
}

.section-title {
    font-size: 14px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--cds-text-secondary);
    margin: 40px 0 16px 0;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--cds-border-subtle-01);
    display: flex;
    align-items: center;
    gap: 8px;
}

.grid-2 {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(450px, 1fr));
    gap: 24px;
    margin-bottom: 24px;
}

.card {
    background-color: var(--cds-layer-01);
    border: 1px solid var(--cds-border-subtle-01);
    padding: 24px;
    display: flex;
    flex-direction: column;
}

.card h2 {
    font-size: 16px;
    font-weight: 400;
    margin-bottom: 24px;
    color: var(--cds-text-primary);
    border-left: 3px solid var(--cds-blue);
    padding-left: 12px;
}

.legend { list-style: none; flex: 1; min-width: 180px; }
.legend li {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 0;
    font-size: 13px;
    border-bottom: 1px solid var(--cds-border-subtle-01);
}
.legend li:last-child { border-bottom: none; }
.legend .dot { width: 8px; height: 8px; flex-shrink: 0; }
.legend .count {
    margin-left: auto;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
}

.bar-chart { display: flex; flex-direction: column; gap: 12px; }
.bar-row { display: flex; align-items: center; gap: 16px; font-size: 13px; }
.bar-label {
    min-width: 140px;
    text-align: right;
    color: var(--cds-text-secondary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.bar-track { flex: 1; height: 20px; background-color: var(--cds-border-subtle-01); position: relative; }
.bar-fill {
    height: 100%;
    transition: width 0.8s cubic-bezier(0.16, 1, 0.3, 1);
    display: flex;
    align-items: center;
    padding-left: 8px;
    font-size: 11px;
    font-family: 'IBM Plex Mono', monospace;
    color: #ffffff;
    min-width: 24px;
}

table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
}

thead th {
    text-align: left;
    padding: 12px 16px;
    background-color: var(--cds-layer-02);
    border-bottom: 1px solid var(--cds-border-strong-01);
    color: var(--cds-text-primary);
    font-weight: 500;
    font-size: 12px;
}

tbody td {
    padding: 12px 16px;
    border-bottom: 1px solid var(--cds-border-subtle-01);
    color: var(--cds-text-secondary);
}

tbody tr {
    background-color: var(--cds-layer-01);
    transition: background-color 0.1s ease;
}

tbody tr:hover { background-color: var(--cds-layer-02); }

.badge {
    display: inline-block;
    padding: 2px 8px;
    font-size: 11px;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}
.badge.critical { background-color: rgba(218, 30, 40, 0.15); color: #ff8389; border-left: 3px solid var(--cds-support-error); }
.badge.high     { background-color: rgba(219, 109, 40, 0.15); color: #ffb38a; border-left: 3px solid #db6d28; }
.badge.medium   { background-color: rgba(241, 194, 27, 0.15); color: #f1c21b; border-left: 3px solid var(--cds-support-warning); }
.badge.low      { background-color: rgba(36, 161, 72, 0.15); color: #8ee0a5; border-left: 3px solid var(--cds-support-success); }
.badge.info     { background-color: rgba(15, 98, 254, 0.15); color: #78a9ff; border-left: 3px solid var(--cds-support-info); }

.progress-bar {
    display: inline-block;
    width: 100px;
    height: 8px;
    background-color: var(--cds-border-subtle-01);
    vertical-align: middle;
}
.progress-fill { height: 100%; transition: width 0.5s ease; }
.progress-fill.low      { background-color: var(--cds-support-success); }
.progress-fill.medium   { background-color: var(--cds-support-warning); }
.progress-fill.high     { background-color: #db6d28; }
.progress-fill.critical { background-color: var(--cds-support-error); }
.pct-label {
    font-size: 11px;
    font-family: 'IBM Plex Mono', monospace;
    margin-left: 8px;
    vertical-align: middle;
    color: var(--cds-text-secondary);
}

.empty-state {
    text-align: center;
    padding: 40px;
    color: var(--cds-text-helper);
    font-style: normal;
    border: 1px dashed var(--cds-border-strong-01);
    background-color: var(--cds-background);
}

canvas { max-width: 100%; }

.footer {
    margin-top: 80px;
    padding: 32px;
    background-color: var(--cds-layer-01);
    border: 1px solid var(--cds-border-subtle-01);
    display: grid;
    grid-template-columns: 1.2fr 0.8fr 1fr;
    gap: 32px;
    align-items: start;
}

.footer-col { display: flex; flex-direction: column; gap: 8px; }
.footer-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    color: var(--cds-text-helper);
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
    margin-bottom: 4px;
}
.footer-value {
    font-size: 13px;
    color: var(--cds-text-primary);
    font-family: 'IBM Plex Mono', monospace;
    line-height: 1.6;
    word-break: break-all;
}
.footer-value strong { color: var(--cds-text-primary); font-weight: 500; }

.grade-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 16px;
    background-color: var(--cds-layer-02);
    border: 1px solid var(--cds-border-subtle-01);
    cursor: help;
    position: relative;
    transition: border-color 0.15s ease;
}
.grade-card:hover { border-color: var(--cds-blue); }
.grade-card .grade-letter {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 64px;
    font-weight: 300;
    line-height: 1;
    margin-bottom: 8px;
}
.grade-card .grade-rate { font-size: 12px; font-family: 'IBM Plex Mono', monospace; color: var(--cds-text-secondary); letter-spacing: 0.5px; }
.grade-card .grade-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    color: var(--cds-text-helper);
    margin-top: 12px;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
}
.grade-card[data-tooltip]:hover::after {
    content: attr(data-tooltip);
    position: absolute;
    bottom: calc(100% + 8px);
    left: 50%;
    transform: translateX(-50%);
    background-color: var(--cds-layer-02);
    border: 1px solid var(--cds-blue);
    color: var(--cds-text-primary);
    padding: 12px 16px;
    font-size: 11px;
    font-family: 'IBM Plex Sans', sans-serif;
    text-transform: none;
    letter-spacing: normal;
    line-height: 1.5;
    width: 240px;
    text-align: left;
    z-index: 10;
    pointer-events: none;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
    white-space: pre-wrap;
}

.action-bar { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 4px; }

.btn {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 14px;
    font-size: 12px;
    font-family: 'IBM Plex Sans', sans-serif;
    font-weight: 500;
    background-color: var(--cds-layer-02);
    color: var(--cds-text-primary);
    border: 1px solid var(--cds-border-strong-01);
    cursor: pointer;
    transition: background-color 0.15s ease, border-color 0.15s ease;
    text-decoration: none;
}
.btn:hover { background-color: var(--cds-layer-01); border-color: var(--cds-blue); }
.btn-primary { background-color: var(--cds-blue); color: #ffffff; border-color: var(--cds-blue); }
.btn-primary:hover { background-color: #0353e9; border-color: #0353e9; }
.btn-icon { width: 14px; height: 14px; flex-shrink: 0; }

.footer-meta {
    margin-top: 24px;
    padding-top: 20px;
    border-top: 1px solid var(--cds-border-subtle-01);
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
    font-size: 11px;
    color: var(--cds-text-helper);
    font-family: 'IBM Plex Mono', monospace;
    grid-column: 1 / -1;
}
.footer-meta a { color: var(--cds-link); text-decoration: none; }
.footer-meta a:hover { text-decoration: underline; }

.disclaimer-box {
    position: fixed;
    inset: 0;
    background-color: rgba(0, 0, 0, 0.7);
    display: none;
    align-items: center;
    justify-content: center;
    z-index: 100;
    padding: 32px;
}
.disclaimer-box.is-open { display: flex; }
.disclaimer-modal {
    background-color: var(--cds-layer-01);
    border: 1px solid var(--cds-border-strong-01);
    max-width: 560px;
    width: 100%;
    padding: 32px;
    max-height: 80vh;
    overflow-y: auto;
}
.disclaimer-modal h3 {
    font-size: 16px;
    font-weight: 600;
    margin-bottom: 16px;
    color: var(--cds-text-primary);
    text-transform: uppercase;
    letter-spacing: 1px;
}
.disclaimer-modal p {
    font-size: 13px;
    line-height: 1.6;
    color: var(--cds-text-secondary);
    margin-bottom: 16px;
}
.disclaimer-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 24px; }

@media (max-width: 768px) {
    .grid-2 { grid-template-columns: 1fr; }
    .kpi-row { grid-template-columns: repeat(2, 1fr); }
    .footer { grid-template-columns: 1fr; gap: 24px; }
    body { padding: 16px; }
}

@media print {
    body { background-color: #ffffff; color: #000000; padding: 12px; }
    .header, .footer, .kpi-card, .card { background-color: #ffffff !important; border-color: #d0d0d0 !important; break-inside: avoid; }
    .footer { display: none; }
    .section-title { color: #000000; border-bottom-color: #000000; }
    thead th { background-color: #f4f4f4; color: #000000; }
    .no-print { display: none; }
}
</style>
</head>
<body>
"@
}

# ============================================================================
# Get-StandardHtmlOpen - opens <body> with header bar + KPI tiles.
# Pass a hashtable of @{value=...; label=...; color=...} for each KPI.
# ============================================================================
function Get-StandardHtmlOpen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter()][string]$Subtitle = '',
        [Parameter()][string]$GeneratedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
        [Parameter()][string]$Operator = '',
        [Parameter()][hashtable[]]$Kpis = @()
    )

    $kpiHtml = ''
    foreach ($k in $Kpis) {
        $color = if ($k.ContainsKey('color') -and $k['color']) { "color:$($k['color'])" } else { '' }
        $kpiHtml += "<div class=`"kpi-card`"><div class=`"kpi-value`" style=`"$color`">$($k['value'])</div><div class=`"kpi-label`">$($k['label'])</div></div>`n"
    }

    $operatorRow = if ($Operator) { "<div style=`"margin-top: 4px;`">OPERATOR: $Operator</div>" } else { '' }

    return @"
<div class="header">
    <div class="header-left">
        <h1>$Title</h1>
        <div class="subtitle">$Subtitle</div>
    </div>
    <div class="header-right">
        <div>GENERATED: $GeneratedAt</div>
        $operatorRow
    </div>
</div>

<!-- KPI Cards -->
<div class="kpi-row">
$kpiHtml</div>
"@
}

# ============================================================================
# Get-StandardHtmlFooter - emits the canonical 3-column footer + modal.
# ============================================================================
function Get-StandardHtmlFooter {
    [CmdletBinding()]
    param(
        [Parameter()][string]$Tenant = '',
        [Parameter()][string]$Operator = '',
        [Parameter()][string]$GeneratedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
        [Parameter()][string]$Timezone = [System.TimeZoneInfo]::Local.DisplayName,
        [Parameter()][string]$Utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"),
        [Parameter()][string]$RunId = ([guid]::NewGuid().ToString().Substring(0, 8).ToUpper()),
        [Parameter()][string]$Version = '1.0.0',
        [Parameter()][string]$ReportName = 'Report',
        [Parameter()][string]$Grade = '',
        [Parameter()][string]$GradeRate = '',
        [Parameter()][string]$GradeColor = '',
        [Parameter()][string]$GradeTip = ''
    )

    $gradeBlock = if ($Grade) {
        $tipAttr = if ($GradeTip) { " data-tooltip=`"$GradeTip`"" } else { '' }
        @"
    <div class="footer-col">
        <div class="grade-card"$tipAttr>
            <div class="grade-letter" style="color:$GradeColor">$Grade</div>
            <div class="grade-rate">$GradeRate</div>
            <div class="grade-label">Compliance Grade</div>
        </div>
    </div>
"@
    } else {
        '<div class="footer-col"></div>'
    }

    return @"
<!-- Footer -->
<div class="footer">
    <div class="footer-col">
        <div class="footer-label">Tenant</div>
        <div class="footer-value"><strong>$Tenant</strong></div>
        <div class="footer-label" style="margin-top:12px;">Operator</div>
        <div class="footer-value">$Operator</div>
        <div class="footer-label" style="margin-top:12px;">Generated</div>
        <div class="footer-value">$GeneratedAt</div>
        <div class="footer-value" style="color:var(--cds-text-helper);font-size:11px;">$Timezone &middot; UTC $Utc</div>
    </div>
$gradeBlock
    <div class="footer-col">
        <div class="footer-label">Run</div>
        <div class="footer-value">$RunId</div>
        <div class="footer-label" style="margin-top:12px;">Quick Actions</div>
        <div class="action-bar">
            <button class="btn btn-primary" onclick="window.print()" title="Print or save as PDF">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M4 2h8v3H4V2zm0 5h8a2 2 0 0 1 2 2v3h-2v3H4v-3H2V9a2 2 0 0 1 2-2zm1 7v-3h6v3H5z"/></svg>
                Print
            </button>
            <button class="btn" onclick="navigator.clipboard.writeText(window.location.href)" title="Copy file path">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M5 2h7a1 1 0 0 1 1 1v9h-2V4H6v8H4V3a1 1 0 0 1 1-1zM2 5h8a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zm1 2v6h6V7H3z"/></svg>
                Copy Path
            </button>
            <button class="btn" onclick="document.querySelector('.header').scrollIntoView({behavior:'smooth'})" title="Back to top">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M8 3.5l5 5h-3v4H6v-4H3l5-5z"/></svg>
                Top
            </button>
        </div>
        <div class="action-bar" style="margin-top:8px;">
            <button class="btn" onclick="document.getElementById('disclaimerModal').classList.add('is-open')" title="View full disclaimer">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1a7 7 0 1 0 0 14A7 7 0 0 0 8 1zm0 3a1 1 0 0 1 1 1v4a1 1 0 0 1-2 0V5a1 1 0 0 1 1-1zm0 8a1 1 0 1 1 0-2 1 1 0 0 1 0 2z"/></svg>
                Disclaimer
            </button>
        </div>
    </div>
    <div class="footer-meta">
        <span>$ReportName &middot; v$Version &middot; Run $RunId</span>
        <span>Generated by <a href="https://github.com/mabdulkadr/powershell-enterprise-admin-skill" target="_blank" rel="noopener">PowerShell Enterprise Admin</a></span>
    </div>
</div>

<!-- Disclaimer modal -->
<div class="disclaimer-box" id="disclaimerModal" onclick="if(event.target===this)this.classList.remove('is-open')">
    <div class="disclaimer-modal">
        <h3>Disclaimer</h3>
        <p>This report is generated from read-only queries and is provided as-is with no warranty of any kind. The metrics and identifiers shown are a point-in-time snapshot and may not reflect the current state by the time this report is reviewed.</p>
        <p>Test generated tools in a staging environment before deploying to production. The authors assume no liability for any damage or data loss resulting from their use.</p>
        <p>This report may contain tenant identifiers and operator account names. Treat the file as confidential and follow your organization's data-handling policy when sharing.</p>
        <div class="disclaimer-actions">
            <button class="btn" onclick="document.getElementById('disclaimerModal').classList.remove('is-open')">Close</button>
        </div>
    </div>
</div>
"@
}

# ============================================================================
# Get-StandardHtmlClose - emits </body></html> + the standard JS helpers.
# ============================================================================
function Get-StandardHtmlClose {
    [CmdletBinding()]
    param()

    return @"
<script>
// Close disclaimer modal on Escape
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        const m = document.getElementById('disclaimerModal');
        if (m) m.classList.remove('is-open');
    }
});
</script>
</body>
</html>
"@
}

# ============================================================================
# Get-StandardHtmlChartScripts - optional helper for scripts that draw donuts/bars.
# ============================================================================
function Get-StandardHtmlChartScripts {
    [CmdletBinding()]
    param()

    return @"
<script>
// Mini donut chart renderer (no dependencies)
function drawDonut(canvasId, data, colors) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const cx = canvas.width / 2, cy = canvas.height / 2;
    const outerR = 76, innerR = 58;
    const total = data.reduce((a, b) => a + b, 0);
    if (total === 0) return;
    let startAngle = -Math.PI / 2;
    data.forEach((val, i) => {
        const sliceAngle = (val / total) * 2 * Math.PI;
        ctx.beginPath();
        ctx.arc(cx, cy, outerR, startAngle, startAngle + sliceAngle);
        ctx.arc(cx, cy, innerR, startAngle + sliceAngle, startAngle, true);
        ctx.closePath();
        ctx.fillStyle = colors[i];
        ctx.fill();
        startAngle += sliceAngle;
    });
}

// Bar chart renderer
function drawBars(containerId, data, colorFn) {
    const container = document.getElementById(containerId);
    if (!container || !data) return;
    const dataArray = Array.isArray(data) ? data : [data];
    if (!dataArray.length || (dataArray.length === 1 && !dataArray[0])) return;
    const maxVal = Math.max(...dataArray.map(d => d.value || 0));
    const colors = ['#0f62fe','#8a3ffc','#00b0ff','#008080','#da1e28','#ff832b','#8d8d8d','#e0e0e0'];
    dataArray.forEach((item, i) => {
        if (!item) return;
        const val = item.value || 0;
        const label = item.label || 'Unknown';
        const pct = maxVal > 0 ? (val / maxVal * 100) : 0;
        const color = colorFn ? colorFn(item, i) : colors[i % colors.length];
        const row = document.createElement('div');
        row.className = 'bar-row';
        row.innerHTML =
            '<div class="bar-label" title="' + label + '">' + label + '</div>' +
            '<div class="bar-track"><div class="bar-fill" style="width:' + pct + '%;background-color:' + color + '">' + val + '</div></div>';
        container.appendChild(row);
    });
}
</script>
"@
}

# ============================================================================
# Export-StandardHtmlReport - convenience: build + write a complete report in one call.
# Pass -Body as the HTML between header and footer.
# ============================================================================
function Export-StandardHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter()][string]$Subtitle = '',
        [Parameter()][string]$Tenant = '',
        [Parameter()][string]$Operator = '',
        [Parameter()][string]$Body = '',
        [Parameter()][hashtable[]]$Kpis = @(),
        [Parameter()][string]$Grade = '',
        [Parameter()][string]$GradeRate = '',
        [Parameter()][string]$GradeColor = '',
        [Parameter()][string]$GradeTip = '',
        [Parameter()][string]$Version = '1.0.0',
        [Parameter()][string]$ReportName = 'Report',
        [Parameter()][string]$ChartScripts = ''
    )

    $now = Get-Date
    $html = Get-StandardHtmlHead -Title $Title -Subtitle $Subtitle
    $html += Get-StandardHtmlOpen -Title $Title -Subtitle $Subtitle -GeneratedAt $now.ToString('yyyy-MM-dd HH:mm:ss') -Operator $Operator -Kpis $Kpis
    $html += $Body
    $html += Get-StandardHtmlFooter -Tenant $Tenant -Operator $Operator -GeneratedAt $now.ToString('yyyy-MM-dd HH:mm:ss') `
        -Timezone ([System.TimeZoneInfo]::Local.DisplayName) `
        -Utc $now.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") `
        -RunId ([guid]::NewGuid().ToString().Substring(0, 8).ToUpper()) `
        -Version $Version -ReportName $ReportName `
        -Grade $Grade -GradeRate $GradeRate -GradeColor $GradeColor -GradeTip $GradeTip
    if ($ChartScripts) { $html += "`n$ChartScripts" }
    $html += Get-StandardHtmlClose

    $html | Out-File -FilePath $OutputPath -Encoding utf8 -Force
}

# ============================================================================
# MAIN FLOW INITIALIZATION - structured logging starts before any tenant work.
# Flow: init log -> banner -> module setup -> Graph auth -> main logic.
# ============================================================================

$SolutionName = 'get-app-installation-status-report'
$ScriptMode   = 'run'

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner

# Resolve OutputPath beside the script when caller passes "" or "." (Law 12).
$scriptBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $OutputPath -or $OutputPath -eq ".") {
    $OutputPath = Join-Path $scriptBase "Reports"
} elseif ($PSBoundParameters.ContainsKey('OutputPath') -and $OutputPath -and -not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptBase $OutputPath
}

# ============================================================================
# ENVIRONMENT DETECTION AND SETUP
# ============================================================================

function Initialize-RequiredModule {
    param(
        [string[]]$ModuleNames,
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            Write-Information "Module '$ModuleName' not found. Installing..." -InformationAction Continue

            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$ModuleName' is required but installation was declined."
                }
            }

            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }

                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "✓ Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch [System.Exception] {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        Import-Module -Name $ModuleName -Force -ErrorAction Stop
    }
}

# Initialize required modules
$RequiredModules = @("Microsoft.Graph.Authentication")

# MgGraphCommunity provides WAM-free interactive sign-in for workstation scenarios
$RequiredModules += "MgGraphCommunity"

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch [System.Exception] {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION
# ============================================================================

try {
    $scopes = @(
            "DeviceManagementApps.Read.All",
            "DeviceManagementManagedDevices.Read.All"
        )

    if ($TenantId -and $ClientId -and ($ClientSecret -or $CertificateThumbprint)) {
        Write-Output "Connecting to Microsoft Graph with app-only authentication..."
        if ($CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $secureSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $secureSecret
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecretCredential $credential -NoWelcome -ErrorAction Stop
        }
        Write-Output "✓ Successfully connected to Microsoft Graph (app-only)"
    }
    else {
        Write-Output "Connecting to Microsoft Graph..."
        if (Get-Module -ListAvailable -Name MgGraphCommunity) {
            Connect-MgGraphCommunity -Scopes $scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "✓ Successfully connected to Microsoft Graph"
    }
}
catch [System.Exception] {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to get all pages of results with rate limiting
function Get-MgGraphAllPages {
    param(
        [string]$Uri,
        [int]$DelayMs = 100,
        [int]$MaxResults = 0
    )

    $allResults = @()
    $nextLink = $Uri
    $requestCount = 0

    do {
        try {
            # Add delay to respect rate limits
            if ($requestCount -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
            $requestCount++

            if ($null -ne $response.value) {
                $allResults += $response.value
            }
            else {
                $allResults += $response
            }

            # Stop paging once the requested maximum is reached ($top only sets
            # page size, so without this the pager would follow every nextLink)
            if ($MaxResults -gt 0 -and $allResults.Count -ge $MaxResults) {
                $allResults = @($allResults | Select-Object -First $MaxResults)
                break
            }

            $nextLink = $response.'@odata.nextLink'

            # Show progress for large datasets
            if ($requestCount % 10 -eq 0) {
                Write-Verbose "Fetched $($allResults.Count) items so far..."
            }
        }
        catch {
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                Write-Information "`nRate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data from $nextLink : $($_.Exception.Message)"
        }
    } while ($nextLink)

    # The comma preserves single-element arrays (Invoke-MgGraphRequest hashtable rows
    # otherwise unroll and .Count returns key count)
    return , $allResults
}

# Function to get app installation status rows from the reports endpoint with paging
# (the mobileApps deviceStatuses endpoint was retired from the Graph service)
function Get-AppInstallStatusReportRow {
    param(
        [string]$AppId,
        [int]$PageSize = 500,
        [int]$DelayMs = 100
    )

    $reportUri = "https://graph.microsoft.com/beta/deviceManagement/reports/retrieveDeviceAppInstallationStatusReport"
    $allRows = @()
    $skip = 0
    # MaxValue sentinel keeps the loop alive if the very first page hits a 429
    # (a zero sentinel would end the do/while before any retry could happen)
    $totalRows = [int]::MaxValue

    do {
        try {
            # Add delay to respect rate limits
            if ($skip -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $body = @{
                filter = "(ApplicationId eq '$AppId')"
                top    = $PageSize
                skip   = $skip
                select=@("DeviceId", "DeviceName", "UserName", "UserPrincipalName", "Platform", "AppVersion", "InstallState", "InstallStateDetail", "ErrorCode", "LastModifiedDateTime")
            } | ConvertTo-Json -Depth 5

            $reportPath = Join-Path ([System.IO.Path]::GetTempPath()) "Intune-AppInstall-$([guid]::NewGuid().ToString('N')).json"
            try {
                Invoke-MgGraphRequest -Uri $reportUri -Method POST -Body $body -ContentType "application/json" -OutputFilePath $reportPath | Out-Null
                $response = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -AsHashtable
            }
            finally {
                if (Test-Path -LiteralPath $reportPath) {
                    Remove-Item -LiteralPath $reportPath -Force
                }
            }

            $columnIndex = @{}
            for ($i = 0; $i -lt $response['Schema'].Count; $i++) {
                $columnIndex[$response['Schema'][$i].Column] = $i
            }

            foreach ($row in $response['Values']) {
                $allRows += [PSCustomObject]@{
                    DeviceId             = $row[$columnIndex['DeviceId']]
                    DeviceName           = $row[$columnIndex['DeviceName']]
                    UserName             = $row[$columnIndex['UserName']]
                    UserPrincipalName    = $row[$columnIndex['UserPrincipalName']]
                    Platform             = $row[$columnIndex['Platform']]
                    AppVersion           = $row[$columnIndex['AppVersion']]
                    InstallState         = $row[$columnIndex['InstallState']]
                    InstallStateDetail   = $row[$columnIndex['InstallStateDetail']]
                    ErrorCode            = $row[$columnIndex['ErrorCode']]
                    LastModifiedDateTime = $row[$columnIndex['LastModifiedDateTime']]
                }
            }

            $skip += $PageSize
            $totalRows = [int]$response['TotalRowCount']
        }
        catch {
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                Write-Information "`nRate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            Write-Warning "Error fetching install status report for app $AppId : $($_.Exception.Message)"
            break
        }
    } while ($skip -lt $totalRows)

    # Comma preserves a single-row result as an array so .Count is correct
    return , $allRows
}

# Function to convert report InstallState values to install state names
# Values per the resultantAppState enum (Microsoft Graph beta):
# 1 installed, 2 failed, 3 notInstalled, 4 uninstallFailed,
# 5 pendingInstall, 99 unknown, -1 notApplicable
function Convert-InstallStateValue {
    param($StateValue)

    switch ([int]$StateValue) {
        1 { return "installed" }
        2 { return "failed" }
        3 { return "notInstalled" }
        4 { return "uninstallFailed" }
        5 { return "pendingInstall" }
        99 { return "unknown" }
        -1 { return "notApplicable" }
        default { return "unknown" }
    }
}

# Function to map install state codes to human-readable status
function Get-InstallStateDisplay {
    param([string]$State)

    switch ($State) {
        "installed" { return "Installed" }
        "failed" { return "Failed" }
        "notApplicable" { return "Not Applicable" }
        "unknown" { return "Unknown" }
        "available" { return "Available" }
        "notInstalled" { return "Not Installed" }
        "uninstallFailed" { return "Uninstall Failed" }
        "pendingInstall" { return "Pending Install" }
        default { return $State }
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Starting application installation status report generation..."

    # Get all mobile apps
    Write-Output "Retrieving managed applications..."
    # Requests only the fields the report reads; typed collections always
    # return @odata.type
    $appsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$select=id,displayName,publisher,isAssigned"

    if ($MaxApps -gt 0) {
        $appsUri += "&`$top=$MaxApps"
    }

    # MaxResults enforces the actual app limit ($top only sets page size)
    $allApps = Get-MgGraphAllPages -Uri $appsUri -MaxResults $MaxApps

    # Filter apps if needed
    if ($FilterByAppName) {
        $allApps = $allApps | Where-Object { $_.displayName -like "*$FilterByAppName*" }
    }

    Write-Output "✓ Found $($allApps.Count) managed applications"

    # Create installation status collection
    $installationStatusList = @()
    $processedApps = 0

    Write-Output "Processing application installation status..."

    # Index-based loop so a throttled app can be retried without being skipped
    $appIndex = 0
    $throttleAttempts = 0
    while ($appIndex -lt $allApps.Count) {
        $app = $allApps[$appIndex]
        $processedApps = $appIndex + 1
        Write-Progress -Activity "Processing Application Installation Status" -Status "Processing app $processedApps of $($allApps.Count): $($app.displayName)" -PercentComplete (($processedApps / $allApps.Count) * 100)

        try {
            # Get device install status rows for this app via the reports endpoint
            $deviceStatuses = Get-AppInstallStatusReportRow -AppId $app.id

            foreach ($status in $deviceStatuses) {
                $installStateName = Convert-InstallStateValue -StateValue $status.InstallState

                # Apply filters. Wildcard match so "pending" also matches the
                # enum-derived "pendingInstall" state name
                if ($FilterByInstallState -ne "all" -and $installStateName -notlike "*$FilterByInstallState*") {
                    continue
                }

                # Skip if no device name (orphaned status)
                if (-not $status.DeviceName) {
                    continue
                }

                # Create status entry (OS details are not exposed by the installation status report)
                $statusEntry = [PSCustomObject]@{
                    ApplicationName       = $app.displayName
                    ApplicationId         = $app.id
                    ApplicationType       = $app.'@odata.type' -replace '#microsoft.graph.', ''
                    Publisher             = if ($app.publisher) { $app.publisher } else { "Unknown" }
                    DeviceName            = $status.DeviceName
                    DeviceId              = $status.DeviceId
                    UserName              = $status.UserName
                    UserPrincipalName     = $status.UserPrincipalName
                    Platform              = $status.Platform
                    InstallState          = Get-InstallStateDisplay -State $installStateName
                    InstallStateRaw       = $installStateName
                    InstallStateDetail    = if ($null -ne $status.InstallStateDetail) { $status.InstallStateDetail } else { "N/A" }
                    ErrorCode             = if ($status.ErrorCode) { $status.ErrorCode } else { "N/A" }
                    LastModifiedDateTime  = $status.LastModifiedDateTime
                    AppVersion            = if ($status.AppVersion) { $status.AppVersion } else { "Unknown" }
                    OSVersion             = "Unknown"
                    OSDescription         = "Unknown"
                }

                # Apply platform filter (report platform values include the OS
                # version, e.g. "Windows 10.0.26100.1")
                if ($FilterByPlatform -ne "all" -and $statusEntry.Platform -notlike "$FilterByPlatform*") {
                    continue
                }

                $installationStatusList += $statusEntry
            }

            # Add small delay to respect rate limits
            Start-Sleep -Milliseconds 200
        }
        catch {
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                $throttleAttempts++
                if ($throttleAttempts -lt 3) {
                    Write-Output "`nRate limit hit, waiting 60 seconds..."
                    Start-Sleep -Seconds 60
                    # Retry the same app without advancing the index
                    continue
                }
                Write-Warning "Rate limit persisted after 3 attempts for app $($app.displayName), skipping"
            }
            else {
                Write-Warning "Error processing app $($app.displayName): $($_.Exception.Message)"
            }
        }
        $throttleAttempts = 0
        $appIndex++
    }

    Write-Progress -Activity "Processing Application Installation Status" -Completed

    if ($installationStatusList.Count -eq 0) {
        Write-Output "No installation status records found matching the specified filters."
        Write-Output "Try adjusting your filter parameters or check if applications are deployed to devices."
        Disconnect-MgGraph | Out-Null
        exit 0
    }

    # Generate summary statistics
    $totalInstallations = $installationStatusList.Count
    $successfulInstalls = ($installationStatusList | Where-Object { $_.InstallStateRaw -eq "installed" }).Count
    $failedInstalls = ($installationStatusList | Where-Object { $_.InstallStateRaw -eq "failed" }).Count
    $pendingInstalls = ($installationStatusList | Where-Object { $_.InstallStateRaw -like "*pending*" }).Count
    $uniqueApps = ($installationStatusList | Group-Object ApplicationName).Count
    $uniqueDevices = ($installationStatusList | Group-Object DeviceName).Count

    $successRate = if ($totalInstallations -gt 0) { [math]::Round(($successfulInstalls / $totalInstallations) * 100, 2) } else { 0 }
    $failureRate = if ($totalInstallations -gt 0) { [math]::Round(($failedInstalls / $totalInstallations) * 100, 2) } else { 0 }

    # Get top failed apps
    $topFailedApps = $installationStatusList |
        Where-Object { $_.InstallStateRaw -eq "failed" } |
        Group-Object ApplicationName |
        ForEach-Object {
            [PSCustomObject]@{
                ApplicationName = $_.Name
                FailureCount    = $_.Count
                UniqueDevices   = ($_.Group | Group-Object DeviceName).Count
            }
        } |
        Sort-Object FailureCount -Descending |
        Select-Object -First 10

    # Get installation status by platform
    $statusByPlatform = $installationStatusList |
        Group-Object Platform |
        ForEach-Object {
            $platformData = $_.Group
            [PSCustomObject]@{
                Platform    = $_.Name
                Total       = $platformData.Count
                Installed   = ($platformData | Where-Object { $_.InstallStateRaw -eq "installed" }).Count
                Failed      = ($platformData | Where-Object { $_.InstallStateRaw -eq "failed" }).Count
                Pending     = ($platformData | Where-Object { $_.InstallStateRaw -like "*pending*" }).Count
                SuccessRate = if ($platformData.Count -gt 0) { [math]::Round((($platformData | Where-Object { $_.InstallStateRaw -eq "installed" }).Count / $platformData.Count) * 100, 2) } else { 0 }
            }
        } |
        Sort-Object Total -Descending

    # Generate timestamp for file names
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $csvPath = Join-Path $OutputPath "Intune_App_Installation_Status_Report_$timestamp.csv"
    $htmlPath = Join-Path $OutputPath "Intune_App_Installation_Status_Report_$timestamp.html"

    # Export to CSV
    try {
        $installationStatusList | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "✓ CSV report saved: $csvPath"
    }
    catch {
        Write-Error "Failed to save CSV report: $($_.Exception.Message)"
    }

    # Generate HTML report
    try {
        $htmlContent =         # Add filter information if filters were applied
        if ($FilterByInstallState -ne "all" -or $FilterByPlatform -ne "all" -or $FilterByAppName -or $MaxApps -gt 0) {
            $htmlContent += "<div class='filter-info'><strong>Applied Filters:</strong> "
            if ($FilterByInstallState -ne "all") { $htmlContent += "Install State: $FilterByInstallState | " }
            if ($FilterByPlatform -ne "all") { $htmlContent += "Platform: $FilterByPlatform | " }
            if ($FilterByAppName) { $htmlContent += "Application: $FilterByAppName | " }
            if ($MaxApps -gt 0) { $htmlContent += "Max Apps: $MaxApps | " }
            $htmlContent = $htmlContent.TrimEnd(" | ") + "</div>"
        }

        $htmlContent += @"
    <div class="summary">
        <h2>Summary</h2>
        <div class="summary-grid">
            <div class="summary-item">
                <div class="summary-number">$totalInstallations</div>
                <div>Total Installation Records</div>
            </div>
            <div class="summary-item">
                <div class="summary-number success">$successfulInstalls</div>
                <div>Successful Installations</div>
            </div>
            <div class="summary-item">
                <div class="summary-number danger">$failedInstalls</div>
                <div>Failed Installations</div>
            </div>
            <div class="summary-item">
                <div class="summary-number warning">$pendingInstalls</div>
                <div>Pending Installations</div>
            </div>
            <div class="summary-item">
                <div class="summary-number">$uniqueApps</div>
                <div>Unique Applications</div>
            </div>
            <div class="summary-item">
                <div class="summary-number">$uniqueDevices</div>
                <div>Unique Devices</div>
            </div>
        </div>

        <h3>Success Rate</h3>
        <div class="progress-bar">
            <div class="progress-fill" style="width: $successRate%">$successRate%</div>
        </div>
        <p style="text-align: center; margin-top: 10px;">Failure Rate: <span class="danger">$failureRate%</span></p>

        <div class="top-lists">
            <div class="top-list">
                <h3>Top 10 Failed Applications</h3>
"@

        if ($topFailedApps) {
            foreach ($app in $topFailedApps) {
                $htmlContent += "<div class='top-item'><span>$($app.ApplicationName)</span><span class='danger'>$($app.FailureCount) failures</span></div>"
            }
        }
        else {
            $htmlContent += "<p>No failed installations found.</p>"
        }

        $htmlContent += @"
            </div>
            <div class="top-list">
                <h3>Status by Platform</h3>
"@

        foreach ($platform in $statusByPlatform) {
            $htmlContent += @"
                <div class='top-item'>
                    <span><strong>$($platform.Platform)</strong></span>
                    <span>$($platform.SuccessRate)% success</span>
                </div>
                <div style='font-size: 12px; color: #6c757d; padding-left: 10px; margin-bottom: 10px;'>
                    Installed: $($platform.Installed) | Failed: $($platform.Failed) | Pending: $($platform.Pending)
                </div>
"@
        }

        $htmlContent += @"
            </div>
        </div>
    </div>

    <div class="summary">
        <h2>Detailed Installation Status</h2>
        <table>
            <thead>
                <tr>
                    <th>Application</th>
                    <th>Device</th>
                    <th>User</th>
                    <th>Platform</th>
                    <th>Status</th>
                    <th>Error Code</th>
                    <th>Last Modified</th>
                </tr>
            </thead>
            <tbody>
"@

        foreach ($status in $installationStatusList | Sort-Object ApplicationName, DeviceName) {
            $statusClass = switch ($status.InstallStateRaw) {
                "installed" { "status-installed" }
                "failed" { "status-failed" }
                { $_ -like "*pending*" } { "status-pending" }
                default { "status-other" }
            }

            $htmlContent += @"
                <tr>
                    <td>$($status.ApplicationName)</td>
                    <td>$($status.DeviceName)</td>
                    <td>$($status.UserName)</td>
                    <td>$($status.Platform)</td>
                    <td><span class="status-badge $statusClass">$($status.InstallState)</span></td>
                    <td>$($status.ErrorCode)</td>
                    <td>$($status.LastModifiedDateTime)</td>
                </tr>
"@
        }

        $htmlContent += @"
            </tbody>
        </table>
    </div>

    <div class='footer'>Report generated by Intune Application Installation Status Script v1.0</div>
</body>
</html>
"@

        $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
        Write-Output "✓ HTML report saved: $htmlPath"

        if ($OpenReport) {
            try {
                Start-Process $htmlPath
            }
            catch {
                Write-Warning "Could not open the report automatically: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Error "Failed to generate HTML report: $($_.Exception.Message)"
    }

    # Display summary
    Write-Output ""
    Write-Output "APPLICATION INSTALLATION STATUS SUMMARY"
    Write-Output "========================================"
    Write-Output "Total Installation Records: $totalInstallations"
    Write-Output "Successful Installations: $successfulInstalls ($successRate%)"
    Write-Output "Failed Installations: $failedInstalls ($failureRate%)"
    Write-Output "Pending Installations: $pendingInstalls"
    Write-Output "Unique Applications: $uniqueApps"
    Write-Output "Unique Devices: $uniqueDevices"

    if ($topFailedApps -and $topFailedApps.Count -gt 0) {
        Write-Output "`nTop 5 Failed Applications:"
        $topFailedApps | Select-Object -First 5 | ForEach-Object {
            Write-Output "  $($_.ApplicationName): $($_.FailureCount) failures on $($_.UniqueDevices) devices"
        }
    }

    Write-Output "`nReports saved to:"
    Write-Output "CSV: $csvPath"
    Write-Output "HTML: $htmlPath"

    Write-Output "`nApplication installation status report generation completed successfully!"
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Microsoft Graph
    try {
        if (Get-MgContext -ErrorAction SilentlyContinue) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Output "✓ Disconnected from Microsoft Graph"
        }
    }
    catch {
        # Ignore disconnection errors - this is expected behavior when already disconnected
        Write-Verbose "Graph disconnection completed (may have already been disconnected)"
    }
}

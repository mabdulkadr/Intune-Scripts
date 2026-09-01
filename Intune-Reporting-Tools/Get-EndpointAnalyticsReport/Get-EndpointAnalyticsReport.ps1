<#
.TITLE
    Endpoint Analytics Report

.SYNOPSIS
    Generate comprehensive Endpoint Analytics reports from Microsoft Intune including startup performance, application reliability, battery health, and work from anywhere metrics.

.DESCRIPTION
    This script connects to Microsoft Graph API (beta) and retrieves Endpoint Analytics data from Intune.
    It collects metrics across multiple categories including device startup performance, application reliability,
    battery health, work from anywhere readiness, and overall device scores. Results are exported to CSV and HTML
    formats for analysis and reporting purposes.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Monitoring,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.4.1

.CHANGELOG
    1.4.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.4 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.2 - The ShowProgress switch now drives Write-Progress during metric collection; analytics queries project only the fields the report consumes; output directory is created automatically before exports; pagination helper keeps single-item results as arrays
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing); work from anywhere metrics now use the allDevices metricDevices endpoint
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-endpoint-analytics-report.ps1
    Generates a complete Endpoint Analytics report with all metrics

.EXAMPLE
    .\get-endpoint-analytics-report.ps1 -OutputPath "C:\Reports" -IncludeStartupPerformance "true"
    Generates report with only startup performance metrics

.EXAMPLE
    .\get-endpoint-analytics-report.ps1 -IncludeAll "true" -ExportJson "true"
    Generates report with all metrics and exports to both CSV and JSON formats

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Uses Microsoft Graph Beta API endpoints
    - Some features require Intune Advanced Analytics license
    - Battery Health metrics require Windows 10/11 devices
    - Endpoint Analytics must be enabled in Intune
    - Documentation: https://learn.microsoft.com/en-us/intune/analytics/overview
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Directory path to save reports")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Include startup performance metrics")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeStartupPerformance,

    [Parameter(Mandatory = $false, HelpMessage = "Include application reliability metrics")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeAppReliability,

    [Parameter(Mandatory = $false, HelpMessage = "Include battery health metrics")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeBatteryHealth,

    [Parameter(Mandatory = $false, HelpMessage = "Include work from anywhere metrics")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeWorkFromAnywhere,

    [Parameter(Mandatory = $false, HelpMessage = "Include all available metrics")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeAll,

    [Parameter(Mandatory = $false, HelpMessage = "Export results in JSON format as well")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportJson,

    [Parameter(Mandatory = $false, HelpMessage = "Show progress during processing")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ShowProgress,

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
        [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Tenant ID for app-only authentication")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Client ID for app-only authentication")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
)

$ErrorActionPreference = 'Stop'

# Normalize the module-install override parameter.
$forceModuleInstallRaw = [string]$ForceModuleInstall
Remove-Variable -Name ForceModuleInstall -ErrorAction SilentlyContinue
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

# Normalize boolean string parameters so
# workstation execution uses consistent boolean types.
foreach ($boolParamName in @('IncludeStartupPerformance', 'IncludeAppReliability', 'IncludeBatteryHealth', 'IncludeWorkFromAnywhere', 'IncludeAll', 'ExportJson', 'ShowProgress')) {
    $boolRaw = [string](Get-Variable -Name $boolParamName -ValueOnly)
    Remove-Variable -Name $boolParamName -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($boolRaw)) {
        Set-Variable -Name $boolParamName -Value $false
        continue
    }

    switch ($boolRaw.Trim().ToLowerInvariant()) {
        { $_ -in @("true", "1", '$true') } {
            Set-Variable -Name $boolParamName -Value $true
        }
        { $_ -in @("false", "0", '$false') } {
            Set-Variable -Name $boolParamName -Value $false
        }
        default {
            throw "Parameter '$boolParamName' accepts only true, false, 1, 0, $true, or $false."
        }
    }
}

# If no specific category is selected, include all by default
if (-not ($IncludeStartupPerformance -or $IncludeAppReliability -or $IncludeBatteryHealth -or $IncludeWorkFromAnywhere -or $IncludeAll)) {
    $IncludeAll = $true
}

# If IncludeAll is set, enable all categories
if ($IncludeAll) {
    $IncludeStartupPerformance = $true
    $IncludeAppReliability = $true
    $IncludeBatteryHealth = $true
    $IncludeWorkFromAnywhere = $true
}

# ============================================================================
# CONFIGURATION - solution identity used by the logging helpers.
# ============================================================================

$SolutionName = 'get-endpoint-analytics-report'
$ScriptMode   = 'run'

# Anchor the default report location beside this script (Enterprise Law 12):
# dot-sourcing can leave $PSScriptRoot empty, so fall back through PSCommandPath,
# MyInvocation, and finally the current directory.
$scriptBase = if ($PSScriptRoot) {
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

if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $OutputPath = Join-Path $scriptBase 'Reports'
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
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }
                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "[OK] Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }
        try {
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Verbose "[OK] Successfully imported '$ModuleName'"
        }
        catch {
            throw "Failed to import module '$ModuleName': $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# ENVIRONMENT AND MODULES - Workstation only
# ============================================================================

$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "MgGraphCommunity"
)

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "[OK] All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# AUTHENTICATION - Workstation (interactive) and unattended app-only
# ============================================================================

try {
    if ($TenantId -and $ClientId -and $ClientSecret) {
        Write-Output "Connecting to Microsoft Graph with client secret..."
        $secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $secureSecret -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
    elseif ($TenantId -and $ClientId -and $CertificateThumbprint) {
        Write-Output "Connecting to Microsoft Graph with certificate..."
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementManagedDevices.Read.All"
        )
        if (Get-Command -Name Connect-MgGraphCommunity -ErrorAction SilentlyContinue) {
            Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}
# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-MgGraphAllPages {
    param(
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $allResults = @()
    $nextLink = $Uri
    $requestCount = 0

    do {
        try {
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

            $nextLink = $response.'@odata.nextLink'

            if ($requestCount % 10 -eq 0) {
                Write-Verbose "Processed $requestCount requests..."
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

    # Comma prevents unrolling so single-element results stay arrays
    return , $allResults
}

function Get-SafeAverage {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Property,

        [double]$Divisor = 1
    )

    $numericValues = @(
        foreach ($item in $InputObject) {
            $propertyValue = $item.PSObject.Properties[$Property].Value
            if ($null -ne $propertyValue -and $propertyValue -is [System.IConvertible]) {
                try { [double]$propertyValue } catch { continue }
            }
        }
    )

    if ($numericValues.Count -eq 0) { return 0 }
    return [math]::Round(($numericValues | Measure-Object -Average).Average / $Divisor, 1)
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Endpoint Analytics report generation started" -Level 'INFO'

    Write-Output "Starting Endpoint Analytics report generation..."

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $allMetrics = @{}

    # Device Scores - Always collect for overview
    Write-Output "Retrieving device scores..."
    if ($ShowProgress) {
        Write-Progress -Activity "Endpoint Analytics Report" -Status "Retrieving device scores" -PercentComplete 10
    }
    try {
        $deviceScoresUri = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsDeviceScores?`$select=id,deviceName,model,endpointAnalyticsScore,startupPerformanceScore,appReliabilityScore,batteryHealthScore"
        $deviceScores = Get-MgGraphAllPages -Uri $deviceScoresUri
        $allMetrics['DeviceScores'] = $deviceScores
        Write-Output "✓ Retrieved $($deviceScores.Count) device score records"
    }
    catch {
        Write-Log -Message "Failed to retrieve device scores: $($_.Exception.Message)" -Level 'WARNING'
        Write-Warning "Failed to retrieve device scores: $($_.Exception.Message)"
        $allMetrics['DeviceScores'] = @()
    }

    # Startup Performance
    if ($IncludeStartupPerformance) {
        Write-Output "Retrieving startup performance metrics..."
        if ($ShowProgress) {
            Write-Progress -Activity "Endpoint Analytics Report" -Status "Retrieving startup performance metrics" -PercentComplete 30
        }
        try {
            $startupHistoryUri = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsDeviceStartupHistory"
            $startupHistory = Get-MgGraphAllPages -Uri $startupHistoryUri
            $allMetrics['StartupHistory'] = $startupHistory
            Write-Output "✓ Retrieved $($startupHistory.Count) startup history records"

            $devicePerformanceUri = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsDevicePerformance?`$select=id,deviceName,model,manufacturer,coreBootTimeInMs,groupPolicyBootTimeInMs"
            $devicePerformance = Get-MgGraphAllPages -Uri $devicePerformanceUri
            $allMetrics['DevicePerformance'] = $devicePerformance
            Write-Output "✓ Retrieved $($devicePerformance.Count) device performance records"
        }
        catch {
            Write-Log -Message "Failed to retrieve startup performance: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Failed to retrieve startup performance: $($_.Exception.Message)"
            $allMetrics['StartupHistory'] = @()
            $allMetrics['DevicePerformance'] = @()
        }
    }

    # Application Reliability
    if ($IncludeAppReliability) {
        Write-Output "Retrieving application reliability metrics..."
        if ($ShowProgress) {
            Write-Progress -Activity "Endpoint Analytics Report" -Status "Retrieving application reliability metrics" -PercentComplete 50
        }
        try {
            $appHealthDeviceUri = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsAppHealthDevicePerformanceDetails"
            $appHealthDevice = Get-MgGraphAllPages -Uri $appHealthDeviceUri
            $allMetrics['AppHealthDevice'] = $appHealthDevice
            Write-Output "✓ Retrieved $($appHealthDevice.Count) app health device records"

            $appHealthAppUri = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsAppHealthApplicationPerformance?`$select=appDisplayName,appCrashCount,activeDeviceCount"
            $appHealthApp = Get-MgGraphAllPages -Uri $appHealthAppUri
            $allMetrics['AppHealthApplication'] = $appHealthApp
            Write-Output "✓ Retrieved $($appHealthApp.Count) app health application records"
        }
        catch {
            Write-Log -Message "Failed to retrieve application reliability: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Failed to retrieve application reliability: $($_.Exception.Message)"
            $allMetrics['AppHealthDevice'] = @()
            $allMetrics['AppHealthApplication'] = @()
        }
    }

    # Battery Health
    if ($IncludeBatteryHealth) {
        Write-Output "Retrieving battery health metrics..."
        if ($ShowProgress) {
            Write-Progress -Activity "Endpoint Analytics Report" -Status "Retrieving battery health metrics" -PercentComplete 70
        }
        try {
            $batteryOsUri = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsBatteryHealthOsPerformance"
            $batteryOs = Get-MgGraphAllPages -Uri $batteryOsUri
            $allMetrics['BatteryOsPerformance'] = $batteryOs
            Write-Output "✓ Retrieved $($batteryOs.Count) battery OS performance records"

            $batteryDeviceUri = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsBatteryHealthDevicePerformance?`$select=id,deviceName,model,deviceBatteryHealthScore,maxCapacityPercentage,batteryAgeInDays"
            $batteryDevice = Get-MgGraphAllPages -Uri $batteryDeviceUri
            $allMetrics['BatteryDevicePerformance'] = $batteryDevice
            Write-Output "✓ Retrieved $($batteryDevice.Count) battery device performance records"
        }
        catch {
            Write-Log -Message "Failed to retrieve battery health: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Failed to retrieve battery health: $($_.Exception.Message)"
            $allMetrics['BatteryOsPerformance'] = @()
            $allMetrics['BatteryDevicePerformance'] = @()
        }
    }

    # Work From Anywhere
    if ($IncludeWorkFromAnywhere) {
        Write-Output "Retrieving work from anywhere metrics..."
        if ($ShowProgress) {
            Write-Progress -Activity "Endpoint Analytics Report" -Status "Retrieving work from anywhere metrics" -PercentComplete 90
        }
        try {
            $wfaUri = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsWorkFromAnywhereMetrics('allDevices')/metricDevices"
            $wfaMetrics = Get-MgGraphAllPages -Uri $wfaUri
            $allMetrics['WorkFromAnywhere'] = $wfaMetrics
            Write-Output "✓ Retrieved $($wfaMetrics.Count) work from anywhere records"
        }
        catch {
            Write-Log -Message "Failed to retrieve work from anywhere metrics: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Failed to retrieve work from anywhere metrics: $($_.Exception.Message)"
            $allMetrics['WorkFromAnywhere'] = @()
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Endpoint Analytics Report" -Completed
    }

    # Create output directory if it does not exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Output "Created output directory: $OutputPath"
    }

    # Export results to CSV
    Write-Output "Exporting results to CSV..."

    foreach ($key in $allMetrics.Keys) {
        if ($allMetrics[$key].Count -gt 0) {
            $csvPath = Join-Path $OutputPath "EndpointAnalytics_${key}_$timestamp.csv"
            try {
                $allMetrics[$key] | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
                Write-Output "✓ Exported $key to: $csvPath"
            }
            catch {
                Write-Log -Message "Failed to export $key to CSV: $($_.Exception.Message)" -Level 'WARNING'
                Write-Warning "Failed to export $key to CSV: $($_.Exception.Message)"
            }
        }
    }

    # Export to JSON if requested
    if ($ExportJson) {
        Write-Output "Exporting results to JSON..."
        foreach ($key in $allMetrics.Keys) {
            if ($allMetrics[$key].Count -gt 0) {
                $jsonPath = Join-Path $OutputPath "EndpointAnalytics_${key}_$timestamp.json"
                try {
                    $allMetrics[$key] | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding utf8
                    Write-Output "✓ Exported $key to: $jsonPath"
                }
                catch {
                    Write-Log -Message "Failed to export $key to JSON: $($_.Exception.Message)" -Level 'WARNING'
                    Write-Warning "Failed to export $key to JSON: $($_.Exception.Message)"
                }
            }
        }
    }

    # Calculate Analytics and Statistics
    Write-Output "Calculating analytics statistics..."

    # Device Scores Analytics
    $avgEndpointScore = Get-SafeAverage -InputObject @($allMetrics['DeviceScores']) -Property 'endpointAnalyticsScore'
    $avgStartupScore = Get-SafeAverage -InputObject @($allMetrics['DeviceScores']) -Property 'startupPerformanceScore'
    $avgAppReliabilityScore = Get-SafeAverage -InputObject @($allMetrics['DeviceScores']) -Property 'appReliabilityScore'

    # Startup Performance Analytics
    $slowBootDevices = @()
    $avgBootTime = 0
    if ($IncludeStartupPerformance -and $allMetrics['DevicePerformance'].Count -gt 0) {
        # Calculate total boot time (core + group policy)
        $bootTimeRecords = @(
            $allMetrics['DevicePerformance'] | ForEach-Object {
                [pscustomobject]@{
                    totalBootTime = [double]$_.coreBootTimeInMs + [double]$_.groupPolicyBootTimeInMs
                }
            }
        )
        $avgBootTime = Get-SafeAverage -InputObject $bootTimeRecords -Property 'totalBootTime' -Divisor 1000
        $slowBootDevices = $allMetrics['DevicePerformance'] |
            Where-Object { ($_.coreBootTimeInMs + $_.groupPolicyBootTimeInMs) -gt 60000 } |
            Sort-Object { $_.coreBootTimeInMs + $_.groupPolicyBootTimeInMs } -Descending |
            Select-Object -First 10 deviceName, @{N='BootTimeSec';E={[math]::Round(($_.coreBootTimeInMs + $_.groupPolicyBootTimeInMs)/1000,1)}}, model, manufacturer
    }

    # App Reliability Analytics
    $topCrashingApps = @()
    if ($IncludeAppReliability -and $allMetrics['AppHealthApplication'].Count -gt 0) {
        $topCrashingApps = $allMetrics['AppHealthApplication'] |
            Where-Object { $_.appCrashCount -gt 0 } |
            Sort-Object appCrashCount -Descending |
            Select-Object -First 10 appDisplayName, appCrashCount, activeDeviceCount
    }

    # Battery Health Analytics
    $lowBatteryDevices = @()
    $avgBatteryHealth = 0
    if ($IncludeBatteryHealth -and $allMetrics['BatteryDevicePerformance'].Count -gt 0) {
        $avgBatteryHealth = Get-SafeAverage -InputObject @($allMetrics['BatteryDevicePerformance']) -Property 'deviceBatteryHealthScore'
        $lowBatteryDevices = $allMetrics['BatteryDevicePerformance'] |
            Where-Object { $_.maxCapacityPercentage -lt 60 } |
            Sort-Object maxCapacityPercentage |
            Select-Object -First 10 deviceName, maxCapacityPercentage, batteryAgeInDays, model
    }

    # Generate HTML Summary Report
    Write-Output "Generating HTML summary report..."

    $htmlContent =     # Startup Performance Section
    if ($IncludeStartupPerformance -and $slowBootDevices.Count -gt 0) {
        $htmlContent += @"
    <div class="top-lists">
        <div class="top-list">
            <h2>Startup Performance</h2>
            <div class="insight-box">
                <h4>Key Insights</h4>
                <p>Average boot time: <strong>$avgBootTime seconds</strong></p>
                <p>Devices with slow boot (&gt;60s): <strong>$($slowBootDevices.Count)</strong></p>
            </div>
            <h3>Slowest Booting Devices</h3>
"@
        foreach ($device in $slowBootDevices) {
            $htmlContent += @"
            <div class="top-item">
                <span>$($device.deviceName)</span>
                <span>$($device.BootTimeSec)s</span>
            </div>
"@
        }
        $htmlContent += "</div>"
    }

    # App Reliability Section
    if ($IncludeAppReliability -and $topCrashingApps.Count -gt 0) {
        if (-not $IncludeStartupPerformance) {
            $htmlContent += '<div class="top-lists">'
        }
        $htmlContent += @"
        <div class="top-list">
            <h2>Application Reliability</h2>
            <div class="insight-box">
                <h4>Key Insights</h4>
                <p>Applications monitored: <strong>$($allMetrics['AppHealthApplication'].Count)</strong></p>
                <p>Apps with crashes: <strong>$($topCrashingApps.Count)</strong></p>
            </div>
            <h3>Top Crashing Applications</h3>
"@
        foreach ($app in $topCrashingApps) {
            $htmlContent += @"
            <div class="top-item">
                <span>$($app.appDisplayName)</span>
                <span>$($app.appCrashCount) crashes</span>
            </div>
"@
        }
        $htmlContent += "</div>"
        if ($IncludeStartupPerformance -or (-not $IncludeBatteryHealth)) {
            $htmlContent += "</div>"
        }
    }

    # Battery Health Section
    if ($IncludeBatteryHealth -and $lowBatteryDevices.Count -gt 0) {
        if (-not ($IncludeStartupPerformance -or $IncludeAppReliability)) {
            $htmlContent += '<div class="top-lists">'
        }
        $htmlContent += @"
        <div class="top-list">
            <h2>Battery Health</h2>
            <div class="insight-box">
                <h4>Key Insights</h4>
                <p>Devices monitored: <strong>$($allMetrics['BatteryDevicePerformance'].Count)</strong></p>
                <p>Devices with low battery (&lt;60%): <strong>$($lowBatteryDevices.Count)</strong></p>
            </div>
            <h3>Devices Needing Battery Replacement</h3>
"@
        foreach ($device in $lowBatteryDevices) {
            $htmlContent += @"
            <div class="top-item">
                <span>$($device.deviceName)</span>
                <span>$($device.maxCapacityPercentage)% capacity</span>
            </div>
"@
        }
        $htmlContent += "</div></div>"
    }

    # Detailed Device Scores Table
    if ($allMetrics['DeviceScores'].Count -gt 0) {
        $htmlContent += @"
    <div class="section">
        <h2>Detailed Device Scores</h2>
        <table>
            <thead>
                <tr>
                    <th>Device Name</th>
                    <th>Model</th>
                    <th>Endpoint Score</th>
                    <th>Startup Score</th>
                    <th>App Reliability</th>
                    <th>Battery Health</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
"@
        foreach ($device in $allMetrics['DeviceScores'] | Sort-Object deviceName) {
            $status = if ($device.endpointAnalyticsScore -ge 70) { "<span class='metric-badge badge-good'>Good</span>" }
                      elseif ($device.endpointAnalyticsScore -ge 50) { "<span class='metric-badge badge-warning'>Fair</span>" }
                      else { "<span class='metric-badge badge-bad'>Poor</span>" }

            $htmlContent += @"
                <tr>
                    <td>$($device.deviceName)</td>
                    <td>$($device.model)</td>
                    <td>$($device.endpointAnalyticsScore)</td>
                    <td>$($device.startupPerformanceScore)</td>
                    <td>$($device.appReliabilityScore)</td>
                    <td>$($device.batteryHealthScore)</td>
                    <td>$status</td>
                </tr>
"@
        }
        $htmlContent += @"
            </tbody>
        </table>
    </div>
"@
    }

    $htmlContent += @"
    <div class="footer">Report generated by Endpoint Analytics Script v1.0</div>
</body>
</html>
"@

    $htmlPath = Join-Path $OutputPath "EndpointAnalytics_Summary_$timestamp.html"
    try {
        $htmlContent | Out-File -FilePath $htmlPath -Encoding utf8
        Write-Output "✓ HTML summary report saved: $htmlPath"
    }
    catch {
        Write-Log -Message "Failed to generate HTML report: $($_.Exception.Message)" -Level 'WARNING'
        Write-Warning "Failed to generate HTML report: $($_.Exception.Message)"
    }

    Write-Output "`n✓ Endpoint Analytics report generation completed successfully!"
    Write-Output "Reports saved to: $OutputPath"
    Write-Log -Message "Endpoint Analytics report generation completed successfully - reports saved to: $OutputPath" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    try {
        Disconnect-MgGraph | Out-Null
        Write-Output "✓ Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Graph disconnection completed (may have already been disconnected)"
    }
}

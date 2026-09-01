<#
.TITLE
    Device Compliance Report

.SYNOPSIS
    Generate a comprehensive device compliance report for managed devices in Intune.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves managed devices and their compliance status,
    and generates a detailed report in both CSV and HTML formats. The report includes device details,
    compliance status, and summary statistics.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Devices,Compliance,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All,DeviceManagementConfiguration.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.4.1

.CHANGELOG
    1.4.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.4 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.2 - Managed device query now requests only the fields used by the report; output directory is created automatically when missing; per-device policy state calls are spaced with a short delay to reduce throttling; policy-state and summary counts are wrapped in @() so single-result queries report accurate totals; progress bar output is suppressed in Azure Automation
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing); report auto-open failures no longer abort the script
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-device-compliance-report.ps1
    Generates compliance reports for all managed devices

.EXAMPLE
    .\get-device-compliance-report.ps1 -OutputPath "C:\Reports"
    Generates reports and saves them to the specified directory

.EXAMPLE
    .\get-device-compliance-report.ps1 -ForceModuleInstall "true"
    Generates reports and forces module installation without prompting

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Large tenants may take several minutes to complete
    - Reports are saved in both CSV and HTML formats
    - Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
    - Logs: %ProgramData%\get-device-compliance-report\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Output directory for the reports")]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Open the HTML report after generation")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$OpenReport,

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

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-device-compliance-report'
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
# REPORT OUTPUT ANCHORING (Law 12)
# Anchor relative output paths beside the script so CSV/HTML exports always
# land in a predictable location regardless of the caller's current directory.
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

if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = [System.IO.Path]::GetFullPath((Join-Path $scriptDirectory $OutputPath))
}

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
foreach ($boolParamName in @('OpenReport')) {
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
        Write-Log -Message "Connected to Microsoft Graph with client secret" -Level 'SUCCESS'
    }
    elseif ($TenantId -and $ClientId -and $CertificateThumbprint) {
        Write-Output "Connecting to Microsoft Graph with certificate..."
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
        Write-Log -Message "Connected to Microsoft Graph with certificate" -Level 'SUCCESS'
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementManagedDevices.Read.All",
            "DeviceManagementConfiguration.Read.All"
        )
        if (Get-Command -Name Connect-MgGraphCommunity -ErrorAction SilentlyContinue) {
            Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "[OK] Successfully connected to Microsoft Graph"
        Write-Log -Message "Connected to Microsoft Graph with interactive authentication" -Level 'SUCCESS'
    }
}
catch {
    Write-Log -Message "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}
# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to get all pages of results from Graph API
function Get-MgGraphAllPages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $AllResults = @()
    $NextLink = $Uri
    $RequestCount = 0

    do {
        try {
            # Add delay to respect rate limits
            if ($RequestCount -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $Response = Invoke-MgGraphRequest -Uri $NextLink -Method GET
            $RequestCount++

            if ($null -ne $Response.value) {
                $AllResults += $Response.value
            }
            else {
                $AllResults += $Response
            }

            $NextLink = $Response.'@odata.nextLink'
        }
        catch {
            # HTTP 429 / throttling backs off for 60 seconds and retries; anything else is terminal.
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                Write-Log -Message "Rate limit hit - pausing pagination for 60 seconds" -Level 'WARNING'
                Write-Information "`nRate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            # Non-throttle failures are terminating so callers see real paging errors.
            Write-Log -Message "Pagination failed for ${NextLink}: $($_.Exception.Message)" -Level 'ERROR'
            throw "Error fetching data from $NextLink : $($_.Exception.Message)"
        }
    } while ($NextLink)

    return $AllResults
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Starting device compliance report generation..."
    Write-Log -Message "Starting device compliance report generation" -Level 'INFO'

    # Get all managed devices (only the fields used by the report)
    Write-Output "Retrieving managed devices..."
    $deviceSelect = "id,deviceName,userPrincipalName,userDisplayName,operatingSystem,osVersion,model,manufacturer,serialNumber,lastSyncDateTime,enrolledDateTime,managementState,managedDeviceOwnerType,complianceGracePeriodExpirationDateTime"
    $devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=$deviceSelect"
    Write-Output "✓ Found $($devices.Count) managed devices"
    Write-Log -Message "Found $($devices.Count) managed devices" -Level 'INFO'

    # Get compliance policies
    try {
        Write-Output "Retrieving compliance policies..."
        $compliancePolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies"
        Write-Output "✓ Found $($compliancePolicies.Count) compliance policies"
        Write-Log -Message "Found $($compliancePolicies.Count) compliance policies" -Level 'INFO'
    }
    catch {
        # Policy inventory is best-effort - an empty list keeps the report moving.
        Write-Log -Message "Could not retrieve compliance policies: $($_.Exception.Message)" -Level 'WARNING'
        Write-Warning "Could not retrieve compliance policies: $($_.Exception.Message)"
        $compliancePolicies = @()
    }

    # Create report array
    $report = @()
    $processedCount = 0

    Write-Output "Processing device compliance data..."

    foreach ($device in $devices) {
        $processedCount++
                    Write-Progress -Activity "Processing Devices" -Status "Processing device $processedCount of $($devices.Count)" -PercentComplete (($processedCount / $devices.Count) * 100)

        try {
            # Space out per-device calls to reduce throttling
            Start-Sleep -Milliseconds 100

            # Get device compliance details
            $complianceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($device.id)')/deviceCompliancePolicyStates"
            $deviceCompliance = Get-MgGraphAllPages -Uri $complianceUri

            # Calculate compliance summary
            $compliantPolicies = @($deviceCompliance | Where-Object { $_.state -eq "compliant" }).Count
            $nonCompliantPolicies = @($deviceCompliance | Where-Object { $_.state -eq "nonCompliant" }).Count
            $errorPolicies = @($deviceCompliance | Where-Object { $_.state -eq "error" }).Count
            $totalPolicies = @($deviceCompliance).Count

            # Determine overall compliance status
            $overallCompliance = if ($nonCompliantPolicies -gt 0 -or $errorPolicies -gt 0) {
                "Non-Compliant"
            }
            elseif ($compliantPolicies -gt 0) {
                "Compliant"
            }
            else {
                "Unknown"
            }

            # Calculate days since last sync
            $daysSinceSync = if ($device.lastSyncDateTime) {
                [math]::Round(((Get-Date) - [DateTime]$device.lastSyncDateTime).TotalDays, 1)
            }
            else {
                "Never"
            }

            # Create device report object
            $deviceInfo = [PSCustomObject]@{
                DeviceName                              = $device.deviceName
                UserPrincipalName                       = $device.userPrincipalName
                UserDisplayName                         = $device.userDisplayName
                OperatingSystem                         = $device.operatingSystem
                OSVersion                               = $device.osVersion
                Model                                   = $device.model
                Manufacturer                            = $device.manufacturer
                SerialNumber                            = $device.serialNumber
                OverallCompliance                       = $overallCompliance
                CompliantPolicies                       = $compliantPolicies
                NonCompliantPolicies                    = $nonCompliantPolicies
                ErrorPolicies                           = $errorPolicies
                TotalPolicies                           = $totalPolicies
                LastSyncDateTime                        = $device.lastSyncDateTime
                DaysSinceLastSync                       = $daysSinceSync
                EnrolledDateTime                        = $device.enrolledDateTime
                ManagementState                         = $device.managementState
                OwnerType                               = $device.managedDeviceOwnerType
                ComplianceGracePeriodExpirationDateTime = $device.complianceGracePeriodExpirationDateTime
                DeviceId                                = $device.id
            }

            $report += $deviceInfo

        }
        catch {
            # A single bad device must not abort the whole report - log and continue.
            Write-Log -Message "Error processing device $($device.deviceName): $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Error processing device $($device.deviceName): $($_.Exception.Message)"
        }
    }

            Write-Progress -Activity "Processing Devices" -Completed

    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Generate timestamp for file names
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $csvPath = Join-Path $OutputPath "Intune_Device_Compliance_Report_$timestamp.csv"
    $htmlPath = Join-Path $OutputPath "Intune_Device_Compliance_Report_$timestamp.html"

    # Export to CSV
    try {
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "✓ CSV report saved: $csvPath"
        Write-Log -Message "CSV report saved: $csvPath" -Level 'SUCCESS'
    }
    catch {
        # CSV failure is reported but does not prevent the HTML report from rendering.
        Write-Log -Message "Failed to save CSV report: $($_.Exception.Message)" -Level 'ERROR'
        Write-Error "Failed to save CSV report: $($_.Exception.Message)"
    }

    # Generate HTML report
    try {
        $htmlContent =         # Add table
        $htmlContent += "<table><thead><tr>"
        $htmlContent += "<th>Device Name</th><th>User</th><th>OS</th><th>Compliance Status</th><th>Compliant Policies</th><th>Non-Compliant Policies</th><th>Last Sync</th><th>Days Since Sync</th>"
        $htmlContent += "</tr></thead><tbody>"

        foreach ($device in $report | Sort-Object DeviceName) {
            $complianceClass = switch ($device.OverallCompliance) {
                "Compliant" { "compliant" }
                "Non-Compliant" { "non-compliant" }
                default { "unknown" }
            }

            $htmlContent += "<tr>"
            $htmlContent += "<td>$($device.DeviceName)</td>"
            $htmlContent += "<td>$($device.UserDisplayName)</td>"
            $htmlContent += "<td>$($device.OperatingSystem) $($device.OSVersion)</td>"
            $htmlContent += "<td class='$complianceClass'>$($device.OverallCompliance)</td>"
            $htmlContent += "<td>$($device.CompliantPolicies)</td>"
            $htmlContent += "<td>$($device.NonCompliantPolicies)</td>"
            $htmlContent += "<td>$($device.LastSyncDateTime)</td>"
            $htmlContent += "<td>$($device.DaysSinceLastSync)</td>"
            $htmlContent += "</tr>"
        }

        $htmlContent += "</tbody></table>"
        $htmlContent += "<div class='footer'>Report generated by Intune Device Compliance Script v1.0</div>"
        $htmlContent += "</body></html>"

        $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
        Write-Output "✓ HTML report saved: $htmlPath"
        Write-Log -Message "HTML report saved: $htmlPath" -Level 'SUCCESS'

        if ($OpenReport) {
            try {
                Start-Process $htmlPath
            }
            catch {
                # Auto-open is convenience only - never fatal to the report run.
                Write-Log -Message "Could not open the report automatically: $($_.Exception.Message)" -Level 'WARNING'
                Write-Warning "Could not open the report automatically: $($_.Exception.Message)"
            }
        }

    }
    catch {
        # HTML rendering failed - CSV export has already been attempted independently.
        Write-Log -Message "Failed to generate HTML report: $($_.Exception.Message)" -Level 'ERROR'
        Write-Error "Failed to generate HTML report: $($_.Exception.Message)"
    }

    # Display summary
    Write-Output "`n"
    Write-Output "📊 COMPLIANCE REPORT SUMMARY"
    Write-Output "================================"
    Write-Output "Total Devices: $($report.Count)"
    Write-Output "Compliant Devices: $(@($report | Where-Object { $_.OverallCompliance -eq 'Compliant' }).Count)"
    Write-Output "Non-Compliant Devices: $(@($report | Where-Object { $_.OverallCompliance -eq 'Non-Compliant' }).Count)"
    Write-Output "Unknown Status: $(@($report | Where-Object { $_.OverallCompliance -eq 'Unknown' }).Count)"
    Write-Output "Stale Devices (>7 days): $(@($report | Where-Object { $_.DaysSinceLastSync -ne 'Never' -and [double]$_.DaysSinceLastSync -gt 7 }).Count)"

    Write-Output "`nReports saved to:"
    Write-Output "📄 CSV: $csvPath"
    Write-Output "🌐 HTML: $htmlPath"

    Write-Output "`n🎉 Device compliance report generation completed successfully!"
    Write-Log -Message "Device compliance report generation completed successfully" -Level 'SUCCESS'
}
catch {
    # Fatal error - log it, surface it on the error stream, and exit non-zero.
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Microsoft Graph
    try {
        Disconnect-MgGraph | Out-Null
        Write-Output "✓ Disconnected from Microsoft Graph"
    }
    catch {
        # Ignore disconnection errors - this is expected behavior when already disconnected
        Write-Verbose "Graph disconnection completed (may have already been disconnected)"
        Write-Log -Message "Graph disconnection completed (may have already been disconnected)" -Level 'DEBUG'
    }
}

<#
.TITLE
    Multi-Admin Approval Compliance Dashboard Report

.SYNOPSIS
    Generate comprehensive compliance reports on Multi-Admin Approval (MAA) usage and coverage in Intune.

.DESCRIPTION
    This script connects to Microsoft Graph and analyzes Multi-Admin Approval configurations, usage patterns,
    and compliance metrics across your Intune environment. It generates detailed reports showing MAA coverage
    gaps, approval statistics, admin permissions, and trends. The script helps organizations ensure proper
    implementation of MAA controls and identify areas for security improvement. Reports are generated in
    both HTML and CSV formats for different audiences.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Compliance,Reporting,Security,MAA,Governance

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementApps.Read.All,DeviceManagementManagedDevices.Read.All,DeviceManagementRBAC.Read.All,DeviceManagementScripts.Read.All,Directory.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.5.1

.CHANGELOG
    1.5.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.5 - Declare and request DeviceManagementScripts.Read.All for platform-script inventory
    1.4 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.2 - Approver status is now resolved from MAA policy approver groups (transitive membership) to populate IsApprover, ApproversCount and AdminsWithoutMAA; resource coverage table computes per-category protected counts from MAA policy types instead of a hardcoded zero; role assignment group members are resolved via transitiveMembers; resource list calls request only the fields used; single-result Graph collections are wrapped in @() so counts are accurate; unused -DetailedAnalysis switch and AuditLog.Read.All permission removed
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing); report auto-open failures no longer abort the script; device management scripts are queried via the beta endpoint and approvers are resolved by enumerating role assignment group members
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-maa-compliance-report.ps1
    Generates MAA compliance reports in current directory with default 30-day analysis period

.EXAMPLE
    .\get-maa-compliance-report.ps1 -OutputPath "C:\Reports" -DaysToAnalyze 90
    Generates reports with 90-day analysis period and saves to specified directory

.EXAMPLE
    .\get-maa-compliance-report.ps1 -OutputPath "C:\Reports" -IncludeRecommendations "true"
    Generates detailed reports with security recommendations

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Supports both local execution and Azure Automation Runbook environments
    - Generates both HTML dashboard and CSV data exports
    - HTML report includes charts and visualizations
    - CSV exports enable further analysis in Excel or Power BI
    - Consider running monthly for compliance tracking
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
    - Logs: %ProgramData%\get-maa-compliance-report\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Directory path to save reports")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Number of days to analyze for historical data")]
    [ValidateRange(1, 365)]
    [int]$DaysToAnalyze = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Include detailed security recommendations")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeRecommendations,

    [Parameter(Mandatory = $false, HelpMessage = "Export individual CSV files for each section")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportDetailedCSV,

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

$SolutionName = 'get-maa-compliance-report'
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
foreach ($boolParamName in @('IncludeRecommendations', 'ExportDetailedCSV')) {
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
# MODULES AND AUTHENTICATION
# ============================================================================

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
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementApps.Read.All",
            "DeviceManagementManagedDevices.Read.All",
            "DeviceManagementRBAC.Read.All",
            "DeviceManagementScripts.Read.All",
            "Directory.Read.All"
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
                Write-Information "Rate limit hit, waiting 60 seconds..." -InformationAction Continue
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

# Function to get MAA policies
function Get-MAAPolicy {
    try {
        Write-Information "Retrieving MAA policies..." -InformationAction Continue

        $Uri = "https://graph.microsoft.com/beta/deviceManagement/operationApprovalPolicies"
        $Policies = Get-MgGraphAllPages -Uri $Uri

        Write-Information "✓ Found $($Policies.Count) MAA policies" -InformationAction Continue
        Write-Log -Message "Found $($Policies.Count) MAA policies" -Level 'INFO'
        return $Policies
    }
    catch {
        # Policy inventory is best-effort - an empty result keeps the dashboard renderable.
        Write-Log -Message "Could not retrieve MAA policies: $($_.Exception.Message)" -Level 'WARNING'
        Write-Warning "Could not retrieve MAA policies: $($_.Exception.Message)"
        return @()
    }
}

# Function to get all MAA requests
function Get-MAARequest {
    param(
        [int]$DaysBack
    )

    try {
        Write-Information "Retrieving MAA requests from last $DaysBack days..." -InformationAction Continue

        $Uri = "https://graph.microsoft.com/beta/deviceManagement/operationApprovalRequests"
        $AllRequests = Get-MgGraphAllPages -Uri $Uri

        # Filter by date range
        $StartDate = (Get-Date).AddDays(-$DaysBack)
        $FilteredRequests = $AllRequests | Where-Object {
            $RequestDate = if ($_.requestDateTime) { [DateTime]$_.requestDateTime }
            elseif ($_.createdDateTime) { [DateTime]$_.createdDateTime }
            else { [DateTime]::MinValue }
            $RequestDate -ge $StartDate
        }

        Write-Information "✓ Found $($FilteredRequests.Count) MAA requests in the specified period" -InformationAction Continue
        Write-Log -Message "Found $($FilteredRequests.Count) MAA requests in the specified period" -Level 'INFO'
        return $FilteredRequests
    }
    catch {
        # Request history is best-effort - an empty result keeps the analytics renderable.
        Write-Log -Message "Could not retrieve MAA requests: $($_.Exception.Message)" -Level 'WARNING'
        Write-Warning "Could not retrieve MAA requests: $($_.Exception.Message)"
        return @()
    }
}

# Function to get protected resources
function Get-ProtectedResource {
    try {
        Write-Information "Identifying MAA-protectable resources..." -InformationAction Continue

        $Resources = @{
            Apps          = @()
            Scripts       = @()
            Policies      = @()
            DeviceActions = @()
            RBAC          = @()
        }

        # Get Apps
        try {
            $AppsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$select=id,displayName"
            $Apps = Get-MgGraphAllPages -Uri $AppsUri
            $Resources.Apps = @($Apps | Select-Object id, displayName, '@odata.type')
            Write-Information "  Found $($Resources.Apps.Count) applications" -InformationAction Continue
        }
        catch {
            # App inventory is best-effort per category - coverage math tolerates gaps.
            Write-Log -Message "Could not retrieve apps: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Could not retrieve apps: $($_.Exception.Message)"
        }

        # Get Scripts
        try {
            $ScriptsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts?`$select=id,displayName,fileName"
            $Scripts = Get-MgGraphAllPages -Uri $ScriptsUri
            $Resources.Scripts = @($Scripts | Select-Object id, displayName, fileName)
            Write-Information "  Found $($Resources.Scripts.Count) scripts" -InformationAction Continue
        }
        catch {
            # Script inventory is best-effort per category - coverage math tolerates gaps.
            Write-Log -Message "Could not retrieve scripts: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Could not retrieve scripts: $($_.Exception.Message)"
        }

        # Get Settings Catalog configuration policies. This is the resource the MAA
        # 'configurationPolicy' approval type actually gates, so the Policies bucket
        # must inventory configurationPolicies (beta), not the legacy deviceConfigurations
        # endpoint (which is a different, non-matching resource set).
        try {
            $PoliciesUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$select=id,name"
            $Policies = Get-MgGraphAllPages -Uri $PoliciesUri
            $Resources.Policies = @($Policies | Select-Object id, name, '@odata.type')
            Write-Information "  Found $($Resources.Policies.Count) configuration policies" -InformationAction Continue
        }
        catch {
            # Policy inventory is best-effort per category - coverage math tolerates gaps.
            Write-Log -Message "Could not retrieve policies: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Could not retrieve policies: $($_.Exception.Message)"
        }

        # Get RBAC roles
        try {
            $RBACUri = "https://graph.microsoft.com/beta/deviceManagement/roleDefinitions?`$select=id,displayName,isBuiltIn"
            $RBAC = Get-MgGraphAllPages -Uri $RBACUri
            $Resources.RBAC = @($RBAC | Select-Object id, displayName, isBuiltIn)
            Write-Information "  Found $($Resources.RBAC.Count) RBAC roles" -InformationAction Continue
        }
        catch {
            # RBAC inventory is best-effort per category - coverage math tolerates gaps.
            Write-Log -Message "Could not retrieve RBAC roles: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Could not retrieve RBAC roles: $($_.Exception.Message)"
        }

        return $Resources
    }
    catch {
        # Resource inventory failed outright - an empty map degrades the dashboard gracefully.
        Write-Log -Message "Failed to retrieve protected resources: $($_.Exception.Message)" -Level 'ERROR'
        Write-Error "Failed to retrieve protected resources: $($_.Exception.Message)"
        return @{}
    }
}

# Function to get approvers and admins
function Get-ApproverAndAdmin {
    param(
        [array]$ApproverGroupIds = @()
    )

    try {
        Write-Information "Retrieving administrators and approvers..." -InformationAction Continue

        $Admins = @()

        # Resolve approver user ids from the MAA policy approver groups (transitive membership)
        $ApproverUserIds = @{}
        foreach ($GroupId in ($ApproverGroupIds | Where-Object { $_ } | Select-Object -Unique)) {
            try {
                $ApproverMembersUri = "https://graph.microsoft.com/beta/groups/$GroupId/transitiveMembers?`$select=id,displayName,userPrincipalName"
                $ApproverMembers = Get-MgGraphAllPages -Uri $ApproverMembersUri
                foreach ($Member in @($ApproverMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' })) {
                    $ApproverUserIds[$Member.id] = $true
                }
            }
            catch {
                # Approver group resolution is best-effort - IsApprover may under-count.
                Write-Log -Message "Could not retrieve approver group members for $GroupId" -Level 'WARNING'
                Write-Warning "Could not retrieve approver group members for $GroupId"
            }
        }

        # Get Intune role assignments
        try {
            $RoleAssignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/roleAssignments"
            $RoleAssignments = Get-MgGraphAllPages -Uri $RoleAssignmentsUri

            foreach ($Assignment in $RoleAssignments) {
                # Get role definition
                $RoleUri = "https://graph.microsoft.com/beta/deviceManagement/roleDefinitions/$($Assignment.roleDefinitionId)"
                $Role = Invoke-MgGraphRequest -Uri $RoleUri -Method GET

                # Get members (Intune role assignment members are group ids, so enumerate each group)
                $Members = $Assignment.members
                foreach ($MemberId in $Members) {
                    try {
                        $GroupMembersUri = "https://graph.microsoft.com/beta/groups/$MemberId/transitiveMembers?`$select=id,displayName,userPrincipalName"
                        $GroupMembers = Get-MgGraphAllPages -Uri $GroupMembersUri

                        foreach ($User in $GroupMembers) {
                            $Admins += [PSCustomObject]@{
                                UserId            = $User.id
                                UserPrincipalName = $User.userPrincipalName
                                DisplayName       = $User.displayName
                                Role              = $Role.displayName
                                RoleId            = $Role.id
                                AssignmentId      = $Assignment.id
                                IsApprover        = $ApproverUserIds.ContainsKey($User.id)
                            }
                        }
                    }
                    catch {
                        # One unreachable group must not abort the whole member walk.
                        Write-Log -Message "Could not retrieve group members for $MemberId" -Level 'WARNING'
                        Write-Warning "Could not retrieve group members for $MemberId"
                    }
                }
            }
        }
        catch {
            # Role assignment enumeration is best-effort - admin list may be partial.
            Write-Log -Message "Could not retrieve role assignments: $($_.Exception.Message)" -Level 'WARNING'
            Write-Warning "Could not retrieve role assignments: $($_.Exception.Message)"
        }

        Write-Information "✓ Found $($Admins.Count) administrators" -InformationAction Continue
        Write-Log -Message "Found $($Admins.Count) administrators" -Level 'INFO'
        return $Admins
    }
    catch {
        # Administrator inventory failed outright - metrics degrade to zero counts.
        Write-Log -Message "Failed to retrieve administrators: $($_.Exception.Message)" -Level 'ERROR'
        Write-Error "Failed to retrieve administrators: $($_.Exception.Message)"
        return @()
    }
}

# Function to analyze MAA compliance
function Get-MAAComplianceMetric {
    param(
        [array]$Policies,
        [array]$Requests,
        [hashtable]$Resources,
        [array]$Admins
    )

    $Metrics = @{
        TotalPolicies             = $Policies.Count
        ActivePolicies            = @($Policies | Where-Object { $_.isEnabled -eq $true }).Count
        TotalRequests             = $Requests.Count
        PendingRequests           = @($Requests | Where-Object { $_.status -eq 0 -or $_.status -eq "pending" }).Count
        ApprovedRequests          = @($Requests | Where-Object { $_.status -eq 1 -or $_.status -eq "approved" }).Count
        RejectedRequests          = @($Requests | Where-Object { $_.status -eq 2 -or $_.status -eq "rejected" }).Count
        CancelledRequests         = @($Requests | Where-Object { $_.status -eq 3 -or $_.status -eq "cancelled" }).Count
        CompletedRequests         = @($Requests | Where-Object { $_.status -eq 4 -or $_.status -eq "completed" }).Count

        # Resource coverage
        TotalProtectableResources = 0
        ProtectedResources        = 0
        ProtectedByCategory       = @{}
        CoverageGaps              = @()

        # Approval metrics
        AverageApprovalTime       = 0
        MedianApprovalTime        = 0
        FastestApproval           = 0
        SlowestApproval           = 0

        # Admin metrics
        TotalAdmins               = $Admins.Count
        ApproversCount            = @($Admins | Where-Object { $_.IsApprover } | Select-Object -ExpandProperty UserId -Unique).Count
        AdminsWithoutMAA          = @($Admins | Where-Object { -not $_.IsApprover } | Select-Object -ExpandProperty UserPrincipalName -Unique)
    }

    # Calculate resource coverage
    foreach ($Category in $Resources.Keys) {
        $Metrics.TotalProtectableResources += $Resources[$Category].Count
        $Metrics.ProtectedByCategory[$Category] = 0
    }

    # Analyze policy coverage: an MAA policy protects every resource of its policy type
    # Only map policy types whose resources are actually inventoried in $Resources.
    # MAA approval is enforced per operation type (tenant-wide), so an existing
    # approval policy of a mapped type protects every resource in that category.
    # compliancePolicy/endpointSecurityPolicy/device* are intentionally omitted:
    # their resource instances are not inventoried here, so counting them against
    # the deviceConfigurations-backed 'Policies' bucket would overstate coverage.
    $PolicyTypeCategoryMap = @{
        app                 = 'Apps'
        script              = 'Scripts'
        configurationPolicy = 'Policies'
        role                = 'RBAC'
    }
    foreach ($Policy in $Policies) {
        $PolicyType = [string]$Policy.policyType
        $Category = $PolicyTypeCategoryMap[$PolicyType]
        if ($Category -and $Metrics.ProtectedByCategory.ContainsKey($Category)) {
            $Metrics.ProtectedByCategory[$Category] = @($Resources[$Category]).Count
        }
    }
    $Metrics.ProtectedResources = ($Metrics.ProtectedByCategory.Values | Measure-Object -Sum).Sum

    # Calculate approval times
    $ApprovalTimes = @()
    foreach ($Request in @($Requests | Where-Object { $_.status -eq 1 -or $_.status -eq "approved" })) {
        if ($Request.requestDateTime -and $Request.approvalDateTime) {
            $TimeDiff = ([DateTime]$Request.approvalDateTime - [DateTime]$Request.requestDateTime).TotalHours
            $ApprovalTimes += $TimeDiff
        }
    }

    if ($ApprovalTimes.Count -gt 0) {
        $Metrics.AverageApprovalTime = [Math]::Round(($ApprovalTimes | Measure-Object -Average).Average, 2)
        $Sorted = $ApprovalTimes | Sort-Object
        $Metrics.MedianApprovalTime = [Math]::Round($Sorted[$Sorted.Count / 2], 2)
        $Metrics.FastestApproval = [Math]::Round($Sorted[0], 2)
        $Metrics.SlowestApproval = [Math]::Round($Sorted[-1], 2)
    }

    # Calculate approval rate
    $TotalProcessed = $Metrics.ApprovedRequests + $Metrics.RejectedRequests
    if ($TotalProcessed -gt 0) {
        $Metrics.ApprovalRate = [Math]::Round(($Metrics.ApprovedRequests / $TotalProcessed) * 100, 2)
    }
    else {
        $Metrics.ApprovalRate = 0
    }

    # Identify coverage gaps
    if ($Metrics.TotalProtectableResources -gt 0) {
        $Metrics.CoveragePercentage = [Math]::Round(($Metrics.ProtectedResources / $Metrics.TotalProtectableResources) * 100, 2)
    }
    else {
        $Metrics.CoveragePercentage = 0
    }

    return $Metrics
}

# Function to generate HTML report
function New-HTMLReport {
    param(
        [hashtable]$Metrics,
        [array]$Policies,
        [array]$Requests,
        [hashtable]$Resources,
        [array]$Admins,
        [bool]$IncludeRecommendations
    )

    $ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $HTMLReport =     # Add resource coverage details
    foreach ($ResourceType in $Resources.Keys) {
        $Total = $Resources[$ResourceType].Count
        $Protected = if ($Metrics.ProtectedByCategory.ContainsKey($ResourceType)) { $Metrics.ProtectedByCategory[$ResourceType] } else { 0 }
        $Unprotected = $Total - $Protected
        $Coverage = if ($Total -gt 0) { [Math]::Round(($Protected / $Total) * 100, 2) } else { 0 }

        $HTMLReport += @"
                        <tr>
                            <td><strong>$ResourceType</strong></td>
                            <td>$Total</td>
                            <td>$Protected</td>
                            <td>$Unprotected</td>
                            <td>$Coverage%</td>
                        </tr>
"@
    }

    $HTMLReport += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Policy Status -->
        <div class="section">
            <h2>📋 MAA Policy Status</h2>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Policy Name</th>
                            <th>Status</th>
                            <th>Resource Type</th>
                            <th>Approvers</th>
                            <th>Created Date</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    # Add policy details
    foreach ($Policy in $Policies | Sort-Object -Property displayName) {
        $Status = if ($Policy.isEnabled) { "Active" } else { "Inactive" }
        $StatusClass = if ($Policy.isEnabled) { "status-active" } else { "status-inactive" }
        $CreatedDate = if ($Policy.createdDateTime) { ([DateTime]$Policy.createdDateTime).ToString("yyyy-MM-dd") } else { "N/A" }
        $ApproverCount = if ($Policy.approvers) { $Policy.approvers.Count } else { 0 }

        $HTMLReport += @"
                        <tr>
                            <td><strong>$($Policy.displayName)</strong></td>
                            <td><span class="status-badge $StatusClass">$Status</span></td>
                            <td>$($Policy.resourceType)</td>
                            <td>$ApproverCount approver(s)</td>
                            <td>$CreatedDate</td>
                        </tr>
"@
    }

    $HTMLReport += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Request Analytics -->
        <div class="section">
            <h2>📈 Request Analytics ($DaysToAnalyze Day Period)</h2>

            <div class="metrics-grid">
                <div class="metric-card">
                    <div class="metric-label">Total Requests</div>
                    <div class="metric-value">$($Metrics.TotalRequests)</div>
                </div>

                <div class="metric-card">
                    <div class="metric-label">Approved</div>
                    <div class="metric-value" style="color: #27ae60;">$($Metrics.ApprovedRequests)</div>
                </div>

                <div class="metric-card">
                    <div class="metric-label">Rejected</div>
                    <div class="metric-value" style="color: #e74c3c;">$($Metrics.RejectedRequests)</div>
                </div>

                <div class="metric-card">
                    <div class="metric-label">Pending</div>
                    <div class="metric-value" style="color: #f39c12;">$($Metrics.PendingRequests)</div>
                </div>
            </div>

            <div class="chart-container">
                <h3>Approval Time Distribution</h3>
                <ul>
                    <li>Fastest Approval: $($Metrics.FastestApproval) hours</li>
                    <li>Average Approval: $($Metrics.AverageApprovalTime) hours</li>
                    <li>Median Approval: $($Metrics.MedianApprovalTime) hours</li>
                    <li>Slowest Approval: $($Metrics.SlowestApproval) hours</li>
                </ul>
            </div>
        </div>
"@

    # Add recommendations if requested
    if ($IncludeRecommendations) {
        $HTMLReport += @"
        <!-- Recommendations -->
        <div class="section">
            <h2>🎯 Security Recommendations</h2>
"@

        # Check for critical findings
        if ($Metrics.CoveragePercentage -lt 50) {
            $HTMLReport += @"
            <div class="alert alert-danger">
                <strong>⚠️ Critical:</strong> MAA coverage is below 50%. Significant security gaps exist.
            </div>
"@
        }

        if ($Metrics.ActivePolicies -eq 0) {
            $HTMLReport += @"
            <div class="alert alert-danger">
                <strong>⚠️ Critical:</strong> No active MAA policies found. Multi-admin approval is not enforced.
            </div>
"@
        }

        if ($Metrics.AverageApprovalTime -gt 72) {
            $HTMLReport += @"
            <div class="alert alert-warning">
                <strong>⚠️ Warning:</strong> Average approval time exceeds 72 hours. Consider process improvements.
            </div>
"@
        }

        $HTMLReport += @"
            <div class="recommendation-box">
                <h3>Recommended Actions</h3>
                <ul>
                    <li>Increase MAA coverage to at least 80% for critical resources</li>
                    <li>Ensure all sensitive operations require multi-admin approval</li>
                    <li>Regularly review and update approver lists</li>
                    <li>Implement automated notifications for pending requests</li>
                    <li>Document approval policies and procedures</li>
                    <li>Conduct quarterly MAA compliance reviews</li>
                    <li>Train administrators on MAA workflows</li>
                    <li>Monitor approval times and optimize processes</li>
                </ul>
            </div>

            <div class="recommendation-box">
                <h3>Best Practices</h3>
                <ul>
                    <li>Require MAA for all production changes</li>
                    <li>Maintain minimum of 2 approvers per policy</li>
                    <li>Separate requesters from approvers (separation of duties)</li>
                    <li>Set maximum approval time SLAs</li>
                    <li>Regular audit of MAA bypasses and exceptions</li>
                    <li>Integrate MAA with change management processes</li>
                </ul>
            </div>
        </div>
"@
    }

    $HTMLReport += @"
        <div class="footer">
            <p>© 2025 MAA Compliance Report | Generated by Intune Automation Suite</p>
            <p>Report Period: Last $DaysToAnalyze days | Next Review: $(([DateTime]::Now.AddDays(30)).ToString("yyyy-MM-dd"))</p>
        </div>
    </div>

    <script>
        // Add any interactive features here
        document.addEventListener('DOMContentLoaded', function() {
            console.log('MAA Compliance Report Loaded');
        });
    </script>
</body>
</html>
"@

    return $HTMLReport
}

# Function to export to CSV
function Export-MAADataToCSV {
    param(
        [string]$OutputPath,
        [hashtable]$Metrics,
        [array]$Policies,
        [array]$Requests,
        [hashtable]$Resources,
        [array]$Admins
    )

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    # Export summary metrics
    $MetricsCSV = @()
    foreach ($Key in $Metrics.Keys) {
        $MetricsCSV += [PSCustomObject]@{
            Metric    = $Key
            Value     = $Metrics[$Key]
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    $MetricsCSV | Export-Csv -Path "$OutputPath\MAA_Metrics_$Timestamp.csv" -NoTypeInformation -Encoding utf8

    # Export policies
    if ($Policies.Count -gt 0) {
        $Policies | Select-Object displayName, isEnabled, resourceType, createdDateTime, lastModifiedDateTime, @{Name = 'ApproverCount'; Expression = { $_.approvers.Count } } |
        Export-Csv -Path "$OutputPath\MAA_Policies_$Timestamp.csv" -NoTypeInformation -Encoding utf8
    }

    # Export requests
    if ($Requests.Count -gt 0) {
        $Requests | Select-Object id, status, requestDateTime, approvalDateTime, requestor, approver, requestJustification |
        Export-Csv -Path "$OutputPath\MAA_Requests_$Timestamp.csv" -NoTypeInformation -Encoding utf8
    }

    Write-Information "✓ CSV files exported to $OutputPath" -InformationAction Continue
    Write-Log -Message "CSV files exported to $OutputPath" -Level 'SUCCESS'
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Starting MAA Compliance Dashboard Report generation..."
    Write-Output "Analysis Period: Last $DaysToAnalyze days"
    Write-Output "Output Path: $OutputPath"
    Write-Log -Message "Starting MAA Compliance Dashboard Report generation (period: last $DaysToAnalyze days)" -Level 'INFO'

    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Step 1: Gather MAA data
    $MAAPolicies = @(Get-MAAPolicy)
    $MAARequests = @(Get-MAARequest -DaysBack $DaysToAnalyze)
    $ProtectedResources = Get-ProtectedResource
    $ApproverGroupIds = @($MAAPolicies | ForEach-Object { $_.approverGroupIds } | Where-Object { $_ } | Select-Object -Unique)
    $Administrators = Get-ApproverAndAdmin -ApproverGroupIds $ApproverGroupIds

    # Step 2: Analyze compliance metrics
    $ComplianceMetrics = Get-MAAComplianceMetric -Policies $MAAPolicies -Requests $MAARequests -Resources $ProtectedResources -Admins $Administrators

    Write-Output "Analysis complete:"
    Write-Output "  - Policies: $($MAAPolicies.Count)"
    Write-Output "  - Requests: $($MAARequests.Count)"
    Write-Output "  - Coverage: $($ComplianceMetrics.CoveragePercentage)%"
    Write-Output "  - Approval Rate: $($ComplianceMetrics.ApprovalRate)%"
    Write-Log -Message "Analysis complete - Policies: $($MAAPolicies.Count) Requests: $($MAARequests.Count) Coverage: $($ComplianceMetrics.CoveragePercentage)% Approval Rate: $($ComplianceMetrics.ApprovalRate)%" -Level 'INFO'

    # Step 3: Generate HTML report
    $HTMLReport = New-HTMLReport -Metrics $ComplianceMetrics -Policies $MAAPolicies -Requests $MAARequests -Resources $ProtectedResources -Admins $Administrators -IncludeRecommendations $IncludeRecommendations

    $HTMLFileName = "MAA_Compliance_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $HTMLFullPath = Join-Path $OutputPath $HTMLFileName
    $HTMLReport | Out-File -FilePath $HTMLFullPath -Encoding UTF8

    Write-Output "✓ HTML report saved to: $HTMLFullPath"
    Write-Log -Message "HTML report saved to: $HTMLFullPath" -Level 'SUCCESS'

    # Step 4: Export CSV data if requested
    if ($ExportDetailedCSV) {
        Export-MAADataToCSV -OutputPath $OutputPath -Metrics $ComplianceMetrics -Policies $MAAPolicies -Requests $MAARequests -Resources $ProtectedResources -Admins $Administrators
    }

    # Step 5: Generate summary CSV
    $SummaryData = [PSCustomObject]@{
        ReportDate               = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        AnalysisPeriodDays       = $DaysToAnalyze
        TotalPolicies            = $ComplianceMetrics.TotalPolicies
        ActivePolicies           = $ComplianceMetrics.ActivePolicies
        CoveragePercentage       = $ComplianceMetrics.CoveragePercentage
        TotalRequests            = $ComplianceMetrics.TotalRequests
        PendingRequests          = $ComplianceMetrics.PendingRequests
        ApprovalRate             = $ComplianceMetrics.ApprovalRate
        AverageApprovalTimeHours = $ComplianceMetrics.AverageApprovalTime
        TotalAdmins              = $ComplianceMetrics.TotalAdmins
    }

    $SummaryFileName = "MAA_Summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $SummaryFullPath = Join-Path $OutputPath $SummaryFileName
    $SummaryData | Export-Csv -Path $SummaryFullPath -NoTypeInformation -Encoding utf8

    Write-Output "✓ Summary CSV saved to: $SummaryFullPath"
    Write-Log -Message "Summary CSV saved to: $SummaryFullPath" -Level 'SUCCESS'

    # Display summary
    Write-Output "
========================================
MAA Compliance Report Summary
========================================
Coverage Rate: $($ComplianceMetrics.CoveragePercentage)%
Active Policies: $($ComplianceMetrics.ActivePolicies) of $($ComplianceMetrics.TotalPolicies)
Approval Rate: $($ComplianceMetrics.ApprovalRate)%
Pending Requests: $($ComplianceMetrics.PendingRequests)
Average Approval Time: $($ComplianceMetrics.AverageApprovalTime) hours
========================================
Reports saved to: $OutputPath
========================================
"

    # Open HTML report
    Write-Output "Opening HTML report in default browser..."
    try {
        Start-Process $HTMLFullPath
    }
    catch {
        # Auto-open is convenience only - never fatal to the report run.
        Write-Log -Message "Could not open the report automatically: $($_.Exception.Message)" -Level 'WARNING'
        Write-Warning "Could not open the report automatically: $($_.Exception.Message)"
    }

    Write-Log -Message "MAA Compliance Dashboard Report generation completed successfully" -Level 'SUCCESS'
}
catch {
    # Fatal error - log it, surface it on the error stream, and exit non-zero.
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level 'DEBUG'
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Cleanup operations
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        Write-Output "Disconnected from Microsoft Graph"
    }
    catch {
        # Ignore disconnect errors - expected when no Graph session was established.
    }
}

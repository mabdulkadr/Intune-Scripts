<#
.TITLE
    Apple Token Validity Checker

.SYNOPSIS
    Monitor and report on the validity and expiration status of Apple DEP tokens and Push Notification Certificates in Intune.

.DESCRIPTION
    This script connects to Microsoft Graph and retrieves all Apple Device Enrollment Program (DEP) tokens
    and Apple Push Notification Certificates configured in Intune. It checks their validity status,
    expiration dates, and sync status to help administrators proactively manage Apple Business Manager
    integrations. The script generates detailed reports in CSV format, highlighting tokens and certificates
    that are expired, expiring soon, or have sync issues.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Monitoring

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementServiceConfig.Read.All,Mail.Send

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.5.1

.CHANGELOG
    1.5.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.5 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.4 - Added Microsoft Graph email delivery with configurable addresses and Azure Automation-compatible email enablement
    1.3 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.2 - Output directory is now created automatically before the CSV export; pagination helper keeps single-item results as arrays
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Test-AppleTokenValidity.ps1
    Generates Apple token validity reports for all DEP tokens and Push Notification Certificates

.EXAMPLE
    .\Test-AppleTokenValidity.ps1 -OutputPath "C:\Reports" -ExpirationWarningDays 60
    Generates reports with 60-day expiration warning and saves to specified directory

.EXAMPLE
    .\Test-AppleTokenValidity.ps1 -OnlyShowProblems "true" -SendEmailAlert "true" -AlertEmailAddress "<recipient-address>" -SenderUPN "<sender-upn>"
    Shows only problematic tokens and certificates and sends email alerts for critical issues

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires DeviceManagementServiceConfig.Read.All to read Apple tokens and certificates
    - Email alerts require the Mail.Send application permission and a provisioned sender mailbox
    - DEP tokens are valid for one year from creation
    - Apple Push Notification Certificates are valid for one year from creation
    - Automatic sync occurs daily, manual sync can be triggered
    - Critical for maintaining iOS/macOS device and app management
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
    - Logs: %ProgramData%\check-apple-token-validity\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Directory path to save reports")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Number of days before expiration to show warnings")]
    [ValidateRange(1, 365)]
    [int]$ExpirationWarningDays = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Only show tokens with problems")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$OnlyShowProblems,

    [Parameter(Mandatory = $false, HelpMessage = "Set to true to send email alerts for critical issues")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$SendEmailAlert = "false",

    [Parameter(Mandatory = $false, HelpMessage = "Email address to send alerts to")]
    [string]$AlertEmailAddress = "",

    [Parameter(Mandatory = $false, HelpMessage = "User principal name of the mailbox used to send alerts")]
    [string]$SenderUPN = "",

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
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'check-apple-token-validity'
$ScriptMode   = 'run'

$scriptBasePath = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path -Path $scriptBasePath -ChildPath $OutputPath
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
foreach ($boolParamName in @('OnlyShowProblems')) {
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

$SendEmailAlertEnabled = $SendEmailAlert.Trim() -in @("true", "1", '$true')

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

$RequiredModuleList = @(
    "Microsoft.Graph.Authentication",
    "MgGraphCommunity"
)

try {
    Initialize-RequiredModule -ModuleNames $RequiredModuleList -ForceInstall $ForceModuleInstall
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
            "DeviceManagementServiceConfig.Read.All"
        )
        if ($SendEmailAlertEnabled) {
            $Scopes += "Mail.Send"
        }
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

# Function to get all pages of results from Graph API
function Get-MgGraphAllPages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $AllResult = @()
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
                $AllResult += $Response.value
            }
            else {
                $AllResult += $Response
            }

            $NextLink = $Response.'@odata.nextLink'
        }
        catch {
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                Write-Information "`nRate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data from $NextLink : $($_.Exception.Message)"
        }
    } while ($NextLink)

    # Comma prevents unrolling so single-element results stay arrays
    return , $AllResult
}

# Function to determine token health status
function Get-TokenHealthStatus {
    param(
        [string]$State,
        [datetime]$ExpirationDate,
        [string]$LastSyncStatus,
        [int]$WarningDays
    )

    $DaysUntilExpiration = ($ExpirationDate - (Get-Date)).Days

    # Determine overall health
    if ($State -eq "expired" -or $DaysUntilExpiration -le 0) {
        return "Critical"
    }
    elseif ($State -eq "invalid" -or $LastSyncStatus -eq "failed") {
        return "Critical"
    }
    elseif ($DaysUntilExpiration -le $WarningDays) {
        return "Warning"
    }
    elseif ($State -eq "valid" -and $LastSyncStatus -eq "completed") {
        return "Healthy"
    }
    else {
        return "Unknown"
    }
}

# Function to format time span
function Format-TimeSpan {
    param([datetime]$Date)

    $TimeSpan = $Date - (Get-Date)

    if ($TimeSpan.TotalDays -gt 0) {
        return "$([math]::Round($TimeSpan.TotalDays)) days"
    }
    elseif ($TimeSpan.TotalDays -gt -1) {
        return "Today"
    }
    else {
        return "$([math]::Abs([math]::Round($TimeSpan.TotalDays))) days ago"
    }
}

function ConvertTo-HtmlEncodedText {
    param(
        [AllowNull()]
        [object]$Value
    )

    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Send-CriticalIssueEmail {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Issues,

        [Parameter(Mandatory = $true)]
        [string]$RecipientAddresses,

        [Parameter(Mandatory = $true)]
        [string]$SenderUserPrincipalName
    )

    $ToRecipients = @(
        $RecipientAddresses -split '[,;]' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object {
                try {
                    $ValidatedAddress = [System.Net.Mail.MailAddress]::new($_).Address
                }
                catch {
                    throw "Invalid alert email address '$_'."
                }

                @{
                    emailAddress = @{
                        address = $ValidatedAddress
                    }
                }
            }
    )

    if ($ToRecipients.Count -eq 0) {
        throw "At least one alert email address is required."
    }

    $IssueRows = foreach ($Issue in $Issues) {
        $ActionRequired = if ($Issue.State -eq "expired") {
            "Replace token immediately"
        }
        elseif ($Issue.State -eq "invalid") {
            "Check the Apple management configuration"
        }
        else {
            "Investigate synchronization issues"
        }

        @"
<tr>
    <td>$(ConvertTo-HtmlEncodedText -Value $Issue.TokenName)</td>
    <td>$(ConvertTo-HtmlEncodedText -Value $Issue.TokenType)</td>
    <td>$(ConvertTo-HtmlEncodedText -Value $Issue.State)</td>
    <td>$(ConvertTo-HtmlEncodedText -Value $Issue.ExpirationStatus)</td>
    <td>$(ConvertTo-HtmlEncodedText -Value $ActionRequired)</td>
</tr>
"@
    }

    $GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss K")
    $HtmlBody =     $MailPayload = @{
        message         = @{
            subject      = "[Critical] Intune Apple token or certificate issue"
            importance   = "high"
            body         = @{
                contentType = "HTML"
                content     = $HtmlBody
            }
            toRecipients = $ToRecipients
        }
        saveToSentItems = $true
    }

    $EncodedSenderUPN = [uri]::EscapeDataString($SenderUserPrincipalName)
    $SendMailUri = "https://graph.microsoft.com/beta/users/$EncodedSenderUPN/sendMail"
    $MailBody = $MailPayload | ConvertTo-Json -Depth 10

    Invoke-MgGraphRequest -Uri $SendMailUri -Method POST -Body $MailBody -ContentType "application/json" -ErrorAction Stop | Out-Null
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner

    Write-Output "Starting Apple token validity check..."

    if ($SendEmailAlertEnabled) {
        if ([string]::IsNullOrWhiteSpace($AlertEmailAddress)) {
            throw "AlertEmailAddress is required when SendEmailAlert is enabled."
        }
        if ([string]::IsNullOrWhiteSpace($SenderUPN)) {
            throw "SenderUPN is required when SendEmailAlert is enabled."
        }
    }

    # Initialize results arrays
    $AllTokens = @()
    $CriticalIssues = @()

    # ========================================================================
    # GET DEP TOKENS (ENROLLMENT PROGRAM TOKENS)
    # ========================================================================

    Write-Output "Retrieving Apple DEP tokens..."

    try {
        $DepTokensUri = "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings"
        $DepTokens = Get-MgGraphAllPages -Uri $DepTokensUri
        Write-Output "Retrieving $($DepTokens.Count) DEP token entries..."

        $ValidDepTokenCount = 0
        foreach ($Token in $DepTokens) {
            try {
                # Skip if essential fields are missing
                if (-not $Token.tokenExpirationDateTime -or -not $Token.id) {
                    Write-Verbose "Skipping DEP token entry with missing essential fields (ID: $($Token.id))"
                    continue
                }

                $ExpirationDate = [datetime]$Token.tokenExpirationDateTime
                $LastSyncDate = if ($Token.lastSuccessfulSyncDateTime) { [datetime]$Token.lastSuccessfulSyncDateTime } else { $null }

                # DEP tokens don't have the same state enum as VPP, so we determine state based on expiration
                $State = if ($ExpirationDate -lt (Get-Date)) { "expired" } else { "valid" }
                $LastSyncStatus = if ($Token.lastSyncErrorCode -eq 0 -or $null -eq $Token.lastSyncErrorCode) { "completed" } else { "failed" }

                $HealthStatus = Get-TokenHealthStatus -State $State -ExpirationDate $ExpirationDate -LastSyncStatus $LastSyncStatus -WarningDays $ExpirationWarningDays

                $TokenInfo = [PSCustomObject]@{
                    TokenType            = "DEP"
                    TokenName            = if ($Token.tokenName) { $Token.tokenName } else { "Unknown DEP Token" }
                    AppleId              = if ($Token.appleIdentifier) { $Token.appleIdentifier } else { "Unknown" }
                    State                = $State
                    AccountType          = if ($Token.tokenType) { $Token.tokenType } else { "Unknown" }
                    CountryRegion        = "N/A"
                    ExpirationDateTime   = $ExpirationDate
                    DaysUntilExpiration  = ($ExpirationDate - (Get-Date)).Days
                    ExpirationStatus     = Format-TimeSpan -Date $ExpirationDate
                    LastSyncDateTime     = $LastSyncDate
                    LastSyncStatus       = $LastSyncStatus
                    AutoUpdateApps       = "N/A"
                    HealthStatus         = $HealthStatus
                    TokenId              = $Token.id
                    LastModifiedDateTime = if ($Token.lastModifiedDateTime) { [datetime]$Token.lastModifiedDateTime } else { $null }
                }

                $AllTokens += $TokenInfo
                $ValidDepTokenCount++

                # Track critical issues
                if ($HealthStatus -eq "Critical") {
                    $CriticalIssues += $TokenInfo
                }
            }
            catch {
                Write-Verbose "Error processing DEP token (ID: $($Token.id)): $($_.Exception.Message)"
                continue
            }
        }

        Write-Output "[OK] Found $ValidDepTokenCount valid DEP tokens"
    }
    catch {
        Write-Warning "Failed to retrieve DEP tokens: $($_.Exception.Message)"
    }

    # ========================================================================
    # GET APPLE PUSH NOTIFICATION CERTIFICATE
    # ========================================================================

    Write-Output "Retrieving Apple Push Notification Certificate..."

    try {
        $ApnsCertUri = "https://graph.microsoft.com/beta/deviceManagement/applePushNotificationCertificate"
        $ApnsCert = Invoke-MgGraphRequest -Uri $ApnsCertUri -Method GET

        if ($ApnsCert) {
            Write-Output "[OK] Found Apple Push Notification Certificate"

            $ExpirationDate = [datetime]$ApnsCert.expirationDateTime
            $LastModifiedDate = if ($ApnsCert.lastModifiedDateTime) { [datetime]$ApnsCert.lastModifiedDateTime } else { $null }

            # Determine certificate state based on expiration and upload status
            $State = if ($ExpirationDate -lt (Get-Date)) {
                "expired"
            }
            elseif ([string]::IsNullOrEmpty($ApnsCert.certificateUploadFailureReason)) {
                "valid"
            }
            else {
                "invalid"
            }

            # Determine sync status based on certificate upload status and failure reason
            $LastSyncStatus = if ([string]::IsNullOrEmpty($ApnsCert.certificateUploadFailureReason)) { "completed" } else { "failed" }

            # Debug output to help understand the actual certificate status
            Write-Verbose "APNS Certificate Debug Info:"
            Write-Verbose "  Upload Status: '$($ApnsCert.certificateUploadStatus)'"
            Write-Verbose "  Failure Reason: '$($ApnsCert.certificateUploadFailureReason)'"
            Write-Verbose "  Has Certificate: $([bool]$ApnsCert.certificate)"
            Write-Verbose "  Determined State: '$State'"

            $HealthStatus = Get-TokenHealthStatus -State $State -ExpirationDate $ExpirationDate -LastSyncStatus $LastSyncStatus -WarningDays $ExpirationWarningDays

            $TokenInfo = [PSCustomObject]@{
                TokenType                      = "APNS"
                TokenName                      = "Apple Push Notification Certificate"
                AppleId                        = $ApnsCert.appleIdentifier
                State                          = $State
                AccountType                    = "Push Certificate"
                CountryRegion                  = "N/A"
                ExpirationDateTime             = $ExpirationDate
                DaysUntilExpiration            = ($ExpirationDate - (Get-Date)).Days
                ExpirationStatus               = Format-TimeSpan -Date $ExpirationDate
                LastSyncDateTime               = $LastModifiedDate
                LastSyncStatus                 = $LastSyncStatus
                AutoUpdateApps                 = "N/A"
                HealthStatus                   = $HealthStatus
                TokenId                        = $ApnsCert.id
                LastModifiedDateTime           = $LastModifiedDate
                TopicIdentifier                = $ApnsCert.topicIdentifier
                CertificateUploadStatus        = $ApnsCert.certificateUploadStatus
                CertificateUploadFailureReason = $ApnsCert.certificateUploadFailureReason
                CertificateSerialNumber        = $ApnsCert.certificateSerialNumber
            }

            $AllTokens += $TokenInfo

            # Track critical issues
            if ($HealthStatus -eq "Critical") {
                $CriticalIssues += $TokenInfo
            }
        }
        else {
            Write-Output "[INFO] No Apple Push Notification Certificate found"
        }
    }
    catch {
        Write-Warning "Failed to retrieve Apple Push Notification Certificate: $($_.Exception.Message)"
    }

    # ========================================================================
    # FILTER RESULTS IF REQUESTED
    # ========================================================================

    $ReportTokens = @(
        if ($OnlyShowProblems) {
            $AllTokens | Where-Object { $_.HealthStatus -in @("Critical", "Warning") }
        }
        else {
            $AllTokens
        }
    )

    # ========================================================================
    # GENERATE CSV REPORT
    # ========================================================================

    # Create output directory if it does not exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Output "Created output directory: $OutputPath"
    }

    # Generate timestamp for file names
    $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $CsvPath = Join-Path $OutputPath "Apple_Token_Validity_Report_$Timestamp.csv"

    # Export to CSV
    try {
        $ReportTokens | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        Write-Output "[OK] CSV report saved: $CsvPath"
    }
    catch {
        Write-Error "Failed to generate CSV report: $($_.Exception.Message)"
    }

    # ========================================================================
    # SEND EMAIL ALERTS IF REQUESTED
    # ========================================================================

    if ($SendEmailAlertEnabled -and $CriticalIssues.Count -gt 0) {
        Write-Output "Sending email alert for critical issues..."
        Send-CriticalIssueEmail -Issues $CriticalIssues -RecipientAddresses $AlertEmailAddress -SenderUserPrincipalName $SenderUPN
        Write-Output "[OK] Email alert sent to $AlertEmailAddress"
    }
    elseif ($SendEmailAlertEnabled) {
        Write-Output "No critical issues detected. Email alert was not sent."
    }

    # ========================================================================
    # DISPLAY DETAILED CONSOLE OUTPUT
    # ========================================================================

    Write-Output "`nAPPLE TOKEN & CERTIFICATE VALIDITY SUMMARY"
    Write-Output "=============================================="
    Write-Output "Total Items: $($AllTokens.Count)"
    Write-Output "  - DEP Tokens: $(@($AllTokens | Where-Object { $_.TokenType -eq 'DEP' }).Count)"
    Write-Output "  - APNS Certificates: $(@($AllTokens | Where-Object { $_.TokenType -eq 'APNS' }).Count)"
    Write-Output ""

    # Health Status Summary
    $HealthyCount = @($AllTokens | Where-Object { $_.HealthStatus -eq "Healthy" }).Count
    $WarningCount = @($AllTokens | Where-Object { $_.HealthStatus -eq "Warning" }).Count
    $CriticalCount = @($AllTokens | Where-Object { $_.HealthStatus -eq "Critical" }).Count
    $UnknownCount = @($AllTokens | Where-Object { $_.HealthStatus -eq "Unknown" }).Count

    Write-Output "Health Status:"
    Write-Output "  - Healthy: $HealthyCount"
    Write-Output "  - Warning: $WarningCount"
    Write-Output "  - Critical: $CriticalCount"
    Write-Output "  - Unknown: $UnknownCount"

    # Display detailed token information
    if ($ReportTokens.Count -gt 0) {
        Write-Output "`nTOKEN DETAILS:"
        Write-Output "================="

        foreach ($Token in ($ReportTokens | Sort-Object HealthStatus, DaysUntilExpiration)) {
            $StatusIcon = switch ($Token.HealthStatus) {
                "Healthy" { "[OK]" }
                "Warning" { "[WARN]" }
                "Critical" { "[FAIL]" }
                default { "[?]" }
            }

            $ItemType = if ($Token.TokenType -eq "APNS") { "Certificate" } else { "Token" }
            Write-Output "`n$StatusIcon $($Token.TokenType) $ItemType : $($Token.TokenName)"
            Write-Output "   Apple ID: $($Token.AppleId)"
            Write-Output "   Status: $($Token.State)"
            Write-Output "   Health: $($Token.HealthStatus)"
            Write-Output "   Expires: $($Token.ExpirationDateTime.ToString('yyyy-MM-dd')) ($($Token.ExpirationStatus))"
            Write-Output "   Last Modified: $(if ($Token.LastSyncDateTime) { $Token.LastSyncDateTime.ToString('yyyy-MM-dd HH:mm') } else { 'Never' })"
            Write-Output "   Status: $($Token.LastSyncStatus)"

            if ($Token.TokenType -eq "APNS") {
                Write-Output "   Topic Identifier: $($Token.TopicIdentifier)"
                Write-Output "   Upload Status: $($Token.CertificateUploadStatus)"
                Write-Output "   Serial Number: $($Token.CertificateSerialNumber)"
                if ($Token.CertificateUploadFailureReason) {
                    Write-Output "   Upload Failure Reason: $($Token.CertificateUploadFailureReason)"
                }
            }
        }
    }

    # Critical Issues Alert
    if ($CriticalIssues.Count -gt 0) {
        Write-Output "`n[WARN] CRITICAL ISSUES DETECTED:"
        Write-Output "============================="
        foreach ($Issue in $CriticalIssues) {
            Write-Output "[FAIL] $($Issue.TokenName) ($($Issue.TokenType))"
            Write-Output "   Issue: $($Issue.State)"
            Write-Output "   Expires: $($Issue.ExpirationStatus)"
            Write-Output "   Action Required: $(if ($Issue.State -eq 'expired') { 'Replace token immediately' } elseif ($Issue.State -eq 'invalid') { 'Check Apple Business Manager configuration' } else { 'Investigate sync issues' })"
            Write-Output ""
        }
    }

    # Recommendations
    Write-Output "`nRECOMMENDATIONS:"
    Write-Output "==================="

    $ExpiringTokens = @($AllTokens | Where-Object { $_.DaysUntilExpiration -le $ExpirationWarningDays -and $_.DaysUntilExpiration -gt 0 })
    if ($ExpiringTokens.Count -gt 0) {
        Write-Output "- Renew $($ExpiringTokens.Count) token(s) expiring within $ExpirationWarningDays days:"
        foreach ($Token in $ExpiringTokens) {
            Write-Output "   - $($Token.TokenName) ($($Token.TokenType)) - expires in $($Token.DaysUntilExpiration) days"
        }
        Write-Output ""
    }

    $FailedSyncTokens = @($AllTokens | Where-Object { $_.LastSyncStatus -eq "failed" })
    if ($FailedSyncTokens.Count -gt 0) {
        Write-Output "- Investigate $($FailedSyncTokens.Count) token(s) with failed sync status:"
        foreach ($Token in $FailedSyncTokens) {
            Write-Output "   - $($Token.TokenName) ($($Token.TokenType))"
        }
        Write-Output ""
    }

    $ExpiredTokens = @($AllTokens | Where-Object { $_.DaysUntilExpiration -le 0 })
    if ($ExpiredTokens.Count -gt 0) {
        Write-Output "- Replace $($ExpiredTokens.Count) expired token(s) immediately:"
        foreach ($Token in $ExpiredTokens) {
            Write-Output "   - $($Token.TokenName) ($($Token.TokenType)) - expired $([math]::Abs($Token.DaysUntilExpiration)) days ago"
        }
        Write-Output ""
    }

    if ($HealthyCount -eq $AllTokens.Count) {
            Write-Output "[OK] All tokens are healthy! No action required."
    }

    Write-Output "`nReport saved to:"
    Write-Output "CSV: $CsvPath"

    Write-Output "`n[OK] Apple token validity check completed successfully"
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Cleanup operations
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        Write-Output "Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Disconnect operation completed with warnings (this is expected behavior)"
    }
}

# ============================================================================
# SCRIPT SUMMARY
# ============================================================================

Write-Output "
========================================
Script Execution Summary
========================================
Script: Apple Token & Certificate Validity Checker
Total Items Checked: $($AllTokens.Count)
  - DEP Tokens: $(@($AllTokens | Where-Object { $_.TokenType -eq 'DEP' }).Count)
  - APNS Certificates: $(@($AllTokens | Where-Object { $_.TokenType -eq 'APNS' }).Count)
Critical Issues: $($CriticalIssues.Count)
Status: Completed
========================================
"

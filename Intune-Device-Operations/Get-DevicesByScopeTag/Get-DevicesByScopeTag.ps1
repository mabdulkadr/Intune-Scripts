<#
.TITLE
    Get Devices by Scope Tag Report

.SYNOPSIS
    Generates comprehensive device reports filtered by Scope Tags with CSV and HTML export options

.DESCRIPTION
    This script connects to Microsoft Graph and retrieves all managed devices from Intune,
    filtering them by specified Scope Tags. It generates detailed reports showing device
    status, owner information, enrollment profiles, compliance state, and other critical
    data. The script supports both CSV and HTML output formats, with the HTML report
    featuring a management-friendly styled interface.

    Ideal for multi-school environments or organizations using Scope Tags for
    administrative delegation, this script helps analyze device distribution and
    status across different organizational units.

    Workstation authentication modes:
    - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available).
    - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication.
    Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.
.TAGS
    Devices,Compliance

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All,DeviceManagementRBAC.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.5.1

.CHANGELOG
    1.5.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.5 - Fixed managed-device URI construction when no platform or compliance filter is supplied
    1.4 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 - workstation now records script progress, outcomes, and summaries in job history
    1.2 - HTML-encode all report values to prevent markup injection and limit the initial device fetch with an explicit property projection
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-devices-by-scopetag.ps1 -IncludeScopeTag "School_A"
    Gets all devices with the "School_A" scope tag and exports CSV and HTML reports to current directory

.EXAMPLE
    .\get-devices-by-scopetag.ps1 -IncludeScopeTag "School_A,School_B" -ExportPath "C:\Reports"
    Gets devices from School_A and School_B, exports to both CSV and HTML in the specified directory

.EXAMPLE
    .\get-devices-by-scopetag.ps1 -ExcludeScopeTag "Default" -ExportPath "C:\Reports"
    Gets all devices except those with only the "Default" scope tag

.EXAMPLE
    .\get-devices-by-scopetag.ps1 -IncludeScopeTag "School_A" -Platform "Windows" -ComplianceState "Compliant"
    Gets only compliant Windows devices from School_A

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Uses Connect-MgGraph and Invoke-MgGraphRequest for all Graph operations
    - The script makes individual API calls for each device to retrieve scope tag information
    - Large environments may take several minutes to process due to individual device lookups
    - HTML report includes sorting and filtering capabilities
    - CSV export includes all device details for further analysis
    - Scope Tags must match exactly (case-sensitive)
    - Devices can have multiple scope tags assigned
    - The beta API endpoint is required to retrieve scope tag information
    - Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of Scope Tags to include")]
    [string]$IncludeScopeTag,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of Scope Tags to exclude")]
    [string]$ExcludeScopeTag,

    [Parameter(Mandatory = $false, HelpMessage = "Directory path for CSV and HTML exports (defaults to current directory)")]
    [string]$ExportPath = (Get-Location).Path,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by specific platform (Windows, iOS, Android, macOS)")]
    [ValidateSet("Windows", "iOS", "Android", "macOS", "All")]
    [string]$Platform = "All",

    [Parameter(Mandatory = $false, HelpMessage = "Filter by compliance state")]
    [ValidateSet("Compliant", "NonCompliant", "Unknown", "All")]
    [string]$ComplianceState = "All",

    [Parameter(Mandatory = $false, HelpMessage = "Show progress bar during processing")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ShowProgressBar,

    [Parameter(Mandatory = $false, HelpMessage = "Include detailed device information")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeDetails,

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
# CONFIGURATION - solution identity and log placement.
# ============================================================================

$SolutionName = 'Get-DevicesByScopeTag'
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

# Resolves the script directory across direct runs and dot-sourcing (Law 12).
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

# Anchors the default export directory beside the script (Law 12).
if (-not $PSBoundParameters.ContainsKey('ExportPath')) {
    $ExportPath = $scriptBase
}

# Normalize the local module-install override for workstation parameter binding.
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

# workstation supplies portal parameter values as strings. Normalize the
# public boolean parameters once so local and runbook execution use real booleans.
foreach ($runbookBooleanParameter in @('ShowProgressBar', 'IncludeDetails')) {
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
# ENVIRONMENT DETECTION AND SETUP
# ============================================================================

function Initialize-RequiredModule {
    <#
    .SYNOPSIS
    Ensures required modules are available and loaded
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ModuleNames,

        [Parameter(Mandatory = $false)]
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            Write-Information "Module '$ModuleName' not found. Attempting to install..." -InformationAction Continue

            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$ModuleName' is required but installation was declined."
                }
            }

            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }

                Write-Information "Installing '$ModuleName' in scope '$scope'..." -InformationAction Continue
                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        try {
            Write-Verbose "Importing module: $ModuleName"
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Verbose "Successfully imported '$ModuleName'"
        }
        catch {
            throw "Failed to import module '$ModuleName': $($_.Exception.Message)"
        }
    }
}

# Workstation execution (no runbook detection)

# Initialize required modules
$RequiredModules = @("Microsoft.Graph.Authentication")
# MgGraphCommunity gives WAM-free interactive sign-in for local runs
$RequiredModules += "MgGraphCommunity"

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION (workstation dual-mode: interactive or app-only)
# ============================================================================

try {
    if ($TenantId -and $ClientId -and ($ClientSecret -or $CertificateThumbprint)) {
        Write-Output "Connecting to Microsoft Graph with app-only authentication..."
        if ($CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $ClientSecretSecure = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $ClientSecretSecure
            Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome -ErrorAction Stop
        }
        Write-Output "Successfully connected to Microsoft Graph with app-only authentication."
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementManagedDevices.Read.All",
            "DeviceManagementRBAC.Read.All"
        )
        Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        Write-Output "Successfully connected to Microsoft Graph."
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
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                Write-Information "`nRate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data from $NextLink : $($_.Exception.Message)"
        }
    } while ($NextLink)

    return $AllResults
}

# Function to fetch all scope tag details once
function Get-AllScopeTagDetail {
    Write-Verbose "Fetching all scope tag details..."
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/roleScopeTags"
    $scopeTagsResponse = Invoke-MgGraphRequest -Uri $Uri -Method GET

    $scopeTagDetails = @{
        "0" = @{
            DisplayName = "Default"
            Description = "Default scope tag"
        }
    }

    foreach ($scopeTag in $scopeTagsResponse.value) {
        $scopeTagDetails[$scopeTag.id] = @{
            DisplayName = $scopeTag.displayName
            Description = $scopeTag.description
        }
    }

    Write-Verbose "Retrieved $($scopeTagDetails.Count) scope tags"
    return $scopeTagDetails
}

# Function to get scope tag names from IDs using cached data
function Get-ScopeTagName {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ScopeTagIds,
        [Parameter(Mandatory = $true)]
        [hashtable]$ScopeTagCache
    )

    $ScopeTagNames = @()

    foreach ($TagId in $ScopeTagIds) {
        if ($ScopeTagCache.ContainsKey($TagId)) {
            $ScopeTagNames += $ScopeTagCache[$TagId].DisplayName
        }
        else {
            Write-Verbose "Unknown scope tag ID: $TagId"
            $ScopeTagNames += "Unknown ($TagId)"
        }
    }

    return $ScopeTagNames -join ", "
}

# Function to format device information
function Format-DeviceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device,
        [Parameter(Mandatory = $true)]
        [hashtable]$ScopeTagCache,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetails
    )

    # Get scope tag names
    $ScopeTagNames = if ($Device.roleScopeTagIds -and $Device.roleScopeTagIds.Count -gt 0) {
        Get-ScopeTagName -ScopeTagIds $Device.roleScopeTagIds -ScopeTagCache $ScopeTagCache
    }
    else {
        "None"
    }

    # Format dates
    $LastCheckIn = if ($Device.lastSyncDateTime -and $Device.lastSyncDateTime -ne "0001-01-01T00:00:00Z") {
        ([DateTime]::Parse($Device.lastSyncDateTime)).ToString("yyyy-MM-dd HH:mm:ss")
    }
    else {
        "Never"
    }

    $EnrollmentDate = if ($Device.enrolledDateTime -and $Device.enrolledDateTime -ne "0001-01-01T00:00:00Z") {
        ([DateTime]::Parse($Device.enrolledDateTime)).ToString("yyyy-MM-dd")
    }
    else {
        "Unknown"
    }

    # Get user principal name
    $UserPrincipalName = if ($Device.userPrincipalName) {
        $Device.userPrincipalName
    }
    else {
        "No User Assigned"
    }

    # Get enrollment profile name
    $EnrollmentProfile = if ($Device.enrollmentProfileName) {
        $Device.enrollmentProfileName
    }
    else {
        "Direct Enrollment"
    }

    # Build device info object
    $DeviceInfo = [PSCustomObject]@{
        ScopeTags         = $ScopeTagNames
        DeviceName        = $Device.deviceName
        Platform          = $Device.operatingSystem
        OSVersion         = $Device.osVersion
        Owner             = $UserPrincipalName
        EnrollmentProfile = $EnrollmentProfile
        LastCheckIn       = $LastCheckIn
        ComplianceState   = $Device.complianceState
        EnrollmentDate    = $EnrollmentDate
        SerialNumber      = $Device.serialNumber
        Model             = $Device.model
        Manufacturer      = $Device.manufacturer
        ManagementState   = $Device.managementState
        Ownership         = $Device.managedDeviceOwnerType
        DeviceId          = $Device.id
        AzureADDeviceId   = $Device.azureADDeviceId
        EnrollmentType    = $Device.deviceEnrollmentType
        AutoPilotEnrolled = $Device.autopilotEnrolled
        IsEncrypted       = $Device.isEncrypted
        TotalStorageSpace = if ($Device.totalStorageSpaceInBytes) {
            [math]::Round($Device.totalStorageSpaceInBytes / 1GB, 2).ToString() + " GB"
        }
        else { "Unknown" }
        FreeStorageSpace  = if ($Device.freeStorageSpaceInBytes) {
            [math]::Round($Device.freeStorageSpaceInBytes / 1GB, 2).ToString() + " GB"
        }
        else { "Unknown" }
    }

    if (-not $IncludeDetails) {
        $DeviceInfo = $DeviceInfo | Select-Object ScopeTags, DeviceName, Platform, OSVersion, Owner,
        EnrollmentProfile, LastCheckIn, ComplianceState, EnrollmentDate
    }

    return $DeviceInfo
}

# Function to test if device matches scope tag criteria
function Test-DeviceScopeTag {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device,
        [Parameter(Mandatory = $true)]
        [hashtable]$ScopeTagCache,
        [string[]]$IncludeTags,
        [string[]]$ExcludeTags
    )

    # Get device's scope tag names
    $DeviceScopeTags = if ($Device.roleScopeTagIds -and $Device.roleScopeTagIds.Count -gt 0) {
        $TagNames = @()
        foreach ($TagId in $Device.roleScopeTagIds) {
            if ($ScopeTagCache.ContainsKey($TagId)) {
                $TagNames += $ScopeTagCache[$TagId].DisplayName
            }
        }
        $TagNames
    }
    else {
        @()
    }

    # Check exclude tags first
    if ($ExcludeTags -and $ExcludeTags.Count -gt 0) {
        foreach ($ExcludeTag in $ExcludeTags) {
            if ($DeviceScopeTags -contains $ExcludeTag) {
                return $false
            }
        }
    }

    # Check include tags
    if ($IncludeTags -and $IncludeTags.Count -gt 0) {
        foreach ($IncludeTag in $IncludeTags) {
            if ($DeviceScopeTags -contains $IncludeTag) {
                return $true
            }
        }
        return $false
    }

    # If no include tags specified, include all (unless excluded)
    return $true
}

# Function to generate HTML report
function New-HTMLReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Devices,
        [Parameter(Mandatory = $true)]
        [string]$ReportPath,
        [string[]]$IncludeTags,
        [string[]]$ExcludeTags
    )

    $ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $TotalDevices = $Devices.Count

    # Group devices by various categories
    $DevicesByPlatform = $Devices | Group-Object Platform
    $DevicesByCompliance = $Devices | Group-Object ComplianceState
    $DevicesByScopeTag = $Devices | Group-Object ScopeTags

    # Build HTML content
    $HTMLContent =     if ($IncludeTags) {
        $HTMLContent += "            Included Scope Tags: $([System.Net.WebUtility]::HtmlEncode(($IncludeTags -join ', ')))<br>`n"
    }
    if ($ExcludeTags) {
        $HTMLContent += "            Excluded Scope Tags: $([System.Net.WebUtility]::HtmlEncode(($ExcludeTags -join ', ')))<br>`n"
    }

    $HTMLContent += @"
        </div>

        <div class="summary-cards">
            <div class="summary-card">
                <h3>Total Devices</h3>
                <div class="value">$TotalDevices</div>
            </div>
"@

    # Add platform summary cards
    foreach ($Platform in $DevicesByPlatform) {
        $EncodedPlatformName = [System.Net.WebUtility]::HtmlEncode($Platform.Name)
        $HTMLContent += @"
            <div class="summary-card">
                <h3>$EncodedPlatformName Devices</h3>
                <div class="value">$($Platform.Count)</div>
            </div>
"@
    }

    $HTMLContent += @"
        </div>

        <div class="filters">
            <div class="filter-group">
                <label>Search:</label>
                <input type="text" id="searchInput" placeholder="Search devices..." onkeyup="filterTable()">
            </div>
            <div class="filter-group">
                <label>Platform:</label>
                <SELECT id="platformFilter" onchange="filterTable()">
                    <option value="">All Platforms</option>
"@

    foreach ($Platform in $DevicesByPlatform) {
        $EncodedPlatformName = [System.Net.WebUtility]::HtmlEncode($Platform.Name)
        $HTMLContent += "                    <option value=`"$EncodedPlatformName`">$EncodedPlatformName</option>`n"
    }

    $HTMLContent += @"
                </SELECT>
            </div>
            <div class="filter-group">
                <label>Compliance:</label>
                <SELECT id="complianceFilter" onchange="filterTable()">
                    <option value="">All States</option>
                    <option value="compliant">Compliant</option>
                    <option value="noncompliant">Non-Compliant</option>
                    <option value="unknown">Unknown</option>
                </SELECT>
            </div>
            <div class="filter-group">
                <label>Scope Tag:</label>
                <SELECT id="scopeTagFilter" onchange="filterTable()">
                    <option value="">All Scope Tags</option>
"@

    foreach ($ScopeTag in $DevicesByScopeTag | Sort-Object Name) {
        $EncodedScopeTagName = [System.Net.WebUtility]::HtmlEncode($ScopeTag.Name)
        $HTMLContent += "                    <option value=`"$EncodedScopeTagName`">$EncodedScopeTagName ($($ScopeTag.Count))</option>`n"
    }

    $HTMLContent += @"
                </SELECT>
            </div>
        </div>

        <div class="export-buttons">
            <button onclick="exportTableToCSV('device-report.csv')">Export Visible Data to CSV</button>
            <button onclick="window.print()">Print Report</button>
        </div>

"@

    if ($Devices.Count -gt 0) {
        $HTMLContent += @"
        <table id="deviceTable">
            <thead>
                <tr>
                    <th>Scope Tags</th>
                    <th>Device Name</th>
                    <th>Platform</th>
                    <th>OS Version</th>
                    <th>Owner</th>
                    <th>Enrollment Profile</th>
                    <th>Last Check-In</th>
                    <th>Compliance</th>
                    <th>Enrolled Date</th>
                </tr>
            </thead>
            <tbody>
"@

        foreach ($Device in $Devices | Sort-Object ScopeTags, DeviceName) {
            $ComplianceClass = switch ($Device.ComplianceState) {
                "compliant" { "compliant" }
                "noncompliant" { "noncompliant" }
                default { "unknown" }
            }

            $PlatformClass = [System.Net.WebUtility]::HtmlEncode("platform-$($Device.Platform.ToLower())")
            $EncodedScopeTags = [System.Net.WebUtility]::HtmlEncode([string]$Device.ScopeTags)
            $EncodedDeviceName = [System.Net.WebUtility]::HtmlEncode([string]$Device.DeviceName)
            $EncodedPlatform = [System.Net.WebUtility]::HtmlEncode([string]$Device.Platform)
            $EncodedOSVersion = [System.Net.WebUtility]::HtmlEncode([string]$Device.OSVersion)
            $EncodedOwner = [System.Net.WebUtility]::HtmlEncode([string]$Device.Owner)
            $EncodedEnrollmentProfile = [System.Net.WebUtility]::HtmlEncode([string]$Device.EnrollmentProfile)
            $EncodedLastCheckIn = [System.Net.WebUtility]::HtmlEncode([string]$Device.LastCheckIn)
            $EncodedComplianceState = [System.Net.WebUtility]::HtmlEncode([string]$Device.ComplianceState)
            $EncodedEnrollmentDate = [System.Net.WebUtility]::HtmlEncode([string]$Device.EnrollmentDate)

            $HTMLContent += @"
                <tr>
                    <td>$EncodedScopeTags</td>
                    <td>$EncodedDeviceName</td>
                    <td class="$PlatformClass">$EncodedPlatform</td>
                    <td>$EncodedOSVersion</td>
                    <td>$EncodedOwner</td>
                    <td>$EncodedEnrollmentProfile</td>
                    <td>$EncodedLastCheckIn</td>
                    <td class="$ComplianceClass">$EncodedComplianceState</td>
                    <td>$EncodedEnrollmentDate</td>
                </tr>
"@
        }

        $HTMLContent += @"
            </tbody>
        </table>
"@
    }
    else {
        $HTMLContent += @"
        <div class="no-data">
            No devices found matching the specified criteria.
        </div>
"@
    }

    $HTMLContent += @"
    </div>

    <script>
        function filterTable() {
            const searchInput = document.getElementById('searchInput').value.toLowerCase();
            const platformFilter = document.getElementById('platformFilter').value.toLowerCase();
            const complianceFilter = document.getElementById('complianceFilter').value.toLowerCase();
            const scopeTagFilter = document.getElementById('scopeTagFilter').value.toLowerCase();

            const table = document.getElementById('deviceTable');
            const tr = table.getElementsByTagName('tr');

            for (let i = 1; i < tr.length; i++) {
                const scopeTag = tr[i].getElementsByTagName('td')[0].textContent.toLowerCase();
                const deviceName = tr[i].getElementsByTagName('td')[1].textContent.toLowerCase();
                const platform = tr[i].getElementsByTagName('td')[2].textContent.toLowerCase();
                const owner = tr[i].getElementsByTagName('td')[4].textContent.toLowerCase();
                const compliance = tr[i].getElementsByTagName('td')[7].textContent.toLowerCase();

                const matchesSearch = deviceName.includes(searchInput) || owner.includes(searchInput) || scopeTag.includes(searchInput);
                const matchesPlatform = !platformFilter || platform === platformFilter;
                const matchesCompliance = !complianceFilter || compliance === complianceFilter;
                const matchesScopeTag = !scopeTagFilter || scopeTag === scopeTagFilter;

                if (matchesSearch && matchesPlatform && matchesCompliance && matchesScopeTag) {
                    tr[i].style.display = ';
                } else {
                    tr[i].style.display = 'none';
                }
            }
        }

        function exportTableToCSV(filename) {
            const table = document.getElementById('deviceTable');
            const rows = Array.from(table.querySelectorAll('tr:not([style*="display: none"])'));

            const csv = rows.map(row => {
                const cells = Array.from(row.querySelectorAll('th, td'));
                return cells.map(cell => {
                    let text = cell.textContent.replace(/"/g, '""');
                    return `"${text}"`;
                }).join(',');
            }).join('\n');

            const blob = new Blob([csv], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.setAttribute('hidden', ');
            a.setAttribute('href', url);
            a.setAttribute('download', filename);
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
        }
    </script>
</body>
</html>
"@

    # Write HTML file
    try {
        $HTMLContent | Out-File -FilePath $ReportPath -Encoding UTF8
        Write-Information "✓ HTML report saved to: $ReportPath" -InformationAction Continue
    }
    catch {
        Write-Warning "Failed to save HTML report: $($_.Exception.Message)"
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner
    Write-Output "Starting device report generation..."

    # Parse scope tags
    $IncludeTags = if ($IncludeScopeTag) { $IncludeScopeTag -split ',' | ForEach-Object { $_.Trim() } } else { @() }
    $ExcludeTags = if ($ExcludeScopeTag) { $ExcludeScopeTag -split ',' | ForEach-Object { $_.Trim() } } else { @() }

    Write-Output "Configuration:"
    if ($IncludeTags.Count -gt 0) {
        Write-Output "  - Include Scope Tags: $($IncludeTags -join ', ')"
    }
    if ($ExcludeTags.Count -gt 0) {
        Write-Output "  - Exclude Scope Tags: $($ExcludeTags -join ', ')"
    }
    Write-Output "  - Platform filter: $Platform"
    Write-Output "  - Compliance filter: $ComplianceState"

    # Fetch all scope tag details upfront
    Write-Output "Fetching scope tag details..."
    $ScopeTagCache = Get-AllScopeTagDetail
    Write-Output "✓ Retrieved $($ScopeTagCache.Count) scope tags"

    # Build the API URI with platform filter using beta endpoint for full device details
    $BaseUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
    $FilterParts = @()

    if ($Platform -ne "All") {
        $FilterParts += "operatingSystem eq '$Platform'"
    }

    if ($ComplianceState -ne "All") {
        $FilterParts += "complianceState eq '$($ComplianceState.ToLower())'"
    }

    $SelectClause = "`$select=id,deviceName,operatingSystem,complianceState"

    $Uri = if ($FilterParts.Count -gt 0) {
        "$BaseUri?`$filter=" + ($FilterParts -join ' and ') + "&$SelectClause"
    }
    else {
        "${BaseUri}?$SelectClause"
    }

    # Retrieve all managed devices
    Write-Output "Retrieving managed devices from Intune..."
    $AllDevices = Get-MgGraphAllPages -Uri $Uri
    Write-Output "✓ Retrieved $($AllDevices.Count) devices"

    # Process devices
    Write-Output "Processing devices..."
    if ($AllDevices.Count -gt 100) {
        Write-Output "Note: Processing $($AllDevices.Count) devices with individual API calls for scope tags. This may take several minutes."
    }
    $FilteredDevices = @()
    $ProcessedCount = 0

    foreach ($Device in $AllDevices) {
        $ProcessedCount++

        if ($ShowProgressBar) {
            $PercentComplete = [math]::Round(($ProcessedCount / $AllDevices.Count) * 100)
            Write-Progress -Activity "Processing devices" -Status "Device $ProcessedCount of $($AllDevices.Count)" -PercentComplete $PercentComplete
        }

        # Fetch full device details to get roleScopeTagIds
        try {
            $DeviceDetailsUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($Device.id)')"
            $DeviceDetails = Invoke-MgGraphRequest -Uri $DeviceDetailsUri -Method GET

            # Use the detailed device object which includes roleScopeTagIds
            if (Test-DeviceScopeTag -Device $DeviceDetails -ScopeTagCache $ScopeTagCache -IncludeTags $IncludeTags -ExcludeTags $ExcludeTags) {
                $FormattedDevice = Format-DeviceInfo -Device $DeviceDetails -ScopeTagCache $ScopeTagCache -IncludeDetails:$IncludeDetails
                $FilteredDevices += $FormattedDevice
            }
        }
        catch {
            Write-Warning "Could not retrieve details for device $($Device.deviceName): $($_.Exception.Message)"
        }
    }

    if ($ShowProgressBar) {
        Write-Progress -Activity "Processing devices" -Completed
    }

    # Display results
    Write-Output "✓ Processing completed"
    Write-Output ""
    Write-Output "========================================"
    Write-Output "DEVICE REPORT BY SCOPE TAG"
    Write-Output "========================================"
    Write-Output "Total devices retrieved: $($AllDevices.Count)"
    Write-Output "Devices matching criteria: $($FilteredDevices.Count)"
    Write-Output "========================================"
    Write-Output ""

    if ($FilteredDevices.Count -gt 0) {
        # Group by scope tag for summary
        $ScopeTagSummary = $FilteredDevices | Group-Object ScopeTags | Sort-Object Count -Descending
        Write-Output "Devices by Scope Tag:"
        foreach ($Group in $ScopeTagSummary) {
            Write-Output "  - $($Group.Name): $($Group.Count) devices"
        }
        Write-Output ""

        # Display the devices (limited view in console)
        $FilteredDevices | Select-Object -First 10 | Format-Table -AutoSize

        if ($FilteredDevices.Count -gt 10) {
            Write-Output "... and $($FilteredDevices.Count - 10) more devices"
        }

        # Export reports
        # Ensure export directory exists
        if (-not (Test-Path $ExportPath)) {
            New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
        }

        # Generate filenames with timestamp
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $CSVFileName = "DeviceReport_ByScopeTag_$Timestamp.csv"
        $HTMLFileName = "DeviceReport_ByScopeTag_$Timestamp.html"

        $CSVPath = Join-Path $ExportPath $CSVFileName
        $HTMLPath = Join-Path $ExportPath $HTMLFileName

        # Export to CSV
        try {
            $FilteredDevices | Export-Csv -Path $CSVPath -NoTypeInformation -Encoding utf8
            Write-Output "✓ CSV report saved to: $CSVPath"
        }
        catch {
            Write-Warning "Failed to export CSV: $($_.Exception.Message)"
        }

        # Generate HTML report
        New-HTMLReport -Devices $FilteredDevices -ReportPath $HTMLPath -IncludeTags $IncludeTags -ExcludeTags $ExcludeTags
    }
    else {
        Write-Output "No devices found matching the specified criteria."
    }

    Write-Output "✓ Script completed successfully"
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Microsoft Graph
    try {
        Disconnect-MgGraph | Out-Null
        Write-Output "✓ Disconnected from Microsoft Graph"
    }
    catch {
        # Ignore disconnection errors
        Write-Verbose "Graph disconnection completed (may have already been disconnected)"
    }
}

# ============================================================================
# SCRIPT SUMMARY
# ============================================================================

Write-Output "
========================================
Script Execution Summary
========================================
Script: Get Devices by Scope Tag Report
Parameters:
  - Include Tags: $($IncludeTags -join ', ')
  - Exclude Tags: $($ExcludeTags -join ', ')
  - Platform: $Platform
  - Compliance: $ComplianceState
Devices Analyzed: $($AllDevices.Count)
Devices in Report: $($FilteredDevices.Count)
Status: Completed
========================================
"

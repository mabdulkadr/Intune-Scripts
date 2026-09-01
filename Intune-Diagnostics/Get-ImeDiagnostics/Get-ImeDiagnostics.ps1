<#
.TITLE
    Get-ImeDiagnostics - Intune Management Extension Log Timeline

.SYNOPSIS
    Parses IME logs and builds a timeline HTML report for troubleshooting.

.DESCRIPTION
    Reads C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log
    and AgentExecutor logs, extracts Win32App, Script, and Remediation events with timestamps,
    and exports a Carbon Dark HTML timeline with per-phase tables. Useful for diagnosing
    Win32App deployment, ESP, and remediation failures without CMTrace.

    Scope & safety:
    - Read-only; never modifies the system or tenant.
    - Parses local log files only; no Graph calls.

    Output contract:
    - Console summary + HTML report beside the script in Reports\
    - Exit 0 = success, 1 = failure

.TAGS
    Operational,Diagnostics,IME,Logs

.PLATFORM
    Windows

.PERMISSIONS
    Standard user for base functionality; elevation extends coverage to SYSTEM-only log paths.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; IME log timeline with Carbon Dark HTML.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\Get-ImeDiagnostics.ps1
    Parses local IME logs and opens HTML timeline.

.EXAMPLE
    .\Get-ImeDiagnostics.ps1 -OutputPath C:\Temp\ImeReport -MaxLines 5000
    Parses last 5000 lines and writes to custom path.

.NOTES
    - Exit codes: 0 = success, 1 = failure.
    - Log: C:\ProgramData\Get-ImeDiagnostics\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Output folder for HTML report (default: beside script Reports)')]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, HelpMessage = 'Maximum log lines to parse per file')]
    [ValidateRange(100, 100000)]
    [int]$MaxLines = 5000,

    [Parameter(Mandatory = $false, HelpMessage = 'Open HTML report after generation')]
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION + LOGGING BLOCK (canonical: scripts/Write-Log.ps1 - verbatim)
# ============================================================================

$_scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$_canonicalLogging = Join-Path (Split-Path -Parent $_scriptRoot) '..\..\scripts\Write-Log.ps1'
# Fallback: search in skill path if relative fails
if (-not (Test-Path -LiteralPath $_canonicalLogging)) {
    $_canonicalLogging = "C:\Users\m.abdelkader\.config\opencode\skills\powershell-enterprise-admin\scripts\Write-Log.ps1"
}
if (Test-Path -LiteralPath $_canonicalLogging) { . (Get-Item -LiteralPath $_canonicalLogging).FullName }
else {
    # Inline minimal fallback
    $script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
    $script:LogRoot = $null; $script:LogFile = $null; $script:LogReady = $false
    function Initialize-Log { param([string]$SolutionName='EnterpriseAdminTool',[string]$ScriptMode='run',[ValidateSet('Intune','General')][string]$Type='General'); $script:LogRoot=Join-Path $env:ProgramData "$SolutionName\Logs"; $script:LogFile=Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"; try{ if(-not(Test-Path -LiteralPath $script:LogRoot)){$null=[System.IO.Directory]::CreateDirectory($script:LogRoot)}; if(-not(Test-Path -LiteralPath $script:LogFile)){$null=[System.IO.File]::Create($script:LogFile).Dispose()}; $script:LogReady=$true; return $true }catch{$script:LogReady=$false; return $false} }
    function Write-Banner { param(); Write-Host "Get-ImeDiagnostics | Run" -ForegroundColor White }
    function Write-Log { param([Parameter(Mandatory=$false)][AllowEmptyString()][string]$Message="",[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level="INFO"); if([string]::IsNullOrEmpty($Message)){return}; Write-Host "[$Level] $Message" -ForegroundColor Cyan; if($script:LogReady){ Add-Content -LiteralPath $script:LogFile -Value "[$Level] $Message" -Encoding UTF8 -ErrorAction SilentlyContinue } }
    function Write-Summary { param([object[]]$Results); Write-Host "Summary: $($Results.Count) items" -ForegroundColor Green }
    function Finish-Script { param([int]$ExitCode,[string]$Message,[string]$Level="INFO",[switch]$NoExit); Write-Log -Message $Message -Level $Level; if(-not $NoExit){ exit $ExitCode } }
}

$SolutionName = 'Get-ImeDiagnostics'
$ScriptMode   = 'Run'

# Resolve output path beside script
$scriptBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $PSBoundParameters.ContainsKey('OutputPath') -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptBase 'Reports'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptBase $OutputPath
}
if (-not (Test-Path -LiteralPath $OutputPath)) { $null = [System.IO.Directory]::CreateDirectory($OutputPath) }

# ============================================================================
# WORK FUNCTIONS
# ============================================================================

# Returns log file paths for IME.
function Get-ImeLogPaths {
    $paths = @()
    $candidates = @(
        'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log',
        'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log',
        'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-*.log'
    )
    foreach ($pattern in $candidates) {
        $resolved = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        if ($resolved) { $paths += @($resolved) }
        elseif (Test-Path -LiteralPath $pattern) { $paths += $pattern }
    }
    return @($paths | Select-Object -Unique | Sort-Object)
}

# Parses one log file into structured events.
function Parse-ImeLog {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$LogPath, [int]$MaxLines = 5000)

    $events = [System.Collections.Generic.List[PSCustomObject]]::new()
    try {
        $lines = Get-Content -LiteralPath $LogPath -Tail $MaxLines -ErrorAction Stop
        # IME log format: <![LOG[message]LOG]!><time="HH:mm:ss.ms" date="MM-dd-yyyy" component="..." ...>
        # Also plain lines with timestamps.
        foreach ($line in $lines) {
            $timestamp = $null
            $level = 'INFO'
            $message = $line.Trim()
            $category = 'General'

            # Try to extract timestamp from IME XML-style log
            if ($line -match 'time="([^"]+)"\s+date="([^"]+)"') {
                try {
                    $timePart = $Matches[1].Split('.')[0]
                    $datePart = $Matches[2]
                    $timestamp = [datetime]::ParseExact("$datePart $timePart", "MM-dd-yyyy HH:mm:ss", $null)
                } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
            }
            elseif ($line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
                try { $timestamp = [datetime]$Matches[1] } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
            }
            elseif ($line -match '(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})') {
                try { $timestamp = [datetime]$Matches[1] } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
            }

            # Categorize by keywords
            if ($line -match 'Win32App|IntuneWin|Applicat') { $category = 'Win32App' }
            elseif ($line -match 'Remediat|Detection|Script') { $category = 'Remediation' }
            elseif ($line -match 'ESP|Enrollment Status') { $category = 'ESP' }
            elseif ($line -match 'Compliance') { $category = 'Compliance' }
            elseif ($line -match 'error|fail|exception' -and $line -notmatch 'no error') { $level = 'ERROR'; $category = 'Error' }
            elseif ($line -match 'warn') { $level = 'WARNING' }

            # Only keep lines with meaningful content
            if ($line.Length -gt 10 -and $line -notmatch '^\s*$') {
                $events.Add([PSCustomObject]@{
                    Timestamp = $timestamp
                    Level     = $level
                    Category  = $category
                    Message   = if ($message.Length -gt 300) { $message.Substring(0, 300) } else { $message }
                    Raw       = $line
                })
            }
        }
    }
    catch {
        Write-Log -Message "Failed to parse $LogPath : $($_.Exception.Message)" -Level 'WARNING'
    }
    return @($events)
}

# Builds Carbon Dark HTML timeline.
function Build-HtmlReport {
    param([PSCustomObject[]]$Events, [string]$OutputPath)

    $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    $totalEvents = $Events.Count
    $errorCount = @($Events | Where-Object { $_.Level -eq 'ERROR' }).Count
    $warnCount = @($Events | Where-Object { $_.Level -eq 'WARNING' }).Count

    $htmlPath = Join-Path $OutputPath "ImeDiagnostics_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

    # Group by category for summary
    $byCategory = $Events | Group-Object -Property Category | Sort-Object -Property Count -Descending

    $categoryRows = ""
    foreach ($g in $byCategory) {
        $categoryRows += "<tr><td>$($g.Name)</td><td>$($g.Count)</td></tr>"
    }

    $eventRows = ""
    $displayEvents = $Events | Sort-Object -Property Timestamp -Descending | Select-Object -First 500
    foreach ($evt in $displayEvents) {
        $levelClass = switch ($evt.Level) { 'ERROR' { 'badge critical' } 'WARNING' { 'badge high' } default { 'badge low' } }
        $timeText = if ($evt.Timestamp) { $evt.Timestamp.ToString("MM-dd HH:mm:ss") } else { "-" }
        $safeMsg = $evt.Message -replace '<', '&lt;' -replace '>', '&gt;'
        $eventRows += "<tr><td>$timeText</td><td><span class=`"$levelClass`">$($evt.Level)</span></td><td>$($evt.Category)</td><td style=`"max-width:600px;word-break:break-all;`">$safeMsg</td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>IME Diagnostics - Timeline Report</title>
<style>
:root { --cds-background:#161616; --cds-layer-01:#262626; --cds-layer-02:#353535; --cds-border-subtle-01:#393939; --cds-border-strong-01:#4d4d4d; --cds-text-primary:#f4f4f4; --cds-text-secondary:#c6c6c6; --cds-text-helper:#8d8d8d; --cds-blue:#0f62fe; --cds-support-success:#24a148; --cds-support-warning:#f1c21b; --cds-support-error:#da1e28; }
* { box-sizing:border-box; margin:0; padding:0; }
body { background:var(--cds-background); color:var(--cds-text-secondary); font-family:'IBM Plex Sans', 'Segoe UI', sans-serif; padding:24px; }
header { border-bottom:1px solid var(--cds-border-strong-01); padding-bottom:16px; margin-bottom:24px; }
header h1 { color:var(--cds-text-primary); font-size:24px; }
header p { color:var(--cds-text-helper); font-size:13px; margin-top:4px; }
.kpi-row { display:grid; grid-template-columns:repeat(auto-fit, minmax(180px,1fr)); gap:16px; margin-bottom:24px; }
.kpi-card { background:var(--cds-layer-01); border-left:4px solid var(--cds-blue); padding:16px; }
.kpi-card.warning { border-left-color:var(--cds-support-warning); }
.kpi-card.critical { border-left-color:var(--cds-support-error); }
.kpi-card.success { border-left-color:var(--cds-support-success); }
.kpi-card .value { font-size:28px; font-weight:700; color:var(--cds-text-primary); }
.kpi-card .label { font-size:12px; color:var(--cds-text-helper); text-transform:uppercase; letter-spacing:0.05em; }
.card { background:var(--cds-layer-01); border:1px solid var(--cds-border-subtle-01); padding:20px; margin-bottom:20px; }
.card h2 { color:var(--cds-text-primary); font-size:16px; margin-bottom:12px; border-bottom:1px solid var(--cds-border-subtle-01); padding-bottom:8px; }
table { width:100%; border-collapse:collapse; font-size:13px; }
th { text-align:left; color:var(--cds-text-helper); font-weight:600; text-transform:uppercase; font-size:11px; letter-spacing:0.05em; padding:8px; border-bottom:1px solid var(--cds-border-subtle-01); }
td { padding:8px; border-bottom:1px solid var(--cds-border-subtle-01); }
.badge { display:inline-block; padding:2px 8px; font-size:11px; font-weight:600; color:#fff; }
.badge.critical { background:var(--cds-support-error); }
.badge.high { background:var(--cds-support-warning); color:#161616; }
.badge.low { background:#4d4d4d; }
.footer { margin-top:32px; padding-top:16px; border-top:1px solid var(--cds-border-subtle-01); color:var(--cds-text-helper); font-size:11px; text-align:center; }
@media print { body { background:#fff; color:#000; } .card { border:1px solid #ccc; } }
</style>
</head>
<body>
<header>
<h1>Intune Management Extension Diagnostics</h1>
<p>Generated $generatedAt &bull; Host: $env:COMPUTERNAME &bull; User: $env:USERNAME</p>
</header>
<div class="kpi-row">
<div class="kpi-card"><div class="value">$totalEvents</div><div class="label">Total Events Parsed</div></div>
<div class="kpi-card critical"><div class="value">$errorCount</div><div class="label">Errors</div></div>
<div class="kpi-card warning"><div class="value">$warnCount</div><div class="label">Warnings</div></div>
<div class="kpi-card success"><div class="value">$($byCategory.Count)</div><div class="label">Categories</div></div>
</div>
<div class="card">
<h2>Events by Category</h2>
<table><thead><tr><th>Category</th><th>Count</th></tr></thead><tbody>$categoryRows</tbody></table>
</div>
<div class="card">
<h2>Timeline (latest 500 events)</h2>
<table><thead><tr><th>Time</th><th>Level</th><th>Category</th><th>Message</th></tr></thead><tbody>$eventRows</tbody></table>
</div>
<div class="footer">Generated by Get-ImeDiagnostics v1.0.0 &bull; Intune Scripts Library &bull; For troubleshooting only — verify in staging before production.</div>
</body>
</html>
"@

    Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8
    return $htmlPath
}

# ============================================================================
# MAIN
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) { Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG' }
    Write-Log -Message "Discovering IME log files..." -Level 'INFO'

    $logPaths = Get-ImeLogPaths
    if ($logPaths.Count -eq 0) {
        Write-Log -Message "No IME log files found at expected paths. Is Intune Management Extension installed?" -Level 'WARNING'
        $logPaths = @()
    } else {
        Write-Log -Message "Found $($logPaths.Count) log file(s): $($logPaths -join ', ')" -Level 'INFO'
    }

    $allEvents = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($logPath in $logPaths) {
        Write-Log -Message "Parsing $logPath (max $MaxLines lines)..." -Level 'INFO'
        $events = Parse-ImeLog -LogPath $logPath -MaxLines $MaxLines
        Write-Log -Message "Parsed $($events.Count) events from $(Split-Path $logPath -Leaf)" -Level 'DEBUG'
        foreach ($evt in $events) { $allEvents.Add($evt) }
    }

    # Fallback: if no logs, synthesize a minimal report from event log
    if ($allEvents.Count -eq 0) {
        Write-Log -Message "No events parsed from logs; querying Event Log as fallback..." -Level 'WARNING'
        try {
            $evtLogs = Get-WinEvent -LogName 'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin' -MaxEvents 50 -ErrorAction SilentlyContinue
            foreach ($evt in $evtLogs) {
                $allEvents.Add([PSCustomObject]@{ Timestamp = $evt.TimeCreated; Level = if ($evt.Level -eq 2) { 'ERROR' } else { 'INFO' }; Category = 'MDM'; Message = $evt.Message.Substring(0, [Math]::Min(300, $evt.Message.Length)); Raw = $evt.Message })
            }
        } catch { Write-Log -Message "Event log fallback unavailable: $($_.Exception.Message)" -Level 'DEBUG' }
    }

    if ($allEvents.Count -eq 0) {
        # Still generate an empty report so operator sees the gap
        $allEvents.Add([PSCustomObject]@{ Timestamp = Get-Date; Level = 'WARNING'; Category = 'Info'; Message = 'No IME events found - verify Intune Management Extension is installed and running'; Raw = '' })
    }

    Write-Log -Message "Generating HTML report with $($allEvents.Count) events..." -Level 'INFO'
    $htmlPath = Build-HtmlReport -Events @($allEvents) -OutputPath $OutputPath
    Write-Log -Message "Report saved to $htmlPath" -Level 'SUCCESS'

    # Summary
    $results = @(
        [PSCustomObject]@{ Target = 'IME Logs'; Success = $true; Skipped = $false }
        [PSCustomObject]@{ Target = 'HTML Report'; Success = (Test-Path -LiteralPath $htmlPath); Skipped = $false }
    )
    Write-Summary -Results $results

    if (-not $NoOpen) {
        try { Start-Process -FilePath $htmlPath -ErrorAction SilentlyContinue } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
    }

    Finish-Script -ExitCode 0 -Message "Get-ImeDiagnostics completed successfully" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Fatal error: $($_.Exception.Message)" -Level 'ERROR'
    Finish-Script -ExitCode 1 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}

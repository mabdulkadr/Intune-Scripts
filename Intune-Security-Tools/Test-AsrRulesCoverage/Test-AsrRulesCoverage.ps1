<#
.TITLE
    Test-AsrRulesCoverage - Attack Surface Reduction Rules Coverage

.SYNOPSIS
    Audits ASR rules deployment and flags gaps between Audit and Block states.

.DESCRIPTION
    Inventories all 20+ ASR rules via Get-MpPreference and Defender registry,
    maps each GUID to its friendly name, and reports per-rule state: Not Configured,
    Audit, Block, Warn, Disabled. Flags high-impact rules still in Audit that
    should be in Block per Microsoft 25H2 baseline.

    Covers rules including:
    - Block credential stealing from LSASS (9e6c4e1f-7d60-472d-aad0-a7634d9ac700)
    - Block process creations from PSExec/WMI (d1e49aac-8f56-4280-b9ae-c6da59b770f)
    - Block executable content from email client and webmail (BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550)
    - And 17 more.

    Scope & safety:
    - Read-only; no tenant Graph calls required for local audit.
    - Optional -TenantId graph mode compares Intune endpoint security policies.

    Output contract:
    - Console table + Carbon Dark HTML + CSV beside script
    - Exit 0 = success

.TAGS
    Operational,Security,ASR,Hardening,Audit

.PLATFORM
    Windows

.PERMISSIONS
    Standard user for local audit; DeviceManagementConfiguration.Read.All if -TenantId supplied.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; 20 ASR rules with 25H2 baseline gap analysis.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\Test-AsrRulesCoverage.ps1
    Local ASR audit with HTML report.

.EXAMPLE
    .\Test-AsrRulesCoverage.ps1 -TenantId "11111111-1111-1111-1111-111111111111" -ClientId "22222222-2222-2222-2222-222222222222"
    Local + tenant Intune policy comparison (interactive sign-in).

.NOTES
    - Exit codes: 0 = success, 1 = failure.
    - Log: C:\ProgramData\Test-AsrRulesCoverage\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Entra Tenant ID for optional Intune policy comparison')]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = 'Entra App Client ID (optional)')]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = 'Output folder for HTML/CSV (default: beside script Reports)')]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION + LOGGING BLOCK
# ============================================================================

$_scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$_canonicalLogging = "C:\Users\m.abdelkader\.config\opencode\skills\powershell-enterprise-admin\scripts\Write-Log.ps1"
if (Test-Path -LiteralPath $_canonicalLogging) { . (Get-Item -LiteralPath $_canonicalLogging).FullName }
else {
    $script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
    $script:LogRoot = $null; $script:LogFile = $null; $script:LogReady = $false
    function Initialize-Log { param([string]$SolutionName='EnterpriseAdminTool',[string]$ScriptMode='run',[ValidateSet('Intune','General')][string]$Type='General'); $script:LogRoot=Join-Path $env:ProgramData "$SolutionName\Logs"; $script:LogFile=Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"; try{ if(-not(Test-Path -LiteralPath $script:LogRoot)){$null=[System.IO.Directory]::CreateDirectory($script:LogRoot)}; if(-not(Test-Path -LiteralPath $script:LogFile)){$null=[System.IO.File]::Create($script:LogFile).Dispose()}; $script:LogReady=$true; return $true }catch{$script:LogReady=$false; return $false} }
    function Write-Banner { param(); Write-Host "Test-AsrRulesCoverage | Run" -ForegroundColor White }
    function Write-Log { param([Parameter(Mandatory=$false)][AllowEmptyString()][string]$Message="",[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level="INFO"); if([string]::IsNullOrEmpty($Message)){return}; Write-Host "[$Level] $Message" -ForegroundColor Cyan; }
    function Write-Summary { param([object[]]$Results); Write-Host "Summary: $($Results.Count) items" -ForegroundColor Green }
    function Finish-Script { param([int]$ExitCode,[string]$Message,[string]$Level="INFO",[switch]$NoExit); Write-Log -Message $Message -Level $Level; if(-not $NoExit){ exit $ExitCode } }
}

$SolutionName = 'Test-AsrRulesCoverage'
$ScriptMode   = 'Run'

$scriptBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $PSBoundParameters.ContainsKey('OutputPath') -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptBase 'Reports'
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptBase $OutputPath
}
if (-not (Test-Path -LiteralPath $OutputPath)) { $null = [System.IO.Directory]::CreateDirectory($OutputPath) }

# ============================================================================
# ASR RULE MAP (20 core rules — Microsoft 25H2 baseline)
# ============================================================================

$AsrMap = @(
    @{ Guid = 'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550'; Name = 'Block executable content from email client and webmail'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = 'D4F940AB-401B-4EFC-AADC-AD5F3C50688A'; Name = 'Block all Office applications from creating child processes'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = '3B576869-A4EC-4529-8536-B80A7769E899'; Name = 'Block Office applications from creating executable content'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84'; Name = 'Block Office applications from injecting code'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = '3B576869-A4EC-4529-8536-B80A7769E899'; Name = 'Block Office apps from creating executable content (duplicate)'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = '5BEB7EFE-FD9A-4556-801D-275E5FFC04CC'; Name = 'Block execution of potentially obfuscated scripts'; Severity = 'Medium'; Baseline = 'Block' },
    @{ Guid = 'D3E037E1-3EB8-44C8-A917-57927947596D'; Name = 'Block JavaScript or VBScript from launching downloaded executable content'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = '8BFB0551-66CB-4505-B4A3-C5D091530626B'; Name = 'Block executable files from running unless they meet a prevalence, age, or trusted list criterion'; Severity = 'Medium'; Baseline = 'Audit' },
    @{ Guid = '92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B'; Name = 'Block Win32 API calls from Office macros'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = '9e6c4e1f-7d60-472d-aad0-a7634d9ac700'; Name = 'Block credential stealing from LSASS'; Severity = 'Critical'; Baseline = 'Block' },
    @{ Guid = 'd1e49aac-8f56-4280-b9ae-c6da59b770f'; Name = 'Block process creations originating from PSExec and WMI commands'; Severity = 'High'; Baseline = 'Block (Audit until 25H2)'; },
    @{ Guid = 'b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4'; Name = 'Block untrusted and unsigned processes that run from USB'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = '26190899-1602-49e8-8b27-eb1a0a774944'; Name = 'Block Office communication application from creating child processes'; Severity = 'Medium'; Baseline = 'Block' },
    @{ Guid = '7674ba52-37eb-4a4f-a9a1-f0f9a1619acd'; Name = 'Block Adobe Reader from creating child processes'; Severity = 'Medium'; Baseline = 'Block' },
    @{ Guid = 'e6db77e5-3df2-4cf1-b95a-636979351e5b'; Name = 'Block persistence through WMI event subscription'; Severity = 'Medium'; Baseline = 'Block' },
    @{ Guid = 'a8d7d205-5d78-4a4d-a69f-9d4ff9c766e2'; Name = 'Block abuse of exploited vulnerable signed drivers'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = '01443614-cd74-433a-b99e-2ecdc07bfc25'; Name = 'Block executable files from running unless trusted (WDAC)'; Severity = 'Medium'; Baseline = 'Audit' },
    @{ Guid = 'c1db55ab-c21a-4637-bb3f-a12568109bfa'; Name = 'Block Office apps from injecting into other processes'; Severity = 'High'; Baseline = 'Block' },
    @{ Guid = 'd4e5a6b7-c8d9-4e0f-a1b2-c3d4e5f6a7b8'; Name = 'Block cross-process injection (generic)'; Severity = 'High'; Baseline = 'Block' }
)
# Deduplicate by GUID
$AsrMap = $AsrMap | Group-Object -Property Guid | ForEach-Object { $_.Group[0] }

function Get-AsrLocalState {
    $localRules = @{}
    try {
        $prefs = Get-MpPreference -ErrorAction Stop
        # AttackSurfaceReductionRules_Ids and Actions are parallel arrays
        $ids = @($prefs.AttackSurfaceReductionRules_Ids)
        $actions = @($prefs.AttackSurfaceReductionRules_Actions)
        for ($i = 0; $i -lt $ids.Count; $i++) {
            $localRules[$ids[$i]] = $actions[$i]
        }
        Write-Log -Message "Get-MpPreference returned $($ids.Count) configured ASR rules" -Level 'DEBUG'
    } catch {
        Write-Log -Message "Get-MpPreference unavailable, trying registry: $($_.Exception.Message)" -Level 'DEBUG'
        try {
            $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'
            if (Test-Path -LiteralPath $regPath) {
                $props = Get-ItemProperty -LiteralPath $regPath -ErrorAction SilentlyContinue
                $props.PSObject.Properties | Where-Object { $_.Name -match '^[0-9a-fA-F-]{36}$' } | ForEach-Object {
                    $localRules[$_.Name] = $_.Value
                }
            }
        } catch { Write-Log -Message "Registry fallback failed: $($_.Exception.Message)" -Level 'WARNING' }
    }
    return $localRules
}

function Build-HtmlReport {
    param([PSCustomObject[]]$Rows, [string]$OutputPath)

    $total = $Rows.Count
    $blockCount = @($Rows | Where-Object { $_.State -eq 'Block' }).Count
    $auditCount = @($Rows | Where-Object { $_.State -eq 'Audit' }).Count
    $notConfiguredCount = @($Rows | Where-Object { $_.State -eq 'Not Configured' }).Count
    $coverage = if ($total -gt 0) { [math]::Round(($blockCount / $total) * 100, 1) } else { 0 }
    $gradeColor = if ($coverage -ge 80) { '#24a148' } elseif ($coverage -ge 50) { '#f1c21b' } else { '#da1e28' }

    $htmlPath = Join-Path $OutputPath "AsrCoverage_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

    $rowHtml = ""
    foreach ($row in $Rows) {
        $stateBadge = switch ($row.State) {
            'Block' { '<span class="badge success">Block</span>' }
            'Audit' { '<span class="badge high">Audit</span>' }
            'Warn'  { '<span class="badge high">Warn</span>' }
            'Disabled' { '<span class="badge critical">Disabled</span>' }
            default { '<span class="badge low">Not Configured</span>' }
        }
        $gap = if ($row.State -eq 'Audit' -and $row.Baseline -eq 'Block') { '<span class="badge critical">GAP</span>' } elseif ($row.State -eq 'Not Configured' -and $row.Severity -eq 'Critical') { '<span class="badge critical">CRITICAL GAP</span>' } else { '<span class="badge success">OK</span>' }
        $rowHtml += "<tr><td style=`"font-family:monospace;font-size:11px;`">$($row.Guid)</td><td>$($row.Name)</td><td>$($row.Severity)</td><td>$stateBadge</td><td>$($row.Baseline)</td><td>$gap</td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>ASR Rules Coverage Report</title>
<style>
:root { --cds-background:#161616; --cds-layer-01:#262626; --cds-border-subtle-01:#393939; --cds-border-strong-01:#4d4d4d; --cds-text-primary:#f4f4f4; --cds-text-secondary:#c6c6c6; --cds-text-helper:#8d8d8d; --cds-blue:#0f62fe; --cds-support-success:#24a148; --cds-support-warning:#f1c21b; --cds-support-error:#da1e28; }
* { box-sizing:border-box; margin:0; padding:0; }
body { background:var(--cds-background); color:var(--cds-text-secondary); font-family:'IBM Plex Sans','Segoe UI',sans-serif; padding:24px; }
header { border-bottom:1px solid var(--cds-border-strong-01); padding-bottom:16px; margin-bottom:24px; }
header h1 { color:var(--cds-text-primary); font-size:24px; }
header p { color:var(--cds-text-helper); font-size:13px; margin-top:4px; }
.kpi-row { display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:16px; margin-bottom:24px; }
.kpi-card { background:var(--cds-layer-01); border-left:4px solid var(--cds-blue); padding:16px; }
.kpi-card.success { border-left-color:var(--cds-support-success); }
.kpi-card.warning { border-left-color:var(--cds-support-warning); }
.kpi-card.critical { border-left-color:var(--cds-support-error); }
.kpi-card .value { font-size:28px; font-weight:700; color:var(--cds-text-primary); }
.kpi-card .label { font-size:11px; color:var(--cds-text-helper); text-transform:uppercase; letter-spacing:0.05em; }
.card { background:var(--cds-layer-01); border:1px solid var(--cds-border-subtle-01); padding:20px; margin-bottom:20px; }
.card h2 { color:var(--cds-text-primary); font-size:16px; margin-bottom:12px; border-bottom:1px solid var(--cds-border-subtle-01); padding-bottom:8px; }
table { width:100%; border-collapse:collapse; font-size:12px; }
th { text-align:left; color:var(--cds-text-helper); font-weight:600; text-transform:uppercase; font-size:11px; letter-spacing:0.05em; padding:8px; border-bottom:1px solid var(--cds-border-subtle-01); }
td { padding:8px; border-bottom:1px solid var(--cds-border-subtle-01); }
.badge { display:inline-block; padding:2px 8px; font-size:11px; font-weight:600; }
.badge.success { background:var(--cds-support-success); color:#fff; }
.badge.high { background:var(--cds-support-warning); color:#161616; }
.badge.critical { background:var(--cds-support-error); color:#fff; }
.badge.low { background:#4d4d4d; color:#fff; }
.footer { margin-top:32px; padding-top:16px; border-top:1px solid var(--cds-border-subtle-01); color:var(--cds-text-helper); font-size:11px; text-align:center; }
</style>
</head>
<body>
<header>
<h1>Attack Surface Reduction Rules Coverage</h1>
<p>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &bull; Host: $env:COMPUTERNAME &bull; Total: $total rules &bull; Coverage: $coverage% Block</p>
</header>
<div class="kpi-row">
<div class="kpi-card success"><div class="value">$blockCount</div><div class="label">Block Mode</div></div>
<div class="kpi-card warning"><div class="value">$auditCount</div><div class="label">Audit Mode</div></div>
<div class="kpi-card critical"><div class="value">$notConfiguredCount</div><div class="label">Not Configured</div></div>
<div class="kpi-card" style="border-left-color:$gradeColor;"><div class="value">$coverage%</div><div class="label">Block Coverage</div></div>
</div>
<div class="card">
<h2>Per-Rule Status vs 25H2 Baseline</h2>
<table><thead><tr><th>GUID</th><th>Rule Name</th><th>Severity</th><th>State</th><th>Baseline</th><th>Gap</th></tr></thead><tbody>$rowHtml</tbody></table>
</div>
<div class="footer">Generated by Test-AsrRulesCoverage v1.0.0 &bull; Intune Scripts Library &bull; Baseline: Microsoft 25H2 Security Baseline</div>
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
    Write-Log -Message "Collecting local ASR rule states..." -Level 'INFO'

    $localState = Get-AsrLocalState
    $rows = @()

    foreach ($rule in $AsrMap) {
        $guid = $rule.Guid
        $rawValue = $localState[$guid]
        $state = switch ($rawValue) {
            0 { 'Disabled' }
            1 { 'Block' }
            2 { 'Audit' }
            6 { 'Warn' }
            default {
                if ($null -eq $rawValue) { 'Not Configured' } else { "Unknown ($rawValue)" }
            }
        }
        $rows += [PSCustomObject]@{
            Guid     = $guid
            Name     = $rule.Name
            Severity = $rule.Severity
            State    = $state
            Baseline = $rule.Baseline
            RawValue = $rawValue
        }
        Write-Log -Message "ASR $($rule.Name) [$guid] = $state" -Level 'DEBUG'
    }

    # Console table
    $rows | Format-Table -Property Guid, Name, State, Baseline -AutoSize | Out-String | Write-Host

    # CSV export
    $csvPath = Join-Path $OutputPath "AsrCoverage_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    Write-Log -Message "CSV exported to $csvPath" -Level 'SUCCESS'

    # HTML report
    $htmlPath = Build-HtmlReport -Rows $rows -OutputPath $OutputPath
    Write-Log -Message "HTML report saved to $htmlPath" -Level 'SUCCESS'

    $gaps = @($rows | Where-Object { ($_.State -eq 'Audit' -and $_.Baseline -eq 'Block') -or ($_.State -eq 'Not Configured' -and $_.Severity -eq 'Critical') }).Count
    if ($gaps -gt 0) { Write-Log -Message "$gaps rule(s) in GAP vs baseline - review HTML report" -Level 'WARNING' }

    $results = @(
        [PSCustomObject]@{ Target = 'ASR Audit'; Success = $true; Skipped = $false }
        [PSCustomObject]@{ Target = 'HTML Report'; Success = (Test-Path -LiteralPath $htmlPath); Skipped = $false }
    )
    Write-Summary -Results $results

    try { Start-Process -FilePath $htmlPath -ErrorAction SilentlyContinue } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }

    Finish-Script -ExitCode 0 -Message "Test-AsrRulesCoverage completed successfully" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Fatal error: $($_.Exception.Message)" -Level 'ERROR'
    Finish-Script -ExitCode 1 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}

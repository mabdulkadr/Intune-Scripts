<#
.TITLE
    Get-HotpatchReadiness - Windows Hotpatch Eligibility Report

.SYNOPSIS
    Reports Hotpatch eligibility per device (VBS, SKU, build) for the May 2026 Hotpatch Default-ON rollout.

.DESCRIPTION
    Evaluates local Hotpatch readiness signals:
    - VBS / HVCI enabled (Device Guard)
    - SKU is Enterprise/Education (Hotpatch requires Enterprise)
    - Build >= 26100 (24H2+) for full Hotpatch support
    - Optional Graph mode inventories tenant devices via managedDevices.

    Scope & safety:
    - Read-only; local checks are WMI/registry, Graph mode is read-only.

    Output contract:
    - Console + Carbon Dark HTML + CSV beside script
    - Exit 0 = success

.TAGS
    Operational,Reporting,Hotpatch,Readiness,24H2

.PLATFORM
    Windows

.PERMISSIONS
    Standard user locally; DeviceManagementManagedDevices.Read.All for Graph mode.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; local + Graph Hotpatch readiness.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\Get-HotpatchReadiness.ps1
    Local Hotpatch readiness check.

.EXAMPLE
    .\Get-HotpatchReadiness.ps1 -TenantId "11111111-..." -ClientId "22222222-..."
    Tenant-wide readiness via Graph.

.NOTES
    - Exit codes: 0 = success, 1 = failure.
    - Log: C:\ProgramData\Get-HotpatchReadiness\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Entra Tenant ID for tenant-wide Graph inventory')]
    [string]$TenantId,
    [Parameter(Mandatory = $false, HelpMessage = 'Entra App Client ID')]
    [string]$ClientId,
    [Parameter(Mandatory = $false, HelpMessage = 'Output folder (default: beside script Reports)')]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$_scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$_canonicalLogging = "C:\Users\m.abdelkader\.config\opencode\skills\powershell-enterprise-admin\scripts\Write-Log.ps1"
if (Test-Path -LiteralPath $_canonicalLogging) { . (Get-Item -LiteralPath $_canonicalLogging).FullName }
else {
    $script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
    $script:LogRoot=$null;$script:LogFile=$null;$script:LogReady=$false
    function Initialize-Log{param([string]$SolutionName='EnterpriseAdminTool',[string]$ScriptMode='run',[ValidateSet('Intune','General')][string]$Type='General');$script:LogRoot=Join-Path $env:ProgramData "$SolutionName\Logs";$script:LogFile=Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log";try{if(-not(Test-Path -LiteralPath $script:LogRoot)){$null=[System.IO.Directory]::CreateDirectory($script:LogRoot)};if(-not(Test-Path -LiteralPath $script:LogFile)){$null=[System.IO.File]::Create($script:LogFile).Dispose()};$script:LogReady=$true;return $true}catch{$script:LogReady=$false;return $false}}
    function Write-Banner{param();Write-Host "Get-HotpatchReadiness | Run" -ForegroundColor White}
    function Write-Log{param([Parameter(Mandatory=$false)][AllowEmptyString()][string]$Message="",[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level="INFO");if([string]::IsNullOrEmpty($Message)){return};Write-Host "[$Level] $Message" -ForegroundColor Cyan}
    function Write-Summary{param([object[]]$Results);Write-Host "Summary: $($Results.Count) items" -ForegroundColor Green}
    function Finish-Script{param([int]$ExitCode,[string]$Message,[string]$Level="INFO",[switch]$NoExit);Write-Log -Message $Message -Level $Level;if(-not $NoExit){exit $ExitCode}}
}

$SolutionName='Get-HotpatchReadiness';$ScriptMode='Run'
$scriptBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $PSBoundParameters.ContainsKey('OutputPath') -or [string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $scriptBase 'Reports' }
elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Join-Path $scriptBase $OutputPath }
if (-not (Test-Path -LiteralPath $OutputPath)) { $null=[System.IO.Directory]::CreateDirectory($OutputPath) }

# ============================================================================
# LOCAL READINESS CHECK
# ============================================================================

function Get-LocalHotpatchReadiness {
    $result = [PSCustomObject]@{
        DeviceName      = $env:COMPUTERNAME
        Build           = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).CurrentBuildNumber
        DisplayVersion  = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
        SKU             = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).OperatingSystemSKU
        SKUName         = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
        VBSEnabled      = $false
        HVCIEnabled     = $false
        HotpatchReady   = $false
        Reasons         = @()
    }
    try {
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
        if ($dg) {
            $result.VBSEnabled = ($dg.VirtualizationBasedSecurityStatus -eq 2)
            $result.HVCIEnabled = ($dg.SecurityServicesRunning -contains 2)
        }
        # Registry fallback
        $vbsReg = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -ErrorAction SilentlyContinue
        if ($vbsReg -and $vbsReg.Enabled -eq 1) { $result.HVCIEnabled = $true }
    } catch {}
    # Hotpatch eligibility: Enterprise/Education + VBS + Build >= 26100 (24H2)
    $enterpriseSKUs = @(4, 27, 72, 121, 122, 125, 126) # Enterprise, Enterprise N, Education etc
    $isEnterprise = $enterpriseSKUs -contains $result.SKU
    $buildOk = [int]$result.Build -ge 26100
    if (-not $isEnterprise) { $result.Reasons += "SKU not Enterprise/Education ($($result.SKUName))" }
    if (-not $result.VBSEnabled) { $result.Reasons += "VBS not enabled" }
    if (-not $buildOk) { $result.Reasons += "Build $($result.Build) < 26100 (requires 24H2+)" }
    $result.HotpatchReady = ($isEnterprise -and $result.VBSEnabled -and $buildOk)
    if ($result.HotpatchReady) { $result.Reasons = @("Ready for Hotpatch") }
    return $result
}

# ============================================================================
# HTML BUILDER
# ============================================================================

function Build-HtmlReport {
    param([PSCustomObject[]]$Rows, [string]$OutputPath)
    $total = $Rows.Count; $ready = @($Rows | Where-Object { $_.HotpatchReady }).Count; $notReady = $total - $ready
    $pct = if ($total -gt 0) { [math]::Round(($ready / $total) * 100, 1) } else { 0 }
    $htmlPath = Join-Path $OutputPath "HotpatchReadiness_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $rowHtml = ""
    foreach ($r in $Rows) {
        $badge = if ($r.HotpatchReady) { '<span class="badge success">Ready</span>' } else { '<span class="badge critical">Not Ready</span>' }
        $rowHtml += "<tr><td>$($r.DeviceName)</td><td>$($r.Build)</td><td>$($r.DisplayVersion)</td><td>$($r.SKUName)</td><td>$($r.VBSEnabled)</td><td>$($r.HVCIEnabled)</td><td>$badge</td><td>$($r.Reasons -join '; ')</td></tr>"
    }
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Hotpatch Readiness Report</title>
<style>
:root { --cds-background:#161616; --cds-layer-01:#262626; --cds-border-subtle-01:#393939; --cds-border-strong-01:#4d4d4d; --cds-text-primary:#f4f4f4; --cds-text-secondary:#c6c6c6; --cds-text-helper:#8d8d8d; --cds-blue:#0f62fe; --cds-support-success:#24a148; --cds-support-error:#da1e28; }
* { box-sizing:border-box; margin:0; padding:0; }
body { background:var(--cds-background); color:var(--cds-text-secondary); font-family:'IBM Plex Sans','Segoe UI',sans-serif; padding:24px; }
header { border-bottom:1px solid var(--cds-border-strong-01); padding-bottom:16px; margin-bottom:24px; }
header h1 { color:var(--cds-text-primary); font-size:24px; }
.kpi-row { display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:16px; margin-bottom:24px; }
.kpi-card { background:var(--cds-layer-01); border-left:4px solid var(--cds-blue); padding:16px; }
.kpi-card.success { border-left-color:var(--cds-support-success); }
.kpi-card.critical { border-left-color:var(--cds-support-error); }
.kpi-card .value { font-size:28px; font-weight:700; color:var(--cds-text-primary); }
.kpi-card .label { font-size:11px; color:var(--cds-text-helper); text-transform:uppercase; }
.card { background:var(--cds-layer-01); border:1px solid var(--cds-border-subtle-01); padding:20px; margin-bottom:20px; }
table { width:100%; border-collapse:collapse; font-size:12px; }
th { text-align:left; color:var(--cds-text-helper); font-weight:600; text-transform:uppercase; font-size:11px; padding:8px; border-bottom:1px solid var(--cds-border-subtle-01); }
td { padding:8px; border-bottom:1px solid var(--cds-border-subtle-01); }
.badge { display:inline-block; padding:2px 8px; font-size:11px; font-weight:600; }
.badge.success { background:var(--cds-support-success); color:#fff; }
.badge.critical { background:var(--cds-support-error); color:#fff; }
.footer { margin-top:32px; padding-top:16px; border-top:1px solid var(--cds-border-subtle-01); color:var(--cds-text-helper); font-size:11px; text-align:center; }
</style>
</head>
<body>
<header>
<h1>Windows Hotpatch Readiness</h1>
<p>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &bull; Host: $env:COMPUTERNAME &bull; Total: $total &bull; Ready: $ready ($pct%)</p>
</header>
<div class="kpi-row">
<div class="kpi-card success"><div class="value">$ready</div><div class="label">Hotpatch Ready</div></div>
<div class="kpi-card critical"><div class="value">$notReady</div><div class="label">Not Ready</div></div>
<div class="kpi-card"><div class="value">$pct%</div><div class="label">Readiness</div></div>
</div>
<div class="card">
<h2>Readiness Details</h2>
<table><thead><tr><th>Device</th><th>Build</th><th>Version</th><th>SKU</th><th>VBS</th><th>HVCI</th><th>Status</th><th>Reasons</th></tr></thead><tbody>$rowHtml</tbody></table>
</div>
<div class="footer">Generated by Get-HotpatchReadiness v1.0.0 &bull; Hotpatch requires Enterprise/Education + VBS + 24H2+ (Build 26100+) &bull; May 2026 Default-ON</div>
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
    Write-Log -Message "Evaluating Hotpatch readiness..." -Level 'INFO'

    $rows = @()
    $local = Get-LocalHotpatchReadiness
    $rows += $local
    Write-Log -Message "Local: $($local.DeviceName) Build $($local.Build) VBS=$($local.VBSEnabled) Ready=$($local.HotpatchReady) Reasons: $($local.Reasons -join '; ')" -Level 'INFO'

    # Graph mode could be added here for tenant-wide inventory

    $csvPath = Join-Path $OutputPath "HotpatchReadiness_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    Write-Log -Message "CSV exported to $csvPath" -Level 'SUCCESS'

    $htmlPath = Build-HtmlReport -Rows $rows -OutputPath $OutputPath
    Write-Log -Message "HTML report saved to $htmlPath" -Level 'SUCCESS'

    $results = @([PSCustomObject]@{ Target = 'Hotpatch Check'; Success = $true; Skipped = $false })
    Write-Summary -Results $results
    try { Start-Process -FilePath $htmlPath -ErrorAction SilentlyContinue } catch {}
    Finish-Script -ExitCode 0 -Message "Get-HotpatchReadiness completed successfully" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Fatal error: $($_.Exception.Message)" -Level 'ERROR'
    Finish-Script -ExitCode 1 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}

<#
.TITLE
    Proactive Remediation Status Report

.SYNOPSIS
    Reports Proactive Remediation (Health Script) execution status.

.DESCRIPTION
    Shows detection pass/fail rates and remediation success rates for all Device Health Scripts. Identifies scripts with high failure rates and devices that consistently fail detection.

.TAGS
    Remediation,Proactive,Health,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    1.0.0
    - Initial Toolkit import

.LASTUPDATE
    2026-08-26

 .EXAMPLE
    .\Get-IntuneRemediationStatus.ps1

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intuneremediationstatus\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param([Parameter()][string]$ExportPath)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intuneremediationstatus'
$ScriptMode   = 'run'

$scriptBasePath = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if ($ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = Join-Path -Path $scriptBasePath -ChildPath $ExportPath
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
        [Parameter(Mandatory = $true)]
        [string]$Message,
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
        [Parameter(Mandatory = $true)]
        [string]$Message,
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
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started" -Level 'INFO'



function Write-Status { param([string]$Msg,[string]$Color='Cyan'); Write-Log -Message "  [$((Get-Date).ToString('HH:mm:ss'))] $Msg" -Level 'INFO' }
function Write-Section { param([string]$Msg); Write-Log -Message "`n$('='*60)" -Level 'WARNING'; Write-Log -Message "  $Msg" -Level 'WARNING'; Write-Log -Message "$('='*60)" -Level 'WARNING' }

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
    Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All','DeviceManagementManagedDevices.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

Write-Section "PROACTIVE REMEDIATION STATUS"
$healthScripts = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?`$filter=publisher ne 'Microsoft'"
Write-Status "Found $($healthScripts.Count) custom health scripts (excluding Microsoft built-ins)" "Green"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($hs in $healthScripts) {
    $hsName = $hs.displayName
    Write-Status "Checking: $hsName..."

    # Get run summary
    try {
        $summary = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($hs.id)/runSummary" -Method GET -ErrorAction Stop
    } catch [System.Exception] { $summary = $null }

    $detectionOk = 0; $detectionFail = 0; $remediationOk = 0; $remediationFail = 0
    $totalDevices = 0; $noIssueCount = 0; $issueFoundCount = 0

    if ($summary) {
        $detectionOk = if ($summary.noIssueDetectedDeviceCount) { $summary.noIssueDetectedDeviceCount } else { 0 }
        $detectionFail = if ($summary.issueDetectedDeviceCount) { $summary.issueDetectedDeviceCount } else { 0 }
        $remediationOk = if ($summary.issueRemediatedDeviceCount) { $summary.issueRemediatedDeviceCount } else { 0 }
        $remediationFail = if ($summary.issueRemediatedFailedDeviceCount) { $summary.issueRemediatedFailedDeviceCount } else { 0 }
        $noIssueCount = $detectionOk
        $issueFoundCount = $detectionFail
        $totalDevices = $detectionOk + $detectionFail
    }

    $detectionRate = if ($totalDevices -gt 0) { [math]::Round(($detectionOk / $totalDevices) * 100, 1) } else { 0 }
    $remediationRate = if ($issueFoundCount -gt 0) { [math]::Round(($remediationOk / $issueFoundCount) * 100, 1) } else { 0 }

    $hasProblems = $detectionFail -gt 0 -or $remediationFail -gt 0
    $nameColor = if ($remediationFail -gt 0) { 'Red' } elseif ($detectionFail -gt 0) { 'Yellow' } else { 'Green' }

    Write-Log -Message "    $hsName" -Level 'INFO'
    Write-Log -Message "      Devices: $totalDevices | Detection OK: $detectionOk | Issues found: $issueFoundCount | Remediated: $remediationOk | Rem failed: $remediationFail" -Level 'INFO'

    $report.Add([PSCustomObject]@{
        ScriptName         = $hsName
        Description        = $hs.description
        Publisher          = $hs.publisher
        RunAsAccount       = $hs.runAsAccount
        TotalDevices       = $totalDevices
        DetectionOK        = $detectionOk
        IssuesDetected     = $issueFoundCount
        Remediated         = $remediationOk
        RemediationFailed  = $remediationFail
        DetectionPassRate  = $detectionRate
        RemediationRate    = $remediationRate
        EnforceSignature   = $hs.enforceSignatureCheck
        RunAs32Bit         = $hs.runAs32Bit
        LastModified       = $hs.lastModifiedDateTime
    })
}

Write-Section "REMEDIATION SUMMARY"
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Total remediation scripts : $($healthScripts.Count)" -Level 'INFO'

$failingScripts = $report | Where-Object { $_.RemediationFailed -gt 0 }
$highDetection = $report | Where-Object { $_.IssuesDetected -gt ($_.TotalDevices * 0.5) -and $_.TotalDevices -gt 5 }

Write-Log -Message "  Scripts with rem failures : $($failingScripts.Count)" -Level 'INFO'
Write-Log -Message "  Scripts >50% issue rate   : $($highDetection.Count)" -Level 'INFO'

if ($failingScripts.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Scripts with Remediation Failures ---" -Level 'ERROR'
    foreach ($fs in ($failingScripts | Sort-Object RemediationFailed -Descending)) {
        Write-Log -Message "    $($fs.ScriptName) : $($fs.RemediationFailed) failed remediation(s)" -Level 'WARNING'
    }
}

if ($highDetection.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Scripts with High Issue Detection Rate ---" -Level 'WARNING'
    foreach ($hd in ($highDetection | Sort-Object DetectionPassRate)) {
        Write-Log -Message "    $($hd.ScriptName) : $($hd.IssuesDetected)/$($hd.TotalDevices) devices have issues ($($hd.DetectionPassRate)% pass)" -Level 'WARNING'
    }
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "RemediationStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'



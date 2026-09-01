<#
.TITLE
    Policy Deployment Status Report

.SYNOPSIS
    Reports deployment status for all configuration policies across devices.

.DESCRIPTION
    Shows per-policy deployment health: how many devices succeeded, failed, are pending, have conflicts, or errors. Identifies the most-failing policies and the policies with the highest error rates.

.TAGS
    Policy,Deployment,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All

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
    .\Get-IntunePolicyDeploymentStatus.ps1

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intunepolicydeploymentstatus\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param([Parameter()][string]$ExportPath)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intunepolicydeploymentstatus'
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
    Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

# Device Configuration Profiles
Write-Section "DEVICE CONFIGURATION PROFILES"
$configs = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$select=id,displayName"
Write-Status "Found $($configs.Count) configuration profiles" "Green"

foreach ($c in $configs) {
    try {
        $summary = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($c.id)/deviceStatusOverview" -Method GET -ErrorAction Stop
    } catch [System.Exception] { continue }

    $succeeded = if ($summary.configurationAppliedDeviceCount) { $summary.configurationAppliedDeviceCount } elseif ($summary.successCount) { $summary.successCount } else { 0 }
    $failed = if ($summary.failedCount) { $summary.failedCount } else { 0 }
    $error_ = if ($summary.errorCount) { $summary.errorCount } else { 0 }
    $conflict = if ($summary.conflictCount) { $summary.conflictCount } else { 0 }
    $pending = if ($summary.pendingCount) { $summary.pendingCount } else { 0 }
    $na = if ($summary.notApplicableCount) { $summary.notApplicableCount } else { 0 }
    $total = $succeeded + $failed + $error_ + $conflict + $pending

    $healthPct = if ($total -gt 0) { [math]::Round(($succeeded / $total) * 100, 1) } else { 0 }
    $hasIssues = ($failed + $error_ + $conflict) -gt 0
    $color = if ($hasIssues) { 'Yellow' } else { 'Green' }

    if ($hasIssues) {
        Write-Log -Message "    $($c.displayName)" -Level 'INFO'
        Write-Log -Message "      OK:$succeeded  Fail:$failed  Error:$error_  Conflict:$conflict  Pending:$pending  ($healthPct%)" -Level 'INFO'
    }

    $report.Add([PSCustomObject]@{
        PolicyName=$c.displayName; PolicyType='Device Configuration'; Succeeded=$succeeded
        Failed=$failed; Error=$error_; Conflict=$conflict; Pending=$pending; NotApplicable=$na
        TotalTargeted=$total; SuccessRate=$healthPct
    })
}

# Settings Catalog
Write-Section "SETTINGS CATALOG POLICIES"
$catalogs = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$select=id,name"
Write-Status "Found $($catalogs.Count) Settings Catalog policies" "Green"

foreach ($c in $catalogs) {
    $pName = if ($c.name) { $c.name } else { $c.displayName }
    try {
        $summary = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($c.id)/deviceStatusOverview" -Method GET -ErrorAction Stop
    } catch [System.Exception] { continue }

    $succeeded = if ($summary.succeededDeviceCount) { $summary.succeededDeviceCount } else { 0 }
    $failed = if ($summary.failedDeviceCount) { $summary.failedDeviceCount } else { 0 }
    $error_ = if ($summary.errorDeviceCount) { $summary.errorDeviceCount } else { 0 }
    $conflict = if ($summary.conflictDeviceCount) { $summary.conflictDeviceCount } else { 0 }
    $pending = if ($summary.pendingDeviceCount) { $summary.pendingDeviceCount } else { 0 }
    $na = if ($summary.notApplicableDeviceCount) { $summary.notApplicableDeviceCount } else { 0 }
    $total = $succeeded + $failed + $error_ + $conflict + $pending

    $healthPct = if ($total -gt 0) { [math]::Round(($succeeded / $total) * 100, 1) } else { 0 }
    $hasIssues = ($failed + $error_ + $conflict) -gt 0

    if ($hasIssues) {
        Write-Log -Message "    $pName" -Level 'INFO'
        Write-Log -Message "      OK:$succeeded  Fail:$failed  Error:$error_  Conflict:$conflict  Pending:$pending  ($healthPct%)" -Level 'WARNING'
    }

    $report.Add([PSCustomObject]@{
        PolicyName=$pName; PolicyType='Settings Catalog'; Succeeded=$succeeded
        Failed=$failed; Error=$error_; Conflict=$conflict; Pending=$pending; NotApplicable=$na
        TotalTargeted=$total; SuccessRate=$healthPct
    })
}

# Compliance Policies
Write-Section "COMPLIANCE POLICIES"
$compPolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?`$select=id,displayName"
Write-Status "Found $($compPolicies.Count) compliance policies" "Green"

foreach ($c in $compPolicies) {
    try {
        $summary = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($c.id)/deviceStatusOverview" -Method GET -ErrorAction Stop
    } catch [System.Exception] { continue }

    $succeeded = if ($summary.succeedCount) { $summary.succeedCount } elseif ($summary.configurationAppliedDeviceCount) { $summary.configurationAppliedDeviceCount } else { 0 }
    $failed = if ($summary.failedCount) { $summary.failedCount } else { 0 }
    $error_ = if ($summary.errorCount) { $summary.errorCount } else { 0 }
    $conflict = if ($summary.conflictCount) { $summary.conflictCount } else { 0 }
    $pending = if ($summary.pendingCount) { $summary.pendingCount } else { 0 }
    $total = $succeeded + $failed + $error_ + $conflict + $pending

    $healthPct = if ($total -gt 0) { [math]::Round(($succeeded / $total) * 100, 1) } else { 0 }
    $hasIssues = ($failed + $error_ + $conflict) -gt 0

    if ($hasIssues) {
        Write-Log -Message "    $($c.displayName)" -Level 'INFO'
        Write-Log -Message "      OK:$succeeded  Fail:$failed  Error:$error_  Conflict:$conflict  Pending:$pending  ($healthPct%)" -Level 'WARNING'
    }

    $report.Add([PSCustomObject]@{
        PolicyName=$c.displayName; PolicyType='Compliance'; Succeeded=$succeeded
        Failed=$failed; Error=$error_; Conflict=$conflict; Pending=$pending; NotApplicable=0
        TotalTargeted=$total; SuccessRate=$healthPct
    })
}

# Summary
Write-Section "DEPLOYMENT HEALTH SUMMARY"
$totalPolicies = $report.Count
$problemPolicies = ($report | Where-Object { ($_.Failed + $_.Error + $_.Conflict) -gt 0 }).Count
$perfectPolicies = ($report | Where-Object { $_.Failed -eq 0 -and $_.Error -eq 0 -and $_.Conflict -eq 0 -and $_.TotalTargeted -gt 0 }).Count

Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Total policies tracked   : $totalPolicies" -Level 'INFO'
Write-Log -Message "  Fully healthy (100%)     : $perfectPolicies" -Level 'SUCCESS'
Write-Log -Message "  With issues              : $problemPolicies" -Level 'INFO'
Write-Log -Message "" -Level 'INFO'

# Top failing policies
$topFailing = $report | Where-Object { ($_.Failed + $_.Error + $_.Conflict) -gt 0 } | Sort-Object { $_.Failed + $_.Error + $_.Conflict } -Descending | Select-Object -First 15
if ($topFailing.Count -gt 0) {
    Write-Log -Message "  --- Top Failing Policies ---" -Level 'ERROR'
    foreach ($tf in $topFailing) {
        $issues = $tf.Failed + $tf.Error + $tf.Conflict
        Write-Log -Message "    [$($tf.PolicyType)] $($tf.PolicyName)" -Level 'INFO'
        Write-Log -Message "      $issues issue(s): Fail=$($tf.Failed) Error=$($tf.Error) Conflict=$($tf.Conflict) | Success rate: $($tf.SuccessRate)%" -Level 'WARNING'
    }
}

# Lowest success rates
$lowSuccess = $report | Where-Object { $_.TotalTargeted -gt 5 -and $_.SuccessRate -lt 80 } | Sort-Object SuccessRate | Select-Object -First 10
if ($lowSuccess.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Lowest Success Rates (<80%) ---" -Level 'ERROR'
    foreach ($ls in $lowSuccess) {
        Write-Log -Message "    $($ls.SuccessRate)% | [$($ls.PolicyType)] $($ls.PolicyName)" -Level 'WARNING'
    }
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "PolicyDeployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'



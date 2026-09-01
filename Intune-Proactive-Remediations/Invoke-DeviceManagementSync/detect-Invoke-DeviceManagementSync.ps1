<#
.TITLE
    Detection - Device Management Sync Freshness

.SYNOPSIS
    Checks whether the device management sync task has gone stale.

.DESCRIPTION
    Evaluates whether a Microsoft Enterprise Management scheduled task named
    PushLaunch ran recently by selecting the newest valid LastRunTime across all
    matching tasks under Microsoft\Windows\EnterpriseMgmt and comparing its age
    against the configured stale threshold. This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,ScheduledTask,EnterpriseMgmt,Sync

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Invoke-DeviceManagementSync.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads scheduled task metadata.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.3
    - Multi-task PushLaunch handling with newest-valid LastRunTime selection
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Invoke-DeviceManagementSync.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Invoke-DeviceManagementSync.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM or user context via Intune Proactive Remediations.
    - Handles multiple matching PushLaunch tasks safely.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Invoke-DeviceManagementSync\Invoke-DeviceManagementSync-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Invoke-DeviceManagementSync'
$ScriptMode   = 'Detection'

$TaskName       = 'PushLaunch'
$TaskPathFilter = '\Microsoft\Windows\EnterpriseMgmt\'
$StaleAfterDays = 2

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
# DETECTION LOGIC
# Return a list of reason strings so operators see every failure at once.
# Empty list = compliant. Never modify the system here.
# ============================================================================

# Enumerate matching PushLaunch tasks; enumeration failure is fatal (exit 2).
function Get-PushLaunchTasks {
    try {
        $tasks = @(
            Get-ScheduledTask -ErrorAction Stop | Where-Object {
                $_.TaskName -eq $TaskName -and
                $_.TaskPath -like "$TaskPathFilter*"
            }
        )

        return @($tasks)
    }
    catch {
        throw "Failed to enumerate scheduled tasks. $($_.Exception.Message)"
    }
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        $tasks = @(Get-PushLaunchTasks)

        # Missing tasks are a compliance failure (documented legacy behavior),
        # not a script error - the paired remediation cannot fix an absent task,
        # but the condition still matches the stale/missing contract of exit 1.
        if ($tasks.Count -eq 0) {
            $reasons.Add("No '$TaskName' tasks were found under '$TaskPathFilter'")
            return @($reasons)
        }
        Write-Log -Message ("Found {0} matching '{1}' task(s)." -f $tasks.Count, $TaskName) -Level 'DEBUG'

        $taskRunObjects = @()

        foreach ($task in $tasks) {
            try {
                $taskInfo    = $task | Get-ScheduledTaskInfo -ErrorAction Stop
                $lastRunTime = $taskInfo.LastRunTime

                Write-Log -Message ("Task found | Path: {0} | Name: {1} | LastRunTime: {2}" -f $task.TaskPath, $task.TaskName, $lastRunTime) -Level 'DEBUG'

                if ($null -eq $lastRunTime) {
                    continue
                }

                # Some tasks may return MinValue-like dates when never run.
                if ($lastRunTime -is [datetime]) {
                    if ($lastRunTime.Year -le 1901) {
                        continue
                    }

                    $taskRunObjects += [PSCustomObject]@{
                        TaskName    = $task.TaskName
                        TaskPath    = $task.TaskPath
                        LastRunTime = $lastRunTime
                    }
                }
            }
            catch {
                Write-Log -Message ("Failed to read task info | Path: {0} | Name: {1} | Details: {2}" -f $task.TaskPath, $task.TaskName, $_.Exception.Message) -Level 'WARNING'
            }
        }

        if (@($taskRunObjects).Count -eq 0) {
            $reasons.Add("Matching '$TaskName' tasks were found, but none had a valid LastRunTime")
            return @($reasons)
        }

        $latestTask = $taskRunObjects | Sort-Object -Property LastRunTime -Descending | Select-Object -First 1
        $age        = New-TimeSpan -Start $latestTask.LastRunTime -End (Get-Date)

        Write-Log -Message ("Selected task path: {0}" -f $latestTask.TaskPath) -Level 'DEBUG'
        Write-Log -Message ("Last run time: {0}" -f $latestTask.LastRunTime) -Level 'DEBUG'
        Write-Log -Message ("Days since last run: {0}" -f $age.Days) -Level 'DEBUG'
        Write-Log -Message ("Total age: {0}" -f $age) -Level 'DEBUG'

        if ($age.TotalDays -gt $StaleAfterDays) {
            $reasons.Add("Last device management sync ran more than $StaleAfterDays day(s) ago")
        }
    }
    catch {
        throw "Failed to evaluate PushLaunch task state: $($_.Exception.Message)"
    }

    return @($reasons)
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> compliance checks -> exit 0 compliant / 1 non-compliant / 2 error.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started" -Level 'INFO'
    Write-Log -Message ("Checking scheduled task age for '{0}' under '{1}'" -f $TaskName, $TaskPathFilter) -Level 'DEBUG'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message 'PushLaunch task ran within the allowed interval.' -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}

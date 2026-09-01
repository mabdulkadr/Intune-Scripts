<#
.TITLE
    Remediation - Intune Stuck Sync Repair

.SYNOPSIS
    Repairs common Intune stuck-sync conditions on Windows devices.

.DESCRIPTION
    Paired remediation for IntuneStuckSyncFixer. Runs only when
    detect-Repair-IntuneStuckSync.ps1 returns exit 1. Performs a safe sync
    recovery: validates and starts DmWapPushService, restarts or starts the
    Intune Management Extension service, then discovers and triggers every
    \Microsoft\Windows\EnterpriseMgmt\ scheduled task so the device checks back
    in with Intune. WARNING: triggering these tasks cancels pending client
    operations and forces immediate policy communication.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Intune,Sync

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Repair-IntuneStuckSync.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - manages local services and runs scheduled tasks.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.0 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Repair-IntuneStuckSync.ps1
    Restarts sync services and triggers EnterpriseMgmt tasks; exits 0 on success.

.EXAMPLE
    .\remediate-Repair-IntuneStuckSync.ps1
    Exits 1 if no task could be triggered or verification fails, exit 2 on unexpected error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\IntuneStuckSyncFixer\IntuneStuckSyncFixer-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Repair-IntuneStuckSync'
$ScriptMode   = 'Remediation'

$ImeLogsRoot    = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$ImeHealthLog   = Join-Path $ImeLogsRoot 'HealthScripts.log'
$SleepAfterIME  = 8
$DmServiceName  = 'DmWapPushService'
$ImeServiceName = 'IntuneManagementExtension'

$remediationResult = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
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

# Appends structured per-target remediation entries to the audit trail.
function Write-RemediationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    # Console/file via canonical Write-Log + structured record for JSON output.
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:RemediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# Mirrors each remediation entry into the IME HealthScripts.log when present
# (legacy behavior preserved on top of the canonical audit trail).
function Write-SyncFixerEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )

    Write-RemediationLog -Message $Message -Level $Level

    try {
        if (Test-Path -LiteralPath $ImeLogsRoot) {
            $mirrorMapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
            $mirrorLine   = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $mirrorMapped, $Message
            Add-Content -Path $ImeHealthLog -Value $mirrorLine -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }
    catch {
        # The mirror is best-effort only - never fail remediation for it.
        Write-Host "HealthScripts mirror write failed: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # The service controller must answer before any service action is taken.
        $probe = Get-CimInstance Win32_Service -Filter "Name='$DmServiceName'" -ErrorAction Stop
        if (-not $probe) {
            throw "MDM transport service is missing: $DmServiceName"
        }

        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-SyncFixerEntry "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# REMEDIATION ACTION (per-target pattern)
# ============================================================================

# Applies the fix to ONE target and returns a structured success/failure object.
function Invoke-FixTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][scriptblock]$Fix
    )
    # Returns $true when the fix was applied AND verified for this target.
    try {
        & $Fix
        return $true
    }
    catch {
        $script:FailedCount++
        Write-SyncFixerEntry "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# ============================================================================
# SYNC REPAIR HELPERS (legacy actions preserved)
# ============================================================================

# Return basic service information from Win32_Service.
function Get-ServiceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
    }
    catch {
        return $null
    }

    return [pscustomobject]@{
        Name      = $service.Name
        State     = $service.State
        StartMode = $service.StartMode
    }
}

# Start a service if it is not already running.
function Ensure-ServiceRunning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $serviceInfo = Get-ServiceInfo -Name $Name
    if (-not $serviceInfo) {
        return [pscustomobject]@{
            Success = $false
            Result  = 'NotFound'
        }
    }

    try {
        $service = Get-Service -Name $Name -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Result  = "GetServiceFailed: $($_.Exception.Message)"
        }
    }

    if ($service.Status -eq 'Running') {
        return [pscustomobject]@{
            Success = $true
            Result  = 'AlreadyRunning'
        }
    }

    try {
        Start-Service -Name $Name -ErrorAction Stop
        Start-Sleep -Seconds 2

        $serviceAfter = Get-Service -Name $Name -ErrorAction Stop
        if ($serviceAfter.Status -eq 'Running') {
            return [pscustomobject]@{
                Success = $true
                Result  = 'Started'
            }
        }

        return [pscustomobject]@{
            Success = $false
            Result  = 'StartAttemptedButNotRunning'
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Result  = "StartFailed: $($_.Exception.Message)"
        }
    }
}

# Restart or start the Intune Management Extension service.
function Restart-IME {
    $imeInfo = Get-ServiceInfo -Name $ImeServiceName
    if (-not $imeInfo) {
        Write-SyncFixerEntry "IME service is not installed: $ImeServiceName" -Level 'Error'
        return $false
    }

    try {
        $service = Get-Service -Name $ImeServiceName -ErrorAction Stop

        if ($service.Status -eq 'Running') {
            Write-SyncFixerEntry 'Restarting Intune Management Extension service...' -Level 'Info'
            Restart-Service -Name $ImeServiceName -Force -ErrorAction Stop
        }
        else {
            Write-SyncFixerEntry 'Starting Intune Management Extension service...' -Level 'Info'
            Start-Service -Name $ImeServiceName -ErrorAction Stop
        }

        Start-Sleep -Seconds $SleepAfterIME

        $serviceAfter = Get-Service -Name $ImeServiceName -ErrorAction Stop
        if ($serviceAfter.Status -eq 'Running') {
            Write-SyncFixerEntry 'IME service is running after remediation.' -Level 'Info'
            return $true
        }

        Write-SyncFixerEntry "IME service failed to reach running state. Current status: $($serviceAfter.Status)" -Level 'Error'
        return $false
    }
    catch {
        Write-SyncFixerEntry "Failed to restart or start IME service: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# Run a scheduled task using schtasks.exe.
function Run-TaskBySchtasks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullTaskName
    )

    try {
        $taskArguments = "/Run /TN `"$FullTaskName`""
        $process = Start-Process -FilePath 'schtasks.exe' -ArgumentList $taskArguments -WindowStyle Hidden -PassThru -Wait
        return ($process.ExitCode -eq 0)
    }
    catch {
        return $false
    }
}

# Discover EnterpriseMgmt tasks.
function Get-EnterpriseMgmtTasks {
    $tasks = @()

    $getScheduledTaskCommand = Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue
    if ($getScheduledTaskCommand) {
        try {
            $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object {
                $_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*'
            }

            return @($tasks)
        }
        catch {
            # Fall back to schtasks parsing below.
        }
    }

    try {
        $rawOutput = & schtasks.exe /Query /FO LIST /V 2>$null
        if (-not $rawOutput) {
            return @()
        }

        foreach ($line in $rawOutput) {
            if ($line -match '^TaskName:\s+(?<n>.+)$') {
                $currentTaskName = $Matches['n'].Trim()

                if ($currentTaskName -like '\Microsoft\Windows\EnterpriseMgmt\*') {
                    $leafName = Split-Path -Path $currentTaskName -Leaf
                    $taskPath = $currentTaskName.Substring(0, $currentTaskName.Length - $leafName.Length)

                    $tasks += [pscustomobject]@{
                        TaskName = $leafName
                        TaskPath = $taskPath
                    }
                }
            }
        }
    }
    catch {
        # schtasks parsing failed as well - report an empty task list upstream.
    }

    return @($tasks)
}

# Trigger one EnterpriseMgmt task via Start-ScheduledTask with schtasks fallback.
function Start-EnterpriseMgmtTask {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Task
    )

    $taskPath = $Task.TaskPath
    if (-not $taskPath.EndsWith('\')) {
        $taskPath += '\'
    }

    $fullTaskName = "$taskPath$($Task.TaskName)"
    $started      = $false

    $startScheduledTaskCommand = Get-Command -Name Start-ScheduledTask -ErrorAction SilentlyContinue
    if ($startScheduledTaskCommand) {
        try {
            Start-ScheduledTask -TaskPath $taskPath -TaskName $Task.TaskName -ErrorAction Stop
            $started = $true
        }
        catch {
            # Start-ScheduledTask refused - fall back to schtasks.exe below.
            $started = $false
        }
    }

    if (-not $started) {
        $started = Run-TaskBySchtasks -FullTaskName $fullTaskName
    }

    return [pscustomobject]@{
        FullTaskName = $fullTaskName
        Success      = $started
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # The IME service running is the core observable outcome of this fix;
        # at least one triggered task is enforced separately in MAIN reporting.
        $imeAfter = Get-ServiceInfo -Name $ImeServiceName
        return ($null -ne $imeAfter -and $imeAfter.State -eq 'Running')
    }
    catch {
        Write-SyncFixerEntry "Verification could not read the IME service state: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> per-target fix -> post-verify -> exit 0 / 1 / 2.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-SyncFixerEntry "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-SyncFixerEntry "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount     = 0
    $targetCount            = 0
    $script:TriggeredCount  = 0
    $script:SkipRemaining   = $false
    $script:NoTasksFound    = $false

    Write-SyncFixerEntry "Executing remediation actions..." -Level 'Info'

    # Target 1: validate and start the MDM transport service.
    $targetCount++
    Invoke-FixTarget -TargetName "Ensure $DmServiceName running" -Fix {
        $dmResult = Ensure-ServiceRunning -Name $DmServiceName
        if (-not $dmResult.Success) {
            throw $dmResult.Result
        }
        Write-SyncFixerEntry "DmWapPushService action result: $($dmResult.Result)" -Level 'Info'
    }

    # Target 2: restart or start the Intune Management Extension service.
    # A missing IME aborts the remaining steps (legacy early-exit preserved).
    if (-not $script:SkipRemaining) {
        $targetCount++
        $failuresBeforeIme = $script:FailedCount
        Invoke-FixTarget -TargetName "Restart or start $ImeServiceName" -Fix {
            $restarted = Restart-IME
            if (-not $restarted) {
                throw "IME service did not reach running state"
            }
        }
        if ($script:FailedCount -gt $failuresBeforeIme) {
            $script:SkipRemaining = $true
        }
    }

    # Target group 3: discover and trigger every EnterpriseMgmt scheduled task.
    if (-not $script:SkipRemaining) {
        Write-SyncFixerEntry 'Discovering EnterpriseMgmt scheduled tasks...' -Level 'Info'
        $tasks = @(Get-EnterpriseMgmtTasks)

        Write-SyncFixerEntry "EnterpriseMgmt tasks discovered: $($tasks.Count)" -Level 'Info'

        if ($tasks.Count -lt 1) {
            $script:NoTasksFound = $true
            Write-SyncFixerEntry 'No EnterpriseMgmt scheduled tasks were found.' -Level 'Error'
        }

        foreach ($task in $tasks) {
            $targetCount++
            $currentTask = $task
            Invoke-FixTarget -TargetName "Trigger task $($currentTask.TaskName)" -Fix {
                $taskResult = Start-EnterpriseMgmtTask -Task $currentTask
                if (-not $taskResult.Success) {
                    throw "Failed to trigger task: $($taskResult.FullTaskName)"
                }
                $script:TriggeredCount++
                Write-SyncFixerEntry "Triggered task: $($taskResult.FullTaskName)" -Level 'Info'
            }
        }

        Write-SyncFixerEntry "EnterpriseMgmt task trigger summary: Attempted=$($tasks.Count) | Triggered=$($script:TriggeredCount)" -Level 'Info'
    }

    # --- Verify ---
    Write-SyncFixerEntry "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = (-not $script:SkipRemaining) -and (-not $script:NoTasksFound) -and (Test-FixApplied) -and ($script:TriggeredCount -ge 1)

    if ($targetCount -gt 0 -and $script:FailedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $($script:FailedCount))"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Intune stuck-sync remediation completed successfully." -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
    }
}
catch {
    $script:RemediationResult.Status = "Error"
    $script:RemediationResult.Error = @{
        Message    = $_.Exception.Message
        Type       = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
    }
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally {
    Write-Log -Message "Cleanup complete." -Level 'DEBUG'
}



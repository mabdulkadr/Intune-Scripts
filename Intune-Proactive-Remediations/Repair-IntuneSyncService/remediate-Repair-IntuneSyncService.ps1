<#
.TITLE
    Remediation - Repair Intune Sync Services

.SYNOPSIS
    Repairs a stalled Intune sync state by fixing services and re-triggering management tasks.

.DESCRIPTION
    Paired remediation for Repair-IntuneSyncService. Runs only when
    detect-Repair-IntuneSyncService.ps1 returns exit 1. Ensures DmWapPushService
    is running, restarts (or starts) IntuneManagementExtension, then triggers the
    scheduled tasks used for Intune/MDM sync under
    \Microsoft\Windows\EnterpriseMgmt\. Performs: (1) pre-remediation validation,
    (2) service recovery and per-task triggers with failure tracking, (3)
    post-remediation verification (at least one sync task triggered), (4)
    structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Intune,Services

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Repair-IntuneSyncService.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - starts/restarts services and runs EnterpriseMgmt scheduled tasks.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.2
    - Legacy release prior to canonical migration
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Repair-IntuneSyncService.ps1
    Recovers services, triggers sync tasks, and verifies; exits 0 on success.

.EXAMPLE
    .\remediate-Repair-IntuneSyncService.ps1
    Exits 1 if no sync task could be triggered, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Preserved waits: 2 seconds after starting a stopped transport service and
      SleepAfterIME = 8 seconds before re-checking the IME service state.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\Repair-IntuneSyncService\Repair-IntuneSyncService-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Repair-IntuneSyncService'
$ScriptMode   = 'Remediation'

$DmServiceName  = 'DmWapPushService'
$ImeServiceName = 'IntuneManagementExtension'
$SleepAfterIME  = 8
$ImeHealthLog   = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\HealthIntune-Management-Scripts.log'

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

# Mirrors remediation entries into the IME health log (preserved legacy dual-write).
function Write-MirroredLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    Write-RemediationLog -Message $Message -Level $Level

    # Best-effort mirror into the IME health log when its folder exists (legacy behavior).
    try {
        $imeLogFolder = Split-Path -Path $ImeHealthLog -Parent
        if (Test-Path -LiteralPath $imeLogFolder) {
            $mirrorLine = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
                $(switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }), $Message
            Add-Content -Path $ImeHealthLog -Value $mirrorLine -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }
    catch [System.IO.IOException] {
        # IME health log temporarily locked - skip this mirror write only.
    }
    catch [System.UnauthorizedAccessException] {
        # Access denied on the IME health log - skip this mirror write only.
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # The MDM transport service must exist before any recovery is attempted.
        # The IME service may legitimately be absent; that is handled during the fix.
        $service = Get-CimInstance Win32_Service -Filter "Name='$DmServiceName'" -ErrorAction Stop
        if (-not $service) {
            throw "Required service is missing: $DmServiceName"
        }

        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-MirroredLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
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
        Write-MirroredLog "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# Returns CIM service info, or $null when the service is not installed.
function Get-ServiceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
}

# Starts the named service when stopped and reports a structured result.
function Ensure-ServiceRunning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $serviceInfo = Get-ServiceInfo -Name $Name
    if (-not $serviceInfo) {
        return @{
            Ok     = $false
            Result = 'NotFound'
        }
    }

    try {
        $service = Get-Service -Name $Name -ErrorAction Stop
    }
    catch {
        return @{
            Ok     = $false
            Result = "GetServiceFailed: $($_.Exception.Message)"
        }
    }

    if ($service.Status -eq 'Running') {
        return @{
            Ok     = $true
            Result = 'AlreadyRunning'
        }
    }

    try {
        Start-Service -Name $Name -ErrorAction Stop
        Start-Sleep -Seconds 2

        $service = Get-Service -Name $Name -ErrorAction Stop
        if ($service.Status -eq 'Running') {
            return @{
                Ok     = $true
                Result = 'Started'
            }
        }

        return @{
            Ok     = $false
            Result = 'StartAttemptedButNotRunning'
        }
    }
    catch {
        return @{
            Ok     = $false
            Result = "StartFailed: $($_.Exception.Message)"
        }
    }
}

# Restarts (or starts) the Intune Management Extension service; returns success.
function Restart-ImeService {
    $imeInfo = Get-ServiceInfo -Name $ImeServiceName
    if (-not $imeInfo) {
        Write-MirroredLog "IME not installed: $ImeServiceName" -Level 'Error'
        return $false
    }

    try {
        $service = Get-Service -Name $ImeServiceName -ErrorAction Stop

        if ($service.Status -eq 'Running') {
            Write-MirroredLog 'Restarting IntuneManagementExtension service.' -Level 'Info'
            Restart-Service -Name $ImeServiceName -Force -ErrorAction Stop
        }
        else {
            Write-MirroredLog 'Starting IntuneManagementExtension service.' -Level 'Info'
            Start-Service -Name $ImeServiceName -ErrorAction Stop
        }

        Start-Sleep -Seconds $SleepAfterIME
        $service = Get-Service -Name $ImeServiceName -ErrorAction Stop

        if ($service.Status -eq 'Running') {
            Write-MirroredLog 'IntuneManagementExtension service is running.' -Level 'Info'
            return $true
        }

        Write-MirroredLog ("IntuneManagementExtension failed to reach running state. Current state: {0}" -f $service.Status) -Level 'Error'
        return $false
    }
    catch {
        Write-MirroredLog ("Failed to start or restart IntuneManagementExtension: {0}" -f $_.Exception.Message) -Level 'Error'
        return $false
    }
}

# Runs one scheduled task via schtasks.exe as a fallback; returns success.
function Invoke-ScheduledTaskFallback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullTaskName
    )

    try {
        $process = Start-Process -FilePath 'schtasks.exe' -ArgumentList "/Run /TN `"$FullTaskName`"" -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop
        return ($process.ExitCode -eq 0)
    }
    catch {
        return $false
    }
}

# Discovers EnterpriseMgmt scheduled tasks via Get-ScheduledTask with schtasks.exe fallback.
function Get-EnterpriseMgmtTasks {
    $getScheduledTask = Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue
    if ($getScheduledTask) {
        $cmdletDiscoveryFailed = $false
        try {
            return @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*' })
        }
        catch {
            # Cmdlet discovery failed - fall back to schtasks.exe parsing below.
            $cmdletDiscoveryFailed = $true
        }
    }

    $tasks = @()
    $parseFailed = $false

    try {
        $rawTasks = & schtasks.exe /Query /FO LIST /V 2>$null
        $currentTaskName = $null

        foreach ($line in $rawTasks) {
            if ($line -match '^TaskName:\s+(?<n>.+)$') {
                $currentTaskName = $Matches['n'].Trim()

                if ($currentTaskName -like '\Microsoft\Windows\EnterpriseMgmt\*') {
                    $taskName = Split-Path -Path $currentTaskName -Leaf
                    $taskPath = $currentTaskName.Substring(0, $currentTaskName.Length - $taskName.Length)

                    $tasks += [PSCustomObject]@{
                        TaskName = $taskName
                        TaskPath = $taskPath
                    }
                }
            }
        }
    }
    catch {
        # schtasks.exe query or parsing failed - return whatever was collected.
        $parseFailed = $true
    }

    return @($tasks)
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # Success definition preserved from the legacy script: at least one
        # EnterpriseMgmt sync task must have been triggered successfully.
        return ($script:TriggeredCount -ge 1)
    }
    catch {
        Write-MirroredLog "Verification could not evaluate the trigger summary: $($_.Exception.Message)" -Level 'Error'
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
    Write-MirroredLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-MirroredLog "Performing pre-remediation checks..." -Level 'Info'

    $dmServiceInfo = Get-ServiceInfo -Name $DmServiceName
    if (-not $dmServiceInfo) {
        # Preserved legacy outcome: missing transport service is a failed
        # remediation, not a crash.
        $script:RemediationResult.Status = "Failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Required service is missing: $DmServiceName" -Level 'ERROR'
    }
    Write-MirroredLog ("DmWapPushService state: {0}; start mode: {1}" -f $dmServiceInfo.State, $dmServiceInfo.StartMode) -Level 'Info'

    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount     = 0
    $targetCount            = 0
    $script:TriggeredCount  = 0

    Write-MirroredLog "Executing remediation actions..." -Level 'Info'

    # Target 1: best-effort start of the MDM transport service (legacy semantics).
    $dmActionResult = Ensure-ServiceRunning -Name $DmServiceName
    if ($dmActionResult.Ok) {
        Write-MirroredLog ("DmWapPushService action result: {0}" -f $dmActionResult.Result) -Level 'Info'
    }
    else {
        $targetCount++
        $script:FailedCount++
        Write-MirroredLog ("DmWapPushService action result: {0}" -f $dmActionResult.Result) -Level 'Warning'
    }

    # Target 2: recover the Intune Management Extension service.
    $targetCount++
    $imeRecovered = Invoke-FixTarget -TargetName "Recover service: $ImeServiceName" -Fix {
        if (-not (Restart-ImeService)) {
            throw "Failed to recover IntuneManagementExtension service."
        }
    }

    # Targets 3..N: trigger every discovered EnterpriseMgmt sync task.
    $attempted = 0

    if ($imeRecovered) {
        Write-MirroredLog 'Discovering EnterpriseMgmt scheduled tasks.' -Level 'Info'
        $tasks = @(Get-EnterpriseMgmtTasks)
        Write-MirroredLog ("EnterpriseMgmt tasks discovered: {0}" -f $tasks.Count) -Level 'Info'

        if ($tasks.Count -lt 1) {
            Write-MirroredLog 'No EnterpriseMgmt scheduled tasks were found.' -Level 'Error'
        }
        else {
            $startScheduledTask = Get-Command -Name Start-ScheduledTask -ErrorAction SilentlyContinue

            foreach ($task in $tasks) {
                $attempted++
                $taskPath = $task.TaskPath

                if (-not $taskPath.EndsWith('\')) {
                    $taskPath += '\'
                }

                $fullTaskName = '{0}{1}' -f $taskPath, $task.TaskName

                $targetCount++
                $taskTriggered = Invoke-FixTarget -TargetName "Trigger scheduled task: $fullTaskName" -Fix {
                    $triggeredOk = $false

                    if ($startScheduledTask) {
                        try {
                            Start-ScheduledTask -TaskPath $taskPath -TaskName $task.TaskName -ErrorAction Stop
                            $triggeredOk = $true
                        }
                        catch {
                            # Cmdlet trigger failed - the schtasks.exe fallback runs next.
                            $triggeredOk = $false
                        }
                    }

                    if (-not $triggeredOk) {
                        $triggeredOk = Invoke-ScheduledTaskFallback -FullTaskName $fullTaskName
                    }

                    if (-not $triggeredOk) {
                        throw "Failed to trigger scheduled task: $fullTaskName"
                    }
                }

                if ($taskTriggered) {
                    $script:TriggeredCount++
                    Write-MirroredLog "Triggered scheduled task: $fullTaskName" -Level 'Info'
                }
            }
        }
    }

    Write-MirroredLog ("Task trigger summary: Attempted={0}; Triggered={1}" -f $attempted, $script:TriggeredCount) -Level 'Info'

    # --- Verify ---
    Write-MirroredLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $script:FailedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $script:FailedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message 'Intune sync remediation completed successfully.' -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message 'No EnterpriseMgmt sync task was triggered successfully.' -Level 'ERROR'
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

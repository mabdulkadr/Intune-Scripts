<#
.TITLE
    Full Intune Client Repair Engine

.SYNOPSIS
    Performs a best-effort end-to-end repair of the Intune client stack on Windows devices.

.DESCRIPTION
    Performs a best-effort end-to-end repair of the Intune client stack on Windows devices:
      1) Restarts key Intune/MDM services (IME + MDM + Notification)
      2) Triggers MDM policy/compliance sync (EnterpriseMgmt tasks + optional deviceenroller)
      3) Kicks IME for Win32 apps / scripts / remediations (service + process)
      4) (Deep mode) Repairs download pipeline (BITS/DO) and Windows Update services
      5) (Deep mode) Clears IME cache (Content + Logs optional) and relaunches IME cleanly
      6) (Deep mode) Flushes MDM scheduled task channel by starting all EnterpriseMgmt tasks

    Exit contract:
    Exit 0 = success (all stages completed; best-effort per stage)
    Exit 1 = script error (caller should retry)

    Elevation behavior: detects admin at runtime; if not elevated, self-relaunches via
    Start-Process -Verb RunAs and the original instance exits 0 silently. Degrades
    gracefully on Windows builds that lack a service.

.TAGS
    Intune,Repair,IME,MDM,Troubleshooting

.PLATFORM
    Windows

.MINROLE
    Local Administrator

.PERMISSIONS
    None (local SYSTEM context) - restarts services and triggers scheduled tasks; no Graph API calls.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-27)
    - Migrated to canonical Enterprise Admin structure ([CmdletBinding], Write-Log, Finish-Script, try/catch/finally)
    - Fixed: header opens with <# instead of <#!; added .MINROLE field
    - Fixed: -Wait on self-elevation Start-Process; primary instance exits 0 on self-relaunch
    - Fixed: explicit exit codes (Finish-Script) instead of bare exit / exit 1
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Admin header standards (canonical field order, PS 5.1 contract)
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-27

.EXAMPLE
    .\Full-Intune-Client-Repair-Engine.ps1
    Runs the standard repair pass.

.EXAMPLE
    .\Full-Intune-Client-Repair-Engine.ps1 -DeepRepair
    Runs the full deep-clean pass including BITS repair and IME cache reset.

.EXAMPLE
    .\Full-Intune-Client-Repair-Engine.ps1 -DeepRepair -ClearImeLogs
    Deep pass that also clears the IME Logs folder (usually retained).

.NOTES
    - Best-effort: behavior varies by Windows build and enrollment state.
    - Does NOT unenroll/re-enroll the device.
    - Requires admin; auto-relaunches elevated when not.
    - Logs: <SystemDrive>\IntuneLogs\Full-Intune-Client-Repair-Engine\Full-Intune-Client-Repair-Engine.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$DeepRepair,
    [switch]$EnablePolicySync = [bool]$true,
    [switch]$EnableDeviceEnroller = [bool]$true,
    [switch]$EnableImeKick = [bool]$true,
    [switch]$RestartImeProcess = [bool]$true,
    [switch]$EnableDeliveryRepair = [bool]$true,
    [switch]$EnableImeCacheCleanup = [bool]$true,
    [switch]$ClearImeLogs
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and stage toggles.
# ============================================================================

$SolutionName = 'Full-Intune-Client-Repair-Engine'
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
# ELEVATION DETECTION (runtime, no hard requirement)
# ============================================================================

# Returns $true when the current process is elevated (Administrator).
function Test-IsElevated {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunches the current script as Administrator via Start-Process -Verb RunAs.
function Invoke-SelfElevation {
    $self = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($self) -or -not (Test-Path -LiteralPath $self)) {
        return $false
    }

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$self`"")
    if ($DeepRepair)            { $argList += '-DeepRepair' }
    if ($ClearImeLogs)          { $argList += '-ClearImeLogs' }

    $process = Start-Process -Verb RunAs -FilePath 'powershell.exe' -ArgumentList $argList -PassThru
    $process.WaitForExit()
    return $true
}

# ============================================================================
# SERVICE HELPERS
# ============================================================================

# Returns current service status or $null when service is not registered.
function Get-ServiceStatusSafe {
    param([Parameter(Mandatory = $true)][string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return $null }
    return $svc.Status
}

# Restart a single service using Restart-Service with a stop/start fallback.
function Restart-ServiceBestEffort {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Name)

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log -Message "Service not found: $Name" -Level 'WARNING'
        return
    }

    try {
        Write-Log -Message "Restarting: $Name" -Level 'INFO'
        Restart-Service -Name $Name -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    }
    catch {
        try {
            if ($svc.Status -eq 'Running') {
                Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            Start-Service -Name $Name -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Log -Message "Restart failed: $Name - $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    $status = Get-ServiceStatusSafe -Name $Name
    if ($status -eq 'Running') {
        Write-Log -Message "Status: $Name = $status" -Level 'SUCCESS'
    }
    elseif ($status) {
        Write-Log -Message "Status: $Name = $status (manual trigger can be normal)" -Level 'WARNING'
    }
    else {
        Write-Log -Message "Status: $Name unknown" -Level 'WARNING'
    }
}

# ============================================================================
# MDM / ENTERPRISE MGMT HELPERS
# ============================================================================

# Resolves the per-device enrollment GUID from the EnterpriseMgmt scheduled task path.
function Get-EnrollmentGuid {
    try {
        $tasks = Get-ScheduledTask -TaskPath '\Microsoft\Windows\EnterpriseMgmt\' -ErrorAction Stop
        $paths = $tasks | Select-Object -ExpandProperty TaskPath -Unique
    }
    catch {
        try {
            $paths = (Get-ScheduledTask -ErrorAction Stop | Select-Object -ExpandProperty TaskPath -Unique) |
                     Where-Object { $_ -like "\Microsoft\Windows\EnterpriseMgmt\*\\" }
        }
        catch {
            return $null
        }
    }

    foreach ($p in $paths) {
        $m = [regex]::Match($p, "\\Microsoft\\Windows\\EnterpriseMgmt\\(?<g>[^\\]+)\\")
        if ($m.Success -and -not [string]::IsNullOrWhiteSpace($m.Groups['g'].Value)) {
            return $m.Groups['g'].Value
        }
    }
    return $null
}

# Starts every enabled EnterpriseMgmt scheduled task for the given enrollment GUID.
function Start-EnterpriseMgmtTasks {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$EnrollmentGuid)

    $taskPath = "\Microsoft\Windows\EnterpriseMgmt\{0}\" -f $EnrollmentGuid
    $tasks = @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue)

    if (-not $tasks -or $tasks.Count -eq 0) {
        Write-Log -Message "No tasks found under $taskPath" -Level 'WARNING'
        return
    }

    # Conservative excludes: avoid Login/Logout that interrupt the active session.
    $exclude = @('Login', 'Logout')
    $startable = $tasks | Where-Object {
        $_.State -ne 'Disabled' -and ($exclude -notcontains $_.TaskName)
    }

    foreach ($t in $startable) {
        try {
            Write-Log -Message "Starting task: $($t.TaskName)" -Level 'INFO'
            Start-ScheduledTask -TaskName $t.TaskName -TaskPath $taskPath -ErrorAction Stop
            Start-Sleep -Milliseconds 500
            Write-Log -Message "Started task: $($t.TaskName)" -Level 'SUCCESS'
        }
        catch {
            Write-Log -Message "Task failed: $($t.TaskName) - $($_.Exception.Message)" -Level 'WARNING'
        }
    }
}

# ============================================================================
# REPAIR STAGES
# ============================================================================

# Stage 1: triggers MDM policy + compliance sync via EnterpriseMgmt tasks and deviceenroller.
function Invoke-MdmPolicySync {
    Write-Log -Message "--- MDM Policy/Compliance Sync ---" -Level 'INFO'

    $guid = Get-EnrollmentGuid
    if (-not $guid) {
        Write-Log -Message "Enrollment GUID not found (EnterpriseMgmt missing). Skipping policy sync." -Level 'WARNING'
        return $null
    }

    Write-Log -Message "Enrollment GUID: $guid" -Level 'INFO'
    Start-EnterpriseMgmtTasks -EnrollmentGuid $guid

    if ($EnableDeviceEnroller) {
        $deviceEnroller = Join-Path $env:WINDIR "System32\deviceenroller.exe"
        if (Test-Path -LiteralPath $deviceEnroller) {
            try {
                $arguments = "/o {0} /c /b" -f $guid
                Write-Log -Message "Running: deviceenroller.exe $arguments" -Level 'INFO'
                $proc = Start-Process -FilePath $deviceEnroller -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
                Write-Log -Message "deviceenroller exit: $($proc.ExitCode)" -Level 'SUCCESS'
            }
            catch {
                Write-Log -Message "deviceenroller failed: $($_.Exception.Message)" -Level 'WARNING'
            }
        }
        else {
            Write-Log -Message "deviceenroller.exe not found. Skipping." -Level 'WARNING'
        }
    }

    return $guid
}

# Stage 2: kicks IntuneManagementExtension service (and optional process restart).
function Invoke-ImeKick {
    Write-Log -Message "--- IME App/Script/Remediation Kick ---" -Level 'INFO'

    try {
        $svc = Get-Service -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Log -Message "IME service not found. Skipping." -Level 'WARNING'
            return
        }

        Write-Log -Message "Restarting IntuneManagementExtension service..." -Level 'INFO'
        Restart-Service -Name 'IntuneManagementExtension' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        $status = Get-ServiceStatusSafe -Name 'IntuneManagementExtension'
        if ($status -eq 'Running') {
            Write-Log -Message "IME service status: $status" -Level 'SUCCESS'
        }
        else {
            Write-Log -Message "IME service status: $status" -Level 'WARNING'
        }
    }
    catch {
        Write-Log -Message "IME restart failed: $($_.Exception.Message)" -Level 'WARNING'
    }

    if ($RestartImeProcess) {
        try {
            $imeProc = Get-Process -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($imeProc) {
                Write-Log -Message "Restarting IntuneManagementExtension process..." -Level 'INFO'
                Stop-Process -Id $imeProc.Id -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Start-Service -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Write-Log -Message "IME process kick done." -Level 'SUCCESS'
            }
            else {
                Write-Log -Message "IME process not running (service may relaunch it). OK." -Level 'INFO'
            }
        }
        catch {
            Write-Log -Message "IME process restart failed: $($_.Exception.Message)" -Level 'WARNING'
        }
    }
}

# Stage 3 (Deep): repairs the download/update pipeline (BITS / DO / UsoSvc / wuauserv).
function Repair-DeliveryPipeline {
    Write-Log -Message "--- Download/Update Pipeline Repair (Deep) ---" -Level 'INFO'

    $svcList = @(
        'BITS',
        'DoSvc',
        'UsoSvc',
        'wuauserv'
    )

    foreach ($s in $svcList) {
        Restart-ServiceBestEffort -Name $s
    }
}

# Stage 4 (Deep): clears IME Content cache (and optionally Logs) then relaunches the service.
function Clear-ImeCache {
    Write-Log -Message "--- IME Cache Cleanup (Deep) ---" -Level 'INFO'

    $base = Join-Path ${env:ProgramFiles(x86)} "Microsoft Intune Management Extension"
    if (-not (Test-Path -LiteralPath $base)) {
        Write-Log -Message "IME folder not found: $base" -Level 'WARNING'
        return
    }

    $content = Join-Path $base 'Content'
    $logs    = Join-Path $base 'Logs'

    try {
        Write-Log -Message "Stopping IME service..." -Level 'INFO'
        Stop-Service -Name 'IntuneManagementExtension' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Log -Message "Stop IME failed: $($_.Exception.Message)" -Level 'WARNING'
    }

    if ($EnableImeCacheCleanup -and (Test-Path -LiteralPath $content)) {
        try {
            Write-Log -Message "Removing: $content" -Level 'INFO'
            Remove-Item -LiteralPath $content -Recurse -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Write-Log -Message "IME Content cache cleared." -Level 'SUCCESS'
        }
        catch {
            Write-Log -Message "Content cleanup failed: $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    if ($ClearImeLogs -and (Test-Path -LiteralPath $logs)) {
        try {
            Write-Log -Message "Removing: $logs" -Level 'INFO'
            Remove-Item -LiteralPath $logs -Recurse -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Write-Log -Message "IME Logs cleared." -Level 'SUCCESS'
        }
        catch {
            Write-Log -Message "Logs cleanup failed: $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    try {
        Write-Log -Message "Starting IME service..." -Level 'INFO'
        Start-Service -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        $status = Get-ServiceStatusSafe -Name 'IntuneManagementExtension'
        if ($status -eq 'Running') {
            Write-Log -Message "IME service status: $status" -Level 'SUCCESS'
        }
        else {
            Write-Log -Message "IME service status: $status" -Level 'WARNING'
        }
    }
    catch {
        Write-Log -Message "Start IME failed: $($_.Exception.Message)" -Level 'WARNING'
    }
}

# ============================================================================
# SERVICE SETS
# ============================================================================

$CoreServices = @(
    'IntuneManagementExtension',
    'dmwappushservice'
)

$EnrollmentCandidates = @('dmEnrollmentSvc', 'DeviceManagementEnrollmentService')

$NotificationServices = @(
    'WpnService'
)

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> log + banner -> elevation gate (relaunch if needed) -> stages -> exit 0.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Machine: $env:COMPUTERNAME | User: $env:USERDOMAIN\$env:USERNAME" -Level 'INFO'
    Write-Log -Message "Mode: $(if ($DeepRepair) { 'DeepRepair' } else { 'Standard' })" -Level 'INFO'

    # --- Elevation gate: relaunch as admin and exit primary instance ---
    if (-not (Test-IsElevated)) {
        Write-Log -Message "Not elevated - attempting self-relaunch as Administrator..." -Level 'WARNING'
        if (Invoke-SelfElevation) {
            Finish-Script -ExitCode 0 -Message "Re-launched elevated; primary instance exiting." -Level 'INFO'
        }
        else {
            Finish-Script -ExitCode 1 -Message "Cannot self-elevate: script path unavailable in this host." -Level 'ERROR'
        }
    }
    Write-Log -Message "Running as Administrator." -Level 'SUCCESS'

    # --- Stage: core services ---
    Write-Log -Message "--- Restart Intune/MDM Core Services ---" -Level 'INFO'
    foreach ($s in $CoreServices) {
        Restart-ServiceBestEffort -Name $s
    }

    # Enrollment service name differs by Windows build; try both.
    $enrollmentRestarted = $false
    foreach ($s in $EnrollmentCandidates) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            Restart-ServiceBestEffort -Name $s
            $enrollmentRestarted = $true
            break
        }
    }
    if (-not $enrollmentRestarted) {
        Write-Log -Message "Enrollment service not found (dmEnrollmentSvc/DeviceManagementEnrollmentService)." -Level 'WARNING'
    }

    Write-Log -Message "--- Restart Notification Services ---" -Level 'INFO'
    foreach ($s in $NotificationServices) {
        Restart-ServiceBestEffort -Name $s
    }

    # --- Stage: MDM policy sync + IME kick ---
    $EnrollmentGuid = $null
    if ($EnablePolicySync) {
        $EnrollmentGuid = Invoke-MdmPolicySync
    }
    if ($EnableImeKick) {
        Invoke-ImeKick
    }

    # --- Stage: Deep repair (optional) ---
    if ($DeepRepair) {
        if ($EnableDeliveryRepair) {
            Repair-DeliveryPipeline
        }
        if ($EnableImeCacheCleanup) {
            Clear-ImeCache
        }
        if ($EnablePolicySync -and $EnrollmentGuid) {
            Write-Log -Message "--- MDM Task Channel Flush (Deep) ---" -Level 'INFO'
            Start-EnterpriseMgmtTasks -EnrollmentGuid $EnrollmentGuid
        }
        if ($EnableImeKick) {
            Write-Log -Message "--- Final IME Kick (Deep) ---" -Level 'INFO'
            Invoke-ImeKick
        }
    }

    Finish-Script -ExitCode 0 -Message "Repair pass complete." -Level 'SUCCESS'
}
catch {
    Finish-Script -ExitCode 1 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}

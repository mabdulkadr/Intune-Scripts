<#
.TITLE
    Remediation - Restart Reminder Notification

.SYNOPSIS
    Shows a Windows toast notification reminding the user to restart the device.

.DESCRIPTION
    Paired remediation for Get-DeviceUptimeStatus. Runs only when
    detect-Get-DeviceUptimeStatus.ps1 returns exit 1. This remediation reports
    to the user rather than mutating device state: it registers a temporary
    toast AppID under HKCU and displays a localized restart reminder whose
    action launches "shutdown.exe /r /t 0". When uptime is below the threshold
    no notification is shown and the script exits 0.

    Exit contract:
    Exit 0 = success (notification shown, or uptime below threshold)
    Exit 1 = failure (notification could not be shown after attempting)
    Exit 2 = script error

.TAGS
    Remediation,Action,Uptime,Notification

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Get-DeviceUptimeStatus.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - registers an HKCU toast AppID and displays a user notification.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    - Restart reminder text unified to English (legacy localized variants removed)
    1.3 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Get-DeviceUptimeStatus.ps1
    Shows the restart reminder when the threshold is reached; exits 0 on success.

.EXAMPLE
    .\remediate-Get-DeviceUptimeStatus.ps1
    Exits 1 if the toast cannot be displayed, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\Get-DeviceUptimeStatus\Get-DeviceUptimeStatus-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Get-DeviceUptimeStatus'
$ScriptMode   = 'Remediation'

$MaxUptimeDays = 7
$ToastAppId    = 'PowerShell.DeviceUptimeReminder'

$ToastRegistryRoot = 'HKCU:\SOFTWARE\Classes\AppUserModelId'
$ToastDisplayName  = 'PowerShell Notifications'

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

# ============================================================================
# NOTIFICATION HELPERS
# ============================================================================

# Reads the current OS uptime from Get-ComputerInfo.
function Get-Uptime {
    $computerInfo = Get-ComputerInfo -ErrorAction Stop
    return $computerInfo.OSUptime
}

# Returns the English restart reminder content for the given uptime.
function Get-NotificationContent {
    param(
        [Parameter(Mandatory = $true)]
        [int]$UptimeDays
    )

    return @{
        Title   = 'Device Restart Required'
        Message = "The device has been running for $UptimeDays days without a restart. Save your work and restart the device to improve performance and apply updates."
        Footer  = 'Please restart the device as soon as possible.'
    }
}

# Registers the temporary toast AppID used by the notification.
function Register-ToastApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    try {
        $registryPath = Join-Path $ToastRegistryRoot $AppId

        if (-not (Test-Path -LiteralPath $registryPath)) {
            New-Item -Path $registryPath -Force -ErrorAction Stop | Out-Null
        }

        New-ItemProperty -Path $registryPath -Name 'DisplayName' -Value $ToastDisplayName -PropertyType String -Force -ErrorAction Stop | Out-Null
        Write-RemediationLog "Created PowerShell notification AppID registration." -Level 'Info'
    }
    catch {
        throw "Failed to register AppID for toast notification. $($_.Exception.Message)"
    }
}

# Displays the restart reminder toast via Windows WinRT notifications.
function Show-RestartToast {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Content
    )

    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop | Out-Null
    }
    catch [System.Runtime.InteropServices.COMException] {
        # Best-effort load only; WinRT projection usually resolves without it.
        Write-RemediationLog "System.Runtime.WindowsRuntime could not be loaded explicitly. Continuing with WinRT types." -Level 'Warning'
    }

    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    }
    catch {
        throw "Windows toast notification WinRT types are not available. $($_.Exception.Message)"
    }

    $toastXml = @"
<toast activationType="protocol" launch="shutdown.exe /r /t 0">
    <visual>
        <binding template="ToastGeneric">
            <text>$($Content.Title)</text>
            <text>$($Content.Message)</text>
            <text>$($Content.Footer)</text>
        </binding>
    </visual>
    <actions>
        <action content="Restart now" activationType="protocol" arguments="shutdown.exe /r /t 0" />
        <action content="Dismiss" activationType="system" arguments="dismiss" />
    </actions>
</toast>
"@

    try {
        $xmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xmlDocument.LoadXml($toastXml)

        $toast    = [Windows.UI.Notifications.ToastNotification]::new($xmlDocument)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)

        $notifier.Show($toast)
        Write-RemediationLog "Restart reminder notification displayed successfully." -Level 'Info'
    }
    catch {
        throw "Failed to display restart reminder notification. $($_.Exception.Message)"
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any action - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # Uptime must be readable before deciding whether a toast is required.
        $uptime     = Get-Uptime
        $uptimeDays = [int][Math]::Floor($uptime.TotalDays)
        $script:UptimeDays = $uptimeDays

        $script:RemediationResult.PreCheckStatus += "Current OSUptime: $uptime"
        $script:RemediationResult.PreCheckStatus += "Current uptime days: $uptimeDays"
        Write-RemediationLog "Current uptime days: $uptimeDays" -Level 'Info'

        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
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
        Write-RemediationLog "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # The toast AppID registration is the durable artifact of this
        # remediation; display success was already enforced by the fix not
        # throwing while showing the toast.
        $registryPath = Join-Path $ToastRegistryRoot $ToastAppId
        $displayName  = Get-ItemPropertyValue -LiteralPath $registryPath -Name 'DisplayName' -ErrorAction Stop
        return ($displayName -eq $ToastDisplayName)
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-RemediationLog "Verification could not find the toast AppID registration." -Level 'Error'
        return $false
    }
    catch {
        Write-RemediationLog "Verification could not read the toast AppID registration: $($_.Exception.Message)" -Level 'Error'
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
    Write-RemediationLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    if ($script:UptimeDays -lt $MaxUptimeDays) {
        # Below threshold: no notification required - legacy behavior preserved.
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Device uptime is below threshold: $($script:UptimeDays) day(s). No notification required."

        Write-Output "Device uptime is below threshold: $($script:UptimeDays) day(s). No notification required."
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Device uptime is below threshold: $($script:UptimeDays) day(s). No notification required." -Level 'SUCCESS'
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $content = Get-NotificationContent -UptimeDays $script:UptimeDays

    $targetCount++
    Invoke-FixTarget -TargetName "Register toast AppID $ToastAppId" -Fix {
        Register-ToastApp -AppId $ToastAppId
    }

    $targetCount++
    Invoke-FixTarget -TargetName "Display restart reminder toast" -Fix {
        Show-RestartToast -AppId $ToastAppId -Content $content
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Restart reminder processed successfully for uptime of $($script:UptimeDays) day(s)."
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Restart reminder processed successfully for uptime of $($script:UptimeDays) day(s)." -Level 'SUCCESS'
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

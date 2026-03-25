<#
.SYNOPSIS
    Displays a restart reminder notification when device uptime reaches the configured threshold.

.DESCRIPTION
    This remediation script checks the current device uptime and, when the configured
    threshold is reached, shows a Windows toast notification reminding the user to restart.

    The script:
    - Reads device uptime using Get-ComputerInfo
    - Detects the preferred UI language
    - Registers a temporary AppID for toast notifications
    - Displays a localized restart reminder toast notification
    - Writes detailed log output to the local Intune log folder

    Exit codes:
    - Exit 0: Notification displayed successfully or uptime is below threshold
    - Exit 1: Script failed

.RUN AS
    System or User

.EXAMPLE
    .\Get-DeviceUptimeStatus--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.3
#>

#region -- BOOTSTRAP -----------------------------------------------------------

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#endregion -- BOOTSTRAP --------------------------------------------------------

#region -- CONFIGURATION -------------------------------------------------------

$ScriptName    = 'Get-DeviceUptimeStatus--Remediate.ps1'
$SolutionName  = 'Get-DeviceUptimeStatus'
$ScriptMode    = 'Remediation'
$MaxUptimeDays = 7

$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
elseif ($env:SystemRoot) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    'C:'
}

$LogRoot    = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile    = Join-Path $LogRoot 'Get-DeviceUptimeStatus--Remediate.txt'
$BannerLine = '=' * 78
$ToastAppId = 'PowerShell.DeviceUptimeReminder'

#endregion -- CONFIGURATION ----------------------------------------------------

#region -- FUNCTIONS -----------------------------------------------------------

function Initialize-Log {
    try {
        if (-not (Test-Path -Path $LogRoot)) {
            New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }

        return $true
    }
    catch {
        Write-Host ("Logging initialization failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

function Write-Banner {
    $Title = '{0} | {1}' -f $SolutionName, $ScriptMode
    $Lines = @(
        ''
        $BannerLine
        $Title
        $BannerLine
    )

    foreach ($Line in $Lines) {
        if ($Line -eq $Title) {
            Write-Host $Line -ForegroundColor White
        }
        else {
            Write-Host $Line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            try {
                Add-Content -Path $LogFile -Value $Line -Encoding UTF8
            }
            catch {}
        }
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $Line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
    exit $ExitCode
}

function Get-ExecutionIdentity {
    try {
        $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if ($CurrentIdentity.IsSystem) {
            return 'NT AUTHORITY\SYSTEM'
        }

        return $CurrentIdentity.Name
    }
    catch {
        return $env:USERNAME
    }
}

function Get-Uptime {
    $ComputerInfo = Get-ComputerInfo -ErrorAction Stop
    return $ComputerInfo.OSUptime
}

function Get-NotificationLanguage {
    try {
        $CultureName = (Get-UICulture).Name

        if ($CultureName -like 'ar*') {
            return 'ar-SA'
        }

        return 'en-US'
    }
    catch {
        return 'en-US'
    }
}

function Get-NotificationContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Language,

        [Parameter(Mandatory = $true)]
        [int]$UptimeDays
    )

    if ($Language -eq 'ar-SA') {
        return @{
            Title   = 'إعادة تشغيل الجهاز مطلوبة'
            Message = "الجهاز يعمل منذ $UptimeDays يومًا بدون إعادة تشغيل. يُنصح بحفظ العمل ثم إعادة تشغيل الجهاز لتحسين الأداء وتطبيق التحديثات."
            Footer  = 'يرجى إعادة التشغيل في أقرب وقت ممكن.'
        }
    }

    return @{
        Title   = 'Device Restart Required'
        Message = "The device has been running for $UptimeDays days without a restart. Save your work and restart the device to improve performance and apply updates."
        Footer  = 'Please restart the device as soon as possible.'
    }
}

function Register-ToastApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    try {
        $RegistryPath = 'HKCU:\SOFTWARE\Classes\AppUserModelId\' + $AppId

        if (-not (Test-Path -Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force -ErrorAction Stop | Out-Null
        }

        New-ItemProperty -Path $RegistryPath -Name 'DisplayName' -Value 'PowerShell Notifications' -PropertyType String -Force -ErrorAction Stop | Out-Null
        Write-Log -Message 'Created PowerShell notification AppID registration.'
    }
    catch {
        throw "Failed to register AppID for toast notification. $($_.Exception.Message)"
    }
}

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
    catch {
        Write-Log -Level 'WARNING' -Message 'System.Runtime.WindowsRuntime could not be loaded explicitly. Continuing with WinRT types.'
    }

    try {
        $Null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $Null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    }
    catch {
        throw "Windows toast notification WinRT types are not available. $($_.Exception.Message)"
    }

    $ToastXml = @"
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

    if ((Get-NotificationLanguage) -eq 'ar-SA') {
        $ToastXml = @"
<toast activationType="protocol" launch="shutdown.exe /r /t 0">
    <visual>
        <binding template="ToastGeneric">
            <text>إعادة تشغيل الجهاز مطلوبة</text>
            <text>$($Content.Message)</text>
            <text>$($Content.Footer)</text>
        </binding>
    </visual>
    <actions>
        <action content="إعادة التشغيل الآن" activationType="protocol" arguments="shutdown.exe /r /t 0" />
        <action content="إغلاق" activationType="system" arguments="dismiss" />
    </actions>
</toast>
"@
    }

    try {
        $XmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument
        $XmlDocument.LoadXml($ToastXml)

        $Toast = [Windows.UI.Notifications.ToastNotification]::new($XmlDocument)
        $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)

        $Notifier.Show($Toast)
        Write-Log -Level 'SUCCESS' -Message 'Restart reminder notification displayed successfully.'
    }
    catch {
        throw "Failed to display restart reminder notification. $($_.Exception.Message)"
    }
}

#endregion -- FUNCTIONS --------------------------------------------------------

#region -- MAIN ----------------------------------------------------------------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    Write-Log -Message ("Running as: {0}" -f (Get-ExecutionIdentity))
    Write-Log -Message ("Checking whether device uptime reached {0} day(s)." -f $MaxUptimeDays)

    $Uptime = Get-Uptime
    $UptimeDays = [int][Math]::Floor($Uptime.TotalDays)

    Write-Log -Message ("Current OSUptime: {0}" -f $Uptime)
    Write-Log -Message ("Current uptime days: {0}" -f $UptimeDays)

    if ($UptimeDays -lt $MaxUptimeDays) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Device uptime is below threshold: {0} day(s). No notification required." -f $UptimeDays)
    }

    $Language = Get-NotificationLanguage
    Write-Log -Message ("Selected notification language: {0}" -f $Language)

    $Content = Get-NotificationContent -Language $Language -UptimeDays $UptimeDays

    Register-ToastApp -AppId $ToastAppId
    Show-RestartToast -AppId $ToastAppId -Content $Content

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Restart reminder processed successfully for uptime of {0} day(s)." -f $UptimeDays)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation failed: {0}" -f $_.Exception.Message)
}

#endregion -- MAIN -------------------------------------------------------------
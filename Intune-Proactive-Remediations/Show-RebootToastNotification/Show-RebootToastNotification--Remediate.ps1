<#
.SYNOPSIS
    Shows a simple toast asking the user to reboot the machine.

.DESCRIPTION
    This remediation script uses `Windows.UI.Notifications.ToastNotificationManager`
    and the built-in `ToastText02` template to display a basic two-line reboot
    reminder.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Show-RebootToastNotification--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Show-RebootToastNotification--Remediate.ps1'
$SolutionName = 'Show-RebootToastNotification'
$ScriptMode   = 'Remediation'
$ToastTitle   = 'Please Restart your Machine'
$ToastText    = 'Your computer has been on for more than 7 days, please reboot when possible'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Show-RebootToastNotification--Remediate.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

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
        Write-Host "Logging initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Write-Banner {
    $title = "{0} | {1}" -f $SolutionName, $ScriptMode
    $lines = @('', $BannerLine, $title, $BannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        }
        else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
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

    $line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
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

function Show-Notification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $rawXml = [xml]$template.GetXml()
    ($rawXml.toast.visual.binding.text | Where-Object { $_.id -eq '1' }).AppendChild($rawXml.CreateTextNode($Title)) > $null
    ($rawXml.toast.visual.binding.text | Where-Object { $_.id -eq '2' }).AppendChild($rawXml.CreateTextNode($Message)) > $null

    $serializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $serializedXml.LoadXml($rawXml.OuterXml)

    $toast = [Windows.UI.Notifications.ToastNotification]::new($serializedXml)
    $toast.Tag = 'PowerShell'
    $toast.Group = 'PowerShell'
    $toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(1)

    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('PowerShell').Show($toast)
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    Write-Log -Message 'Showing reboot reminder toast notification.'
    Show-Notification -Title $ToastTitle -Message $ToastText
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Reboot reminder toast notification was shown.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------

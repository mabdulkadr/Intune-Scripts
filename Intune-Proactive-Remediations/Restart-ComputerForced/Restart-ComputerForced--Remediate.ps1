<#
.SYNOPSIS
    Warns the user, waits, and then forces a restart when a pending reboot exists.

.DESCRIPTION
    This remediation script reads the status file created by detection,
    displays balloon notifications, waits for the configured delay, and then
    forces a restart.

.RUN AS
    System or User (according to assignment settings and script requirements).

.EXAMPLE
    .\Restart-ComputerForced--Remediate.ps1

.NOTES
    Script  : Restart-ComputerForced--Remediate.ps1
    Updated : 2026-02-15
#>

param(
    [int]$DelaySeconds = 1800
)

#region ---------- Configuration ----------

$ScriptName   = 'Restart-ComputerForced--Remediate.ps1'
$SolutionName = 'Restart-ComputerForced'
$ScriptMode   = 'Remediation'

$StatusRoot = 'C:\Intune'
$StatusFile = Join-Path $StatusRoot 'RestartStatus.txt'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Restart-ComputerForced--Remediate.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

function Initialize-Log {
    if (-not (Test-Path -Path $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
}

function Write-Banner {
    Write-Host ''
    Write-Host $BannerLine -ForegroundColor DarkGray
    Write-Host ("{0} | {1}" -f $SolutionName, $ScriptMode) -ForegroundColor White
    Write-Host $BannerLine -ForegroundColor DarkGray
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0} | {1,-7} | {2}' -f $timestamp, $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
    Write-Output $Message
    exit $ExitCode
}

function Show-BalloonTip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
        $balloon.BalloonTipText = $Text
        $balloon.BalloonTipTitle = $Title
        $balloon.Icon = [System.Drawing.SystemIcons]::Information
        $balloon.Visible = $true
        $balloon.ShowBalloonTip(10000)
        Start-Sleep -Seconds 10
        $balloon.Dispose()
    }
    catch {
        Write-Log -Message ("Unable to display balloon tip: {0}" -f $_.Exception.Message) -Level 'WARNING'
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner

    if (-not (Test-Path -Path $StatusFile)) {
        Finish-Script -Message 'Status file not found. Ensure the detection script has been run.' -ExitCode 1 -Level 'ERROR'
    }

    $restartStatus = (Get-Content -Path $StatusFile -Raw -ErrorAction Stop).Trim()
    Write-Log -Message ("Read restart status: {0}" -f $restartStatus)

    if ($restartStatus -ne 'Restart required') {
        Finish-Script -Message 'No restart is required. No action taken.' -ExitCode 0 -Level 'SUCCESS'
    }

    $minutesUntilRestart = [math]::Round($DelaySeconds / 60, 0)
    Show-BalloonTip -Title 'Restart Warning' -Text "Your system will restart in $minutesUntilRestart minutes. Please save your work."
    Write-Log -Message ("Waiting {0} seconds before the forced restart." -f $DelaySeconds) -Level 'WARNING'
    Start-Sleep -Seconds $DelaySeconds

    Show-BalloonTip -Title 'Final Restart Warning' -Text 'Your system will restart in 1 minute. Please save your work now.'
    Start-Sleep -Seconds 60

    Write-Log -Message 'Forcing system restart now.' -Level 'WARNING'
    Restart-Computer -Force -Confirm:$false
    Finish-Script -Message 'Forced restart command issued successfully.' -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------

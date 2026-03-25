<#
.SYNOPSIS
    Shows a short restart notice and schedules a restart after 60 seconds.

.DESCRIPTION
    This remediation script displays a basic message box, then schedules a
    restart using shutdown.exe with a 60-second timeout.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Stop-ComputerImmediate--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName      = 'Stop-ComputerImmediate--Remediate.ps1'
$SolutionName    = 'Stop-ComputerImmediate'
$ScriptMode      = 'Remediation'
$RestartTimeout  = 60
$ShutdownCommand = "/r /t $RestartTimeout /d p:0:0"
$NoticeTitle     = 'Restart Notice'
$NoticeMessage   = "Restart triggered in $RestartTimeout seconds."

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Stop-ComputerImmediate--Remediate.txt'
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

function Show-RestartNotice {
    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore
        [System.Windows.MessageBox]::Show($NoticeMessage, $NoticeTitle) | Out-Null
        Write-Log -Message 'Restart notice message box was displayed.'
    }
    catch {
        Write-Log -Message ("Message box could not be shown: {0}" -f $_.Exception.Message) -Level 'WARNING'
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    Show-RestartNotice
    Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList $ShutdownCommand -WindowStyle Hidden -ErrorAction Stop | Out-Null
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Restart command issued with timeout {0} second(s)." -f $RestartTimeout)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------

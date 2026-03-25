<#
.SYNOPSIS
    Checks whether Dell SupportAssist is installed on the device.

.DESCRIPTION
    This detection script searches the standard uninstall registry locations
    for an application named `Dell SupportAssist`.

    When the application is found, the script also outputs its uninstall
    string so remediation can use the same removal method.

    Exit codes:
    - Exit 0: Dell SupportAssist not found
    - Exit 1: Dell SupportAssist found

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Uninstall-DellSupportAssistApp--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Uninstall-DellSupportAssistApp--Detect.ps1'
$SolutionName = 'Uninstall-DellSupportAssistApp'
$ScriptMode   = 'Detection'

$UninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$TargetDisplayName = 'Dell SupportAssist'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Uninstall-DellSupportAssistApp--Detect.txt'
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

function Get-DellSupportAssistEntry {
    return Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $TargetDisplayName } |
        Select-Object -First 1 DisplayName, UninstallString, PSPath
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message 'Searching uninstall registry locations for Dell SupportAssist.'

    $app = Get-DellSupportAssistEntry
    if (-not $app) {
        Finish-Script -Message 'Compliant: Dell SupportAssist was not found.' -ExitCode 0 -Level 'SUCCESS'
    }

    $message = "Non-Compliant: Dell SupportAssist found. UninstallString: $($app.UninstallString)"
    Finish-Script -Message $message -ExitCode 1 -Level 'WARNING'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------

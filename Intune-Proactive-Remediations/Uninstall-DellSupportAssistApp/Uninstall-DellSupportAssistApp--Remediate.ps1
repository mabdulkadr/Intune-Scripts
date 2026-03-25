<#
.SYNOPSIS
    Removes Dell SupportAssist from the device.

.DESCRIPTION
    This remediation script reads the uninstall registry data for
    `Dell SupportAssist` and uses one of the supported uninstall methods:

    - `msiexec.exe` with an extracted product GUID
    - `SupportAssistUninstaller.exe` with `/arp /S`

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Uninstall-DellSupportAssistApp--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Uninstall-DellSupportAssistApp--Remediate.ps1'
$SolutionName = 'Uninstall-DellSupportAssistApp'
$ScriptMode   = 'Remediation'

$UninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$TargetDisplayName = 'Dell SupportAssist'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Uninstall-DellSupportAssistApp--Remediate.txt'
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

function Get-UninstallCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UninstallString
    )

    if ($UninstallString -match 'msiexec(\.exe)?' -and $UninstallString -match '\{[A-Za-z0-9\-]+\}') {
        $productCode = $matches[0]
        return [pscustomobject]@{
            FilePath     = 'msiexec.exe'
            ArgumentList = "/x $productCode /qn /norestart"
        }
    }

    if ($UninstallString -match 'SupportAssistUninstaller\.exe') {
        $exePath = [regex]::Match($UninstallString, '^\s*"?(?<path>[^"]*SupportAssistUninstaller\.exe)"?').Groups['path'].Value
        if (-not $exePath) {
            throw 'Unable to parse SupportAssistUninstaller.exe path from the uninstall string.'
        }

        return [pscustomobject]@{
            FilePath     = $exePath
            ArgumentList = '/arp /S'
        }
    }

    throw 'Unsupported uninstall method for Dell SupportAssist.'
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message 'Searching uninstall registry locations for Dell SupportAssist.'

    $app = Get-DellSupportAssistEntry
    if (-not $app) {
        Finish-Script -Message 'Dell SupportAssist was not found. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    if ([string]::IsNullOrWhiteSpace($app.UninstallString)) {
        Finish-Script -Message 'Dell SupportAssist was found but no uninstall string is available.' -ExitCode 1 -Level 'ERROR'
    }

    $command = Get-UninstallCommand -UninstallString $app.UninstallString
    Write-Log -Message ("Starting uninstall for {0}." -f $app.DisplayName)

    $process = Start-Process -FilePath $command.FilePath -ArgumentList $command.ArgumentList -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
    if ($process.ExitCode -ne 0) {
        Finish-Script -Message ("Dell SupportAssist uninstall failed. Exit code: {0}" -f $process.ExitCode) -ExitCode 1 -Level 'ERROR'
    }

    Finish-Script -Message 'Dell SupportAssist uninstall completed successfully.' -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------

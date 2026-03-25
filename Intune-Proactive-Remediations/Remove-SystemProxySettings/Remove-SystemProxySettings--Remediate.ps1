<#
.SYNOPSIS
    Removes the current user's WinINET proxy settings.

.DESCRIPTION
    This remediation script disables the current user's proxy by setting
    `ProxyEnable = 0` and clearing `ProxyServer`.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Remove-SystemProxySettings--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Remove-SystemProxySettings--Remediate.ps1'
$SolutionName = 'Remove-SystemProxySettings'
$ScriptMode   = 'Remediation'
$RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Remove-SystemProxySettings--Remediate.txt'
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
        try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
    }
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$OutputMessage
    )

    Write-Log -Message $Message -Level $Level

    if ($OutputMessage) {
        Write-Output $OutputMessage
    }

    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Removing current user proxy settings under: {0}" -f $RegistryPath)

try {
    Set-ItemProperty -Path $RegistryPath -Name 'ProxyEnable' -Value 0 -ErrorAction Stop
    Set-ItemProperty -Path $RegistryPath -Name 'ProxyServer' -Value '' -ErrorAction Stop

    $internetSettings = Get-ItemProperty -Path $RegistryPath -ErrorAction Stop
    $proxyEnabled = [int]($internetSettings.ProxyEnable)
    $proxyServer = [string]$internetSettings.ProxyServer

    if ($proxyEnabled -eq 0 -and [string]::IsNullOrWhiteSpace($proxyServer)) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Current user proxy settings were removed successfully.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message 'Proxy settings did not match the expected cleared state after remediation.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to remove current user proxy settings: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------

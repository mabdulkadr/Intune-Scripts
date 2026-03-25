<#
.SYNOPSIS
    Attempts to uninstall blacklisted applications from the device.

.DESCRIPTION
    This remediation script searches the standard 64-bit and 32-bit uninstall
    registry locations under `HKLM`, matches entries against a configurable
    blacklist array, reads each uninstall string, and attempts to launch the
    uninstall silently.

    For MSI-based uninstall strings, the script uses `msiexec.exe /x ... /qn`.
    For non-MSI uninstall commands, the script launches the vendor command and
    appends `/S`.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Uninstall-InstalledApplication--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Uninstall-InstalledApplication--Remediate.ps1'
$SolutionName = 'Uninstall-InstalledApplication'
$ScriptMode   = 'Remediation'

$BlacklistApps = @(
    'APP 1'
    'APP 2'
)

$UninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Uninstall-InstalledApplication--Remediate.txt'
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

function Get-InstalledBlacklistedApps {
    return @(
        Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
        ForEach-Object {
            $name = if ($_.DisplayName) { [string]$_.DisplayName } else { [string]$_.DisplayName_Localized }
            if (-not $name -or $BlacklistApps -notcontains $name) { return }

            [pscustomobject]@{
                Name            = $name
                UninstallString = [string]$_.UninstallString
                RegistryPath    = $_.PSPath
            }
        }
    )
}

function Get-UninstallCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UninstallString
    )

    $trimmed = $UninstallString.Trim()

    if ($trimmed -match 'msiexec(\.exe)?' -and $trimmed -match '\{[A-Za-z0-9\-]+\}') {
        $productCode = $matches[0]
        return [pscustomobject]@{
            FilePath     = 'msiexec.exe'
            ArgumentList = "/x $productCode /qn /norestart"
        }
    }

    return [pscustomobject]@{
        FilePath     = 'cmd.exe'
        ArgumentList = "/c `"$trimmed /S`""
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message 'Searching uninstall registry locations for blacklisted applications.'

    $matches = Get-InstalledBlacklistedApps
    if (@($matches).Count -eq 0) {
        Finish-Script -Message 'No blacklisted applications were detected. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    $failureCount = 0

    foreach ($app in $matches) {
        if ([string]::IsNullOrWhiteSpace($app.UninstallString)) {
            $failureCount++
            Write-Log -Message ("Uninstall string is missing for '{0}'." -f $app.Name) -Level 'ERROR'
            continue
        }

        $command = Get-UninstallCommand -UninstallString $app.UninstallString
        Write-Log -Message ("Starting uninstall for '{0}'." -f $app.Name)

        $process = Start-Process -FilePath $command.FilePath -ArgumentList $command.ArgumentList -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            $failureCount++
            Write-Log -Message ("Uninstall failed for '{0}'. Exit code: {1}" -f $app.Name, $process.ExitCode) -Level 'ERROR'
            continue
        }

        Write-Log -Message ("Uninstall completed for '{0}'." -f $app.Name) -Level 'SUCCESS'
    }

    if ($failureCount -gt 0) {
        Finish-Script -Message ("Remediation completed with {0} failure(s)." -f $failureCount) -ExitCode 1 -Level 'WARNING'
    }

    Finish-Script -Message ("Remediation completed successfully for {0} blacklisted application(s)." -f @($matches).Count) -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------

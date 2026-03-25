<#
.SYNOPSIS
    Attempts to remove the per-user Chrome installation silently.

.DESCRIPTION
    This remediation script reads the current user's uninstall entries,
    locates `Google Chrome`, extracts the uninstall command, and launches it
    with silent arguments.

    It supports both MSI-style uninstall strings and non-MSI uninstall
    commands.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Uninstall-ChromePerUser--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Uninstall-ChromePerUser--Remediate.ps1'
$SolutionName = 'Uninstall-ChromePerUser'
$ScriptMode   = 'Remediation'

$UninstallRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$BlacklistApps    = @('Google Chrome')

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Uninstall-ChromePerUser--Remediate.txt'
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

function Get-PerUserChromeEntries {
    if (-not (Test-Path -Path $UninstallRegPath)) {
        return @()
    }

    return @(
        Get-ChildItem -Path $UninstallRegPath -ErrorAction Stop |
        ForEach-Object {
            $entry = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if (-not $entry) { return }

            $name = if ($entry.DisplayName) { [string]$entry.DisplayName } else { [string]$entry.DisplayName_Localized }
            if (-not $name -or $BlacklistApps -notcontains $name) { return }

            [pscustomobject]@{
                Name            = $name
                UninstallString = [string]$entry.UninstallString
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

    if ($trimmed -match 'MsiExec(\.exe)?') {
        if ($trimmed -match '\{[A-Za-z0-9\-]+\}') {
            $productCode = $matches[0]
            return [pscustomobject]@{
                FilePath     = 'msiexec.exe'
                ArgumentList = "/x $productCode /qn /norestart"
            }
        }

        return [pscustomobject]@{
            FilePath     = 'cmd.exe'
            ArgumentList = "/c $trimmed /qn /norestart"
        }
    }

    return [pscustomobject]@{
        FilePath     = 'cmd.exe'
        ArgumentList = "/c `"$trimmed --uninstall --force-uninstall --system-level --multi-install --chrome --silent`""
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message ("Checking user uninstall entries under: {0}" -f $UninstallRegPath)

    $matches = Get-PerUserChromeEntries
    if (@($matches).Count -eq 0) {
        Finish-Script -Message 'Per-user Google Chrome was not detected. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    $failureCount = 0

    foreach ($match in $matches) {
        if ([string]::IsNullOrWhiteSpace($match.UninstallString)) {
            $failureCount++
            Write-Log -Message ("Uninstall string is missing for '{0}'." -f $match.Name) -Level 'ERROR'
            continue
        }

        $command = Get-UninstallCommand -UninstallString $match.UninstallString
        Write-Log -Message ("Starting silent uninstall for '{0}'." -f $match.Name)

        $process = Start-Process -FilePath $command.FilePath -ArgumentList $command.ArgumentList -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            $failureCount++
            Write-Log -Message ("Uninstall failed for '{0}'. Exit code: {1}" -f $match.Name, $process.ExitCode) -Level 'ERROR'
            continue
        }

        Write-Log -Message ("Uninstall completed for '{0}'." -f $match.Name) -Level 'SUCCESS'
    }

    if ($failureCount -gt 0) {
        Finish-Script -Message ("Remediation completed with {0} failure(s)." -f $failureCount) -ExitCode 1 -Level 'WARNING'
    }

    Finish-Script -Message ("Remediation completed successfully for {0} uninstall entry(ies)." -f @($matches).Count) -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------

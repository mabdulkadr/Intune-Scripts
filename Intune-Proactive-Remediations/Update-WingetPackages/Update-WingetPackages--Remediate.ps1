<#
.SYNOPSIS
    Upgrades all packages that Winget considers eligible for update.

.DESCRIPTION
    This remediation script resolves the installed Winget client and runs
    `winget upgrade --all --force --silent` to update every available package.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Update-WingetPackages--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Update-WingetPackages--Remediate.ps1'
$SolutionName = 'Update-WingetPackages'
$ScriptMode   = 'Remediation'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Update-WingetPackages--Remediate.txt'
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

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DETAIL')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0} | {1,-7} | {2}' -f $timestamp, $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        'DETAIL'  { Write-Host $line -ForegroundColor DarkGray }
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

function Resolve-WingetExecutable {
    $appInstallerPackage = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if ($appInstallerPackage -and $appInstallerPackage.InstallLocation) {
        foreach ($fileName in 'winget.exe', 'AppInstallerCLI.exe') {
            $packageExecutable = Join-Path $appInstallerPackage.InstallLocation $fileName
            if (Test-Path -Path $packageExecutable) {
                return $packageExecutable
            }
        }
    }

    $patterns = @(
        (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe'),
        (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\AppInstallerCLI.exe')
    )

    foreach ($pattern in $patterns) {
        $resolvedPath = Resolve-Path -Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object -Property Path -Descending |
            Select-Object -First 1

        if ($resolvedPath) {
            return $resolvedPath.Path
        }
    }

    $command = Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue
    if ($command) {
        return $(if ($command.Source) { $command.Source } else { $command.Name })
    }

    $shimPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -Path $shimPath) {
        return 'winget.exe'
    }

    return $null
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner

    $wingetPath = Resolve-WingetExecutable
    if (-not $wingetPath) {
        Finish-Script -Message 'Winget was not found. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    Write-Log -Message ("Using Winget executable: {0}" -f $wingetPath)
    Write-Log -Message 'Starting Winget upgrade for all eligible packages.'

    $output = & $wingetPath upgrade --all --force --silent --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { [string]$_ }
    foreach ($line in $output) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Write-Log -Message $line.Trim() -Level 'DETAIL'
        }
    }

    if ($LASTEXITCODE -ne 0) {
        Finish-Script -Message ("Winget upgrade failed. Exit code: {0}" -f $LASTEXITCODE) -ExitCode 1 -Level 'ERROR'
    }

    Finish-Script -Message 'Winget upgrade completed successfully.' -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------

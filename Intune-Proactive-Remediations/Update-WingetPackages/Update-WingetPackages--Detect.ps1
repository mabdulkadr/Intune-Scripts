<#
.SYNOPSIS
    Checks whether Winget reports pending package upgrades.

.DESCRIPTION
    This detection script resolves the installed Winget client, runs
    `winget upgrade`, and evaluates the returned package rows to determine
    whether updates are available.

    Exit codes:
    - Exit 0: No Winget upgrades detected
    - Exit 1: Pending Winget upgrades detected

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Update-WingetPackages--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Update-WingetPackages--Detect.ps1'
$SolutionName = 'Update-WingetPackages'
$ScriptMode   = 'Detection'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Update-WingetPackages--Detect.txt'
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

function Get-WingetUpgradeSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath
    )

    $rawLines = & $ExecutablePath upgrade --accept-source-agreements 2>&1 | ForEach-Object { [string]$_ }
    $cleanLines = $rawLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $packageLines = $cleanLines | Where-Object {
        $_ -match '^\S+\s+\S+\s+\S+\s+\S+' -and
        $_ -notmatch '^(Name|---|\d+\s+upgrades?\s+available|The following packages|No installed package|No newer package)'
    }

    [pscustomobject]@{
        RawLines       = $cleanLines
        PackageLines   = @($packageLines)
        UpgradeCount   = @($packageLines).Count
        HasNoUpgrades  = ($cleanLines -match 'No newer package versions are available from the configured sources\.|No available upgrade found\.|No installed package found matching input criteria\.').Count -gt 0
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner

    $wingetPath = Resolve-WingetExecutable
    if (-not $wingetPath) {
        Finish-Script -Message 'Winget was not found. No pending upgrades can be evaluated.' -ExitCode 0 -Level 'SUCCESS'
    }

    Write-Log -Message ("Using Winget executable: {0}" -f $wingetPath)
    $snapshot = Get-WingetUpgradeSnapshot -ExecutablePath $wingetPath

    if ($snapshot.HasNoUpgrades -or $snapshot.UpgradeCount -eq 0) {
        Finish-Script -Message 'No Winget upgrades detected.' -ExitCode 0 -Level 'SUCCESS'
    }

    Finish-Script -Message ("Non-Compliant: Winget reports {0} pending upgrade(s)." -f $snapshot.UpgradeCount) -ExitCode 1 -Level 'WARNING'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------

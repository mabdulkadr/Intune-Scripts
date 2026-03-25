<#
.SYNOPSIS
    Pins the selected OneDrive folder and its contents for offline use.

.DESCRIPTION
    This remediation script builds the OneDrive business folder path for the
    current user, applies `-U +P /s /d` to the root folder, then applies
    `-U +P` to each child item recursively.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Set-OneDriveFolderOfflineAvailability--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Set-OneDriveFolderOfflineAvailability--Remediate.ps1'
$SolutionName = 'Set-OneDriveFolderOfflineAvailability'
$ScriptMode   = 'Remediation'
$CompanyName  = 'scloud'
$ODFolder     = 'Desktop'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Set-OneDriveFolderOfflineAvailability--Remediate.txt'
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

function Get-OneDriveTargetPath {
    return (Join-Path $env:USERPROFILE ("OneDrive - {0}\{1}" -f $CompanyName, $ODFolder))
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    $targetPath = Get-OneDriveTargetPath
    Write-Log -Message ("Target path: {0}" -f $targetPath)

    if (-not (Test-Path -LiteralPath $targetPath)) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'Target OneDrive folder was not found.'
    }

    & attrib.exe $targetPath -U +P /s /d | Out-Null
    Write-Log -Message 'Pinned the root OneDrive folder tree for offline use.' -Level 'SUCCESS'

    $childItems = Get-ChildItem -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
    foreach ($item in $childItems) {
        & attrib.exe $item.FullName -U +P | Out-Null
    }

    Write-Log -Message ("Applied offline availability attributes to child items: {0}" -f $childItems.Count) -Level 'SUCCESS'
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'The OneDrive folder was pinned for offline availability successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------

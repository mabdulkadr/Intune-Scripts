<#
.SYNOPSIS
    Detects whether application updates are available using Windows Package Manager (winget).

.DESCRIPTION
    This detection script checks whether installed applications on the device
    have pending updates through Windows Package Manager (winget).

    The script resolves winget.exe from the WindowsApps folder in a way that works
    reliably in SYSTEM context, such as Microsoft Intune Remediations.

    Logic:
    - Exit 0: No upgradeable applications were found
    - Exit 1: One or more applications have available updates
    - Exit 1: Detection failed

.RUN AS
    System

.EXAMPLE
    .\WingetUpdateAll--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'WingetUpdateAll--Detect.ps1'
$ScriptBaseName = 'WingetUpdateAll--Detect'
$SolutionName   = 'Winget-Update-All'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    'C:'
}

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -LiteralPath $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write a message to console and log file
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$TimeStamp] [$Level] $Message"

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

# Resolve winget.exe in SYSTEM context
function Get-WingetPath {
    try {
        $ResolveWingetPath = Resolve-Path 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' -ErrorAction Stop
        if ($ResolveWingetPath) {
            $WingetRoot = $ResolveWingetPath[-1].Path
            $WingetExe  = Join-Path $WingetRoot 'winget.exe'

            if (Test-Path -LiteralPath $WingetExe) {
                return $WingetExe
            }
        }

        return $null
    }
    catch {
        return $null
    }
}

# Run winget and return captured output
function Invoke-WingetUpgradeCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetPath
    )

    $Output = & $WingetPath upgrade --accept-source-agreements 2>&1
    return @($Output)
}

# Determine whether output indicates available upgrades
function Test-WingetUpdatesAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$OutputLines
    )

    $Text = ($OutputLines | ForEach-Object { $_.ToString() }) -join "`n"

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    if ($Text -match 'No installed package found matching input criteria') {
        return $false
    }

    if ($Text -match 'No available upgrade found') {
        return $false
    }

    if ($Text -match 'upgrades available') {
        return $true
    }

    # Ignore common source/header lines and count meaningful output
    $MeaningfulLines = @(
        $OutputLines |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object {
            $_ -and
            $_ -notmatch '^-+$' -and
            $_ -notmatch '^Name\s+Id\s+Version' -and
            $_ -notmatch '^The following packages' -and
            $_ -notmatch '^Winget' -and
            $_ -notmatch '^For information on' -and
            $_ -notmatch '^Source agreed' -and
            $_ -notmatch '^Downloading' -and
            $_ -notmatch '^Successfully' -and
            $_ -notmatch '^No available upgrade found'
        }
    )

    if ($MeaningfulLines.Count -gt 2) {
        return $true
    }

    return $false
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Log file: $LogFile"

try {
    # Resolve winget path
    $Winget = Get-WingetPath

    if (-not $Winget) {
        Write-Log -Message 'winget.exe was not found.' -Level 'ERROR'
        Write-Output 'Not Compliant'
        exit 1
    }

    Write-Log -Message "Winget path: $Winget"

    # Run winget upgrade check
    $UpdateCheck = Invoke-WingetUpgradeCheck -WingetPath $Winget
    Write-Log -Message "Raw result count: $($UpdateCheck.Count)"

    if ($UpdateCheck.Count -gt 0) {
        $PreviewLines = $UpdateCheck | Select-Object -First 10
        foreach ($Line in $PreviewLines) {
            Write-Log -Message ("winget: " + $Line.ToString())
        }
    }

    # Decide compliance
    $UpdatesAvailable = Test-WingetUpdatesAvailable -OutputLines $UpdateCheck

    if (-not $UpdatesAvailable) {
        Write-Log -Message 'No application upgrades detected.' -Level 'SUCCESS'
        Write-Output 'Compliant'
        exit 0
    }

    Write-Log -Message 'Application updates are available. Device is not compliant.' -Level 'WARNING'
    Write-Output 'Not Compliant'
    exit 1
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Output 'Not Compliant'
    exit 1
}

#endregion ---------- Detection Logic ----------
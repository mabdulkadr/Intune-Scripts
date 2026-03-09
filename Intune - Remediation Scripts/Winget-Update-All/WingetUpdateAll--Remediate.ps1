<#
.SYNOPSIS
    Remediates outdated applications by upgrading all supported apps using Windows Package Manager (winget).

.DESCRIPTION
    This remediation script upgrades all installed applications that have
    available updates using Windows Package Manager (winget).

    The script resolves winget.exe from the WindowsApps directory in a way
    that works reliably in SYSTEM context, such as Microsoft Intune Remediations.

    It executes:
        winget upgrade --all --force --silent

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Remediation failed

.RUN AS
    System

.EXAMPLE
    .\WingetUpdateAll--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'WingetUpdateAll--Remediate.ps1'
$ScriptBaseName = 'WingetUpdateAll--Remediate'
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

# Run winget and capture output
function Invoke-WingetUpgradeAll {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetPath
    )

    $Output = & $WingetPath upgrade --all --force --silent --accept-package-agreements --accept-source-agreements 2>&1
    $ExitCode = $LASTEXITCODE

    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output   = @($Output)
    }
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Log file: $LogFile"

try {
    # Resolve winget path
    $Winget = Get-WingetPath

    if (-not $Winget) {
        Write-Log -Message 'winget.exe was not found.' -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Winget path: $Winget"

    # Execute upgrade لجميع التطبيقات القابلة للتحديث
    $Result = Invoke-WingetUpgradeAll -WingetPath $Winget

    Write-Log -Message "Winget exit code: $($Result.ExitCode)"

    if ($Result.Output.Count -gt 0) {
        foreach ($Line in $Result.Output) {
            if (-not [string]::IsNullOrWhiteSpace($Line.ToString())) {
                Write-Log -Message ("winget: " + $Line.ToString())
            }
        }
    }
    else {
        Write-Log -Message 'Winget returned no output.'
    }

    if ($Result.ExitCode -eq 0) {
        Write-Log -Message 'Winget remediation completed successfully.' -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message 'Winget remediation completed with errors.' -Level 'ERROR'
    exit 1
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------
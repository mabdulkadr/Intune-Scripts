<#
.SYNOPSIS
    Repairs and resets key Windows Update components.

.DESCRIPTION
    This remediation script runs a Windows Update repair workflow that can
    include the built-in troubleshooter, DISM image repair, cleanup of common
    Windows Update policy values, resetting update components, and attempting
    to scan for and install pending software updates.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: One or more remediation steps failed

.RUN AS
    System

.EXAMPLE
    .\Repair-WindowsUpdateComponents--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName         = 'Repair-WindowsUpdateComponents--Remediate.ps1'
$SolutionName       = 'Repair-WindowsUpdateComponents'
$ScriptMode         = 'Remediation'
$TroubleshooterPath = 'C:\Windows\diagnostics\system\WindowsUpdate'
$RegistryCleanupMap = @{
    'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings' = @(
        'PausedQualityDate',
        'PausedFeatureDate',
        'PausedQualityStatus',
        'PausedFeatureStatus'
    )
    'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update' = @(
        'PauseQualityUpdatesStartTime',
        'PauseFeatureUpdatesStartTime',
        'DeferFeatureUpdatesPeriodInDays'
    )
}

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Repair-WindowsUpdateComponents--Remediate.txt'
$DismLogPath = Join-Path $LogRoot 'WindowsUpdateTroublshooting-DISM.txt'
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

function Remove-RegistryProperties {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Log -Message ("Registry path not found: {0}" -f $Path)
        return
    }

    $item = Get-Item -Path $Path -ErrorAction Stop
    foreach ($propertyName in $PropertyNames) {
        if ($item.Property -contains $propertyName) {
            Write-Log -Message ("Removing registry property '{0}' from '{1}'." -f $propertyName, $Path)
            Remove-ItemProperty -Path $Path -Name $propertyName -ErrorAction Stop
        }
    }
}

function Ensure-RequiredModule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-Log -Message ("Module '{0}' is already available." -f $ModuleName)
        return $true
    }

    if (-not (Get-Command -Name Install-Module -ErrorAction SilentlyContinue)) {
        Write-Log -Message ("Install-Module is not available. Cannot install '{0}'." -f $ModuleName) -Level 'WARNING'
        return $false
    }

    Write-Log -Message ("Installing module '{0}'." -f $ModuleName)
    Install-Module -Name $ModuleName -Force -AllowClobber -ErrorAction Stop
    return $true
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
$hadFailures = $false

Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
    Write-Log -Message ("DISM log file: {0}" -f $DismLogPath)
}

try {
    if ((Get-Command -Name Get-TroubleshootingPack -ErrorAction SilentlyContinue) -and (Test-Path -Path $TroubleshooterPath)) {
        try {
            Write-Log -Message 'Running the Windows Update troubleshooter.'
            Get-TroubleshootingPack -Path $TroubleshooterPath | Invoke-TroubleshootingPack -Unattended
            Write-Log -Message 'Windows Update troubleshooter completed.' -Level 'SUCCESS'
        }
        catch {
            $hadFailures = $true
            Write-Log -Message ("Windows Update troubleshooter failed: {0}" -f $_.Exception.Message) -Level 'WARNING'
        }
    }
    else {
        Write-Log -Message 'Windows Update troubleshooter is not available on this system.' -Level 'WARNING'
    }

    try {
        Write-Log -Message 'Running Repair-WindowsImage -Online -RestoreHealth.'
        Repair-WindowsImage -Online -RestoreHealth -NoRestart -LogPath $DismLogPath -ErrorAction Stop | Out-Null
        Write-Log -Message 'Repair-WindowsImage RestoreHealth completed.' -Level 'SUCCESS'
    }
    catch {
        $hadFailures = $true
        Write-Log -Message ("Repair-WindowsImage RestoreHealth failed: {0}" -f $_.Exception.Message) -Level 'WARNING'
    }

    foreach ($registryPath in $RegistryCleanupMap.Keys) {
        try {
            Remove-RegistryProperties -Path $registryPath -PropertyNames $RegistryCleanupMap[$registryPath]
        }
        catch {
            $hadFailures = $true
            Write-Log -Message ("Registry cleanup failed for '{0}': {1}" -f $registryPath, $_.Exception.Message) -Level 'WARNING'
        }
    }

    foreach ($moduleName in @('PSWindowsUpdate', 'FU.WhyAmIBlocked')) {
        try {
            $moduleReady = Ensure-RequiredModule -ModuleName $moduleName
            if (-not $moduleReady) {
                $hadFailures = $true
            }
        }
        catch {
            $hadFailures = $true
            Write-Log -Message ("Module preparation failed for '{0}': {1}" -f $moduleName, $_.Exception.Message) -Level 'WARNING'
        }
    }

    if (Get-Module -ListAvailable -Name 'PSWindowsUpdate') {
        try {
            Import-Module -Name 'PSWindowsUpdate' -Force -ErrorAction Stop
            Write-Log -Message "Module 'PSWindowsUpdate' imported." -Level 'SUCCESS'
        }
        catch {
            $hadFailures = $true
            Write-Log -Message ("Failed to import 'PSWindowsUpdate': {0}" -f $_.Exception.Message) -Level 'WARNING'
        }
    }

    if (Get-Command -Name Reset-WUComponents -ErrorAction SilentlyContinue) {
        try {
            Write-Log -Message 'Resetting Windows Update components.'
            Reset-WUComponents -ErrorAction Stop | Out-Null
            Write-Log -Message 'Windows Update components were reset.' -Level 'SUCCESS'
        }
        catch {
            $hadFailures = $true
            Write-Log -Message ("Reset-WUComponents failed: {0}" -f $_.Exception.Message) -Level 'WARNING'
        }
    }
    else {
        Write-Log -Message 'Reset-WUComponents command is not available.' -Level 'WARNING'
    }

    if (Get-Command -Name Get-WindowsUpdate -ErrorAction SilentlyContinue) {
        try {
            Write-Log -Message 'Checking for and installing pending software updates.'
            Get-WindowsUpdate -Install -AcceptAll -UpdateType Software -IgnoreReboot -ErrorAction Stop | Out-Null
            Write-Log -Message 'Windows Update scan and install step completed.' -Level 'SUCCESS'
        }
        catch {
            $hadFailures = $true
            Write-Log -Message ("Get-WindowsUpdate failed: {0}" -f $_.Exception.Message) -Level 'WARNING'
        }
    }
    else {
        $hadFailures = $true
        Write-Log -Message 'Get-WindowsUpdate command is not available.' -Level 'WARNING'
    }

    if ($hadFailures) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'One or more Windows Update remediation steps reported warnings or failures.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Windows Update remediation completed successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------

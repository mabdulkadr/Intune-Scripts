<#
.SYNOPSIS
    Repairs core Windows Update components.

.DESCRIPTION
    This remediation script repairs common Windows Update issues by:
    1. Stopping related services
    2. Cleaning common update policy values
    3. Renaming SoftwareDistribution and Catroot2
    4. Starting services again
    5. Running a Windows Update detection scan

    This script focuses on repairing Windows Update components only.
    It does not install updates.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: One or more repair steps failed

.RUN AS
    System

.EXAMPLE
    .\RepairWindowsUpdateComponents.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'RepairWindowsUpdateComponents.ps1'
$ScriptBaseName = 'RepairWindowsUpdateComponents'
$SolutionName   = 'Repair Windows Update Components'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    'C:'
}

# Logging paths
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

# DISM log path
$DismLogPath = Join-Path $BasePath 'RepairWindowsUpdateComponents-DISM.txt'

# Windows Update troubleshooter path
$TroubleshooterPath = 'C:\Windows\diagnostics\system\WindowsUpdate'

# Windows Update-related services
$ServiceNames = @(
    'wuauserv',
    'bits',
    'cryptsvc',
    'appidsvc'
)

# Common update policy values that may block scanning
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

# Common Windows Update folders to reset
$SoftwareDistributionPath = Join-Path $env:SystemRoot 'SoftwareDistribution'
$Catroot2Path             = Join-Path $env:SystemRoot 'System32\catroot2'

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
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
    $Line      = "[$TimeStamp] [$Level] $Message"

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

# Run one repair step and return success/failure
function Invoke-RepairStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StepName,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    try {
        Write-Log -Message $StepName
        & $ScriptBlock
        Write-Log -Message "$StepName completed successfully." -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-Log -Message "$StepName failed: $($_.Exception.Message)" -Level 'WARNING'
        return $false
    }
}

# Stop a list of services if they exist
function Stop-TargetServices {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($Name in $Names) {
        $Service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $Service) {
            Write-Log -Message "Service '$Name' was not found." -Level 'WARNING'
            continue
        }

        if ($Service.Status -ne 'Stopped') {
            Write-Log -Message "Stopping service '$Name'..."
            Stop-Service -Name $Name -Force -ErrorAction Stop
        }
        else {
            Write-Log -Message "Service '$Name' is already stopped."
        }
    }
}

# Start a list of services if they exist
function Start-TargetServices {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($Name in $Names) {
        $Service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $Service) {
            Write-Log -Message "Service '$Name' was not found." -Level 'WARNING'
            continue
        }

        if ($Service.Status -ne 'Running') {
            Write-Log -Message "Starting service '$Name'..."
            Start-Service -Name $Name -ErrorAction Stop
        }
        else {
            Write-Log -Message "Service '$Name' is already running."
        }
    }
}

# Remove selected registry properties if they exist
function Remove-RegistryProperties {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Log -Message "Registry path not found: $Path"
        return
    }

    $Item = Get-Item -Path $Path -ErrorAction Stop

    foreach ($PropertyName in $PropertyNames) {
        if ($Item.Property -contains $PropertyName) {
            Write-Log -Message "Removing registry property '$PropertyName' from '$Path'"
            Remove-ItemProperty -Path $Path -Name $PropertyName -ErrorAction Stop
        }
    }
}

# Rename a folder to .bak_timestamp if it exists
function Rename-UpdateFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Log -Message "Path not found, skipping: $Path"
        return
    }

    $BackupPath = '{0}.bak_{1}' -f $Path, (Get-Date -Format 'yyyyMMddHHmmss')
    Write-Log -Message "Renaming '$Path' to '$BackupPath'"
    Rename-Item -Path $Path -NewName (Split-Path -Path $BackupPath -Leaf) -ErrorAction Stop
}

# Trigger a Windows Update scan
function Start-WindowsUpdateScan {
    if (Get-Command -Name UsoClient.exe -ErrorAction SilentlyContinue) {
        Write-Log -Message 'Triggering Windows Update scan with UsoClient StartScan'
        Start-Process -FilePath 'UsoClient.exe' -ArgumentList 'StartScan' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
        return
    }

    if (Get-Command -Name wuauclt.exe -ErrorAction SilentlyContinue) {
        Write-Log -Message 'Triggering Windows Update scan with wuauclt /detectnow'
        Start-Process -FilePath 'wuauclt.exe' -ArgumentList '/detectnow' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
        return
    }

    Write-Log -Message 'No supported Windows Update scan command was found.' -Level 'WARNING'
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Log file: $LogFile"
Write-Log -Message "DISM log file: $DismLogPath"

$HadFailures = $false

try {
    # Step 1: Run the built-in troubleshooter if available
    if ((Get-Command -Name Get-TroubleshootingPack -ErrorAction SilentlyContinue) -and (Test-Path -Path $TroubleshooterPath)) {
        $StepResult = Invoke-RepairStep -StepName 'Running Windows Update troubleshooter' -ScriptBlock {
            Get-TroubleshootingPack -Path $TroubleshooterPath | Invoke-TroubleshootingPack -Unattended
        }

        if (-not $StepResult) {
            $HadFailures = $true
        }
    }
    else {
        Write-Log -Message 'Windows Update troubleshooter is not available on this system.' -Level 'WARNING'
    }

    # Step 2: Run DISM RestoreHealth
    $StepResult = Invoke-RepairStep -StepName 'Running DISM RestoreHealth' -ScriptBlock {
        Repair-WindowsImage -Online -RestoreHealth -NoRestart -LogPath $DismLogPath -ErrorAction Stop | Out-Null
    }

    if (-not $StepResult) {
        $HadFailures = $true
    }

    # Step 3: Clean update-related policy values
    foreach ($RegistryPath in $RegistryCleanupMap.Keys) {
        $CurrentPath = $RegistryPath
        $CurrentProperties = $RegistryCleanupMap[$RegistryPath]

        $StepResult = Invoke-RepairStep -StepName "Cleaning registry values under '$CurrentPath'" -ScriptBlock {
            Remove-RegistryProperties -Path $CurrentPath -PropertyNames $CurrentProperties
        }

        if (-not $StepResult) {
            $HadFailures = $true
        }
    }

    # Step 4: Stop update-related services
    $StepResult = Invoke-RepairStep -StepName 'Stopping Windows Update-related services' -ScriptBlock {
        Stop-TargetServices -Names $ServiceNames
    }

    if (-not $StepResult) {
        $HadFailures = $true
    }

    # Step 5: Reset SoftwareDistribution
    $StepResult = Invoke-RepairStep -StepName 'Resetting SoftwareDistribution folder' -ScriptBlock {
        Rename-UpdateFolder -Path $SoftwareDistributionPath
    }

    if (-not $StepResult) {
        $HadFailures = $true
    }

    # Step 6: Reset Catroot2
    $StepResult = Invoke-RepairStep -StepName 'Resetting Catroot2 folder' -ScriptBlock {
        Rename-UpdateFolder -Path $Catroot2Path
    }

    if (-not $StepResult) {
        $HadFailures = $true
    }

    # Step 7: Start update-related services again
    $StepResult = Invoke-RepairStep -StepName 'Starting Windows Update-related services' -ScriptBlock {
        Start-TargetServices -Names $ServiceNames
    }

    if (-not $StepResult) {
        $HadFailures = $true
    }

    # Step 8: Trigger a fresh update scan
    $StepResult = Invoke-RepairStep -StepName 'Triggering Windows Update scan' -ScriptBlock {
        Start-WindowsUpdateScan
    }

    if (-not $StepResult) {
        $HadFailures = $true
    }

    if ($HadFailures) {
        Write-Log -Message 'One or more Windows Update repair steps reported warnings or failures.' -Level 'ERROR'
        exit 1
    }

    Write-Log -Message 'Windows Update component repair completed successfully.' -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------
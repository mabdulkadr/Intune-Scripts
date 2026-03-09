<#
.SYNOPSIS
    Remediates monthly restore point compliance by creating a valid restore point when needed.

.DESCRIPTION
    This remediation script checks whether a valid restore point already exists
    for the current month. If not, it:
    1. Ensures System Protection is available on the OS drive.
    2. Temporarily clears the restore point creation throttle.
    3. Creates the required monthly restore point.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 2: System Protection could not be enabled or is unavailable
    - Exit 3: Restore point creation failed
    - Exit 4: Unexpected error

.RUN AS
    System

.EXAMPLE
    .\MonthlyRestorePoint--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Script metadata
$ScriptName     = 'MonthlyRestorePoint--Remediate.ps1'
$ScriptBaseName = 'MonthlyRestorePoint--Remediate'
$SolutionName   = 'Monthly System Restore Point Compliance'

# Restore point naming
$CanonicalPrefix  = 'Monthly System Restore Point'
$AcceptedPrefixes = @(
    $CanonicalPrefix,
    'Intune Monthly Restore Point',
    'System Safety Restore Point'
)

# Resolve OS drive
try {
    $OsDrive = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).SystemDrive
}
catch {
    $OsDrive = $env:SystemDrive
}

if (-not $OsDrive) {
    $OsDrive = $env:SystemDrive
}

# Current month values
$Now            = Get-Date
$MonthStart     = Get-Date -Year $Now.Year -Month $Now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$NextMonthStart = $MonthStart.AddMonths(1)
$MonthTag       = "({0})" -f $MonthStart.ToString('yyyy-MM')
$Description    = "$CanonicalPrefix $MonthTag"

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

$OsDrive = $OsDrive.TrimEnd('\')

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

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

# Convert WMI datetime string to DateTime
function Convert-WmiDate {
    param(
        [string]$WmiDate
    )

    try {
        [System.Management.ManagementDateTimeConverter]::ToDateTime($WmiDate)
    }
    catch {
        $null
    }
}

# Safely parse date values
function Convert-ToDateTime {
    param(
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    try {
        return [datetime]$Value
    }
    catch {}

    foreach ($Format in @('G', 'g', 'yyyy-MM-dd HH:mm:ss', 'MM/dd/yyyy HH:mm:ss', 'dd/MM/yyyy HH:mm:ss')) {
        try {
            return [datetime]::ParseExact([string]$Value, $Format, $null)
        }
        catch {}
    }

    return $null
}

# Collect restore points from Get-ComputerRestorePoint
function Get-RestorePointsFromCommand {
    $Items = @()

    try {
        foreach ($RestorePoint in Get-ComputerRestorePoint) {
            $CreationDate = Convert-ToDateTime -Value $RestorePoint.CreationTime
            if ($CreationDate) {
                $Items += [pscustomobject]@{
                    Source       = 'Get-ComputerRestorePoint'
                    Sequence     = $RestorePoint.SequenceNumber
                    Description  = [string]$RestorePoint.Description
                    CreationTime = $CreationDate
                }
            }
        }
    }
    catch {}

    return $Items
}

# Collect restore points from WMI
function Get-RestorePointsFromWmi {
    $Items = @()

    try {
        foreach ($RestorePoint in Get-CimInstance -Namespace 'root/default' -ClassName 'SystemRestore') {
            $CreationDate = Convert-WmiDate -WmiDate $RestorePoint.CreationTime
            if ($CreationDate) {
                $Items += [pscustomobject]@{
                    Source       = 'WMI:SystemRestore'
                    Sequence     = $RestorePoint.SequenceNumber
                    Description  = [string]$RestorePoint.Description
                    CreationTime = $CreationDate
                }
            }
        }
    }
    catch {}

    return $Items
}

# Collect restore points from both providers
function Get-AllRestorePoints {
    $Items = @()
    $Items += Get-RestorePointsFromCommand
    $Items += Get-RestorePointsFromWmi
    return $Items
}

# Determine whether a restore point matches the monthly rules
function Test-MonthlyRestorePointMatch {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$RestorePoint
    )

    $CurrentDescription = ([string]$RestorePoint.Description).Trim()
    $IsInMonth          = ($RestorePoint.CreationTime -ge $MonthStart -and $RestorePoint.CreationTime -lt $NextMonthStart)
    $HasPrefix          = $false

    foreach ($Prefix in $AcceptedPrefixes) {
        if ($CurrentDescription -match [regex]::Escape($Prefix)) {
            $HasPrefix = $true
            break
        }
    }

    $HasMonthTag = ($CurrentDescription -match [regex]::Escape($MonthTag))

    if (($IsInMonth -and $HasPrefix) -or $HasMonthTag) {
        return $true
    }

    return $false
}

# Check whether a valid monthly restore point already exists
function Test-MonthlyRestorePointExists {
    $RestorePoints = Get-AllRestorePoints

    if (-not $RestorePoints -or $RestorePoints.Count -eq 0) {
        return $false
    }

    $UniqueRestorePoints = $RestorePoints |
        Sort-Object CreationTime -Descending |
        Group-Object Sequence, Description, CreationTime |
        ForEach-Object { $_.Group | Select-Object -First 1 }

    foreach ($RestorePoint in $UniqueRestorePoints) {
        if (Test-MonthlyRestorePointMatch -RestorePoint $RestorePoint) {
            Write-Log -Message "Existing valid restore point found: '$($RestorePoint.Description)' at $($RestorePoint.CreationTime) via $($RestorePoint.Source)" -Level 'SUCCESS'
            return $true
        }
    }

    return $false
}

# Ensure System Protection is available on the target drive
function Ensure-SystemProtection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Drive
    )

    try {
        $null = Get-ComputerRestorePoint -ErrorAction Stop
        Write-Log -Message "System Protection is already available on $Drive." -Level 'SUCCESS'
        return $true
    }
    catch {}

    Write-Log -Message "System Protection is not available. Attempting to enable it on $Drive." -Level 'WARNING'

    try {
        Enable-ComputerRestore -Drive $Drive -ErrorAction Stop
        Start-Sleep -Seconds 2
        $null = Get-ComputerRestorePoint -ErrorAction Stop
        Write-Log -Message "System Protection enabled successfully on $Drive." -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-Log -Message "Failed to enable System Protection on $Drive : $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

# Create a restore point and temporarily bypass the 24-hour throttle
function New-MonthlyRestorePoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RestorePointDescription
    )

    $RegistryPath  = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $ValueName     = 'SystemRestorePointCreationFrequency'
    $OriginalValue = $null
    $HadValue      = $false

    try {
        if (-not (Test-Path -Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force | Out-Null
        }

        try {
            $CurrentValue = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop
            $OriginalValue = $CurrentValue.$ValueName
            $HadValue = $true
        }
        catch {}

        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value 0 -Force
        Write-Log -Message 'Temporarily cleared the restore point creation throttle.'
    }
    catch {
        Write-Log -Message "Failed to modify the restore point throttle setting: $($_.Exception.Message)" -Level 'WARNING'
    }

    try {
        Checkpoint-Computer -Description $RestorePointDescription -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log -Message "Restore point created successfully: $RestorePointDescription" -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-Log -Message "MODIFY_SETTINGS failed: $($_.Exception.Message). Trying APPLICATION_INSTALL." -Level 'WARNING'

        try {
            Checkpoint-Computer -Description $RestorePointDescription -RestorePointType APPLICATION_INSTALL -ErrorAction Stop
            Write-Log -Message "Restore point created successfully using APPLICATION_INSTALL: $RestorePointDescription" -Level 'SUCCESS'
            return $true
        }
        catch {
            Write-Log -Message "Restore point creation failed: $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
    finally {
        try {
            if ($HadValue) {
                Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value $OriginalValue -Force
                Write-Log -Message "Restored throttle value to: $OriginalValue"
            }
            else {
                Remove-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
                Write-Log -Message 'Removed temporary throttle override.'
            }
        }
        catch {
            Write-Log -Message 'Failed to restore the throttle registry setting.' -Level 'WARNING'
        }
    }
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "OS drive: $OsDrive"
Write-Log -Message "Month tag: $MonthTag"
Write-Log -Message "Restore point description: $Description"
Write-Log -Message "Log file: $LogFile"

try {
    # Do nothing when the device is already compliant
    if (Test-MonthlyRestorePointExists) {
        Write-Log -Message 'Device is already compliant. No action is required.' -Level 'SUCCESS'
        exit 0
    }

    # Make sure System Protection is available
    if (-not (Ensure-SystemProtection -Drive $OsDrive)) {
        Write-Log -Message 'System Protection is unavailable. Remediation stopped.' -Level 'ERROR'
        exit 2
    }

    # Create the required restore point
    if (New-MonthlyRestorePoint -RestorePointDescription $Description) {
        Write-Log -Message 'Monthly restore point remediation completed successfully.' -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message 'Failed to create the required monthly restore point.' -Level 'ERROR'
    exit 3
}
catch {
    Write-Log -Message "Unexpected remediation error: $($_.Exception.Message)" -Level 'ERROR'
    exit 4
}

#endregion ---------- Remediation Logic ----------
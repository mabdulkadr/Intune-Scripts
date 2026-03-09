<#
.SYNOPSIS
    Detects whether a valid monthly system restore point exists.

.DESCRIPTION
    This detection script checks system restore points from both
    Get-ComputerRestorePoint and the SystemRestore WMI provider.

    A device is treated as compliant when at least one restore point matches
    the accepted naming rules for the current month.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant

.RUN AS
    System

.EXAMPLE
    .\MonthlyRestorePoint--Detect.ps1

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
$ScriptName     = 'MonthlyRestorePoint--Detect.ps1'
$ScriptBaseName = 'MonthlyRestorePoint--Detect'
$SolutionName   = 'Monthly System Restore Point Compliance'

# Accepted restore point naming patterns
$AcceptedPrefixes = @(
    'Monthly System Restore Point',
    'Intune Monthly Restore Point',
    'System Safety Restore Point'
)

# Current month window
$Now            = Get-Date
$MonthStart     = Get-Date -Year $Now.Year -Month $Now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$NextMonthStart = $MonthStart.AddMonths(1)
$MonthTag       = "({0})" -f $MonthStart.ToString('yyyy-MM')

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

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

# Safely parse restore point time values
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

# Check whether a restore point matches the monthly compliance rules
function Test-MonthlyRestorePoint {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$RestorePoint
    )

    $Description = ([string]$RestorePoint.Description).Trim()
    $IsInMonth   = ($RestorePoint.CreationTime -ge $MonthStart -and $RestorePoint.CreationTime -lt $NextMonthStart)
    $HasPrefix   = $false

    foreach ($Prefix in $AcceptedPrefixes) {
        if ($Description -match [regex]::Escape($Prefix)) {
            $HasPrefix = $true
            break
        }
    }

    $HasMonthTag = ($Description -match [regex]::Escape($MonthTag))

    if (($IsInMonth -and $HasPrefix) -or $HasMonthTag) {
        return [pscustomobject]@{
            IsMatch = $true
            Reason  = if ($HasMonthTag) { 'MonthTag' } else { 'Prefix+Window' }
        }
    }

    return [pscustomobject]@{
        IsMatch = $false
        Reason  = ''
    }
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Month start: $($MonthStart.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Log -Message "Next month start: $($NextMonthStart.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Log -Message "Month tag: $MonthTag"
Write-Log -Message "Accepted prefixes: $($AcceptedPrefixes -join ', ')"
Write-Log -Message "Log file: $LogFile"

try {
    # Collect restore points from both providers
    $RestorePoints = @()
    $RestorePoints += Get-RestorePointsFromCommand
    $RestorePoints += Get-RestorePointsFromWmi

    if (-not $RestorePoints -or $RestorePoints.Count -eq 0) {
        Write-Log -Message 'No restore points were found on the system.' -Level 'WARNING'
        Write-Output 'Detection: Non-compliant - No restore points found on system.'
        exit 1
    }

    Write-Log -Message "Restore points collected: $($RestorePoints.Count)"

    # Remove duplicate restore points returned by both providers
    $UniqueRestorePoints = $RestorePoints |
        Sort-Object CreationTime -Descending |
        Group-Object Sequence, Description, CreationTime |
        ForEach-Object { $_.Group | Select-Object -First 1 }

    Write-Log -Message "Unique restore points after deduplication: $($UniqueRestorePoints.Count)"

    foreach ($RestorePoint in $UniqueRestorePoints) {
        $Description = ([string]$RestorePoint.Description).Trim()
        $MatchResult = Test-MonthlyRestorePoint -RestorePoint $RestorePoint

        Write-Log -Message "Evaluating restore point: '$Description' | $($RestorePoint.CreationTime) | $($RestorePoint.Source)"

        if ($MatchResult.IsMatch) {
            Write-Log -Message "Valid monthly restore point found: '$Description' at $($RestorePoint.CreationTime) via $($RestorePoint.Source) (Reason: $($MatchResult.Reason))" -Level 'SUCCESS'
            Write-Output "Detection: Compliant - '$Description' at $($RestorePoint.CreationTime) via $($RestorePoint.Source) (Reason: $($MatchResult.Reason))"
            exit 0
        }
    }

    Write-Log -Message "No valid restore point was found for $($MonthStart.ToString('yyyy-MM'))." -Level 'WARNING'
    Write-Output "Detection: Non-compliant - No valid restore point found for $($MonthStart.ToString('yyyy-MM'))."
    exit 1
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Output "Detection error: $($_.Exception.Message)"
    exit 1
}

#endregion ---------- Detection Logic ----------
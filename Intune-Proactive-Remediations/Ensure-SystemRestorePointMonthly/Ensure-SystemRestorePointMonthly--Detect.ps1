<#
.SYNOPSIS
    Detect whether a valid monthly system restore point exists.

.DESCRIPTION
    This detection script checks system restore points from both
    `Get-ComputerRestorePoint` and the `SystemRestore` WMI provider.

    A device is treated as compliant when at least one restore point matches
    the accepted naming rules for the current month.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\Ensure-SystemRestorePointMonthly--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName       = 'Ensure-SystemRestorePointMonthly--Detect.ps1'
$SolutionName     = 'Ensure-SystemRestorePointMonthly'
$ScriptMode       = 'Detection'
$AcceptedPrefixes = @(
    'Monthly System Restore Point',
    'Intune Monthly Restore Point',
    'System Safety Restore Point'
)

$Now            = Get-Date
$MonthStart     = Get-Date -Year $Now.Year -Month $Now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$NextMonthStart = $MonthStart.AddMonths(1)
$MonthTag       = '({0})' -f $MonthStart.ToString('yyyy-MM')

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Ensure-SystemRestorePointMonthly--Detect.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

# Create the log folder and file when needed.
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

# Write the same banner to the console and the log file.
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

# Write one formatted log line.
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

# Convert a WMI datetime string to a standard DateTime object.
function Convert-WmiDate {
    param([string]$WmiDate)

    try {
        return [System.Management.ManagementDateTimeConverter]::ToDateTime($WmiDate)
    }
    catch {
        return $null
    }
}

# Attempt to parse different restore point time formats safely.
function Convert-ToDateTime {
    param([object]$Value)

    try {
        return [datetime]$Value
    }
    catch {}

    foreach ($format in 'G', 'g', 'yyyy-MM-dd HH:mm:ss', 'MM/dd/yyyy HH:mm:ss', 'dd/MM/yyyy HH:mm:ss') {
        try {
            return [datetime]::ParseExact([string]$Value, $format, $null)
        }
        catch {}
    }

    return $null
}

# Collect restore points from both available providers and remove duplicates.
function Get-RestorePoints {
    $collection = New-Object System.Collections.Generic.List[object]

    try {
        foreach ($restorePoint in Get-ComputerRestorePoint) {
            $creationDate = Convert-ToDateTime -Value $restorePoint.CreationTime
            if ($creationDate) {
                $collection.Add([pscustomobject]@{
                    Source       = 'Get-ComputerRestorePoint'
                    Sequence     = $restorePoint.SequenceNumber
                    Description  = ($restorePoint.Description).Trim()
                    CreationTime = $creationDate
                })
            }
        }
    }
    catch {}

    try {
        foreach ($restorePoint in Get-CimInstance -Namespace 'root/default' -ClassName 'SystemRestore') {
            $creationDate = Convert-WmiDate -WmiDate $restorePoint.CreationTime
            if ($creationDate) {
                $collection.Add([pscustomobject]@{
                    Source       = 'WMI:SystemRestore'
                    Sequence     = $restorePoint.SequenceNumber
                    Description  = ($restorePoint.Description).Trim()
                    CreationTime = $creationDate
                })
            }
        }
    }
    catch {}

    return @(
        $collection |
        Sort-Object CreationTime -Descending |
        Group-Object Sequence, Description, CreationTime |
        ForEach-Object { $_.Group | Select-Object -First 1 }
    )
}

# Test whether a valid restore point exists for the current month.
function Test-MonthlyRestorePoint {
    param([object[]]$RestorePoints)

    foreach ($restorePoint in $RestorePoints) {
        $description = $restorePoint.Description
        $isInMonth   = ($restorePoint.CreationTime -ge $MonthStart -and $restorePoint.CreationTime -lt $NextMonthStart)
        $prefixMatch = $AcceptedPrefixes | Where-Object { $description -match [regex]::Escape($_) }
        $tagMatch    = ($description -match [regex]::Escape($MonthTag))

        if (($isInMonth -and $prefixMatch) -or $tagMatch) {
            return $restorePoint
        }
    }

    return $null
}

# Write the final result, emit the Intune compliance state, and exit.
function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$ComplianceState
    )

    Write-Log -Message $Message -Level $Level

    if ($ComplianceState) {
        Write-Output $ComplianceState
    }

    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Checking restore points for month tag: {0}" -f $MonthTag)

try {
    $restorePoints = Get-RestorePoints

    if ($restorePoints.Count -eq 0) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message 'No restore points were found on the system.'
    }

    Write-Log -Message ("Restore points collected: {0}" -f $restorePoints.Count)
    $matchingRestorePoint = Test-MonthlyRestorePoint -RestorePoints $restorePoints

    if ($matchingRestorePoint) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -ComplianceState 'Compliant' -Message ("Valid monthly restore point found: '{0}' at {1} via {2}" -f $matchingRestorePoint.Description, $matchingRestorePoint.CreationTime, $matchingRestorePoint.Source)
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message ("No valid restore point was found for {0}." -f $MonthStart.ToString('yyyy-MM'))
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -ComplianceState 'Not Compliant' -Message ("Detection error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------

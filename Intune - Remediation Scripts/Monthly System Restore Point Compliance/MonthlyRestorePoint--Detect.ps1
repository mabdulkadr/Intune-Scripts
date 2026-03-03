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
    .\MonthlyRestorePoint--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'MonthlyRestorePoint--Detect.ps1'
$ScriptBaseName = 'MonthlyRestorePoint--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Accepted restore point naming patterns.
$AcceptedPrefixes = @(
    'Monthly System Restore Point',
    'Intune Monthly Restore Point',
    'System Safety Restore Point'
)

$Now            = Get-Date
$MonthStart     = Get-Date -Year $Now.Year -Month $Now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$NextMonthStart = $MonthStart.AddMonths(1)
$MonthTag       = "({0})" -f $MonthStart.ToString('yyyy-MM')
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Monthly System Restore Point Compliance"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Detection-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ==================== PATHS AND LOGGING ====================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and file exist before any write attempts.
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        # If logging init fails, the script still continues with console output.
        return $false
    }
}

$LogReady = Initialize-Logging

# Write colored console output and persist the same line to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "FAIL")]
        [string]$Level = "INFO"
    )

    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "FAIL" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    if ($LogReady) {
        try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
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
function Try-ParseDate {
    param([object]$Value)

    $DateValue = $null

    try {
        $DateValue = [datetime]$Value
    }
    catch {}

    if (-not $DateValue) {
        foreach ($Format in 'G', 'g', 'yyyy-MM-dd HH:mm:ss', 'MM/dd/yyyy HH:mm:ss', 'dd/MM/yyyy HH:mm:ss') {
            try {
                $DateValue = [datetime]::ParseExact([string]$Value, $Format, $null)
                break
            }
            catch {}
        }
    }

    return $DateValue
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Write-Log -Level "INFO" -Message "=== Detection START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Month start: {0}" -f $MonthStart.ToString('yyyy-MM-dd HH:mm:ss'))
Write-Log -Level "INFO" -Message ("Month tag: {0}" -f $MonthTag)

try {
    $RestorePoints = New-Object System.Collections.Generic.List[object]

    # Provider A: collect restore points returned by Get-ComputerRestorePoint.
    try {
        foreach ($RestorePoint in Get-ComputerRestorePoint) {
            $CreationDate = Try-ParseDate -Value $RestorePoint.CreationTime
            if ($CreationDate) {
                $RestorePoints.Add([pscustomobject]@{
                    Source       = 'Get-ComputerRestorePoint'
                    Sequence     = $RestorePoint.SequenceNumber
                    Description  = ($RestorePoint.Description).Trim()
                    CreationTime = $CreationDate
                })
            }
        }
    }
    catch {}

    # Provider B: collect restore points returned by the SystemRestore WMI class.
    try {
        foreach ($RestorePoint in Get-CimInstance -Namespace 'root/default' -ClassName 'SystemRestore') {
            $CreationDate = Convert-WmiDate -WmiDate $RestorePoint.CreationTime
            if ($CreationDate) {
                $RestorePoints.Add([pscustomobject]@{
                    Source       = 'WMI:SystemRestore'
                    Sequence     = $RestorePoint.SequenceNumber
                    Description  = ($RestorePoint.Description).Trim()
                    CreationTime = $CreationDate
                })
            }
        }
    }
    catch {}

    if ($RestorePoints.Count -eq 0) {
        Write-Log -Level "WARN" -Message "Non-compliant: no restore points were found on the system."
        Write-Output "Detection: Non-compliant – No restore points found on system."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    Write-Log -Level "INFO" -Message ("Restore points collected: {0}" -f $RestorePoints.Count)

    # Remove duplicate restore points that may be returned by both providers.
    $UniqueRestorePoints = $RestorePoints |
        Sort-Object CreationTime -Descending |
        Group-Object Sequence, Description, CreationTime |
        ForEach-Object { $_.Group | Select-Object -First 1 }

    foreach ($RestorePoint in $UniqueRestorePoints) {
        $IsInMonth   = ($RestorePoint.CreationTime -ge $MonthStart -and $RestorePoint.CreationTime -lt $NextMonthStart)
        $Description = $RestorePoint.Description

        $PrefixMatch = $AcceptedPrefixes | Where-Object { $Description -match [regex]::Escape($_) }
        $TagMatch    = ($Description -match [regex]::Escape($MonthTag))

        if (($IsInMonth -and $PrefixMatch) -or $TagMatch) {
            $Reason = if ($TagMatch) { 'MonthTag' } else { 'Prefix+Window' }
            Write-Log -Level "OK" -Message ("Compliant restore point found: '{0}' at {1} via {2} (Reason: {3})" -f $RestorePoint.Description, $RestorePoint.CreationTime, $RestorePoint.Source, $Reason)
            Write-Output ("Detection: Compliant – '{0}' at {1} via {2} (Reason: {3})" -f $RestorePoint.Description, $RestorePoint.CreationTime, $RestorePoint.Source, $Reason)
            Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
            exit 0
        }
    }

    Write-Log -Level "WARN" -Message ("Non-compliant: no valid restore point found for {0}." -f $MonthStart.ToString('yyyy-MM'))
    Write-Output ("Detection: Non-compliant – No valid restore point found for {0}." -f $MonthStart.ToString('yyyy-MM'))
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
catch {
    Write-Log -Level "FAIL" -Message ("Detection error: {0}" -f $_.Exception.Message)
    Write-Output ("Detection error: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================

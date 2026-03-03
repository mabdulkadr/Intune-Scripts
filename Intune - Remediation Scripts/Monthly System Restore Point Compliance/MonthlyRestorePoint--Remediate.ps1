<#
.SYNOPSIS
    Remediate monthly restore point compliance by creating a valid restore point when needed.

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
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\MonthlyRestorePoint--Remediate.ps1

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
$ScriptName     = 'MonthlyRestorePoint--Remediate.ps1'
$ScriptBaseName = 'MonthlyRestorePoint--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Accepted restore point naming patterns.
$CanonicalPrefix  = 'Monthly System Restore Point'
$AcceptedPrefixes = @(
    $CanonicalPrefix,
    'Intune Monthly Restore Point',
    'System Safety Restore Point'
)

# Resolve the OS drive used for System Protection.
try {
    $OsDrive = (Get-CimInstance Win32_OperatingSystem).SystemDrive
}
catch {
    $OsDrive = $env:SystemDrive
}
if (-not $OsDrive) {
    $OsDrive = $SystemDrive
}
$OsDrive = $OsDrive.TrimEnd('\')

# Monthly identifiers used in restore point naming and evaluation.
$Now            = Get-Date
$MonthStart     = Get-Date -Year $Now.Year -Month $Now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$NextMonthStart = $MonthStart.AddMonths(1)
$MonthTag       = "({0})" -f $MonthStart.ToString('yyyy-MM')
$Description    = "{0} {1}" -f $CanonicalPrefix, $MonthTag
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Monthly System Restore Point Compliance"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Remediation-specific log file.
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
        [ValidateSet("INFO", "OK", "WARN", "FAIL")][string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line      = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

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

# Collect restore points from both available providers.
function Get-AllRestorePoints {
    $Collection = New-Object System.Collections.Generic.List[object]

    try {
        foreach ($RestorePoint in Get-ComputerRestorePoint) {
            $CreationDate = Try-ParseDate -Value $RestorePoint.CreationTime
            if ($CreationDate) {
                $Collection.Add([pscustomobject]@{
                    Source       = 'Get-ComputerRestorePoint'
                    Sequence     = $RestorePoint.SequenceNumber
                    Description  = ($RestorePoint.Description).Trim()
                    CreationTime = $CreationDate
                })
            }
        }
    }
    catch {}

    try {
        foreach ($RestorePoint in Get-CimInstance -Namespace 'root/default' -ClassName 'SystemRestore') {
            $CreationDate = Convert-WmiDate -WmiDate $RestorePoint.CreationTime
            if ($CreationDate) {
                $Collection.Add([pscustomobject]@{
                    Source       = 'WMI:SystemRestore'
                    Sequence     = $RestorePoint.SequenceNumber
                    Description  = ($RestorePoint.Description).Trim()
                    CreationTime = $CreationDate
                })
            }
        }
    }
    catch {}

    return $Collection
}

# Determine whether a valid monthly restore point already exists.
function Test-MonthlyRestorePoint {
    $RestorePoints = Get-AllRestorePoints
    if (-not $RestorePoints -or $RestorePoints.Count -eq 0) {
        return $false
    }

    foreach ($RestorePoint in ($RestorePoints | Sort-Object CreationTime -Descending)) {
        $CurrentDescription = $RestorePoint.Description
        $IsInMonth          = ($RestorePoint.CreationTime -ge $MonthStart -and $RestorePoint.CreationTime -lt $NextMonthStart)

        $PrefixMatch = $AcceptedPrefixes | Where-Object { $CurrentDescription -match [regex]::Escape($_) }
        $TagMatch    = ($CurrentDescription -match [regex]::Escape($MonthTag))

        if (($IsInMonth -and $PrefixMatch) -or $TagMatch) {
            return $true
        }
    }

    return $false
}

# Ensure System Protection is available for the target drive.
function Ensure-SystemProtection {
    param([string]$Drive)

    try {
        $null = Get-ComputerRestorePoint
        return $true
    }
    catch {}

    Write-Log -Level "WARN" -Message ("System Protection is not enabled. Attempting to enable it on {0}." -f $Drive)

    try {
        Enable-ComputerRestore -Drive $Drive
        Start-Sleep -Seconds 2
        $null = Get-ComputerRestorePoint
        Write-Log -Level "OK" -Message ("System Protection enabled successfully on {0}." -f $Drive)
        return $true
    }
    catch {
        Write-Log -Level "FAIL" -Message ("Failed to enable System Protection: {0}" -f $_.Exception.Message)
        return $false
    }
}

# Create the required monthly restore point, temporarily bypassing the 24-hour throttle.
function New-MonthlyRestorePoint {
    param([string]$RestorePointDescription)

    $RegistryPath  = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $ValueName     = 'SystemRestorePointCreationFrequency'
    $OriginalValue = $null
    $HadValue      = $false

    try {
        if (Test-Path -Path $RegistryPath) {
            try {
                $CurrentValue = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop
                $OriginalValue = $CurrentValue.$ValueName
                $HadValue = $true
            }
            catch {}

            Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value 0 -Force
            Write-Log -Level "INFO" -Message "Temporarily cleared the restore point creation throttle."
        }
    }
    catch {
        Write-Log -Level "WARN" -Message ("Failed to modify the throttle registry value: {0}" -f $_.Exception.Message)
    }

    try {
        Checkpoint-Computer -Description $RestorePointDescription -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log -Level "OK" -Message ("Restore point created successfully: {0}" -f $RestorePointDescription)
        return $true
    }
    catch {
        Write-Log -Level "WARN" -Message ("MODIFY_SETTINGS failed: {0}. Trying APPLICATION_INSTALL." -f $_.Exception.Message)
        try {
            Checkpoint-Computer -Description $RestorePointDescription -RestorePointType APPLICATION_INSTALL -ErrorAction Stop
            Write-Log -Level "OK" -Message "Restore point created successfully using APPLICATION_INSTALL."
            return $true
        }
        catch {
            Write-Log -Level "FAIL" -Message ("Restore point creation failed: {0}" -f $_.Exception.Message)
            return $false
        }
    }
    finally {
        try {
            if ($HadValue) {
                Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value $OriginalValue -Force
                Write-Log -Level "INFO" -Message ("Restored throttle value: {0}" -f $OriginalValue)
            }
            else {
                Remove-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
                Write-Log -Level "INFO" -Message "Removed the temporary throttle override."
            }
        }
        catch {
            Write-Log -Level "WARN" -Message "Failed to restore the throttle registry setting."
        }
    }
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
Write-Log -Level "INFO" -Message "=== Remediation START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("OS drive: {0}" -f $OsDrive)
Write-Log -Level "INFO" -Message ("Month tag: {0}" -f $MonthTag)

try {
    if (Test-MonthlyRestorePoint) {
        Write-Log -Level "OK" -Message "Device is already compliant. No action is required."
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
        exit 0
    }

    if (-not (Ensure-SystemProtection -Drive $OsDrive)) {
        Write-Log -Level "FAIL" -Message "System Protection is unavailable. Remediation aborted."
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 2) ==="
        exit 2
    }

    if (New-MonthlyRestorePoint -RestorePointDescription $Description) {
        Write-Log -Level "OK" -Message "Remediation completed successfully."
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
        exit 0
    }

    Write-Log -Level "FAIL" -Message "Failed to create the required restore point."
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 3) ==="
    exit 3
}
catch {
    Write-Log -Level "FAIL" -Message ("Unexpected error: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 4) ==="
    exit 4
}
#endregion ================= FIRST REMEDIATION BLOCK =================

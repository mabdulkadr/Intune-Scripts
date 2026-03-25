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
    .\Ensure-SystemRestorePointMonthly--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName       = 'Ensure-SystemRestorePointMonthly--Remediate.ps1'
$SolutionName     = 'Ensure-SystemRestorePointMonthly'
$ScriptMode       = 'Remediation'
$CanonicalPrefix  = 'Monthly System Restore Point'
$AcceptedPrefixes = @(
    $CanonicalPrefix,
    'Intune Monthly Restore Point',
    'System Safety Restore Point'
)

try {
    $OsDrive = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).SystemDrive
}
catch {
    $OsDrive = $env:SystemDrive
}

if (-not $OsDrive) {
    $OsDrive = $env:SystemDrive
}
$OsDrive = $OsDrive.TrimEnd('\')

$Now            = Get-Date
$MonthStart     = Get-Date -Year $Now.Year -Month $Now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$NextMonthStart = $MonthStart.AddMonths(1)
$MonthTag       = '({0})' -f $MonthStart.ToString('yyyy-MM')
$Description    = '{0} {1}' -f $CanonicalPrefix, $MonthTag

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Ensure-SystemRestorePointMonthly--Remediate.txt'
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

# Determine whether a valid monthly restore point already exists.
function Test-MonthlyRestorePoint {
    foreach ($restorePoint in (Get-RestorePoints)) {
        $description = $restorePoint.Description
        $isInMonth   = ($restorePoint.CreationTime -ge $MonthStart -and $restorePoint.CreationTime -lt $NextMonthStart)
        $prefixMatch = $AcceptedPrefixes | Where-Object { $description -match [regex]::Escape($_) }
        $tagMatch    = ($description -match [regex]::Escape($MonthTag))

        if (($isInMonth -and $prefixMatch) -or $tagMatch) {
            return $true
        }
    }

    return $false
}

# Ensure System Protection is available for the target drive.
function Ensure-SystemProtection {
    param([string]$Drive)

    try {
        $null = Get-ComputerRestorePoint -ErrorAction Stop
        return $true
    }
    catch {}

    Write-Log -Message ("System Protection is not enabled. Attempting to enable it on {0}." -f $Drive) -Level 'WARNING'

    try {
        Enable-ComputerRestore -Drive $Drive -ErrorAction Stop
        Start-Sleep -Seconds 2
        $null = Get-ComputerRestorePoint -ErrorAction Stop
        Write-Log -Message ("System Protection enabled successfully on {0}." -f $Drive) -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-Log -Message ("Failed to enable System Protection: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return $false
    }
}

# Create the required monthly restore point, temporarily bypassing the 24-hour throttle.
function New-MonthlyRestorePoint {
    param([string]$RestorePointDescription)

    $registryPath  = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $valueName     = 'SystemRestorePointCreationFrequency'
    $originalValue = $null
    $hadValue      = $false

    try {
        if (Test-Path -Path $registryPath) {
            try {
                $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction Stop
                $originalValue = $currentValue.$valueName
                $hadValue = $true
            }
            catch {}

            Set-ItemProperty -Path $registryPath -Name $valueName -Value 0 -Force
            Write-Log -Message 'Temporarily cleared the restore point creation throttle.'
        }
    }
    catch {
        Write-Log -Message ("Failed to modify the throttle registry value: {0}" -f $_.Exception.Message) -Level 'WARNING'
    }

    try {
        Checkpoint-Computer -Description $RestorePointDescription -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log -Message ("Restore point created successfully: {0}" -f $RestorePointDescription) -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-Log -Message ("MODIFY_SETTINGS failed: {0}. Trying APPLICATION_INSTALL." -f $_.Exception.Message) -Level 'WARNING'
        try {
            Checkpoint-Computer -Description $RestorePointDescription -RestorePointType APPLICATION_INSTALL -ErrorAction Stop
            Write-Log -Message 'Restore point created successfully using APPLICATION_INSTALL.' -Level 'SUCCESS'
            return $true
        }
        catch {
            Write-Log -Message ("Restore point creation failed: {0}" -f $_.Exception.Message) -Level 'ERROR'
            return $false
        }
    }
    finally {
        try {
            if ($hadValue) {
                Set-ItemProperty -Path $registryPath -Name $valueName -Value $originalValue -Force
                Write-Log -Message ("Restored throttle value: {0}" -f $originalValue)
            }
            else {
                Remove-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
                Write-Log -Message 'Removed the temporary throttle override.'
            }
        }
        catch {
            Write-Log -Message 'Failed to restore the throttle registry setting.' -Level 'WARNING'
        }
    }
}

# Write the final message and exit with the right code.
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

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("OS drive: {0}" -f $OsDrive)
Write-Log -Message ("Checking restore point compliance for month tag: {0}" -f $MonthTag)

try {
    if (Test-MonthlyRestorePoint) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'A valid monthly restore point already exists. No action is required.'
    }

    if (-not (Ensure-SystemProtection -Drive $OsDrive)) {
        Finish-Script -ExitCode 2 -Level 'ERROR' -Message 'System Protection is unavailable. Remediation aborted.'
    }

    if (New-MonthlyRestorePoint -RestorePointDescription $Description) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Monthly restore point remediation completed successfully.'
    }

    Finish-Script -ExitCode 3 -Level 'ERROR' -Message 'Failed to create the required monthly restore point.'
}
catch {
    Finish-Script -ExitCode 4 -Level 'ERROR' -Message ("Unexpected remediation error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------

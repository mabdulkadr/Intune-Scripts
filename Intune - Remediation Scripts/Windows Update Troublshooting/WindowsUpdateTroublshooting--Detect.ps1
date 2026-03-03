<#
.SYNOPSIS
    Detects whether the last installed Windows update is recent enough.

.DESCRIPTION
    This detection script checks the date of the most recent installed Windows
    update and marks the device as non-compliant when that update is older than
    the configured threshold.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Non-compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\WindowsUpdateTroublshooting--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'WindowsUpdateTroublshooting--Detect.ps1'
$ScriptBaseName = 'WindowsUpdateTroublshooting--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive   = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$LogFolderName = 'Windows Update Troublshooting'
$LogDirectory  = Join-Path $SystemDrive "Intune\$LogFolderName"
$LogFilePath   = Join-Path $LogDirectory "$ScriptBaseName.txt"

# Define the maximum acceptable age of the last update.
$UpdateThresholdDays = 40
#endregion ====================== CONFIGURATION =========================

#region ======================= HELPER FUNCTIONS =======================
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogLine   = "[$Timestamp] [$Level] $Message"

    Add-Content -Path $LogFilePath -Value $LogLine -Encoding UTF8
    Write-Output $LogLine
}

function Get-LatestInstalledUpdateDate {
    $LatestHotFix = Get-HotFix -ErrorAction Stop |
        Where-Object { $_.InstalledOn } |
        Sort-Object -Property InstalledOn |
        Select-Object -Last 1

    if ($null -eq $LatestHotFix) {
        return $null
    }

    return [datetime]$LatestHotFix.InstalledOn
}
#endregion ==================== HELPER FUNCTIONS =======================

#region ===================== FIRST DETECTION BLOCK =====================
try {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    Write-Log -Message '=== Detection START ==='
    Write-Log -Message "Script: $ScriptName"
    Write-Log -Message "Log file: $LogFilePath"
    Write-Log -Message "Update age threshold (days): $UpdateThresholdDays"

    # Read the most recent installed hotfix date.
    $LastUpdate = Get-LatestInstalledUpdateDate
    if ($null -eq $LastUpdate) {
        Write-Log -Message 'No installed Windows updates were found on the system.' -Level 'FAIL'
        Write-Log -Message '=== Detection END (Exit 1) ==='
        exit 1
    }

    Write-Log -Message "Last installed update date: $($LastUpdate.ToString('yyyy-MM-dd'))"

    # Calculate how many days have passed since the last installed update.
    $CurrentDate     = Get-Date
    $DaysSinceUpdate = (New-TimeSpan -Start $LastUpdate -End $CurrentDate).Days
    Write-Log -Message "Days since last update: $DaysSinceUpdate"

    if ($DaysSinceUpdate -ge $UpdateThresholdDays) {
        Write-Log -Message "The last update was installed $DaysSinceUpdate days ago, which exceeds the threshold." -Level 'WARN'
        Write-Log -Message '=== Detection END (Exit 1) ==='
        exit 1
    }

    Write-Log -Message "Windows Update recency is compliant. Last update age is $DaysSinceUpdate day(s)." -Level 'OK'
    Write-Log -Message '=== Detection END (Exit 0) ==='
    exit 0
}
catch {
    Write-Log -Message "Detection error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================

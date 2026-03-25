<#
.SYNOPSIS
    Detects whether Intune Management Extension activity occurred recently.

.DESCRIPTION
    This detection script verifies strict IME activity by checking:
    1. The Intune Management Extension service exists and is running.
    2. The main IME log file exists.
    3. The log file was updated within the configured lookback window.
    4. Recent log content shows IME operational activity.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant

.RUN AS
    System

.EXAMPLE
    .\IntuneIMESync--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 2.0
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'IntuneIMESync--Detect.ps1'
$ScriptBaseName = 'IntuneIMESync--Detect'
$SolutionName   = 'IntuneSyncTrigger'

# IME service and log settings
$ServiceName   = 'IntuneManagementExtension'
$LookbackHours = 8
$ImeLogRoot    = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$ImeMainLog    = Join-Path $ImeLogRoot 'IntuneManagementExtension.log'

# Keywords used as practical indicators of IME activity
$ActivityPatterns = @(
    'check[- ]?in',
    'policy',
    'report',
    'health',
    'sidecar',
    'request'
)

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

# Return a readable time span string
function Get-AgeText {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$DateTimeValue
    )

    $Span = New-TimeSpan -Start $DateTimeValue -End (Get-Date)
    return ('{0} day(s), {1} hour(s), {2} minute(s)' -f $Span.Days, $Span.Hours, $Span.Minutes)
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Service name: $ServiceName"
Write-Log -Message "IME log path: $ImeMainLog"
Write-Log -Message "Lookback window: $LookbackHours hour(s)"
Write-Log -Message "Log file: $LogFile"

try {
    # 1) Service must exist and run
    $ImeService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $ImeService) {
        Write-Log -Message "IME service '$ServiceName' was not found." -Level 'WARNING'
        exit 1
    }

    Write-Log -Message "IME service state: $($ImeService.Status)"

    if ($ImeService.Status -ne 'Running') {
        Write-Log -Message "IME service is not running." -Level 'WARNING'
        exit 1
    }

    # 2) Main log must exist
    if (-not (Test-Path -Path $ImeMainLog)) {
        Write-Log -Message "IME main log file was not found: $ImeMainLog" -Level 'WARNING'
        exit 1
    }

    $LogItem = Get-Item -Path $ImeMainLog -ErrorAction Stop
    $LastWriteTime = $LogItem.LastWriteTime
    $CutoffTime    = (Get-Date).AddHours(-$LookbackHours)

    Write-Log -Message "IME log last write time: $LastWriteTime"
    Write-Log -Message "IME log age: $(Get-AgeText -DateTimeValue $LastWriteTime)"

    # 3) File must be updated recently
    if ($LastWriteTime -lt $CutoffTime) {
        Write-Log -Message "IME log has not been updated within the last $LookbackHours hour(s)." -Level 'WARNING'
        exit 1
    }

    # 4) Recent log text should show actual activity
    $RecentLines = Get-Content -Path $ImeMainLog -Tail 300 -ErrorAction Stop
    $Pattern     = ($ActivityPatterns -join '|')
    $MatchedLine = $RecentLines | Select-String -Pattern $Pattern -CaseSensitive:$false | Select-Object -Last 1

    if (-not $MatchedLine) {
        Write-Log -Message 'IME log was updated recently, but no clear recent activity pattern was found in the latest log lines.' -Level 'WARNING'
        exit 1
    }

    Write-Log -Message "Recent IME activity detected: $($MatchedLine.Line)" -Level 'SUCCESS'
    Write-Log -Message 'IME activity verification passed.' -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Detection Logic ----------
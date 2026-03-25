<#
.SYNOPSIS
    Repairs common Intune stuck-sync conditions on Windows devices.

.DESCRIPTION
    This remediation script performs a safe Intune sync recovery workflow.

    The script attempts to:
    1. Validate and start DmWapPushService
    2. Restart or start the Intune Management Extension service
    3. Trigger all EnterpriseMgmt scheduled tasks
    4. Write actions to the remediation log

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Remediation failed

.RUN AS
    System

.EXAMPLE
    .\IntuneStuckSyncFixer--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'IntuneStuckSyncFixer--Remediate.ps1'
$ScriptBaseName = 'IntuneStuckSyncFixer--Remediate'
$SolutionName   = 'Intune Stuck Sync Fixer'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    'C:'
}

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

# Remediation settings
$ImeLogsRoot     = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$ImeHealthLog    = Join-Path $ImeLogsRoot 'HealthScripts.log'
$SleepAfterIME   = 8
$DmServiceName   = 'DmWapPushService'
$ImeServiceName  = 'IntuneManagementExtension'

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -LiteralPath $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $LogFile)) {
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

    # Best effort إضافي داخل HealthScripts.log لو كان موجودًا
    try {
        if (Test-Path -LiteralPath $ImeLogsRoot) {
            Add-Content -Path $ImeHealthLog -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }
    catch {}
}

# Return basic service information from Win32_Service
function Get-ServiceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $Service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
    }
    catch {
        return $null
    }

    return [pscustomobject]@{
        Name      = $Service.Name
        State     = $Service.State
        StartMode = $Service.StartMode
    }
}

# Start a service if it is not already running
function Ensure-ServiceRunning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $ServiceInfo = Get-ServiceInfo -Name $Name
    if (-not $ServiceInfo) {
        return [pscustomobject]@{
            Success = $false
            Result  = 'NotFound'
        }
    }

    try {
        $Service = Get-Service -Name $Name -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Result  = "GetServiceFailed: $($_.Exception.Message)"
        }
    }

    if ($Service.Status -eq 'Running') {
        return [pscustomobject]@{
            Success = $true
            Result  = 'AlreadyRunning'
        }
    }

    try {
        Start-Service -Name $Name -ErrorAction Stop
        Start-Sleep -Seconds 2

        $ServiceAfter = Get-Service -Name $Name -ErrorAction Stop
        if ($ServiceAfter.Status -eq 'Running') {
            return [pscustomobject]@{
                Success = $true
                Result  = 'Started'
            }
        }

        return [pscustomobject]@{
            Success = $false
            Result  = 'StartAttemptedButNotRunning'
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Result  = "StartFailed: $($_.Exception.Message)"
        }
    }
}

# Restart or start the Intune Management Extension service
function Restart-IME {
    $ImeInfo = Get-ServiceInfo -Name $ImeServiceName
    if (-not $ImeInfo) {
        Write-Log -Message "IME service is not installed: $ImeServiceName" -Level 'ERROR'
        return $false
    }

    try {
        $Service = Get-Service -Name $ImeServiceName -ErrorAction Stop

        if ($Service.Status -eq 'Running') {
            Write-Log -Message 'Restarting Intune Management Extension service...'
            Restart-Service -Name $ImeServiceName -Force -ErrorAction Stop
        }
        else {
            Write-Log -Message 'Starting Intune Management Extension service...'
            Start-Service -Name $ImeServiceName -ErrorAction Stop
        }

        Start-Sleep -Seconds $SleepAfterIME

        $ServiceAfter = Get-Service -Name $ImeServiceName -ErrorAction Stop
        if ($ServiceAfter.Status -eq 'Running') {
            Write-Log -Message 'IME service is running after remediation.' -Level 'SUCCESS'
            return $true
        }

        Write-Log -Message "IME service failed to reach running state. Current status: $($ServiceAfter.Status)" -Level 'ERROR'
        return $false
    }
    catch {
        Write-Log -Message "Failed to restart or start IME service: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

# Run a scheduled task using schtasks.exe
function Run-TaskBySchtasks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullTaskName
    )

    try {
        $Args = "/Run /TN `"$FullTaskName`""
        $Process = Start-Process -FilePath 'schtasks.exe' -ArgumentList $Args -WindowStyle Hidden -PassThru -Wait
        return ($Process.ExitCode -eq 0)
    }
    catch {
        return $false
    }
}

# Discover EnterpriseMgmt tasks
function Get-EnterpriseMgmtTasks {
    $Tasks = @()

    $GetScheduledTaskCommand = Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue
    if ($GetScheduledTaskCommand) {
        try {
            $Tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object {
                $_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*'
            }

            return @($Tasks)
        }
        catch {
            # Fall back to schtasks parsing
        }
    }

    try {
        $RawOutput = & schtasks.exe /Query /FO LIST /V 2>$null
        if (-not $RawOutput) {
            return @()
        }

        $CurrentTaskName = $null

        foreach ($Line in $RawOutput) {
            if ($Line -match '^TaskName:\s+(?<n>.+)$') {
                $CurrentTaskName = $Matches['n'].Trim()

                if ($CurrentTaskName -like '\Microsoft\Windows\EnterpriseMgmt\*') {
                    $TaskName = Split-Path -Path $CurrentTaskName -Leaf
                    $TaskPath = $CurrentTaskName.Substring(0, $CurrentTaskName.Length - $TaskName.Length)

                    $Tasks += [pscustomobject]@{
                        TaskName = $TaskName
                        TaskPath = $TaskPath
                    }
                }
            }
        }
    }
    catch {}

    return @($Tasks)
}

# Trigger one EnterpriseMgmt task
function Start-EnterpriseMgmtTask {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Task
    )

    $TaskPath = $Task.TaskPath
    if (-not $TaskPath.EndsWith('\')) {
        $TaskPath += '\'
    }

    $FullTaskName = "$TaskPath$($Task.TaskName)"
    $Started = $false

    $StartScheduledTaskCommand = Get-Command -Name Start-ScheduledTask -ErrorAction SilentlyContinue
    if ($StartScheduledTaskCommand) {
        try {
            Start-ScheduledTask -TaskPath $TaskPath -TaskName $Task.TaskName -ErrorAction Stop
            $Started = $true
        }
        catch {
            $Started = $false
        }
    }

    if (-not $Started) {
        $Started = Run-TaskBySchtasks -FullTaskName $FullTaskName
    }

    return [pscustomobject]@{
        FullTaskName = $FullTaskName
        Success      = $Started
    }
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "DmWapPushService name: $DmServiceName"
Write-Log -Message "IntuneManagementExtension name: $ImeServiceName"
Write-Log -Message "HealthScripts log: $ImeHealthLog"
Write-Log -Message "Log file: $LogFile"

try {
    # Step 1: Validate and start DmWapPushService
    $DmService = Get-ServiceInfo -Name $DmServiceName

    if (-not $DmService) {
        Write-Log -Message "MDM transport service is missing: $DmServiceName" -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "DmWapPushService state: $($DmService.State) | StartMode: $($DmService.StartMode)"

    $DmResult = Ensure-ServiceRunning -Name $DmServiceName
    if ($DmResult.Success) {
        Write-Log -Message "DmWapPushService action result: $($DmResult.Result)" -Level 'SUCCESS'
    }
    else {
        Write-Log -Message "DmWapPushService action result: $($DmResult.Result)" -Level 'WARNING'
    }

    # Step 2: Restart or start Intune Management Extension
    if (-not (Restart-IME)) {
        exit 1
    }

    # Step 3: Discover and trigger EnterpriseMgmt tasks
    Write-Log -Message 'Discovering EnterpriseMgmt scheduled tasks...'
    $Tasks = @(Get-EnterpriseMgmtTasks)

    Write-Log -Message "EnterpriseMgmt tasks discovered: $($Tasks.Count)"

    if ($Tasks.Count -lt 1) {
        Write-Log -Message 'No EnterpriseMgmt scheduled tasks were found.' -Level 'ERROR'
        exit 1
    }

    $AttemptedCount = 0
    $TriggeredCount = 0

    foreach ($Task in $Tasks) {
        $AttemptedCount++

        $TaskResult = Start-EnterpriseMgmtTask -Task $Task
        if ($TaskResult.Success) {
            $TriggeredCount++
            Write-Log -Message "Triggered task: $($TaskResult.FullTaskName)" -Level 'SUCCESS'
        }
        else {
            Write-Log -Message "Failed to trigger task: $($TaskResult.FullTaskName)" -Level 'WARNING'
        }
    }

    Write-Log -Message "EnterpriseMgmt task trigger summary: Attempted=$AttemptedCount | Triggered=$TriggeredCount"

    if ($TriggeredCount -lt 1) {
        Write-Log -Message 'No EnterpriseMgmt sync task was triggered successfully.' -Level 'ERROR'
        exit 1
    }

    Write-Log -Message 'Intune stuck-sync remediation completed successfully.' -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------
<#
.SYNOPSIS
    Remediates common Windows time configuration issues.

.DESCRIPTION
    This remediation script:
    1. Ensures the Windows Time service is running and set to Automatic.
    2. Configures time synchronization and triggers a resync.
    3. Enables automatic time zone detection.
    4. Starts the Location Service when available.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System

.EXAMPLE
    .\TimeIssues--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'TimeIssues--Remediate.ps1'
$ScriptBaseName = 'TimeIssues--Remediate'
$SolutionName   = 'Fix Windows Time Issues'

# Time-related services and settings
$TimeServiceName      = 'w32time'
$LocationServiceName  = 'lfsvc'
$TimeZoneRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$TimeZoneValueName    = 'Start'
$ExpectedTimeZoneMode = 3
$TimeServer           = 'time.windows.com'

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

# Check whether the current session has admin rights
function Test-IsAdministrator {
    try {
        $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Time service: $TimeServiceName"
Write-Log -Message "Time server: $TimeServer"
Write-Log -Message "Log file: $LogFile"

try {
    # Time configuration changes require elevation
    if (-not (Test-IsAdministrator)) {
        Write-Log -Message 'Administrative privileges are required to fix Windows time settings.' -Level 'ERROR'
        exit 1
    }

    # Make sure the Windows Time service exists
    $TimeService = Get-Service -Name $TimeServiceName -ErrorAction SilentlyContinue
    if (-not $TimeService) {
        Write-Log -Message 'Windows Time service was not found.' -Level 'ERROR'
        exit 1
    }

    # Set the service to start automatically
    Set-Service -Name $TimeServiceName -StartupType Automatic -ErrorAction Stop
    Write-Log -Message 'Windows Time service startup type set to Automatic.' -Level 'SUCCESS'

    # Start the service if needed
    if ($TimeService.Status -ne 'Running') {
        Start-Service -Name $TimeServiceName -ErrorAction Stop
        Write-Log -Message 'Windows Time service started successfully.' -Level 'SUCCESS'
    }
    else {
        Write-Log -Message 'Windows Time service is already running.' -Level 'SUCCESS'
    }

    # Configure time synchronization
    Write-Log -Message 'Configuring time synchronization...'
    & w32tm /config /manualpeerlist:$TimeServer /syncfromflags:manual /update | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to configure the Windows Time service.'
    }

    Write-Log -Message "Time synchronization configured to use $TimeServer." -Level 'SUCCESS'

    # Trigger a time resync
    Write-Log -Message 'Triggering time synchronization...'
    & w32tm /resync | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message 'Time resync did not complete successfully.' -Level 'WARNING'
    }
    else {
        Write-Log -Message 'Time synchronized successfully.' -Level 'SUCCESS'
    }

    # Make sure automatic time zone detection is enabled
    if (-not (Test-Path -Path $TimeZoneRegistryPath)) {
        New-Item -Path $TimeZoneRegistryPath -Force | Out-Null
    }

    $TimeZoneSetting = Get-ItemProperty -Path $TimeZoneRegistryPath -Name $TimeZoneValueName -ErrorAction SilentlyContinue

    if (-not $TimeZoneSetting -or $TimeZoneSetting.$TimeZoneValueName -ne $ExpectedTimeZoneMode) {
        Set-ItemProperty -Path $TimeZoneRegistryPath -Name $TimeZoneValueName -Value $ExpectedTimeZoneMode -ErrorAction Stop
        Write-Log -Message 'Automatic time zone detection enabled.' -Level 'SUCCESS'
    }
    else {
        Write-Log -Message 'Automatic time zone detection is already enabled.' -Level 'SUCCESS'
    }

    # Start the Location Service if it exists
    $LocationService = Get-Service -Name $LocationServiceName -ErrorAction SilentlyContinue

    if (-not $LocationService) {
        Write-Log -Message 'Location Service was not found. Skipping this step.' -Level 'WARNING'
    }
    else {
        try {
            Set-Service -Name $LocationServiceName -StartupType Manual -ErrorAction SilentlyContinue | Out-Null
        }
        catch {}

        if ($LocationService.Status -ne 'Running') {
            Start-Service -Name $LocationServiceName -ErrorAction Stop
            Write-Log -Message 'Location Service started successfully.' -Level 'SUCCESS'
        }
        else {
            Write-Log -Message 'Location Service is already running.' -Level 'SUCCESS'
        }
    }

    Write-Log -Message 'Time-related remediation completed successfully.' -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------
<#
.SYNOPSIS
    Repairs the device secure channel to the domain when needed.

.DESCRIPTION
    This remediation script checks whether the device is domain-joined and then
    attempts to repair the computer secure channel directly.

    Exit codes:
    - Exit 0: Completed successfully or not applicable
    - Exit 1: Repair failed or an error occurred

.RUN AS
    System

.EXAMPLE
    .\SecureChannel--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'SecureChannel--Remediate.ps1'
$ScriptBaseName = 'SecureChannel--Remediate'
$SolutionName   = 'Repair-SecureChannel'

# Optional reboot after a successful repair
$ForceRebootAfterRepair = $false

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

# Test whether the device is joined to a domain
function Get-ComputerDomainInfo {
    try {
        Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    }
    catch {
        $null
    }
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Log file: $LogFile"
Write-Log -Message "Force reboot after repair: $ForceRebootAfterRepair"

try {
    # Check domain membership first
    $ComputerSystem = Get-ComputerDomainInfo

    if (-not $ComputerSystem) {
        Write-Log -Message 'Failed to read computer system information.' -Level 'ERROR'
        exit 1
    }

    # Skip non-domain devices
    if (-not $ComputerSystem.PartOfDomain) {
        Write-Log -Message 'Device is not domain-joined. Secure channel repair is not applicable.' -Level 'SUCCESS'
        exit 0
    }

    $DomainName = $ComputerSystem.Domain
    Write-Log -Message "Domain: $DomainName"

    # Check current secure channel state before repair
    try {
        $SecureChannelHealthy = Test-ComputerSecureChannel -ErrorAction Stop
    }
    catch {
        $SecureChannelHealthy = $false
    }

    if ($SecureChannelHealthy) {
        Write-Log -Message 'Secure channel is already healthy. No repair is required.' -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message 'Secure channel is broken. Attempting repair now.' -Level 'WARNING'

    # Attempt built-in repair
    $RepairResult = Test-ComputerSecureChannel -Repair -Verbose:$false -ErrorAction Stop

    if (-not $RepairResult) {
        Write-Log -Message 'Secure channel repair command completed, but the result was unsuccessful.' -Level 'ERROR'
        exit 1
    }

    Write-Log -Message 'Secure channel repair command completed successfully.' -Level 'SUCCESS'

    # Verify again after repair
    $SecureChannelHealthyAfterRepair = Test-ComputerSecureChannel -ErrorAction Stop

    if (-not $SecureChannelHealthyAfterRepair) {
        Write-Log -Message 'Repair was attempted, but the secure channel is still unhealthy.' -Level 'ERROR'
        exit 1
    }

    Write-Log -Message 'Secure channel is healthy after repair.' -Level 'SUCCESS'

    # Optional restart
    if ($ForceRebootAfterRepair) {
        Write-Log -Message 'A reboot was requested. Scheduling restart in 5 minutes.'
        shutdown.exe /r /t 300 /c "Secure channel repaired by Intune remediation" | Out-Null
    }

    exit 0
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------
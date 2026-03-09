<#
.SYNOPSIS
    Remediates WinRM by enabling and configuring PowerShell Remoting.

.DESCRIPTION
    This remediation script makes sure the WinRM service exists, starts it if needed,
    enables PowerShell Remoting, sets the service startup type to Automatic,
    and verifies the final WinRM configuration.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System

.EXAMPLE
    .\EnableWinRM--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'EnableWinRM--Remediate.ps1'
$ScriptBaseName = 'EnableWinRM--Remediate'
$SolutionName   = 'Enable WinRM'

# WinRM service name
$ServiceName = 'WinRM'

# Prefer Windows PowerShell for classic remoting configuration
$WindowsPowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

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
Write-Log -Message "Service name: $ServiceName"
Write-Log -Message "Log file: $LogFile"

try {
    # WinRM changes require elevation
    if (-not (Test-IsAdministrator)) {
        Write-Log -Message 'Administrative privileges are required to enable WinRM.' -Level 'ERROR'
        exit 1
    }

    # Make sure the WinRM service exists
    $WinRMService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $WinRMService) {
        Write-Log -Message 'WinRM service was not found.' -Level 'ERROR'
        exit 1
    }

    # Start the service if needed
    if ($WinRMService.Status -ne 'Running') {
        Write-Log -Message 'WinRM service is not running. Starting service...'
        Start-Service -Name $ServiceName -ErrorAction Stop
        Write-Log -Message 'WinRM service started successfully.' -Level 'SUCCESS'
    }
    else {
        Write-Log -Message 'WinRM service is already running.' -Level 'SUCCESS'
    }

    # Enable PowerShell Remoting
    Write-Log -Message 'Enabling PowerShell Remoting...'

    if (Test-Path -Path $WindowsPowerShellPath) {
        $RemotingCommand = @"
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
"@

        & $WindowsPowerShellPath -NoProfile -ExecutionPolicy Bypass -Command $RemotingCommand

        if ($LASTEXITCODE -ne 0) {
            throw 'Windows PowerShell failed to enable PowerShell Remoting.'
        }
    }
    else {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
    }

    Write-Log -Message 'PowerShell Remoting enabled successfully.' -Level 'SUCCESS'

    # Make sure the service starts automatically
    Set-Service -Name $ServiceName -StartupType Automatic -ErrorAction Stop
    Write-Log -Message 'WinRM service startup type set to Automatic.' -Level 'SUCCESS'

    # Final verification
    Write-Log -Message 'Verifying WinRM configuration...'
    $null = Test-WSMan -ErrorAction Stop
    Write-Log -Message 'WinRM configuration verified successfully.' -Level 'SUCCESS'

    Write-Log -Message 'WinRM remediation completed successfully.' -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "WinRM remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------
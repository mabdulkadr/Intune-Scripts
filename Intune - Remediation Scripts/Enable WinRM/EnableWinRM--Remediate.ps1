<#
.SYNOPSIS
    Remediate WinRM by enabling and configuring PowerShell Remoting.

.DESCRIPTION
    This remediation script ensures that the WinRM service exists, starts it if
    needed, enables PowerShell Remoting, sets the service startup type to
    Automatic, and verifies the final WinRM configuration.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\EnableWinRM--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'EnableWinRM--Remediate.ps1'
$ScriptBaseName = 'EnableWinRM--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# WinRM service name used throughout the remediation workflow.
$ServiceName = 'WinRM'

# Prefer Windows PowerShell for WinRM configuration so classic remoting settings are applied reliably.
$WindowsPowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Enable WinRM"
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
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
Write-Log -Level "INFO" -Message "=== Remediation START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Service name: {0}" -f $ServiceName)

try {
    # Ensure the script is running with administrative rights before changing service or remoting settings.
    $IsAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $IsAdministrator) {
        Write-Log -Level "FAIL" -Message "Administrative privileges are required to enable WinRM."
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
        exit 1
    }

    # Check whether the WinRM service exists before attempting configuration.
    $WinRMService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $WinRMService) {
        Write-Log -Level "FAIL" -Message "WinRM service was not found. Ensure WinRM is installed."
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
        exit 1
    }

    # Start the WinRM service if it is not already running.
    if ($WinRMService.Status -ne 'Running') {
        Write-Log -Level "INFO" -Message "WinRM service is not running. Starting the service."
        Start-Service -Name $ServiceName -ErrorAction Stop
        Write-Log -Level "OK" -Message "WinRM service started successfully."
    }
    else {
        Write-Log -Level "OK" -Message "WinRM service is already running."
    }

    # Enable PowerShell Remoting and bypass the public-network profile restriction when needed.
    Write-Log -Level "INFO" -Message "Enabling PowerShell Remoting with SkipNetworkProfileCheck."
    if (Test-Path -Path $WindowsPowerShellPath) {
        $RemotingCommand = "try { Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop; exit 0 } catch { Write-Error $_.Exception.Message; exit 1 }"
        & $WindowsPowerShellPath -NoProfile -ExecutionPolicy Bypass -Command $RemotingCommand

        if ($LASTEXITCODE -ne 0) {
            throw "Windows PowerShell failed to enable PSRemoting."
        }
    }
    else {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
    }
    Write-Log -Level "OK" -Message "PowerShell Remoting enabled successfully."

    # Ensure the service starts automatically after reboot.
    Write-Log -Level "INFO" -Message "Setting WinRM service startup type to Automatic."
    Set-Service -Name $ServiceName -StartupType Automatic -ErrorAction Stop
    Write-Log -Level "OK" -Message "WinRM service startup type set to Automatic."

    # Run a final verification so failures are surfaced immediately.
    Write-Log -Level "INFO" -Message "Verifying WinRM configuration."
    winrm quickconfig -quiet | Out-Null
    Write-Log -Level "OK" -Message "WinRM configuration verified successfully."

    Write-Log -Level "OK" -Message "WinRM remediation completed successfully."
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
    exit 0
}
catch {
    Write-Log -Level "FAIL" -Message ("WinRM remediation failed: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================

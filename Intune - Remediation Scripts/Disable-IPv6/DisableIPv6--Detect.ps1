<#
.SYNOPSIS
    Detect whether IPv6 is disabled on all network adapters.

.DESCRIPTION
    This detection script checks the `ms_tcpip6` binding state across all
    network adapters.

    If IPv6 is disabled on every adapter, the device is treated as compliant.
    If IPv6 remains enabled on one or more adapters, remediation should run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DisableIPv6--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DisableIPv6--Detect.ps1'
$ScriptBaseName = 'DisableIPv6--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Network binding component used to evaluate IPv6 state.
$BindingComponentId = 'ms_tcpip6'
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Disable-IPv6"
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
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Write-Log -Level "INFO" -Message "=== Detection START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Binding component: {0}" -f $BindingComponentId)

try {
    # Retrieve IPv6 binding state for all adapters.
    $AllBindings = @(Get-NetAdapterBinding -ComponentID $BindingComponentId -ErrorAction Stop)

    if (-not $AllBindings) {
        Write-Log -Level "FAIL" -Message ("No network adapter bindings were returned for component '{0}'." -f $BindingComponentId)
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    $DisabledBindings = @($AllBindings | Where-Object { $_.Enabled -eq $false })
    $EnabledBindings  = @($AllBindings | Where-Object { $_.Enabled -eq $true })

    Write-Log -Level "INFO" -Message ("Total adapters checked: {0}" -f $AllBindings.Count)
    Write-Log -Level "INFO" -Message ("Adapters with IPv6 disabled: {0}" -f $DisabledBindings.Count)
    Write-Log -Level "INFO" -Message ("Adapters with IPv6 enabled: {0}" -f $EnabledBindings.Count)

    if ($DisabledBindings.Count -eq $AllBindings.Count) {
        Write-Log -Level "OK" -Message "Compliant: IPv6 is disabled on all network adapters."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
        exit 0
    }
    else {
        Write-Log -Level "WARN" -Message "Non-compliant: IPv6 is enabled on one or more network adapters."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }
}
catch {
    Write-Log -Level "FAIL" -Message ("Detection error: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================

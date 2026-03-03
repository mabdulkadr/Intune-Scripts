<#
.SYNOPSIS
    Remediate IPv6 by disabling it on network adapters and in the registry.

.DESCRIPTION
    This remediation script disables the `ms_tcpip6` binding on network adapters
    where IPv6 is still enabled, then updates the registry to disable IPv6
    components system-wide.

    A restart is typically required for the full change to take effect.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DisableIPv6--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DisableIPv6--Remediate.ps1'
$ScriptBaseName = 'DisableIPv6--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# IPv6 binding and registry settings used for remediation.
$BindingComponentId   = 'ms_tcpip6'
$RegistryPath         = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
$RegistryValueName    = 'DisabledComponents'
$RegistryValueData    = 255
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Disable-IPv6"
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
Write-Log -Level "INFO" -Message ("Binding component: {0}" -f $BindingComponentId)

try {
    # Retrieve all adapter bindings, then target only those where IPv6 is still enabled.
    $AllBindings     = @(Get-NetAdapterBinding -ComponentID $BindingComponentId -ErrorAction Stop)
    $EnabledBindings = @($AllBindings | Where-Object { $_.Enabled -eq $true })

    if (-not $AllBindings) {
        Write-Log -Level "FAIL" -Message ("No network adapter bindings were returned for component '{0}'." -f $BindingComponentId)
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
        exit 1
    }

    Write-Log -Level "INFO" -Message ("Total adapters found: {0}" -f $AllBindings.Count)
    Write-Log -Level "INFO" -Message ("Adapters with IPv6 enabled: {0}" -f $EnabledBindings.Count)

    $BindingErrors = 0

    if (-not $EnabledBindings) {
        Write-Log -Level "OK" -Message "No adapters currently have IPv6 enabled. No binding changes required."
    }
    else {
        foreach ($binding in $EnabledBindings) {
            try {
                # Disable IPv6 only on adapters where it is still enabled.
                Disable-NetAdapterBinding -Name $binding.Name -ComponentID $BindingComponentId -ErrorAction Stop
                Write-Log -Level "OK" -Message ("IPv6 disabled on adapter: {0}" -f $binding.Name)
            }
            catch {
                $BindingErrors++
                Write-Log -Level "WARN" -Message ("Failed to disable IPv6 on adapter '{0}': {1}" -f $binding.Name, $_.Exception.Message)
            }
        }
    }

    try {
        # Update the registry so IPv6 components are disabled system-wide.
        New-ItemProperty -Path $RegistryPath -Name $RegistryValueName -PropertyType DWord -Value $RegistryValueData -Force -ErrorAction Stop | Out-Null
        Write-Log -Level "OK" -Message ("Registry updated: {0}\\{1}={2}" -f $RegistryPath, $RegistryValueName, $RegistryValueData)
        Write-Log -Level "INFO" -Message "A system restart is required for all changes to take full effect."
    }
    catch {
        Write-Log -Level "FAIL" -Message ("Failed to update registry: {0}" -f $_.Exception.Message)
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
        exit 1
    }

    if ($BindingErrors -gt 0) {
        Write-Log -Level "WARN" -Message ("Remediation completed with adapter-level issues. Failed adapters: {0}" -f $BindingErrors)
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
        exit 1
    }

    Write-Log -Level "OK" -Message "Remediation completed successfully. A system restart is required."
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
    exit 0
}
catch {
    Write-Log -Level "FAIL" -Message ("Remediation error: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================

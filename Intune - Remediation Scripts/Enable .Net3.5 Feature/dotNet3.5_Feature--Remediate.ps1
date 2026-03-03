<#
.SYNOPSIS
    Remediate the .NET Framework 3.5 feature by enabling it.

.DESCRIPTION
    This remediation script checks the current state of the `NetFx3` Windows
    optional feature.

    If the feature is not enabled, the script attempts to install it using
    `Add-WindowsCapability`.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\dotNet3.5_Feature--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'dotNet3.5_Feature--Remediate.ps1'
$ScriptBaseName = 'dotNet3.5_Feature--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Windows feature identifiers used for remediation.
$FeatureName     = 'NetFx3'
$CapabilityName  = 'NetFx3~~~~'
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Enable .Net3.5 Feature"
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
Write-Log -Level "INFO" -Message ("Feature name: {0}" -f $FeatureName)
Write-Log -Level "INFO" -Message ("Capability name: {0}" -f $CapabilityName)

try {
    # Read the current state of the Windows optional feature before installing.
    $Feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop

    if (-not $Feature) {
        Write-Log -Level "FAIL" -Message ("No feature data was returned for '{0}'." -f $FeatureName)
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
        exit 1
    }

    Write-Log -Level "INFO" -Message ("Current feature state: {0}" -f $Feature.State)

    if ($Feature.State -eq 'Enabled') {
        Write-Log -Level "OK" -Message ".NET Framework 3.5 is already enabled."
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
        exit 0
    }

    Write-Log -Level "INFO" -Message "Installing .NET Framework 3.5."

    # Install the Windows capability that provides .NET Framework 3.5.
    Add-WindowsCapability -Online -Name $CapabilityName -ErrorAction Stop | Out-Null

    $FeatureAfter = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    if ($FeatureAfter.State -eq 'Enabled') {
        Write-Log -Level "OK" -Message ".NET Framework 3.5 has been enabled successfully."
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
        exit 0
    }

    Write-Log -Level "WARN" -Message ("Installation completed, but feature state is '{0}'." -f $FeatureAfter.State)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
catch {
    Write-Log -Level "FAIL" -Message ("Failed to enable .NET Framework 3.5: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================

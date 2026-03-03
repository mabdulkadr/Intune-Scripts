<#
.SYNOPSIS
    Detect whether the required local network access flag is configured for Chrome and Edge.

.DESCRIPTION
    This detection script checks the `Local State` files for Google Chrome and
    Microsoft Edge, then verifies whether the required experiment flag is
    present in `browser.enabled_labs_experiments`.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DisableLocalNetworkAccess--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
[CmdletBinding()]
param()

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DisableLocalNetworkAccess--Detect.ps1'
$ScriptBaseName = 'DisableLocalNetworkAccess--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Required browser flag and target Local State files.
$RequiredFlag = "local-network-access-check@3"
$ChromeLocalState = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Local State"
$EdgeLocalState   = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Local State"
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Disable Local Network Access Checks (Chrome & Edge)"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Detection-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ==================== PATHS AND LOGGING ====================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and file exist before any write attempts.
function Initialize-Logging {
    try {
        if (-not (Test-Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path $LogFile)) {
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

# Test whether the required labs flag exists in the browser Local State file.
function Test-LnaFlag {
    param(
        [Parameter(Mandatory = $true)][string]$LocalStatePath,
        [Parameter(Mandatory = $true)][string]$BrowserName
    )

    # Ensure the Local State file exists for the target browser.
    if (-not (Test-Path -Path $LocalStatePath)) {
        Write-Log -Level "WARN" -Message ("{0}: Local State not found: {1}" -f $BrowserName, $LocalStatePath)
        return $false
    }

    # Read and parse the Local State JSON safely.
    try {
        $rawContent = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop
        $jsonData   = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Log -Level "FAIL" -Message ("{0}: Failed to read or parse Local State JSON." -f $BrowserName)
        return $false
    }

    # Validate that the expected property path exists before checking the flag.
    if ($null -eq $jsonData.browser -or $null -eq $jsonData.browser.enabled_labs_experiments) {
        Write-Log -Level "WARN" -Message ("{0}: Missing browser.enabled_labs_experiments." -f $BrowserName)
        return $false
    }

    # Check whether the required feature flag is present.
    $experiments = @($jsonData.browser.enabled_labs_experiments)
    if ($experiments -contains $RequiredFlag) {
        Write-Log -Level "OK" -Message ("{0}: Found required flag: {1}" -f $BrowserName, $RequiredFlag)
        return $true
    }

    Write-Log -Level "WARN" -Message ("{0}: Required flag not present: {1}" -f $BrowserName, $RequiredFlag)
    return $false
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Write-Log -Level "INFO" -Message "=== Detection START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Required flag: {0}" -f $RequiredFlag)

# Test Chrome and Edge separately so the compliance result is explicit.
$ChromeOK = Test-LnaFlag -LocalStatePath $ChromeLocalState -BrowserName "Chrome"
$EdgeOK   = Test-LnaFlag -LocalStatePath $EdgeLocalState -BrowserName "Edge"

if ($ChromeOK -and $EdgeOK) {
    Write-Log -Level "OK" -Message "Compliant: Chrome=True Edge=True"
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
    exit 0
}
else {
    Write-Log -Level "WARN" -Message ("Non-Compliant: Chrome={0} Edge={1}" -f $ChromeOK, $EdgeOK)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================

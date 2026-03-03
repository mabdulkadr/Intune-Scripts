<#
.SYNOPSIS
    Remediate local network access checks for Chrome and Edge.

.DESCRIPTION
    This remediation script updates the `Local State` files for Google Chrome
    and Microsoft Edge so the required local network access experiment flag is
    present.

    The script stops both browsers, updates the flag with fallback support,
    then relaunches each browser with the required runtime switch.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DisableLocalNetworkAccess--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
[CmdletBinding()]
param(
    # Force the script to try the older labs flag variant first when required.
    [switch]$ForceVariant2
)

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DisableLocalNetworkAccess--Remediate.ps1'
$ScriptBaseName = 'DisableLocalNetworkAccess--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Feature flag variants and browser launch switch used to disable the check.
$PrimaryFlag   = if ($ForceVariant2) { "local-network-access-check@2" } else { "local-network-access-check@3" }
$FallbackFlag  = if ($ForceVariant2) { "local-network-access-check@3" } else { "local-network-access-check@2" }
$LaunchArg     = "--disable-features=LocalNetworkAccessChecks,LocalNetworkAccessCheck"

# Browser Local State paths.
$ChromeLocalState = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Local State"
$EdgeLocalState   = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Local State"
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Disable Local Network Access Checks (Chrome & Edge)"
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

# Stop running browser processes so the Local State files can be edited safely.
function Stop-Processes {
    param([string[]]$Names)

    foreach ($processName in $Names) {
        Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Wait until a file can be opened for write access, which indicates it is no longer locked.
function Wait-FileUnlocked {
    param(
        [string]$Path,
        [int]$MaxWaitSeconds = 15
    )

    for ($i = 0; $i -lt $MaxWaitSeconds; $i++) {
        try {
            $fileStream = [System.IO.File]::Open($Path, 'Open', 'Write', 'None')
            $fileStream.Close()
            return $true
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    return $false
}

# Convert a hashtable to PSCustomObject so nested property access remains consistent.
function Ensure-PSCustomObject {
    param([ref]$ObjectRef)

    if ($ObjectRef.Value -is [hashtable]) {
        $ObjectRef.Value = [pscustomobject]$ObjectRef.Value
    }
}

# Update the target Local State file and verify that one of the flag variants is present.
function Set-LNAFlagDisabled {
    param(
        [string]$LocalStatePath,
        [string]$FlagTry1 = "local-network-access-check@3",
        [string]$FlagTry2 = "local-network-access-check@2"
    )

    if (-not (Test-Path -Path $LocalStatePath)) {
        Write-Log -Level "WARN" -Message ("Local State not found: {0}" -f $LocalStatePath)
        return $false
    }

    if (-not (Wait-FileUnlocked -Path $LocalStatePath -MaxWaitSeconds 15)) {
        Write-Log -Level "FAIL" -Message ("File is still locked: {0}" -f $LocalStatePath)
        return $false
    }

    $backupPath = "{0}.bak_{1}" -f $LocalStatePath, (Get-Date -Format 'yyyyMMddHHmmss')
    Copy-Item -Path $LocalStatePath -Destination $backupPath -Force -ErrorAction Stop
    Write-Log -Level "INFO" -Message ("Backup created: {0}" -f $backupPath)

    try {
        $rawContent = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop
        $jsonData   = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Log -Level "FAIL" -Message ("Failed to parse JSON. Restoring backup for: {0}" -f $LocalStatePath)
        Copy-Item -Path $backupPath -Destination $LocalStatePath -Force -ErrorAction SilentlyContinue
        return $false
    }

    # Ensure the expected object structure exists before editing nested properties.
    if (-not ($jsonData.PSObject.Properties['browser'])) {
        $jsonData | Add-Member -NotePropertyName browser -NotePropertyValue ([pscustomobject]@{})
    }
    else {
        Ensure-PSCustomObject ([ref]$jsonData.browser)
    }

    if (-not ($jsonData.browser.PSObject.Properties['enabled_labs_experiments'])) {
        $jsonData.browser | Add-Member -NotePropertyName enabled_labs_experiments -NotePropertyValue @()
    }

    if ($null -eq $jsonData.browser.enabled_labs_experiments) {
        $jsonData.browser.enabled_labs_experiments = @()
    }

    function Apply-And-Verify {
        param([string]$Flag)

        # Remove any existing local-network-access-check variants, then apply the target value.
        $jsonData.browser.enabled_labs_experiments = @(
            $jsonData.browser.enabled_labs_experiments |
            Where-Object { $_ -notmatch '^local-network-access-check@' }
        )
        $jsonData.browser.enabled_labs_experiments += $Flag

        ($jsonData | ConvertTo-Json -Depth 12) | Set-Content -Path $LocalStatePath -Encoding UTF8

        $verifyData = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return ($verifyData.browser.enabled_labs_experiments -contains $Flag)
    }

    try {
        if (Apply-And-Verify -Flag $FlagTry1) {
            Write-Log -Level "OK" -Message ("Local State updated successfully with: {0}" -f $FlagTry1)
            return $true
        }

        Write-Log -Level "WARN" -Message ("Primary flag variant was not accepted. Trying fallback: {0}" -f $FlagTry2)
        if (Apply-And-Verify -Flag $FlagTry2) {
            Write-Log -Level "OK" -Message ("Local State updated successfully with: {0}" -f $FlagTry2)
            return $true
        }

        Write-Log -Level "FAIL" -Message "Verification failed for both flag variants."
        return $false
    }
    catch {
        Write-Log -Level "FAIL" -Message ("Failed while applying browser flag: {0}" -f $_.Exception.Message)
        Copy-Item -Path $backupPath -Destination $LocalStatePath -Force -ErrorAction SilentlyContinue
        return $false
    }
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
Write-Log -Level "INFO" -Message "=== Remediation START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Flag preference: try '{0}' then '{1}'" -f $PrimaryFlag, $FallbackFlag)

# Stop both browsers first so Local State can be updated reliably.
Write-Log -Level "INFO" -Message "Stopping Chrome processes."
Stop-Processes -Names @("chrome", "chrome.exe", "GoogleCrashHandler", "GoogleCrashHandler64", "GoogleUpdate", "GoogleUpdate.exe", "GoogleChromeElevationService")
cmd /c taskkill /IM chrome.exe /F > $null 2>&1

Write-Log -Level "INFO" -Message "Stopping Edge processes."
Stop-Processes -Names @("msedge", "msedge.exe", "MicrosoftEdgeUpdate", "MicrosoftEdgeUpdate.exe", "MicrosoftEdgeElevationService")
cmd /c taskkill /IM msedge.exe /F > $null 2>&1
Start-Sleep -Seconds 1

# Apply the required labs flag to both browser profiles.
Write-Log -Level "INFO" -Message ("Editing Chrome Local State: {0}" -f $ChromeLocalState)
$ChromeOK = Set-LNAFlagDisabled -LocalStatePath $ChromeLocalState -FlagTry1 $PrimaryFlag -FlagTry2 $FallbackFlag

Write-Log -Level "INFO" -Message ("Editing Edge Local State: {0}" -f $EdgeLocalState)
$EdgeOK = Set-LNAFlagDisabled -LocalStatePath $EdgeLocalState -FlagTry1 $PrimaryFlag -FlagTry2 $FallbackFlag

# Resolve browser executable paths using environment variables instead of fixed C:\ paths.
$ProgramFilesPaths = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }

$ChromeCandidates = @()
foreach ($programFilesPath in $ProgramFilesPaths) {
    $ChromeCandidates += Join-Path $programFilesPath "Google\Chrome\Application\chrome.exe"
}
$ChromeCandidates += Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"
$ChromeExe = $ChromeCandidates | Where-Object { Test-Path -Path $_ } | Select-Object -First 1

$EdgeCandidates = @()
foreach ($programFilesPath in $ProgramFilesPaths) {
    $EdgeCandidates += Join-Path $programFilesPath "Microsoft\Edge\Application\msedge.exe"
}
$EdgeCandidates += Join-Path $env:LOCALAPPDATA "Microsoft\Edge\Application\msedge.exe"
$EdgeExe = $EdgeCandidates | Where-Object { Test-Path -Path $_ } | Select-Object -First 1

# Relaunch browsers with the runtime switch that disables local network access checks.
if ($ChromeExe) {
    Write-Log -Level "INFO" -Message "Relaunching Chrome with local network access checks disabled."
    & $ChromeExe $LaunchArg | Out-Null
    Write-Log -Level "OK" -Message "Chrome relaunched successfully."
}
else {
    Write-Log -Level "WARN" -Message "Chrome executable not found."
}

if ($EdgeExe) {
    Write-Log -Level "INFO" -Message "Relaunching Edge with local network access checks disabled."
    & $EdgeExe $LaunchArg | Out-Null
    Write-Log -Level "OK" -Message "Edge relaunched successfully."
}
else {
    Write-Log -Level "WARN" -Message "Edge executable not found."
}

Write-Log -Level "INFO" -Message ("Verify Chrome command line includes: {0}" -f $LaunchArg)
Write-Log -Level "INFO" -Message ("Verify Edge command line includes: {0}" -f $LaunchArg)

if ($ChromeOK -and $EdgeOK) {
    Write-Log -Level "OK" -Message "Remediation completed successfully for Chrome and Edge."
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
    exit 0
}
else {
    Write-Log -Level "WARN" -Message ("Remediation completed with issues: Chrome={0} Edge={1}" -f $ChromeOK, $EdgeOK)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================

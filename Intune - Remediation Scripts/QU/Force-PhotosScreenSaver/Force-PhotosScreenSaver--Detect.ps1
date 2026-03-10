<#
.SYNOPSIS
    Detect whether the Photos screen saver configuration is compliant.

.DESCRIPTION
    This detection script validates the user-level Photos screen saver settings
    across the standard desktop key, the policy desktop key, and the Photos
    screen saver registry settings.

    The configured screen saver path is accepted in both expanded and
    unexpanded forms.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant or detection failed

.RUN AS
    User. In Intune, run this script using the logged-on credentials.

.EXAMPLE
    .\Force-PhotosScreenSaver--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'Force-PhotosScreenSaver--Detect.ps1'
$ScriptBaseName = 'Force-PhotosScreenSaver--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Expected Photos screen saver values.
$EncryptedPIDL = @"
FAAfWA0aLPAhvlBDiLBzZ/yW7zy7AAAAtQC7r5M7pwAEAAAAAAAtAAAAMVNQU3ND
5Qq+Q61PheRp3IYzmG4RAAAACwAAAAALAAAA//8AAAAAAABJAAAAMVNQUzDxJbfv
RxoQpfECYIye66wtAAAACgAAAAAfAAAADgAAAFEAYQBzAHMAaQBtAFUALgBsAG8A
YwBhAGwAAAAAAAAALQAAADFTUFM6pL3eszeDQ5HnRJjaKZWrEQAAAAMAAAAAEwAA
AAAAAAAAAAAAAAAAAAAARADDAcVcXFFhc3NpbVUubG9jYWxcU1lTVk9MAE1pY3Jv
c29mdCBOZXR3b3JrAExvZ29uIHNlcnZlciBzaGFyZSAAAgBoADEAAAAAAD5acToQ
BFFBU1NJTX4xLkxPQwAATAAJAAQA774+WnE6PlpxOi4AAACvuAEAAAADAAAAAAAD
AACgAAAAAAAA5UUdAFEAYQBzAHMAaQBtAFUALgBsAG8AYwBhAGwAAAAcAGwAMQAA
AAAAWFyPQBAAU0NSRUVOfjEAAFQACQAEAO++WFx6QFhcj0AuAAAA2W0BAAAA+yIA
AAAAAAAAAAAAAAAAAC275wBTAGMAcgBlAGUAbgBTAGEAdgBlAHIAUABoAG8AdABv
AHMAAAAYAAAA
"@ -replace "\r?\n",""

$TimeOutSeconds  = 600
$RequirePassword = 0
$Shuffle         = 1
$Speed           = 1

# Accept both expanded and unexpanded screen saver path forms.
$ScreenSaverExe_Unexpanded = "%SystemRoot%\System32\PhotoScreensaver.scr"
$ScreenSaverExe_Expanded   = Join-Path $env:WINDIR "System32\PhotoScreensaver.scr"

#endregion ====================== CONFIGURATION ======================
#region ========================= PATHS AND LOGGING =========================
# Script-specific logging location.
$SolutionName = "Force-PhotosScreenSaver"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Detection-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== PATHS AND LOGGING ======================
#region ========================= HELPER FUNCTIONS =========================
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

function Start-LogRun {
    # Add a visual separator so each run is easier to scan in the same log file.
    if (Get-Command -Name Initialize-LogFile -ErrorAction SilentlyContinue) {
        Initialize-LogFile
    }
    elseif (Get-Command -Name Initialize-Logging -ErrorAction SilentlyContinue) {
        Initialize-Logging | Out-Null
    }
    $logTarget = $null
    foreach ($name in @('LogFile', 'LogFilePath')) {
        $var = Get-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue
        if ($var -and -not [string]::IsNullOrWhiteSpace([string]$var.Value)) {
            $logTarget = [string]$var.Value
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($logTarget)) {
        return
    }
    if (Test-Path -LiteralPath $logTarget) {
        $existingLog = Get-Item -LiteralPath $logTarget -ErrorAction SilentlyContinue
        if ($existingLog -and $existingLog.Length -gt 0) {
            Add-Content -Path $logTarget -Value '' -Encoding UTF8
        }
    }
    Add-Content -Path $logTarget -Value ('=' * 78) -Encoding UTF8
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

# Safely read a registry value and return null when the key or value is missing.
function Get-RegValueSafe {
    param(
        [string]$Path,
        [string]$Name
    )

    try {
        if (-not (Test-Path -Path $Path)) {
            return $null
        }

        return (Get-ItemProperty -Path $Path -ErrorAction Stop).$Name
    }
    catch {
        return $null
    }
}

# Compare two strings without enforcing case or whitespace differences.
function Equals-StringLoose {
    param(
        [string]$A,
        [string]$B
    )

    if ($null -eq $A -and $null -eq $B) {
        return $true
    }
    if ($null -eq $A -or $null -eq $B) {
        return $false
    }

    return ($A.Trim().ToLowerInvariant() -eq $B.Trim().ToLowerInvariant())
}

# Validate the screen saver path in either accepted format.
function Is-ScreenSaverExeCompliant {
    param([string]$Current)

    if ([string]::IsNullOrWhiteSpace($Current)) {
        return $false
    }

    $currentValue = $Current.Trim().ToLowerInvariant()
    $unexpanded   = $ScreenSaverExe_Unexpanded.Trim().ToLowerInvariant()
    $expanded     = $ScreenSaverExe_Expanded.Trim().ToLowerInvariant()

    return ($currentValue -eq $unexpanded -or $currentValue -eq $expanded)
}
#endregion ====================== HELPER FUNCTIONS ======================
#region ========================= FIRST DETECTION BLOCK =========================
Write-Log -Level "INFO" -Message "=== Detection START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)

try {
    $DesktopKey = "HKCU:\Control Panel\Desktop"
    $PolicyKey  = "HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
    $PhotosKey  = "HKCU:\Software\Microsoft\Windows Photo Viewer\Slideshow\Screensaver"

    $Issues = New-Object System.Collections.Generic.List[string]

    # Validate the standard user desktop screen saver settings.
    $CurrentValue = Get-RegValueSafe -Path $DesktopKey -Name "ScreenSaveActive"
    if (-not (Equals-StringLoose -A $CurrentValue -B "1")) {
        $Issues.Add("HKCU Desktop ScreenSaveActive != 1 (Current: $CurrentValue)")
    }

    $CurrentValue = Get-RegValueSafe -Path $DesktopKey -Name "ScreenSaveTimeOut"
    if (-not (Equals-StringLoose -A $CurrentValue -B ([string]$TimeOutSeconds))) {
        $Issues.Add("HKCU Desktop ScreenSaveTimeOut != $TimeOutSeconds (Current: $CurrentValue)")
    }

    $CurrentValue = Get-RegValueSafe -Path $DesktopKey -Name "SCRNSAVE.EXE"
    if (-not (Is-ScreenSaverExeCompliant -Current $CurrentValue)) {
        $Issues.Add("HKCU Desktop SCRNSAVE.EXE not compliant (Current: $CurrentValue)")
    }

    $CurrentValue = Get-RegValueSafe -Path $DesktopKey -Name "ScreenSaverIsSecure"
    if (-not (Equals-StringLoose -A $CurrentValue -B ([string]$RequirePassword))) {
        $Issues.Add("HKCU Desktop ScreenSaverIsSecure != $RequirePassword (Current: $CurrentValue)")
    }

    # Validate the policy-enforced desktop screen saver settings.
    $CurrentValue = Get-RegValueSafe -Path $PolicyKey -Name "ScreenSaveActive"
    if (-not (Equals-StringLoose -A $CurrentValue -B "1")) {
        $Issues.Add("HKCU Policy ScreenSaveActive != 1 (Current: $CurrentValue)")
    }

    $CurrentValue = Get-RegValueSafe -Path $PolicyKey -Name "ScreenSaveTimeOut"
    if (-not (Equals-StringLoose -A $CurrentValue -B ([string]$TimeOutSeconds))) {
        $Issues.Add("HKCU Policy ScreenSaveTimeOut != $TimeOutSeconds (Current: $CurrentValue)")
    }

    $CurrentValue = Get-RegValueSafe -Path $PolicyKey -Name "SCRNSAVE.EXE"
    if (-not (Is-ScreenSaverExeCompliant -Current $CurrentValue)) {
        $Issues.Add("HKCU Policy SCRNSAVE.EXE not compliant (Current: $CurrentValue)")
    }

    $CurrentValue = Get-RegValueSafe -Path $PolicyKey -Name "ScreenSaverIsSecure"
    if (-not (Equals-StringLoose -A $CurrentValue -B ([string]$RequirePassword))) {
        $Issues.Add("HKCU Policy ScreenSaverIsSecure != $RequirePassword (Current: $CurrentValue)")
    }

    # Validate the Photos screen saver-specific settings.
    $CurrentValue = Get-RegValueSafe -Path $PhotosKey -Name "EncryptedPIDL"
    if (-not (Equals-StringLoose -A $CurrentValue -B $EncryptedPIDL)) {
        $CurrentLength = if ($null -ne $CurrentValue) { ([string]$CurrentValue).Length } else { 0 }
        $Issues.Add("Photos EncryptedPIDL mismatch (Current length: $CurrentLength)")
    }

    $CurrentValue = Get-RegValueSafe -Path $PhotosKey -Name "Shuffle"
    if ([int]$CurrentValue -ne [int]$Shuffle) {
        $Issues.Add("Photos Shuffle != $Shuffle (Current: $CurrentValue)")
    }

    $CurrentValue = Get-RegValueSafe -Path $PhotosKey -Name "Speed"
    if ([int]$CurrentValue -ne [int]$Speed) {
        $Issues.Add("Photos Speed != $Speed (Current: $CurrentValue)")
    }

    if ($Issues.Count -gt 0) {
        Write-Log -Level "WARN" -Message ("Not compliant. Issue count: {0}" -f $Issues.Count)
        Write-Output "Not Compliant"
        foreach ($Issue in $Issues) {
            Write-Log -Level "WARN" -Message $Issue
            Write-Output $Issue
        }
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    Write-Log -Level "OK" -Message "Compliant."
    Write-Output "Compliant"
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
    exit 0
}
catch {
    Write-Log -Level "FAIL" -Message ("Detection error: {0}" -f $_.Exception.Message)
    Write-Output ("Not Compliant (Detection error): {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}

#endregion ====================== FIRST DETECTION BLOCK ======================

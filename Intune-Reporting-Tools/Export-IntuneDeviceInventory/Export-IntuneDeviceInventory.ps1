<#
.TITLE
    Export-IntuneDeviceInventory - Comprehensive Device Inventory Export

.SYNOPSIS
    Exports a comprehensive Intune device inventory with hardware, OS, compliance, and enrollment details.

.DESCRIPTION
    Queries Microsoft Graph to build a complete device inventory combining Intune managed devices and Entra ID records with hardware, OS, compliance, encryption, storage, primary user, and enrollment details for asset management and lifecycle planning.

        Scope & safety:
        - Read-only Graph queries; never modifies devices or groups.
        Degradation behavior:
        - Missing Entra enrichment fields render as '-' ; empty groups exit gracefully.
        Output contract:
        - CSV export; console summary; exit 0 = success, 1 = failure.

.TAGS
    Reporting,Inventory,Intune,EntraID,Graph

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All, Device.Read.All, Directory.Read.All, Group.Read.All, GroupMember.Read.All, User.Read.All, DeviceManagementApps.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.1

.CHANGELOG
    1.0.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Export-IntuneDeviceInventory.ps1
    Exports inventory for all managed devices.

.EXAMPLE
    .\\Export-IntuneDeviceInventory.ps1 -OSFilter "Windows" -ExportPath "C:\\temp\\windows_inventory.csv"
    Exports Windows devices only to a specific CSV.

.EXAMPLE
    .\\Export-IntuneDeviceInventory.ps1 -GroupName "SG-Intune-Pilot" -IncludeDetectedApps
    Exports devices in a group with detected app counts.

.NOTES
    - Requires Microsoft.Graph.Authentication module.
        - Read-only; no modifications.
        - Logs: C:\ProgramData\Export-IntuneDeviceInventory\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OSFilter,

    [Parameter()]
    [string]$GroupName,

    [Parameter()]
    [switch]$IncludeDetectedApps,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'Export-IntuneDeviceInventory'
$ScriptMode   = 'run'

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the Intune log folder/file and reports readiness.
function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}

# ============================================================================
# REPORT OUTPUT ANCHORING (Law 12)
# Anchors relative output paths beside the script using fallback chain.
# ============================================================================

$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

# Resolve relative ExportPath/OutputPath beside the script (Law 12).
if ($PSBoundParameters.ContainsKey('ExportPath') -and $ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = Join-Path $scriptDirectory $ExportPath
}
if ($PSBoundParameters.ContainsKey('OutputPath') -and $OutputPath -and -not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptDirectory $OutputPath
}


# ============================================================================
# MAIN ENTRY LOGGING INITIALIZATION
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started: Export-IntuneDeviceInventory" -Level 'INFO'


#region --- Graph connection & inventory build ---

# Connect to Microsoft Graph (interactive, read-only scopes declared in header).
try {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes @(
            'DeviceManagementManagedDevices.Read.All',
            'Device.Read.All',
            'Directory.Read.All',
            'Group.Read.All',
            'GroupMember.Read.All',
            'User.Read.All',
            'DeviceManagementApps.Read.All'
        ) -NoWelcome -ErrorAction Stop | Out-Null
    }
    Write-Log -Message "Connected to Microsoft Graph." -Level 'SUCCESS'
}
catch {
    Finish-Script -ExitCode 1 -Message "Graph connection failed: $($_.Exception.Message)" -Level 'ERROR'
}

# Resolve GroupName -> groupId and member deviceIds (if -GroupName supplied).
$groupId       = $null
$memberDeviceIds = $null
if ($GroupName) {
    try {
        $grp = Get-MgGroup -Filter "displayName eq '$GroupName'" -All -ErrorAction Stop | Select-Object -First 1
        if (-not $grp) {
            Finish-Script -ExitCode 1 -Message "Group '$GroupName' not found." -Level 'ERROR'
        }
        $groupId = $grp.Id
        $memberDeviceIds = (Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop |
                            Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.device' }).Id
        Write-Log -Message "Group '$GroupName' resolved. Member devices: $($memberDeviceIds.Count)." -Level 'INFO'
    }
    catch {
        Finish-Script -ExitCode 1 -Message "Group resolution failed: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# Collect managed devices from Intune.
try {
    $mgmtDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
    Write-Log -Message "Intune managed devices returned: $($mgmtDevices.Count)." -Level 'INFO'
}
catch {
    Finish-Script -ExitCode 1 -Message "Get-MgDeviceManagementManagedDevice failed: $($_.Exception.Message)" -Level 'ERROR'
}

# Apply group filter (if any).
if ($memberDeviceIds) {
    $mgmtDevices = $mgmtDevices | Where-Object { $memberDeviceIds -contains $_.Id }
    Write-Log -Message "After group filter: $($mgmtDevices.Count) devices." -Level 'INFO'
}

# Apply OS filter (if any). Intune reports operatingSystem field.
if ($OSFilter) {
    $mgmtDevices = $mgmtDevices | Where-Object { $_.OperatingSystem -eq $OSFilter }
    Write-Log -Message "After OS filter ($OSFilter): $($mgmtDevices.Count) devices." -Level 'INFO'
}

# Enrich with Entra ID device record (joinType, trustType, encryption) + primary user.
$inventory = foreach ($d in $mgmtDevices) {
    $entra = $null
    try { $entra = Get-MgDevice -DeviceId $d.Id -ErrorAction SilentlyContinue } catch { Write-Log -Message "Entra enrichment skipped for $($d.Id): $($_.Exception.Message)" -Level 'DEBUG' }

    $totalGB = 0; $freeGB = 0; $usedPct = '-'
    if ($d.TotalStorageSpaceInBytes) {
        $totalGB = [math]::Round($d.TotalStorageSpaceInBytes / 1GB, 1)
    }
    if ($d.FreeStorageSpaceInBytes -and $totalGB -gt 0) {
        $freeGB = [math]::Round($d.FreeStorageSpaceInBytes / 1GB, 1)
        $usedPct = [math]::Round((1 - ($d.FreeStorageSpaceInBytes / $d.TotalStorageSpaceInBytes)) * 100, 1)
    }

    $primaryUser = '-'
    if ($d.UserId) {
        try {
            $u = Get-MgUser -UserId $d.UserId -ErrorAction SilentlyContinue
            if ($u) { $primaryUser = $u.UserPrincipalName }
        } catch { Write-Log -Message "Primary user lookup skipped for $($d.Id): $($_.Exception.Message)" -Level 'DEBUG' }
    }

    [pscustomobject]@{
        DeviceName         = $d.DeviceName
        OperatingSystem    = $d.OperatingSystem
        OSVersion          = $d.OsVersion
        Manufacturer       = $d.Manufacturer
        Model              = $d.Model
        SerialNumber       = $d.SerialNumber
        ComplianceState    = $d.ComplianceState
        Ownership          = $d.OwnerType
        ManagementAgent    = $d.ManagementAgent
        JoinType           = if ($entra) { $entra.TrustType } else { '-' }
        IsEncrypted        = $entra.IsManaged -and $entra.IsCompliant
        LastCheckIn        = $d.LastCheckInDateTime
        EnrolledDateTime   = $d.EnrolledDateTime
        PrimaryUser        = $primaryUser
        TotalStorageGB     = $totalGB
        FreeStorageGB      = $freeGB
        StorageUsedPct     = $usedPct
        DeviceId           = $d.Id
    }
}

# Optional: count detected apps per device.
if ($IncludeDetectedApps -and $inventory) {
    Write-Log -Message "Counting detected apps per device..." -Level 'INFO'
    foreach ($row in $inventory) {
        try {
            $cnt = (Get-MgDeviceManagementManagedDeviceDetectedApp -ManagedDeviceId $row.DeviceId -All -ErrorAction SilentlyContinue).Count
            $row | Add-Member -NotePropertyName DetectedAppCount -NotePropertyValue $cnt -Force
        } catch {
            $row | Add-Member -NotePropertyName DetectedAppCount -NotePropertyValue 0 -Force
        }
    }
}

if (-not $inventory -or $inventory.Count -eq 0) {
    Finish-Script -ExitCode 0 -Message "No devices matched the supplied filters. Nothing to export." -Level 'WARNING'
}

Write-Log -Message "Inventory built: $($inventory.Count) devices." -Level 'SUCCESS'

#endregion


#region --- Summaries & Export ---

# Compliance breakdown
Write-Log -Message "--- Compliance State ---" -Level 'WARNING'
$compBrkdown = $inventory | Group-Object ComplianceState | Sort-Object Count -Descending
foreach ($cs in $compBrkdown) {
    $compColor = switch ($cs.Name) {
        'compliant'     { 'Green' }
        'noncompliant'  { 'Red' }
        'inGracePeriod' { 'Yellow' }
        default         { 'Gray' }
    }
    Write-Log -Message "$($cs.Name) : $($cs.Count)" -Level 'INFO'
}
# separator removed - handled by Write-Log banner

# Ownership breakdown
Write-Log -Message "--- Ownership ---" -Level 'WARNING'
$ownBrkdown = $inventory | Group-Object Ownership | Sort-Object Count -Descending
foreach ($ow in $ownBrkdown) {
    Write-Log -Message "$($ow.Name) : $($ow.Count)" -Level 'INFO'
}
# separator removed - handled by Write-Log banner

# Encryption status
$encryptedCount = ($inventory | Where-Object { $_.IsEncrypted -eq $true }).Count
$notEncryptedCount = ($inventory | Where-Object { $_.IsEncrypted -eq $false }).Count
$unknownEncCount = $inventory.Count - $encryptedCount - $notEncryptedCount
Write-Log -Message "--- Encryption ---" -Level 'WARNING'
Write-Log -Message "Encrypted     : $encryptedCount" -Level 'SUCCESS'
Write-Log -Message "Not Encrypted : $notEncryptedCount" -Level 'INFO'
Write-Log -Message "Unknown       : $unknownEncCount" -Level 'DEBUG'
# separator removed - handled by Write-Log banner

# Join type breakdown
Write-Log -Message "--- Join Type ---" -Level 'WARNING'
$joinBrkdown = $inventory | Group-Object JoinType | Sort-Object Count -Descending
foreach ($jt in $joinBrkdown) {
    Write-Log -Message "$($jt.Name) : $($jt.Count)" -Level 'INFO'
}
# separator removed - handled by Write-Log banner

# Management agent breakdown
Write-Log -Message "--- Management Agent ---" -Level 'WARNING'
$agentBrkdown = $inventory | Group-Object ManagementAgent | Sort-Object Count -Descending
foreach ($ag in $agentBrkdown) {
    Write-Log -Message "$($ag.Name) : $($ag.Count)" -Level 'INFO'
}
# separator removed - handled by Write-Log banner

# Manufacturer breakdown (top 10)
Write-Log -Message "--- Top Manufacturers ---" -Level 'WARNING'
$mfgBrkdown = $inventory | Group-Object Manufacturer | Sort-Object Count -Descending | Select-Object -First 10
foreach ($mf in $mfgBrkdown) {
    Write-Log -Message "$($mf.Name) : $($mf.Count)" -Level 'INFO'
}
# separator removed - handled by Write-Log banner

# Model breakdown (top 10)
Write-Log -Message "--- Top Models ---" -Level 'WARNING'
$modelBrkdown = $inventory | Group-Object Model | Sort-Object Count -Descending | Select-Object -First 10
foreach ($md in $modelBrkdown) {
    Write-Log -Message "$($md.Name) : $($md.Count)" -Level 'INFO'
}
# separator removed - handled by Write-Log banner

# Storage warnings
$lowStorageDevices = $inventory | Where-Object { $_.StorageUsedPct -ne '-' -and [double]$_.StorageUsedPct -ge 90 }
if ($lowStorageDevices.Count -gt 0) {
    Write-Log -Message "=== LOW STORAGE WARNING (>90% used) ===" -Level \'INFO\'
    # separator removed - handled by Write-Log banner
    foreach ($ls in ($lowStorageDevices | Sort-Object { [double]$_.StorageUsedPct } -Descending | Select-Object -First 15)) {
        Write-Log -Message "$($ls.DeviceName)" -Level 'INFO'
        Write-Log -Message "| $($ls.StorageUsedPct)% used" -Level 'ERROR'
        Write-Log -Message "| $($ls.FreeStorageGB) GB free of $($ls.TotalStorageGB) GB" -Level 'DEBUG'
    }
    if ($lowStorageDevices.Count -gt 15) {
        Write-Log -Message "... and $($lowStorageDevices.Count - 15) more (see CSV export)" -Level 'DEBUG'
    }
    # separator removed - handled by Write-Log banner
}

# OS version distribution (Windows)
$windowsDevices = $inventory | Where-Object { $_.OperatingSystem -eq 'Windows' }
if ($windowsDevices.Count -gt 0) {
    Write-Log -Message "=== WINDOWS VERSION DISTRIBUTION ===" -Level \'INFO\'
    # separator removed - handled by Write-Log banner
    $winVerBrkdown = $windowsDevices | Group-Object OSVersion | Sort-Object Name -Descending
    foreach ($wv in $winVerBrkdown) {
        $pct = [math]::Round(($wv.Count / $windowsDevices.Count) * 100, 1)
        Write-Log -Message "$($wv.Name) : $($wv.Count) ($pct%)" -Level 'INFO'
    }
    # separator removed - handled by Write-Log banner
}

# Export (Law 12: default report path beside the script in Reports\).
if ($ExportPath) {
    if (-not [System.IO.Path]::IsPathRooted($ExportPath)) {
        $ExportPath = Join-Path $scriptDirectory $ExportPath
    }
    $reportDir = Split-Path -Parent $ExportPath
    if (-not (Test-Path -LiteralPath $reportDir)) {
        $null = [System.IO.Directory]::CreateDirectory($reportDir)
    }
    $inventory | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
    Write-Log -Message "Exported $($inventory.Count) devices to: $ExportPath" -Level 'INFO'
} else {
    $scopeSafe = if ($GroupName) { $GroupName -replace '[^\w\-]','_' }
                 elseif ($OSFilter) { $OSFilter }
                 else { 'AllDevices' }
    $reportsDir = Join-Path $scriptDirectory 'Reports'
    if (-not (Test-Path -LiteralPath $reportsDir)) {
        $null = [System.IO.Directory]::CreateDirectory($reportsDir)
    }
    $defaultPath = Join-Path $reportsDir ("{0}_DeviceInventory_{1}.csv" -f $scopeSafe, (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $inventory | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
    Write-Log -Message "Auto-exported $($inventory.Count) devices to: $defaultPath" -Level 'INFO'
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
#endregion



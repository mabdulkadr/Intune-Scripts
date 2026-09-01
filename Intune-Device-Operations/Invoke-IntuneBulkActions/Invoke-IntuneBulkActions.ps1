<#
.TITLE
    Intune Bulk Device Actions

.SYNOPSIS
    Performs bulk Intune device actions: sync, restart, BitLocker key rotation, Windows Defender scan, and collect diagnostics.

.DESCRIPTION
    Executes a specified remote action against multiple Intune managed devices. Devices can be targeted by group membership, OS type, compliance state, or a CSV file of device names. Includes safety confirmations, throttling to avoid Graph API rate limits, and detailed progress/result tracking. Supported actions: Sync, Restart, BitLockerRotate, DefenderScan, DefenderSignatures, CollectDiagnostics.

.TAGS
    Devices,Bulk,Operations

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementManagedDevices.PrivilegedOperations.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    1.0.0
    - Initial Toolkit import

.LASTUPDATE
    2026-08-26

 .EXAMPLE
    .\Invoke-IntuneBulkActions.ps1 -Action Sync -GroupName "SG-Windows-Pilot"
    # Sync all devices in a group
 .EXAMPLE
    .\Invoke-IntuneBulkActions.ps1 -Action Sync -OSFilter "Windows" -StaleOnly -StaleDays 3
    # Sync Windows devices that haven't checked in for 3+ days
 .EXAMPLE
    .\Invoke-IntuneBulkActions.ps1 -Action Restart -DeviceNames "PC-001","PC-002" -Force
    # Restart specific devices without confirmation
 .EXAMPLE
    .\Invoke-IntuneBulkActions.ps1 -Action DefenderScan -NonCompliantOnly -OSFilter "Windows"
    # Trigger Defender scan on non-compliant Windows devices
 .EXAMPLE
    .\Invoke-IntuneBulkActions.ps1 -Action BitLockerRotate -CsvPath "C:\temp\devices.csv"
    # Rotate BitLocker keys for devices listed in a CSV

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\invoke-intunebulkactions\Logs
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByGroup')]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Sync','Restart','BitLockerRotate','DefenderScan','DefenderSignatures','CollectDiagnostics')]
    [string]$Action,

    [Parameter(Mandatory, ParameterSetName = 'ByGroup')]
    [string]$GroupName,

    [Parameter(Mandatory, ParameterSetName = 'ByOS')]
    [string]$OSFilter,

    [Parameter(Mandatory, ParameterSetName = 'ByName')]
    [string[]]$DeviceNames,

    [Parameter(Mandatory, ParameterSetName = 'ByCsv')]
    [string]$CsvPath,

    [Parameter()]
    [switch]$NonCompliantOnly,

    [Parameter()]
    [switch]$StaleOnly,

    [Parameter()]
    [int]$StaleDays = 7,

    [Parameter()]
    [int]$ThrottleMs = 200,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'invoke-intunebulkactions'
$ScriptMode   = 'run'

$scriptBasePath = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if ($ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = Join-Path -Path $scriptBasePath -ChildPath $ExportPath
}

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
        [Parameter(Mandatory = $true)]
        [string]$Message,
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
        [Parameter(Mandatory = $true)]
        [string]$Message,
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
# MAIN ENTRY LOGGING INITIALIZATION
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started" -Level 'INFO'



#region --- Helpers ---
function Write-Status { param([string]$Msg, [string]$Color = 'Cyan') ; Write-Log -Message "  [$((Get-Date).ToString('HH:mm:ss'))] $Msg" -Level 'INFO' }
function Write-Section { param([string]$Msg) ; Write-Log -Message "`n$('='*60)" -Level 'WARNING'; Write-Log -Message "  $Msg" -Level 'WARNING'; Write-Log -Message "$('='*60)" -Level 'WARNING' }

function Get-MgGraphAllPages {
    param([string]$Uri, [string]$Method = 'GET')
    try {
        $response = Invoke-MgGraphRequest -Uri $Uri -Method $Method -ErrorAction Stop
        $results = @()
        if ($null -ne $response.value) { $results += $response.value }
        elseif ($response) { $results += $response }
        while ($response.'@odata.nextLink') {
            $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -ErrorAction Stop
            if ($null -ne $response.value) { $results += $response.value }
        }
        return ,$results
    } catch [System.Exception] {
        Write-Verbose "Graph call failed for $Uri : $_"
        return @()
    }
}

function Get-ActionEndpoint {
    param([string]$ActionName, [string]$DeviceId)
    $base = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId"
    switch ($ActionName) {
        'Sync'                { return "$base/syncDevice" }
        'Restart'             { return "$base/rebootNow" }
        'BitLockerRotate'     { return "$base/rotateBitLockerKeys" }
        'DefenderScan'        { return "$base/windowsDefenderScan" }
        'DefenderSignatures'  { return "$base/windowsDefenderUpdateSignatures" }
        'CollectDiagnostics'  { return "$base/createDeviceLogCollectionRequest" }
    }
}

function Get-ActionDescription {
    param([string]$ActionName)
    switch ($ActionName) {
        'Sync'                { return 'Force device sync (check-in)' }
        'Restart'             { return 'Reboot device' }
        'BitLockerRotate'     { return 'Rotate BitLocker recovery keys' }
        'DefenderScan'        { return 'Trigger Windows Defender quick scan' }
        'DefenderSignatures'  { return 'Update Defender signature definitions' }
        'CollectDiagnostics'  { return 'Collect device diagnostic logs' }
    }
}
#endregion

#region --- Authentication ---
Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Write-Status "Connecting to Microsoft Graph..." "White"
    Connect-MgGraph -Scopes @(
        'DeviceManagementManagedDevices.ReadWrite.All',
        'DeviceManagementManagedDevices.PrivilegedOperations.All',
        'Device.Read.All',
        'Directory.Read.All',
        'Group.Read.All',
        'GroupMember.Read.All'
    ) -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
#endregion

#region --- Resolve Target Devices ---
Write-Section "RESOLVING TARGET DEVICES"

$targetDevices = @()

switch ($PSCmdlet.ParameterSetName) {
    'ByGroup' {
        Write-Status "Resolving group: $GroupName"
        $groups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$($GroupName -replace "'","''")'"
        if ($groups.Count -eq 0) {
            Write-Log -Message "  ERROR: Group '$GroupName' not found." -Level 'ERROR'
            return
        }
        $groupId = $groups[0].id
        Write-Status "Group: $($groups[0].displayName)"

        $members = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members?`$select=id,deviceId,displayName,@odata.type"
        $deviceMembers = $members | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' }

        if ($deviceMembers.Count -gt 0) {
            foreach ($dm in $deviceMembers) {
                if ($dm.deviceId) {
                    $md = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$($dm.deviceId)'&`$select=id,deviceName,userPrincipalName,operatingSystem,complianceState,lastSyncDateTime"
                    $targetDevices += $md
                }
            }
        } else {
            $userMembers = $members | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' }
            foreach ($um in $userMembers) {
                $ud = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=userId eq '$($um.id)'&`$select=id,deviceName,userPrincipalName,operatingSystem,complianceState,lastSyncDateTime"
                $targetDevices += $ud
            }
        }
    }
    'ByOS' {
        Write-Status "Fetching all $OSFilter devices..."
        $targetDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq '$OSFilter'&`$select=id,deviceName,userPrincipalName,operatingSystem,complianceState,lastSyncDateTime"
    }
    'ByName' {
        Write-Status "Looking up $($DeviceNames.Count) device(s) by name..."
        foreach ($name in $DeviceNames) {
            $md = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$name'&`$select=id,deviceName,userPrincipalName,operatingSystem,complianceState,lastSyncDateTime"
            if ($md.Count -eq 0) {
                Write-Log -Message "    WARNING: Device '$name' not found, skipping." -Level 'WARNING'
            } else {
                $targetDevices += $md
            }
        }
    }
    'ByCsv' {
        if (-not (Test-Path $CsvPath)) {
            Write-Log -Message "  ERROR: CSV file not found: $CsvPath" -Level 'ERROR'
            return
        }
        $csvData = Import-Csv -Path $CsvPath
        if (-not ($csvData | Get-Member -Name 'DeviceName' -ErrorAction SilentlyContinue)) {
            Write-Log -Message "  ERROR: CSV must contain a 'DeviceName' column." -Level 'ERROR'
            return
        }
        $deviceNameList = $csvData.DeviceName | Where-Object { $_ }
        Write-Status "CSV loaded: $($deviceNameList.Count) device names"

        foreach ($name in $deviceNameList) {
            $md = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$name'&`$select=id,deviceName,userPrincipalName,operatingSystem,complianceState,lastSyncDateTime"
            if ($md.Count -eq 0) {
                Write-Log -Message "    WARNING: Device '$name' not found, skipping." -Level 'WARNING'
            } else {
                $targetDevices += $md
            }
        }
    }
}

# Apply additional filters
if ($NonCompliantOnly) {
    $before = $targetDevices.Count
    $targetDevices = $targetDevices | Where-Object { $_.complianceState -ne 'compliant' }
    Write-Status "Filtered to non-compliant: $before -> $($targetDevices.Count) devices"
}

if ($StaleOnly) {
    $staleThreshold = (Get-Date).AddDays(-$StaleDays)
    $before = $targetDevices.Count
    $targetDevices = $targetDevices | Where-Object {
        $_.lastSyncDateTime -and [datetime]$_.lastSyncDateTime -lt $staleThreshold
    }
    Write-Status "Filtered to stale (>$StaleDays days): $before -> $($targetDevices.Count) devices"
}

# Deduplicate
$targetDevices = $targetDevices | Sort-Object -Property id -Unique

if ($targetDevices.Count -eq 0) {
    Write-Log -Message "  No devices found matching the specified criteria." -Level 'WARNING'
    return
}

Write-Status "$($targetDevices.Count) device(s) targeted for action" "Green"
#endregion

#region --- Confirmation ---
Write-Section "ACTION CONFIRMATION"
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Action      : $Action - $(Get-ActionDescription $Action)" -Level 'INFO'
Write-Log -Message "  Target count: $($targetDevices.Count) device(s)" -Level 'INFO'
Write-Log -Message "  Throttle    : ${ThrottleMs}ms between calls" -Level 'DEBUG'
Write-Log -Message "" -Level 'INFO'

# Show sample of target devices
$showCount = [math]::Min($targetDevices.Count, 10)
Write-Log -Message "  Target devices (showing $showCount of $($targetDevices.Count)):" -Level 'INFO'
foreach ($d in ($targetDevices | Select-Object -First 10)) {
    $daysSince = if ($d.lastSyncDateTime) { [math]::Round(((Get-Date) - [datetime]$d.lastSyncDateTime).TotalDays, 1) } else { '?' }
    Write-Log -Message "    $($d.deviceName) | $($d.operatingSystem) | $($d.complianceState) | Sync: ${daysSince}d ago" -Level 'DEBUG'
}
if ($targetDevices.Count -gt 10) {
    Write-Log -Message "    ... and $($targetDevices.Count - 10) more" -Level 'DEBUG'
}
Write-Log -Message "" -Level 'INFO'

# Warning for destructive actions
if ($Action -in @('Restart','BitLockerRotate')) {
    Write-Log -Message "  WARNING: '$Action' is a potentially disruptive action!" -Level 'WARNING'
    Write-Log -Message "  - Restart will reboot devices immediately" -Level 'WARNING'
    Write-Log -Message "  - BitLockerRotate will invalidate current recovery keys" -Level 'WARNING'
    Write-Log -Message "" -Level 'INFO'
}

if (-not $Force) {
    $confirm = Read-Host "  Proceed with '$Action' on $($targetDevices.Count) device(s)? (Y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Log -Message "  Action cancelled by user." -Level 'WARNING'
        return
    }
}
#endregion

#region --- Execute Actions ---
Write-Section "EXECUTING: $Action"

$results = [System.Collections.Generic.List[PSCustomObject]]::new()
$successCount = 0
$failCount = 0
$deviceIndex = 0

foreach ($device in $targetDevices) {
    $deviceIndex++
    Write-Progress -Activity "Executing $Action" -Status "$deviceIndex of $($targetDevices.Count) - $($device.deviceName)" -PercentComplete (($deviceIndex / $targetDevices.Count) * 100)

    $endpoint = Get-ActionEndpoint -ActionName $Action -DeviceId $device.id
    $status = 'Success'
    $errorMsg = '-'

    try {
        # Build the request body based on action
        $body = switch ($Action) {
            'DefenderScan' { @{ quickScan = $true } | ConvertTo-Json }
            'CollectDiagnostics' { @{ templateType = @{ '@odata.type' = '#microsoft.graph.deviceLogCollectionRequest' } } | ConvertTo-Json }
            default { $null }
        }

        if ($body) {
            Invoke-MgGraphRequest -Uri $endpoint -Method POST -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
        } else {
            Invoke-MgGraphRequest -Uri $endpoint -Method POST -ErrorAction Stop | Out-Null
        }

        $successCount++
        Write-Log -Message "    [OK] $($device.deviceName)" -Level 'SUCCESS'
    } catch [System.Exception] {
        $failCount++
        $status = 'Failed'
        $errorMsg = $_.Exception.Message -replace "`n",' ' -replace "`r",''
        # Truncate long error messages
        if ($errorMsg.Length -gt 200) { $errorMsg = $errorMsg.Substring(0,197) + '...' }
        Write-Log -Message "    [FAIL] $($device.deviceName) : $errorMsg" -Level 'ERROR'
    }

    $results.Add([PSCustomObject]@{
        DeviceName        = $device.deviceName
        UserPrincipalName = $device.userPrincipalName
        OperatingSystem   = $device.operatingSystem
        ComplianceState   = $device.complianceState
        Action            = $Action
        Status            = $status
        Error             = $errorMsg
        Timestamp         = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        DeviceId          = $device.id
    })

    # Throttle to avoid rate limiting
    if ($deviceIndex -lt $targetDevices.Count) {
        Start-Sleep -Milliseconds $ThrottleMs
    }
}

Write-Progress -Activity "Executing $Action" -Completed
#endregion

#region --- Results Summary ---
Write-Section "ACTION RESULTS: $Action"
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Total devices  : $($targetDevices.Count)" -Level 'INFO'
Write-Log -Message "  Successful     : $successCount" -Level 'SUCCESS'
Write-Log -Message "  Failed         : $failCount" -Level 'INFO'

if ($failCount -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Failed devices:" -Level 'WARNING'
    $failedDevices = $results | Where-Object { $_.Status -eq 'Failed' }
    foreach ($fd in ($failedDevices | Select-Object -First 20)) {
        Write-Log -Message "    $($fd.DeviceName) : $($fd.Error)" -Level 'ERROR'
    }
    if ($failedDevices.Count -gt 20) {
        Write-Log -Message "    ... and $($failedDevices.Count - 20) more (see CSV export)" -Level 'DEBUG'
    }
}

# Export
if ($results.Count -gt 0) {
    if ($ExportPath) {
        $results | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
        Write-Status "Results exported to: $ExportPath" "Green"
    } else {
        $defaultPath = Join-Path $env:TEMP "BulkAction_$($Action)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $results | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
        Write-Status "Results auto-exported to: $defaultPath" "Green"
    }
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
#endregion



<#
.TITLE
    Scope Tag Usage Report

.SYNOPSIS
    Reports scope tag usage across all Intune policies and RBAC assignments.

.DESCRIPTION
    Lists all scope tags and shows which policies, apps, and configurations reference each tag. Identifies unused tags and untagged policies. Important for multi-team Intune environments with delegated administration.

.TAGS
    ScopeTag,RBAC,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementRBAC.Read.All

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
    .\Get-IntuneScopeTagReport.ps1

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intunescopetagreport\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param([Parameter()][string]$ExportPath)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intunescopetagreport'
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



function Write-Status { param([string]$Msg,[string]$Color='Cyan'); Write-Log -Message "  [$((Get-Date).ToString('HH:mm:ss'))] $Msg" -Level 'INFO' }
function Write-Section { param([string]$Msg); Write-Log -Message "`n$('='*60)" -Level 'WARNING'; Write-Log -Message "  $Msg" -Level 'WARNING'; Write-Log -Message "$('='*60)" -Level 'WARNING' }

function Get-MgGraphAllPages {
    param([string]$Uri,[string]$Method='GET')
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
    } catch [System.Exception] { Write-Verbose "Graph call failed: $_"; return @() }
}

Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All','DeviceManagementRBAC.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

# Get all scope tags
Write-Section "SCOPE TAGS"
$scopeTags = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/roleScopeTags"
Write-Status "Found $($scopeTags.Count) scope tags" "Green"

$tagMap = @{}
foreach ($st in $scopeTags) { $tagMap[$st.id] = $st.displayName }

# Get RBAC role assignments
Write-Status "Fetching RBAC role assignments..."
$roleAssignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/roleAssignments"

# Get policies and count scope tag usage
Write-Status "Scanning policies for scope tag references..."
$tagUsage = @{}
foreach ($st in $scopeTags) { $tagUsage[$st.id] = [System.Collections.Generic.List[string]]::new() }

# Device configurations
$configs = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$select=id,displayName,roleScopeTagIds"
foreach ($c in $configs) {
    if ($c.roleScopeTagIds) {
        foreach ($tagId in $c.roleScopeTagIds) {
            if ($tagUsage.ContainsKey($tagId.ToString())) { $tagUsage[$tagId.ToString()].Add("[Config] $($c.displayName)") }
        }
    }
}

# Settings Catalog
$catalogs = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$select=id,name,roleScopeTagIds"
foreach ($c in $catalogs) {
    if ($c.roleScopeTagIds) {
        foreach ($tagId in $c.roleScopeTagIds) {
            $pName = if ($c.name) { $c.name } else { $c.id }
            if ($tagUsage.ContainsKey($tagId.ToString())) { $tagUsage[$tagId.ToString()].Add("[Catalog] $pName") }
        }
    }
}

# Compliance policies
$compPolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?`$select=id,displayName,roleScopeTagIds"
foreach ($c in $compPolicies) {
    if ($c.roleScopeTagIds) {
        foreach ($tagId in $c.roleScopeTagIds) {
            if ($tagUsage.ContainsKey($tagId.ToString())) { $tagUsage[$tagId.ToString()].Add("[Compliance] $($c.displayName)") }
        }
    }
}

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Log -Message "" -Level 'INFO'
foreach ($st in ($scopeTags | Sort-Object displayName)) {
    $usageCount = $tagUsage[$st.id].Count
    $roleCount = ($roleAssignments | Where-Object { $_.roleScopeTagIds -contains $st.id }).Count

    $color = if ($usageCount -eq 0 -and $st.id -ne '0') { 'DarkGray' } else { 'White' }
    $isDefault = $st.id -eq '0'

    Write-Log -Message "  $($st.displayName)$(if($isDefault){' (Default)'})" -Level 'INFO'
    Write-Log -Message "    Tag ID: $($st.id) | Policies using: $usageCount | Role assignments: $roleCount" -Level 'DEBUG'

    if ($usageCount -gt 0 -and $usageCount -le 10) {
        foreach ($usage in $tagUsage[$st.id]) {
            Write-Log -Message "      $usage" -Level 'INFO'
        }
    } elseif ($usageCount -gt 10) {
        foreach ($usage in ($tagUsage[$st.id] | Select-Object -First 5)) {
            Write-Log -Message "      $usage" -Level 'INFO'
        }
        Write-Log -Message "      ... and $($usageCount - 5) more" -Level 'DEBUG'
    }

    $report.Add([PSCustomObject]@{
        TagName=$st.displayName; TagId=$st.id; IsDefault=$isDefault
        Description=$st.description; PolicyCount=$usageCount; RoleAssignmentCount=$roleCount
        Policies=($tagUsage[$st.id] -join '; ')
    })
}

Write-Section "SCOPE TAG SUMMARY"
$unusedTags = $report | Where-Object { $_.PolicyCount -eq 0 -and -not $_.IsDefault }
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Total scope tags    : $($scopeTags.Count)" -Level 'INFO'
Write-Log -Message "  Tags in use         : $(($report | Where-Object { $_.PolicyCount -gt 0 }).Count)" -Level 'SUCCESS'
Write-Log -Message "  Unused tags         : $($unusedTags.Count)" -Level 'INFO'
Write-Log -Message "  Role assignments    : $($roleAssignments.Count)" -Level 'INFO'

if ($unusedTags.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Unused Scope Tags ---" -Level 'WARNING'
    foreach ($ut in $unusedTags) {
        Write-Log -Message "    $($ut.TagName) (ID: $($ut.TagId))" -Level 'DEBUG'
    }
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "ScopeTagReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'



<#
.SYNOPSIS
    Remediates low disk space on the Windows system drive.

.DESCRIPTION
    This remediation script runs Disk Cleanup, clears selected temporary paths,
    and empties folders named "temp" on the Windows system drive.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User (depending on Intune assignment)

.EXAMPLE
    .\CleanUpDisk--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'CleanUpDisk--Remediate.ps1'
$ScriptBaseName = 'CleanUpDisk--Remediate'
$SolutionName   = 'CleanUpDisk'

# Detect the Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

$SystemDriveLetter = $SystemDrive.TrimEnd(':')
$SystemDriveLabel  = "$SystemDriveLetter :"

# Cleanup categories for Disk Cleanup
$CleanupTypeSelection = @(
    'Temporary Sync Files',
    'Downloaded Program Files',
    'Memory Dump Files',
    'Recycle Bin'
)

# Extra paths to clear after CleanMgr
$PathsToClean = @(
    (Join-Path $SystemDrive 'Temp')
)

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write message to console and log file
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$TimeStamp] [$Level] $Message"

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

# Convert bytes to readable text
function Format-Size {
    param([Int64]$Bytes)

    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }

    return "$Bytes B"
}

# Get drive usage details
function Get-DriveInfo {
    param(
        [string]$DriveLetter = $SystemDriveLetter
    )

    try {
        $Drive = Get-PSDrive -Name $DriveLetter -ErrorAction Stop

        [pscustomobject]@{
            Free  = [Int64]$Drive.Free
            Used  = [Int64]$Drive.Used
            Total = [Int64]$Drive.Free + [Int64]$Drive.Used
        }
    }
    catch {
        $null
    }
}

# Estimate folder size before cleanup
function Get-DirectorySize {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $Files = Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction Stop |
                 Where-Object { -not $_.PSIsContainer }

        ($Files | Measure-Object -Property Length -Sum).Sum
    }
    catch {
        $null
    }
}

# Clear folder contents but keep the main folder
function Clear-FolderContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

        return $true
    }
    catch {
        return $false
    }
}

#endregion ---------- Functions ----------


#region ---------- Initialization ----------

# Prepare logging
$LogReady = Initialize-Logging

# Store cleanup summary
$Summary = @()
$TotalCleanedBytes = 0

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Log file: $LogFile"

$DriveBefore = Get-DriveInfo

if ($DriveBefore) {
    Write-Log -Message "$SystemDriveLabel Free before: $(Format-Size $DriveBefore.Free) | Used: $(Format-Size $DriveBefore.Used) | Total: $(Format-Size $DriveBefore.Total)"
}

#endregion ---------- Initialization ----------


#region ---------- Stage 1 - Run Disk Cleanup ----------

Write-Log -Message 'Stage 1: Configuring Disk Cleanup handlers'

foreach ($KeyName in $CleanupTypeSelection) {
    try {
        New-ItemProperty `
            -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$KeyName" `
            -Name 'StateFlags0001' `
            -Value 1 `
            -PropertyType DWord `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Log -Message "Enabled cleanup option: $KeyName" -Level 'SUCCESS'
    }
    catch {
        Write-Log -Message "Failed to enable cleanup option: $KeyName" -Level 'WARNING'
    }
}

try {
    Start-Process -FilePath 'CleanMgr.exe' -ArgumentList '/sagerun:1' -NoNewWindow -Wait -ErrorAction Stop
    Write-Log -Message 'Disk Cleanup completed successfully.' -Level 'SUCCESS'
}
catch {
    Write-Log -Message 'Disk Cleanup failed to run.' -Level 'WARNING'
}

#endregion ---------- Stage 1 - Run Disk Cleanup ----------


#region ---------- Stage 2 - Clear Selected Paths ----------

Write-Log -Message 'Stage 2: Clearing selected paths'

foreach ($Path in $PathsToClean) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Log -Message "Path not found, skipping: $Path"
        continue
    }

    $SizeBefore = Get-DirectorySize -Path $Path

    if (Clear-FolderContent -Path $Path) {
        Write-Log -Message "Cleared: $Path" -Level 'SUCCESS'

        if ($null -ne $SizeBefore) {
            $Summary += [pscustomobject]@{
                Path  = $Path
                Bytes = $SizeBefore
            }

            $TotalCleanedBytes += $SizeBefore
        }
    }
    else {
        Write-Log -Message "Failed to clear: $Path" -Level 'WARNING'
    }
}

#endregion ---------- Stage 2 - Clear Selected Paths ----------


#region ---------- Stage 3 - Clear Temp Folders ----------

Write-Log -Message "Stage 3: Searching for folders named 'temp' on $SystemDriveLabel"

try {
    $TempFolders = Get-ChildItem -LiteralPath "$SystemDriveLabel\" -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -ieq 'temp' }

    foreach ($Folder in $TempFolders) {
        $SizeBefore = Get-DirectorySize -Path $Folder.FullName

        if (Clear-FolderContent -Path $Folder.FullName) {
            Write-Log -Message "Cleared temp folder: $($Folder.FullName)" -Level 'SUCCESS'

            if ($null -ne $SizeBefore) {
                $Summary += [pscustomobject]@{
                    Path  = $Folder.FullName
                    Bytes = $SizeBefore
                }

                $TotalCleanedBytes += $SizeBefore
            }
        }
        else {
            Write-Log -Message "Failed to clear temp folder: $($Folder.FullName)" -Level 'WARNING'
        }
    }
}
catch {
    Write-Log -Message "Error while searching temp folders: $($_.Exception.Message)" -Level 'WARNING'
}

#endregion ---------- Stage 3 - Clear Temp Folders ----------


#region ---------- Final Summary ----------

Write-Log -Message 'Cleanup summary'

foreach ($Item in $Summary) {
    Write-Log -Message "Path: $($Item.Path) | Cleared: $(Format-Size $Item.Bytes)"
}

Write-Log -Message "Total cleared (estimated): $(Format-Size $TotalCleanedBytes)"

$DriveAfter = Get-DriveInfo

if ($DriveAfter) {
    Write-Log -Message "$SystemDriveLabel Free after: $(Format-Size $DriveAfter.Free) | Used: $(Format-Size $DriveAfter.Used) | Total: $(Format-Size $DriveAfter.Total)"
}

Write-Log -Message 'Remediation completed successfully.' -Level 'SUCCESS'
exit 0

#endregion ---------- Final Summary ----------
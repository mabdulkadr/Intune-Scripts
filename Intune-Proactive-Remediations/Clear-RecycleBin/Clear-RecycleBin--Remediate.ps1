<#
.SYNOPSIS
    Clears the Windows Recycle Bin.

.DESCRIPTION
    This remediation script empties the Windows Recycle Bin by running
    `Clear-RecycleBin -Force`.

    It is designed to be paired with a detection script that intentionally
    returns non-compliant so the cleanup operation can be executed whenever the
    remediation package runs.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Clear-RecycleBin--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.3
#>

#region ---------- Configuration ----------

$ScriptName   = 'Clear-RecycleBin--Remediate.ps1'
$SolutionName = 'Clear-RecycleBin'
$ScriptMode   = 'Remediation'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Clear-RecycleBin--Remediate.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

# Create the log folder and file when needed.
function Initialize-Log {
    try {
        if (-not (Test-Path -Path $LogRoot)) {
            New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }

        return $true
    }
    catch {
        Write-Host "Logging initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Write the same banner to the console and the log file.
function Write-Banner {
    $title = "{0} | {1}" -f $SolutionName, $ScriptMode
    $lines = @('', $BannerLine, $title, $BannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        }
        else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            try {
                Add-Content -Path $LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                $script:LogReady = $false
                Write-Host ("Log writing disabled: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
            }
        }
    }
}

# Write one formatted log line.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            $script:LogReady = $false
            Write-Host ("Log writing disabled: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
        }
    }
}

# Write the final message and exit with the right code.
function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
    exit $ExitCode
}

# Return each filesystem recycle bin root that currently exists.
function Get-RecycleBinRoots {
    $roots = foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        $recycleBinRoot = Join-Path $drive.Root '$Recycle.Bin'

        try {
            if (Test-Path -LiteralPath $recycleBinRoot -ErrorAction Stop) {
                $recycleBinRoot
            }
        }
        catch {
            Write-Log -Message ("Skipping inaccessible recycle bin path: {0}" -f $recycleBinRoot) -Level 'WARNING'
        }
    }

    return $roots | Sort-Object -Unique
}

# Return real recycle bin contents, excluding the top-level SID folders themselves.
function Get-RecycleBinContent {
    $content = foreach ($recycleBinRoot in (Get-RecycleBinRoots)) {
        foreach ($rootItem in (Get-ChildItem -LiteralPath $recycleBinRoot -Force -ErrorAction SilentlyContinue)) {
            if ($rootItem.PSIsContainer) {
                Get-ChildItem -LiteralPath $rootItem.FullName -Force -Recurse -ErrorAction SilentlyContinue
            }
            else {
                $rootItem
            }
        }
    }

    return @($content)
}

# Clear recycle bin items directly when the built-in cmdlet is unreliable.
function Clear-RecycleBinFallback {
    foreach ($recycleBinRoot in (Get-RecycleBinRoots)) {
        foreach ($rootItem in (Get-ChildItem -LiteralPath $recycleBinRoot -Force -ErrorAction SilentlyContinue)) {
            if ($rootItem.PSIsContainer) {
                foreach ($childItem in (Get-ChildItem -LiteralPath $rootItem.FullName -Force -ErrorAction SilentlyContinue)) {
                    Remove-Item -LiteralPath $childItem.FullName -Force -Recurse -ErrorAction Stop
                }
            }
            else {
                Remove-Item -LiteralPath $rootItem.FullName -Force -Recurse -ErrorAction Stop
            }
        }
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

$recycleBinContent = Get-RecycleBinContent

if (-not $recycleBinContent) {
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Recycle Bin is already empty.'
}

Write-Log -Message ("Detected {0} recycle bin item(s) before cleanup." -f $recycleBinContent.Count)
Write-Log -Message 'Running command: Clear-RecycleBin -Force'

$clearRecycleBinFailed = $false

try {
    $commandOutput = Clear-RecycleBin -Force -ErrorAction Stop 2>&1

    if ($commandOutput) {
        foreach ($line in ($commandOutput | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })) {
            Write-Log -Message $line
        }
    }
}
catch {
    $clearRecycleBinFailed = $true
    Write-Log -Message ("Clear-RecycleBin failed, switching to fallback cleanup: {0}" -f $_.Exception.Message) -Level 'WARNING'
}

$remainingContent = Get-RecycleBinContent

if (-not $remainingContent) {
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Recycle Bin was cleared successfully.'
}

Write-Log -Message ("{0} recycle bin item(s) remain after Clear-RecycleBin." -f $remainingContent.Count) -Level 'WARNING'
Write-Log -Message 'Running fallback cleanup by deleting recycle bin contents directly.'

try {
    Clear-RecycleBinFallback
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Fallback recycle bin cleanup failed: {0}" -f $_.Exception.Message)
}

$remainingContent = Get-RecycleBinContent

if (-not $remainingContent) {
    $successMessage = if ($clearRecycleBinFailed) {
        'Recycle Bin was cleared successfully using fallback cleanup.'
    }
    else {
        'Recycle Bin was cleared successfully.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message $successMessage
}

Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Recycle Bin cleanup did not complete. {0} item(s) remain." -f $remainingContent.Count)

#endregion ---------- Main ----------

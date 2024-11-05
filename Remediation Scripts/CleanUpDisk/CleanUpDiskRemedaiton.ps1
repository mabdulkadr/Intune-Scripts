<#
.SYNOPSIS
    Configures and runs the Windows Disk Cleanup tool with predefined cleanup categories.

.DESCRIPTION
    This script sets specific cleanup options in the Windows Registry to enable automatic cleanup of selected file types. It then executes the Disk Cleanup utility (`CleanMgr.exe`) with the specified settings to free up disk space.

.POSSIBLE CLEANUP CATEGORIES
    'Active Setup Temp Folders', 'BranchCache', 'Content Indexer Cleaner', 'Device Driver Packages', 
    'Downloaded Program Files', 'GameNewsFiles', 'GameStatisticsFiles', 'GameUpdateFiles',
    'Internet Cache Files', 'Memory Dump Files', 'Offline Pages Files', 'Old ChkDsk Files', 
    'Previous Installations', 'Recycle Bin', 'Service Pack Cleanup', 'Setup Log Files', 
    'System error memory dump files', 'System error minidump files', 'Temporary Files', 
    'Temporary Setup Files', 'Temporary Sync Files', 'Thumbnail Cache', 'Update Cleanup', 
    'Upgrade Discarded Files', 'User file versions', 'Windows Defender',
    'Windows Error Reporting Archive Files', 'Windows Error Reporting Queue Files', 
    'Windows Error Reporting System Archive Files', 'Windows Error Reporting System Queue Files', 
    'Windows ESD installation files', 'Windows Upgrade Log Files'

.HINT
    This is a community script. There is no guarantee for this. Please check thoroughly before running.

.RUN AS
    Administrator

.EXAMPLE
    .\CleanUpDiskRemedaiton.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04

#> 

# Define the cleanup categories to enable
$cleanupTypeSelection = @(
    'Temporary Sync Files',
    'Downloaded Program Files',
    'Memory Dump Files',
    'Recycle Bin'
)

# Enable the selected cleanup categories in the registry
foreach ($keyName in $cleanupTypeSelection) {
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$keyName"
    $propertyName = 'StateFlags0001'
    $propertyValue = 1
    $propertyType = 'DWord'

    try {
        # Create or update the registry property
        New-ItemProperty -Path $registryPath -Name $propertyName -Value $propertyValue -PropertyType $propertyType -Force -ErrorAction Stop | Out-Null
        Write-Verbose "Enabled cleanup for: $keyName"
    }
    catch {
        Write-Warning "Failed to set registry for: $keyName. Error: $_"
    }
}

# Execute Disk Cleanup with the predefined settings
try {
    Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1' -NoNewWindow -Wait -ErrorAction Stop
    Write-Output "Disk Cleanup executed successfully."
}
catch {
    Write-Error "Failed to execute Disk Cleanup. Error: $_"
}

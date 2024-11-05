<#
.SYNOPSIS
    Monitors the free disk space on the C: drive and determines if cleanup is necessary.

.DESCRIPTION
    This script evaluates the free space on the C: drive. If the available free space is greater than the specified storage threshold, the script exits with code 0 indicating sufficient space. Otherwise, it exits with code 1 indicating low disk space.

.HINT
    This is a community script. There is no guarantee for this. Please check thoroughly before running.

.RUN AS
    Administrator

.EXAMPLE
    .\CleanUpDiskDetection.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04

#> 

# Define the storage threshold in gigabytes
$storageThreshold = 15

# Retrieve the free space on the C: drive in bytes
$utilization = (Get-PSDrive -Name C).Free

# Compare the free space with the threshold
if (($storageThreshold * 1GB) -lt $utilization) {
    exit 0  # Sufficient free space
}
else {
    exit 1  # Low disk space
}

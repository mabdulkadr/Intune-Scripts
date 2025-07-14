<#
.SYNOPSIS
    Downloads and installs CMTrace.exe to the C:\Windows\System32 directory.

.DESCRIPTION
    This script retrieves the CMTrace executable from a specified repository URL and saves it in the System32 folder. 
    CMTrace is a log viewer tool used for troubleshooting in System Center Configuration Manager (SCCM) environments.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

# Define the repository URL for CMTrace
$ownRepoUri = "https://github.com/mabdulkadr/Intune/blob/main/Remediation%20Scripts/CMTrace%20Install/cmtrace.exe"
                

# Define the output path for CMTrace
$destinationPath = "C:\Windows\System32\CMTrace.exe"

# Function to log messages
function Log-Message {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] [$Type] $Message"
}

# Start installation process
Log-Message "Starting CMTrace installation process."

try {
    # Check if the destination folder exists
    if (-not (Test-Path -Path "C:\Windows\System32")) {
        Log-Message "System32 directory does not exist. Aborting." "ERROR"
        throw "The System32 directory does not exist."
    }

    # Download CMTrace.exe
    Log-Message "Downloading CMTrace.exe from $ownRepoUri."
    Invoke-WebRequest -Uri $ownRepoUri -OutFile $destinationPath -ErrorAction Stop
    Log-Message "CMTrace.exe downloaded successfully to $destinationPath."

    # Verify the file exists
    if (Test-Path -Path $destinationPath) {
        Log-Message "CMTrace.exe installation completed successfully."
    } else {
        Log-Message "CMTrace.exe installation failed. File not found in $destinationPath." "ERROR"
    }
} catch {
    Log-Message "An error occurred: $_" "ERROR"
} finally {
    Log-Message "CMTrace installation process completed."
}

# End of script

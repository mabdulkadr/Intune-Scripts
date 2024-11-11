
# CleanUpDisk

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

`CleanUpDisk` is a set of PowerShell scripts designed to monitor disk space and perform automated cleanup of unnecessary files on Windows systems. These scripts help maintain optimal disk utilization by checking available space and executing disk cleanup tasks when needed.

## Features

- **Disk Space Monitoring**: Checks the free space on the C: drive against a predefined threshold.
- **Automated Cleanup**: Configures and runs Windows Disk Cleanup (`CleanMgr.exe`) with selected cleanup categories.
- **Customizable Cleanup Categories**: Allows selection of specific file types to clean, ensuring only desired data is removed.
- **Administrative Execution**: Requires administrator privileges to modify system settings and perform cleanup operations.
- **64-bit Context**: Designed to run on 64-bit Windows systems.

## Prerequisites

- **Operating System**: Windows 7 or later (64-bit)
- **PowerShell**: Version 5.0 or higher
- **Administrator Privileges**: Required to execute scripts successfully


## Usage

The `CleanUpDisk` project includes two primary scripts:

### 1. Detection Script:

**Filename**: `CleanUpDiskDetection.ps1`

**Purpose**: Checks the free space on the C: drive against a specified threshold.

**Parameters**:
- `storageThreshold`: The minimum required free space in gigabytes (default is 15 GB).

**Execution**:

Run the script with administrator privileges:

```powershell
.\CleanUpDiskDetection.ps1
```

**Exit Codes**:
- `0`: Sufficient free space available.
- `1`: Free space below the threshold.


### 2. Remediation Script

**Filename**: `CleanUpDiskRemedaiton.ps1`

**Purpose**: Configures and runs the Windows Disk Cleanup utility with predefined cleanup categories.

**Parameters**:
- `cleanupTypeSelection`: Array of cleanup categories to enable (e.g., 'Temporary Sync Files', 'Recycle Bin').

**Execution**:

Run the script with administrator privileges:

```powershell
.\CleanUpDiskRemedaiton.ps1
```

**How It Works**:
1. **Registry Configuration**: The script sets specific cleanup categories in the Windows Registry to enable automatic deletion of selected file types.
2. **Execute Disk Cleanup**: It then runs `CleanMgr.exe` with the `/sagerun:1` argument to perform the cleanup based on the configured settings.

## How It Works

1. **Monitoring Disk Space**:
   - The `CleanUpDiskDetection.ps1` script retrieves the free space on the C: drive.
   - It compares the free space against the `storageThreshold`.
   - Based on the comparison, it exits with a code indicating whether cleanup is necessary.

2. **Performing Cleanup**:
   - The `CleanUpDiskRemedaiton.ps1` script sets registry keys to enable specific cleanup categories.
   - It then runs the Disk Cleanup utility to remove unnecessary files, freeing up disk space.



## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.

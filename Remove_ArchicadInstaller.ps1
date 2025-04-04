<#
.SYNOPSIS
Remotely removes the Archicad installer file from multiple Windows machines.

.DESCRIPTION
- Verifies each PC is online via ping
- Connects remotely using PowerShell Remoting and domain credentials
- Checks for the existence of the installer file
- Removes the installer if found
- Logs the result for each machine locally and centrally

.PARAMETER $computers
A list of machine names to process.

.PARAMETER $installerPath
Path to the installer file on each remote PC (e.g. C:\ProgramData\ArchicadInstaller.exe).

.NOTES
Author: TechAsen  
Version: 1.0  
Created: April 2025  
Tested on: Windows 10, 11, Server 2019, Server 2022  
Requirements: PowerShell Remoting (WinRM), domain credentials

.EXAMPLE
Run as administrator with network access to the target machines:

.\Remove_ArchicadInstaller.ps1

#>

﻿# Allow script execution temporarily for this session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Define list of computers to target
$computers = @("PC-001", "PC-002", "PC-N...")

# Path of the installer to remove from each computer
$installerPath = "C:\ProgramData\ArchicadInstaller.exe"

# Local path on each machine where log files will be stored
$remoteLogPath = "C:\ProgramData\ArchicadLogs"

# Path for central (admin) log file on the executing machine
$centralLog = "$env:TEMP\Remove_Installer_MasterLog.txt"

# Start logging the script's actions
Start-Transcript -Path $centralLog -Append

# Prompt for credentials once, used for all remote commands
$creds = Get-Credential

# Loop through all target computers
foreach ($pc in $computers) {

    # Check if the machine is reachable (ping)
    if (Test-Connection -ComputerName $pc -Count 1 -Quiet) {
        Write-Host "$pc is online. Proceeding with removal..."

        Invoke-Command -ComputerName $pc -ScriptBlock {
            param($installerPath, $logPath, $pcName)

            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $logFile = "$logPath\$pcName-remove-$timestamp.log"

            # Ensure log folder exists
            if (!(Test-Path $logPath)) {
                New-Item -ItemType Directory -Path $logPath -Force
            }

            try {
                # Check if the file exists before trying to remove
                if (Test-Path $installerPath) {
                    Remove-Item -Path $installerPath -Force
                    Add-Content -Path $logFile -Value "[$timestamp] File removed: $installerPath"
                } else {
                    Add-Content -Path $logFile -Value "[$timestamp] File not found: $installerPath"
                }
            } catch {
                Add-Content -Path $logFile -Value "[$timestamp] Error removing file: $_"
            }

        } -ArgumentList $installerPath, $remoteLogPath, $pc -Credential $creds

    } else {
        # If machine is unreachable, skip and log in console
        Write-Host "$pc is offline or unreachable. Skipping..."
    }
}

# Stop the central log
Stop-Transcript

<#
.SYNOPSIS
Remotely deploys Archicad hotfix to multiple Windows PCs via PowerShell Remoting.

.DESCRIPTION
- Checks if each target PC is online (ping)
- Copies the Archicad installer to the remote machine
- Executes a silent unattended installation using Graphisoft-supported switches
- Logs installation results on each machine
- Centralizes log output on the admin machine

.PARAMETER $computers
A hardcoded list of computer names (can be adapted for CSV or external source)

.PARAMETER $sourceInstaller
UNC path to the shared Archicad installer on a server

.PARAMETER $localInstaller
Path where the installer will be copied to on the remote PC

.PARAMETER $params
Parameters passed to the installer (silent/unattended mode)

.NOTES
Author: TechAsen  
Version: 1.0  
Created: April 2025  
Tested on: Windows 10, 11, Server 2019л, Server 2022  
Requires: PowerShell Remoting (WinRM enabled) and domain credentials

.EXAMPLE
Run directly from an elevated PowerShell session:

.\Update_Archicad_Remotly.ps1

#>

# Temporarily bypass the execution policy for this process to allow script execution
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Define the list of target computers (can be expanded with more IPs or hostnames)
$computers = @("PC-001", "PC-002")

# Define the path to the installer on the network share
$sourceInstaller = "\\DC\Scripts\Update\Archicad-27.3.2-Hotfix-INT.exe"

# Define the local path on the remote machine where the installer will be copied
$installerPath = "C:\ProgramData\ArchicadInstaller.exe"

# Define the path where installation logs will be saved
$logPath = "C:\ProgramData\ArchicadLogs"

# Define the installer parameters for unattended installation
$params = "--mode unattended --unattendedmodeui none"

# Generate a timestamp to uniquely name the log file
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Prompt the user to enter credentials to run remote commands
$creds = Get-Credential

# Loop through each computer
foreach ($pc in $computers) {
    Write-Host "`n[$pc] Checking connectivity..." -ForegroundColor Cyan

    # Test if the computer is reachable (ping)
    if (Test-Connection -ComputerName $pc -Count 1 -Quiet) {
        Write-Host "[$pc] Online. Proceeding..." -ForegroundColor Green

        try {
            # Define full path to where the installer will be copied on the remote machine
            $destPath = "\\$pc\C$\ProgramData\ArchicadInstaller.exe"

            # Copy the installer to the remote machine
            Copy-Item -Path $sourceInstaller -Destination $destPath -Force -ErrorAction Stop
            Write-Host "[$pc] Installer copied." -ForegroundColor Yellow
        } catch {
            # Handle any errors during the copy process
            Write-Host "[$pc] ERROR copying installer: $_" -ForegroundColor Red
            continue
        }

        # Prepare the full command to execute the installer silently and log the output
        $cmd = "cmd.exe /c `"$installerPath $params > $logPath\Install-$timestamp.log 2>&1`""

        # Run the command remotely using the provided credentials
        Invoke-Command -ComputerName $pc -Credential $creds -ScriptBlock {
            param($cmdLine, $logDir)

            # Ensure the log directory exists
            if (!(Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force
            }

            # Execute the installation command
            Invoke-Expression $cmdLine

        } -ArgumentList $cmd, $logPath

        Write-Host "[$pc] Installer started via cmd.exe" -ForegroundColor DarkGreen
    }
    else {
        # If the computer is offline, skip to the next one
        Write-Host "[$pc] Offline. Skipping." -ForegroundColor DarkGray
    }
}

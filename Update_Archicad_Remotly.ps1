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
Tested on: Windows 10, 11, Server 2019  
Requires: PowerShell Remoting (WinRM enabled) and domain credentials

.EXAMPLE
Run directly from an elevated PowerShell session:

.\Update_Archicad_Remotly.ps1

#>

# Bypass execution policy for this session (required on some systems)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Define the list of target computers
$computers = @("PC-001", "PC-002", "PC-N...")

# Network path to the Archicad installer on shared server
$sourceInstaller = "\\dc\Scripts\Update\Archicad-27.3.2-Hotfix-INT.exe"

# Parameters for silent installation using Graphisoft's supported switches
$params = '--mode unattended --unattendedmodeui minimalWithDialogs'

# Local path where installer will be copied to on each client machine
$localInstaller = "C$\ProgramData\ArchicadInstaller.exe"

# Remote path where log files will be stored on each machine
$logPathRemote = "C$\ProgramData\ArchicadLogs"

# Path for the central master log (local, on the admin machine running this script)
$logPathCentral = "$env:TEMP\Archicad_MasterLog.txt"

# Start logging the whole process
Start-Transcript -Path $logPathCentral -Append

# Prompt once for domain admin credentials to use with remote commands
$creds = Get-Credential

# Loop through each computer in the list
foreach ($pc in $computers) {

    # Check if the computer is online (ping)
    if (Test-Connection -ComputerName $pc -Count 1 -Quiet) {
        Write-Host "$pc is online. Proceeding with installation..."

        try {
            # Build remote UNC path for installer copy
            $remotePath = "\\$pc\$localInstaller"

            Write-Host "Copying installer to $pc..."
            Copy-Item -Path $sourceInstaller -Destination $remotePath -Force -ErrorAction Stop

            Write-Host "Running installer on $pc..."

            # Invoke remote script block to install Archicad and generate logs
            Invoke-Command -ComputerName $pc -ScriptBlock {
                param($params, $logPath, $installerPath, $pcName)

                $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
                $logFile = "$logPath\$pcName-$timestamp.log"

                # Ensure the log directory exists
                if (!(Test-Path $logPath)) {
                    New-Item -ItemType Directory -Path $logPath -Force
                }

                try {
                    Add-Content -Path $logFile -Value "[$timestamp] Starting installation..."
                    $process = Start-Process -FilePath $installerPath -ArgumentList $params -Wait -PassThru
                    Add-Content -Path $logFile -Value "[$timestamp] Exit code: $($process.ExitCode)"

                    if ($process.ExitCode -eq 0) {
                        Add-Content -Path $logFile -Value "[$timestamp] Installation completed successfully."
                    } else {
                        Add-Content -Path $logFile -Value "[$timestamp] Installation exited with error."
                    }
                } catch {
                    Add-Content -Path $logFile -Value "[$timestamp] Error during installation: $_"
                }

            } -ArgumentList $params, "C:\ProgramData\ArchicadLogs", "C:\ProgramData\ArchicadInstaller.exe", $pc -Credential $creds

        } catch {
            Write-Host "[$pc] ERROR: $_"
        }

    } else {
        # Skip the machine if it's offline
        Write-Host "$pc is offline or unreachable. Skipping..."
    }
}

# End of the session log
Stop-Transcript

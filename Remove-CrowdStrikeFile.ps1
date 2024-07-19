<#
.SYNOPSIS
    Removes the faulty CrowdStrike channel file that caused the July 2024 BSOD outage.

.DESCRIPTION
    Locates the OS drive by finding the Windows System32 directory,
    navigates to the CrowdStrike driver folder, deletes all files matching
    C-00000291*, logs every action with timestamps, and restarts the machine.

    Designed to run from a bootable WinPE/USB environment where Windows
    cannot complete its normal boot process.

    If no matching files are found the script exits cleanly without restarting -
    the machine may already be remediated.

    Logs are written to: <OSDrive>\Temp\FileDeletionLog.txt

.NOTES
    Run from WinPE or Safe Mode with administrative privileges.
    No network connection required.
    No parameters required - OS drive is auto-detected.

    Author  : Soar Systems
    Version : 2.0.0
    Date    : 2024-07-19
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Auto-detect OS drive
$osDrives = Get-PSDrive -PSProvider FileSystem |
    Where-Object { Test-Path "$($_.Root)Windows\System32" }

if (-not $osDrives) {
    Write-Host "ERROR: Could not locate Windows System32 directory on any drive." -ForegroundColor Red
    exit 1
}

$osRoot  = $osDrives[0].Root
$logDir  = "${osRoot}Temp"
$logFile = "${logDir}\FileDeletionLog.txt"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "=== CrowdStrike Remediation Script starting ==="
Write-Log "OS drive detected: $osRoot"
Write-Log "All drives found: $($osDrives | ForEach-Object { $_.Root } | Join-String -Separator ', ')"

$targetPath       = "${osRoot}Windows\System32\drivers\CrowdStrike"
$matchingFilesFound = $false

Write-Log "Checking: $targetPath"

if (-not (Test-Path $targetPath)) {
    Write-Log "CrowdStrike driver directory not found. Nothing to do."
    Write-Log "=== Script complete (no action taken). ==="
    Read-Host "Press Enter to close"
    exit 0
}

$files = Get-ChildItem -Path $targetPath -Filter "C-00000291*" -ErrorAction SilentlyContinue

if (@($files).Count -eq 0) {
    Write-Log "No files matching C-00000291* found. Device may already be remediated."
    Write-Log "=== Script complete (no action taken). ==="
    Read-Host "Press Enter to close"
    exit 0
}

$matchingFilesFound = $true
Write-Log "Found $(@($files).Count) file(s) matching C-00000291*:"

foreach ($file in $files) {
    Write-Log "  Target: $($file.FullName) ($($file.Length) bytes)"
    try {
        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
        Write-Log "  Deleted: $($file.FullName)"
    } catch {
        Write-Log "  FAILED to delete: $($file.FullName) - Error: $_"
    }
}

Write-Log "File deletion complete."
Write-Log "=== Script complete. Restarting in 3 seconds... ==="

Start-Sleep -Seconds 3
Restart-Computer -Force

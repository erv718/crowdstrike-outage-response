<#
.SYNOPSIS
    Prepares a bootable remediation USB drive using Rufus.

.DESCRIPTION
    Downloads a remediation ISO, verifies SHA-256 integrity, auto-detects
    the only connected USB drive, ensures it is not the OS drive, uses Rufus
    portable to create a bootable USB, and removes the downloaded ISO afterward.

.PARAMETER IsoUrl
    URL to download the remediation ISO.
    For the CrowdStrike July 2024 remediation ISO:
    https://drive.google.com/uc?export=download&id=1Dxe5-vVjL7jHR3eoQjV9MypZd4eS-Jy1

.PARAMETER RufusPath
    Path to the Rufus portable executable (rufusp.exe).
    Download from: https://rufus.ie/downloads/
    Use the portable version: rufus-4.xp.exe

.PARAMETER ExpectedIsoHash
    SHA-256 hash of the remediation ISO for integrity verification.
    CrowdStrike July 2024 ISO hash:
    01D94B0A4610F45461233BCDF5BA959BFD2E2F94043EF5195B9533EB8670D381

.PARAMETER ExpectedRufusHash
    Optional SHA-256 hash for Rufus validation. Skipped if not provided.

.PARAMETER TempDir
    Local working directory. Defaults to C:\Temp.

.EXAMPLE
    # CrowdStrike July 19, 2024 remediation:
    .\Prepare-RemediationUsb.ps1 `
        -IsoUrl          "https://drive.google.com/uc?export=download&id=1Dxe5-vVjL7jHR3eoQjV9MypZd4eS-Jy1" `
        -ExpectedIsoHash "01D94B0A4610F45461233BCDF5BA959BFD2E2F94043EF5195B9533EB8670D381" `
        -RufusPath       "\\server\Tools\rufusp.exe"

.NOTES
    Requires Rufus portable (rufusp.exe) — https://rufus.ie/downloads/
    Must be run with administrative privileges.
    Only one USB drive should be connected when running this script.

    Author  : Soar Systems
    Version : 2.0.0
    Date    : 2024-07-19
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$IsoUrl,

    [Parameter(Mandatory)]
    [string]$RufusPath,

    [Parameter(Mandatory)]
    [string]$ExpectedIsoHash,

    [string]$ExpectedRufusHash,

    [string]$TempDir = "C:\Temp"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colour = switch ($Level) { "WARN" {"Yellow"} "ERROR" {"Red"} default {"Cyan"} }
    Write-Host "[$ts][$Level] $Message" -ForegroundColor $colour
}

function Get-FileHashString {
    param ([string]$FilePath)
    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
}

function Get-OnlyUsbDrive {
    $usbDrives = Get-CimInstance -ClassName Win32_DiskDrive |
        Where-Object { $_.InterfaceType -eq "USB" }

    if (@($usbDrives).Count -eq 0) { throw "No USB drives detected. Please connect a USB drive." }
    if (@($usbDrives).Count -gt 1) { throw "Multiple USB drives detected. Please connect only one USB drive." }

    return $usbDrives[0]
}

$isoPath       = Join-Path -Path $TempDir -ChildPath "CrowdStrike_File_Removal_Fix.iso"
$rufusLocalPath = Join-Path -Path $TempDir -ChildPath "rufusp.exe"

Write-Log "=== Remediation USB Preparation starting ==="

try {
    if (-not (Test-Path -Path $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir | Out-Null
        Write-Log "Created temp directory: $TempDir"
    }

    # Copy Rufus to temp
    if (Test-Path -Path $rufusLocalPath) {
        if ($ExpectedRufusHash) {
            $localRufusHash = Get-FileHashString -FilePath $rufusLocalPath
            if ($localRufusHash -ne $ExpectedRufusHash) {
                Write-Log "Rufus hash mismatch. Updating..." -Level WARN
                Copy-Item -Path $RufusPath -Destination $rufusLocalPath -Force
            } else {
                Write-Log "Rufus verified and up-to-date."
            }
        } else {
            Write-Log "Rufus found locally. Hash check skipped (no ExpectedRufusHash provided)."
        }
    } else {
        Write-Log "Rufus not found locally. Copying from $RufusPath ..."
        Copy-Item -Path $RufusPath -Destination $rufusLocalPath -Force
    }

    # Download ISO if needed
    $downloadIso = $false
    if (Test-Path -Path $isoPath) {
        Write-Log "ISO found locally. Verifying hash..."
        $localIsoHash = Get-FileHashString -FilePath $isoPath
        if ($localIsoHash -ne $ExpectedIsoHash) {
            Write-Log "ISO hash mismatch. Re-downloading..." -Level WARN
            $downloadIso = $true
        } else {
            Write-Log "ISO hash verified. Using cached copy."
        }
    } else {
        Write-Log "ISO not found locally. Downloading..."
        $downloadIso = $true
    }

    if ($downloadIso) {
        Write-Log "Downloading ISO from: $IsoUrl"
        Invoke-WebRequest -Uri $IsoUrl -OutFile $isoPath -UseBasicParsing

        Write-Log "Verifying downloaded ISO hash..."
        $downloadedHash = Get-FileHashString -FilePath $isoPath
        if ($downloadedHash -ne $ExpectedIsoHash) {
            throw "Downloaded ISO hash mismatch. Expected: $ExpectedIsoHash | Got: $downloadedHash"
        }
        Write-Log "ISO downloaded and verified successfully."
    }

    # Detect USB drive
    Write-Log "Detecting USB drive..."
    $usbDrive = Get-OnlyUsbDrive
    Write-Log "Found USB drive: $($usbDrive.Model) — $($usbDrive.DeviceID)"

    # Get drive letter
    $usbPartitions  = Get-CimAssociatedInstance -InputObject $usbDrive -Association Win32_DiskDriveToDiskPartition
    $usbLogicalDisks = foreach ($p in $usbPartitions) {
        Get-CimAssociatedInstance -InputObject $p -Association Win32_LogicalDiskToPartition
    }
    $usbDriveLetter = ($usbLogicalDisks | Select-Object -First 1).DeviceID

    # Safety: confirm it is not the OS drive
    $osDrive = (Get-CimInstance Win32_OperatingSystem).SystemDrive
    if ($usbDriveLetter -like "$osDrive*") {
        throw "Selected USB drive letter '$usbDriveLetter' matches the OS drive '$osDrive'. Aborting."
    }

    Write-Log "USB drive letter: $usbDriveLetter"

    # Create bootable USB
    if ($PSCmdlet.ShouldProcess($usbDriveLetter, "Create bootable USB — this will ERASE all data")) {
        Write-Log "Creating bootable USB drive at $usbDriveLetter ..."
        Start-Process -FilePath $rufusLocalPath `
            -ArgumentList "--iso=$isoPath", "--device=$usbDriveLetter", "--format" `
            -Wait
        Write-Log "USB drive setup complete."
    }

    # Cleanup
    Remove-Item $isoPath -Force -ErrorAction SilentlyContinue
    Write-Log "ISO cleaned up."
    Write-Log "=== Done. USB drive is ready for deployment. ==="

} catch {
    Write-Log "An error occurred: $_" -Level ERROR
}

Read-Host -Prompt "Press Enter to close this window"

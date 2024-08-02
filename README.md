# CrowdStrike Falcon Outage - Mass Remediation Scripts

On July 19, 2024, a faulty CrowdStrike Falcon content update caused a global Windows BSOD
outage affecting millions of endpoints. This repository contains the USB-based mass remediation
workflow used to recover impacted systems across 110+ locations when remote access and
centralized management were unavailable.

## The Problem

The defective channel file update (`C-00000291*.sys`) caused Windows to crash before login,
making every standard remote tool useless. With 110+ physical locations staffed by non-technical
employees, the only viable approach was a bootable USB that staff could run themselves with
zero IT involvement on-site.

## Scripts

| Script | Purpose |
|---|---|
| `Prepare-RemediationUsb.ps1` | Downloads remediation ISO, verifies SHA-256, auto-detects USB drive, creates bootable drive with Rufus |
| `Remove-CrowdStrikeFile.ps1` | Auto-detects OS drive, deletes `C-00000291*` files, logs all actions, restarts |

## Download

### Remediation ISO

| File | SHA-256 |
|---|---|
| [CrowdStrike_File_Removal_Fix.iso](https://drive.google.com/file/d/1Dxe5-vVjL7jHR3eoQjV9MypZd4eS-Jy1/view?usp=sharing) | `01D94B0A4610F45461233BCDF5BA959BFD2E2F94043EF5195B9533EB8670D381` |

Verify the hash after downloading:
```powershell
Get-FileHash .\CrowdStrike_File_Removal_Fix.iso -Algorithm SHA256
# Expected: 01D94B0A4610F45461233BCDF5BA959BFD2E2F94043EF5195B9533EB8670D381
```

> The ISO is a WinPE environment with `Remove-CrowdStrikeFile.ps1` embedded.
> It boots directly into the remediation script - no user interaction required.

### Rufus (required for Prepare-RemediationUsb.ps1)

Download the portable version from **[rufus.ie/downloads](https://rufus.ie/downloads/)** - use `rufusp.exe`, not the installer.

## Usage

### Step 1 - Prepare bootable USB drives (run on any working IT machine)

```powershell
.\Prepare-RemediationUsb.ps1 `
    -IsoUrl          "https://drive.google.com/uc?export=download&id=1Dxe5-vVjL7jHR3eoQjV9MypZd4eS-Jy1" `
    -ExpectedIsoHash "01D94B0A4610F45461233BCDF5BA959BFD2E2F94043EF5195B9533EB8670D381" `
    -RufusPath       "C:\Tools\rufusp.exe"
```

### Step 2 - Run on each affected machine (from the bootable USB)

No parameters needed. Insert the USB, boot from it, and the script runs automatically.
It will detect the OS drive, delete the bad file, and restart the machine.

## Requirements

| | Prepare-RemediationUsb.ps1 | Remove-CrowdStrikeFile.ps1 |
|---|---|---|
| Admin rights | Required | Required |
| Network access | Required (ISO download) | Not required |
| Rufus portable | Required - [rufus.ie/downloads](https://rufus.ie/downloads/) | Not required |
| Boot environment | Normal Windows | WinPE or Safe Mode |

## How It Was Used

1. IT burned 20+ USB drives in parallel using `Prepare-RemediationUsb.ps1` - under 1 hour
2. Drives shipped overnight to affected locations
3. On-site staff: insert USB → boot → wait for auto-restart (~5 min per machine)
4. IT confirmed each location coming back online via RMM
5. Full fleet recovered in under 8 hours

## Alternative: PXE Network Boot

If Windows Deployment Services (WDS) is already deployed in your environment,
PXE boot is a faster and more scalable alternative to physical USB drives.

PXE negotiation happens at the firmware level, before Windows attempts to load -
meaning the CrowdStrike BSOD loop would not have blocked it. Machines configured
for PXE-first boot would have pulled the WinPE image over the network and run
the remediation automatically, with no physical media required.

### Why we used USB instead

Our 110+ locations each run on isolated local networks. PXE relies on DHCP
broadcast (options 66/67), which is local-subnet only. Serving WinPE to remote
sites requires either:
- A WDS server at every location, or
- DHCP helper/relay configured on every site router pointing to a central WDS server

Neither was in place. USB could be manufactured and shipped same day. PXE could not.

### WDS setup for future incidents

If you want to be ready before the next incident, here is the minimum WDS configuration
to serve a remediation WinPE image to remote sites:

**1. Install WDS on a central Windows Server:**
```powershell
Install-WindowsFeature -Name WDS -IncludeManagementTools
wdsutil /initialize-server /remInst:"C:\RemoteInstall"
wdsutil /set-server /answerclients:all
```

**2. Add the WinPE boot image:**
```powershell
# Import your WinPE .wim file into WDS
wdsutil /add-image /imagefile:"C:\WinPE\boot.wim" /imagetype:boot
```

**3. Configure DHCP options on each site router:**

| DHCP Option | Value | Description |
|---|---|---|
| Option 66 | `<WDS server IP>` | TFTP server address |
| Option 67 | `boot\x64\wdsnbp.com` | Boot file name |

**4. Ensure machines have PXE enabled in UEFI:**
- Boot order: Network first, local disk second
- Secure Boot: May need to be configured to trust your WDS server certificate

### Testing in a VM

To simulate the CrowdStrike scenario and test the removal script without a physical USB:

```powershell
# Create a dummy bad file on any Windows VM
New-Item -Path "C:\Windows\System32\drivers\CrowdStrike" -ItemType Directory -Force
New-Item -Path "C:\Windows\System32\drivers\CrowdStrike\C-00000291-00000000-00000032.sys" -ItemType File

# Run the removal script (comment out Restart-Computer while testing)
.\Remove-CrowdStrikeFile.ps1

# Verify the log
Get-Content "C:\Temp\FileDeletionLog.txt"
```

For full USB boot testing: attach a USB drive via passthrough in VMware Workstation or
VirtualBox (with Extensions Pack), run `Prepare-RemediationUsb.ps1` inside the VM, then
boot a second test VM from the resulting USB.

## Blog Post

[The Day CrowdStrike Took Down the World - How We Responded](https://blog.soarsystems.cc)

(Update this URL with the real post slug once published on Ghost.)

---
*Built by [Soar Systems](https://soarsystems.cc) - July 2024*

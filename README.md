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

Verify after downloading:
```powershell
Get-FileHash .\CrowdStrike_File_Removal_Fix.iso -Algorithm SHA256
# Expected: 01D94B0A4610F45461233BCDF5BA959BFD2E2F94043EF5195B9533EB8670D381
```

### Rufus (Required for Prepare-RemediationUsb.ps1)

Download the **portable version** (`rufusp.exe`) from [rufus.ie/downloads](https://rufus.ie/downloads/)

> Use the portable version (`rufusp.exe`) - not the installer. It runs without elevation prompts
> and is better suited for automated and scripted use.

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

| Tool | Where |
|---|---|
| PowerShell 5.1+ | Built into Windows |
| Rufus portable (`rufusp.exe`) | [rufus.ie/downloads](https://rufus.ie/downloads/) |
| Admin rights | Required for both scripts |

- `Prepare-RemediationUsb.ps1` - requires network access to download ISO, and Rufus
- `Remove-CrowdStrikeFile.ps1` - runs from WinPE/USB, no network required

## How It Was Used

1. IT burned 20+ USB drives in parallel using `Prepare-RemediationUsb.ps1` - under 1 hour
2. Drives shipped overnight to affected locations
3. On-site staff: insert USB → boot → wait for auto-restart (~5 min per machine)
4. IT confirmed each location coming back online via RMM
5. Full fleet recovered in under 8 hours

## Blog Post

Full write-up: [blog.soarsystems.cc](https://blog.soarsystems.cc)

---
*Built by [Soar Systems](https://soarsystems.cc) - July 2024*

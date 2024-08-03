# CrowdStrike Falcon Outage - Remediation Script

Remove-CrowdStrikeFile.ps1 deletes the faulty CrowdStrike channel file
(C-00000291*.sys) that caused the July 19, 2024 global Windows BSOD outage.
Boot any affected workstation from the USB drive below and this script runs
automatically - no input required.

## Download the bootable ISO

| File | SHA-256 |
|---|---|
| [CrowdStrike_File_Removal_Fix.iso](https://drive.google.com/file/d/1Dxe5-vVjL7jHR3eoQjV9MypZd4eS-Jy1/view?usp=sharing) | `01D94B0A4610F45461233BCDF5BA959BFD2E2F94043EF5195B9533EB8670D381` |

Verify after downloading:
```powershell
Get-FileHash .\CrowdStrike_File_Removal_Fix.iso -Algorithm SHA256
# Expected: 01D94B0A4610F45461233BCDF5BA959BFD2E2F94043EF5195B9533EB8670D381
```

## How to create the bootable USB (Rufus)

1. Download [Rufus portable](https://rufus.ie/downloads/) - use `rufusp.exe`
2. Plug in a USB drive (8GB or larger) and open Rufus
3. Under **Device**, select your USB drive
4. Under **Boot selection**, click **Select** and choose the ISO
5. Click **Start**, select **Write in ISO Image mode** when prompted
6. Click OK - wait for it to finish

## How to run it

Boot the affected workstation from the USB drive.

| Manufacturer | Boot menu key |
|---|---|
| Dell | F12 (F2 = BIOS, not boot menu) |
| HP | F9, or Esc then F9 (F10 = BIOS) |
| Lenovo | F12, or F11 on older models |

Select the USB from the boot menu. The script runs automatically, deletes
the bad file, and reboots the workstation. About 5 minutes per workstation.
A log is written to C:\Temp\FileDeletionLog.txt on every machine.

## Blog Post

https://blog.soarsystems.cc

---
*Built by [Soar Systems](https://soarsystems.cc) - July 2024*

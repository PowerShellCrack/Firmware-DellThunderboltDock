# Update Firmware for Dell Thunderbolt Dock

## Files
**Check-TBSupportedModels.ps1** - Used for MDT or SCCM Task sequence to check if its supported based on the [ModelsSupported.txt](ModelsSupported.txt) file. Sets SMSTS environment variable SMSTS_TBSupported

**Invoke-TBFirmware.ps1** - Check the supported models as well, and applies the firmware if compatible. Does check for Bios password in plain text file BIOSPassword.txt (if exists). It will attempt to suspend bitlocker if enabled. Also sets a SMSTS environment variable SMSTS_TBBatteryCharge, SMSTS_TBRebootRequired which can be used for a reboot sequence. 
 
## Warning: These updates should be done before plugging in the docking station for the first time.

## Summary of [Dell's Guidelines](https://www.dell.com/support/article/us/en/04/sln304347/dell-thunderbolt-dock-tb16-driver-installation-guide?lang=en)
 - Flash the latest Basic Input / Output System (BIOS) for the system. This is available in the "BIOS" section.
 - Install the latest Intel Thunderbolt Controller Driver for the system. This is available in the "Chipset" section.
 - Install the latest Intel Thunderbolt 3 Firmware Update for the system. This is available in the "Chipset" section.
 - Install the latest Intel HD Graphics Driver for the system. This is available in the "Video" section.
 - Install the latest ASMedia USB 3.0 Extended Host Controller Driver for Dell Thunderbolt Dock. This is available in the "Docks & Stands" section.
 - Install the latest RealTek USB GBE Ethernet Controller Driver for Dell Thunderbolt Dock and Dell Dock. This is available in the "Docks & Stands" section.
 - Install the latest RealTek USB Audio Driver for Dell Thunderbolt Dock and Dell Dock. This is available in the "Docks & Stands" section.
 - Restart the system.
 - After the software update process completes, connect the AC adapter to the TB16 dock first and then attach the Thunderbolt 3 (Type C) cable to the computer before using the docking station.


## RUN EXE IN ORDER (REBOOT IF NEEDED)
 - BIOS (eg. Latitude_7x80_1.10.1.exe)
 - Docks_Stands_Driver_G8VCP_WN32_2.44.2018.0504_A10.EXE
 - DellDockingStationFwUp_1.0.0_03192018_TB16.exe
 - ASMedia-USB-Extended-Host-Controller-Driver_3T8M8_WIN_1.16.51.1_A08.EXE
 - Realtek-USB-Audio-Driver_CCV58_WIN_6.3.9600.172_A09.EXE
 
### Originators/Credit

* [@AdmiralTolwyn](https://github.com/AdmiralTolwyn) (Anton Romanyuk)
* [@NickolajA](https://github.com/NickolajA) (Nickolaj Andersen)
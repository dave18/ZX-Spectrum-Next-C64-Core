# ZX-Spectrum-Next-C64-Core
Port of the MiSTer C64 Core to the Spectrum Next Issue 4 (KS2)

This port is based on the repository here https://github.com/MiSTer-devel/C64_MiSTer

## Features
- C64 and C64GS modes (Select Rom from Menu)
- External IEC through Expansion port
- Almost all cartridge formats (*.CRT)
- Direct file injection (*.PRG)
- Dual SID
- Similar to 6581 and 8580 SID filters
- Loadable Kernal/C1541 ROMs
- C128/Smart Turbo mode up to 4x
- Complete C1530 Datasette implementation with shortcuts keys

## Installation
Copy the core2.bit and core.cfg file to machines/C64/.

## Usage

### Next Keyboard
Note: Number and Letter mapped as expected.

| Next Key              | C64 Key                                      |
|:---------------------:|----------------------------------------------|
| BRK                   | F1                                           |
| EDIT                  | F3                                           |
| True Video            | F5                                           |
| Inverse Video         | F7                                           |
| Caps Lock             | Run Stop                                     |
| Graph                 | CTRL                                         |
| Delete                | INST DEL                                     |
| Cursor Up             | *                                            |
| Cursor Left           | =                                            |
| Cursor Right          | Cursor Right (Left with shift)               |
| Cursor Down           | Cursor Down (Up with shift)                  |
| Symbol Shift          | Commodore Key                                |
| Caps Shift            | Left Shift                                   |
| ;                     | ;                                            |
| "                     | :                                            |
| ,                     | ,                                            |
| .                     | .                                            |


Pushing the Extend Mode key toggles alternative mappings for some keys

| Next Key              | C64 Key                                      |
|:---------------------:|----------------------------------------------|
| Delete                | CLR HOME                                     |
| Cursor Up             | Up Arrow                                     |
| Cursor Left           | Left Arrow                                   |
| Caps Shift            | RightShift                                   |
| ;                     | @                                            |
| "                     | /                                            |
| ,                     | +                                            |
| .                     | -                                            |
| 4                     | Pound Sign                                            |

Note: Some combinations of Shift/CBM and other keys to get PETSCII symbols may not work due to Next ghosting.

### PS2 Keyboard
Note: F2, F4, F6, F8, Left/Up keys automatically activate Shift key.

| Key                   | Function                                     |
|:---------------------:|----------------------------------------------|
| F9                    | Arrow-up key                                 |
| F10                   | = key                                        |
| F11                   | Restore key. Also special key in AR/FC carts |
| Alt, Tab              | C= key                                       |
| WIN + Cursor Up       | Tape Play / Stop                             |
| WIN + Cursor Down     | Tape Stop                                    |
| WIN + Cursor Left     | Tape Rewind                                  |
| WIN + Cursor Right    | Tape Fast Forward                            |
| WIN + Canc (or Del)   | Tape Counter Reset                           |
<br>

### Loadable ROM
Alternative ROM can be loaded from OSD: Hardware->System ROM 64.
Format is simple concatenation of BASIC + Kernal.rom + C1541.rom

To create the ROM in DOS or Windows, gather your files in one place and use the following command from the DOS prompt. 
The easiest place to acquire the ROM files is from the VICE distribution. BASIC and KERNAL are in the C64 directory,
and dos1541 is in the Drives directory.

`COPY BASIC + KERNAL + dos1541 MYOWN.ROM /B`

To use JiffyDOS or another alternative kernel, replace the filenames with the name of your ROM or BIN file. (Note, you must use the 1541-II ROM. The ROM for the original 1541 only covers half the drive ROM and does not work with emulators.)

`COPY /B BASIC.bin +JiffyDOS_C64.bin +JiffyDOS_1541-II.bin MYOWN.ROM`

Note: As internal drives are not implemented the final part of the ROM is currently ignored.

To confirm you have the correct image, the ROM created must be exactly 32768 or 49152 (in case of 32KB C1541 ROM) bytes long. 

Two loadable ROM sets are provided: **DolphinDOS v2.0** and **SpeedDOS v2.7**. Both ROMs support the parallel Disk Port (more info below). DolphinDOS is the faster of the two.

### C1530 and tape support
In OSD->Load *.TAP and choose a TAP file. When a TAP is mounted use the Tape submeni in the OSD all the commands for managing the C1530. If using PS2 the keyboard shortcuts will also be enabled.

### Turbo modes
**C128 mode:** this is C128 compatible turbo mode available in C64 mode on Commodore 128 and can be controlled from software, so games written with this turbo mode support will take advantage of this.

**Smart mode:** In this mode any access to disk will disable turbo mode for short time enough to finish disk operations, thus you will have turbo mode without losing disk operations.

### Internal Disk Drives
The FPGA in the Spectrum Next cannot fit in both the fully fledged SID and Disk implementations that MiSTer uses so it was a choice of either using a simpler SID implementation or lost the disk drives (Fully MiSTer core takes up around 40k LUTs and we only have 15k and needs to squeeze a soft CPU in too). I have chosen to prioritise the SID as programs can be loaded from PRG, Tape and Cart and the sound really needs to be as good as possible. Disks can be loaded externally through the expansion bus and I want to try and use the PI Zero accelerator to manage disks in future.

### External Disk Drives (and other IEC devices)
The IEC port is mapped to the Next's Expansion Bus using the following connections.
| IEC Pin               | Expansion Bus Output                         |
|:---------------------:|----------------------------------------------|
| Ground                | Ground                                       |
| ATN                   | CLK                                          |
| CLK                   | D1                                           |
| DATA                  | A0                                           |

Because the Next Expansion Bus direction can only be set for all Address lines at once (using BUSACK) and all Data lines at once (using Bus_Y) the open collectors of CLK and DATA need to be split across the two. ATN is a simple output so mapped to clk as this is an output on the bus. You will need to ensure the Kernel ROM matches the one on the external device.

I've tested this with a PI1541 and it works perfectly, see picture below for wiring. 

![alt text](https://github.com/dave18/ZX-Spectrum-Next-C64-Core/blob/main/Images/PXL_20260923_211712881.jpg?raw=true)

### TODO
Try to implement HDMI output
Try to add PI1541 to Next Accelerator and interface seamlessly with core
Add RTC support
Add Boot Cartridge Support
Improve Firmware, especially file browsing

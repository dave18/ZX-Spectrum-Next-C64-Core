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
| Symbol Shift          | Commodore Key                                |
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

# Dig Dug - Digilent Basys 3

Dig Dug (1982 Namco), FPGA core by MiSTer-X, based on Tang Nano 20K port by
pinballwiz.org (<https://github.com/pinballwizz/TangNano20K-DigDug>).

## Hardware

- Digilent Basys 3 (Artix-7 `xc7a35tcpg236-1`).
- VGA monitor (31 kHz), or a 15 kHz TV/CRT (sw13, not tested).
- USB keyboard on the Basys 3 USB-HID host port.
- Optional: Atari-style joystick on Pmod JA, Digilent PmodAMP2 on Pmod JXADC.

## Build

Requirements:

- Vivado 2020.2, gcc, make, unzip, openFPGALoader.
- Romset `digdug.zip`.

```
make roms        # compile make_vhdl_prom, unzip ~/roms/digdug.zip, write PROM VHDL
make bitstream   # Vivado batch build of basys3/digdug_basys3.xpr
make load        # program the xc7 in JTAG mode (jumper JP1 in the JTAG position)
make clean       # remove roms, PROM VHDL and Vivado outputs
```

- `ROMDIR=<dir>` or `ROMZIP=<zip>` selects the romset.
- `VIVADO=<path>` selects the Vivado binary.

## IO

| Input           | Function                                      |
|-----------------|-----------------------------------------------|
| Arrow keys      | move                                          |
| Left Ctrl       | pump                                          |
| 1 / 2           | start 1 player / 2 players                    |
| 5               | coin                                          |
| btnU, btnD      | coin                                          |
| btnL / btnR     | start 1 player / 2 players                    |
| btnC            | reset                                         |
| JA 1/2/3/4/7    | joystick right/left/down/up/pump (active low) |
| sw0-sw9         | DIP switches (down = default, see below)      |
| sw12 up         | test mode                                     |
| sw13 down       | 31 kHz VGA                                    |
| sw13 up         | 15 kHz TV, composite sync on HS (not tested)  |
| sw14 up         | scanlines, alternate lines at 50 %, 31 kHz    |
| sw15 up         | audio off (PmodAMP2 shutdown)                 |

DIP switches (switch up inverts the default bit):

| Switch  | Setting        | Default            |
|---------|----------------|--------------------|
| sw0-sw2 | bonus life     | 10K only           |
| sw3-sw4 | lives          | 3                  |
| sw5-sw6 | difficulty     | easy               |
| sw7     | allow continue | no                 |
| sw8     | demo sounds    | off                |
| sw9     | freeze         | off                |

Coin A and coin B are fixed at 1 coin 1 credit, the cabinet at upright.

## Clock

One MMCM makes the 48, 24 and 12 MHz clocks of the Tang Nano 20K build. The core
derives its bus, CPU, video and sound clocks from 48 MHz. These are called out
explicitly in the Vivado XDC constraints so that their logic is timed. Converting to
clock enables on the master clock is in the backlog for investigation.

## Core changes for the Basys 3 port

Changes to the core files in `src/` (shared with the Tang Nano 20K project):

- Pump button not working: VBLK, the clock of the input sampling, registered on the
  pixel clock, so the decode of the counters cannot glitch it (`DIGDUG_VIDEO.v`).
- Right-hand columns lost on VGA monitors, then a stray column at the right edge:
  horizontal sync moved after a front porch, blanking one pixel earlier (`HVGEN.v`).

## Third-party additions

- `tools/tools_prom_src/src/make_vhdl_prom.c` (darfpga): PROM-to-VHDL converter,
  unmodified, from <https://github.com/pinballwizz/DE2-Xevious>.

## License

- The additions and changes made for the Basys 3 port are MIT licensed.
- Core files (`src/*.v`): (c) 2017 MiSTer-X, terms as stated in their headers. Other
  code keeps the terms stated in its files. `make_vhdl_prom.c` states no license.
- Roms and anything generated from them (PROM VHDL, bitstreams) are not distributed.

# Tang Nano 20K - Dig Dug

Dig Dug Arcade ported to a Tang Nano 20K FPGA Board by PinballWiz.org 2025.  
Works with VGA Monitor. Original code by MiSTer-X.

## Basys 3 port

Digilent Basys 3 version on branch `Port-to-Basys-3`: see
[TN20K-DigDug/basys3/README.md](TN20K-DigDug/basys3/README.md).

The Basys 3 version changes two core files shared with the Tang Nano 20K project: VBLK,
the clock of the input sampling, is registered so that it cannot glitch
(`DIGDUG_VIDEO.v`), and the horizontal sync starts after a front porch (`HVGEN.v`).

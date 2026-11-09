#!/bin/bash
# Generate the PROM VHDL from the Dig Dug romset into ../proms/ (port of
# make_digdug_proms.bat):
#   1. compile make_vhdl_prom into tools_prom_src/bin/
#   2. unzip ROMZIP (comma-separated) or ${ROMDIR:-~/roms}/digdug.zip into unzip/
#   3. write the PROM VHDL into ../proms/
#   4. create ../proms/.done, a marker file the Makefile checks before a bitstream build
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROM_DIR="$HERE/../proms"
UNZIP="$HERE/unzip"
TOOL="$HERE/tools_prom_src/bin/make_vhdl_prom"

if [ -n "${ROMZIP:-}" ]; then
    IFS=, read -r -a romzips <<< "$ROMZIP"
else
    romzips=("${ROMDIR:-$HOME/roms}/digdug.zip")
fi
for z in "${romzips[@]}"; do
    if [ ! -f "$z" ]; then
        echo "error: romset not found: $z (set ROMDIR or ROMZIP)" >&2
        exit 1
    fi
done

mkdir -p "$(dirname "$TOOL")" "$UNZIP" "$PROM_DIR"
gcc -w "$HERE/tools_prom_src/src/make_vhdl_prom.c" -lm -o "$TOOL"

for z in "${romzips[@]}"; do
    unzip -q -o "$z" -d "$UNZIP"
done
cd "$UNZIP"

prom() {
    "$TOOL" "$1" "$2"
    mv -f "$2" "$PROM_DIR/$2"
}

cat dd1a.1 dd1a.2 dd1a.3 dd1a.4 > cpu0_rom
cat dd1.15 dd1.14 dd1.13 dd1.12 > spchip_rom
cat dd1a.5 dd1a.6 > cpu1_rom
cp dd1.7 cpu2_rom
cp dd1.10b bgscrn_rom
cp dd1.11 bgchip_rom
cp dd1.9 fgchip_rom
cp 136007.110 wave_rom
cp 136007.111 spclut_rom
cp 136007.112 bgclut_rom
cp 136007.113 palette_rom

for r in cpu0_rom spchip_rom cpu1_rom cpu2_rom bgscrn_rom bgchip_rom fgchip_rom \
         wave_rom spclut_rom bgclut_rom palette_rom; do
    prom "$r" "$r.vhd"
done

touch "$PROM_DIR/.done"
echo "PROM VHDL in $PROM_DIR:"
ls -1 "$PROM_DIR"

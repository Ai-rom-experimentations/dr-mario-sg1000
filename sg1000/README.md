# Dr. Mario SG-1000 prototype

A small, playable SG-1000 port prototype built as a 32 KiB cartridge ROM. It uses the SG-1000's Z80 CPU, TMS9918A graphics and SN76489 sound hardware. The NES source in the parent repository is reference material only; this build is independent.

## Build

Install [SjASMPlus](https://github.com/z00m128/sjasmplus), then from this directory run:

```sh
./build.sh
```

The output is `build/drmario.sg` (32,768 bytes). To select another assembler executable, set `SJASMPLUS`, for example `SJASMPLUS=/usr/local/bin/sjasmplus ./build.sh`.

## Run / controls

Load `build/drmario.sg` in an SG-1000 emulator. On the title screen, left/right changes the selected value, up/down selects level or speed, and either fire button starts. During play, the D-pad moves/drops the pill and the fire buttons rotate it.

`tools/run.py` is a lightweight host-side test/render harness (requires the Python `z80` package):

```sh
python3 tools/run.py --frames 60 --script '1:A' --shot /tmp/game.png
```

The harness is for development checks, not part of the ROM.

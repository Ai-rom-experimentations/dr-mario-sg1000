#!/usr/bin/env python3
"""Headless SG-1000 harness for the Dr. Mario prototype.

Emulates a Z80 (via the `z80` Python package) plus just enough TMS9918A to
render a frame, so the ROM can be checked without a GUI emulator.

    python3 tools/run.py --frames 120 --shot out.png
    python3 tools/run.py --script "20:RIGHT 5:A 30:DOWN" --shot out.png
    python3 tools/run.py --savetile 0x31        # dump a tile as text

Button names: UP DOWN LEFT RIGHT A (=B1) B (=B2) START, or a "-" list.
"""

import argparse
import struct
import sys
import zlib

import z80

W, H = 256, 192

# TMS9918A palette (MAME's values)
PALETTE = [
    (0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120),
    (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
    (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
    (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255),
]


class VDP:
    def __init__(self):
        self.vram = bytearray(0x4000)
        self.regs = [0] * 8
        self.latch = False
        self.addr = 0
        self.status = 0x00
        self.readbuf = 0
        self.cram = bytearray(32)      # SG-1000 32 byte palette
        self.mode = 0
        self.display_on = False
        self.irq = False
        # timing within a scanline
        self.hpos = 0
        self.line = 0
        self.vint_pending = False

    # ---- registers ------------------------------------------------------
    def set_reg(self, n, v):
        self.regs[n] = v
        if n <= 1:
            self.update_mode()
        if n == 1 and (v & 0x20):
            pass

    def update_mode(self):
        r0, r1 = self.regs[0], self.regs[1]
        m1 = (r1 >> 4) & 1
        m2 = (r1 >> 3) & 1
        m3 = (r0 >> 2) & 1              # SMS only; the SG-1000 is a TMS9918A
        if m3:
            self.mode = 4
        elif m1:
            self.mode = 1
        elif m2:
            self.mode = 3
        elif r0 & 0x02:
            self.mode = 2
        else:
            self.mode = 0
        # Graphics I is the TMS9918 mode 0
        self.graphics1 = not (m1 or m2 or m3)

    # ---- ports ----------------------------------------------------------
    def write_ctrl(self, v):
        if not self.latch:
            self.latch = True
            self.addr = (self.addr & 0x3F00) | v
        else:
            self.latch = False
            if v & 0x80:
                self.set_reg(v & 0x0F, self.addr & 0xFF)
            else:
                self.addr = ((v & 0x3F) << 8) | (self.addr & 0xFF)

    def write_data(self, v):
        self.latch = False
        if self.mode == 4 and (self.addr & 0x2000 or self.addr >= 0x2000):
            pass
        self.vram[self.addr & 0x3FFF] = v
        self.readbuf = v
        self.addr = (self.addr + 1) & 0x3FFF

    def read_data(self):
        self.latch = False
        v = self.readbuf
        self.readbuf = self.vram[self.addr & 0x3FFF]
        self.addr = (self.addr + 1) & 0x3FFF
        return v

    def read_ctrl(self):
        self.latch = False
        v = self.status
        self.status &= 0x1F            # clear vblank / collision / overflow
        self.vint_pending = False
        self.irq = False
        return v

    # ---- rendering ------------------------------------------------------
    def render(self):
        px = bytearray(W * H)
        backdrop = self.regs[7] & 0x0F
        while backdrop == 0:
            backdrop = 1
        for i in range(W * H):
            px[i] = backdrop
        if not (self.regs[1] & 0x40):
            return px

        # backdrop
        for i in range(W * H):
            px[i] = backdrop

        if self.graphics1:
            self.render_g1(px)
        else:
            # unsupported mode: leave the backdrop
            pass
        self.render_sprites(px)
        return px

    def color_of(self, index):
        # TMS9918: colour 0 in the colour table means transparent, and the
        # backdrop is forced to black when register 7 selects colour 0
        if index == 0:
            bd = self.regs[7] & 0x0F
            return bd if bd else 1
        return index

    def render_g1(self, px):
        name = (self.regs[2] & 0x0F) << 10
        colour = (self.regs[3] * 64) & 0x3FFF   # MAME: m_colour = R3*64
        pattern = (self.regs[4] & 0x07) << 11
        for ty in range(24):
            for tx in range(32):
                ch = self.vram[(name + ty * 32 + tx) & 0x3FFF]
                fg = self.vram[(colour + (ch >> 3)) & 0x3FFF] >> 4
                bg = self.vram[(colour + (ch >> 3)) & 0x3FFF] & 0x0F
                fg = self.color_of(fg)
                bg = self.color_of(bg)
                base = pattern + ch * 8
                for row in range(8):
                    bits = self.vram[(base + row) & 0x3FFF]
                    yy = ty * 8 + row
                    for col in range(8):
                        c = fg if bits & (0x80 >> col) else bg
                        px[yy * W + tx * 8 + col] = c

    def render_sprites(self, px):
        sat = (self.regs[5] & 0x7F) << 7
        spt = (self.regs[6] & 0x07) << 11
        size = 16 if (self.regs[1] & 0x02) else 8
        mag = 2 if (self.regs[1] & 0x01) else 1
        # first pass: foreground sprite pixels
        fgmask = bytearray(W * H)
        for s in range(32):
            base = sat + s * 4
            y = self.vram[base]
            if y == 0xD0:
                break
            y = (y + 1) & 0xFF
            if y >= 0xE0:
                y -= 0x100
            x = self.vram[base + 1]
            pat = self.vram[base + 2]
            col = self.vram[base + 3]
            if col & 0x80:
                x -= 32
            col &= 0x0F
            if col == 0:
                continue
            if size == 16:
                pat &= 0xFC
            for row in range(size):
                sy = y + row * mag
                bits = self.vram[(spt + pat * 8 + row) & 0x3FFF]
                for c in range(8):
                    if not (bits & (0x80 >> c)):
                        continue
                    for k in range(mag):
                        sx = x + (c * mag) + k
                        for j in range(mag):
                            py = sy + j
                            if 0 <= sx < W and 0 <= py < H:
                                px[py * W + sx] = col
                                fgmask[py * W + sx] = 1
        # second pass: background sprites (bit 7 of the colour byte)
        for s in range(32):
            base = sat + s * 4
            y = self.vram[base]
            if y == 0xD0:
                break
            y = (y + 1) & 0xFF
            if y >= 0xE0:
                y -= 0x100
            x = self.vram[base + 1]
            pat = self.vram[base + 2]
            col = self.vram[base + 3]
            if col & 0x80:
                x -= 32
            else:
                continue
            col &= 0x0F
            if col == 0:
                continue
            if size == 16:
                pat &= 0xFC
            for row in range(size):
                sy = y + row * mag
                bits = self.vram[(spt + pat * 8 + row) & 0x3FFF]
                for c in range(8):
                    if not (bits & (0x80 >> c)):
                        continue
                    for k in range(mag):
                        sx = x + (c * mag) + k
                        for j in range(mag):
                            py = sy + j
                            if 0 <= sx < W and 0 <= py < H and not fgmask[py * W + sx]:
                                px[py * W + sx] = col


BUTTONS = {
    'UP': 0x01, 'DOWN': 0x02, 'LEFT': 0x04, 'RIGHT': 0x08,
    'A': 0x10, 'B': 0x20, 'START': 0x40,
}


class Machine:
    def __init__(self, rom):
        self.m = z80.Z80Machine()
        self.vdp = VDP()
        self.ram = bytearray(0x400)
        self.rom = rom
        self.buttons = 0
        self.psg = []
        self.frames = 0
        self.period = 59736
        self.left = self.period
        self.irq_enabled = False
        self.finished = False

        self.m.set_output_callback(self.on_out)
        self.m.set_input_callback(self.on_in)
        self.m.set_write_callback(self.on_write)
        self.m.set_read_callback(self.on_read)
        # mark the memory areas we shadow
        self.m.mark_addrs(0xC000, 0x0400, self.m.READ_MARK | self.m.WRITE_MARK)
        self.m.pc = 0
        self.m.memory[0x0000:len(rom)] = rom

    # ---- bus ------------------------------------------------------------
    def on_read(self, addr):
        if 0xC000 <= addr < 0xC400:
            return self.ram[addr - 0xC000]
        return self.m.memory[addr]

    def on_write(self, addr, value):
        if 0xC000 <= addr < 0xC400:
            self.ram[addr - 0xC000] = value

    def on_in(self, port):
        p = port & 0xFF
        if (port >> 8) & 0xFF == 0xBF or p == 0xBF:
            if p in (0xBE, 0xBF):
                pass
        if p in (0xBE, 0xBF):
            if p == 0xBE:
                return self.vdp.read_data()
            return self.vdp.read_ctrl()
        if p in (0xDC, 0xDE):
            return 0x7F & ~self.buttons   # P1, active low
        if p in (0xDD, 0xDF):
            return 0xFF
        return 0xFF

    def on_out(self, port, value):
        p = port & 0xFF
        if p in (0xBE, 0xBF):
            if p == 0xBE:
                self.vdp.write_data(value)
            else:
                self.vdp.write_ctrl(value)
            return
        if p in (0x7F, 0x40) or (port & 0xFF) in (0x7F, 0x40):
            self.psg.append(value)
            return

    # ---- run ------------------------------------------------------------
    def step(self):
        """Run until the next end of scanline."""
        chunk = min(self.left, 64)
        if chunk == 0:
            chunk = 1
        self.m.ticks_to_stop = chunk
        self.m.run()
        self.left -= chunk
        if self.left <= 0:
            self.left += self.period
            self.end_line()

    def end_line(self):
        v = self.vdp
        v.line += 1
        if v.line == 192:
            v.status |= 0x80
            v.vint_pending = True
            if v.regs[1] & 0x20:
                v.irq = True
        if v.line >= 262:
            v.line = 0
            self.frames += 1
        if v.irq:
            self.m.on_handle_active_int()

    def run_frames(self, n):
        target = self.frames + n
        guard = 0
        while self.frames < target:
            self.step()
            guard += 1
            if guard > 100_000_000:
                raise RuntimeError('emulator stuck')
        return self.frames

    def press(self, buttons, frames=2):
        self.buttons = buttons
        self.run_frames(frames)

    def release(self):
        self.buttons = 0
        self.run_frames(1)


def write_png(path, px, scale=2):
    """Minimal PNG writer (RGB), scaled up for readability."""
    w, h = W * scale, H * scale
    rows = bytearray()
    for y in range(H):
        line = bytearray()
        for x in range(W):
            line += bytes(PALETTE[px[y * W + x] & 0x0F]) * scale
        for _ in range(scale):
            rows.append(0)
            rows += line
    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(rows), 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)
    print('wrote', path)


def ascii_frame(px, x0=0, y0=0, cols=32, rows=24):
    """Render the screen as text, one character per 8x8 tile."""
    out = []
    for ty in range(rows):
        line = ''
        for tx in range(cols):
            counts = {}
            for row in range(8):
                for col in range(8):
                    c = px[(y0 + ty) * 8 * W + row * W + (x0 + tx) * 8 + col]
                    counts[c] = counts.get(c, 0) + 1
            bg = max(counts, key=counts.get)
            mask = 0
            for row in range(8):
                for col in range(8):
                    if px[(y0 + ty) * 8 * W + row * W + (x0 + tx) * 8 + col] != bg:
                        mask |= 1 << (row * 8 + col)
            line += tile_char(mask)
        out.append(line)
    return '\n'.join(out)


def tile_char(mask):
    # rough density based character
    n = bin(mask).count('1')
    if n == 0:
        return '.'
    if n < 8:
        return ':'
    if n < 20:
        return '+'
    if n < 40:
        return '*'
    return '#'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rom', default='build/drmario.sg')
    ap.add_argument('--frames', type=int, default=60)
    ap.add_argument('--script', default='')
    ap.add_argument('--shot', default='')
    ap.add_argument('--ascii', action='store_true')
    ap.add_argument('--trace', action='store_true')
    ap.add_argument('--scale', type=int, default=2)
    args = ap.parse_args()

    rom = open(args.rom, 'rb').read()
    m = Machine(rom)
    m.run_frames(2)

    for token in args.script.split():
        if ':' in token:
            n, keys = token.split(':', 1)
            m.run_frames(int(n))
            bits = 0
            for k in keys.split('-'):
                bits |= BUTTONS[k]
            m.press(bits, 3)
            m.release()
    m.run_frames(args.frames)

    if args.trace:
        print('frames', m.frames, 'pc', hex(m.m.pc))
        print('vdp regs', [hex(x) for x in m.vdp.regs])
        print('mode', m.vdp.mode, 'g1', m.vdp.graphics1)
        print('ram', bytes(m.ram[:0x20]).hex())
        print('field', bytes(m.ram[0x20:0xA0]).hex())

    px = m.vdp.render()
    if args.ascii:
        print(ascii_frame(px))
    if args.shot:
        write_png(args.shot, px, args.scale)
    return 0


if __name__ == '__main__':
    sys.exit(main())

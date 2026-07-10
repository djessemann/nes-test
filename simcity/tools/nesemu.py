#!/usr/bin/env python3
"""Minimal headless NES emulator for automated testing of this project.

Supports: official 6502 opcodes, mappers 0/1, PPU registers with loopy
v/t/x/w semantics, frame rendering to PNG (numpy+PIL), scripted controller
input. Timing is frame-approximate: CPU runs N cycles of "visible" period,
then vblank flag + NMI, then vblank period. Good enough to catch logic and
PPU-usage bugs; not cycle-exact.

Usage:
  nesemu.py rom.nes --frames 300 --png out.png
  nesemu.py rom.nes --frames 300 --png-at 60=a.png,120=b.png \
      --input "30:START,60-120:RIGHT+A"
"""
import sys, argparse

import numpy as np

CYCLES_VISIBLE = 27384
CYCLES_VBLANK = 2400

# standard 2C02 palette (RGB triplets)
NES_PALETTE = [
    (84,84,84),(0,30,116),(8,16,144),(48,0,136),(68,0,100),(92,0,48),(84,4,0),(60,24,0),
    (32,42,0),(8,58,0),(0,64,0),(0,60,0),(0,50,60),(0,0,0),(0,0,0),(0,0,0),
    (152,150,152),(8,76,196),(48,50,236),(92,30,228),(136,20,176),(160,20,100),(152,34,32),(120,60,0),
    (84,90,0),(40,114,0),(8,124,0),(0,118,40),(0,102,120),(0,0,0),(0,0,0),(0,0,0),
    (236,238,236),(76,154,236),(120,124,236),(176,98,236),(228,84,236),(236,88,180),(236,106,100),(212,136,32),
    (160,170,0),(116,196,0),(76,208,32),(56,204,108),(56,180,204),(60,60,60),(0,0,0),(0,0,0),
    (236,238,236),(168,204,236),(188,188,236),(212,178,236),(236,174,236),(236,174,212),(236,180,176),(228,196,144),
    (204,210,120),(180,222,120),(168,226,144),(152,226,180),(160,214,228),(160,162,160),(0,0,0),(0,0,0),
]

BUTTONS = {'A':0,'B':1,'SEL':2,'START':3,'U':4,'D':5,'L':6,'R':7}

class NES:
    def __init__(self, rom_path):
        with open(rom_path,'rb') as f: rom = f.read()
        assert rom[:4] == b'NES\x1a', 'not an iNES file'
        prg_banks, chr_banks = rom[4], rom[5]
        self.mapper = (rom[6] >> 4) | (rom[7] & 0xF0)
        self.four_screen = bool(rom[6] & 8)
        self.mirroring = 2 if (rom[6] & 1) else 3  # 2=vert,3=horiz (MMC1 codes)
        off = 16 + (512 if rom[6] & 4 else 0)
        self.prg = rom[off:off+prg_banks*16384]
        off += prg_banks*16384
        self.chr = bytearray(rom[off:off+chr_banks*8192]) if chr_banks else bytearray(8192)
        self.chr_is_ram = chr_banks == 0
        self.prg_banks = prg_banks
        # MMC1 state
        self.m1_shift = 0; self.m1_count = 0
        self.m1_ctrl = 0x0C  # PRG mode 3 (fix last), 8KB CHR
        self.m1_chr0 = 0; self.m1_chr1 = 0; self.m1_prg = 0
        if self.mapper == 1:
            self.mirroring = self.m1_ctrl & 3
        # memory
        self.ram = bytearray(0x800)
        self.wram = bytearray(0x2000)
        self.vram = bytearray(0x800)
        self.pal = bytearray(32)
        self.oam = bytearray(256)
        # PPU regs
        self.v = 0; self.t = 0; self.x = 0; self.w = 0
        self.ppuctrl = 0; self.ppumask = 0; self.ppustatus = 0
        self.oamaddr = 0; self.ppudata_buf = 0
        self.in_vblank = False
        self.rendering_warned = set()
        self.frame = 0
        # controller
        self.joy_strobe = 0; self.joy_shift = 0; self.buttons = 0
        # CPU
        self.a = 0; self.xr = 0; self.yr = 0; self.sp = 0xFD
        self.p = 0x24
        self.cycles = 0
        self.pc = self.read16(0xFFFC)
        self.build_ops()
        self.warnings = []

    # ------------------------------------------------------------ memory ---
    def prg_read(self, addr):
        if self.mapper == 0:
            return self.prg[(addr - 0x8000) % len(self.prg)]
        # MMC1
        mode = (self.m1_ctrl >> 2) & 3
        bank = self.m1_prg & 0x0F
        if mode <= 1:  # 32KB
            base = (bank >> 1) * 0x8000
            return self.prg[(base + (addr - 0x8000)) % len(self.prg)]
        if mode == 2:  # fix first at 8000
            if addr < 0xC000: return self.prg[addr - 0x8000]
            return self.prg[(bank*0x4000 + (addr-0xC000)) % len(self.prg)]
        # mode 3: fix last at C000
        if addr < 0xC000: return self.prg[(bank*0x4000 + (addr-0x8000)) % len(self.prg)]
        return self.prg[len(self.prg)-0x4000 + (addr-0xC000)]

    def chr_addr(self, addr):
        if self.mapper != 1: return addr % len(self.chr)
        if self.m1_ctrl & 0x10:  # 4KB mode
            if addr < 0x1000: return (self.m1_chr0*0x1000 + addr) % len(self.chr)
            return (self.m1_chr1*0x1000 + (addr-0x1000)) % len(self.chr)
        return ((self.m1_chr0 >> 1)*0x2000 + addr) % len(self.chr)

    def nt_addr(self, addr):
        addr &= 0x0FFF
        table = addr // 0x400; off = addr % 0x400
        m = self.mirroring
        if m == 2:   phys = table & 1          # vertical
        elif m == 3: phys = (table >> 1) & 1   # horizontal
        elif m == 0: phys = 0                  # one-screen A
        else:        phys = 1                  # one-screen B
        return phys*0x400 + off

    def ppu_read(self, addr):
        addr &= 0x3FFF
        if addr < 0x2000: return self.chr[self.chr_addr(addr)]
        if addr < 0x3F00: return self.vram[self.nt_addr(addr)]
        a = addr & 0x1F
        if a >= 0x10 and (a & 3) == 0: a -= 0x10
        return self.pal[a]

    def ppu_write(self, addr, val):
        addr &= 0x3FFF
        if addr < 0x2000:
            if self.chr_is_ram: self.chr[self.chr_addr(addr)] = val
        elif addr < 0x3F00:
            self.vram[self.nt_addr(addr)] = val
        else:
            a = addr & 0x1F
            if a >= 0x10 and (a & 3) == 0: a -= 0x10
            self.pal[a] = val

    def warn_render_write(self, what):
        if self.ppumask & 0x18 and not self.in_vblank:
            key = (what, self.frame)
            if key not in self.rendering_warned:
                self.rendering_warned.add(key)
                self.warnings.append(f"frame {self.frame}: {what} while rendering enabled outside vblank")

    def read(self, addr):
        if addr < 0x2000: return self.ram[addr & 0x7FF]
        if addr < 0x4000:
            r = addr & 7
            if r == 2:
                val = self.ppustatus
                self.ppustatus &= 0x7F
                self.w = 0
                return val
            if r == 4: return self.oam[self.oamaddr]
            if r == 7:
                a = self.v & 0x3FFF
                if a < 0x3F00:
                    val = self.ppudata_buf
                    self.ppudata_buf = self.ppu_read(a)
                else:
                    val = self.ppu_read(a)
                    self.ppudata_buf = self.vram[self.nt_addr(a)]
                self.v = (self.v + (32 if self.ppuctrl & 4 else 1)) & 0x7FFF
                return val
            return 0
        if addr == 0x4016:
            if self.joy_strobe: return self.buttons & 1
            val = self.joy_shift & 1
            self.joy_shift = (self.joy_shift >> 1) | 0x80
            return val
        if addr == 0x4017: return 0
        if addr < 0x4020: return 0
        if 0x6000 <= addr < 0x8000: return self.wram[addr - 0x6000]
        if addr >= 0x8000: return self.prg_read(addr)
        return 0

    def write(self, addr, val):
        val &= 0xFF
        if addr < 0x2000: self.ram[addr & 0x7FF] = val; return
        if addr < 0x4000:
            r = addr & 7
            if r == 0:
                old = self.ppuctrl
                self.ppuctrl = val
                self.t = (self.t & 0xF3FF) | ((val & 3) << 10)
                if (val & 0x80) and not (old & 0x80) and (self.ppustatus & 0x80):
                    self.pending_nmi = True
            elif r == 1: self.ppumask = val
            elif r == 3: self.oamaddr = val
            elif r == 4:
                self.oam[self.oamaddr] = val
                self.oamaddr = (self.oamaddr + 1) & 0xFF
            elif r == 5:
                if self.w == 0:
                    self.t = (self.t & 0x7FE0) | (val >> 3)
                    self.x = val & 7
                    self.w = 1
                else:
                    self.t = (self.t & 0x0C1F) | ((val & 7) << 12) | ((val & 0xF8) << 2)
                    self.w = 0
            elif r == 6:
                if self.w == 0:
                    self.t = (self.t & 0x00FF) | ((val & 0x3F) << 8)
                    self.w = 1
                else:
                    self.t = (self.t & 0x7F00) | val
                    self.v = self.t
                    self.w = 0
                self.warn_render_write('PPUADDR write')
            elif r == 7:
                self.warn_render_write('PPUDATA write')
                self.ppu_write(self.v, val)
                self.v = (self.v + (32 if self.ppuctrl & 4 else 1)) & 0x7FFF
            return
        if addr == 0x4014:
            self.warn_render_write('OAM DMA')
            base = val << 8
            for i in range(256):
                self.oam[(self.oamaddr + i) & 0xFF] = self.read(base + i)
            self.cycles += 513
            return
        if addr == 0x4016:
            if self.joy_strobe and not (val & 1):
                self.joy_shift = self.buttons
            self.joy_strobe = val & 1
            return
        if addr < 0x4020: return  # APU
        if 0x6000 <= addr < 0x8000: self.wram[addr - 0x6000] = val; return
        if addr >= 0x8000:
            if self.mapper == 1: self.mmc1_write(addr, val)
            return

    def mmc1_write(self, addr, val):
        if val & 0x80:
            self.m1_shift = 0; self.m1_count = 0
            self.m1_ctrl |= 0x0C
            return
        self.m1_shift |= (val & 1) << self.m1_count
        self.m1_count += 1
        if self.m1_count == 5:
            reg = (addr >> 13) & 3
            v = self.m1_shift
            self.m1_shift = 0; self.m1_count = 0
            if reg == 0:
                self.m1_ctrl = v
                self.mirroring = v & 3
            elif reg == 1: self.m1_chr0 = v
            elif reg == 2: self.m1_chr1 = v
            else: self.m1_prg = v

    def read16(self, addr):
        return self.read(addr) | (self.read(addr+1) << 8)

    # ------------------------------------------------------------- CPU -----
    def build_ops(self):
        self.pending_nmi = False

    def push(self, v): self.write(0x100 + self.sp, v); self.sp = (self.sp - 1) & 0xFF
    def pop(self): self.sp = (self.sp + 1) & 0xFF; return self.read(0x100 + self.sp)

    def set_zn(self, v):
        self.p = (self.p & ~0x82) | (0x02 if v == 0 else 0) | (v & 0x80)

    def nmi_interrupt(self):
        self.push(self.pc >> 8); self.push(self.pc & 0xFF)
        self.push((self.p & ~0x10) | 0x20)
        self.p |= 0x04
        self.pc = self.read16(0xFFFA)
        self.cycles += 7

    def step(self):
        op = self.read(self.pc)
        pc = self.pc
        self.pc = (self.pc + 1) & 0xFFFF
        c = self.exec_op(op)
        if c is None:
            raise RuntimeError(f"unknown opcode ${op:02X} at ${pc:04X}")
        self.cycles += c

    # addressing helpers: return address
    def a_imm(self):
        a = self.pc; self.pc = (self.pc+1) & 0xFFFF; return a
    def a_zp(self):
        a = self.read(self.a_imm()); return a
    def a_zpx(self): return (self.a_zp() + self.xr) & 0xFF
    def a_zpy(self): return (self.a_zp() + self.yr) & 0xFF
    def a_abs(self):
        a = self.read16(self.pc); self.pc = (self.pc+2) & 0xFFFF; return a
    def a_abx(self): return (self.a_abs() + self.xr) & 0xFFFF
    def a_aby(self): return (self.a_abs() + self.yr) & 0xFFFF
    def a_indx(self):
        z = (self.a_zp() + self.xr) & 0xFF
        return self.read(z) | (self.read((z+1) & 0xFF) << 8)
    def a_indy(self):
        z = self.a_zp()
        return ((self.read(z) | (self.read((z+1) & 0xFF) << 8)) + self.yr) & 0xFFFF

    def branch(self, cond):
        off = self.read(self.a_imm())
        if cond:
            if off & 0x80: off -= 256
            self.pc = (self.pc + off) & 0xFFFF
            return 3
        return 2

    def adc(self, val):
        c = self.p & 1
        r = self.a + val + c
        self.p = (self.p & ~0xC3)
        if r > 0xFF: self.p |= 1
        if (~(self.a ^ val) & (self.a ^ r)) & 0x80: self.p |= 0x40
        self.a = r & 0xFF
        self.set_zn(self.a)

    def cmp_(self, reg, val):
        r = (reg - val) & 0x1FF
        self.p = (self.p & ~0x83) | (1 if reg >= val else 0)
        self.set_zn((reg - val) & 0xFF)
        self.p |= (1 if reg >= val else 0)

    def asl_val(self, v):
        self.p = (self.p & ~1) | (v >> 7)
        v = (v << 1) & 0xFF; self.set_zn(v); return v
    def lsr_val(self, v):
        self.p = (self.p & ~1) | (v & 1)
        v >>= 1; self.set_zn(v); return v
    def rol_val(self, v):
        c = self.p & 1
        self.p = (self.p & ~1) | (v >> 7)
        v = ((v << 1) | c) & 0xFF; self.set_zn(v); return v
    def ror_val(self, v):
        c = self.p & 1
        self.p = (self.p & ~1) | (v & 1)
        v = (v >> 1) | (c << 7); self.set_zn(v); return v

    def exec_op(self, op):
        # returns cycle count or None
        A = self  # brevity
        if op == 0xEA: return 2  # NOP
        # ---- loads
        if op == 0xA9: A.a = A.read(A.a_imm()); A.set_zn(A.a); return 2
        if op == 0xA5: A.a = A.read(A.a_zp()); A.set_zn(A.a); return 3
        if op == 0xB5: A.a = A.read(A.a_zpx()); A.set_zn(A.a); return 4
        if op == 0xAD: A.a = A.read(A.a_abs()); A.set_zn(A.a); return 4
        if op == 0xBD: A.a = A.read(A.a_abx()); A.set_zn(A.a); return 4
        if op == 0xB9: A.a = A.read(A.a_aby()); A.set_zn(A.a); return 4
        if op == 0xA1: A.a = A.read(A.a_indx()); A.set_zn(A.a); return 6
        if op == 0xB1: A.a = A.read(A.a_indy()); A.set_zn(A.a); return 5
        if op == 0xA2: A.xr = A.read(A.a_imm()); A.set_zn(A.xr); return 2
        if op == 0xA6: A.xr = A.read(A.a_zp()); A.set_zn(A.xr); return 3
        if op == 0xB6: A.xr = A.read(A.a_zpy()); A.set_zn(A.xr); return 4
        if op == 0xAE: A.xr = A.read(A.a_abs()); A.set_zn(A.xr); return 4
        if op == 0xBE: A.xr = A.read(A.a_aby()); A.set_zn(A.xr); return 4
        if op == 0xA0: A.yr = A.read(A.a_imm()); A.set_zn(A.yr); return 2
        if op == 0xA4: A.yr = A.read(A.a_zp()); A.set_zn(A.yr); return 3
        if op == 0xB4: A.yr = A.read(A.a_zpx()); A.set_zn(A.yr); return 4
        if op == 0xAC: A.yr = A.read(A.a_abs()); A.set_zn(A.yr); return 4
        if op == 0xBC: A.yr = A.read(A.a_abx()); A.set_zn(A.yr); return 4
        # ---- stores
        if op == 0x85: A.write(A.a_zp(), A.a); return 3
        if op == 0x95: A.write(A.a_zpx(), A.a); return 4
        if op == 0x8D: A.write(A.a_abs(), A.a); return 4
        if op == 0x9D: A.write(A.a_abx(), A.a); return 5
        if op == 0x99: A.write(A.a_aby(), A.a); return 5
        if op == 0x81: A.write(A.a_indx(), A.a); return 6
        if op == 0x91: A.write(A.a_indy(), A.a); return 6
        if op == 0x86: A.write(A.a_zp(), A.xr); return 3
        if op == 0x96: A.write(A.a_zpy(), A.xr); return 4
        if op == 0x8E: A.write(A.a_abs(), A.xr); return 4
        if op == 0x84: A.write(A.a_zp(), A.yr); return 3
        if op == 0x94: A.write(A.a_zpx(), A.yr); return 4
        if op == 0x8C: A.write(A.a_abs(), A.yr); return 4
        # ---- transfers
        if op == 0xAA: A.xr = A.a; A.set_zn(A.xr); return 2
        if op == 0xA8: A.yr = A.a; A.set_zn(A.yr); return 2
        if op == 0x8A: A.a = A.xr; A.set_zn(A.a); return 2
        if op == 0x98: A.a = A.yr; A.set_zn(A.a); return 2
        if op == 0xBA: A.xr = A.sp; A.set_zn(A.xr); return 2
        if op == 0x9A: A.sp = A.xr; return 2
        # ---- stack
        if op == 0x48: A.push(A.a); return 3
        if op == 0x68: A.a = A.pop(); A.set_zn(A.a); return 4
        if op == 0x08: A.push(A.p | 0x30); return 3
        if op == 0x28: A.p = (A.pop() & ~0x10) | 0x20; return 4
        # ---- arithmetic
        if op == 0x69: A.adc(A.read(A.a_imm())); return 2
        if op == 0x65: A.adc(A.read(A.a_zp())); return 3
        if op == 0x75: A.adc(A.read(A.a_zpx())); return 4
        if op == 0x6D: A.adc(A.read(A.a_abs())); return 4
        if op == 0x7D: A.adc(A.read(A.a_abx())); return 4
        if op == 0x79: A.adc(A.read(A.a_aby())); return 4
        if op == 0x61: A.adc(A.read(A.a_indx())); return 6
        if op == 0x71: A.adc(A.read(A.a_indy())); return 5
        if op == 0xE9: A.adc(A.read(A.a_imm()) ^ 0xFF); return 2
        if op == 0xE5: A.adc(A.read(A.a_zp()) ^ 0xFF); return 3
        if op == 0xF5: A.adc(A.read(A.a_zpx()) ^ 0xFF); return 4
        if op == 0xED: A.adc(A.read(A.a_abs()) ^ 0xFF); return 4
        if op == 0xFD: A.adc(A.read(A.a_abx()) ^ 0xFF); return 4
        if op == 0xF9: A.adc(A.read(A.a_aby()) ^ 0xFF); return 4
        if op == 0xE1: A.adc(A.read(A.a_indx()) ^ 0xFF); return 6
        if op == 0xF1: A.adc(A.read(A.a_indy()) ^ 0xFF); return 5
        # ---- logic
        if op == 0x29: A.a &= A.read(A.a_imm()); A.set_zn(A.a); return 2
        if op == 0x25: A.a &= A.read(A.a_zp()); A.set_zn(A.a); return 3
        if op == 0x35: A.a &= A.read(A.a_zpx()); A.set_zn(A.a); return 4
        if op == 0x2D: A.a &= A.read(A.a_abs()); A.set_zn(A.a); return 4
        if op == 0x3D: A.a &= A.read(A.a_abx()); A.set_zn(A.a); return 4
        if op == 0x39: A.a &= A.read(A.a_aby()); A.set_zn(A.a); return 4
        if op == 0x21: A.a &= A.read(A.a_indx()); A.set_zn(A.a); return 6
        if op == 0x31: A.a &= A.read(A.a_indy()); A.set_zn(A.a); return 5
        if op == 0x09: A.a |= A.read(A.a_imm()); A.set_zn(A.a); return 2
        if op == 0x05: A.a |= A.read(A.a_zp()); A.set_zn(A.a); return 3
        if op == 0x15: A.a |= A.read(A.a_zpx()); A.set_zn(A.a); return 4
        if op == 0x0D: A.a |= A.read(A.a_abs()); A.set_zn(A.a); return 4
        if op == 0x1D: A.a |= A.read(A.a_abx()); A.set_zn(A.a); return 4
        if op == 0x19: A.a |= A.read(A.a_aby()); A.set_zn(A.a); return 4
        if op == 0x01: A.a |= A.read(A.a_indx()); A.set_zn(A.a); return 6
        if op == 0x11: A.a |= A.read(A.a_indy()); A.set_zn(A.a); return 5
        if op == 0x49: A.a ^= A.read(A.a_imm()); A.set_zn(A.a); return 2
        if op == 0x45: A.a ^= A.read(A.a_zp()); A.set_zn(A.a); return 3
        if op == 0x55: A.a ^= A.read(A.a_zpx()); A.set_zn(A.a); return 4
        if op == 0x4D: A.a ^= A.read(A.a_abs()); A.set_zn(A.a); return 4
        if op == 0x5D: A.a ^= A.read(A.a_abx()); A.set_zn(A.a); return 4
        if op == 0x59: A.a ^= A.read(A.a_aby()); A.set_zn(A.a); return 4
        if op == 0x41: A.a ^= A.read(A.a_indx()); A.set_zn(A.a); return 6
        if op == 0x51: A.a ^= A.read(A.a_indy()); A.set_zn(A.a); return 5
        # ---- compare
        if op == 0xC9: A.cmp_(A.a, A.read(A.a_imm())); return 2
        if op == 0xC5: A.cmp_(A.a, A.read(A.a_zp())); return 3
        if op == 0xD5: A.cmp_(A.a, A.read(A.a_zpx())); return 4
        if op == 0xCD: A.cmp_(A.a, A.read(A.a_abs())); return 4
        if op == 0xDD: A.cmp_(A.a, A.read(A.a_abx())); return 4
        if op == 0xD9: A.cmp_(A.a, A.read(A.a_aby())); return 4
        if op == 0xC1: A.cmp_(A.a, A.read(A.a_indx())); return 6
        if op == 0xD1: A.cmp_(A.a, A.read(A.a_indy())); return 5
        if op == 0xE0: A.cmp_(A.xr, A.read(A.a_imm())); return 2
        if op == 0xE4: A.cmp_(A.xr, A.read(A.a_zp())); return 3
        if op == 0xEC: A.cmp_(A.xr, A.read(A.a_abs())); return 4
        if op == 0xC0: A.cmp_(A.yr, A.read(A.a_imm())); return 2
        if op == 0xC4: A.cmp_(A.yr, A.read(A.a_zp())); return 3
        if op == 0xCC: A.cmp_(A.yr, A.read(A.a_abs())); return 4
        # ---- inc/dec
        if op == 0xE6: a = A.a_zp(); v = (A.read(a)+1)&0xFF; A.write(a,v); A.set_zn(v); return 5
        if op == 0xF6: a = A.a_zpx(); v = (A.read(a)+1)&0xFF; A.write(a,v); A.set_zn(v); return 6
        if op == 0xEE: a = A.a_abs(); v = (A.read(a)+1)&0xFF; A.write(a,v); A.set_zn(v); return 6
        if op == 0xFE: a = A.a_abx(); v = (A.read(a)+1)&0xFF; A.write(a,v); A.set_zn(v); return 7
        if op == 0xC6: a = A.a_zp(); v = (A.read(a)-1)&0xFF; A.write(a,v); A.set_zn(v); return 5
        if op == 0xD6: a = A.a_zpx(); v = (A.read(a)-1)&0xFF; A.write(a,v); A.set_zn(v); return 6
        if op == 0xCE: a = A.a_abs(); v = (A.read(a)-1)&0xFF; A.write(a,v); A.set_zn(v); return 6
        if op == 0xDE: a = A.a_abx(); v = (A.read(a)-1)&0xFF; A.write(a,v); A.set_zn(v); return 7
        if op == 0xE8: A.xr = (A.xr+1)&0xFF; A.set_zn(A.xr); return 2
        if op == 0xC8: A.yr = (A.yr+1)&0xFF; A.set_zn(A.yr); return 2
        if op == 0xCA: A.xr = (A.xr-1)&0xFF; A.set_zn(A.xr); return 2
        if op == 0x88: A.yr = (A.yr-1)&0xFF; A.set_zn(A.yr); return 2
        # ---- shifts
        if op == 0x0A: A.a = A.asl_val(A.a); return 2
        if op == 0x06: a=A.a_zp(); A.write(a, A.asl_val(A.read(a))); return 5
        if op == 0x16: a=A.a_zpx(); A.write(a, A.asl_val(A.read(a))); return 6
        if op == 0x0E: a=A.a_abs(); A.write(a, A.asl_val(A.read(a))); return 6
        if op == 0x1E: a=A.a_abx(); A.write(a, A.asl_val(A.read(a))); return 7
        if op == 0x4A: A.a = A.lsr_val(A.a); return 2
        if op == 0x46: a=A.a_zp(); A.write(a, A.lsr_val(A.read(a))); return 5
        if op == 0x56: a=A.a_zpx(); A.write(a, A.lsr_val(A.read(a))); return 6
        if op == 0x4E: a=A.a_abs(); A.write(a, A.lsr_val(A.read(a))); return 6
        if op == 0x5E: a=A.a_abx(); A.write(a, A.lsr_val(A.read(a))); return 7
        if op == 0x2A: A.a = A.rol_val(A.a); return 2
        if op == 0x26: a=A.a_zp(); A.write(a, A.rol_val(A.read(a))); return 5
        if op == 0x36: a=A.a_zpx(); A.write(a, A.rol_val(A.read(a))); return 6
        if op == 0x2E: a=A.a_abs(); A.write(a, A.rol_val(A.read(a))); return 6
        if op == 0x3E: a=A.a_abx(); A.write(a, A.rol_val(A.read(a))); return 7
        if op == 0x6A: A.a = A.ror_val(A.a); return 2
        if op == 0x66: a=A.a_zp(); A.write(a, A.ror_val(A.read(a))); return 5
        if op == 0x76: a=A.a_zpx(); A.write(a, A.ror_val(A.read(a))); return 6
        if op == 0x6E: a=A.a_abs(); A.write(a, A.ror_val(A.read(a))); return 6
        if op == 0x7E: a=A.a_abx(); A.write(a, A.ror_val(A.read(a))); return 7
        # ---- bit
        if op == 0x24:
            v = A.read(A.a_zp())
            A.p = (A.p & ~0xC2) | (v & 0xC0) | (0 if (v & A.a) else 2)
            return 3
        if op == 0x2C:
            v = A.read(A.a_abs())
            A.p = (A.p & ~0xC2) | (v & 0xC0) | (0 if (v & A.a) else 2)
            return 4
        # ---- jumps
        if op == 0x4C: A.pc = A.a_abs(); return 3
        if op == 0x6C:
            a = A.a_abs()
            lo = A.read(a)
            hi = A.read((a & 0xFF00) | ((a+1) & 0xFF))  # 6502 page-wrap bug
            A.pc = lo | (hi << 8)
            return 5
        if op == 0x20:
            a = A.a_abs()
            ret = (A.pc - 1) & 0xFFFF
            A.push(ret >> 8); A.push(ret & 0xFF)
            A.pc = a
            return 6
        if op == 0x60:
            lo = A.pop(); hi = A.pop()
            A.pc = ((hi << 8) | lo) + 1 & 0xFFFF
            return 6
        if op == 0x40:
            A.p = (A.pop() & ~0x10) | 0x20
            lo = A.pop(); hi = A.pop()
            A.pc = (hi << 8) | lo
            return 6
        if op == 0x00:
            ret = (A.pc + 1) & 0xFFFF
            A.push(ret >> 8); A.push(ret & 0xFF)
            A.push(A.p | 0x30)
            A.p |= 4
            A.pc = A.read16(0xFFFE)
            return 7
        # ---- branches
        if op == 0x10: return A.branch(not (A.p & 0x80))
        if op == 0x30: return A.branch(A.p & 0x80)
        if op == 0x50: return A.branch(not (A.p & 0x40))
        if op == 0x70: return A.branch(A.p & 0x40)
        if op == 0x90: return A.branch(not (A.p & 0x01))
        if op == 0xB0: return A.branch(A.p & 0x01)
        if op == 0xD0: return A.branch(not (A.p & 0x02))
        if op == 0xF0: return A.branch(A.p & 0x02)
        # ---- flags
        if op == 0x18: A.p &= ~0x01; return 2
        if op == 0x38: A.p |= 0x01; return 2
        if op == 0x58: A.p &= ~0x04; return 2
        if op == 0x78: A.p |= 0x04; return 2
        if op == 0xB8: A.p &= ~0x40; return 2
        if op == 0xD8: A.p &= ~0x08; return 2
        if op == 0xF8: A.p |= 0x08; return 2
        return None

    # ---------------------------------------------------------- frames -----
    def set_buttons(self, mask): self.buttons = mask

    def run_cycles(self, n):
        end = self.cycles + n
        while self.cycles < end:
            if self.pending_nmi:
                self.pending_nmi = False
                self.nmi_interrupt()
            self.step()

    def run_frame(self):
        self.in_vblank = False
        self.run_cycles(CYCLES_VISIBLE)
        # snapshot happens at vblank start (end of visible)
        self.in_vblank = True
        self.ppustatus |= 0x80
        # crude sprite0 hit: set with vblank if rendering on (we don't use it)
        if self.ppumask & 0x18: self.ppustatus |= 0x40
        if self.ppuctrl & 0x80:
            self.pending_nmi = True
        self.run_cycles(CYCLES_VBLANK)
        self.ppustatus &= 0x3F
        self.frame += 1

    # ---------------------------------------------------------- render -----
    def decode_chr(self):
        # (n_tiles, 8, 8) uint8 pixel values
        chrarr = np.frombuffer(bytes(self.chr), dtype=np.uint8)
        n = len(self.chr) // 16
        t = chrarr.reshape(n, 16)
        lo = np.unpackbits(t[:, :8], axis=1).reshape(n, 8, 8)
        hi = np.unpackbits(t[:, 8:], axis=1).reshape(n, 8, 8)
        return lo | (hi << 1)

    def render(self):
        """Render full frame (256x240 RGB) from current PPU state."""
        img = np.zeros((240, 256), dtype=np.uint8)  # palette indices 0-31
        tiles = self.decode_chr()
        bg_color = self.pal[0] & 0x3F
        if self.ppumask & 0x08:
            # background: build 2x2 nametable pixmap (512x480), then crop
            full = np.zeros((480, 512), dtype=np.uint8)
            pt_base = 256 if (self.ppuctrl & 0x10) else 0
            # effective chr offset for pattern table
            for nt in range(4):
                base = 0x2000 + nt*0x400
                ox = (nt & 1)*256; oy = (nt >> 1)*240
                names = np.array([self.vram[self.nt_addr(base + i)] for i in range(960)],
                                 dtype=np.int32).reshape(30, 32)
                attrs = np.array([self.vram[self.nt_addr(base + 960 + i)] for i in range(64)],
                                 dtype=np.uint8).reshape(8, 8)
                # per-tile palette from attrs
                pal_grid = np.zeros((30, 32), dtype=np.uint8)
                for ty in range(30):
                    for tx in range(32):
                        ab = attrs[ty >> 2, tx >> 2]
                        shift = ((ty >> 1) & 1)*4 + ((tx >> 1) & 1)*2
                        pal_grid[ty, tx] = (ab >> shift) & 3
                # map CHR through current banking: tile i at pattern addr
                # pt_base + name; chr_addr translates
                for ty in range(30):
                    row_names = names[ty]
                    for tx in range(32):
                        tid = row_names[tx] + pt_base
                        paddr = self.chr_addr(tid * 16)
                        px = tiles[paddr // 16]
                        out = np.where(px == 0, 0, pal_grid[ty, tx]*4 + px)
                        full[oy+ty*8:oy+ty*8+8, ox+tx*8:ox+tx*8+8] = out
            sx = ((self.t & 0x1F) << 3 | self.x) + ((self.t >> 10) & 1)*256
            sy = (((self.t >> 5) & 0x1F) << 3 | ((self.t >> 12) & 7)) + ((self.t >> 11) & 1)*240
            fullw = np.tile(full, (2, 2))
            img = fullw[sy:sy+240, sx:sx+256].copy()
            if not (self.ppumask & 0x02):
                img[:, :8] = 0
        # sprites
        if self.ppumask & 0x10:
            h16 = bool(self.ppuctrl & 0x20)
            height = 16 if h16 else 8
            for i in range(63, -1, -1):
                y = self.oam[i*4]
                if y >= 0xEF: continue
                tid = self.oam[i*4+1]; at = self.oam[i*4+2]; x = self.oam[i*4+3]
                pal_i = at & 3
                hflip = at & 0x40; vflip = at & 0x80
                if h16:
                    bank = (tid & 1)*256
                    tid0 = tid & 0xFE
                else:
                    bank = 256 if (self.ppuctrl & 0x08) else 0
                    tid0 = tid
                for half in range(height // 8):
                    t_id = tid0 + half + bank
                    paddr = self.chr_addr(t_id * 16)
                    px = tiles[paddr // 16].copy()
                    if hflip: px = px[:, ::-1]
                    if vflip: px = px[::-1, :]
                    yy = y + 1 + (half*8 if not vflip else (height-8-half*8))
                    for r in range(8):
                        sy_ = yy + r
                        if not (0 <= sy_ < 240): continue
                        for c in range(8):
                            sx_ = x + c
                            if not (0 <= sx_ < 256): continue
                            p = px[r, c]
                            if p: img[sy_, sx_] = 16 + pal_i*4 + p
        # palette lookup
        out = np.zeros((240, 256, 3), dtype=np.uint8)
        pal_rgb = np.array(NES_PALETTE, dtype=np.uint8)
        idx = np.zeros((240, 256), dtype=np.uint8)
        for v in range(32):
            if v % 4 == 0 and v != 0: continue
        # build color for each of the 32 palette slots
        slot_colors = np.zeros(32, dtype=np.uint8)
        for s in range(32):
            slot_colors[s] = (self.pal[s] & 0x3F) if s % 4 else bg_color
        out = pal_rgb[slot_colors[img]]
        return out

    def save_png(self, path, scale=2):
        from PIL import Image
        arr = self.render()
        im = Image.fromarray(arr, 'RGB')
        if scale > 1:
            im = im.resize((256*scale, 240*scale), Image.NEAREST)
        im.save(path)


def parse_input(spec):
    """'30:START,60-120:RIGHT+A' -> {frame: buttonmask}"""
    sched = {}
    if not spec: return sched
    for part in spec.split(','):
        part = part.strip()
        if not part: continue
        rng, btns = part.split(':')
        mask = 0
        for b in btns.split('+'):
            mask |= 1 << BUTTONS[b.strip().upper()]
        if '-' in rng:
            a, b = rng.split('-')
            for f in range(int(a), int(b)+1): sched[f] = sched.get(f, 0) | mask
        else:
            f = int(rng)
            sched[f] = sched.get(f, 0) | mask
    return sched


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom')
    ap.add_argument('--frames', type=int, default=60)
    ap.add_argument('--png', default=None)
    ap.add_argument('--png-at', default=None, help='60=a.png,120=b.png')
    ap.add_argument('--input', default=None)
    ap.add_argument('--scale', type=int, default=2)
    ap.add_argument('--quiet', action='store_true')
    args = ap.parse_args()

    nes = NES(args.rom)
    sched = parse_input(args.input)
    shots = {}
    if args.png_at:
        for part in args.png_at.split(','):
            f, p = part.split('=')
            shots[int(f)] = p
    for f in range(args.frames):
        nes.set_buttons(sched.get(f, 0))
        nes.run_frame()
        if f+1 in shots:
            nes.save_png(shots[f+1], args.scale)
            if not args.quiet: print(f"frame {f+1}: wrote {shots[f+1]}")
    if args.png:
        nes.save_png(args.png, args.scale)
        if not args.quiet: print(f"final frame {nes.frame}: wrote {args.png}")
    for w in nes.warnings[:20]:
        print("WARNING:", w)
    if len(nes.warnings) > 20:
        print(f"...and {len(nes.warnings)-20} more warnings")

if __name__ == '__main__':
    main()

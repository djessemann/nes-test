#!/usr/bin/env python3
"""Scripted end-to-end playtest: builds a small city and verifies the sim.

Usage: python3 tools/play_test.py [--shots DIR]
"""
import sys, os, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nesemu import NES, BUTTONS

A, B, SEL, START = 1 << 0, 1 << 1, 1 << 2, 1 << 3
UP, DOWN, LEFT, RIGHT = 1 << 4, 1 << 5, 1 << 6, 1 << 7

MAPW, MAPH = 64, 48

def load_labels(path):
    labels = {}
    with open(path) as f:
        for line in f:
            # "al 00XXXX .name"
            parts = line.split()
            if len(parts) == 3 and parts[0] == 'al':
                labels[parts[2].lstrip('.')] = int(parts[1], 16)
    return labels

class Driver:
    def __init__(self, rom, labels):
        self.nes = NES(rom)
        self.lab = labels
        self.tool = 1  # TL_ROAD after city_new

    def frames(self, n, buttons=0):
        for _ in range(n):
            self.nes.set_buttons(buttons)
            self.nes.run_frame()

    def tap(self, btn, hold=1, settle=1):
        self.frames(hold, btn)
        self.frames(settle, 0)

    def zp(self, name):
        return self.nes.ram[self.lab[name]]

    def zp16(self, name):
        return self.nes.ram[self.lab[name]] | (self.nes.ram[self.lab[name]+1] << 8)

    def ram(self, name):
        return self.nes.ram[self.lab[name]]

    def map0(self, x, y):
        return self.nes.wram[y*64 + x]

    def map1(self, x, y):
        return self.nes.wram[0xC00 + y*64 + x]

    def money(self):
        base = self.lab['money']
        return int(''.join(str(self.nes.ram[base+i]) for i in range(6)))

    def cursor(self):
        return self.zp('cur_x'), self.zp('cur_y')

    def state(self):
        return self.zp('game_state')

    def wait_state(self, st, limit=600):
        for _ in range(limit):
            if self.state() == st:
                return True
            self.frames(1)
        raise RuntimeError(f"state {st} not reached (now {self.state()})")

    def move_to(self, tx, ty):
        guard = 0
        while True:
            self.wait_state(1)
            x, y = self.cursor()
            if (x, y) == (tx, ty):
                return
            btn = 0
            if tx < x: btn = LEFT
            elif tx > x: btn = RIGHT
            elif ty < y: btn = UP
            elif ty > y: btn = DOWN
            self.tap(btn)
            guard += 1
            if guard > 400:
                raise RuntimeError(f"move_to stuck at {x},{y} -> {tx},{ty}")

    def select_tool(self, idx):
        self.wait_state(1)
        self.tap(B)                      # open menu
        # menu draws over ~30 frames then becomes interactive
        for _ in range(120):
            if self.state() == 3 and self.zp('state_sub') == 1:
                break
            self.frames(1)
        else:
            raise RuntimeError("menu never interactive")
        cur = self.zp('menu_sel')
        while cur != idx:
            self.tap(DOWN if idx > cur else UP)
            cur = self.zp('menu_sel')
        self.tap(A)
        self.wait_state(1)               # closes via redraw
        self.tool = idx

    def place(self):
        self.tap(A)

def find_clear(drv, w, h):
    for y in range(1, MAPH - h - 1):
        for x in range(1, MAPW - w - 1):
            if all(drv.map0(x+i, y+j) == 0 for j in range(h) for i in range(w)):
                return x, y
    raise RuntimeError("no clear region found")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--shots', default=None)
    ap.add_argument('--rom', default='micropolis.nes')
    ap.add_argument('--labels', default='labels.txt')
    args = ap.parse_args()

    drv = Driver(args.rom, load_labels(args.labels))
    shots = args.shots
    def shot(name):
        if shots:
            os.makedirs(shots, exist_ok=True)
            drv.nes.save_png(os.path.join(shots, name))
            print(f"  shot: {name}")

    print("== boot to title")
    drv.frames(40)
    print("== start new city")
    drv.tap(A)
    drv.wait_state(1)
    drv.frames(10)
    print(f"  money={drv.money()} state={drv.state()}")

    rx, ry = find_clear(drv, 11, 11)
    print(f"== clear region at {rx},{ry}")

    # layout (relative to rx,ry):
    # coal center (2,2); wire (2,4); res center (2,6); road row 8 cols 0..8
    # com center (6,6) -> road access but NO power (bolt expected)
    print("== build coal plant")
    drv.select_tool(11)                 # TL_COAL
    drv.move_to(rx+2, ry+2)
    drv.place()
    print(f"  money={drv.money()}")
    assert drv.map0(rx+2, ry+2) == 0x64, f"coal center missing: {drv.map0(rx+2,ry+2):02X}"

    print("== wire")
    drv.select_tool(2)                  # TL_WIRE
    drv.move_to(rx+2, ry+4)
    drv.place()
    assert drv.map0(rx+2, ry+4) == 0x08

    print("== res zone")
    drv.select_tool(5)                  # TL_RES
    drv.move_to(rx+2, ry+6)
    drv.place()
    assert drv.map0(rx+2, ry+6) == 0x14, f"res center: {drv.map0(rx+2,ry+6):02X}"

    print("== road row")
    drv.select_tool(1)                  # TL_ROAD
    drv.move_to(rx, ry+8)
    for i in range(9):
        drv.place()
        if i < 8:
            drv.tap(RIGHT)
    n_road = sum(1 for i in range(9) if drv.map0(rx+i, ry+8) == 0x06)
    print(f"  roads placed: {n_road}/9")

    print("== com zone (no power)")
    drv.select_tool(6)                  # TL_COM
    drv.move_to(rx+6, ry+6)
    drv.place()
    assert drv.map0(rx+6, ry+6) == 0x24, f"com center: {drv.map0(rx+6,ry+6):02X}"
    shot('city_built.png')

    print(f"  money after build: {drv.money()}")

    print("== run 2400 frames (~40s)")
    month0 = drv.zp('month')
    for chunk in range(8):
        drv.frames(300)
        res_aux = drv.map1(rx+2, ry+6)
        com_aux = drv.map1(rx+6, ry+6)
        print(f"  f+{(chunk+1)*300}: res aux={res_aux:02X} (pwr={res_aux>>7}, lvl={res_aux&3}) "
              f"com aux={com_aux:02X} month={drv.zp('month')} money={drv.money()} "
              f"bolts={drv.ram('bolt_n')} demand_r={drv.ram('demand_r')}")
    shot('city_grown.png')

    res_aux = drv.map1(rx+2, ry+6)
    com_aux = drv.map1(rx+6, ry+6)
    failures = []
    if not (res_aux & 0x80):
        failures.append("res zone not powered")
    if com_aux & 0x80:
        failures.append("com zone should be unpowered")
    if (res_aux & 3) < 1:
        failures.append("res zone never grew")
    if drv.zp('month') == month0:
        failures.append("date never advanced")
    if drv.ram('bolt_n') < 1:
        failures.append("no bolt for unpowered zone")
    for w in drv.nes.warnings[:10]:
        print("  PPU WARNING:", w)
    if failures:
        print("FAILURES:")
        for f in failures: print("  -", f)
        sys.exit(1)
    print("ALL CHECKS PASSED")

if __name__ == '__main__':
    main()

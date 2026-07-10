#!/usr/bin/env python3
"""Showcase run: full city with amenities, verifies max-density growth."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from play_test import Driver, load_labels, A, RIGHT

TL_ROAD, TL_WIRE, TL_RES, TL_COM, TL_IND = 1, 2, 5, 6, 7
TL_POL, TL_FIRE, TL_STAD, TL_COAL, TL_PORT, TL_AIRP = 8, 9, 10, 11, 13, 14

def main():
    shots = sys.argv[1] if len(sys.argv) > 1 else '/tmp'
    os.makedirs(shots, exist_ok=True)
    drv = Driver('micropolis.nes', load_labels('labels.txt'))
    nes, lab = drv.nes, drv.lab
    drv.frames(40)
    drv.tap(A)
    drv.wait_state(1)
    drv.frames(10)
    # showcase: clear a big region + deep pockets
    rx, ry = 22, 14
    for y in range(ry-1, ry+21):
        for x in range(rx-1, rx+16):
            nes.wram[y*64+x] = 0
    for i, d in enumerate([1,0,0,0,0,0]):
        nes.ram[lab['money']+i] = d
    nes.ram[lab['disaster_on']] = 0   # deterministic run

    def place_at(tool, x, y):
        if drv.tool != tool:
            drv.select_tool(tool)
        drv.move_to(rx + x, ry + y)
        drv.place()

    place_at(TL_COAL, 2, 2)
    place_at(TL_POL, 7, 2)
    place_at(TL_FIRE, 10, 2)
    drv.select_tool(TL_ROAD)
    for row in (5, 9, 13):
        drv.move_to(rx, ry + row)
        for i in range(14):
            drv.place()
            if i < 13: drv.tap(RIGHT)
    drv.select_tool(TL_WIRE)
    for x, y in ((4,2),(5,2),(2,4),(2,5),(12,6),(12,7),(12,8),(12,9),
                 (12,10),(12,11),(12,12),(12,13)):
        drv.move_to(rx + x, ry + y)
        drv.place()
    for x in (1, 4, 7, 10):
        place_at(TL_RES, x, 7)
    place_at(TL_COM, 1, 11)
    place_at(TL_COM, 4, 11)
    place_at(TL_IND, 7, 11)
    place_at(TL_IND, 10, 11)
    place_at(TL_STAD, 2, 16)
    place_at(TL_PORT, 6, 16)
    place_at(TL_AIRP, 10, 16)
    # wires to amenities: down from the zones above, across road row 13
    drv.select_tool(TL_WIRE)
    for x, y in ((2,13),(2,14),(6,13),(6,14),(10,13),(10,14)):
        drv.move_to(rx + x, ry + y)
        drv.place()
    print("built, money:", drv.money())
    nes.save_png(os.path.join(shots, 'show_built.png'))

    for chunk in range(40):
        drv.frames(300)
    rp = nes.ram[lab['res_pop']] | (nes.ram[lab['res_pop']+1] << 8)
    cp = nes.ram[lab['com_pop']] | (nes.ram[lab['com_pop']+1] << 8)
    ip = nes.ram[lab['ind_pop']] | (nes.ram[lab['ind_pop']+1] << 8)
    print(f"after ~7 years: R{rp} C{cp} I{ip} money {drv.money()} "
          f"has_flags {nes.ram[lab['has_flags']]:03b} unpowered {nes.ram[lab['unpowered_n']]}")
    # count level-3 zones
    l3 = 0
    for y in range(48):
        for x in range(64):
            c = nes.wram[y*64+x]
            if c in (0x14, 0x24, 0x34):
                lvl = nes.wram[0xC00+y*64+x] & 3
                if lvl == 3: l3 += 1
    print("level-3 zones:", l3)
    nes.save_png(os.path.join(shots, 'show_grown.png'))
    # move viewport for a nice framing shot of lower half
    drv.move_to(rx+6, ry+18)
    drv.frames(40)
    nes.save_png(os.path.join(shots, 'show_south.png'))
    if rp < 10 or nes.ram[lab['has_flags']] != 7 or l3 == 0:
        print("SHOWCASE CHECKS FAILED")
        sys.exit(1)
    print("SHOWCASE OK")

if __name__ == '__main__':
    main()

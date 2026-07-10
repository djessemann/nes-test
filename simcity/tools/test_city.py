#!/usr/bin/env python3
"""Big-city integration test: builds a full town, runs ~5 game years."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from play_test import Driver, load_labels, find_clear, A, B, UP, DOWN, LEFT, RIGHT

TL_BULL, TL_ROAD, TL_WIRE, TL_RAIL, TL_PARK = 0, 1, 2, 3, 4
TL_RES, TL_COM, TL_IND, TL_POL, TL_FIRE = 5, 6, 7, 8, 9
TL_STAD, TL_COAL, TL_NUKE, TL_PORT, TL_AIRP = 10, 11, 12, 13, 14

def main():
    shots = sys.argv[1] if len(sys.argv) > 1 else None
    drv = Driver('micropolis.nes', load_labels('labels.txt'))
    nes = drv.nes
    print("== boot + new city")
    drv.frames(40)
    drv.tap(A)
    drv.wait_state(1)
    drv.frames(10)

    try:
        rx, ry = find_clear(drv, 14, 18)
        stadium = True
    except RuntimeError:
        rx, ry = find_clear(drv, 14, 14)
        stadium = False
    print(f"== region {rx},{ry} stadium={stadium}")

    def place_at(tool, x, y):
        if drv.tool != tool:
            drv.select_tool(tool)
        drv.move_to(rx + x, ry + y)
        drv.place()

    print("== power plant + services")
    place_at(TL_COAL, 2, 2)
    place_at(TL_POL, 7, 2)
    place_at(TL_FIRE, 10, 2)
    print("== roads")
    drv.select_tool(TL_ROAD)
    drv.move_to(rx, ry + 5)
    for i in range(14):
        drv.place()
        if i < 13: drv.tap(RIGHT)
    drv.move_to(rx, ry + 9)
    for i in range(14):
        drv.place()
        if i < 13: drv.tap(RIGHT)
    print("== wires")
    drv.select_tool(TL_WIRE)
    for x, y in ((4,2),(5,2),(2,4),(2,5),(12,6),(12,7),(12,8),(12,9),(12,10),(12,11)):
        drv.move_to(rx + x, ry + y)
        drv.place()
    print("== zones")
    for x in (1, 4, 7, 10):
        place_at(TL_RES, x, 7)
    place_at(TL_COM, 1, 11)
    place_at(TL_COM, 4, 11)
    place_at(TL_IND, 7, 11)
    place_at(TL_IND, 10, 11)
    if stadium:
        drv.select_tool(TL_WIRE)
        drv.move_to(rx + 2, ry + 13)
        drv.place()
        place_at(TL_STAD, 2, 15)
    print(f"  money after build: {drv.money()}")
    if shots:
        os.makedirs(shots, exist_ok=True)
        drv.nes.save_png(os.path.join(shots, 'big_built.png'))

    print("== run 5 game years")
    lab = drv.lab
    signed = lambda v: v - 256 if v > 127 else v
    for chunk in range(30):
        drv.frames(300)
        if chunk % 5 == 4:
            print(f"  f+{(chunk+1)*300}: money={drv.money()} "
                  f"pops R{nes.ram[lab['res_pop']] | (nes.ram[lab['res_pop']+1]<<8)} "
                  f"C{nes.ram[lab['com_pop']] | (nes.ram[lab['com_pop']+1]<<8)} "
                  f"I{nes.ram[lab['ind_pop']] | (nes.ram[lab['ind_pop']+1]<<8)} "
                  f"dem {signed(nes.ram[lab['demand_r']])}/{signed(nes.ram[lab['demand_c']])}/{signed(nes.ram[lab['demand_i']])} "
                  f"pow {nes.ram[lab['powered_n']]}/{nes.ram[lab['powered_n']]+nes.ram[lab['unpowered_n']]} "
                  f"month {nes.ram[lab['month']]} yr {nes.ram[lab['year']]:02X}{nes.ram[lab['year']+1]:02X} "
                  f"msg {nes.ram[lab['msg_cur']]}")
    if shots:
        drv.nes.save_png(os.path.join(shots, 'big_grown.png'))

    rp = nes.ram[lab['res_pop']] | (nes.ram[lab['res_pop']+1] << 8)
    failures = []
    if rp < 6: failures.append(f"res pop too low: {rp}")
    if nes.ram[lab['unpowered_n']] > 0: failures.append("zones unpowered")
    for w in drv.nes.warnings[:8]:
        print("  PPU WARNING:", w)
    if drv.nes.warnings: failures.append("PPU timing warnings")
    if failures:
        print("FAILURES:", failures)
        sys.exit(1)
    print("ALL CHECKS PASSED")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Water-crossing test: wires + rail bridges over rivers, power across."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from play_test import Driver, load_labels, A, RIGHT

def main():
    lab = load_labels('labels.txt')
    drv = Driver('micropolis.nes', lab)
    nes = drv.nes
    drv.frames(40); drv.tap(A); drv.wait_state(1); drv.frames(5)

    rx, ry = 20, 20
    for y in range(ry-2, ry+7):
        for x in range(rx-2, rx+14):
            nes.wram[y*64+x] = 0
    for y in range(ry-2, ry+7):
        for x in (rx+5, rx+6, rx+7):
            nes.wram[y*64+x] = 2  # river

    drv.select_tool(11)                    # coal, west bank
    drv.move_to(rx+2, ry+2); drv.place()
    drv.select_tool(2)                     # wire across the river
    drv.move_to(rx+4, ry+2)
    for i in range(5):
        drv.place()
        if i < 4: drv.tap(RIGHT)
    codes = [drv.map0(rx+4+i, ry+2) for i in range(5)]
    assert codes == [0x08, 0x0B, 0x0B, 0x0B, 0x08], codes
    drv.select_tool(5)                     # res zone, east bank
    drv.move_to(rx+10, ry+2); drv.place()
    drv.select_tool(1)                     # road access
    drv.move_to(rx+9, ry+4)
    for i in range(4):
        drv.place()
        if i < 3: drv.tap(RIGHT)
    drv.frames(600)
    aux = drv.map1(rx+10, ry+2)
    assert aux & 0x80, f"zone not powered across water (aux={aux:02X})"

    drv.select_tool(3)                     # rail bridge
    drv.move_to(rx+4, ry+5)
    for i in range(5):
        drv.place()
        if i < 4: drv.tap(RIGHT)
    codes = [drv.map0(rx+4+i, ry+5) for i in range(5)]
    assert codes == [0x07, 0x0C, 0x0C, 0x0C, 0x07], codes

    drv.select_tool(0)                     # dozer reverts to water
    drv.move_to(rx+6, ry+5); drv.place()
    assert drv.map0(rx+6, ry+5) == 0x02
    assert not nes.warnings, nes.warnings
    print("BRIDGE TESTS PASSED")

if __name__ == '__main__':
    main()

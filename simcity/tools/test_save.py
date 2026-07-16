#!/usr/bin/env python3
"""Battery-save test: build, 'power-cycle' (carry WRAM over), CONTINUE."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from play_test import Driver, load_labels, find_clear, A, B, DOWN, RIGHT

def main():
    lab = load_labels('labels.txt')
    drv = Driver('micropolis.nes', lab)
    drv.frames(40)
    drv.tap(A)
    drv.wait_state(1)
    drv.frames(10)
    rx, ry = find_clear(drv, 5, 5)
    drv.select_tool(11)              # coal plant
    drv.move_to(rx+2, ry+2)
    drv.place()
    money_before = drv.money()
    # open + close the report to force a save
    drv.tap(8)                       # START
    for _ in range(120):
        if drv.state() == 4 and drv.zp('state_sub') == 1: break
        drv.frames(1)
    drv.tap(8)
    drv.wait_state(1)
    map_before = bytes(drv.nes.wram[:3072])

    # power cycle: fresh console, same battery WRAM
    drv2 = Driver('micropolis.nes', lab)
    drv2.nes.wram = bytearray(drv.nes.wram)
    drv2.frames(40)
    # CONTINUE should be selectable now
    drv2.tap(DOWN)
    if drv2.zp('menu_sel') != 1:
        print("FAIL: CONTINUE not selectable"); sys.exit(1)
    drv2.tap(A)
    drv2.wait_state(1)
    drv2.frames(10)
    ok = True
    if drv2.money() != money_before:
        print(f"FAIL: money {drv2.money()} != {money_before}"); ok = False
    if bytes(drv2.nes.wram[:3072]) != map_before:
        print("FAIL: map changed"); ok = False
    if drv2.map0(rx+2, ry+2) != 0x64:
        print("FAIL: coal plant missing after load"); ok = False
    # liveness: the game must actually RUN after CONTINUE, not just load
    f0 = drv2.zp('frame_ctr')
    x0 = drv2.zp('cur_x')
    drv2.tap(RIGHT)
    drv2.frames(30)
    if drv2.zp('frame_ctr') == f0:
        print("FAIL: frame counter frozen after CONTINUE"); ok = False
    if drv2.zp('cur_x') == x0:
        print("FAIL: cursor unresponsive after CONTINUE"); ok = False
    if drv2.zp('ppuctrl_sh') & 0x80 == 0:
        print("FAIL: NMI disabled (ppuctrl_sh corrupted)"); ok = False
    m0 = drv2.zp('month')
    drv2.frames(400)
    if drv2.zp('month') == m0:
        print("FAIL: simulation not advancing after CONTINUE"); ok = False
    if ok:
        print(f"SAVE/CONTINUE OK (money={drv2.money()}, plant intact, "
              f"sim alive, cursor responsive)")
    else:
        import sys
        sys.exit(1)

if __name__ == '__main__':
    main()

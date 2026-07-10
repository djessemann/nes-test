#!/usr/bin/env python3
"""Render all cell graphics + sprites to a contact sheet PNG for review."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
import gfx
import gfx_tiles
from nesemu import NES_PALETTE

UNIVERSAL = 0x1A  # grass green
PALETTES = [
    [UNIVERSAL, 0x0A, 0x17, 0x2A],  # terrain
    [UNIVERSAL, 0x01, 0x11, 0x2C],  # water
    [UNIVERSAL, 0x0F, 0x10, 0x30],  # gray
    [UNIVERSAL, 0x07, 0x16, 0x27],  # warm
]
SPR_PAL = [0x1A, 0x0F, 0x10, 0x30]

def tile_pixels(data):
    px = np.zeros((8, 8), dtype=np.uint8)
    for y in range(8):
        lo, hi = data[y], data[y+8]
        for x in range(8):
            px[y, x] = ((lo >> (7-x)) & 1) | (((hi >> (7-x)) & 1) << 1)
    return px

def main():
    cells = gfx.CellSet(gfx.BG)
    gfx_tiles.build(gfx.BG, gfx.SPR, cells)
    n = len(cells.cells)
    cols = 12
    rows = (n + cols - 1) // cols
    img = np.zeros((rows*20, cols*20, 3), dtype=np.uint8)
    img[:, :] = (40, 40, 40)
    for i, (name, tl, tr, bl, br, pal) in enumerate(cells.cells):
        cy, cx = (i // cols)*20, (i % cols)*20
        for qi, tid in enumerate((tl, tr, bl, br)):
            px = tile_pixels(gfx.BG.tiles[tid] or bytes(16))
            oy = cy + 2 + (qi // 2)*8
            ox = cx + 2 + (qi % 2)*8
            for y in range(8):
                for x in range(8):
                    img[oy+y, ox+x] = NES_PALETTE[PALETTES[pal][px[y, x]] & 0x3F]
    im = Image.fromarray(img, 'RGB').resize((cols*20*3, rows*20*3), Image.NEAREST)
    im.save(sys.argv[1] if len(sys.argv) > 1 else 'cells.png')
    # sprite sheet
    spr_used = [i for i in range(256) if gfx.SPR.tiles[i]]
    simg = np.zeros((20, max(1,len(spr_used))*12, 3), dtype=np.uint8)
    simg[:, :] = (40, 40, 40)
    for j, i in enumerate(spr_used):
        px = tile_pixels(gfx.SPR.tiles[i])
        for y in range(8):
            for x in range(8):
                simg[6+y, j*12+2+x] = NES_PALETTE[SPR_PAL[px[y, x]] & 0x3F]
    Image.fromarray(simg, 'RGB').resize((simg.shape[1]*3, 60), Image.NEAREST).save(
        (sys.argv[1] if len(sys.argv) > 1 else 'cells.png').replace('.png', '_spr.png'))
    print(f"cells: {n}, BG tiles used: {gfx.BG.used()}/256, SPR: {gfx.SPR.used()}/256")

if __name__ == '__main__':
    main()

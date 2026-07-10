#!/usr/bin/env python3
"""CHR graphics compiler for Micropolis NES.

Generates chr.bin (8KB: 256 BG tiles + 256 sprite tiles) and src/tiles.inc
(ca65 constants for tile indices).

Tiles are authored as 8-line ASCII art, chars '.','1','2','3' = color 0-3.
"""
import sys, os

OUT_INC = os.path.join(os.path.dirname(__file__), '..', 'src', 'tiles.inc')

def tile_bytes(art):
    rows = [r for r in art.strip('\n').split('\n')]
    assert len(rows) == 8, f"tile needs 8 rows, got {len(rows)}:\n{art}"
    lo = bytearray(); hi = bytearray()
    for r in rows:
        r = r.ljust(8, '.')
        assert len(r) == 8, f"row too long: {r!r}"
        l = h = 0
        for ch in r:
            c = {'.': 0, '1': 1, '2': 2, '3': 3}[ch]
            l = (l << 1) | (c & 1)
            h = (h << 1) | (c >> 1)
        lo.append(l); hi.append(h)
    return bytes(lo + hi)

class Page:
    def __init__(self, name):
        self.name = name
        self.tiles = [None] * 256
        self.tiles[0] = bytes(16)  # tile 0 reserved: blank
        self.names = {}
        self.cursor = 0
        self.dedup = {bytes(16): 0}
    def put(self, idx, art, name=None):
        assert self.tiles[idx] is None, f"{self.name} tile ${idx:02X} already used"
        b = tile_bytes(art) if isinstance(art, str) else art
        self.tiles[idx] = b
        self.dedup.setdefault(b, idx)
        if name: self.names[name] = idx
        return idx
    def add(self, art, name=None):
        b = tile_bytes(art) if isinstance(art, str) else art
        if name is None and b in self.dedup:
            return self.dedup[b]
        while self.cursor < 256 and self.tiles[self.cursor] is not None:
            self.cursor += 1
        assert self.cursor < 256, f"{self.name} page full!"
        return self.put(self.cursor, b, name)
    def data(self):
        blank = bytes(16)
        return b''.join(t if t else blank for t in self.tiles)
    def used(self):
        return sum(1 for t in self.tiles if t is not None)

class CellSet:
    """16x16 map-cell graphics: 2x2 BG tiles + a palette each."""
    def __init__(self, page):
        self.page = page
        self.cells = []       # (name, tl, tr, bl, br, pal)
        self.names = {}
        self.blocks = {}      # name -> list of 9 cell ids (3x3 buildings)
        self.dedup = {}
    def add(self, name, art16, pal):
        rows = [r.ljust(16, '.')[:16] for r in art16.strip('\n').split('\n')]
        assert len(rows) <= 16, f"cell {name}: too many rows ({len(rows)})"
        while len(rows) < 16:
            rows.append('.' * 16)
        quads = []
        for qy in range(2):
            for qx in range(2):
                t = '\n'.join(rows[qy*8+y][qx*8:qx*8+8] for y in range(8))
                quads.append(self.page.add(t))
        key = (tuple(quads), pal)
        if key in self.dedup and name is None:
            return self.dedup[key]
        cid = len(self.cells)
        assert cid < 256, "too many cell graphics"
        self.cells.append((name or f"anon{cid}", *quads, pal))
        self.dedup.setdefault(key, cid)
        if name: self.names[name] = cid
        return cid
    def add_block(self, name, art48, pal):
        """48x48 art -> 9 cells; pal may be scalar or list of 9."""
        rows = [r.ljust(48, '.') for r in art48.strip('\n').split('\n')]
        assert len(rows) == 48, f"block {name}: needs 48 rows, got {len(rows)}"
        ids = []
        for cy in range(3):
            for cx in range(3):
                art = '\n'.join(rows[cy*16+y][cx*16:cx*16+16] for y in range(16))
                p = pal[cy*3+cx] if isinstance(pal, (list, tuple)) else pal
                ids.append(self.add(None, art, p))
        self.blocks[name] = ids
        return ids

CELLS = None  # set in main

BG = Page('BG')
SPR = Page('SPR')

# ---------------------------------------------------------------- font ------
# 8x8 font, drawn in color 3. Tile 0 = blank (space).
FONT = {
'0': """
.333333.
33....33
33...333
33.33.33
333...33
33....33
.333333.
........""",
'1': """
...33...
..333...
...33...
...33...
...33...
...33...
.333333.
........""",
'2': """
.333333.
33....33
......33
....333.
..333...
.33.....
33333333
........""",
'3': """
.333333.
33....33
......33
...3333.
......33
33....33
.333333.
........""",
'4': """
....333.
...3333.
..33.33.
.33..33.
33333333
.....33.
.....33.
........""",
'5': """
33333333
33......
3333333.
......33
......33
33....33
.333333.
........""",
'6': """
.333333.
33......
33......
3333333.
33....33
33....33
.333333.
........""",
'7': """
33333333
......33
.....33.
....33..
...33...
...33...
...33...
........""",
'8': """
.333333.
33....33
33....33
.333333.
33....33
33....33
.333333.
........""",
'9': """
.333333.
33....33
33....33
.3333333
......33
......33
.333333.
........""",
'A': """
..3333..
.33..33.
33....33
33....33
33333333
33....33
33....33
........""",
'B': """
3333333.
33....33
33....33
3333333.
33....33
33....33
3333333.
........""",
'C': """
.333333.
33....33
33......
33......
33......
33....33
.333333.
........""",
'D': """
333333..
33...33.
33....33
33....33
33....33
33...33.
333333..
........""",
'E': """
33333333
33......
33......
333333..
33......
33......
33333333
........""",
'F': """
33333333
33......
33......
333333..
33......
33......
33......
........""",
'G': """
.333333.
33....33
33......
33..3333
33....33
33....33
.333333.
........""",
'H': """
33....33
33....33
33....33
33333333
33....33
33....33
33....33
........""",
'I': """
.333333.
...33...
...33...
...33...
...33...
...33...
.333333.
........""",
'J': """
..333333
.....33.
.....33.
.....33.
.....33.
33...33.
.3333...
........""",
'K': """
33....33
33...33.
33..33..
3333....
33..33..
33...33.
33....33
........""",
'L': """
33......
33......
33......
33......
33......
33......
33333333
........""",
'M': """
33....33
333..333
33333333
33.33.33
33....33
33....33
33....33
........""",
'N': """
33....33
333...33
3333..33
33.33.33
33..3333
33...333
33....33
........""",
'O': """
.333333.
33....33
33....33
33....33
33....33
33....33
.333333.
........""",
'P': """
3333333.
33....33
33....33
3333333.
33......
33......
33......
........""",
'Q': """
.333333.
33....33
33....33
33....33
33.33.33
33..333.
.33333.3
........""",
'R': """
3333333.
33....33
33....33
3333333.
33..33..
33...33.
33....33
........""",
'S': """
.3333333
33......
33......
.333333.
......33
......33
3333333.
........""",
'T': """
33333333
...33...
...33...
...33...
...33...
...33...
...33...
........""",
'U': """
33....33
33....33
33....33
33....33
33....33
33....33
.333333.
........""",
'V': """
33....33
33....33
33....33
33....33
.33..33.
..3333..
...33...
........""",
'W': """
33....33
33....33
33....33
33.33.33
33333333
333..333
33....33
........""",
'X': """
33....33
.33..33.
..3333..
...33...
..3333..
.33..33.
33....33
........""",
'Y': """
33....33
33....33
.33..33.
..3333..
...33...
...33...
...33...
........""",
'Z': """
33333333
.....33.
....33..
...33...
..33....
.33.....
33333333
........""",
'$': """
...33...
.3333333
33.33...
.333333.
...33.33
3333333.
...33...
........""",
'.': """
........
........
........
........
........
..33....
..33....
........""",
',': """
........
........
........
........
...33...
...33...
..33....
........""",
'-': """
........
........
........
.333333.
........
........
........
........""",
':': """
........
...33...
...33...
........
...33...
...33...
........
........""",
'/': """
......33
.....33.
....33..
...33...
..33....
.33.....
33......
........""",
'%': """
.33....3
.33...33
.....33.
....33..
...33...
..33..33
.33...33
........""",
'!': """
...33...
...33...
...33...
...33...
...33...
........
...33...
........""",
'?': """
.333333.
33....33
.....33.
....33..
...33...
........
...33...
........""",
"'": """
...33...
...33...
..33....
........
........
........
........
........""",
'(': """
....33..
...33...
..33....
..33....
..33....
...33...
....33..
........""",
')': """
..33....
...33...
....33..
....33..
....33..
...33...
..33....
........""",
}

# Font layout: space=$00, '0'-'9'=$01-$0A, 'A'-'Z'=$0B-$24, symbols after.
FONT_ORDER = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$.,-:/%!?'()"

def build_font():
    idx = 1
    mapping = {' ': 0}
    for ch in FONT_ORDER:
        BG.put(idx, FONT[ch])
        mapping[ch] = idx
        idx += 1
    return mapping

FONT_MAP = build_font()

# ---------------------------------------------------------- main ------------

def bytes_line(vals):
    return '.byte ' + ','.join(f'${v:02X}' for v in vals)

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'chr.bin'
    cells = CellSet(BG)
    import gfx_tiles  # terrain/buildings/sprites, registers into BG/SPR
    extra = gfx_tiles.build(BG, SPR, cells)
    with open(out, 'wb') as f:
        f.write(BG.data())
        f.write(SPR.data())

    # ---- tiles.inc: constants + charmap
    lines = ['; AUTO-GENERATED by tools/gfx.py -- do not edit', '']
    lines.append('.macro FONTMAP')
    for ch, idx in sorted(FONT_MAP.items(), key=lambda kv: kv[1]):
        lines.append(f".charmap {ord(ch)}, {idx}")
    lines.append('.endmacro')
    lines.append('')
    for name, idx in sorted(BG.names.items()):
        lines.append(f"T_{name} = ${idx:02X}")
    lines.append('')
    for name, idx in sorted(SPR.names.items()):
        lines.append(f"S_{name} = ${idx:02X}")
    lines.append('')
    for name, cid in sorted(cells.names.items()):
        lines.append(f"CG_{name} = ${cid:02X}")
    lines.append(f"CELLGFX_COUNT = {len(cells.cells)}")
    lines.append('')
    with open(OUT_INC, 'w') as f:
        f.write('\n'.join(lines))

    # ---- cellgfx.inc: data tables (include inside RODATA)
    lines = ['; AUTO-GENERATED by tools/gfx.py -- do not edit', '']
    for ti, tname in enumerate(['tl', 'tr', 'bl', 'br']):
        lines.append(f'cg_{tname}:')
        vals = [c[1+ti] for c in cells.cells]
        for i in range(0, len(vals), 16):
            lines.append(bytes_line(vals[i:i+16]))
    lines.append('cg_at:')
    vals = [c[5] for c in cells.cells]
    for i in range(0, len(vals), 16):
        lines.append(bytes_line(vals[i:i+16]))
    for name, ids in sorted(cells.blocks.items()):
        lines.append(f'blk_{name}:')
        lines.append(bytes_line(ids))
    if extra:
        lines.extend(extra)
    lines.append('')
    with open(os.path.join(os.path.dirname(__file__), '..', 'src', 'cellgfx.inc'), 'w') as f:
        f.write('\n'.join(lines))
    print(f"chr.bin: BG {BG.used()}/256 tiles, SPR {SPR.used()}/256, "
          f"cells {len(cells.cells)}/256")

if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    main()

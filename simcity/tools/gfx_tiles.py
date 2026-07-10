"""Terrain, building and sprite tile art for Micropolis NES.

Palettes (universal bg color = grass green):
  P0 terrain:  1=dark green  2=brown      3=light green
  P1 water:    1=dark blue   2=blue       3=light cyan
  P2 gray:     1=black       2=gray       3=white
  P3 warm:     1=dark brown  2=red        3=yellow
"""

P_TERRAIN, P_WATER, P_GRAY, P_WARM = 0, 1, 2, 3

N, E, S, W = 1, 2, 4, 8   # road/rail/wire connection mask bits


class C:
    """Simple character canvas for drawing cells programmatically."""
    def __init__(self, w=16, h=16, fill='.'):
        self.w, self.h = w, h
        self.g = [[fill]*w for _ in range(h)]
    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = c
    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return None
    def rect(self, x, y, w, h, fill=None, outline=None):
        for yy in range(y, y+h):
            for xx in range(x, x+w):
                edge = (yy in (y, y+h-1) or xx in (x, x+w-1))
                c = outline if (edge and outline) else fill
                if c: self.px(xx, yy, c)
    def hline(self, x0, x1, y, c, dash=0):
        for x in range(x0, x1+1):
            if dash and (x % (dash*2)) >= dash: continue
            self.px(x, y, c)
    def vline(self, x, y0, y1, c, dash=0):
        for y in range(y0, y1+1):
            if dash and (y % (dash*2)) >= dash: continue
            self.px(x, y, c)
    def windows(self, x0, y0, x1, y1, wx=2, wy=2, gx=2, gy=2, c='3'):
        y = y0
        while y + wy <= y1 + 1:
            x = x0
            while x + wx <= x1 + 1:
                for yy in range(wy):
                    for xx in range(wx):
                        self.px(x+xx, y+yy, c)
                x += wx + gx
            y += wy + gy
    def outline_where(self, target, edge_c):
        """Draw edge_c on target pixels adjacent to non-target."""
        snap = [row[:] for row in self.g]
        for y in range(self.h):
            for x in range(self.w):
                if snap[y][x] != target: continue
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < self.w and 0 <= ny < self.h:
                        if snap[ny][nx] == '.':
                            self.g[y][x] = edge_c
                            break
    def art(self):
        return '\n'.join(''.join(r) for r in self.g)


# ------------------------------------------------------------ networks -----

def road_cell(mask):
    c = C()
    if mask == 0:
        c.rect(4, 4, 8, 8, fill='2')
    else:
        c.rect(4, 4, 8, 8, fill='2')
        if mask & N: c.rect(4, 0, 8, 8, fill='2')
        if mask & S: c.rect(4, 8, 8, 8, fill='2')
        if mask & W: c.rect(0, 4, 8, 8, fill='2')
        if mask & E: c.rect(8, 4, 8, 8, fill='2')
    c.outline_where('2', '1')
    # center dashes on straights
    if mask == (E | W):
        c.hline(0, 15, 7, '3', dash=2)
        c.hline(0, 15, 8, '3', dash=2)
    elif mask == (N | S):
        c.vline(7, 0, 15, '3', dash=2)
        c.vline(8, 0, 15, '3', dash=2)
    return c.art()

def rail_cell(mask):
    c = C()
    # gravel bed, same symmetric band geometry as roads (cols/rows 4..11)
    c.rect(4, 4, 8, 8, fill='2')
    if mask & N: c.rect(4, 0, 8, 8, fill='2')
    if mask & S: c.rect(4, 8, 8, 8, fill='2')
    if mask & W: c.rect(0, 4, 8, 8, fill='2')
    if mask & E: c.rect(8, 4, 8, 8, fill='2')
    # ties (white) then rails (black) along each arm
    if mask & (E | W):
        x0 = 0 if mask & W else 4
        x1 = 15 if mask & E else 11
        for x in range(x0, x1+1):
            if x % 4 < 2:
                c.vline(x, 5, 10, '3')
        c.hline(x0, x1, 5, '1')
        c.hline(x0, x1, 10, '1')
    if mask & (N | S):
        y0 = 0 if mask & N else 4
        y1 = 15 if mask & S else 11
        for y in range(y0, y1+1):
            if y % 4 < 2:
                c.hline(5, 10, y, '3')
        c.vline(5, y0, y1, '1')
        c.vline(10, y0, y1, '1')
    if mask == 0:
        c.hline(4, 11, 5, '1')
        c.hline(4, 11, 10, '1')
    return c.art()

def wire_cell(mask):
    c = C()
    # wire lines
    if mask & N: c.vline(7, 0, 7, '1'); c.vline(8, 0, 7, '1')
    if mask & S: c.vline(7, 8, 15, '1'); c.vline(8, 8, 15, '1')
    if mask & W: c.hline(0, 7, 7, '1'); c.hline(0, 7, 8, '1')
    if mask & E: c.hline(8, 15, 7, '1'); c.hline(8, 15, 8, '1')
    # pole: small pylon at center
    c.rect(6, 5, 4, 6, fill='1')
    c.px(5, 5, '3'); c.px(10, 5, '3')     # insulators
    c.px(6, 4, '2'); c.px(9, 4, '2')
    return c.art()

def roadwire_cell(road_horiz):
    art = road_cell(E | W if road_horiz else N | S)
    c = C()
    c.g = [list(r) for r in art.split('\n')]
    if road_horiz:
        c.vline(7, 0, 15, '1'); c.vline(8, 0, 15, '1')
    else:
        c.hline(0, 15, 7, '1'); c.hline(0, 15, 8, '1')
    return c.art()

def railroad_cross(road_horiz):
    # road with rail crossing it
    art = road_cell(E | W if road_horiz else N | S)
    c = C()
    c.g = [list(r) for r in art.split('\n')]
    if road_horiz:
        c.vline(6, 0, 15, '1'); c.vline(9, 0, 15, '1')
        for y in range(0, 16):
            if y % 4 < 2:
                c.hline(6, 9, y, '3')
        c.vline(6, 0, 15, '1'); c.vline(9, 0, 15, '1')
    else:
        c.hline(0, 15, 6, '1'); c.hline(0, 15, 9, '1')
        for x in range(0, 16):
            if x % 4 < 2:
                c.vline(x, 6, 9, '3')
        c.hline(0, 15, 6, '1'); c.hline(0, 15, 9, '1')
    return c.art()

# ------------------------------------------------------------ zones --------

def zone_edge_cell(pos, col='2'):
    """Empty-zone periphery cell: grass with dashed border facing outward."""
    c = C()
    top    = pos in (0, 1, 2)
    bottom = pos in (6, 7, 8)
    left   = pos in (0, 3, 6)
    right  = pos in (2, 5, 8)
    if top:    c.hline(0, 15, 0, col, dash=2)
    if bottom: c.hline(0, 15, 15, col, dash=2)
    if left:   c.vline(0, 0, 15, col, dash=2)
    if right:  c.vline(15, 0, 15, col, dash=2)
    return c.art()

def sign_cell(letter):
    """Zone sign: white board with a dark letter, on a post."""
    c = C()
    c.rect(2, 2, 12, 11, fill='3', outline='1')
    c.vline(7, 13, 15, '1'); c.vline(8, 13, 15, '1')
    x, y = 5, 4          # letter box origin, 6x7
    if letter == 'R':
        c.vline(x, y, y+6, '1')
        c.hline(x, x+4, y, '1')
        c.vline(x+4, y, y+2, '1')
        c.hline(x, x+4, y+3, '1')
        c.px(x+2, y+4, '1'); c.px(x+3, y+5, '1'); c.px(x+4, y+6, '1')
    elif letter == 'C':
        c.hline(x+1, x+4, y, '1')
        c.px(x+4, y+1, '1')
        c.vline(x, y+1, y+5, '1')
        c.px(x+4, y+5, '1')
        c.hline(x+1, x+4, y+6, '1')
    elif letter == 'I':
        c.hline(x, x+4, y, '1')
        c.hline(x, x+4, y+6, '1')
        c.vline(x+2, y, y+6, '1')
    return c.art()

SIGN_R = """
................
................
....11111111....
...1333333331...
...1322222231...
...1323232231...
...1322232231...
...1323223231...
...1323232231...
...1333333331...
....11111111....
.......11.......
.......11.......
.......11.......
................
................"""

SIGN_C = """
................
................
....11111111....
...1333333331...
...1322222231...
...1323333231...
...1322333331...
...1322333331...
...1323333231...
...1322222231...
...1333333331...
....11111111....
.......11.......
.......11.......
................
................"""

SIGN_I = """
................
................
....11111111....
...1333333331...
...1322222231...
...1333223331...
...1333223331...
...1333223331...
...1333223331...
...1322222231...
...1333333331...
....11111111....
.......11.......
.......11.......
................
................"""

HOUSE_A = """
................
......1111......
....11222211....
...1222222221...
..122222222221..
.12222222222221.
.11111111111111.
.13333333333331.
.13113333311331.
.13113333311331.
.13333333333331.
.13333311333331.
.13333311333331.
.11111111111111.
................
................"""

HOUSE_B = """
................
................
...1111111111...
..122222222221..
.12222222222221.
.11111111111111.
.13333333333331.
.13133133133131.
.13133133133131.
.13333333333331.
.13333113333331.
.13333113333331.
.11111111111111.
................
................
................"""

HOUSE_C = """
................
................
................
.....111111.....
....12222221....
...1222222221...
..122222222221..
..111111111111..
..133333333331..
..131313331331..
..133333333331..
..133331133331..
..111111111111..
................
................"""

SHOP_A = """
................
..111111111111..
..122222222221..
..122222222221..
..111111111111..
..133333333331..
..131331331331..
..131331331331..
..133333333331..
..133333333331..
..131111111131..
..131111111131..
..133333333331..
..111111111111..
................
................"""

SHOP_B = """
................
...1111111111...
..122222222221..
..123232323221..
..122222222221..
..123232323221..
..122222222221..
..123232323221..
..122222222221..
..123232323221..
..122222222221..
..122211112221..
..122211112221..
..111111111111..
................
................"""

FACTORY_A = """
...11.....11....
...121....121...
...121....121...
..111111111111..
..1222222222221.
..1232323232321.
..1222222222221.
..1232323232321.
..1222222222221.
..1222222222221.
..1221112221121.
..1221112221121.
..1111111111111.
................
................"""

FACTORY_B = """
................
....11111111....
...1222222221...
..12222222222111
..12323232322121
..12222222222121
..12323232322121
..12222222222111
..12222222222221
..12211122211221
..12211122211221
..11111111111111
................
................"""

TREES = """
....11..........
...1331...11....
..133331..131...
..133331.1331...
.1333333113331..
.13333331133311.
..133331.13331..
...1221...121...
...1221...121...
.11....11.......
1331..1331..11..
13331133311331..
1333113331133311
.13311.1331.131.
..121...121.121.
..121...121.121."""

WATER = """
2222222222222222
2233222222332222
2222222222222222
2222222332222222
2112222222222112
2222222222222222
2223322222233222
2222222112222222
2222222222222222
2233222222332222
2222222222222222
2222233222222332
2222222222222222
2112222222112222
2222222332222222
2222222222222222"""

RUBBLE = """
................
....22..........
...2222....11...
..222122...221..
...2222...2221..
....22....222...
.....2....22....
..2.............
.2221....222....
.22211..22221...
.2221..2212221..
..221...22221...
...2.....222....
.......2........
................
................"""

PARK = """
......11........
.....1331.......
....133331......
....133331......
.....13331.2....
......121.......
.222..121..222..
.2332.....2332..
.23332...23332..
..2332...2332...
...22..1..22....
......131.......
.....13331......
....1333331.....
.....11311......
.......1........"""

FIRE_A = """
................
......3.........
..3..33....3....
..33.333..33....
..333333.333..3.
.33333333333.33.
.3323333233333..
.3322332233233..
33222322232233..
33222222222223..
3222222222222233
3222112211222233
2221111111122222
2211111111112222
2211111111111222
2111111111111122"""

FIRE_B = """
................
.........3......
....3....33..3..
...33...333..33.
.3.333.3333.333.
.33333333333333.
..33233332333333
..32232232233233
.332222222222233
.332222222222233
3322222222222223
3222112211222223
2221111111122222
2211111111112222
2211111111111222
2111111111111122"""

# ------------------------------------------------------------ blocks -------
# Big buildings are composed from a shared library of 8x8 texture tiles laid
# out on a 6x6 grid (= 3x3 map cells). Sharing textures across buildings keeps
# the CHR budget small; palettes + arrangement give each building its look.

TEX = {
'.': '.'*8 + ('\n'+'.'*8)*7,                # grass
'R': '1'*8 + ('\n'+'1'*8)*7,                # dark roof / solid
'w': '2'*8 + ('\n'+'2'*8)*7,                # plain wall
'W': """
22222222
23322332
23322332
22222222
22222222
23322332
23322332
22222222""",                                 # dense window grid
'o': """
22222222
23322332
23322332
22222222
22222222
22222222
22222222
22222222""",                                 # single window row
'd': """
22222222
22222222
22211222
22111122
22111122
21111112
21111112
21111112""",                                 # entrance
'c': """
22222222
22222212
22222222
22122222
22222222
22222221
22212222
22222222""",                                 # concrete apron
'S': """
.122221.
.122221.
.122221.
.122221.
.122221.
.122221.
.122221.
.122221.""",                                 # smokestack body
'T': """
..3..3..
.3.33.3.
3.3..3.3
.111111.
.122221.
.122221.
.122221.
.122221.""",                                 # smokestack top + smoke
'X': """
.122221.
.133331.
.133331.
.122221.
.122221.
.133331.
.133331.
.122221.""",                                 # striped stack body
'Z': """
...1...1
..21..21
.221.221
12212221
22222222
22222222
22222222
22222222""",                                 # sawtooth factory roof
'G': """
22222222
23333332
21111112
23333332
21111112
23333332
23333332
22222222""",                                 # garage door
'Q': """
22222222
23232323
22222222
32323232
22222222
23232323
22222222
32323232""",                                 # stadium seats
'l': """
...33...
...33...
...33...
...33...
...33...
...33...
...33...
...33...""",                                 # field center line (on grass)
'k': """
22222222
21212121
11111111
22222222
22222222
22222222
22222222
22222222""",                                 # crane arm
'm': """
22211222
22211222
22211222
21111112
22211222
22211222
22211222
22222222""",                                 # crane mast
'C': """
22222222
23333322
23333322
21111122
23333322
23333322
22222222
22222222""",                                 # container stack
'Y': """
11111111
11111111
11111111
33111331
33111331
11111111
11111111
11111111""",                                 # runway with dashes
'a': """
.333333.
.311113.
.333333.
..1111..
..1111..
..1111..
..1111..
..1111..""",                                 # control tower
'B': """
22222222
23333332
23111332
23131332
23111332
23133332
23333322
22222222""",                                 # police badge sign (P on white)
't': """
...11...
..1331..
.133331.
.133331.
.133331.
..1331..
...22...
...22...""",                                 # small tree
'D1': """
......33
....3333
...33333
..333333
.3333333
.3333333
33333333
33333333""",                                 # dome quarter TL
'D2': """
33......
3333....
33333...
333333..
3333333.
3333333.
33333333
33333333""",                                 # dome quarter TR
'D3': """
33333333
33333333
33333133
33333313
33333313
33333133
33333333
33333333""",                                 # dome lower-left (with mark)
'D4': """
33333333
33333333
33133333
31333333
31333333
33133333
33333333
33333333""",                                 # dome lower-right (with mark)
'f': """
22222222
23232323
22222222
32323232
11111111
11111111
11111111
11111111""",                                 # stand edge over dark
}

def compose_block(layout):
    """layout: 6 rows of 6 texture keys (space-separated) -> 48x48 art."""
    grid = [row.split() for row in layout.strip('\n').split('\n')]
    assert len(grid) == 6 and all(len(r) == 6 for r in grid), "layout must be 6x6"
    out = []
    for trow in grid:
        tiles = []
        for key in trow:
            art = TEX[key]
            rows = [r.ljust(8, '.') for r in art.strip('\n').split('\n')]
            tiles.append(rows)
        for y in range(8):
            out.append(''.join(t[y] for t in tiles))
    return '\n'.join(out)

RES3_LAYOUT = """
. R R R R .
. W W W W .
. W W W W .
. W W W W .
. . R R . .
. . d W . ."""

COM3_LAYOUT = """
. R R R R .
. W W W W .
. W W W W .
. W W W W .
. W W W W .
. w d d w ."""

IND3_LAYOUT = """
T . . . T .
S Z Z Z S .
S w w w S .
S o o o S .
S o o o S .
c c c c c c"""

COAL_LAYOUT = """
T . T . T .
X . X . X .
R R R R R R
w o w o w w
w o w o w w
c c R R c c"""

NUKE_LAYOUT = """
. D1 D2 . T .
. D3 D4 . S .
. w w w w .
. o o o o .
. w d w w .
. c c c c ."""

POLICE_LAYOUT = """
. . . . . .
. R R R R .
. W B W W .
. o o o o .
. w d d w .
. c c c c ."""

FIRESTN_LAYOUT = """
. . . . . .
. R R R R .
. o o o o .
. w w w w .
. G G w G .
. c c c c ."""

STADIUM_LAYOUT = """
Q Q Q Q Q Q
Q Q Q Q Q Q
Q Q l . Q Q
Q Q l . Q Q
Q Q Q Q Q Q
Q Q Q Q Q Q"""

SEAPORT_LAYOUT = """
C w w C c .
c c c c c c
k k k k m c
c c c c m c
C C c C C c
c c c c c c"""

AIRPORT_LAYOUT = """
. a . R R .
. w . w w .
c c c c c c
R R R R R R
Y Y Y Y Y Y
c c c c c c"""

# ------------------------------------------------------------ sprites ------

CURSOR_CORNER = """
33333333
31111111
31......
31......
31......
31......
31......
31......"""

BOLT = """
.....33.
....33..
...333..
..3333..
...33333
...333..
..33....
.33....."""

TORNADO_A = """
.223333333322...
..2233333322....
...22333322.....
....223322......
....22332.......
.....2232.......
.....223........
......22........
......22........
.....22.........
.....22.........
....222.........
....22..........
...222..........
....2...........
................"""

TORNADO_B = """
...223333333322.
....2233333322..
.....22333322...
......223322....
......22332.....
......2232......
......223.......
.....22.........
.....22.........
......22........
......22........
......222.......
.......22.......
......222.......
.......2........
................"""


def spr16(SPR, name, art):
    """16x16 sprite -> 4 tiles named name_0..3 (TL,TR,BL,BR)."""
    rows = [r.ljust(16, '.') for r in art.strip('\n').split('\n')]
    while len(rows) < 16: rows.append('.'*16)
    ids = []
    for qx in range(2):
        for qy in range(2):
            t = '\n'.join(rows[qy*8+y][qx*8:qx*8+8] for y in range(8))
            ids.append(SPR.add(t, f"{name}_{qx*2+qy}" if False else None))
    # store first id under name; tiles are sequential? not guaranteed -> name each
    return ids


def build(BG, SPR, cells):
    extra = []

    # ---------------- terrain
    cells.add('DIRT', C().art(), P_TERRAIN)          # plain grass
    cells.add('TREES', TREES, P_TERRAIN)
    cells.add('WATER', WATER, P_WATER)
    cells.add('RUBBLE', RUBBLE, P_TERRAIN)
    cells.add('PARK', PARK, P_TERRAIN)
    cells.add('FIRE_A', FIRE_A, P_WARM)
    cells.add('FIRE_B', FIRE_B, P_WARM)

    # ---------------- networks (16 shapes each, contiguous ids)
    base = cells.add('ROAD', road_cell(0), P_GRAY)
    for m in range(1, 16):
        cells.add(f'ROAD{m}', road_cell(m), P_GRAY)
    base = cells.add('RAIL', rail_cell(0), P_GRAY)
    for m in range(1, 16):
        cells.add(f'RAIL{m}', rail_cell(m), P_GRAY)
    base = cells.add('WIRE', wire_cell(0), P_WARM)
    for m in range(1, 16):
        cells.add(f'WIRE{m}', wire_cell(m), P_WARM)
    cells.add('ROADWIRE_H', roadwire_cell(True), P_GRAY)   # horiz road, vert wire
    cells.add('ROADWIRE_V', roadwire_cell(False), P_GRAY)
    cells.add('RAILROAD_H', railroad_cross(True), P_GRAY)
    cells.add('RAILROAD_V', railroad_cross(False), P_GRAY)

    # ---------------- zone periphery + signs
    for zname, pal, col in (('R', P_WARM, '2'), ('C', P_WATER, '2'), ('I', P_GRAY, '1')):
        for pos in range(9):
            if pos == 4: continue
            cells.add(f'Z{zname}_{pos}', zone_edge_cell(pos, col), pal)
    cells.add('SIGN_R', sign_cell('R'), P_WARM)
    cells.add('SIGN_C', sign_cell('C'), P_WATER)
    cells.add('SIGN_I', sign_cell('I'), P_GRAY)

    # ---------------- zone growth stages (16x16 buildings)
    cells.add('HOUSE_A', HOUSE_A, P_WARM)
    cells.add('HOUSE_B', HOUSE_B, P_WARM)
    cells.add('HOUSE_C', HOUSE_C, P_WARM)
    cells.add('SHOP_A', SHOP_A, P_WATER)
    cells.add('SHOP_B', SHOP_B, P_WATER)
    cells.add('FACTORY_A', FACTORY_A, P_GRAY)
    cells.add('FACTORY_B', FACTORY_B, P_GRAY)

    # ---------------- 3x3 blocks
    cells.add_block('RES3', compose_block(RES3_LAYOUT), P_WARM)
    cells.add_block('COM3', compose_block(COM3_LAYOUT), P_WATER)
    cells.add_block('IND3', compose_block(IND3_LAYOUT), P_GRAY)
    cells.add_block('COAL', compose_block(COAL_LAYOUT), P_GRAY)
    cells.add_block('NUKE', compose_block(NUKE_LAYOUT), P_GRAY)
    cells.add_block('POLICE', compose_block(POLICE_LAYOUT), P_WATER)
    cells.add_block('FIRESTN', compose_block(FIRESTN_LAYOUT), P_WARM)
    cells.add_block('STADIUM', compose_block(STADIUM_LAYOUT), P_GRAY)
    cells.add_block('SEAPORT', compose_block(SEAPORT_LAYOUT), P_GRAY)
    cells.add_block('AIRPORT', compose_block(AIRPORT_LAYOUT), P_GRAY)

    # ---------------- UI tiles (SOLID comes from the font builder)
    for lvl in range(1, 9):
        rows = []
        for y in range(8):
            fill = (7 - y) < lvl
            rows.append('1' + ('3'*6 if fill else '1'*6) + '1')
        BG.add('\n'.join(rows), f'BAR{lvl}')

    # ---------------- zone growth layout tables (asm data)
    def zone_table(tname, sign, edges_prefix, blocks_name, stages):
        vals = []
        for lvl in range(3):
            stage = stages.get(lvl, {})
            for pos in range(9):
                if pos == 4:
                    vals.append(cells.names[sign])
                elif pos in stage:
                    vals.append(cells.names[stage[pos]])
                else:
                    vals.append(cells.names[f'{edges_prefix}_{pos}'])
        vals.extend(cells.blocks[blocks_name])       # level 3 = full block
        lines = [f'zgfx_{tname}:']
        for i in range(0, 36, 12):
            lines.append('.byte ' + ','.join(f'${v:02X}' for v in vals[i:i+12]))
        return lines

    extra += zone_table('r', 'SIGN_R', 'ZR', 'RES3', {
        1: {0: 'HOUSE_A', 5: 'HOUSE_B'},
        2: {0: 'HOUSE_B', 1: 'HOUSE_A', 2: 'HOUSE_C', 3: 'HOUSE_C',
            5: 'HOUSE_A', 6: 'HOUSE_A', 7: 'HOUSE_C', 8: 'HOUSE_B'},
    })
    extra += zone_table('c', 'SIGN_C', 'ZC', 'COM3', {
        1: {3: 'SHOP_A', 8: 'SHOP_B'},
        2: {0: 'SHOP_A', 1: 'SHOP_B', 3: 'SHOP_B',
            5: 'SHOP_A', 7: 'SHOP_B', 8: 'SHOP_A'},
    })
    extra += zone_table('i', 'SIGN_I', 'ZI', 'IND3', {
        1: {1: 'FACTORY_A', 6: 'FACTORY_B'},
        2: {0: 'FACTORY_B', 2: 'FACTORY_A', 3: 'FACTORY_A',
            5: 'FACTORY_B', 7: 'FACTORY_A'},
    })

    # ---------------- sprites
    SPR.add(CURSOR_CORNER, 'CURSOR')
    SPR.add(BOLT, 'BOLT')
    rows = [r.ljust(16, '.') for r in TORNADO_A.strip('\n').split('\n')]
    for name, art in (('TORN_A', TORNADO_A), ('TORN_B', TORNADO_B)):
        rows = [r.ljust(16, '.') for r in art.strip('\n').split('\n')]
        for qi, (qx, qy) in enumerate(((0,0),(1,0),(0,1),(1,1))):
            t = '\n'.join(rows[qy*8+y][qx*8:qx*8+8] for y in range(8))
            SPR.add(t, f'{name}{qi}')

    return extra

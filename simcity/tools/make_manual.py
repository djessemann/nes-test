#!/usr/bin/env python3
"""Generate cover art from the game's CHR tile art + a mini manual PDF."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import gfx
import gfx_tiles
from nesemu import NES_PALETTE

OUT = os.path.join(os.path.dirname(__file__), '..', 'manual')

UNIV_GRASS = 0x1A
PALETTES = [
    [0x0A, 0x17, 0x2A],   # terrain
    [0x01, 0x11, 0x2C],   # water
    [0x0F, 0x10, 0x30],   # gray
    [0x07, 0x16, 0x27],   # warm
]
SPR_TORNADO = [0x0F, 0x00, 0x2D]

cells = gfx.CellSet(gfx.BG)
gfx_tiles.build(gfx.BG, gfx.SPR, cells)

def rgb(idx):
    return NES_PALETTE[idx & 0x3F]

def tile_px(page, tid):
    data = page.tiles[tid] or bytes(16)
    out = []
    for y in range(8):
        lo, hi = data[y], data[y+8]
        out.append([((lo >> (7-x)) & 1) | (((hi >> (7-x)) & 1) << 1) for x in range(8)])
    return out

def draw_tile(img, page, tid, x, y, pal, bg=None, scale=1):
    px = tile_px(page, tid)
    for yy in range(8):
        for xx in range(8):
            v = px[yy][xx]
            if v == 0:
                if bg is None:
                    continue
                c = bg
            else:
                c = rgb(pal[v-1])
            for sy in range(scale):
                for sx in range(scale):
                    img.putpixel((x+xx*scale+sx, y+yy*scale+sy), c)

def draw_cell(img, name_or_id, x, y, bg=None):
    if isinstance(name_or_id, str):
        cid = cells.names[name_or_id]
    else:
        cid = name_or_id
    _, tl, tr, bl, br, pal = cells.cells[cid]
    p = PALETTES[pal]
    draw_tile(img, gfx.BG, tl, x, y, p, bg)
    draw_tile(img, gfx.BG, tr, x+8, y, p, bg)
    draw_tile(img, gfx.BG, bl, x, y+8, p, bg)
    draw_tile(img, gfx.BG, br, x+8, y+8, p, bg)

def draw_block(img, blkname, x, y, bg=None):
    ids = cells.blocks[blkname]
    for i, cid in enumerate(ids):
        draw_cell(img, cid, x + (i % 3)*16, y + (i // 3)*16, bg)

def draw_text(img, s, x, y, scale=1, color=(255, 255, 255), shadow=None):
    W, H = img.size
    def put(px_, py_, c_):
        if 0 <= px_ < W and 0 <= py_ < H:
            img.putpixel((px_, py_), c_)
    for i, ch in enumerate(s):
        if ch == ' ':
            continue
        tid = gfx.FONT_MAP.get(ch)
        if tid is None:
            continue
        px = tile_px(gfx.BG, tid)
        for yy in range(8):
            for xx in range(8):
                if px[yy][xx] != 3:
                    continue
                bx = x + i*8*scale + xx*scale
                by = y + yy*scale
                for sy in range(scale):
                    for sx in range(scale):
                        if shadow:
                            put(bx+sx+scale, by+sy+scale, shadow)
        for yy in range(8):
            for xx in range(8):
                if px[yy][xx] != 3:
                    continue
                bx = x + i*8*scale + xx*scale
                by = y + yy*scale
                for sy in range(scale):
                    for sx in range(scale):
                        put(bx+sx, by+sy, color)

def draw_sprite16(img, base_name, x, y, pal, scale=1):
    # sprite quads named base0..base3 = TL,TR,BL,BR
    for qi, (qx, qy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
        tid = gfx.SPR.names[f'{base_name}{qi}']
        draw_tile(img, gfx.SPR, tid, x+qx*8*scale, y+qy*8*scale, pal, None, scale)

# ---------------------------------------------------------------- cover ----

def make_cover():
    W, H = 256, 352
    NIGHT = (8, 8, 24)
    img = Image.new('RGB', (W, H), NIGHT)
    put = img.putpixel

    # stars
    import random
    rnd = random.Random(7)
    for _ in range(90):
        x, y = rnd.randrange(6, W-6), rnd.randrange(6, 150)
        c = (200, 200, 210) if rnd.random() < .6 else (120, 120, 150)
        put((x, y), c)
    # moon
    for yy in range(10):
        for xx in range(10):
            if (xx-4.5)**2 + (yy-4.5)**2 <= 22:
                put((214+xx, 26+yy), (236, 228, 160))

    # title
    draw_text(img, "MICROPOLIS", 9, 40, scale=3, color=(236, 238, 236),
              shadow=(180, 32, 32))
    draw_text(img, "THE CITY SIMULATOR", 56, 78, scale=1, color=(160, 214, 228))

    grass = rgb(UNIV_GRASS)
    ground_top = 128
    # grass field behind the city (ends just past the river)
    for y in range(ground_top, 276):
        for x in range(0, W):
            put((x, y), grass)

    # tornado in the night sky
    draw_sprite16(img, 'TORN_A', 18, 96, SPR_TORNADO, scale=2)

    # skyline: big blocks
    y0 = ground_top + 8
    for i, b in enumerate(('COM3', 'RES3', 'COAL', 'IND3', 'STADIUM')):
        draw_block(img, b, 4 + i*50, y0, grass)

    # row of small builds
    y1 = y0 + 52
    row = ['TREES', 'HOUSE_A', 'HOUSE_B', 'SIGN_R', 'HOUSE_C', 'PARK',
           'SHOP_A', 'SIGN_C', 'SHOP_B', 'FACTORY_A', 'SIGN_I', 'FACTORY_B',
           'TREES', 'HOUSE_A', 'WIRE10', 'TREES']
    for i, name in enumerate(row):
        draw_cell(img, name, i*16, y1, grass)

    # road with a rail crossing
    y2 = y1 + 16
    for i in range(16):
        name = 'ROAD10'
        if i == 3:
            name = 'RAILROAD_H'
        if i == 12:
            name = 'ROADWIRE_H'
        draw_cell(img, name, i*16, y2, grass)

    # river with bridges
    y3 = y2 + 16
    for i in range(16):
        name = 'WATER'
        if i == 3:
            name = 'RAILW_V'
        if i == 12:
            name = 'WIREW_V'
        draw_cell(img, name, i*16, y3, grass)

    # grass shore row below the river
    for i in range(16):
        name = ('TREES', 'DIRT', 'PARK', 'DIRT')[i % 4]
        draw_cell(img, name, i*16, 260, grass)

    # footer on the night band
    draw_text(img, "8-BIT CITY SIMULATION", 44, 298, scale=1,
              color=(236, 238, 236))
    draw_text(img, "BATTERY CITY SAVE", 60, 312, scale=1,
              color=(120, 120, 150))
    draw_text(img, "MPLS-01", 196, 334, scale=1, color=(80, 80, 100))

    # clear the margin outside the frame, then draw the frame
    for y in range(H):
        for x in (0, 1, W-2, W-1):
            put((x, y), NIGHT)
    for x in range(W):
        for y in (0, 1, H-2, H-1):
            put((x, y), NIGHT)
    fr = (236, 238, 236)
    for x in range(2, W-2):
        put((x, 2), fr); put((x, 3), fr); put((x, H-3), fr); put((x, H-4), fr)
    for y in range(2, H-2):
        put((2, y), fr); put((3, y), fr); put((W-3, y), fr); put((W-4, y), fr)

    img = img.resize((W*3, H*3), Image.NEAREST)
    img.save(os.path.join(OUT, 'cover.png'))
    return img

# ---------------------------------------------------------------- icons ----

def make_icons():
    """Small art assets for the manual's building roster."""
    grass = rgb(UNIV_GRASS)
    icons = {}
    def cell_icon(name, art):
        im = Image.new('RGB', (16, 16), grass)
        draw_cell(im, art, 0, 0, grass)
        icons[name] = im.resize((48, 48), Image.NEAREST)
    def block_icon(name, blk):
        im = Image.new('RGB', (48, 48), grass)
        draw_block(im, blk, 0, 0, grass)
        icons[name] = im
    cell_icon('bulldozer', 'RUBBLE')
    cell_icon('road', 'ROAD10')
    cell_icon('wire', 'WIRE10')
    cell_icon('rail', 'RAIL10')
    cell_icon('park', 'PARK')
    cell_icon('res', 'SIGN_R')
    cell_icon('com', 'SIGN_C')
    cell_icon('ind', 'SIGN_I')
    block_icon('police', 'POLICE')
    block_icon('fire', 'FIRESTN')
    block_icon('stadium', 'STADIUM')
    block_icon('coal', 'COAL')
    block_icon('nuke', 'NUKE')
    block_icon('seaport', 'SEAPORT')
    block_icon('airport', 'AIRPORT')
    # extras
    im = Image.new('RGB', (32, 16), grass)
    draw_cell(im, 'WIREW_H', 0, 0)
    draw_cell(im, 'RAILW_H', 16, 0)
    icons['crossings'] = im.resize((96, 48), Image.NEAREST)
    for k, v in icons.items():
        v.save(os.path.join(OUT, f'icon_{k}.png'))
    return icons

# ---------------------------------------------------------------- pdf ------

DARK = (20/255, 20/255, 28/255)
RED = (180/255, 32/255, 32/255)
GRAY = (120/255, 120/255, 140/255)

def make_pdf():
    from reportlab.pdfgen import canvas as rlcanvas
    from reportlab.lib.pagesizes import letter
    pw, ph = letter
    m = 46
    c = rlcanvas.Canvas(os.path.join(OUT, 'micropolis_manual.pdf'),
                        pagesize=letter)
    c.setTitle('MICROPOLIS - Instruction Booklet')

    def img(name, x, y_top, w, h):
        path = name if os.path.sep in name else os.path.join(OUT, name)
        c.drawImage(path, x, ph - y_top - h, w, h)

    def header_bar(title):
        c.setFillColorRGB(*DARK)
        c.rect(0, ph-64, pw, 64, stroke=0, fill=1)
        c.setFillColorRGB(*RED)
        c.rect(0, ph-68, pw, 4, stroke=0, fill=1)
        c.setFillColorRGB(1, 1, 1)
        c.setFont('Helvetica-Bold', 22)
        c.drawString(m, ph-44, title)
        c.setFillColorRGB(*GRAY)
        c.setFont('Helvetica-Bold', 10)
        c.drawRightString(pw-m, ph-40, 'MICROPOLIS  -  NES')

    def section(title, y_top):
        c.setFillColorRGB(*RED)
        c.setFont('Helvetica-Bold', 13)
        c.drawString(m, ph - y_top, title)
        return y_top + 20

    def wrap(text, font, size, width):
        from reportlab.pdfbase.pdfmetrics import stringWidth
        lines = []
        for para in text.split('\n'):
            words = para.split(' ')
            cur = ''
            for w in words:
                t = (cur + ' ' + w).strip()
                if stringWidth(t, font, size) <= width:
                    cur = t
                else:
                    lines.append(cur)
                    cur = w
            lines.append(cur)
        return lines

    def body(text, y_top, size=10.5, lh=14, width=None, x=None):
        c.setFillColorRGB(0, 0, 0)
        c.setFont('Helvetica', size)
        width = width or (pw - 2*m)
        x = x or m
        for ln in wrap(text, 'Helvetica', size, width):
            c.drawString(x, ph - y_top, ln)
            y_top += lh
        return y_top + 4

    # ---- page 1: cover
    c.setFillColorRGB(8/255, 8/255, 24/255)
    c.rect(0, 0, pw, ph, stroke=0, fill=1)
    cw, chh = 256*1.9, 352*1.9
    img('cover.png', (pw-cw)/2, (ph-chh)/2 - 24, cw, chh)
    c.setFillColorRGB(*GRAY)
    c.setFont('Helvetica-Bold', 11)
    c.drawCentredString(pw/2, 40, 'INSTRUCTION BOOKLET')
    c.showPage()

    # ---- page 2: getting started
    header_bar('GETTING STARTED')
    y = section('THE JOB', 96)
    y = body("Congratulations, Mayor. The land is green, the treasury is "
             "full, and absolutely nothing works yet. Zone neighborhoods, "
             "wire them to a power plant, connect them by road, and keep "
             "the budget out of the red. The city that grows from there is "
             "up to you.", y)
    y = section('CONTROLS', y + 8)
    rows = [
        ('D-PAD', 'Move the cursor. Hold to glide. Push past the screen edge to scroll the map.'),
        ('A', 'Use the current tool at the cursor.'),
        ('B', 'Open / close the build menu.'),
        ('SELECT', 'Quick-cycle to the next tool.'),
        ('START', 'City report: budget, tax rate, sim speed, disasters.'),
    ]
    for btn, desc in rows:
        c.setFillColorRGB(*DARK)
        c.rect(m, ph - y - 16, 64, 20, stroke=0, fill=1)
        c.setFillColorRGB(1, 1, 1)
        c.setFont('Helvetica-Bold', 10)
        c.drawCentredString(m+32, ph - y - 10, btn)
        c.setFillColorRGB(0, 0, 0)
        c.setFont('Helvetica', 10.5)
        c.drawString(m+78, ph - y - 10, desc)
        y += 27
    y = section('YOUR FIRST TEN MINUTES', y + 10)
    y = body("1.  On the title screen pick NEW CITY and a difficulty - that "
             "is your starting treasury ($20,000 / $10,000 / $5,000).\n"
             "2.  Build a COAL POWER plant on open land ($3,000).\n"
             "3.  Zone a few RESIDENTIAL plots nearby ($100 each).\n"
             "4.  Run a POWER LINE from the plant to the first zone. Zones "
             "that touch each other pass power along, so one line can feed "
             "a whole district.\n"
             "5.  Lay a ROAD within two tiles of every zone.\n"
             "6.  Wait. Houses appear, the population climbs, and commerce "
             "and industry start asking for zones of their own - watch the "
             "R C I bars in the status bar.", y)
    y = section('IF A ZONE FLASHES A LIGHTNING BOLT', y + 8)
    y = body("It has no electricity. Trace your power lines: every zone "
             "needs an unbroken path of wires (or touching zones) back to "
             "a plant.", y)
    c.showPage()

    # ---- page 3: catalog
    header_bar("THE BUILDER'S CATALOG")
    items = [
        ('bulldozer', 'BULLDOZER', '$1',
         'Clears any tile. Levels whole zones. Cannot stop fire.'),
        ('road', 'ROAD', '$10',
         'Zones need one within 2 tiles. Yearly upkeep.'),
        ('wire', 'POWER LINE', '$5',
         'Carries power. Place on a river for a pylon crossing.'),
        ('rail', 'RAIL', '$20',
         'Heavy transit. Crosses rivers as a trestle bridge.'),
        ('park', 'PARK', '$10', 'Green space. The neighbors approve.'),
        ('res', 'RESIDENTIAL', '$100',
         'Homes. Grows when powered, roaded, and jobs exist.'),
        ('com', 'COMMERCIAL', '$100',
         'Shops and offices. Feeds on a growing population.'),
        ('ind', 'INDUSTRIAL', '$100',
         'Factories. Your early economic engine.'),
        ('police', 'POLICE DEPT', '$500 +$100/yr',
         'Keeps crime down as the city grows.'),
        ('fire', 'FIRE DEPT', '$500 +$100/yr',
         'Fires burn out faster with coverage.'),
        ('stadium', 'STADIUM', '$5,000',
         'Residential demands one for top density.'),
        ('coal', 'COAL POWER', '$3,000', 'Reliable power. Not pretty.'),
        ('nuke', 'NUKE POWER', '$5,000',
         'More power. Ask about our meltdown policy.'),
        ('seaport', 'SEAPORT', '$3,000',
         'Industry demands one for top density.'),
        ('airport', 'AIRPORT', '$10,000',
         'Commerce demands one for top density.'),
    ]
    col_x = [m, m + (pw - 2*m)/2 + 10]
    col_w = (pw - 2*m)/2 - 20
    y = 92
    for i, (icon, name, cost, desc) in enumerate(items):
        cx = col_x[i % 2]
        img(f'icon_{icon}.png', cx, y, 40, 40)
        c.setFillColorRGB(0, 0, 0)
        c.setFont('Helvetica-Bold', 10)
        c.drawString(cx+48, ph - y - 10, name)
        c.setFillColorRGB(*RED)
        c.setFont('Helvetica-Bold', 9.5)
        c.drawRightString(cx+col_w, ph - y - 10, cost)
        c.setFillColorRGB(0, 0, 0)
        c.setFont('Helvetica', 9)
        yy = y + 23
        for ln in wrap(desc, 'Helvetica', 9, col_w-48):
            c.drawString(cx+48, ph - yy, ln)
            yy += 11
        if i % 2 == 1:
            y += 74
    y += 80
    y = section('CROSSING WATER', y)
    img('icon_crossings.png', pw-m-96, y-6, 96, 48)
    body("Rivers are not the end of the line. Place the POWER LINE or "
         "RAIL tool directly on water to build a crossing. Straight spans "
         "only - and bulldozing one gives the river back.",
         y, width=pw-2*m-112)
    c.showPage()

    # ---- page 4: running the city
    header_bar('RUNNING THE CITY')
    y = section('GROWTH', 96)
    y = body("Zones develop through four stages, from empty plot to a full "
             "city block, driven by the R C I demand bars: residents come "
             "for jobs, commerce and industry come for residents. Every "
             "zone must be powered and near a road. Top density needs the "
             "big amenities - a Stadium for residents, a Seaport for "
             "industry, an Airport for commerce. The advisor line in the "
             "status bar tells you what the city wants next.", y)
    y = section('MONEY & TIME', y + 6)
    y = body("Taxes are collected every January: population times tax "
             "rate. Roads, rails and stations charge their upkeep at the "
             "same time. Press START for the city report, where you set "
             "the tax rate (high taxes scare off growth), the simulation "
             "speed, and whether disasters strike. Your approval rating "
             "lives there too.", y)
    y = section('DISASTERS', y + 6)
    shot = os.path.join(OUT, '..', 'screenshots', 'disaster_aftermath.png')
    img(shot, pw-m-176, y-6, 176, 165)
    y2 = body("Fires spread through trees and buildings - fire stations "
              "shorten them, firebreaks stop them. Tornadoes carve tracks "
              "of rubble. Nuclear plants are perfectly safe, except when "
              "they are not. Pictured: a tornado leveled this city's "
              "commercial district, which blacked out the seaport.\n"
              "Too exciting? Turn disasters OFF in the city report.",
              y, width=pw-2*m-192)
    y = max(y2, y + 172)
    y = section('SAVING', y)
    y = body("The cartridge battery saves your city automatically every "
             "January and whenever you open the city report. Pick CONTINUE "
             "on the title screen to pick up where you left off.", y)
    y = section("MAYOR'S FIELD NOTES", y + 4)
    y = body("-  Zones conduct power to each other. Wire districts, not tiles.\n"
             "-  Industry bootstraps fastest; residential follows jobs.\n"
             "-  7% tax is the citizens' comfort zone. Raise it at your peril.\n"
             "-  Nothing on fire? Nothing next to fire? You are doing fine.", y)
    c.setFillColorRGB(*DARK)
    c.rect(0, 0, pw, 52, stroke=0, fill=1)
    c.setFillColorRGB(*GRAY)
    c.setFont('Helvetica-Bold', 9)
    c.drawCentredString(pw/2, 22, 'MICROPOLIS  -  AN 8-BIT HOMAGE TO THE '
                                  'ORIGINAL CITY SIMULATOR  -  MMC1 - 32K '
                                  'PRG - BATTERY')
    c.showPage()
    c.save()

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    make_cover()
    make_icons()
    make_pdf()
    print('manual assets written to', OUT)

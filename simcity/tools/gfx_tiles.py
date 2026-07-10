"""Terrain, building and sprite tile art for Micropolis NES (placeholder)."""

def build(BG, SPR):
    # solid test tile
    BG.add("""
11111111
12222221
12333321
12333321
12333321
12333321
12222221
11111111""", 'TEST')

    # cursor corner (top-left), other corners via H/V flip
    SPR.add("""
33333...
3.......
3.......
3.......
3.......
........
........
........""", 'CURSOR')

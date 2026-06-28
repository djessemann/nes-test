# How Dragon Quest Built an RPG on the NES

A reference for designing your own NES RPG. The throughline of Dragon Quest’s
(Dragon Warrior in the US) entire design is one rule: **do everything you
possibly can with the background layer, and spend sprites only on things that
actually move.** Once you internalize that, the rest of the architecture falls
out of it.

-----

## 1. Sprites and Tiles

### The two CHR banks

The NES PPU has two 4KB pattern tables, each holding 256 8×8 tiles. The standard
split (and DQ’s) is:

- **$0000 — background tiles:** world/town/dungeon terrain, the font, window
  border pieces, *and the battle monster art*.
- **$1000 — sprite tiles:** the moving characters only — the hero and walking
  NPCs.

That’s the whole trick. The map you walk on, the text you read, the menus, and
the monster you fight are **all background tiles written into the nametable.**
The only true hardware sprites on the field screen are the hero and the handful
of NPCs wandering a town.

In DQ1 specifically, townspeople and monster graphics live in the *same* CHR
bank — the first 32 tiles were townsperson graphics, some of which got
overwritten by title-screen animation and left as dead tiles in the ROM.

### How the map is built: metatiles

The overworld is far too big to store as raw nametable data, and raw 8×8 tiles
are the wrong unit anyway. DQ (like nearly every NES game) works in **16×16
metatiles** — a 2×2 block of tiles plus a palette assignment. Three reasons this
is the natural unit:

1. It matches the **attribute table** granularity. The NES only lets you assign
   a palette per 16×16 region, so a metatile is exactly one palette decision.
1. It compresses map data **4:1** versus storing every 8×8 tile.
1. Collision becomes trivial: one flag per metatile (walkable / wall / water /
   stairs / town-trigger).

So a grass tile, a tree, a bit of castle wall — each is one metatile ID. The
overworld is a big grid of those IDs, and the engine expands each ID into four
tile writes plus an attribute byte when it draws a screen.

### The moving characters

The hero is a **metasprite** — a 16×16 figure made of four 8×8 hardware sprites
arranged 2×2, drawn from a list of `(dx, dy, tile, attributes)` entries relative
to the character’s position. NPCs are the same.

A telling detail about how tight the budget was: in the **Japanese** DQ1,
characters had no facing direction at all — they always faced the screen, Ultima
style — because that’s all the CHR space allowed. When the game was localized as
**Dragon Warrior**, the larger US cartridge had room for directional sprites, so
characters could finally face the way they walked, and the awkward “pick a
direction before you talk” menu got dropped.

### Palette and color limits (why DQ looks the way it does)

- 4 background sub-palettes + 4 sprite sub-palettes, each = 3 colors + one shared
  universal color. Color 0 of a sprite palette is transparent.
- A single tile shows at most 4 colors; a sprite at most 3 + transparent.

This is the direct cause of the heavy **black outlines** on DQ’s characters and
monsters — black does double duty as an outline *and* the shared backdrop color,
and outlining also hid NTSC color bleed (“dot crawl”).

### One classic background-only effect

The **dark dungeon “halo of light”** isn’t a lighting engine. Most of the
background tiles are simply set to solid black, leaving a small lit square around
the hero. That’s why the lit area is square and snaps to the grid — it’s just
nametable tiles. The lit region is small enough that the game can rewrite the
whole thing every frame as you move.

-----

## 2. Where and How Enemies Are Created

Split this into two completely separate problems — they confuse people because
“enemy” means two different things.

### (a) Encounter generation — deciding a fight happens

This is pure data + RNG, no graphics:

- Each step on the overworld/dungeon decrements (or increments) a **step
  counter** and rolls the RNG against an encounter rate.
- The map is divided into **zones/regions**, each with an **encounter table** —
  the list of monster IDs allowed there, often weighted so weak monsters appear
  near the start town and nasty ones appear far out.
- On a hit, pick a monster ID from the current zone’s table. DQ1 fights one
  monster at a time, which keeps this simple.

### (b) Battle representation — drawing the monster

Here’s the part that surprises people: **the monster is not a sprite.** When the
battle window opens, the chosen monster’s image is composed into the
**background nametable**, inside the black battle box. It works as a background
blit because the monster is large, static, and there’s only one of it — exactly
the case sprites are bad at (a 16×16 metasprite would need many hardware sprites
and would hit the 8-sprites-per-scanline limit) and backgrounds are good at.

So the flow for a monster ID is:

```
monster_id ─┬─► CHR / tile data to write into the battle window (the picture)
            ├─► a stats row in a ROM table (HP, attack, defense, agility,
            │     XP reward, gold reward, spell/flee behavior)
            └─► AI/behavior index (which actions it can take each turn)
```

The **stats live in a flat ROM table**, read struct-of-arrays style: parallel
arrays indexed by monster ID (`monster_hp[id]`, `monster_atk[id]`, …). That’s
both how the data is stored and the idiomatic 6502 way to read it — one indexed
load, no multiplication.

### How you’d implement this

- A `battle` game state with its own sub-state machine: intro → command menu →
  player action → enemy action → resolve → check win/lose → loop.
- Monster combatant data copied into RAM at battle start (current HP, status)
  so the ROM table stays read-only.
- For **multiple enemies** (DQ2+), promote the combatants to a small
  struct-of-arrays entity list — the same parallel-array pattern you’d use for
  on-screen actors, just scoped to the battle.

-----

## 3. Writing and Displaying Text

Text is the defining system of an NES RPG, and it’s almost entirely a
**background + windowing** exercise.

### The font is just tiles

Each glyph (letter, digit, kana, punctuation) is one 8×8 background tile sitting
in the CHR bank. “Drawing text” means writing the right sequence of **tile
indices** into the nametable. The NES font grid is effectively fixed-width — one
cell per character. Japanese DQ uses kana, a small enough alphabet to fit
comfortably; the English localization needed a reworked, larger font and more
ROM to hold it, which is part of why command windows got resized.

### Windows are nametable rectangles

A dialogue or menu box is: border tiles (corners + edges) framing an interior of
“blank” tiles, all written into the nametable. Open a window = blit the frame and
clear the interior. Close it = restore whatever background was underneath (so the
engine keeps a copy, or just redraws the map area).

### The text engine itself

Strings are stored in ROM as **byte sequences**, where most bytes map to a font
tile and a reserved range are **control codes**:

|Control code            |Does                                             |
|------------------------|-------------------------------------------------|
|newline                 |move to next line in the window                  |
|end of message          |stop                                             |
|wait-for-button         |pause until the player presses A (the “▼” prompt)|
|open/close window       |manage the box                                   |
|name substitution       |splice in the hero’s chosen name                 |
|(optional) delay / speed|pacing                                           |

Two things worth copying from DQ:

1. **Dictionary/token compression.** Common words and fragments (“the “,
   “thou “, “Dragonlord”) get a single token byte that expands to a whole string
   at print time. RPG scripts are enormous relative to NES ROM, so this matters a
   lot. You build a dictionary, replace frequent substrings with tokens, and the
   printer expands tokens as it walks the string.
1. **Name substitution** via a control code that reads the player-entered name
   out of RAM and prints it inline.

### The typewriter reveal

The character-by-character “typing” effect is a direct consequence of the
hardware, not a stylistic choice. You can only safely write to VRAM during
**vblank**, ~160 bytes per frame. So the text printer:

- holds a pointer into the (decompressed) string and a “chars to print this
  frame” rate,
- each frame, queues the next few glyph tiles into the **VRAM buffer**,
- the NMI handler flushes that buffer to the nametable during vblank.

Print one glyph per frame and you get the classic slow DQ crawl; print four and
it’s faster. Either way it’s the same mechanism — you literally cannot dump a
whole paragraph in one frame, so the reveal is free.

-----

## How This Maps to Your Build

Concrete recommendations for an NES RPG from scratch:

- **Mapper:** go **MMC1 or MMC3**, not NROM. RPGs are ROM-hungry (maps + monster
  tables + a mountain of text), and you’ll want bank switching. MMC3 also gives
  you a scanline IRQ, handy for a fixed status/text area.
- **Map data:** metatile grid (16×16), with RLE on top for towns/dungeons that
  have big repeated regions. Keep a per-metatile collision/trigger flag.
- **Movement:** grid-locked, 16 pixels at a time, like DQ. This sidesteps the
  NES’s two-nametable scrolling glitches — you redraw a row/column as the camera
  steps, and never deal with sub-tile scroll seams.
- **Actors:** struct-of-arrays for hero + NPCs. The hero is a 16×16 metasprite;
  NPCs reuse the same draw routine.
- **Monsters:** ROM stat tables indexed by ID (parallel arrays), monster art as
  background tiles blitted into the battle window, encounter tables per zone.
- **Text:** build the windowing + string interpreter early — control codes,
  a VRAM-buffer-fed typewriter printer, and dictionary compression from the
  start (retrofitting compression later is painful).
- **The golden rule:** never touch $2006/$2007 outside vblank. All map draws,
  text, and window changes go through a RAM VRAM-buffer that the NMI flushes.
  This single discipline prevents the majority of “why is my screen glitching”
  problems.

A sensible build order: boot/init → load a map and walk a grid-locked hero
around → window + text engine → menus → battle state machine → encounter system
→ monster data + battle rendering → save system. Text and movement first because
everything else sits on top of them.

# [Game Title] — NES RPG Design Doc

> This doc is written to be handed to Claude Code. It is a **spec + hardware
> contract + data-format definition**, not a vision pitch. The vision lives in
> §1; everything after it is the binding contract Claude builds against.
> 
> Keep the **Hardware Contract (§2)** mirrored into the repo’s `CLAUDE.md` so it
> is in context for every session.

-----

## 1. Vision (the only “soft” section)

- **Elevator pitch:** [one sentence — e.g. “a short, cozy RPG where every town
  is bursting with odd characters.”]
- **Scope target:** [e.g. ~2–3 hours, 4 towns, 2 dungeons, ~25 enemy types.]
- **The hook is visual variety + personality.** That ambition — not the
  mechanics — sets the technical floor. Treat the art/character count as the
  spec, the mechanics as deliberately simple.
- **Out of scope (write this down so it stays out):** [scrolling combat? voice?
  large party? overworld vehicles? — list what you are NOT doing.]

-----

## 2. Hardware Contract  ← mirror into CLAUDE.md

Non-negotiable rules. Claude must follow all of these in every file.

- **Mapper:** UxROM, CHR-RAM. Core engine + reset + NMI live in the **fixed**
  16KB bank. Content (graphics, text, maps) lives in switchable banks.
- **Save model:** [ password  |  battery SRAM ]. (Battery ⇒ must move to
  MMC1/MMC3. Decide now; do not revisit mid-build.)
- **PPU discipline:** NEVER write $2005/$2006/$2007 outside vblank. All
  nametable/palette updates go into a RAM **VRAM buffer** and are flushed in the
  NMI handler only. Budget ≈160 bytes/frame.
- **Game loop:** split method — logic in main thread, PPU updates in NMI, music
  every frame even on lag frames.
- **Entities:** struct-of-arrays (parallel arrays indexed by X). Never
  array-of-structs.
- **Tiles:** 256 BG + 256 sprite tiles resident at once. Visual variety = tileset
  **swaps behind a fade**, never cramming. A small core set (font, window
  borders, hero, UI) stays resident and is never swapped.
- **Sprites:** 8-per-scanline hardware limit. Stationary NPCs are **background
  tiles**. Only moving actors (hero + wandering NPCs) consume OAM.
- **Movement:** grid-locked, 16px steps. Redraw one row/column per camera step;
  no sub-tile scrolling.
- **Stack:** 256 bytes total. No deep call chains; use jump tables / the RTS
  trick.
- **Cross-bank calls:** use [a trampoline routine — define it]. Engine never
  assumes all code is reachable in one bank.

### Known traps (we avoid these on purpose)

- PPU writes during rendering → glitches. (Buffer + NMI flush.)
- Too many hardware sprites on a line → flicker. (NPCs as BG.)
- CHR-RAM tileset copy takes multiple frames → do it **behind a screen fade**.
- Forgetting to re-set scroll after any $2006 write.
- Exceeding vblank byte budget in one frame.

-----

## 3. Cartridge & Memory Map

- PRG size: [128KB / 256KB] — most goes to **content**, not code.
- Bank layout: [Bank table — what lives where. Fixed bank = engine. Bank N =
  town tilesets, Bank M = monster graphics + stats, Bank K = text/script, etc.]
- RAM budget ($0000–$07FF):
  - ZP: entity arrays + pointers + scratch
  - $0200–$02FF: OAM shadow (reserved)
  - $0300–$03FF: VRAM buffer
  - $0400–$04EF: collision map (240B)
  - $04F0–$07FF: game state, flags, text-engine state
- CHR-RAM plan: which tilesets exist, their decompress size, which screen states
  trigger a load.

-----

## 4. Data Formats (the heart of the doc — be precise)

Define these as byte layouts. Claude builds one interpreter per format, then
content is just data.

### 4.1 Metatiles & maps

- Metatile = 4 tile indices (TL,TR,BL,BR) + palette + collision flag.
- Map = grid of metatile IDs. [RLE? per-screen rooms? specify.]

### 4.2 Tileset manifest

- Per area: [list of CHR blobs to load, palette set, metatile set].
- Trigger: area-enter event ⇒ fade out ⇒ stream tileset ⇒ fade in.

### 4.3 Monster table (struct-of-arrays in ROM)

- Parallel arrays by monster ID: `hp, atk, def, agi, xp, gold, behavior_id`,
  plus `graphic_id` → CHR blob + battle-window layout.
- Battle rendering: blit monster into the **background** nametable inside the
  battle window. (Groups = multiple blits.)

### 4.4 Text / script format

- Glyph bytes (1 tile each) + control-code range:
  `newline, end, wait-for-button, open/close window, name-substitution, [text-speed], [token-expand]`.
- **Dictionary/token compression** from day one (retrofitting is painful).
  Define the token table location + how the printer expands tokens.
- Printer feeds N glyphs/frame into the VRAM buffer (the typewriter reveal).

### 4.5 Palette sets

- 4 BG + 4 sprite sub-palettes per area. Reuse tilesets under different palettes
  for cheap mood variety (dusk / swamp / cave). Specify per-area palettes.

-----

## 5. Systems (deliberately small)

For each: one paragraph + which data formats it touches. Keep them minimal.

- Movement & collision: [grid, metatile flags]
- Encounters: [step counter + per-zone tables + RNG]
- Battle: [state machine: menu → player act → enemy act → resolve → check]
- Menus/inventory: [windowing + cursor]
- Save: [password scheme OR SRAM layout]
- Audio: [hooks to the sound engine; runs every frame]

-----

## 6. Build Milestones (each = a runnable .nes + a success criterion)

Prompt Claude one milestone at a time. Verify the ROM in FCEUX/Mesen before the
next. Do not advance on unverified milestones.

|#|Milestone        |Observable success criterion                            |
|-|-----------------|--------------------------------------------------------|
|0|Boot + init      |Correct init sequence; solid-color screen, no glitch    |
|1|Map + hero       |Grid-locked hero walks a tile map, collision works      |
|2|Text engine      |Window opens; text types in; wait-for-button; closes    |
|3|Tileset streaming|Area change fades, swaps CHR-RAM, fades back in clean   |
|4|NPCs             |Stationary NPCs as BG tiles; one wandering NPC as sprite|
|5|Encounters       |Step counter triggers battle from correct zone table    |
|6|Battle render    |Monster blits into battle window; group layout correct  |
|7|Battle loop      |Full turn cycle; HP/XP/gold; win/lose transitions       |
|8|Save             |Password or SRAM round-trips game state                 |
|9|Content + polish |Pour in towns/monsters/text via the data formats        |

-----

## 7. Asset Pipeline

- Tile editing: [YY-CHR / NES Screen Tool] → `.chr` / compressed blobs.
- Compression: [scheme + the script that produces blobs]. Claude can write the
  converter; specify input → output.
- Map editing: [Tiled + export script?] → metatile arrays.
- Where art enters the ROM: [bank assignments].

-----

## 8. How We Work With Claude Code

- **Per session:** one milestone or one subsystem. State the success criterion
  in the prompt. Reference the relevant §here by number.
- **On failure:** paste concrete debugger output — nametable viewer state, CPU/PPU
  log, frame screenshot — not a description of the symptom.
- **Standing rules** live in `CLAUDE.md` (a copy of §2) so they bind every prompt.
- **Commit per verified milestone.** Keep ROM, build, and a test note together.
- **Toolchain:** ca65/ld65; test in FCEUX (debugger) and Mesen (accuracy).

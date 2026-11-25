# Loading screen and pause menu: implementation spec

For the session that builds the level loading screen, the level pictures and the new pause menu. It says what to build, where the designs and pictures are, what is decided and what still needs Roni.

**Status:** built, together with the campaign, the main menu, settings and controls screens the spec left for later. `docs/ui.md` and `DESIGN.md` now hold how each works; this file stays for where the designs and pictures came from. "What exists today" below describes main before that work.

Read `CODING_STANDARDS.md`, `docs/ui.md` and `docs/web-constraints.md` first, as `CLAUDE.md` says.

## Where the design is

The screens are drawn in a Pencil file outside the repo. Read it only through the Pencil MCP tools (`mcp__pencil__*`); the file is encrypted.

- File: `/Users/roni.helppi/.pencil/documents/07d420e1-2194-4c38-b4b2-bc023df7680c/untitled.pen`
- The whole menus spec: frame `BAWw6`, "Final spec". Every screen is 1152 × 648, the game's design size.

| Section in `BAWw6` | Section frame | Screens |
|---|---|---|
| Loading screen | `zj56q` | Level 1 `Bp2N1`, Level 2 `F4jzL5` |
| Pause menu | `XVC4G` | Paused `iPVkL`, Paused during the tutorial `Q5gFvD`, Settings from the pause menu `b60NAA` |
| Campaign (the level cards) | `AylTS` | Picked level not started `vXT1d`, and three more states |

The numbers below are read from those frames. Where this file and the frames disagree, the frames win; say so in the PR.

## What exists today

As of main at `4982f2b` (2026-11-22). No open PR or issue covers the menus; check again before starting.

- **Loading:** `core/scene_flow/scene_flow.gd` is an autoload that fades to one black card, "Loading…" over a 320 px bar, for every scene change. It loads the next scene's files and draws its materials under the card.
- **Pause:** `ui/pause_menu/` is a centred column: Skip tutorial (tutorial only, on top), Resume, Settings, Main menu. Settings is `ui/settings/settings_menu.tscn`, opened over it.
- **Screen blur:** `ui/screen_blur.gdshaderinc` and `ui/glass.gdshader` blur the screen behind the HUD's panels.
- **Not built:** the campaign screen, levels as something the player picks, the controls screen, and the main menu's slanted buttons. `ui/main_menu/` is still a centred column over one saved run.

So two parts of this work lean on things that don't exist yet. See Order of work.

## The level pictures

Two renders, 2304 × 1296, 16:9. Each is a level's loading image, and its card in the campaign screen is a crop of the same image.

| Level | Name in the design | Star system | Picture |
|---|---|---|---|
| 1 | Your first shift | Vela | The bus coming from the Moon towards Terra |
| 2 | Rough ride | Lyra | The bus in the asteroid field, Brume behind |
| 3 | Return to home | not decided | None yet |

The names are placeholders from the design.

**Where the files are.** Nothing is in the repo yet. The originals sit beside the Pencil file, which outlives any worktree:

- `/Users/roni.helppi/.pencil/documents/07d420e1-2194-4c38-b4b2-bc023df7680c/images/level_1_loading.png`
- `/Users/roni.helppi/.pencil/documents/07d420e1-2194-4c38-b4b2-bc023df7680c/images/level_2_loading.png`

The script that renders them, `render_level_art.py`, is in `art/banner/level_art/` of the worktree `wonderful-robinson-e5cc0c`. `art/` is gitignored, so it is in no other checkout. It opens `art/banner/banner.blend`, one folder up from it, which is in that worktree only too. If the worktree is cleaned up, both are gone.

**The card crop.** Cut the card from the loading image; don't ship a second file. As shares of the image's width and height, from its top left corner:

| Level | x | y | width | height |
|---|---|---|---|---|
| 1 | 0.2643 | 0.0247 | 0.4514 | 0.9498 |
| 2 | 0.4258 | 0.0502 | 0.4089 | 0.8603 |

Both crops are 304:360, the card's shape. In pixels of the 2304 × 1296 originals they are 609, 32, 1040, 1231 and 981, 65, 942, 1115.

**Decided:**
- They go in `shared/level_art/`, since two things use them: the loading card in `core/scene_flow/` and the campaign screen in `ui/` (`CODING_STANDARDS.md`, Layout). Keep each crop beside its picture's path, in whatever describes a level.
- Ship them at 1920 × 1080. The game's design size is 1152 × 648, so that is sharp on most screens at a third less memory.
- Import them lossy. They are flat colours and soft gradients, and 3 MB of PNG each is too much for the web build.

## Loading screen

Design: `Bp2N1` and `F4jzL5`.

### When it shows

**Decided:**
- Entering a level shows that level's picture: Play or Continue in the campaign screen, Continue in the main menu, and Restart.
- Every other scene change keeps today's black card: back to the main menu, the voice lab, the mixer.
- A level with no picture keeps the black card.

`SceneFlow.go_to(path)` knows only a path today. It needs to be told what to show: the picture, the level's name and the bar's two planets. Keep the black card as its default, so existing callers don't change.

`SceneFlow` draws the next scene's materials under the card to compile their shaders. The picture covers the whole screen and is opaque, so that still works; keep it that way.

### Layout

Everything sits in the bottom band, 96 px in from the sides and 48 px up from the bottom, so the bus and planets stay clear.

- **Picture:** fills the screen, cover.
- **Fade behind the text:** over the bottom 264 px, `#0B0920` from clear at the top, to 60 % at 35 % of the way down, to 95 % at the bottom.
- **"Loading…":** bottom left, above the name. Baloo 2, 16 px, weight 600, `text-dim`.
- **Level name:** under it. Baloo 2, 52 px, bold italic, `text`.
- **Tip:** bottom right, 340 px wide, its bottom 10 px above the name's.
  - Heading row: a 16 px lightbulb in `bus` yellow, then "Tip" in Baloo 2, 14 px bold, `text`, 6 px apart and centred on each other.
  - Body: 4 px under it, starting at the icon's left edge. Figtree, 15 px, line height 1.4, `text-dim`, wrapping.
- **Bar:** 20 px under the name and tip, across the full 960 px.
- **Text shadow:** every text has a soft shadow, `#0B0920` at 80 %, 10 px blur, 1 px down, to read over Terra and the pale rocks.

The colour names are the Pencil file's variables; `ui/theme.tres` has the game's own for the same colours.

### The bar

It is the route line from the HUD, used as a progress bar.

- A 22 px planet disc at each end: a dark base with a lit side, as the HUD's planet icons.
- Between them, 6 px apart: the loaded part, a 3 px line in `route` orange; the bus marker, a 28 px disc in `#1D1842` with an 18 px bus icon in `bus` yellow; then what is left, a 3 px line in `track`.
- The marker sits at the end of the loaded part and moves with `SceneFlow`'s progress, 0 at the left disc and 1 at the right.

**Decided:** the discs are two of the level's own planets, where the bus starts and somewhere it goes.

| Level | From | To |
|---|---|---|
| 1 | Moon, `#6E6C8A` with `#DBD9ED` lit | Terra, `#3F7A45` with `#80D157` lit |
| 2 | Hither, `#3F7D6B` with `#6AD1A0` lit | Yon, `#A8506A` with `#FF8FA8` lit |

Reuse the HUD's planet icon if it can draw these; don't draw a second one.

### Tips

**Decided:**
- One tip, picked at random each time the screen shows, not the one shown last time.
- A tip may belong to one level; the rest show on any.
- The tip holds still while loading. No cycling.

The two in the design are placeholders. A list to start from; check each against `DESIGN.md` before using it, and let Roni cut or reword:

- Hold Frameshift to leave a planet once your passengers are on board.
- Flying through the asteroids slows the bus and bumps your passengers. Look for the gaps. (Level 2 only.)
- Flying close to the star heats the bus. Steer away before it overheats.
- Refuel at a station before a long trip. An empty tank means a tow.
- Esc opens the menu at any time.

### Motion

Keep `SceneFlow`'s fade, 0.25 s each way. The marker follows the progress with no easing of its own, as the bar does today. Nothing else moves, so Reduce motion changes nothing.

## Pause menu

Design: `iPVkL`, `Q5gFvD`, `b60NAA`.

### What stays

Everything `ui/pause_menu/pause_menu.gd` does today: Esc and the pause button open it, Esc and Resume close it, leaving browser fullscreen opens it, `hold` and `release`, the 0.2 s fade in, and closing at once. Main menu still leaves through `SceneFlow`.

### Backdrop

The game as it stood, blurred, under `#141230` at 60 %, the feature hints' dim.

- Blur it with `ui/screen_blur.gdshaderinc`, about 14 px at the design size. Never read the screen with `filter_linear_mipmap` (`docs/web-constraints.md`, Costs).
- The HUD must be blurred too, not only the 3D scene. The research screen and the transmission panel already put glass over the paused game from their own CanvasLayers (`game/research/research_screen.tscn`, `game/transmissions/transmission_panel.tscn`, layer 5); the pause menu is on layer 10. Do it as they do, and check in a capture that the HUD under it is blurred.
- **Not measured:** the cost of a full-screen blur in Firefox. The game is paused under it, which helps. If it is too slow, fall back to the dim alone at about 80 %, and say so in the PR.

### Layout

The main menu's layout from the spec (`D662E`), with "Paused" where the logo sits. Buttons are slanted plates, leaning about 10° to the right, each a step left of the one above so their edges make one slanted line.

| Item | x | y | Size | Look |
|---|---|---|---|---|
| "Paused" | 96 | 128 | Baloo 2, 64 px, bold italic | `text` |
| Resume | 82 | 232 | 228 × 66 | Light plate, play icon and "Resume" in `ink`, 22 px bold italic |
| Restart level | 316 | 232 | 78 × 66 | Quiet plate, 22 px rotate-ccw icon, no label |
| Settings | 71 | 316 | 308 × 44 | Quiet plate, 18 px icon and 17 px bold italic label in `text` |
| Controls | 60 | 376 | 308 × 44 | As Settings |
| Main menu | 50 | 436 | 308 × 44 | As Settings |
| Skip tutorial | 37 | 508 | 308 × 44 | As Settings; tutorial only |

- Resume and Restart level share the top row, 12 px apart, and together are as wide as the buttons under them.
- Resume has no second line. The main menu's Continue names the level; here the player knows.
- A quiet plate is `row-hover` (`#FFFFFF24`). The light plate is `text` (`#F4F1FF`).
- The build label stays bottom right. No Credits link here.

### Behaviour

**Decided:**
- **Settings** opens the settings screen over the same blurred game. Back and Esc return to the pause menu. Reset campaign is left out here, as Delete save is today (`offers_save_deletion`), for the reason in `DESIGN.md`, Save game: the run in play would save over it.
- **Controls** opens the main menu's controls screen (the screen in state `DPE3P` of the spec) the same way. Not drawn over the blur; it follows Settings.
- **Restart level** asks first, with the campaign screen's confirm dialog (`G6qd8S`): "Restart Level 2?", Cancel and Restart level. Not drawn over the pause menu. Its tooltip: "Restart level".
- **Skip tutorial** moves from above the others to under them, 12 px further apart than the rest. This changes `docs/ui.md` and the pause menu's test.
- **Focus** starts on Resume, as now. Tab order runs Resume, Restart level, Settings, Controls, Main menu, Skip tutorial.
- **Hover, press and focus** look as the main menu's slanted buttons do, once those are built. The spec's variables name them: `control-hover`, `control-active`, `primary-hover`, `primary-active`.

## Order of work

1. **Pause menu, new look.** The backdrop, the slanted layout, "Paused", and Skip tutorial's new place. The slanted plate doesn't exist yet: build it once in `ui/`, for the main menu to reuse later. Settings opens today's settings panel unchanged; its new look in the spec is separate work.
2. **Level pictures into the repo,** with their crops.
3. **Loading screen.** Needs to know which level is loading. Until the campaign screen exists, pick the picture by the star system the run starts or continues in: level 1's for Vela, level 2's for Lyra, the black card for any other.
4. **Waiting on other work:** the Controls button needs the controls screen; Restart level needs levels and the confirm dialog; the card crops are used by the campaign screen. Leave each out until its screen exists; don't stub them.

Each of 1 to 3 can be its own PR.

## Also change

- `docs/ui.md`: the pause menu's lines (Pause menu, around line 447) and a new entry for the loading screen.
- `DESIGN.md`, Scenes and flow: the diagram and the loading card.
- `test/ui/pause_menu/pause_menu_test.gd`: Skip tutorial's place, and the new buttons as they land.
- `CONTEXT.md`: "level" and "campaign" aren't in the glossary yet. Add them with the campaign work, not here.

## For Roni to decide

- Whether the loading screen should ship before the campaign screen exists, picking its picture by star system (step 3), or wait for it.
- The tips: the list above is a draft.
- Level 3's picture and star system.

## Done when

- `uv run tools/check.py all` passes.
- `capture` of the pause menu and of the loading screen at `--size 1152x648` matches the Pencil frames, but for what step 4 leaves out; paste the frames under Evidence.
- The preview build holds its frame rate with the pause menu open in Firefox. Needs a visual check: `test/previews/pause_menu_preview.tscn`.

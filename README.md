# Dino Surf

The Chrome Dino desert has flooded. You don't control the dino — you control the water.

## Getting started

1. Install **Godot 4.7.2** (standard build, not .NET — C# can't export to web).
2. Install [Git](https://git-scm.com/) (Git LFS comes with it), then run `git lfs install` once.
3. Clone this repo, open Godot, Import → pick `project.godot`.
4. Press F5 to play.

## How to play

Markers on the right edge warn of what's coming (green cactus, red buoy, white gull), at the height you'll meet it.

Surf as far as you can. The score (top right, Chrome Dino style) is the distance; your best is saved.
Like the Chrome Dino, the pace picks up steadily as your score climbs (combos count) (and the water tilts downhill to show it);
the waves carry you up and down, and splash when you land, but never change your speed, and the colours flip every 1000 points. Kills in a row build a combo for bonus points (25, 50, 75...);
from three in a row a big COMBO counter shows up (it's at full speed around 3500 points); now and then
a buoy floats by.
A spin that misses leaves the dino panicked (scared face, red board) until it lands: no spin left.

| Key | Action |
| --- | --- |
| Down, then Up | Leap, spinning |
| Down (in the air) | Fast fall |
| Left / Right | Lean the water back / forward a little: slower / faster |
| Up (or click / tap) | Spin the board (a leap comes with a free spin, so Up mid-air still spins) (on the water or in the air, one per jump): slices a cactus, knocks a gull away. Buoys are solid: go over them |
| Space | Bulge the water ahead into a ramp |
| R | Restart |
| V | Switch between the 3D pop-up view and the flat 2D view |
| L (start screen) | Story: the lore slideshow (or click the Story button) |
| M | Mute / unmute |

## Publishing to itch.io

The `Web` export preset is set up for itch.io (single-threaded, so it runs without special server headers).

1. Install the Godot 4.7.2 export templates once (Editor → Manage Export Templates), at least the web ones.
2. Export: Project → Export → Web → Export Project, to `export/web/index.html`; or from the command line:
   `Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" export/web/index.html`
3. Zip the *contents* of `export/web/` (so `index.html` is at the top of the zip).
4. On itch.io: Create new project → Kind of project: **HTML** → upload the zip → tick
   **This file will be played in the browser** → Viewport dimensions **1280 × 720** → tick **Fullscreen button**.

`export/` is git-ignored: upload builds, don't commit them.

## Code map

`main.tscn` is split into one node per system. Tree order is also tick order, so input and spawning run before the water moves.

| Node | Script | Job |
| --- | --- | --- |
| `Main` | `main.gd` | Score, wipeout and restart; wires the systems' signals together |
| `Controls` | `controls.gd` | Player input → world tilt, water pushes, leap, spin. All control schemes live here |
| `Tsunami` | `tsunami.gd` | The always-on hump behind the dino |
| `ObstacleSpawner` | `obstacle_spawner.gd` | Plants cacti (they stand still; the swell moves around them), checks slices and hits. Uses `flight_planner.gd` so every cactus is clearable |
| `GullSpawner` | `gull_spawner.gd` | Sends in seagulls, checks knocks and hits |
| `Background` | `backdrop.gd` | Pixel-art desert layers (far mountains, mountains, ground, cacti), each a `Backdrop` that tiles and scrolls with parallax; in 3D each stands on its own card at its `depth` |
| `Water` | `water.gd` | Spring-chain surface plus travelling swells |
| `Hazards` | — | Holds the spawned cacti (`obstacle.gd`) and gulls (`seagull.gd`), drawn behind the dino |
| `Dino` | `dino.gd` | Floating, surfing, leaping, spinning, crashing |
| `Camera2D` | `game_camera.gd` | Follow, lean with the tilt, shake |
| `View3D` | `view_3d.gd` | Redraws the 2D game as a 3D pop-up book: each layer on a paper card at its own depth, the water extruded into a slab. V toggles the flat view |
| `Sounds` | `sounds.gd` | Ocean waves on the start screen, the surf theme during a run, wipeout and spin sounds, a chime every 1000 points |
| `HUD` | `hud.gd` | Score and the WIPEOUT screen |
| `HUD/Title` | `title_screen.gd`, `lore_slideshow.gd` | Start screen: the animated handheld (`art/ui/title_handheld_01.png`, made from the artist's GIF with `tools/gif_to_strip.py`) over the paused game; any key starts |

## 3D pop-up view

The game logic is all 2D; `View3D` only changes how it looks. Each layer node under `Main` (`Background`, `Hazards`, `Dino`) is rendered into its own texture and shown on a paper card (white cut-out border, a few px of thickness) at its own depth, and the water's surface line is extruded along z into a slab the cards stand in. Cards further back are scaled up so they line up with the 2D game when the camera is at rest, so hit boxes still match what you see.

- **Adding art:** a new background layer is another `Backdrop` node under `Background` (set its texture and depth). Cactus/gull art goes in their scripts (they live under `Hazards`), dino art in `dino.gd`. Anything drawn must be inside one of those layer nodes, or it shows up on every card.
- **Water:** the slab is textured with `art/backgrounds/water_01.png`, with `water_waves_01.png` as the foam along its front edge. Both are pinned to the surface at their waterline row, so the glints ride the waves.

## Preparing art

Artists export big (pixel art blown up 20×, drawn art on 3840² canvases). `tools/prepare_art.gd` turns those exports into the game-ready PNGs in `art/`: pixel art back to 1 px per art pixel, drawn art cropped and shrunk to 2× its in-game size. Re-run it after the art changes:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/prepare_art.gd -- "<artist folder>"
```

The file list (source → `art/` name) is at the top of the script.
- **Tuning:** depths, camera pitch / FOV, paper border and thickness, and water colours are exported on `View3D`.
- **Depth cues** (`View3D` → *Depth cues*): the dino casts a soft shadow on the water that shrinks as it flies, and
  far layers fade toward the sky.

## Folders

```
scenes/   one .tscn per system
scripts/  GDScript only
art/      PNGs from artists, by category: art/dino/, art/obstacles/, art/backgrounds/, art/ui/
audio/    audio/music/, audio/sfx/
```

## Team rules

- **One owner per scene.** Only edit a scene you own; ask in chat otherwise. `main.tscn` is owned by the producer.
- **Art handoff:** name files `thing_action_01.png` (e.g. `dino_ride_01.png`), drawn at 1× pixel scale for a 640×360 screen. A programmer wires them in.
- **No AI-generated art.** AI is fine for code and docs.
- **Branches:** work on a branch (`water-prototype`, `dino-sprites`), open a pull request, merge to `main`.
- **Builds:** web build to a private itch.io page weekly.

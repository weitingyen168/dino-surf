# Dino Surf

The Chrome Dino desert has flooded. You don't control the dino — you control the water.

## Getting started

1. Install **Godot 4.7.2** (standard build, not .NET — C# can't export to web).
2. Install [Git](https://git-scm.com/) (Git LFS comes with it), then run `git lfs install` once.
3. Clone this repo, open Godot, Import → pick `project.godot`.
4. Press F5 to play.

## Current prototype

Two control schemes to playtest against each other:

| Key | Action |
| --- | --- |
| Space / Up / W / click / tap (hold) | Act |
| Tab | Switch scheme |
| R | Reset |

- **A — shape the wave:** holding raises the water just behind the dino.
- **B — tilt the world:** holding tips gravity forward.

Tuning values are exported on each node in `main.tscn` — tweak them in the Inspector.

## Code map

`main.tscn` is split into one node per system. Tree order is also tick order, so input and spawning run before the water moves.

| Node | Script | Job |
| --- | --- | --- |
| `Main` | `main.gd` | Score, wipeout and restart; wires the systems' signals together |
| `Controls` | `controls.gd` | Player input → world tilt, water pushes, leap, spin. All control schemes live here |
| `Tsunami` | `tsunami.gd` | The always-on hump behind the dino |
| `ObstacleSpawner` | `obstacle_spawner.gd` | Plants cacti (they stand still; the swell moves around them), checks slices and hits. Uses `flight_planner.gd` so every cactus is clearable |
| `GullSpawner` | `gull_spawner.gd` | Sends in seagulls, checks knocks and hits |
| `Background` | — | Pixel-art background sprites go here; in 3D they sit on the furthest card |
| `Water` | `water.gd` | Spring-chain surface plus travelling swells |
| `Hazards` | — | Holds the spawned cacti (`obstacle.gd`) and gulls (`seagull.gd`), drawn behind the dino |
| `Dino` | `dino.gd` | Floating, surfing, leaping, spinning, crashing |
| `Camera2D` | `game_camera.gd` | Follow, lean with the tilt, shake |
| `View3D` | `view_3d.gd` | Redraws the 2D game as a 3D pop-up book: each layer on a paper card at its own depth, the water extruded into a slab. V toggles the flat view |
| `HUD` | `hud.gd` | Stats line and the WIPEOUT screen |

## 3D pop-up view

The game logic is all 2D; `View3D` only changes how it looks. Each layer node under `Main` (`Background`, `Hazards`, `Dino`) is rendered into its own texture and shown on a paper card (white cut-out border, a few px of thickness) at its own depth, and the water's surface line is extruded along z into a slab the cards stand in. Cards further back are scaled up so they line up with the 2D game when the camera is at rest, so hit boxes still match what you see.

- **Adding art:** put background pixel art under `Background`, cactus/gull art in their scripts (they live under `Hazards`), dino art under `Dino`. Anything drawn must be inside one of those layer nodes, or it shows up on every card.
- **Tuning:** depths, camera pitch / FOV, paper border and thickness, and water colours are exported on `View3D`.

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

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

Tuning values are exported on the `Main`, `Water` and `Dino` nodes — tweak them in the Inspector.

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

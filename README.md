# Auto Shooter — Godot 4 (GDScript)

A top-down auto-shooter on a large scrolling map. You are the blue circle. You
move; shooting is automatic and auto-aims at the nearest enemy. The camera
follows you across a world much bigger than the screen, so you explore to
survive. Enemies swarm you from every direction. Rare glowing allies are
scattered far across the map — go find one, walk into it, and it joins your
orbiting ring and shoots alongside you. Off-screen **arrows** point the way:
green toward allies, red toward the nearest incoming enemies. A **minimap**
in the corner shows the whole world at a glance, and everything has **sound**.

Built and verified against Godot 4 (tested headless on 4.3; written to the
stable 4.x GDScript API, so it runs on your `Godot_v4.7.1-stable_win64`).

## How to run

1. Open the Godot editor.
2. **Import** → select the `project.godot` in this folder → **Import & Edit**.
3. Press **F5** (Play). The main scene is `scenes/Main.tscn`.

No external assets — every visual is drawn in code, so there's nothing to
download or re-link.

## Controls

- **Move / explore:** WASD or Arrow keys (the camera follows you)
- **Fire:** automatic (auto-aims nearest enemy)
- **Find allies:** follow the **green arrows** to scattered allies, walk into one to collect it
- **Watch threats:** **red arrows** point to the nearest off-screen enemies
- **Restart:** R (or Space / Enter) on the Game Over screen

## What's in the box

Enemies spawn from a ring outside the screen and scale up each wave (more HP,
more speed, more per spawn, shorter spawn intervals). Allies drop in
periodically and orbit you once collected, adding more auto-fire. There's
juice throughout: hit flashes, death bursts, pickup sparks, and screen shake.

## Project structure

```
project.godot            Config, autoloads, display, GL-compatibility renderer
icon.svg                 Window/app icon
scenes/
  Main.tscn              Root — builds the whole world tree in code
  Player.tscn            CharacterBody2D + player.gd
  Ally.tscn              CharacterBody2D + ally.gd
  Enemy.tscn             CharacterBody2D + enemy.gd
  Bullet.tscn            Area2D + bullet.gd
scripts/
  config.gd     (autoload) Every tunable number + palette + input binding
  event_bus.gd  (autoload) Global signals — systems stay decoupled
  game_manager.gd (autoload) Run state: score, wave, allies, game over/restart
  main.gd        Builds the world, screen shake, background grid, restart key
  spawner.gd     Wave logic: enemy ring spawns + ally pickups, difficulty curve
  hud.gd         All UI, built in code, reads only from EventBus
  fx.gd          Listens to juice signals, spawns effects
  effect.gd      One-shot particle burst / spark
  indicators.gd  Off-screen edge arrows for allies (green) & enemies (red)
  minimap.gd     Corner minimap: world, player, allies, enemies, view rect
  audio_manager.gd (autoload) Plays SFX from EventBus signals, pooled + throttled
audio/                     Procedurally generated SFX (.wav) + import files
tools/make_sfx.py          Regenerate the SFX (Python + numpy); deterministic
  bullet.gd      Projectile
  player.gd      Movement + health + auto-shoot (extends Unit)
  ally.gd        Collectible + orbit-follow + auto-shoot (extends Unit)
  enemy.gd       Swarmer: hunt, contact damage, separation
  components/
    unit.gd      Shared base: target acquisition + firing (Player & Ally reuse)
```

## Built to be extended

This is a foundation for the "multiple things in future" you mentioned.
A few deliberate seams:

- **`config.gd`** — all balance lives here. Want faster bullets, tankier
  enemies, a bigger ally ring? Change one number. Difficulty curves are
  functions (`enemy_health(wave)`, `spawn_interval(wave)`, …) so you can
  reshape the whole game's pacing in one place. Map size is `WORLD_SIZE`;
  ally rarity is `PICKUP_INTERVAL` / `PICKUP_MAX_ON_FIELD` /
  `PICKUP_MIN_DIST_FROM_PLAYER`; arrow behaviour is the `INDICATOR_*` values.
- **`event_bus.gd`** — add a signal, emit it from anywhere, connect from
  anywhere. New systems (audio, upgrades, combos) plug in without touching
  gameplay code.
- **`components/unit.gd`** — shared shooting. New unit types (a shotgun ally,
  a sniper) just `extend Unit` and override stats or `_fire_at`.
- **`main.gd`** builds the tree in code, so there's no fragile scene wiring to
  fight with as the project grows.

Ideas that slot in cleanly next: enemy variety (fast/tank/ranged), ally
weapon types, XP/level-up upgrade picks, pause menu, audio, object pooling for
bullets/enemies at high counts, and a title screen.

## Notes

- Input actions are registered at runtime in `config.gd`, so the game never
  depends on the editor's InputMap serialization surviving a version bump.
- Rendering uses the GL-compatibility backend for the widest hardware support.

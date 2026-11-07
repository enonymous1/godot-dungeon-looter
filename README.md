# Godot Dungeon Looter

## Description

A click-to-move dungeon looter in Godot 4, inspired by classic
action RPGs. Click the floor to move, click an enemy to walk up
and attack it, kill things, take their stuff, equip the good
drops, and clear the floor.

This is the **starter slice (v0.1.0)**: one dungeon floor, one
hero (the Warrior), two enemy types, and rarity loot with an
inventory. It is a separate project, not a port of anything — the
loop is the game.

### The loop

- **Move** — left-click the floor. The Warrior walks there.
- **Fight** — left-click a skeleton or zombie. He walks into range
  and swings until it dies (or you click away). 10% crit chance,
  armor reduces incoming damage, minimum 1 damage per hit.
- **Level** — XP: 25 per skeleton, 35 per zombie. 100 XP to reach
  level 2, 200 more to level 3. Each level is +10 max HP and +1
  potion (max 5).
- **Loot** — skeletons drop loot 35% of the time, zombies 45%.
  Rarity: 60% Normal, 30% Magic (+1 affix), 10% Rare (+2 affixes).
  Weapons (Rusty Sword up to Battle Axe) and armor (Leather up to
  Plate) with +damage, +armor, +strength, and +vitality affixes.
  Click a drop on the floor to walk over and pick it up.
- **Equip** — the inventory panel (right side, 12 slots) shows what
  you carry. Click a weapon or armor to equip it; its stats apply
  immediately — check the damage on your next swing. Equipped gear
  goes back to the bag when you equip something better.
- **Survive** — Q (or 1, or the Drink button) drinks a red potion:
  30 + 10 per level HP. 3 potions to start. Die, and you respawn at
  the entrance at full HP; the dead stay dead.

Clearing the floor (8 enemies, 230 XP total) gets you to level 2
with 130/200 XP toward level 3.

### Controls

| Input | Action |
| --- | --- |
| Left-click floor | Move there |
| Left-click enemy | Walk to it and attack |
| Left-click loot drop | Walk to it and pick it up |
| Q, 1, or Drink button | Drink a potion |
| Click inventory slot | Equip that weapon/armor |

## Prerequisites

- Godot **4.7.2** (stable), standard edition (not the C#/.NET
  one). The project targets 4.7 with the `gl_compatibility`
  renderer, so the Web export runs on WebGL2.
- No API keys, no accounts, no addons, no C#. All art is
  procedural (drawn shapes in a dark dungeon palette) — there are
  no asset files to download.
- To export a standalone build (not needed to play or test), the
  Godot **4.7.2 export templates** (1.28 GB, from the Godot 4.7.2
  release). They are NOT committed and NOT installed in CI.

## Installation

```sh
# 1. Get Godot 4.7.2 from https://godotengine.org/download
#    (Windows: Godot_v4.7.2-stable_win64.exe.zip, ~82 MB).
#    Unzip it anywhere and run the exe — nothing to install.
# 2. Get this project: clone it, or extract the release zip.
git clone https://github.com/enonymous1/godot-dungeon-looter.git
```

Then open the Godot Project Manager, choose **Import**, pick the
project folder's `project.godot`, and click **Import & Edit**.
The first import generates the `.godot/` cache folder (gitignored).

## Local Development

```sh
# Open the project in the Godot editor, or run it headless:
godot --path . --import
godot --path .
```

Press **F5** in the editor to play (1280x720 window); **F8**
stops the run and returns to the editor. The game has never been
seen rendered outside the editor yet — the first launch is the
real visual smoke test.

### Tests

```sh
godot --headless --path . -s res://tests/test_loot_logic.gd
godot --headless --path . -s res://tests/test_combat_logic.gd
godot --headless --path . -s res://tests/test_dungeon_logic.gd
godot --headless --path . -s res://tests/test_scene_smoke.gd
```

Each prints `PASS n/n` and exits 0, or `FAIL ...` and exits 1.
127 checks total (42 loot, 26 combat, 30 dungeon, 29 scene).
The logic tests are deterministic: every roll is passed in as a
float, so the tests pin exact values — rarity thresholds, the
Rare Battle Axe at 12–20 damage, prefix/suffix rolling
independently, the 100/200 XP curve, the double level-up on
exactly 300 XP, and every spawn type having stats and a drop
chance. The scene smoke test drives the real game: target, kill,
loot, equip, level, potion, death, respawn — plus the invariant
that the pickup radius exceeds the player's loot stop distance.

### Project layout

| File | What it does |
| --- | --- |
| `project.godot`, `scenes/main.tscn` | Project + a bare root Node2D; the game is built in code |
| `scripts/loot_logic.gd` | Pure loot logic (rarity rolls, item generation, affixes, derived stats) |
| `scripts/combat_logic.gd` | Pure combat/progression logic (damage, crit, XP curve, potions, enemy table) |
| `scripts/dungeon_logic.gd` | Pure dungeon layout (floor size, walls, spawns, walkability) |
| `scripts/player.gd` | The Warrior: click-to-move, attack, HP/XP/potions, inventory, equip |
| `scripts/enemy.gd` | Skeleton / zombie: aggro, chase, attack, die |
| `scripts/loot_drop.gd` | A drop on the floor: rarity diamond + name label |
| `scripts/dungeon_view.gd` | Draws the floor: stone tiles, walls, torches |
| `scripts/hud.gd` | All interface: HP/XP bars, potions, kills, log, inventory, death overlay |
| `scripts/main.gd` | Composition root: dungeon, spawns, camera, input, loot rolls, death/respawn |
| `tests/` | Headless GDScript tests (see above) |
| `docs/architecture.mmd` | Mermaid diagram of the module layout (see below) |

The three `*_logic.gd` files are pure and scene-free: no nodes,
no I/O, every random input passed in as a float. That is what
makes them testable without the engine running a scene. See
`docs/architecture.mmd` for the module map, and `REVIEW.md` for
the 2026-11-07 staff review (what it found, what it fixed, and
what it deliberately deferred).

### How it works

Combat is click-to-target, classic action-RPG style: clicking an
enemy sets it as the attack target and the Warrior closes the
distance and swings on a 0.6s cooldown. Enemies aggro inside
220–260 px and chase at their own speed (skeletons fast and
frail, zombies slow and tough). Damage rolls inside the attacker's
range, doubles on a crit, and subtracts the defender's armor,
floored at 1. The player's damage is fists (4–7) or the equipped
weapon's range, plus total strength / 4 on both ends.

Loot is generated from explicit rolls, not hidden RNG, which is
what makes it testable: a rarity roll picks the tier, a base roll
picks the item, a prefix roll and a separate suffix roll name it,
then one stat/value roll pair per affix. Magic items get a prefix
("Soldier's", "Sharp", ...), Rare items get a prefix and a suffix
("of the Bear", ...). Affix stats never repeat on one item.

The floor is hand-built, not procedural: 1600x1200 with three
interior walls and door gaps, 5 skeleton and 3 zombie spawns in
fixed spots. `DungeonLogic.is_walkable` is the single source of
truth for what the player can stand on, and the tests assert every
spawn is walkable and has stats and a drop chance.

The HUD is signal-driven: bars and inventory refresh on the
player's `stats_changed` signal, not once per frame. The floor
redraws at 8 Hz (only the torches animate); loot drops bob at
15 Hz.

## Screenshots

No screenshots yet — they are captured from a real play session,
never mocked. The shot list (exact files, what each must show,
and where each goes in this README) is in
[`docs/visual-assets.md`](docs/visual-assets.md): a hero gameplay
shot under the title, a combat-loop GIF in The loop, a loot
close-up in the Loot bullet, and a floor-plan diagram in
How it works.

## What is NOT in v0.1.0

- Rogue / Sorcerer, or any class select — Warrior only.
- Town, NPCs, vendors, gold, or selling loot.
- Descending floors, stairs, or procedural generation — one floor.
- Bosses, elites, shrines, or potion drops (potions come from
  leveling up and respawning).
- Real art, sound, or particles — placeholder shapes and flat
  colors; the dungeon, Warrior, skeletons, and zombies are all
  drawn in code.
- Saving / loading, multiplayer, or a visually verified scene:
  the game imports and runs headless in CI, but this box has no
  rasterizer, so the floor, lighting, and layout have not been
  seen rendered — the first real look is yours in the editor.

## Deployment

There is no deployment yet. The export presets
(`export_presets.cfg`) cover **Windows Desktop** and **Web**
(single-threaded, `gl_compatibility`, so the Web export needs no
special server headers and can be hosted on GitHub Pages — but
the engine WASM is ~40 MB).

To export, install the Godot **4.7.2 export templates** first
(1.28 GB, from the Godot 4.7.2 release — they are NOT committed
and NOT installed in CI), then:

```sh
godot --headless --path . --export-release "Windows Desktop" build/godot-dungeon-looter.exe
godot --headless --path . --export-release "Web" build/web/index.html
```

CI (`.github/workflows/ci.yml`) runs a headless import and all
four test scripts on every push. Exports are deliberately not run
in CI until the templates exist.

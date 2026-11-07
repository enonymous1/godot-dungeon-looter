# Staff review — Godot Dungeon Looter v0.1.0

Review date: 2026-11-07. Reviewer: Muse (staff-level review).
Scope: the whole repo as of commit `fc66c36` (single commit, branch
`main`). This pass applied the fixes below as a follow-up commit;
deferred items are listed, not silently dropped.

## Verdict

Solid starter slice. The separation that matters most — pure,
deterministic logic (`loot_logic`, `combat_logic`,
`dungeon_logic`) under thin scene nodes — was already right, and
the tests already pinned real values instead of asserting
vibes. The review found **one real gameplay bug** (Rare item
names only ever produced 4 of 16 prefix/suffix combinations),
**two silent-misconfiguration holes** (unknown enemy types and
unknown item kinds), **one architectural smell** (`main.gd` was
a 400-line God object holding the whole HUD), and **two
performance wastes** (full-floor redraw and full-HUD refresh
every frame). All are fixed in this pass. Nothing here needed an
architectural rewrite, and no behaviour the player can see
changed except the Rare-name variety fix.

## What changed in this pass

| Area | Change |
| --- | --- |
| `scripts/loot_logic.gd` | Rarity thresholds are named consts (`MAGIC_THRESHOLD`, `RARE_THRESHOLD`); prefix and suffix roll independently (rolls layout is now `[base, prefix, suffix, affix...]`); unknown kinds return `{}` instead of silently building a weapon |
| `scripts/combat_logic.gd` | Enemy attack cooldown and crit chance moved into `ENEMY_STATS` (was a `1.0` and a `0.05` literal in `enemy.gd`); integer-division note on the strength bonus |
| `scripts/enemy.gd` | `setup()` returns `bool`; attack uses the stats-table cooldown/crit; flash duration is a const |
| `scripts/player.gd` | `_swap_equip` takes a kind string, not a bool flag; stop distances and swing duration are named consts; `##` docs on every public method |
| `scripts/dungeon_view.gd` | Redraws at 8 Hz instead of every frame (only torches animate) |
| `scripts/loot_drop.gd` | Bob redraws at 15 Hz; `setup()`-before-`add_child` contract documented |
| `scripts/hud.gd` (new) | All interface extracted from `main.gd`: bars, log, inventory, death overlay; signal-driven via `stats_changed` |
| `scripts/main.gd` | Composition root only (dungeon, spawns, camera, input, loot rolls); `_enemy_near`/`_loot_near` unified into `_nearest_in_radius`; click/pickup radii are named consts; unknown spawn types fail loudly at startup |
| `scripts/dungeon_logic.gd` | `total_enemies()` helper |
| `tests/` | 119 → 127 checks: prefix/suffix independence, unknown kind, per-type cooldown/crit, spawn-type validity, exact 25 XP on a skeleton kill, pickup-radius invariant, unknown enemy setup |
| `README.md` | Rewritten to the required sections (Description, Prerequisites, Installation, Local Development, Deployment) |
| `docs/architecture.mmd` | Real Mermaid module map (new) |
| `docs/visual-assets.md` | Shot list with exact files and README placement (new) |

Tests: **127/127 pass** (42 loot, 26 combat, 30 dungeon,
29 scene). Headless import: 0 errors. 8-second headless run:
clean. Verified from a fresh extraction of the rebuilt zip.

## Findings by pillar

### 1. Best practices & code quality

- **P0 — Rare names were correlated (fixed).**
  `_named()` used one roll for both the prefix and the suffix
  index, so the four prefixes always paired with the same four
  suffixes (`Soldier's … of the Bear`, `Sharp … of Power`, …) —
  4 combinations instead of 16. Prefix and suffix now take
  separate rolls; a test pins `Soldier's Battle Axe of Warding`
  from rolls `[0.99, 0.0, 0.99, …]`, which the old code could
  never produce.
- **P0 — Silent misconfiguration (fixed).** `enemy.setup()`
  returned void and silently did nothing for an unknown type,
  leaving a default-stat skeleton with a mismatched name; and
  `generate_item()` treated any non-`"armor"` kind as a weapon,
  so a typo built a weapon. `setup()` now returns `bool` and
  Main skips the spawn with a `push_error`; `generate_item()`
  returns `{}` for unknown kinds. Both are pinned by tests.
- **P1 — Duplicated nearest-pick scan (fixed).**
  `_enemy_near` and `_loot_near` were the same loop twice. One
  `_nearest_in_radius(items, pos, radius, require_alive)`
  helper now serves both; the `require_alive` flag exists
  because loot drops have no `is_alive()`.
- **P1 — Magic numbers (fixed where they tune gameplay).**
  Rarity thresholds (`0.60`/`0.90`), enemy cooldown (`1.0`) and
  crit (`0.05`), click radii (30/28), pickup radius (32), loot
  stop distance (24), and camera smoothing (8.0) are now named
  consts in the file that owns them. Pure-visual literals (eye
  offsets, bar widths) were left inline — naming those would
  add noise, not clarity.
- **P1 — Boolean flag parameter (fixed).**
  `_swap_equip(item, index, is_weapon)` took a bool that only
  meant "which of two slots". It now takes the kind string
  (`"weapon"`/`"armor"`), matching `equip_item`/`unequip`.
- **P2 — Weak assertion (fixed).** The smoke test asserted
  `player.xp == 25 or player.level == 2` after killing a
  skeleton — an OR that passed for two different reasons. It
  now asserts exactly 25 XP at level 1.
- **Checked, no action:** no secrets, credentials, or personal
  data anywhere in the tracked files; no TODO/FIXME markers;
  `.gitignore` correctly excludes `.godot/`, `build/`, and
  `*.import`; `LICENSE` is MIT.

### 2. Commenting & in-code documentation

- Added `##` doc comments to every public method in
  `player.gd` (previously only the class header was
  documented), plus the non-obvious ones in `enemy.gd`
  (`setup` return contract, unused `_from` kept for future
  thorns) and `main.gd` (click priority: enemy beats loot;
  `died` fires before `queue_free`, so the position is valid
  in the handler).
- Documented the *why* behind the two subtlest rules: the
  pickup radius must exceed the loot stop distance (pinned by
  a smoke test), and level-ups heal + grant a potion because
  there is no town in this slice.
- Deliberate tradeoff, recorded: the pure functions return
  `{}`/`false` for bad input *without* `push_error`, so
  headless test output stays error-clean. Loudness lives at
  the boundary instead — Main `push_error`s on a bad spawn
  type, and the tests pin the empty/false returns.

### 3. Future-proofing & architecture

- **P1 — `main.gd` was a God object (fixed).** It built the
  dungeon, walls, player, enemies, camera, *and* the entire
  HUD (~200 lines of control construction), plus input, loot
  rolls, and death flow. The HUD is now `scripts/hud.gd`
  (`LooterHUD`, a `CanvasLayer`): Main drives it with
  `log`/`set_kills`/`show_death`/`hide_death`, and the player
  drives its bars through `stats_changed`. Main is a
  composition root again (~200 lines). Behaviour is identical;
  the smoke test now talks to the HUD's public API
  (`get_slot_count()`, `is_death_visible()`) instead of its
  former private members.
- **P2 — Floor data is code (deferred, recommended).** `WALLS`,
  `ENEMY_SPAWNS`, and `TORCHES` are const arrays in
  `dungeon_logic.gd`. That is fine for one floor. A second
  floor should become a `DungeonFloor` resource holding those
  same fields — not a second copy of the class. Not done here:
  there is no second floor to test it against.
- **P2 — Inventory logic lives in the player (deferred,
  recommended).** `add_item`/`equip_item`/`unequip`/`_swap_equip`
  are a coherent unit that will want to be an `Inventory`
  class the moment a second container appears (chest, stash,
  vendor). Not extracted now: one bag, no second container.
- **P2 — Enemies don't collide with each other or the player**
  (layer 2, mask 1). They can stack on one spot and on the
  player. Acceptable in this slice; a separation steering
  pass (or a shared collision layer) is the fix when it starts
  to look wrong in play.
- **P2 — Exports ship the tests.** `export_presets.cfg` has an
  empty `exclude_filter`, so the `tests/` scripts ride along
  in the exported PCK. Recommend excluding them before the
  first export; not changed here because exports are untested
  without the templates installed.
- **Noted, no action:** no save/load, no version const, no
  sound/particles — all correctly out of scope for v0.1.0 and
  already listed in the README.

### 4. README modernization

Rewritten to the required sections — Description (with The loop
and Controls), Prerequisites, Installation (new: Godot download
+ clone + import), Local Development (run, tests, project
layout, How it works), Screenshots (pointer to the shot list),
What is NOT in v0.1.0, Deployment. Fixes vs. the old README:
an Installation section that did not exist, test counts
corrected to 127 with the new coverage named, the layout table
gained `hud.gd`, and the loot paragraph now describes the real
roll layout (`[base, prefix, suffix, affix…]`).

### 5. Visual asset strategy

Full shot list with exact filenames, capture instructions, and
README insertion points is in `docs/visual-assets.md`. In
short: a hero gameplay still under the title, a 10–15 s
combat-loop GIF at the end of The loop, a loot close-up in
How it works, a floor-plan diagram beside the floor paragraph,
and the Mermaid architecture diagram (already in the repo at
`docs/architecture.mmd`, linked from the layout table). All
captures must come from a real play session on a machine with
a rasterizer — never mocked. Nothing is linked from the README
yet, because a broken image link is worse than no image; the
snippets are ready to paste once the captures exist.

## Verification

```sh
godot --headless --path . --import  # 0 errors
godot --headless --path . -s res://tests/test_loot_logic.gd     # PASS 42/42
godot --headless --path . -s res://tests/test_combat_logic.gd   # PASS 26/26
godot --headless --path . -s res://tests/test_dungeon_logic.gd  # PASS 30/30
godot --headless --path . -s res://tests/test_scene_smoke.gd    # PASS 29/29
```

Plus an 8-second headless run of the game with no errors, and
the same checks re-run from a fresh extraction of the rebuilt
zip (branch `main`, clean tree, no remote).

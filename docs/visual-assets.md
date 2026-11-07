# Visual assets — shot list

All captures come from a **real play session** in the Godot
editor on a machine with a rasterizer — never mocked, never
staged with fake UI. Until the shots exist, nothing is linked
from the README: a broken image link is worse than no image.
When a shot is captured, save it at the exact path below and
paste the exact markdown snippet at the stated insertion point.

Capture settings for every shot: run the game at 1280x720
(F5 in the editor), default zoom, no debug overlays.

## 1. Hero gameplay still — `docs/screenshots/gameplay-hero.png`

- **Depicts:** the Warrior mid-floor in The Dark Halls, one
  skeleton and one zombie visible, HP/XP bars top-left, the
  inventory panel on the right holding 2–3 items, and one loot
  drop (rarity diamond + name label) on the floor. The whole
  game in one frame.
- **Capture:** play until the first loot drop appears, then
  screenshot the full 1280x720 window (Print Screen or
  ShareX region capture, PNG, keep under ~500 KB).
- **README placement:** directly under the `# Godot Dungeon
  Looter` title, before `## Description`.
- **Snippet:**
  ```md
  ![Gameplay: the Warrior in The Dark Halls, with HUD and inventory](docs/screenshots/gameplay-hero.png)
  ```

## 2. Combat-loop GIF — `docs/screenshots/combat-loop.gif`

- **Depicts (10–15 seconds, ~10 fps):** click the floor to
  move, click a skeleton to attack, the skeleton dies, a loot
  drop appears, click the drop to pick it up, click it in the
  inventory to equip it. The complete loop, end to end.
- **Capture:** record with ScreenToGif or ShareX, trim to the
  loop above, keep under ~5 MB. No cursor trails, no
  narration.
- **README placement:** at the end of the `### The loop`
  section, after the Survive bullet.
- **Snippet:**
  ```md
  ![Combat loop: move, attack, loot, equip](docs/screenshots/combat-loop.gif)
  ```

## 3. Loot close-up — `docs/screenshots/loot-closeup.png`

- **Depicts:** a cropped inventory panel showing one Normal,
  one Magic, and one Rare item side by side (grey / blue /
  gold name colors), with one item's tooltip visible
  (e.g. `Rare Broad Sword of the Bear — 10–16 dmg`).
- **Capture:** crop the inventory panel region from a
  1280x720 screenshot, PNG, keep under ~300 KB.
- **README placement:** in `### How it works`, at the end of
  the loot paragraph (the one starting "Loot is generated
  from explicit rolls").
- **Snippet:**
  ```md
  ![Inventory showing Normal, Magic, and Rare loot](docs/screenshots/loot-closeup.png)
  ```

## 4. Floor-plan diagram — `docs/screenshots/floor-plan.png`

- **Depicts:** a top-down plan of the 1600x1200 floor — the
  three interior walls with their door gaps, torch dots,
  the player start (200, 640), and the 8 spawn markers
  (5 skeletons, 3 zombies). Either a clean annotated
  screenshot of the floor in the editor, or a simple diagram
  drawn from the `DungeonLogic` constants.
- **Capture:** annotate with spawn labels; keep it legible
  at README width (~800 px).
- **README placement:** in `### How it works`, at the end of
  the floor paragraph (the one starting "The floor is
  hand-built").
- **Snippet:**
  ```md
  ![Floor plan: walls, door gaps, torches, and the 8 enemy spawns](docs/screenshots/floor-plan.png)
  ```

## 5. Architecture diagram — `docs/architecture.mmd` (done)

- **Depicts:** the module map — pure logic layer vs. scene
  nodes vs. tests, and who calls whom. Already in the repo
  as a real Mermaid file; GitHub renders it when viewed.
- **README placement:** already linked from the
  `### Project layout` table. No action needed.

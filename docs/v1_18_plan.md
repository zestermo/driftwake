# v1.18: the batch (Zach, 2026-10-19)

## What it is
v1.18 holds the progression core from docs/progression_plan.md (economy and loot, wheels and loadouts, items/food/
cooking, shops and artisans, sailing downtime with the Blender clip pilot, co-op chat), plus the held map with fog
of war, the journal and quests, varied NPC encounters, and deeper swimming. The skills rework, the stamina/swim
fixes, the stern and the ship ropes/boarding are already on main (2026-10-19). Once everything has landed: one
local full run, a fix pass, the perf gate, then the release.

## Decided (2026-10-19)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Minimap | **None.** The compass strip stays as it is. | Zach wants the world on screen, not a HUD map. | — |
| The map | Pulling it out is **an animation in the world**: the captain unrolls a parchment, and the camera tilts down to it over the shoulder while the world keeps going (walk slowly, can be hit). The map is drawn on the parchment. Like Far Cry 2. | Immersion, and it reads as a PS1-era object. | After play |
| Map scope | **One map that zooms.** On an island it opens on the island (fog of war, `?` marks near undiscovered spots: camps, ruins, caves, treasure, landmarks; crewmates, the ship). Zoomed out, it's the sea chart (what sea_chart.gd shows today: islands, log pose, wrecks, treasure Xs). At sea it opens on the chart. | One object, one habit. | — |
| Fog in co-op | **Shared by the crew.** What any captain explores is revealed for all, saved with the world, per island. | Charting islands together. | — |
| Journal | A **shared crew journal** (J) with Active, Done and Rumours tabs. The tracked quest drives the objective HUD and its marker. Quests come from NPCs, notice boards and things you find. They can have several steps and are turned in to whoever gave them. In co-op the crew sees every quest, and **everyone present gets the reward**. Rewards are not XP (progression_plan.md). | Fixes the "turn everything in to one NPC for XP" loop. | — |
| NPCs | **Full encounter variety in 1.18.** Quest givers and notice boards get their own lines for each quest, and island roles get their own small talk. Varied encounters and events on generated islands: travellers, ambushes, festivals... (rival crews are 1.19: docs/rival_crews_plan.md) from seeded pools per theme, nothing guaranteed. | "Every NPC says the same thing." | — |
| Swimming | All four: **diving for loot** (a breath meter; sunken chests, wrecks, pearls, reef ingredients, a few underwater ruins), **a sea that pushes back** (currents and rip tides, surf at the shore, cold water on snow islands, storm swells), **sea threats** (sharks and other creatures that go for swimmers, jellyfish, a fin you can see coming), **better strokes** (dolphin swim, surface dash, climbing out onto ledges and rocks, a better ladder). | Swimming becomes a part of the game in its own right. | After play |
| Breath | When the breath meter empties on a dive, **you take steady damage until you surface**, clearly warned. Plain swimming still never drowns a non-fruit captain. | Diving has stakes, and swimming stays safe. | — |

### Lanes (one agent each, separate areas; pieces land in order)
- **A. Economy:** loot, drop rates and the trait pool for blue and up (per-captain rolls) → food, ingredients, galley
  cooking, buffs and regen → specialist shops, artisans and buy-back. Owns the item data (ItemDB, resources/items),
  loot/chest tables, food effects, the galley, shop_screen.gd and the market's stock.
- **B. Controls:** the consumable key and its wheel, keys 1-5 for abilities, loadout slots and their wheel (2 slots,
  a third through a Captain-tree node), the action wheel (with a registry other features add entries to), and
  making camp (rest, save) → co-op chat. Owns input in player.gd, skill_bar.gd, the hotbar → quick-item change in
  InventoryComponent, and the new wheel and chat UI.
- **C. Map:** the held map (animation, camera, the parchment), fog of war (shared, saved), `?` marks, and folding the
  sea chart in. Owns sea_chart.gd, compass_strip.gd (left as it is) and the new map files.
- **D. Quests and people:** the quest model and journal (J), notice boards, quest givers' lines → island roles'
  small talk → encounters and events. Owns KitQuests, objective_hud.gd, island_life.gd's talk and quests, and the
  new journal/encounter files.
- **E. Swimming:** breath and diving with dive loot → currents, surf and cold → sea threats → better strokes. Owns
  swim_state.gd, the new swim, dive and sea-threat files.
- **F. Sailing downtime + Blender clips** (starts once A's cooking and B's action wheel have landed): lashing the helm,
  the activity loops, the importer and clip player, and one downtime loop from a Blender clip.

### Open / deferred
- The encounter pool's contents and sizes: **assumed** D proposes them (about 8-12 kinds across themes) and lists them in its report.
- Quest kinds beyond today's KitQuests: **assumed** D proposes them.
- The release name and what's-new text: at release time.

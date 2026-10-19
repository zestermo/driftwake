# Progression, economy and life skills (Zach, 2026-10-19)

## What it is
A refinement pass now that the game has enough content to play with. The economy is too generous (too many items,
treasure and gold), new weapons don't feel different, the skill trees are dense and unrewarding, and keeping every
tree fully separate discourages trying other weapons. Life activities (swimming, cooking, later fishing and the rest)
should level up too, so the player gets better at everything they do. Shops, artisans, food and cooking get rebuilt
on top of that. This pass also shapes how the cities get built (roadmap phase 1). It covers roadmap phase 3's
"Economy" and "Levels and abilities", and todo.md's Healing, Economy and Experience-and-skills sections.

Grilled later, after the core lands: the minimap rebuild (fog of war, `?` points of interest, crewmates and
islands), the journal and quests, varied NPC encounters and dialogue off Brinehollow, and making swimming
deeper.

How things work today (read 2026-10-19): `Progression` (scripts/progression/progression.gd) gives 2 skill points
per level (MAX_LEVEL 40) plus per-tree mastery from hits (MASTERY_PER_HIT 4, MAX_MASTERY 30). Each tree has its own
points (`points(tree)`). Swimming spends stamina and does `EXHAUST_DAMAGE` when you're exhausted
(swim_state.gd). Fruit users drown in deep water (`DROWN_DPS`).

## Decided (2026-10-19)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Order | The progression core goes first: the skills rework, then economy and loot, then items, food and cooking, then shops and artisans. The map, journal, NPCs and swimming depth come after it. | Everything else rewards the player through these systems, so building them first means nothing gets redone. | — |
| Skill trees | Fewer, bigger nodes that change how you play. A **shared tree** (body, swimming, cooking, sailing...) is paid with level points. **Weapon trees** fill as you use the weapon. Part of a weapon's mastery **carries over to its family** (blades, heavy, guns...). | The current trees are too dense, and keeping them fully separate punishes trying a new weapon. | After a play pass |
| Life skills | Learned by doing: swimming, cooking, sailing and fishing build mastery the way weapons do, with perks at mastery milestones. | Rewards what the player actually does. Seamanship (ship_upgrades_plan.md) is one of these. | — |
| Quest rewards | XP comes mainly from fighting, exploring and discovering. Quests pay gold, items, recipes, discounts, map reveals and favours, and each one is turned in to whoever gave it. | The "turn quests in to one NPC for XP" loop feels wrong. | At the journal/quests grill |
| Weapons | Far fewer weapon drops. From blue rarity up, each weapon rolls a **named trait that changes a move** (a finisher that bleeds, a dash that leaves fire...). Rarity matters. | Makes a new weapon an event. It builds on the gear-upgrading plan in todo.md. | — |
| Co-op loot | Chests and kills roll separately for each captain (instanced). | A tighter economy without fights over drops. Gold and progression are already per captain. | — |
| Healing | Slow health regen out of combat. In a fight you heal with food and drink from the quick-slots (decided 2026-10-13: short shared cooldown, an eat animation you can be hit out of). Galley meals give **10-20 minute buffs**, cooked from ingredients. | Healing stays readable in a fight, and cooking is worth doing. | — |
| Old saves | Levels, mastery, gold and gear stay. Every skill point is refunded once on load (a Settings/save VERSION migration). | No progress is lost. | — |
| Swimming | A non-fruit captain who runs out of stamina in the water drops to a slow float-paddle and gets stamina back, **with no damage**. Danger comes from the sea (sharks, storms, currents, cold water). Only fruit users drown. | Drowning came too easily for a pirate game. | At the swimming grill |
| Shops | Every shop is a trade (smith, cook/grocer, tailor, chandler) with a short, rotating stock in the island's theme. **Artisans** sometimes turn up on wild islands with a few simple goods. Rare gear comes only from the treasure merchants. Selling pays a fraction of the price, and you can buy back what you just sold. | Makes buying a decision and gives each island its own character. | — |
| Numbers | Drop rates, prices, node costs, the carry-over fraction, the regen rate and buff strengths are all **tuned in play**. | Zach judges feel by playing. | — |

## Decided (2026-10-19, round 2: wheels, loadouts, downtime)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Consumables | **One key** replaces the item hotbar. A tap uses the selected food or drink, and holding opens a radial (the emote wheel's style) to change the selection. | Healing stays fast in a fight and the HUD stays clean. | — |
| Number keys | **1-5 are ability slots**. Nothing is bound to 6 and up. | — | — |
| Weapon loadouts | A **loadout radial**: each slot is a saved weapon setup (twin daggers in 1, a single cutlass in 2, dual pistols in 3...). You start with **2 slots**, and a third is an upgrade. | Makes swapping weapon styles in a fight one gesture, and it works with the family carry-over to encourage trying weapons. | — |
| Action menu | A **context wheel** on its own key that shows only what fits where you are. On an island: make camp (rest, cook, save, later a respawn point), train. On the ship: train, read, tinker, cook, fish, sleep. In town: the town's own things. | One place for "things the captain can do", without leaving the world. | — |
| Sailing downtime | Set a course and **lash the helm**, and the ship holds it, even solo. Activities are short animated loops that build skills: train (weapon mastery), read (XP, lore, recipes), tinker (ammo, small gear upgrades), cook (meals), fish (ingredients). **Storms, enemy ships and sea monsters interrupt** you. | The One Piece crew's downtime (Zoro trains, Usopp tinkers, Robin reads). Sailing time becomes progress. | After a play pass |
| Co-op chat | A text chat for co-op captains. | — | — |
| Blender clips | A **pilot**, after the skills and wheels work: clips authored on the BlenderBody armature (dev_notes 2026-10-16) are imported as per-joint rotation tracks, retargeted the reverse of BlenderBody's `source_now * source_rest^-1 * blender_rest`, and played by Humanoid alongside the keyed poses. The pilot is the importer, a clip player, a test and **one sailing-downtime loop**. Combat stays procedural. Zach supplies the source clips (his own keyframes or library/mocap he downloads). | Long, natural, full-body loops (downtime activities, idles, gestures, NPC work) are where keyed poses are weakest. | After the pilot clip is played in game |

### Fixes, not grilled (one driftwake-fixer)
- The sprint jump costs no stamina; give it a cost.
- Swimming exhaustion: float-paddle, no damage (above).
- Texture problems on the ship's back corners (stern).

### Open / deferred
- ~~The weapon families~~ **Settled 2026-10-19** (SkillTree.FAMILIES): blades (cutlass, katana, dual wield, dagger,
  twin daggers, Corsair), heavy (axe; hammers join later), guns (pistol, Corsair), fists (unarmed). The Corsair is in
  blades and guns. The Devil Fruit tree has no mastery, so it's in no family. Carry-over is 25% (FAMILY_SHARE, tune in play).
- The trait pool (how many traits, which moves they touch): the building agent proposes a first set of about 8-12
  and shows Zach before it lands.
- What "favours" and "discounts" mean in detail: at the journal/quests grill.
- The keys for the item, loadout and action wheels: **assumed** the building agent picks free keys next to T (the emote wheel) and lists them in its report.
- How the third loadout slot is earned: **assumed** a shared-tree node (level points).
- Co-op chat: **assumed** Enter opens it, the last few lines fade over the HUD, it's text only and goes through the host (Net), with a captain's name and colour on each line.
- Where these pieces go in the order: **assumed** the item wheel goes with the items/food piece. The loadouts, the 1-5 ability bar and the action wheel come right after the skills rework. Sailing downtime comes after cooking, because it uses the life skills. Chat is a small piece of its own, any time.
- The minimap, journal/quests, NPC encounters and swimming depth: their own grills, after the core.

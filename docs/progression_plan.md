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
| Galley restock | **No free restock** (Zach, 2026-10-19, confirming lane A's change): food is cooked or bought. The Galley & bunks line gives +1 portion per cook per level instead. This replaces todo.md's 2026-10-13 "the galley refills them as now". | Food is worth something, and cooking matters. | — |
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

## Reconsider (Zach, 2026-10-20, after playing 1.18)
The skills rework did not do what Zach wanted. **To be redesigned from scratch** once he brings references for how the
skill menu/UI should look and work; then a grill round.
- **Dislikes:**
  - The family carry-over: gaining XP for weapon types you aren't using makes no sense.
  - The trimmed trees: there is far less skill progression now.
  - The core (Captain) skills as they are, and 2 points a level for them feels pointless.
  - Most of the rework in general.
- **Likes / keep:**
  - The LIFE tab (the life skills page).
  - The direction of **unlocking more pieces of a weapon's attack patterns by learning that weapon**.
  - The structure already in place, and the abilities already built for the weapons and skills: the redesign reuses
    them.
- **Waits for:** Zach's references (skill menu/UI look and behaviour). Until then, no agent changes Progression,
  SkillTree or the skill map.

## Redesign (Zach, 2026-10-20): Driftwake_Progression_System_Redesign.pdf
Zach's design brief replaces the 1.18 rework. Five layers, each answering one question: Captain (overall growth),
weapon mastery (what this weapon can do), buildcraft (what I bring into a fight), world discoveries (advanced arts
found in the world), life skills (unchanged). Death never takes permanent progress (already true: only the bag and
gold go in the grave).

**Key idea for the build:** the existing node ids, effects and `has_move` / `style_stat` / `elemental` / `stat`
readers stay. Mastery levels, talents and milestones *grant* the existing big nodes instead of selling them for
points, so the ~100 gameplay call sites don't change. Passive slots are a filter on `Progression.stat()`'s sum.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Weapon mastery | **Mastery 1-30 per weapon** (the existing MAX_MASTERY and curve), earned only by using it. Each weapon's tree has **three branches** (katana: Guard, Iai, Blade). **Big nodes** (moves, techniques, mechanics, passives, element, ultimate) come by themselves at their mastery level. **Small stat nodes** with steps (x/3, x/5) are bought with **mastery points**, one a level, in any order; a full tree takes about all 29. No family carry-over. | Zach: unlock a weapon's attack patterns by learning it, but the trees should feel long and deep (filler stat steps and points too). | After the katana prototype |
| No lockouts | **Never a choice between two abilities** (Zach, 2026-10-20). Choices are **variants**: two versions of the same move, technique or passive upgrade (two air attacks, two Wind Severers, two iai upgrades, two Iai Counters). You own both once unlocked and pick which one is active. | Losing an ability for good isn't fun. | — |
| Mastery XP | Hits +4 for the first 12 hits on each foe, kills a quarter of their XP, elites and bosses x3. | Early levels fast, late levels commitment, no hit farming. | Tuned in play |
| Downtime "train" | **Reduced** (Zach): +2 every 6 s (was 5), and only up to mastery 8. | Drills teach the basics; mastery comes from fighting. | — |
| Skill bar | **One bar across the weapon loadouts** (Zach, 2026-10-20, replacing "a bar per loadout"): any skill of a weapon in one of your loadouts can go on it. Using a skill of a weapon you're not holding **switches to that weapon, then uses the skill**. Nothing more (no combined movesets, no special swap rules; Zach). A weapon in no loadout can't have skills on the bar. Captain and Will skills work with anything. Editable out of combat, locked in boss fights. | Mix three katana skills with a pistol one; the bar is the build. | After playing it |
| Passives | 3 slots for the captain (a 4th at level 25); a weapon's passive counts only with that weapon in hand. Weapon passives come from mastery; "any weapon" passives from levels and Will. A few new behaviour passives (Momentum, Riposte Edge, Skyborne, Slipstream). | Passives reward a style instead of always-on stat piles. | — |
| Captain levels | Cap 40. No skill points. Captain-tree stat nodes **folded into per-level growth** (Zach): per level +5.5 health, +2% damage, +0.6 stamina, +0.6 energy, +0.5 defense (draft). | 2 points a level felt pointless. | Tuned in play |
| Comes by itself | Lv 3 Geppo, Lv 8 Soru, Lv 10 third loadout (was Quartermaster), Lv 14 Tekkai, Lv 25 fourth passive slot. | Basic movement shouldn't feel locked away. | — |
| Captain Talents | One of two at levels 5, 10 ... 40, from the old tree's mechanic passives (Swift Step, Long Stride, Steadfast, Mend, Sky Walk, Adrenaline, Iron Stomach, Focus, Last Stand) plus new ones (Fleetfoot, Iron Body, Battle Instinct). Levels 35 and 40 still to design. | Few, bigger choices that change interactions. | — |
| Will (Haki, renamed per originality_plan.md) | Earned by bosses and trials, not level: Iron Will (Morrow), Iron Will: Coat, Sense, Foresight, Captain's Will (the First Sea's last boss). Each brings its technique and a Will passive (Hardening, Black Fists, Instinct, Weak Points). Trial places to decide. | Will milestones mark the story. | When trials are placed |
| Respec | Variants, talents and mastery points are switched at **the ship's bunk** (Zach). | — | — |
| Technique evolutions | The use counters open a free choice between two variants (no points); defensive skills count successful counters, not casts. One per weapon at first. | — | Phase 6 |
| World discoveries | A weapon master (Vey first), a manual item found in ruins, a feat tracker, and a quest `technique` reward. Each captain earns their own. Never core moves. | Exploration pays in combat knowledge. | Phase 5 |
| Old saves | Format 5: mastery levels kept as they are (same 1-30 scale), mastery points refunded once, Captain picks from level, `uses` kept, SP dropped. | No progress lost. | — |

**Mock (2026-10-20):** https://claude.ai/artifact/LtuWdvQws3vYRxNccdWJ8V. The look follows Zach's references (ARC
Raiders' lit branches, a radial pixel-icon tree, Skyrim's constellations): node trees on a night sky with the game's
own 24 px icons. A weapon's tree grows up from its root in three branches, big nodes on the branches, small stat
nodes off them with their step counts, variants drawn as one split node (the active half lit). The mastery chart
branches every weapon from the captain into its own three-branch cluster. The Captain tree reads the same way: a
vertical level trunk, round nodes that come by themselves, split talent nodes, a legend of how it grows, and Will
as its own path beside it.

**Katana tree (draft):**
- Root (mastery 1): combo, heavy, iai.
- Guard: Cut the Shot 3 · Iai Counter 8 (variants Draw Cut / Side Step, new) · Phantom Step 14 · Bullet Return 20.
- Iai: Full Draw 6 · Tiger Rush 10 · iai upgrade 12 (variants Through the Guard / Mind's Eye) · Falling Petals 16 ·
  Blossom Path 25 · Thousand Petals 30.
- Blade: Quick Draw 2 · Wind Severer 5 (variants Towering Wave / Twin Waves at 18, new) · air attack 7 (variants
  Crescent Arc / Falling Moon at 15, new) · Clean Line 13 (passive) · Empty Mind 22 (passive).
- Stat steps (30 in all): Keen Edge 5 (damage), Deep Draw 5 (iai), Whetstone 5 (crit), Steel Nerves 3 (parry),
  Counterweight 3 (counters), Light Feet 3 (stamina), Flow 3 (energy), Swift Recovery 3 (cooldowns). The old stat
  nodes (Folded Steel, Sword Saint) become these steps.

**Phases** (one after another: they share progression.gd, skill_tree.gd and the skill map):
0. This record and the mock (Zach's OK).
1. Katana prototype: the katana's tree in the new schema (big nodes by mastery level, stat steps for points,
   variants), family carry-over removed, per-foe hit cap, reduced training, format-5 migration for the katana, its
   tree on the skill map (other weapons keep the old trees meanwhile).
2. Buildcraft: passive slots, the one bar across loadouts (a skill switches to its weapon, then fires), one katana
   evolution.
3. The other eight weapons (Corsair first; each weapon's ranks in its own file), then the old weapon points go.
4. Captain and Will: growth per level, automatic milestones, talents, Will milestones, a new reward for Vey's
   story step, the Captain tree removed.
5. World discoveries: a master, a manual, a feat, the quest reward.
6. Depth: an evolution per weapon, more traits, a balance pass.

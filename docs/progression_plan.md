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
| Tabs and discovery | **Captain · Combat · Adventure · Loadout**, plus **Driftfruit** once a fruit is eaten (Zach, 2026-10-20). Combat holds the weapon trees, Adventure the life skills: sailing, swimming, cooking, tinkering, fishing, acrobatics, stealth, defense (blocking and parrying), more later. **A tree shows only once its first level is earned** (a new captain sees Cutlass and Captain), with a "new skill tree" banner when one appears (e.g. Dual Wield after fighting with two cutlasses). Adventure trees follow the weapon trees' rules (big nodes by level, steps for points, variants), levels 1-20. The Loadout tab stays: the bar, the passive slots and the library of everything known. | Fewer, bigger menus; finding a tree is a reward. Stealth (stealth.gd, crouch), blocking (block_state.gd) and tinkering (Downtime) already exist to grow them from. | — |
| No lockouts | **Never a choice between two abilities** (Zach, 2026-10-20). Choices are **variants**: two versions of the same move, technique or passive upgrade (two air attacks, two Wind Severers, two iai upgrades, two Iai Counters). You own both once unlocked and pick which one is active. | Losing an ability for good isn't fun. | — |
| Mastery XP | Hits +4 for the first 12 hits on each foe, kills a quarter of their XP, elites and bosses x3. | Early levels fast, late levels commitment, no hit farming. | Tuned in play |
| Downtime "train" | **Reduced** (Zach): +2 every 6 s (was 5), and only up to mastery 8. | Drills teach the basics; mastery comes from fighting. | — |
| Skill bar | **One bar across the weapon loadouts** (Zach, 2026-10-20, replacing "a bar per loadout"): any skill of a weapon in one of your loadouts can go on it. Using a skill of a weapon you're not holding **switches to that weapon, then uses the skill**. Nothing more (no combined movesets, no special swap rules; Zach). A weapon in no loadout can't have skills on the bar. Captain and Will skills work with anything. Editable out of combat, locked in boss fights. | Mix three katana skills with a pistol one; the bar is the build. | After playing it |
| Passives | 3 slots for the captain (a 4th at level 25); a weapon's passive counts only with that weapon in hand. Weapon passives come from mastery; "any weapon" passives from levels and Will. A few new behaviour passives (Momentum, Riposte Edge, Skyborne, Slipstream). | Passives reward a style instead of always-on stat piles. | — |
| Captain levels | Cap 40. No skill points. Captain-tree stat nodes **folded into per-level growth** (Zach): per level +5.5 health, +2% damage, +0.6 stamina, +0.6 energy, +0.5 defense (draft). | 2 points a level felt pointless. | Tuned in play |
| Comes by itself | Lv 8 Soru, Lv 10 third loadout (was Quartermaster), Lv 14 Tekkai, Lv 25 fourth passive slot. | — | — |
| Movement and parrying | **Moved out of the Captain tree** (Zach, 2026-10-20): Geppo (early, so basic movement isn't locked away), Swift Step, Long Stride, Sky Walk and Fleetfoot go to the **Acrobatics** tree; Steadfast, Iron Body and Battle Instinct to **Defense**. Both are Adventure trees, grown by jumping, dodging and air attacks, and by blocking and parrying. | Each tree grows from what it's about. | When those trees are built |
| Captain Talents | One of two at levels 5, 10 ... 40, general picks only (draft): 5 Mend / Iron Stomach · 10 Quick Hands / Sea Dog · 15 Adrenaline / Second Wind · 20 Focus / Bounty Hunter · 25 Rallying Cry / Treasure Sense · 30 Last Stand / Captain's Presence · 35 and 40 to design. New: Quick Hands (eat and drink faster), Sea Dog (stamina twice as fast aboard), Second Wind (once a fight, low health refills stamina and energy), Bounty Hunter (+15% damage to elites and bosses), Rallying Cry (revive crewmates faster, both heal), Treasure Sense (treasure nearby on the compass), Captain's Presence (common foes falter near you). | Few, bigger choices that change interactions. | — |
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

**Menu chrome (mock, 2026-10-20; "more whimsical and fantasy, less modern and polished", Zach):** a warm wooden beam
with knots and grain over a twisted rope; tabs are little wooden signs hanging on ropes, each at its own tilt, with
16 px pixel icons (crown, crossed swords, compass, chest), the active one a gilded sign hanging lower with a twinkle;
a parchment scroll nameplate with a gold doubloon for the level; parchment panels with hand-cut corners, burnt
edges, a coffee ring and a red wax seal; slate panels in a rope border with brass nails; red swallowtail banners;
rope dividers with a gold star; round wooden keycaps; titles in a pixel blackletter (Jacquarda Bastarda 9); a night
sky with soft nebula colour and a dashed map border. In Godot this is new UIStyle frame kinds and a title font.

**Acrobatics tree (draft, levels 1-20):** Air: Geppo 2 · Sky Walk 9 · landing variant 15 (Featherfall / Crash
Landing, new) · Moonstep 20 (new). Dodge: Swift Step 4 · dodge variant 7 (Roll / Sidestep, new) · Fleetfoot 12 ·
Afterimage 18 (new). Stride: Long Stride 3 · Sprint Jump 6 · Sure Footing 10 · Rigging Monkey 16 (new). Steps:
Light Step 5, Quick Feet 5, Breakfall 3, Hang Time 3, Spring 5. Grows from jumps and air time, dodges (through a blow
counts most), sprints and survived falls.

**Defense tree (draft, levels 1-20):** Parry: Clean Parry 2 (a perfect parry staggers, new) · Iron Body 8 · Battle
Instinct 12 · perfect-parry variant 16 (Disarm / Shove, new). Guard: Brace 3 (new) · guard variant 7 (Planted /
Rolling Guard, new) · Hold the Line 11 (new) · Iron Wall 20 (new). Grit: Steadfast 4 · Unshaken 9 · Second Skin 14 ·
Unbreakable 18 (new). Steps: Timing 5, Sturdy Guard 5, Thick Skin 5, Recovery 3, Composure 3. Grows from parrying and
blocking real blows (perfect parries most) and staying up when hit. Weapon-specific parry tricks stay on the weapon
trees.

**Built (prog-core piece 3, 2026-10-20):** Acrobatics and Defense without the new moves (Moonstep, Afterimage,
Roll / Sidestep, Crash Landing, Disarm / Shove, Rolling Guard / Planted wait for the moves batch); Featherfall is its
own node at 15 (out of Sky Walk). New nodes as numbers: Fleetfoot (the old Agility), Sprint Jump (half the bound's
stamina), Sure Footing (stamina 10% faster), Rigging Monkey (climb 40% faster), Clean Parry (a wider window and 10
stamina back; the stagger waits for the moves batch), Brace / Iron Wall (blocks cheaper), Hold the Line (shuffle faster
behind the guard), Unshaken / Second Skin / Unbreakable (health and defense). XP: a jump 3, an air jump 6, a dodge 5;
a parry 15, a blocked blow 5 (tune in play).

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

**The other weapon trees (drafted by prog-core, 2026-10-20; built in piece 2, tuned in play).** Same pattern as the
katana: the root at 1, three branches of big nodes, the element at 16 and 25, the ultimate at 30, eight steps (30 in
all against 29 points; the old stat nodes became the damage / crit / stamina steps). A tree's old style passives are
either a slotted passive or, two of them, a variant (both owned, one active). Mechanics (mech) always count.
- **Cutlass** (Guard / Tide / Swagger). Guard: Arrow Cutting 3 (mech) · Riposte 8 · Return to Sender 20 (mech). Tide:
  Flying Slash 4 · Swordfish Flurry 10 · Call of the Tide 16 · Tidewalker 25 · Kraken's Wake 30. Swagger: Running Cut 2 ·
  Boarding Dive 6 · Flourish 13 (passive) · Pirate's Way 22 (variant: Plunder / Swashbuckler). Steps: Keen Edge 5 (dmg),
  Whetstone 5 (crit), Boarding Edge 5 (finisher), Light Feet 3 (stamina), Lunge 3 (thrust), Steady Hand 3 (parry),
  Flow 3 (energy), Swift Recovery 3 (cooldowns).
- **Unarmed** (Grapple / Martial / Body). Grapple: Shoulder Throw 3 · Heavy Landing 9 (mech) · Suplex 12 · Giant Swing
  18. Martial: Shockwave Palm 4 · Rising Dragon 8 · Hundred Fists 13 · Rushing Wind 16 · Gale Fists 25 · Sea King Fist 30.
  Body: Roundhouse 2 · Meteor Kick 6 · Iron Body 11 (passive) · Chi 15 (passive) · Finishing Blow 22 (passive). Steps:
  Iron Knuckles 5 (dmg), Pressure Points 5 (crit), Heavy Hands 5 (finisher), Light Feet 3, Grip 3 (grapples and arts),
  Stone Skin 3 (defense), Flow 3, Breath 3 (cooldowns).
- **Axe** (Brute / Fury / Blood). Brute: Hatchet Throw 3 · Earthsplitter 9 · Sunder 14 (mech). Fury: Unstoppable 6 (mech)
  · Berserk 11 · Ember Heart 16 · Living Fire 25 · Maelstrom 30. Blood: Skybreaker 2 · Bloodlust 12 (passive) · Rage 20
  (variant: Frenzy / Executioner). Steps: Heft 5 (dmg), Overhead 5 (whirlwind), Keen Bite 5 (crit), Light Grip 3, Iron
  Hide 3 (defense), Cleave 3 (finisher), Flow 3, Recovery 3.
- **Dual Wield** (Guard / Dance / Edge). Guard: Twin Deflect 3 (mech) · Crossed Counter 8 · Ricochet Steel 20 (mech).
  Dance: Blade Dance 5 · Cross Fang 10 · Twin Currents 16 · Crossing Storm 25 · Tempest of Steel 30. Edge: Twin Spin 2 ·
  Twin Cyclone 7 · Whirling Steel 13 (passive) · Dancer's Way 22 (variant: Dancer / Thousand Cuts). Steps: Twin Blades 5,
  Crossing Edge 5 (crit), Finisher 5, Light Feet 3, Steady Pair 3 (parry), Bite 3 (techniques), Flow 3, Recovery 3.
- **Dagger** (Guard / Shadow / Blood). Guard: Flick the Shot 3 (mech) · Slip 8 · Knife in the Dark 20 (mech). Shadow:
  Knife Fan 5 · Cutthroat 10 · Nightfall 16 · Blood Moon 25 · Red Eclipse 30. Blood: Gutting Strike 2 · Fang Dive 7 · Deep
  Cuts 13 (passive) · Killer's Way 22 (variant: In the Back / Open Vein). Steps: Whetstone 5, Weak Spot 5 (crit),
  Serrated 5 (bleed), Light Feet 3, Shadow Lunge 3 (right-click), Slippery 3 (evade), Flow 3, Recovery 3.
- **Twin Daggers** (Guard / Fangs / Venom). Guard: Crossed Knives 3 (mech) · Bleeding Edge 8 · Knives Back 20 (mech).
  Fangs: Viper Flurry 5 · Scissor Leap 10 · Viper's Kiss 16 · Serpent's Coil 25 · Hundred Fangs 30. Venom: Fang Whirl 2 ·
  Knife Rain 7 · Open Wounds 13 (passive) · Viper's Way 22 (variant: Two in the Back / Death by Cuts). Steps: Paired
  Fangs 5, Weak Spot 5, Serrated 5, Light Feet 3, Scissor Rip 3 (right-click), Slippery 3, Flow 3, Recovery 3.
- **Corsair** (Guard / Powder / Steel). Guard: Steel and Shot 3 (mech) · Parley 8 · Return Fire 20 (mech). Powder:
  Grapeshot 5 · Bandolier 9 (mech) · Crossfire 12 · Black Powder 16 · Powder Keg 25 · Broadside 30. Steel: Powder Finale
  2 · Dead Man's Drop 7 · Smoke and Steel 13 (passive) · Corsair's Way 22 (variant: Gunsmoke / No Quarter). Steps:
  Boarding Steel 5, Dread 5 (crit), Powder Lunge 5 (right-click), Light Feet 3, Quick Load 3 (reload), Steady Parry 3,
  Flow 3, Recovery 3.
- **Pistol** (Tricks / Shots / Close). Tricks: Gun Kata 3 · Smoke Bomb 6 · Gun Rain 9 · Hang Time 14 (mech). Shots:
  Bullet Storm 5 · Deadeye 10 · Golden Powder 16 · Ricochet 20 (mech) · Gilded Gun 25 · Death's Waltz 30. Close: Hang
  Shot 2 · Extra Powder 7 (mech) · Point Blank 11 · Close Quarters 15 (passive) · Coup de Grace 22 (passive). Steps:
  Marksman 5 (dmg), Deadeye 5 (crit), Hard Shot 5 (techniques), Quick Load 3 (reload), Close Range 3 (point blank),
  Light Hand 3, Flow 3, Recovery 3.

**Captain tree (drafted by prog-core, 2026-10-20; built in piece 3).** Levels 1-40, no points.
- Growth per level, by itself: +5.5 health, +2% damage, +0.6 stamina, +0.6 energy, +0.5 defense (the old Vitality,
  Strength, Endurance, Spirit, Toughness and Hardy nodes and the old 4 health / 2% a level folded in).
- Milestones (branch "Milestones"): Soru 8, Quartermaster (a third loadout) 10, Tekkai 14, a fourth passive slot 25.
- Talents (branch "Talents", one of two, the first pick anywhere, a change only at the bunk): 5 Mend / Iron Stomach ·
  10 Quick Hands (eat and drink 35% faster) / Sea Dog (aboard, stamina refills twice as fast) · 15 Adrenaline / Second
  Wind (once a fight, dropping under 30% health refills stamina and energy) · 20 Focus / Bounty Hunter (+15% damage to
  elites and bosses) · 25 Rallying Cry (get a crewmate up 50% faster, both heal a quarter) / Treasure Sense (closed chests
  within 60 m on the compass) · 30 Last Stand / Captain's Presence (common foes' blows hit you 25% softer; not elites
  or bosses; the mock's "falter") · **35 (new) Quick Learner** (+15% experience, every tree learns 15% faster) / **Thick
  Hide** (+10 defense, +30 health) · **40 (new) Warlord** (+12% damage, 6% more crits) / **Living Legend** (+60 health, +8
  defense, stamina 20% faster).
- Will (branch "Will"; Haki in code): Iron Will (Captain Morrow; heavies can't be blocked, +8% damage; passive
  Hardening) · Iron Will: Coat (**assumed: a jungle ape boss**; the Coat technique; passive Black Fists) · Sense
  (**assumed: the Brood Queen**; foes flash before they strike; passive Instinct) · Foresight (**assumed: a great beast
  in its arena**; the Foresight technique; passive Weak Points) · Captain's Will (**assumed: a Sea King**, with the other
  four; Conqueror's Will; passive King's Will). Coat, Sense and Foresight need Iron Will; a boss beaten earlier counts
  once its Will opens. Each captain earns their own (the kill near you).
- Gone: the Captain tree's skill points and nodes (Agility and Sea Legs live on as Acrobatics' Fleetfoot and Swimming,
  Steadfast and Iron Hide in Defense, Helmsman in Sailing). Skill tiers open by use alone (no points).
- Vey's story step (was a skill point): a drill, a level of mastery for the weapon in your hand.

**The other Adventure trees (drafted by prog-core, 2026-10-20; built in piece 4).** Levels 1-20, a point a level for the
steps (about 20 steps each), the old milestone perks as big nodes at the same levels, "new" ones numbers-only.
- **Sailing** (was Seamanship; Helm / Guns / Deck): Sea Hand 2 · Helmsman 5 (from the old Captain tree) · Storm Sailing
  10 | Gun Captain 4 · Broadside Master 15 | Hard Over 7 · Bosun 20. Steps: Steady Helm 5, Gunnery 5, Carpenter 3,
  Bilge Rat 3, Lookout 3. XP as before (Seamanship.xp).
- **Swimming** (Stroke / Breath / Sea): Strong Strokes 2 · Sea Born 7 | Deep Lungs 4 · Catch Your Breath 10 (was Second
  Wind: the name is the Captain talent's now) · Deep Diver 14 (new) | Current Reader 8 (new) · Child of the Sea 15 · Old
  Salt Lungs 20 (new). The surface-sprint variant (Dolphin Kick / Long Glide) waits for the moves batch. Steps: Long
  Strokes 5, Big Lungs 5, Tireless 5, Cold Blood 5.
- **Cooking** (Hearty / Spice / Larder): Galley Hand 2 · Iron Gut 10 | Ship's Cook 5 · Master Chef 15 | Long Feast 8 (new)
  · Captain's Table 20 (new). Steps: Seasoning 5, Slow Simmer 5, Taster 5, Good Stock 5.
- **Fishing** (Line / Bait / Lore): Patient Line 2 · Steady Hands 5 · Master Angler 20 | Bait Saver 8 · Old Salt 15 | Sea
  Lore 10. Steps: Quick Bite 5, Strong Reel 5, Lucky Cast 5, Thrifty 5.
- **Stealth** (Sneak / Ambush / Shadow; new): Soft Step 2 (sneak 25% faster) · Ghost 12 | Ambush 4 (a blow from a sneak
  30% harder) · Assassin 15 | Slip Away 8 (a cheaper, longer dodge) · Shadow 20. Steps: Quiet Feet 5, Knife Work 5,
  Patience 5, Nimble 5. XP: sneaking near foes (a few metres at a time), a blow struck from a sneak.
- **Tinkering** (Kit / Powder / Hands; new): Tight Fit 2 (a tuned kit lasts 25% longer) · Fine Springs 10 | Dry Powder 5
  (reload 10% faster, always) · Powder Horn 15 (a shot more, always) | Clever Hands 8 (each spell of tinkering tunes half
  again as long) · Field Whetstone 20 (+4% damage, always). Steps: Oil 5, Ramrod 5, File 5, Patchwork 5. XP: each spell
  of tinkering (the action wheel, aboard or at camp).
- Stealth's notice ranges (Stealth.range_for, judged on the host for a guest's puppet) are left alone: its nodes are
  all on the sneaking captain's own machine (speed, the blow's damage, the dodge), so they work for a guest.

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

## Build: v1.18.2 (Zach, 2026-10-20)
"Do all this now", shipped in 1.18.2 with the optimization session's work.

| Decision | Choice |
|---|---|
| Scope | **Systems now, new moves next.** Every system, menu and tree in 1.18.2, built from abilities that exist plus new numbers-only passives and talents. Trees show only real nodes; a variant whose second version is a new animated move waits (the node shows its one version). The ~30 new animated moves (Falling Moon, Twin Waves, Side Step, Moonstep, Afterimage, Disarm/Shove, Rolling Guard, Crash Landing, Dolphin Kick...) are a follow-up batch (docs/todo.md). |
| Tree tables | The building agent drafts every tree past the katana (8 weapons, Captain, Adventure) into this doc following the katana's pattern, builds them, and Zach tunes in play. |
| Title font | Jacquarda Bastarda 9 (Google Fonts, SIL OFL) downloaded into assets/fonts/ with its licence. |
| Restyle | Other menus and UI in the same whimsical style where it's low-cost (UIStyle frame kinds, so most screens change through the theme). |
| Phase 5 (world discoveries) | Not in 1.18.2 (needs content: a master, manuals, feats). |

**Agents** (separate areas; names fixed for the batch):
- **prog-core** owns `scripts/progression/*` (new tree data, Progression), `scripts/game/story.gd` (Vey's reward),
  `scripts/game/downtime.gd` (training), the XP/mastery grant sites (`power_component.gd:on_sword_hit`'s `pr.on_hit()`
  call only), and in `scenes/player/player.gd` only the per-level growth lines (`_recalc_stats`, `defense()`,
  `damage_multiplier`). Adventure trees' XP hooks in block/crouch/stealth/jump/dodge states are small local calls
  `player.progression.add_life(...)`.
- **menu-ui** owns `scripts/ui/ui_style.gd`, `scripts/ui/skill_map_screen.gd` (becomes the new menu),
  `scripts/ui/game_menu.gd`, `assets/fonts/`, and the other menu screens it restyles (pause, options, inventory,
  shop, journal, galley, shipwright, title, save slots...). Not `skill_bar.gd`.
- **bar-swap** owns `scripts/powers/power_component.gd` (except prog-core's one call), the loadout functions in
  `scenes/player/player.gd` (`LOADOUTS`..`set_loadouts`, ~1679-1777) and the cast input lines (~1526),
  `scripts/ui/skill_bar.gd`, `scripts/ui/loadout_wheel.gd`.

**Contract (prog-core provides in its first landed piece; menu-ui and bar-swap build on it):**
- `SkillTrees` (static data, replaces `SkillTree`'s layout role): `tree_def(id) -> {id, name, section ("captain" |
  "combat" | "adventure" | "fruit"), color, max_level, branches: [{name, nodes: [ids]}]}`; `node_def(id) -> {id, name,
  kind ("root" | "move" | "tech" | "mech" | "passive" | "elem" | "ult" | "step" | "variant" | "auto" | "talent" |
  "will"), tree, branch, level, pos (Vector2, tree space), links, skill (skill id or ""), desc, max_steps,
  versions: [{name, desc, level}]}`; `trees_in(section) -> Array`.
- `Progression`: `visible_trees(section)`, `tree_level(tree)`, `tree_xp(tree)`, `tree_xp_next(tree)`,
  `points_free(tree)`, `steps_of(node)`, `buy_step(node) -> bool`, `owns_node(node)` (not has_node: Node has one), `version_of(node) -> int`,
  `set_version(node, i) -> bool` and `pick_talent(level, i) -> bool` (only where `can_respec()`: the ship's bunk),
  `talent_at(level) -> int`, `has_will(id)`, `passives: Array[String]` (3, a 4th at level 25), `equip_passive(id,
  slot) -> bool`, `library() -> {skills: [...], passives: [...]}`; signal `tree_found(tree)` (the banner is shown
  by prog-core through the hud group). Existing readers (`stat`, `has_move`, `style_stat`, `elemental`,
  `skill_tier`, `knows`, `known_skills`) keep working.
- Extras (prog-core, piece 1): `step_why(node)`, `respec_steps(tree)` (bunk only), `passive_slots()`, `tree_name(tree)`, `SkillTrees.converted(tree)`, `SkillTrees.section_of(tree)`; `node_def.branch` is the branch index (-1 root); versions are their own nodes (kind "version").
- bar-swap needs only `knows(skill)` and `Skills.ALL[id].styles` / `player.loadouts`.

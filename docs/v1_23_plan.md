# v1.23: the Playtest pass (Zach, 2026-10-26)

## What it is
After a ~2 hour co-op playtest on 1.22: the game is fun, but these things keep it from being great. Past the
third island the islands feel copy-pasted (a beast boss, a pirate boss, a bug nest, one village, a harbour).
Abilities unlock too slowly (black-leg mastery 18 had about two abilities). Knockbacks dominate combat (every player
has 2-3 knockdowns to use at will, so fights are repetitive). Big beast bosses are stiff, with poor animation and
effects. The Marines are cool but rare. Enemy ships can't catch you. No rival crew was seen. The bounty is hidden.
Bugs: falling through the ground into the water under the terrain, enemies leaving their arena with their health
reset, grunts standing still and spamming parry/block.

1.23 makes it fun. It **replaces 1.23 combat & gear**: the animation/FX pass folds in where it serves this, and new
weapons and armour stats move back a step (strongholds and Driftfruits likewise).

## Facts found before the grill (not decisions)
- **Rivals:** `RivalWatch` (scripts/ai/rival_watch.gd) places the Mudlark Brigade on the first chain island past
  Brinehollow, then rolls every 3+ islands at 45%. They only come once a captain has been ashore 20 s, is 45 m inland,
  and has nothing hostile within 25 m. Not seeing one in 2 hours is a bug to find.
- **Progression:** mastery only unlocks weapon nodes. They are bought from one shared Combat pool earned by Captain
  level (`Progression.combat_earned`: 2, then 1-2 a level to 10, 2 to 20...). Prices: move/mech 2, tech 3, ult 8
  (+level/10). An unlocked tree with no points to spend is the "two abilities at mastery 18" problem.
- **Knockdowns:** 34 places set `knockdown = true` (combo finishers, Arrow Kick, Cyclone Heel, Handstand Spin, heavies,
  techniques, grunts, bosses, cannonballs). Nothing limits knocking the same target down again and again.
- **Leash:** grunts use a fixed `LEASH` 26 m from their post; scuttlebugs 16 m; bosses have their own checks.

## Decided (2026-10-26)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Release | **1.23 = the Playtest pass**, replacing combat & gear | The fun problem goes first | - |
| Scope | **All four areas**: combat feel and knockback, island content and story, sea threats, progression and bosses (plus the bug pass) | Zach picked all four as top | - |
| Islands | **A story arc per island**: a pool of ~8-10 arc templates (a tyrant pirate holds the town, a corrupt Marine captain, a cursed festival, a beast terrorising a village, a heist, a rebellion, a shipwrecked noble...), rolled per island and themed. **3 beats**: arrive and hear of it; investigate or help (2-3 of today's POIs reused as story steps); the villain's showdown. The villain is the island's boss. The log pose works without the arc; the arc gives the big rewards and the bounty | Islands read as One Piece arcs, not POI checklists | Arc list preview |
| Knockdowns | **A poise / stagger meter**: hits stagger or push; a knockdown lands only when poise breaks (big enemies have more); a few seconds of immunity after a knockdown. Knockdown moves stay, but as a payoff you set up | Ends the knockdown loop and keeps the moves | Poise table preview |
| Enemy AI | **All four**: enemies defend (block, sidestep, parry some of the time; shielded and armoured types need a guard break or a flank); group tactics (surround, a few attack at once with clear tells, ranged keep distance, call for help, a captain buffs); elites and mixed squads (affixes: armoured, berserk, quick, fire); hit back harder (punish whiffs and spam: counters, grabs, openings to read) | Fights that need reading, not mashing | After play |
| Weapon points | **Points per tree**: each weapon tree (and the fruit) earns its own points as its mastery rises, enough to own most of the tree by its top | Using a weapon always pays for that weapon | Node/point curve preview |
| Captain levels | **Captain tree + stats**: HP/stamina/energy growth and points for the shared Captain tree only | No pool shared across weapons | - |
| Beast bosses | **Motion + spectacle pass**: weight and life (body sway, head tracking, tail/mane secondary motion, anticipation and follow-through on every attack, hit reactions, a stagger pose for poise breaks), a signature effect set per boss (roar shockwave, ground cracks, dust, a phase-change moment with a camera punch), a proper intro and death. **2-3 bosses to the bar first for Zach's OK**, then the rest | Stiff and chunky today | The first 2-3 |
| Boss phases (Zach, 2026-10-26) | **Each phase escalates**: most boss fights get harder phase by phase. A phase adds moves the boss didn't have (not just faster versions), a quicker tempo, longer combos and new arena pressure (adds, hazards), with a clear phase-change moment (roar/stagger, camera punch, effect). Every boss's move table lists its moves per phase for Zach's OK with the beast pass | Today a phase change barely changes the fight | The beast move tables |
| Sea pursuit | **All four**: chain shot tears sails (slower until repaired on deck) and grappling hooks lash ships for a boarding you must cut free from; faster hunters and fleets that cut across your course and pin you against islands or reefs; blockades at an island's mouth and nets or booms closing a harbour; rams that hole the hull and boats of boarders rowing over while you sail | Ships that can actually catch and trap you | After play |
| Marines | **Response to big deeds** (beat an island boss or finish an arc: a ring of ships at the harbour or around your ship as you leave; break out or fight through), **hunting you at sea** (patrols scale with the bounty, track your wake, come in from the edge of view, chase until you lose them in fog, storms or distance), **Marines in arcs** (a corrupt base captain, a Marine-run town, a prison break). Named hunters stay as 1.19 built them | More present, tied to what you do | After play |
| Bounty | **All four**: a new-poster moment after a big deed (poster, new number, a sting, the reason); a Wanted tab (each captain's poster, bounty, tier, what raised it, what the tier changes); a HUD heat marker while hunted, with an "escaped" moment; posters in the world (town boards, NPCs reacting, headline gulls) | Today it's hidden | - |
| Previews (standing rule) | Before building: the arc template list, a poise table per enemy class, and the per-tree point curve (nodes and costs over mastery) go to Zach for his OK | Feel systems get a preview first | - |

### Bug pass (not grilled; first)
1. Falling through the ground into the water under the terrain (captains, and check enemies and loot).
2. Enemies leaving their arena and their health resetting (bosses and grunts: leash vs the arena's bounds, whether a
   leash reset should heal at all mid-fight).
3. Pirate grunts and some other enemies stand still spamming parry/block.
4. Rival crews never showed up in a ~2 h co-op session (RivalWatch: the plan's save, the arrival hook, the ashore /
   inland / quiet conditions in co-op).
5. **Quests and journal** (Zach, 2026-10-26):
   - Main quests synced across the crew, but the random smaller quests sometimes didn't.
   - A boss killed before its quest was accepted had to be killed again after accepting it (a quest should count a
     target that's already dead).
   - The mouse breaks on the journal screen.
   - Old quests can't be abandoned, so they stay on the map late into the game: add **abandon/drop** in the journal.
   - Taking a new quest keeps tracking an old one: **a newly accepted quest becomes the tracked one**.

### Round 4 (2026-10-26)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Arena | **The capital's arena** (the 1.21 ladder: bouts, crowd, wooden weapons) is the buggy, unpolished one; it gets a polish pass. The island boss arenas only get the leash/reset fix from the bug pass | Zach | Details from Zach's next play or F12 captures |
| Wandering beasts | **Fewer, with behaviour**: herds graze and flee, predators stalk and ambush from cover, territorial ones warn first (posture, roar) before charging; the roamer becomes a rare event you hear coming, with the bosses' motion pass | Zach | After play |
| Order | **1** bug pass (terrain falls, arena resets, guard spam, missing rivals, quests and journal); **2** combat core: poise, smarter enemies, points per tree (previews first); **3** the beast motion pass (2-3 bosses first); **4** sea pursuit and the Marines; **5** island arcs (arc list previewed first); **6** bounty UI and rivals; then the capital arena polish and the roamers. Unstable builds as pieces land | Zach | - |

### Cutscenes and dialogue (2026-10-26)
Found: `Cutscene` (scripts/dialogue/cutscene.gd) types lines at `CHARS_PER_S` 38, holds `LINE_HOLD` 1.1 s, then moves on
by itself; nothing waits for input. That's why lines were "too fast to read" and "kept going without pressing anything".

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Advancing | **Press to advance**: each line waits for a key press (the first finishes the typing, the second goes on); the text types slower. Co-op: a line moves on once every captain has pressed, or after a ~10 s timeout so one AFK crewmate can't stall the crew. Skip-all stays as it is (everyone presses skip) | Readable, your own pace | After play |
| Replies | **Choices that matter a bit**: 2-3 replies at key moments (rival standoffs, arc villains, quest givers), cocky / cool / diplomatic. A reply changes their next line and sometimes the outcome (fight now or later, a bribe, a better price, a rival's grudge). Co-op: the captain who was spoken to picks, and every screen shows the choice | Agency without writing full dialogue trees | Arc list preview |

Order: advancing is a bug-pass fix (step 1); replies come with the island arcs (step 5) and the rivals (step 6).

### From the inspiration research (2026-10-26, docs/inspiration_research.md)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| In 1.23 | **Part breaks on beast bosses** (2-3 parts each: a break staggers it, removes or changes a move, drops a part material); **breakable places** (crates, stalls, fences, awnings under heavy hits and ultimates; a few big breakables in boss arenas); **masters teach trees** (a master per weapon tree in the chain, a duel test on the captain AI, techniques taught as mastery rises with a short "learned!" scene, the last nodes behind a final test; the face of points per tree); **bounty as heat** (the bounty is the difficulty bar: more and stronger patrols, elites, hunters, better loot and shady prices as it rises; raise it or lie low); **hidden finishes** (1-2 secret win conditions per boss or arc villain, each with a special reward) | Zach's picks | After play |
| Not picked | A **visible** guard gauge (poise stays hidden; the stagger shows it), a game-wide elite affix system (elites stay as decided in round 2), a separate loadout screen | Zach | After play |
| Own grills after 1.23 | **Crew Rush** (a shared gauge, combination finishers from two captains' styles); **style families and awakenings** (Power/Speed/Technique/Ranged movement, the ultimate tier as a timed transformation); **Sea Charts** (replayable star-rated co-op challenge missions); **shrines and cursed relics** | Zach | After 1.23 |

### Villages, harbours and interiors (2026-10-26)
Found: about a dozen shop kinds exist (grocer, fish, chandler, tailor, outfitter, curio, fence, glass, named traders),
but chain villages roll one or two; no instrument seller; Brinehollow's temple and tea house have no role; black leg is
chosen from the bag.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Villagers | **Every named NPC has a job**: vendor, quest giver, master or trainer, rumour-teller pointing at the island's arc, or a service (inn, barber, shipwright). Vendors are rolled per village size from a bigger pool (clothier, armourer, smith, instrument maker, cook, fence, cartographer, plus today's). Ambient crowds stay as scenery with no talk prompt | 85% of villagers did nothing | After play |
| Quest markers | **! over an NPC with a quest, ? over one to turn in** | Quests were hard to find | - |
| District variants | **More variants per district type** (market, harbour, plaza, square... in villages, cities and harbours), so the same market-stall ring isn't on every island | Reuse read as copy-paste | After play |
| Interiors | **Masters live inside**: the tea house is the black-leg master's kitchen (the kicking stance is learned there through a cook's test, not chosen from the bag); the temple houses another master (katana, or the Captain tree's meditation). Elsewhere an interior has a purpose (a counter, a quest giver, a chest, a rest spot); empty rooms are cut | Interiors did nothing; ties to masters teach trees | - |
| Marine outpost | **Warn, alarm, raid**: some villages roll a small fort or jail. Drawn weapons in town get a warning; a fight or duel rings the alarm and the fort sends squads (more with bounty). The fort's armoury holds a locked prize (a weapon or armour piece) you can raid, a stronghold in miniature; jailed NPCs can be freed for a reward | Marines present on islands; fits bounty as heat | After play |
| Clothing pass | **1.24 combat & gear**: fix every clothing piece (textures, clipping, cloth physics, shapes) and add weapon skins, armour and clothing variants and types, with the armour stats. 1.23's clothiers sell today's clothes | 1.23 is already big | 1.24's grill |

Order: villagers, markers, interiors and outposts go with the island arcs (step 5; the arcs' rumour-tellers and
villains live in these villages); district variants with them.

### Will, the Captain tree and passives (2026-10-26)
Found (scripts/progression/skill_trees.gd `_build_captain`): everyone gets Squall Step (level 8) and Ballast (level 14)
as Captain milestones, and each Will ability is given by beating a set boss (Iron Will: Morrow; Coat: a great ape;
Sense: the Brood Queen; Foresight: an arena beast; Captain's Will: a Leviathan with every other Will). Each Will passive
comes free with its boss. Passive slots: `PASSIVE_SLOTS` 3, a fourth at level 25. In co-op, captains beat the same
bosses together, so at level 15 Zach and his friend had half the same hotbar.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Will points (Zach, revised same day) | **Any big fight + training**: every boss, arc villain, rival captain, named hunter and Marine outpost commander gives Will points, whatever the island's theme, plus slow Will training as a sailing-downtime activity (meditation on deck). No Will is tied to a specific boss or theme (a chain with no jungle island locked Will away) | Nobody locked out by the chain's roll | Point curve preview |
| Will unlocks | **Will paths + Will points**: big fights give Will points, not abilities. Each captain chooses a path: **Iron Will** (armament: coat, harden, push), **Sense** (observation: flash, foresight, counters) or the rare late **Captain's Will** (needs both). Each path is a branch bought with Will points; Will masters (with the tree masters) teach a path's top abilities | Captains who beat the same boss grow differently | Point curve preview |
| Squall Step, Ballast | **Move to the life trees**: Squall Step into Acrobatics, Ballast into Defense, learned by doing. The Captain tree's milestones become non-hotbar perks (loadout slot, passive slots) | No identical hotbars | - |
| Passive slots | **Grow with level**: 2 at the start, +1 at Captain levels 10, 20 and 30 (5 at most). Passives come from every tree; Will passives are bought and slotted like the rest, no longer free | A real choice that grows | Point curve preview |
| Will variety | **All four**: versions per ability (2-3 each, switched at the bunk like weapon variants: Coat for heavier hits, faster combos or blocking through); **tiers that awaken** (Iron Will: coat, then emission at range, then the inner strike through armour and guards; Sense: flash, then foresight, then reading a whole crowd); **a Will colour per captain** (colour and aura style, seen in co-op); **Will clashes** (two big Will attacks meeting, vs a boss, rival or a crewmate in a duel, start a short clash to win by timed presses) | Will should feel personal and shonen | After play |

Order: with the combat core (step 2), alongside points per tree; previewed in the same node/point table. Saves: a
migration refunds Will and the moved milestones (Settings VERSION / Progression save format 7).

### The ship's life: rest spots, storage, galley (2026-10-26)
Found: the cabin chest is `GameManager.storage`, the crew's "bank" (the only thing that survives a death; the bag goes
on your grave), the host's shared in co-op. Variants, talents and passives switch only at the ship's bunk
(`Progression.BUNK_REACH`). In play the bunk/loadout system wasn't working or obvious, and banking felt one-way.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Switching builds | **At any rest spot**: the bunk, an inn, or a camp you make (the action wheel), with a clear prompt there; variants, talents and passive slots switch at any of them | Still a place, but many more, and obvious | After play |
| Banking | **Gone**: no "bank" wording or one-way deposit; storage is a normal two-way chest | Couldn't unbank; didn't apply | - |
| Death | **Grave run stays**: your bag drops where you fell (a marker); get back to it to recover it | Stakes without banking | After play |
| Storage | **Bigger, with a Personal tab and a Shared tab**: each captain's own (saved per captain, follows them in any crew) and the crew's (the host's world). **assumed** 40 personal / 60 shared slots, tuned in play | One crew chest didn't fit five captains | After play |
| Galley meals | A meal cooked with several portions goes **on the galley table**, where any crewmate takes a portion (E). **Cooking skills buff the eaters**: the cook's Cooking tree adds a buff (by the cook's level and nodes) to everyone who eats their food, named on the meal ("Zach's Sea Stew: +10% stamina regen, 10 min") | The One Piece galley; a support role for the cook | After play |

Order: with the combat core's progression work (step 2: rest spots, storage tabs, banking out) and the cooking buffs
there too; the save migration moves today's storage into the Shared tab.

### Performance track (2026-10-26)
Zach: the game "feels heavy at times, fine at others"; asked whether to move to Unity or Unreal. **Decided: stay on
Godot.** ~159k lines of procedural GDScript (463 files) and the whole tooling would be a year+ rewrite. The 1.21 bench
is CPU-bound by our own per-frame scripts (proc_scr ~5 ms, draw ~4.3 ms, GPU ~3 ms), so a port of the same design would
be slow there too. "Heavy sometimes" points at spikes, not the mean (Brinehollow ~12.7 ms vs the ~10 target).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Engine | **Stay on Godot 4.7**; native code (GDExtension C++) only for measured hot paths | The bottleneck is our scripts, not the engine | If native hot paths and LOD can't reach the target |
| 1. Spike logger (first, before Zach's next play) | Every frame over ~25 ms logs what ran (island build step, spawns, AI captains and enemies awake, the slowest scripts that frame, co-op peers) to `user://perf.log`, and the F12 capture includes the last spikes | Measure the heaviness instead of guessing | After that play session |
| 2. Time-sliced builds | Island build steps, mesh commits and spawns get a per-frame budget (~3 ms) and finish over several frames (the beast/boss steps read 150-200 ms today) | Hitches before the mean (standing rule) | Spike log |
| 3. AI and animation LOD | Far humanoids animate at 15-30 Hz; AI decisions at ~10 Hz, staggered across frames; a waiting rival or crowd member runs a cheap version until it fights | AI captains are full Player rigs | Spike log |
| 4. Native hot paths | Profile, then move the 3-5 hottest pure-math functions to a GDExtension (C++): likely the humanoid animator's joint math, wave height sampling, spring chains, AI perception | 10-50x on tight loops; everything else stays GDScript | Profile |
| 5. Budgets per system | Scripts, animation, AI and draw each get a slice of the frame, read by the perf gate | Creep shows the day it lands | - |

Order: the spike logger lands with the bug pass (step 1), so Zach's next session produces a log; 2-5 follow in the
order the log says, alongside the other steps. GPU-first (shaders, MultiMesh motion, GPU particles) stays the rule.

### Tutorial and UI walkthrough (Zach, 2026-10-26)
No controls or menus are explained today. 1.23 adds:
- **Vey's practice yard**: Vey walks the captain through every combat button (light combo, heavy, dodge, parry/block,
  techniques 1-5, the ultimate, drawing and sheathing, the loadout swap X), each tried on the dummies with a
  prompt and a tick, then sends them to try it all on the bandit camp.
- **A menu walkthrough**: short tooltip steps the first time each screen opens: the skill map (trees, points,
  buying, versions at rest spots), the loadout wheel and how loadouts work, the bag, the journal, the Wanted
  screen, and the interact/action menu (N). Each can be skipped and replayed from Options.

### Open / deferred
- Where masters live and who they are (one per tree, placed on chain islands and in the cities): **assumed** decided
  while building and listed for Zach's review with the per-tree point curve.
- Rival presence beyond the bug fix (Zach: no preference): **assumed** more often on islands (a gap of 2, and a crew
  can turn up mid-arc as a third party) and rivalry made visible (their posters and bounties beside yours, news of them
  taking an island ahead of you). Meeting rival ships at sea waits until the sea pursuit work has landed.
- What exactly is broken in the capital's arena: to get from Zach (a capture or a list) before its piece.

### Preview answers (Zach, 2026-10-26)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Previews | **Approved** with points per tree **option A** (2 a mastery level, +1 every 5: 66 at 30), the Will paths and sources, the poise and enemy AI tables, the 10 arcs, the three-boss beast pass and roamers (docs/v1_23_previews.md) | Zach | After play |
| Bounty heat | **A counterweight, not a reward**: a higher bounty brings more and harder pursuit (the patrols, blockades, hunters, elite share and shop refusals in the preview's table) and only a small upside: **+2% chest gold and +0.5% purple chance a tier** (at most +8% / +2% at Dreaded) | Zach: the preview's rewards were too much | After play |
| Black leg | **Keep Handstand Spin** (the 4th combo kick: it feels good). **Replace Cartwheel Crescent and Mule Kick** (they don't look good); **Flambe Dash goes far too far**: shorten it. Replacements **assumed** from the juggle set: Mule Kick's slot -> **Rising Heel** (a kick under the chin that launches the foe), Cartwheel's slot -> **Sky Chase** (air-step up to a launched foe, kick it higher or spike it down) | Zach | The anim pass |
| Juggling | **Launchers + chase**: launcher moves knock grunts, rival crewmen and the like into the air every time; minibosses only when their poise breaks; big bosses never (they stagger). Anything hit in the air stays up, each hit lifting it less, and it drops after ~3 s (no infinite loops). Air-step toward a launched foe to chase it and keep the combo going | Zach | After play |
| Air step | **The second jump (Squall Step) looks like stepping on air**: directional, the body leaning into the step's direction, a knee driving and the other leg pushing off, not upright like today. The normal and sprint jumps stay as they are | Zach | His look |

### Cloth and hair physics, native (Zach, 2026-10-26)
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| The reference | **The cape's motion** (SpringChains + mode "a"'s safety net: a soft cushion that eases a segment off the body before it touches, swing limits, never in front of the back) is how all cloth, hair and accessories should move: smooth, never buggy, readable | Zach likes the capes a lot | His look at hair and coats |
| Everything else | Hair, coat tails, skirts, scarves, sashes and accessories get the cape's safety net and limits (each its own cushion caps and swing range) | One feel across the wardrobe | 1.24's clothing pass |
| Native code | **GDExtension (C++)**: scons + godot-cpp pinned to Godot 4.7, a `native/` folder, SpringChains' solver (with the net) as `SpringChainsNative`; the GDScript one stays as the fallback when the library isn't there. The release workflow builds the DLL and the export preset ships it | The profile: spring chains are ~60% of the captain's rig | Bench after the port |

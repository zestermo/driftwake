# Handoff: 1.27 mid-way (2026-10-30), to resume on another machine

## Where things stand
- **On main, pushed with this handoff:**
  - The cities pass C1-C5 (rolled streets, interiors, rooftops, set pieces, investigations, jobs, dens, caches, the
    Stranger's leads, city favour, and the rulers' first quest steps).
  - **The palace hill rebuilt:** terraces and a grand stair, replacing the zigzag road.
- **Not released:** no tag and no GitHub pre-release since 1.26. The 1.27 work is all unstable-to-be.
- **Known:**
  - t/island/beast_moves is red (a rimeback move-variety check, likely older than this work).
  - "CapitalModels: no material beam" errors print in every capital test without failing it.
  - `export_presets.cfg` has an uncommitted local change: the export path goes to `../Driftwake.exe`, probably an
    editor resave. Zach decides whether to keep or revert it. It was deliberately left out of the commits.

## What to try in-game (the capital)
- **The grand stair:** walk up from the palace gate. It climbs three flights, with the terrace walks on top of each
  retaining wall and lawns with cypresses between them.
- **City favour:** ask the Queen "How does the Crown regard me?". The Doge now has a real conversation.
- **The rulers' first steps:**
  - After the audience, ask the Queen "Is there a service the Crown needs of me?". She sends you after the forged
    seal.
  - Ask the Doge "Can I serve the Republic?". He sends you after Grane's smugglers.
  - Each pays 400 gold once when you report back.

## The order Zach set (2026-10-30)
1. ~~The palace fix~~ (done).
2. **Next: the undercities, then stairs to upper floors, then the cities' night life.**
   - The undercities: flooded cellars and smugglers' tunnels under the canal city, and a cellar network under the
     capital. The plan's set-piece lists are in docs/v1_27_plan.md.
   - Stairs to upper floors: CapitalInteriors' hollow ground floors get a stair up to a first floor in some houses.
   - Night life: shutters, lamplighters, a watch patrol, taverns busier, people indoors.
3. The other rank rewards (titles on the captain card, royal stock, water taxis) are still deferred. Pick them up after
   the night life if wanted.
4. **Then the strongholds and the Driftfruit rework: discuss first, then build.**

## The discussion so far (decisions and Zach's direction)
- **Decided** (docs/v1_27_raids_fruits_plan.md "Decided (Zach, 2026-10-30)"):
  - The fruits: Bubble (joke), Iron (solid) and Storm (legendary) are new; Ember is legendary.
  - The great power is the Lagoon Prince, Corvo Malatesta, with the Storm Fruit; the Doge's line ends at him.
  - Only officers, Vice Admirals and the great power eat fruits.
  - The sea gate is a swim-under route for non-users.
  - The preview's numbers are the first pass.
- **Zach's direction**, same doc, "Zach's direction (2026-10-30)". It supersedes the earlier preview where they differ.
  - **Strongholds:**
    - A large fortress of **distinct districts**, a Dark Souls 3 / Elden Ring legacy-dungeon place. Big buildings with
      rooms for chaotic boss fights and wave fights.
    - A **30-60 minute** WoW-dungeon-like raid, **tuned for a squad of 3+** but soloable.
    - **Enemies keep respawning** through the zone (not in set encounter rooms or boss arenas) **until the main boss
      dies**.
    - Then the **Admiralty's emergency broadcast**. **2 minutes later the bombardment** (its own name, not "Buster Call") counts down: the fleet
      surrounds the island and your ship and barrages everything with huge explosive shells that set it all on fire.
  - **The Driftfruits are fully reworked** (moves, costs, progression, mixing with weapons, looks):
    - Mastery by use **evolves the powers**. An ability goes from activated, to triggering on its own, to always on.
      Zach's examples are logia bullet immunity, and flight going from a phase-dash/hover to free flight on Space for
      energy.
    - **Every fruit has an awakening.**
    - **Combat points also buy fruit progression**, so a captain chooses between weapon and fruit growth (Zach's lean).
    - **Controls** are open: one idea is a held modifier for a fruit hotbar (hold Alt for Q/E/R/LMB/RMB).
- **Still to discuss before building** (feel systems get a preview with numbers first):
  - The stronghold: its districts and order, the encounter rooms and bosses (is the Vice Admiral the main boss?), how
    stealth and alarm fit a respawning zone, checkpoints or the brig on a wipe in a 30-60 minute run, and the escape
    from the bombardment (to the ship and out, under fire).
  - The fruit rework:
    - The evolution stages per ability, with mastery thresholds.
    - The awakening's trigger and what it does per fruit.
    - The combat-point split against weapon trees, with a worked example over the level curve.
    - The hotbar/controls options (a mock).
    - How fruits mix with weapons in a loadout.
    - Energy costs.
    - The six fruits' kits under the new model.
- The build order in docs/v1_27_plan.md (steps 1-7) still holds broadly. Expect it to be revised after the discussion.

## How to resume
1. On the new machine: `git pull` on main.
   - Set `GODOT` to the 4.7.2 console exe.
   - Run `& $env:GODOT --headless --import` once.
   - Then `.\tools\dev\run_tests.ps1 t/capital t/canal` to see green.
2. Read docs/v1_27_raids_fruits_plan.md (the preview, Decided, and Zach's direction), docs/v1_27_plan.md (the build
   order and the cities' status sections) and this file.
3. Carry on with step 2 above: the undercities, the stairs and the night life. Write t/capital and t/canal atomic tests
   as before, and render with capitalshot.gd or canalshot.gd (CSHOT_ONLY=...).
4. Then hold the strongholds and fruit-rework discussion with Zach. Previews come first (tables and mocks), and
   nothing is built from picked options alone.

## Red before the push (prepush, 2026-10-30): fix first on the next machine
These suites failed in this run, from the unpushed 1.26.1 work (poise and knockback, bigger weapon trees) rather than
1.27. They're most likely stale tests (suspect the test first):
- **Knockdowns and hitstun:**
  - ragtest: "knockdown hit -> Downed"
  - grunttest: "hit from behind lands (hitstun)"
  - guntest: "shove: small damage + knocked down"
  - powertest: "ring knocks both down"
  - katanatest: "...and the grunt crumples"
  - axetest: "...the splitter knocks them flat"
  - foresttest: "...the charge floors whoever stays in the lane"
  - (1.26.1 piece 4 changed poise and knockdown.)
- **Tree sizes:** wieldtest ("the Corsair tree has 13-19 big nodes ... (26)") and daggertest ("12-19 big nodes"). The
  1.26 trees grew.
- **seatest:** "nobody aboard: no target".
- **uitest:** "load fits the canvas".
- **net-five:** a pistol crit. Fixed in nettest (aa97623b) and to rerun.
- **t/island/beast_moves:** known red.
Fix them, then `.\tools\dev\prepush.ps1` (it reruns only these and what the fixes touch, then pushes).

### Update (2026-10-30, later): the red suites mostly fixed
11 of the 12 now pass (966867ed; what changed is in dev_notes "Stale suites after 1.26.1's poise"), including a real UI
fix (the load screen's blurry 0.91 scale). Still red:
- **powertest:** the captain is swimming before the parry step (docs/todo.md).
- **t/island/beast_moves:** known red.
- **net-five:** fixed in the test, still to rerun.
The stronghold design moved on: preview v2 and its "Decided: the stronghold" table in
docs/v1_27_raids_fruits_plan.md (the Scouring, brig on a wipe, keep the prize, a burnt ruin after).

### Update (2026-10-30, evening): the cities' list done, both designs decided
- **Built and pushed:**
  - the palace stair;
  - the canal undercity and the capital's catacombs (CityUndercity);
  - stairs to an upper floor in about 60% of walk-in homes;
  - the cities by night (the crowd thins, a night watch with lanterns).
  - All city tests pass. dev_notes has a section for each.
- **Decided:** the stronghold (preview v2 plus its Decided table: the Scouring and the rest) and the Driftfruit rework
  (its Decided table: a shared combat pool, a fruit stance on V, evolution by use plus mastery, awakening at 30), both
  in docs/v1_27_raids_fruits_plan.md.
- **Next:**
  - The fruit kits for the other five fruits (powers by form, like Ember's table).
  - Then build: stronghold step 1 (the fortress, the place) from preview v2.
  - Still open from the cities: lamplighters, shutters, busier inns at night; smugglers to fight in the undercity; a
    water gate; the rank perks beyond the discount.
- **Stronghold placement, to decide before step 1:**
  - Chain.gd rolls islands layer by layer from one rng, so a new node shifts every later island's roll (a save's chain
    changes past it).
  - The safe way is to mark an existing island the stronghold: the first island of the layer after the canal city
    (`n["stronghold"] = true`, its content swapped, like `capital`/`canal` at CITY_LAYERS). Other islands stay as
    they were.
  - Build it like CapitalIsland: a fixed plan (StrongholdPlan, data) plus shell pieces a frame each.
- The six fruit kits (Storm, Iron, Wolf, Vine, Bubble, plus Ember's) are in the plan as a preview for Zach's OK.

### Update (2026-10-30, late): the stronghold built up
On main and pushed:
- **The place:** the stronghold is a new island off the chain (`chain.stronghold`, id 1000), built when a ship sails
  near it.
- **Its look**, from Zach's reference (docs/art/stronghold_reference.webp):
  - blue-grey stone, tall lantern towers with emblem banners, sheer walls and torches;
  - the Verdict: twin towers with a circle cut between them;
  - an arched Bridge of Judgement, viaducts and an arcade;
  - the sea gate with a walled harbour basin;
  - no gaps from below (MeshBuilder.all_faces).
- **Its shape:** a ragged rocky outcrop, reef shallows with a deep channel, sea stacks, and a west cove with a grated
  sewer drain.
- **Its first rooms:** the Mess Hall, the Barracks, the Casting Hall and the Command Hall, walked into and lit.
- Test: t/stronghold/place. Render: tools/dev/strongholdshot.gd (CSHOT_ONLY=...).

**Next for the stronghold:**
- More rooms: the prison's cells and the brig, the Arsenal's other halls, the keep's upper floors.
- The tunnel behind the drain.
- Then gameplay: the garrison with spawn doors and respawns, the sealed encounter rooms and their waves, muster flags,
  the bosses (the Drill Sergeant, the Commodore, the Warden, the Vice Admiral), the broadcast and the Scouring.
- Finding it (captured orders, rumours) and its chart entry.

### Update (2026-10-30, night): the garrison is in; the bosses are next, and how to build them
**Done and pushed:**
- The garrison (marine squads per district that respawn; StrongholdGarrison).
- Nav for the fortress.
- The Mess Hall's sealed fight (StrongholdEncounter: a grate, three waves, cleared for good).
- The boss lineup is decided (plan doc "Decided: the stronghold bosses"): Lieutenant Kesh (the Casting Hall), Captain
  Marrow (the Prison Tower), Commodore Vane (the Command Hall, three phases). The two seals can be taken in any order.
  A Vice Admiral leads the Scouring.

**How to build a boss (found while planning it):**
- **Spawning:** `Net.everyone("_all_spawn_rival", [Net.key_of(isl.city), name, look, weapon_id, at, yaw, skill])`
  builds an AI captain on every machine. The host's copy goes through RivalDuel.build (a CaptainBrain, a weapon, and
  give_kit's skills and ultimate by skill). Set it on with `brain.order = "fight"` (RivalEncounter._fight) and
  `brain.target`.
  - Kit: `EnemyShip.marine_look(lk, rng, true)` for an officer.
  - Off-hand: `Player.set_offhand(ItemDB.get_item("pistol"))` (cutlass + pistol = the Corsair).
  - Health: on the host, raise `health_component.max_health` by the boss's multiple and fill it.
- **Phases:** a StrongholdBoss node per arena (under City, like StrongholdEncounter), the host deciding. Work the
  phase out on every machine from something already synced (the boss's health if puppets carry it, else a world flag
  per phase via `Net.world_flag("sh_<boss>_p2")`), so clients need no new RPC.
- **Hazards that hurt captains** (the molten channels, the Commodore's fire quarters): each captain takes damage on
  their own machine. So every machine works out the hazard's timing from a shared clock (`Ocean.clock()`) and the
  phase, and hurts only its own local player (`player.hurtbox.take_hit(HitData)`).
  - FireZone burns enemies, not captains: don't use it for these.
  - Telegraph with FX ground_warn first.
- **The seals:** a world flag per boss beaten ("sh_seal_arsenal", "sh_seal_prison"). The keep's gatehouse gets a
  barrier like the encounter grate while either is missing.
- **The Commodore's phase 2 adds:** reuse StrongholdEncounter's waves (an encounter node in the Command Hall the
  boss arms).
- Tests to write: t/stronghold/boss_lieutenant (spawns on entering, his weapon and kit, phase 2 at 50%, the seal on
  defeat), then the Captain and the Commodore likewise.
- (later) **The officers in the crowds** are built (StrongholdOfficers: one per district as you reach it, then 35% per
  new wave, 5 standing at most, detuned). Zach's direction on pacing (Burning Blood-style crowds, Enies Lobby / Impel
  Down set pieces) and **the Admiral's escape fight** at the Scouring are in the plan doc ("Zach's direction
  (2026-10-30, night)"). The Admiral fight:
  - He blinks in front of whoever runs for the ship and knocks them back.
  - He's tanky, deliberate and never an instant kill.
  - At about 2/3 of his health he speaks and leaves; then you escape.
  - Build it after the Commodore, with the Scouring: the same spawn path as the bosses, plus a blink-and-knockback
    behaviour toward the captain nearest the ship.
- (later) **Kesh and Marrow are built** (StrongholdBoss: a room or open-arena boss, phase 2 by a world flag, its seal),
  with the keep's SealGate opening on both seals. Tests: t/stronghold/kesh, t/stronghold/marrow.
- **Next:** Commodore Vane (the Command Hall; three phases).
  - Phase 2's adds: an armed StrongholdEncounter with marine waves.
  - Phase 2's fire quarters: like Kesh's channels.
  - Phase 3: dual wield and an enrage (shorter cooldowns, more speed), and his fruit if he holds one (step 5).
  - Still to add: Marrow's seastone net and catwalks, then the broadcast and the Scouring (with the Admiral's escape
    fight).
- (later) **Commodore Vane is built:** three phases, the marine waves and flaring quarters, the Verdict's enrage, and
  "sh_seal_keep" on his fall (t/stronghold/vane). All three stronghold bosses are in.
  - **Next:** the emergency broadcast and the Scouring (the fleet ring, telegraphed shells, spreading fires, the escape
    to 500 m out) with the Admiral's escape fight (blink and knockback near the ship, leaves at about 2/3 health). Also
    the respawns stopping once the Commodore is down.
  - **Polish:** Marrow's seastone net and catwalks, the Commodore's fruit in phase 3 once fruits land, rewards (the
    vault's legendary, bounty), the muster flags and the brig on a wipe.

### Update (2026-10-30, latest): the stronghold's raid is playable end to end
On main and pushed: the garrison, the officers (5 at most), the Mess Hall's sealed waves, Kesh, Marrow, the seal gate,
Vane's three phases, the broadcast, the Scouring and the Admiral's escape fight, and the raid bounties. Tests:
t/stronghold/* (7 suites, all green).

**Zach's instruction:** "continue without stopping until you fully finish 1.27 or you hit 95% usage": finish the
strongholds, then build **ten Driftfruits** (plan doc "Zach's direction (2026-10-30, late)").

**Stronghold work left:**
1. **Finding it:**
   - captured orders: a beaten Admiralty officer at sea drops them, and `Chain.learn_stronghold` puts it on the chart;
   - a tavern rumour;
   - the chart showing it only once `Chain.stronghold_known`;
   - the Queen's line step 2 (the writ).
2. **The vault:** the Command Hall's chest after "sh_seal_keep", with a named legendary weapon with a trait (one per
   stronghold, from the plan's list) and the chain's best chest.
3. Muster flags and the brig on a wipe.
4. Marrow's seastone net and catwalks.
5. Escape-from-the-ship polish: the Scouring with the real ship in a world test.

**Fruits** (plan doc: "Decided: the Driftfruit rework", "The six fruit kits", and Zach's ten-fruit direction):
- **The framework first:**
  - the fruit stance on V (LMB/RMB the fruit's attacks, Q/E/R its powers);
  - each power's three forms by its own use plus fruit mastery (Reflex at 150 uses and mastery 12, Nature at 400 and
    24);
  - the shared combat pool;
  - awakening at mastery 30;
  - `DevilFruits.IN_WORLD` on.
- **Then the fruits one at a time,** each to a weapon-size tree (fewer stat nodes, more connected). Today's code:
  scripts/powers/devil_fruits.gd (FRUITS: ember, wolf, vine), skill_trees.gd `_build_ember` and the others, Skills.ALL.
- **The ten:** the six in the plan (Ember, Wolf, Vine, Iron, Bubble, Storm) plus four more. Zoan and logia are
  consistent in structure; paramecia are each very different, some not for combat. Each has a movement power, two
  ultimate options and some CC.
- (latest) **Also done:** finding the stronghold (captured orders from a raided outpost, the chart marker, a rumour), the
  vault and its legendary, and the wipe to the brig.
  - **Stronghold left:** muster flags (respawn at a raised flag while the crew is up), Marrow's seastone net and
    catwalks, a world test of the escape with a real ship, and the Queen's step 2 (the writ).
  - **Next:** the Driftfruits.
- (latest) **Driftfruits so far:** the roster of ten (plan doc), FruitForms (the forms by use plus mastery) and FruitPool
  (once per save, tiered draws, sell prices), each tested. **Next for fruits:**
  1. The fruit stance on V (the Wolf's hybrid V is the model: in stance LMB/RMB are the fruit's attacks, Q/E/R its
     powers).
  2. Rebuild Ember, Wolf and Vine to the new kits (the plan's tables), with the Reflex and Nature behaviours per power
     reading FruitForms.form.
  3. Add Storm, Iron and Bubble, then Gust, Bear, Clockwork and Echo (items, icons, Skills.ALL entries, trees in
     skill_trees.gd).
  4. Turn IN_WORLD on with the sources drawing from FruitPool, then enemy users (officers and Vane's phase 3), the
     costs (the sea's weakness and rescues) and the Seafarer tree.
- (latest) **The fruit stance on V** is in (PowerComponent.set_fruit_stance, `other_loadout`, saved as "fruit_loadout").
  - **The shared combat pool** (decided: 3 points a level across the weapon and fruit trees) is **deferred on purpose**.
    It changes how every weapon tree buys (SkillTrees.pool_of / Progression.earned, each tree's own points today) and
    what existing saves have spent: do it as its own piece, with a refund-and-rebuy for old saves and the economy tests
    updated.
  - **Then the kits:** Ember first as the template.
    - Each of its five powers gets a Skills.ALL entry for its Active form.
    - Its Reflex and Nature behaviours sit in the player's hit and dodge paths, reading FruitForms.form(pr, id, "ember").
    - The tree is in skill_trees.gd `_build_ember`, rebuilt to the plan's shape.
- (latest) **Ember's Flame Body is the first power with its three forms** (Flicker, Skills.ALL plus the e_flicker node;
  Player._flame_body). It's the template for the rest of Ember's powers (Fire Fist, Blaze Step flight, Fire Ring, Pillar
  of Flame), then the other fruits.
  - Every new active skill needs a tree node (t/progression/tree_shape checks it).
- (latest) **Ember:** Flame Body, Cinder Fist and Blazing Ring are done with forms (dev notes). Next: Blaze Step's
  flight, Pillar of Flame, the awakening, Ember's tree. Then the same for the other nine fruits.
- (latest) **Ember's awakening Sunborn and the Wolf's Rending Fang forms are in** (fruit trees cap at 30 now).
  - **Pattern per power:** Skills.ALL Active, a tree node, then its Reflex and Nature in the path they belong to (hit,
    dodge, landing, wounds, aura), reading FruitForms.form.
  - **Next:** the Wolf's other powers (Pounce, Howl, Scent, Moon Leap), Vine's, then the new fruits. Each new fruit
    needs an item .tres (copy ember_fruit.tres), a DevilFruits.FRUITS entry, Skills.ALL powers, a SkillTrees entry
    (cap 30) and a `_build_<fruit>` tree.
- (latest) **Vine Snare's forms and the Iron Fruit's first piece are in** (Iron Guard with forms, Iron Fist, its item,
  entry and tree).
  - **The recipe for a new fruit:** copy iron_fruit.tres, add a FRUITS entry, Skills.ALL powers with cast branches in
    try_cast (or a SkillState case for animated ones), their forms in the right path, and a SkillTrees entry plus
    `_build_<fruit>`.
  - **Next:** Storm, Bubble, then Gust, Bear, Clockwork and Echo; then each fruit's remaining powers, ultimates and
    awakening; then IN_WORLD on with FruitPool.
- (latest) **Storm piece 1 in** (Thunder Step, Chain Lightning with its Reflex). Next: Bubble, then Gust, Bear, Clockwork, Echo (the recipe above).
- (latest) **Bubble piece 1 in** (Bubble Shield with its forms, Slick Floor). Six fruits exist now: Ember, Wolf, Vine, Iron, Storm, Bubble. Next: Gust, Bear, Clockwork, Echo (the recipe above), then each fruit's remaining powers, ultimates, awakenings, icons and models.
- (latest) **Gust piece 1 in.** Seven fruits exist: Ember, Wolf, Vine, Iron, Storm, Bubble, Gust. Next: Bear, Clockwork, Echo.
- (latest) **Bear piece 1 in.** Eight fruits exist. Next: Clockwork and Echo.

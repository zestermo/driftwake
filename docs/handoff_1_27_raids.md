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

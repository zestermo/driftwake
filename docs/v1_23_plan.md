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

### Open / deferred
- Where masters live and who they are (one per tree, placed on chain islands and in the cities): **assumed** decided
  while building and listed for Zach's review with the per-tree point curve.
- Rival presence beyond the bug fix (Zach: no preference): **assumed** more often on islands (a gap of 2, and a crew
  can turn up mid-arc as a third party) and rivalry made visible (their posters and bounties beside yours, news of them
  taking an island ahead of you). Meeting rival ships at sea waits until the sea pursuit work has landed.
- What exactly is broken in the capital's arena: to get from Zach (a capture or a list) before its piece.

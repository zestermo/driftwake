# v1.19 (Zach, 2026-10-19)

## What it is
**Marines and rival crews** (Zach, 2026-10-19, revised): rival pirate crews (docs/rival_crews_plan.md) and the
Marines with bounties (roadmap phase 6), plus a new interactive timeline roadmap on the website (below). A tooling window comes first. The perf pass and fishing moved into 1.18,
and gear upgrading waits for a later release. The table below is the earlier draft, kept as a record.

## Decided (2026-10-23): the full grill
Zach settled the whole version in one grill so it can be built in one go. This section is the plan of record and
**overrides the 2026-10-19 table below** where they differ (marked "reopened").

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | **Rival crews** (captain-style AI, cutscene system, crews) + **the Admiralty, full roadmap phase 6** (bounties, wanted posters, patrol ships at sea, named hunters) + **the intro redesign** + **fighting in the water** + **the weapons' enemy pass**. Out: two/three-sword katana (later), gear upgrading (later), the Admiralty fortress (1.22 strongholds). | Zach: finish the whole version. | — |
| Admiralty at sea (**reopened**: was "patrols and pursuit wait for 1.20") | Patrol ships in busier waters that come about when they spot a wanted captain, built on today's enemy ships and boarding; named hunters past bounty thresholds. | Zach chose full phase 6. | After play |
| Carried over from 1.18.4 | Greatsword finish, black-leg finish, corsair/pistol guards, the web roadmap timeline: **already done** (Zach). | — | — |
| Opening | The tooling window first (crew_lib deps-file race, autoload-name lint); **the perf pass counts as done** (the 2026-10-22/23 combat perf work and skinned bodies piece 1). | Zach. | Prepush bench |
| Rival roster | **Authored captains**: 3-4 hand-written signature crews per chain (captain personality, theme, flag, signature weapon, lines) crewed by seeded members from pools. | Rivals you get to know; members vary per save. | — |
| First meeting | **Placed first, then rolled**: the first meeting is set on an early chain island after the intro sets them up; then crews turn up on rolled islands every few islands, scaled to their level. | — | After play |
| Captain-style AI | **Fair but sharp**: sees only what a player could (your tells, your spacing), blocks, dodges and parries some of the time, punishes whiffs, saves its ultimate for an opening. Skill per member (a rookie vs the captain). Used by rivals, Admiralty officers and hunters. Numbers tuned in play. | "Fought by seemingly other players." | After play |
| Cutscene skip (co-op) | **Everyone presses skip**: a "waiting for N more" chip; it skips for all when the last captain presses (or it ends). | Nobody misses a scene they wanted. | — |
| Bounty (co-op) | **Each captain's own** bounty and poster, raised by what they did; the ship draws patrols by the crew's total. | — | — |
| What a bounty changes | **All four:** Admiralty heat (patrols, ships coming about, named hunters past thresholds, tougher as it climbs); **townsfolk react** (recognition lines, whispers, some flee; posters on boards; Admiralty-friendly shops charge more or refuse, shady ones give a better rate); **rivals react** (lines and respect follow it; bigger bounties draw stronger crews); **bounty hunters** (civilian ambushes on islands, apart from the Admiralty). | Zach. | Economy pass |
| Losing to the Admiralty | **Arrested, then escape**: you wake in their ship's brig or an outpost cell, gear in a chest nearby, and break out (a short escape run); a share of gold is confiscated. | Stings, and its own little scene. | After play |
| Arrest in co-op | **Only if all captains go down**; then everyone wakes in the cells together. While one stands, the downed get revived as usual. | Zach. | — |
| Named hunters | **Persistent**, built like the rival crews: a named officer (look, weapon, voice, lines), remembers wins and losses, returns scaled and better equipped, tracks your ship down the chain and waits at harbours. | — | — |
| The Admiralty's look | **Grey ironclad**: slate grey and steel, armoured officers, darker ships; oppressive. | Zach. | — |
| Intro: motive | **Legend + personal spark**: a legendary prize past the end of the First Sea that the great powers want, and a personal spark on day one (the Admiralty strikes at the captain's home or mentor) so they set out to get strong enough to reach it and answer them. | Gives the game a goal. | — |
| Intro: form | **Cutscene + short play**: a ~60-90 s skippable cutscene (the Admiralty, rival crews, the great powers, the sea's end), then the personal spark as a short playable moment, then Brinehollow as today. | — | — |
| Fighting in the water | **Your own weapon**: a swimmer fights with what they carry, slowed, with water versions of a few moves (no separate diving knife or harpoon). Sharks and morays become fightable in the sea; the captain AI can follow you into the water. | Zach. | After play |
| Weapons' enemy pass | As recorded below (grunt roles for spear, hammer, twin axes, greatsword, black-leg; readable cut-down movesets; they drop their weapon), fielded by rivals and the Admiralty too. | — | — |
| Names and lines | **Claude writes, Zach reviews**: original Driftwake names (the legendary prize, the great powers, Admiralty ranks, the rival crews and captains) and lines, no One Piece terms (docs/originality_plan.md); listed in this doc for review. | — | Zach's review |
| Build order | Tooling, the captain-style AI (on a debug duel key), the cutscene system, rival crews, bounties and posters, the Admiralty at sea and hunters, arrest and escape, the intro, fighting in the water, the enemy pass. Each lands in playable pieces. | The AI is the root the rest builds on. | — |
| Unknowns while building | **Decide, note, keep going**: the option that fits this record, marked **assumed** in "Assumed while building" below, for Zach's review. | Uninterrupted build. | Zach's review |

### Decided after release (2026-10-23), folded into 1.19
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| The waiting crew | **Side work, not circling**: the crew waits off to one side of the duel, each at their own activity (drills, a book, tinkering, an instrument, sitting; never two the same) or just watching, heads on the fight. | Zach: they look like they're working on their own skills. | After play |
| Solo fights | **A shorter gauntlet**: one or two mates (the best matches for your style), then their captain; co-op keeps a rival per captain. | Not a 5-duel grind alone. | After play |
| Their spot | **Just the crew**, no camp props (their own crates and books only). | Works anywhere. | - |
| Reactions | **Brief**: they look up at a mate down, their captain's turn or an ultimate; watchers groan or cheer; the next one gets up and walks in. | - | - |

### Assumed while building
- **Tooling window: already done on main** (checked 2026-10-23): compilecheck has the STATIC AUTOLOAD lint, crew_lib
  reads a deps file inside a try/catch (a file deleted mid-read is a miss), nettest's logs and deps are named per mode
  and its port is random per run, Humanoid._rng is seeded from the (test-seeded) global rng, fauna tests name creatures.

### Build notes: the captain-style AI
- A rival is a **real `Player`** (player.tscn) in AI mode, so it fights with the same states, weapons, skills,
  techniques and ultimates. Three captain kinds: local (keyboard/pad + camera), puppet (co-op: snapshots, no brain),
  **AI** (`is_ai`: the full brain, fed by a brain instead of the keyboard).
- **Input:** `Player.inp` (`CaptainInput`): held input (the stick, sprint, block, jump...) and the view's yaw. The
  local captain's wraps `Input` and the camera rig; an AI's is a `CaptainInput.BrainInput` its brain sets each tick.
  Discrete presses go through the InputBuffer (`buffer_action`); skills, the ultimate and drawing call the Player.
- **Local-only feedback** (camera shake, HUD, slow motion, screen flashes, saves, registering as the captain) is the
  local captain's; an AI captain's shake falls off with distance from the camera.
- **Sides:** an AI captain's hitboxes and target queries use the players' hurtbox layer (128) instead of the enemies'
  (32), and its hurtbox sits on the enemies' layer; it's in the "enemies" and "rivals" groups, never "player(s)".
- **Co-op:** the host simulates AI captains; guests see them as puppets (the captain snapshot path).

### Build log
- **Piece 1 (2026-10-23): the AI captain + a debug duel.** `CaptainInput` (scripts/input/captain_input.gd) and
  `Player.inp`; `Player.cam_shake()/cam_kick()/foe_mask()` (not shake/kick: siblings answering has_method("shake") pass for the camera rig); `Player.is_ai`, `Player.spawn_ai()`, `_setup_ai()`;
  `CaptainBrain` (scripts/ai/captain_brain.gd); `RivalDuel` (scripts/ai/rival_duel.gd), **Alt+F5** in a debug build.
  Test: t/combat/rival_duel.
- **Piece 2: rivals' skills and co-op.** `RivalDuel.give_kit`: weapon and captain skills that fit its style (a rookie 1, a captain 4 and an ultimate half charged). Co-op: `Net._all_spawn_rival` / `_all_rival_gone` (deterministic names); the host's AI is in `net_sync` (its captain snapshot), a guest's copy is a captain puppet built `is_ai` (enemies' side, its hurtbox on 32: a guest's blow routes to the host); `Net.ignore_overlap` and Hitbox let an AI captain's own swing be judged on the host and routed to the guest. nettest mode `rival` (prepush). Assumed: the debug key is the host's.
- **Piece 3: cutscenes.** `Cutscene` (scripts/dialogue/cutscene.gd): camera shots with eased dollies, lines as
  subtitles in the letterbox (the speaker's name over the typed line, voice blips at their pitch), the captain held,
  AI brains still; `Cutscene.scripted(kind, args)` builds the same shots on every machine (`Net._all_cutscene`);
  skip is a vote the host counts (a "waiting for N more" chip). Test: t/ui/cutscene. Render: tools/dev/rivalshot.gd.
  **Assumed:** cutscene lines are subtitles, not bubbles (a world bubble in a close-up is huge and clips the bars);
  fight lines are bubbles over the head (`SpeechBubble`, `FX.speech` through Net.fx).
- **Piece 4: rival crews.** `RivalCrews` (scripts/ai/rival_crews.gd): four authored crews for the first chain, for
  Zach's review: **the Gilded Gulls** (Captain Marisol Vane, "the Gilt Blade": a vain showboat duelist, cutlass,
  white and gold), **the Brine Wolves** (Captain Haskel Rourke, "Ironjaw": a gruff brawler, warhammer, slate and
  steel), **the Lantern Saints** (Captain Odessa Krane, "the Quiet Lamp": calm and exacting, katana, black and red),
  **the Mudlark Brigade** (Captain Pip Tallow, "the Tide Rat": a cocky kid, dagger, mud green and brown); their
  lines (meet, again, grudge_won, grudge_lost, taunt, hurt, ult, mate_down, retreat, gloat) and mates rolled from
  each crew's name pool and palette (seeded per crew and save). `RivalEncounter` (host): they turn up in a line
  facing you, the meeting plays (its lines by the record), duels in turn (one rival per standing captain, the best
  match for the lead captain's weapon first, the captain last; the rest ring the fight and taunt), retreat at 30%
  of their captain's health (gold, 35% a trait weapon of the captain's kind), every captain beaten = spared (Duel)
  and plundered (25% of the gold), back up once they've gone. GameManager.rivals {met, won, lost, last}, saved.
  **Ctrl+Alt+F5** calls up the next crew. Test: t/combat/rival_crew.
  **Assumed:** 2 mates the first time, 3 the second and third, 4 after (`RivalCrews.MATES`); a return makes them
  tougher (+15% health a meeting, their captain x1.8) and sharper (+0.12 skill a meeting); their captain never
  dies (beaten, they call the retreat); co-op pairs each captain with the next rival in the queue (not yet by each
  captain's own mastery); the debug arrival is "turn up in a line 14 m off" (landing by ship comes with the
  placement piece).
- **Piece 5: where they turn up.** `RivalWatch` (scripts/ai/rival_watch.gd, GameManager's, the host's): on each
  chain arrival it decides; the meeting comes once the captain has been ashore 20 s, is 45 m in from the dock and no
  fight is on, the crew coming up from the dock's side. Plan in GameManager.rivals["_plan"]. Test:
  t/combat/rival_placement (the decisions). **Assumed:** the first meeting on the first chain island past
  Brinehollow (layer 1) with the Mudlark Brigade; then none until 3 islands have passed, 45% an island after
  (about one meeting every five islands), never at the capital, crews not met yet first, never the same twice
  running; they "land" by walking up from the dock (no rival ship model yet). **Not yet tested in a world:** the
  trigger on a real chain island (try: sail to the first chain island, walk inland).
- **Piece 6: bounties.** `Bounty` (scripts/game/bounty.gd): each captain's own (`Player.bounty`, saved with the
  captain, in the co-op snapshot), raised through `Net.bounty(kind, at, reach, k)` for every captain in reach, a toast
  each time and a banner when a tier is crossed; the HUD shows "Bounty 6,900 - Wanted" under the gold. Test:
  t/progression/bounty. **The numbers, for Zach's OK** (CLAUDE.md: feel systems preview their numbers; Zach took
  "decide, note, keep going" for tonight, so they're built as one table in Bounty, quick to change):

  | Deed | Bounty (gold) |
  |---|---|
  | a rival crew beaten | 3,000 x the times you've met them |
  | a boss (a camp's or fort's captain, a beast boss) | 6,000 (a miniboss or the roamer 40%) |
  | a Leviathan | 4,000 |
  | a pirate ship sunk or taken | 1,500 |
  | an Admiralty ship sunk or taken | 5,000 |
  | an Admiralty officer beaten | 4,000 |
  | a named Admiralty hunter beaten | 12,000 |
  | a bounty hunter beaten | 1,500 |

  | Tier | From | Switches on |
  |---|---|---|
  | Wanted | 5,000 | posters, townsfolk know your face, Admiralty-minded shops +15%, shady ones -8% |
  | Notorious | 20,000 | patrols come about for you, bounty hunters; Admiralty shops +25%, shady -12% |
  | Infamous | 60,000 | a named hunter takes your trail; Admiralty shops won't serve you; shady -15% |
  | Dreaded | 150,000 | the hunters come tougher and in pairs, the strongest crews seek you out; shady -20% |

  Pace (estimated, not played): the first chain's islands give a boss and a couple of ships each (~9,000), so
  Wanted on the first or second island, Notorious around the fourth or fifth, Infamous near the chain's end.
- **Piece 7: what a bounty changes on land.** Wanted posters (`WantedPoster` on every KitVillage notice board:
  empty until someone's wanted, then the two most wanted captains' names and bounties); shops by trade
  (`Bounty.shop_k`: armourers and smiths supply the Admiralty: dearer, then no service at Infamous with a line;
  treasure dealers are shady: cheaper; the rest as ever); townsfolk barks: half their lines are about the wanted
  captain (`Bounty.RECOGNISE`, by tier). Test: t/progression/bounty. **Assumed:** townsfolk only talk (no fleeing
  yet: villagers have no flee behaviour; a later polish); the posters show the captains' names and bounties, no
  portrait; which trades lean which way (armourer, smith / treasure).
- **Piece 8: rivals react, bounty hunters.** A rival crew comes stronger for a bigger bounty (their tier: the times
  met or the captain's bounty tier, the higher) and their captain has a line about it in the meeting (each crew's
  "bounty" lines, the amount filled in). Bounty hunters (`RivalCrews.HUNTERS`, `RivalEncounter.start_ambush`): no
  meeting, a shout, all at once, no retreat, 1,500 bounty and gold a hunter; they plunder like a crew if they win.
  RivalWatch: from Notorious, 35% on an island no crew comes to (seeded), 2 hunters (+1 a tier above), after 40 s
  ashore and 30 m in. Tests: t/combat/bounty_hunters, rival_crew, rival_placement. **Assumed:** the numbers above
  (chance, count, wait); hunters are civilians in drab browns with a name pool of their own (Zach's review).
- **Piece 9: the Admiralty at sea.** The old Marine patrols (EnemyShip kind "marine": the lane past Brinehollow, the
  sea legs' picks) are the Admiralty's now: "Admiralty Cutter", grey ironclad (slate sails with a steel gull crest,
  crews in slate jackets and steel helmets, half with cuirasses, the officer in a dark longcoat), in group
  "admiralty" (sinking or taking one: an Admiralty ship's bounty). They leave a crew alone until the crew's
  bounties together are Notorious (`EnemyShip.crew_bounty`, `ADMIRALTY_FROM`), then come about ("That's the wanted
  ship! Come about!"); fired on, they come for you whatever. Test: t/ship/admiralty_patrol. **Follow-up:** the hull
  stays wood-brown (the plank texture swallows a cool tint; tints over 1 clamp in the folded vertex colours): a
  grey hull wants a grey plank texture (gen_psx_textures) or an iron-plate band. **Assumed:** "more patrols as the
  bounty climbs" waits (the lanes are fixed at world build); the named hunters bring the extra heat.
- **Piece 10: named Admiralty hunters.** `RivalCrews.ADMIRALTY`, for Zach's review: **Commander Idris Vael** ("the
  Grey Ledger": cold, precise, katana, keeps a ledger of names), **Captain Bertrand Hollow** ("the Breakwall": a
  stout wall of a man, greatsword, morion), **Commodore Sabra Quill** ("the Iron Tide": sharp, warm, commodore of
  the Grey Fleet, cutlass, bicorne); each with a squad of marines in the grey. Run as RivalEncounter squads: the
  meeting (their lines by the record, a line about your bounty), then the whole squad at once (the Admiralty doesn't
  duel), the officer withdraws at 30% (never dies; comes back stronger), a hunter's bounty (12,000) when they do.
  RivalWatch: once the crew's bounties together are Infamous, 50% of islands (seeded) have one waiting at the
  harbour, coming at you from the land side once you're ashore; the officers in turn. **Shift+Alt+F5** calls the
  next. Tests: t/combat/admiralty_hunter, rival_placement. **Assumed:** squad size by the same tiers as the crews
  (4 marines at Infamous); "tracks your ship down the chain" = waiting at the next harbours (no sea pursuit by a
  hunter's own ship yet); until the arrest piece, beating every captain plunders like a crew.
- **Piece 11: arrest and escape.** `AdmiraltyBrig` (scripts/ai/admiralty_brig.gd): every captain beaten by an
  Admiralty squad wakes in the brig (built on every machine at BRIG_AT, high above the world: a sealed room, the
  ceiling keeps the rain out), 30% of their gold and their weapon (and off-hand) confiscated; F at the cell door picks
  the lock (3 s; anyone's opens it for all), two marine guards (captain-style AIs) come on; the chest gives each
  captain their own gear back; the hatch puts them back where they were taken; everyone down in there: back in the
  cell, the door shut; everyone out: the brig goes. Net._all_arrest, _all_brig_door, _all_brig_gone. Test:
  t/combat/arrest. **Assumed:** the brig is the Admiralty ship's (one plank room, a cot, a lantern), not an outpost
  cell; only the equipped weapons are taken (the bag's others stay); no escape timer; the interior's look is
  unchecked by a render (sealed: try it in game, Shift+Alt+F5 then let them beat you).
- **Piece 12: the intro.** `Intro` (scripts/game/intro.gd), for Zach's review: a new game (after the creator, single
  player) plays six narrated lines over a staged night storm far out at sea (the storm wall at the First Sea's end;
  **the Last Lantern** past it, a light that shows the way to whatever a heart wants most; the Admiralty's grey
  ships; the rival crews; **the Tide Lords**, four captains beyond the storm), the last on **Captain Maren Holt**
  and her deckhand (you); then played: two marines from the grey cutter alongside come over the rail, Holt's last
  order ("find the Lantern... make them answer for this"), a broadside, black, and the beach (the story as before).
  Weather and time are put back. Cutscenes now follow node-anchored shots every frame (a rolling deck). Test:
  t/ui/intro; render: tools/dev/introshot.gd. **Assumed:** the spark is the night you washed up (the existing
  start); the narration's words; skipping it skips to the fight (the fight is short: 50 s at most).
- **Piece 13: fighting in the water.** SwimState: attack = a quick strike with your own weapon (its stab: cutlass
  thrust, dagger stab, spear thrust, a jab bare-handed; 11 base, 6 stamina, every 0.55 s), heavy = a lunging cut
  (20 base, 14 stamina, a 2 m lunge, its blow early in it); at the surface or on a dive; the weapon comes out for it
  and goes back 2.5 s after; not while exhausted. Hits through `power.enemies_in`, so sharks and morays (their
  break-off at half health comes sooner now you can hurt them) and AI captains who follow you in (the same states:
  an AI captain fights in the water the same way). Test: t/swim/water_strike (t/swim green). **Assumed:** the
  numbers; no new animations (the land strikes played on the swimming body); techniques and skills stay
  land-only.
- **Piece 14: the weapons' enemy pass.** `PirateGrunt.ROLES`: spear (thrusts, a lunging heavy, a leg sweep; reach
  2.7), hammer (single smashes, an uppercut heavy; x1.45 damage, slower wind-ups), greatsword (two swings, a heavy;
  reach 2.6, x1.35, slow), twin axes (two quick chops, a heavy; reach 1.9, x0.85, quick), black-leg (two kicks, a
  heavy kick; no weapon to drop). The weapon's own move plays whole (its wind-up the tell); no flurries, feints,
  blocks or pistols (a cut-down moveset you learn to read); each drops its weapon. On chain islands 30% of
  ordinary sword grunts (seeded: the same on every machine); Brinehollow's sea untouched; ships' crews (boarders) keep their cutlasses. Test:
  t/combat/grunt_roles (t/combat green). **Assumed:** the numbers; the rivals and the Admiralty field these
  weapons through their own captain-style AIs (RivalCrews' mate weapons), not through grunts; the grunts' looks
  unchanged (only the weapon and stance); not rendered (try a chain island's camp).
- **Assumed:** an AI captain's hits keep the world's hitstop, and its ultimate keeps its slow-motion beat (single
  player; co-op never slows the world): they read as the rival's big moments. Its own moves never punch your camera
  in; its shake fades out past 14 m. AI captains carry no lantern (real lights are budgeted). Rivals count as elite
  (Captain's Presence doesn't soften their blows). After a combo a rival backs off and circles for a beat, and your
  stagger never starts its next combo (no stunlocks); a missed swing of yours does.

## Decided (2026-10-19)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Order | (1) A tooling window: the crew_lib deps-file race, a lint for autoload names in static funcs (todo.md), no agents running. (2) **A perf pass**: Brinehollow back toward the 9.4 ms target with the market's CROWD back on, then the perf gate's baseline. (3) The features. | The perf gate has failed since v1.17 (13.4 ms), and 1.18 adds more. Batch rule 2. | — |
| Headline | **Rival crews** in three pieces: the cutscene system, AI that fights like a captain (the player's own states and skills), the crews themselves (persistent, matchups, lines, retreat/plunder, scaling). The AI starts first. | docs/rival_crews_plan.md. | — |
| Bounties | **Bounties + wanted posters**: beating rival crews (and other big fights) raises the captain's bounty, posters show it, and rivals' lines react to it. Marine patrols and pursuit wait for 1.20. | Gives the rival fights a growing, visible reward. | — |
| Gear upgrading | Smiths (and treasure merchants) **upgrade blue-and-up weapons**, re-roll or name their trait (todo.md "Gear upgrading and customizing"), paid with treasure and materials. | Builds on 1.18's traits; a rival captain's weapon is the prize. | — |
| Fishing | A **fishing minigame** (rod, cast, bite, reel) at rails, piers and shores, feeding the Fishing life skill, its perks and the fish-tagged ingredients. Lane F's downtime fishing stays as the idle version. | The fishing perks and fish ingredients already exist. | — |

## Carried over from 1.18.4 (Zach, 2026-10-22)
1.18.4 ships with what was built when the batch paused (docs/v1_18_4_plan.md "Paused 2026-10-22"), as an unstable
build **with the perf gate waived** (Zach): Brinehollow 9.66 -> 13.34 ms mean frame at noon (+38%), plaza frame1t +44%,
against the 2026-10-15 baseline; the perf pass above is 1.19's first step. Moved here:
- **Greatsword finish:** Updraft and Gatekeeper, Guardbreaker's and Crescent Gale's polish (the handover in the 1.18.4
  plan has the details and patterns).
- **Black-leg finish:** icons, a katana-pass polish, two new techniques (pitched in one line each first).
- **Corsair and pistol mastered guards** (pictures for Zach's pick first).
- **How 1.19 is worked** (Zach, 2026-10-22, to save usage): one feature at a time in the main session, no subagents
  or parallel feature agents unless Zach asks; atomic tests while building, the suites once at the end.

## The web roadmap timeline (Zach, 2026-10-19)
Replace `web/site/roadmap/` with an **interactive scrolling timeline**: every version Driftwake has shipped and every
one planned, as **floating, clickable cards** strung along a timeline line.
- **The timeline:** one long track you scroll along, from the first build to 2.0. Shipped versions on one side of a
  "you are here" marker (the latest release), planned ones past it, looking unfinished (dimmer, dashed, "planned").
  Cards bob gently and lift on hover; scrolling moves through the versions smoothly (wheel and drag on desktop, swipe
  on phones, arrow keys).
- **The cards:** version number, name ("Timber and Tide"), date, a one-line headline and a small screenshot. A click
  opens the card into a detail panel: everything that version added, a screenshot or clip, and links to its news post
  and GitHub release. Planned cards open to what's planned and its status.
- **Content: everything built so far.** Every version from the first builds to 1.18 filled in from the releases page,
  the GitHub release notes, the news posts and `docs/dev_notes.md`; then 1.19 to 1.22 and the road to 2.0 from
  `docs/roadmap_v2.md`. Written with **Driftwake's own names** (docs/originality_plan.md): this is new content, so it
  never needs the 1.20 rewrite.
- **Built like the rest of the site:** static HTML, CSS and plain JS, the site's `style.css`, pixel fonts and PS1 look,
  no framework or build step. The versions live in **one data file** (`web/site/roadmap/roadmap.json`), so each
  release updates the roadmap by adding or editing one entry. Works at phone width (the track turns vertical), with
  keyboard focus on the cards and `prefers-reduced-motion` stopping the floating.
- **Keeping it current:** each release's checklist (`docs/release_*.md`) gains a step: move "you are here", fill in the
  version's card.
- **When:** it touches only `web/site/`, so it can be built alongside any feature batch (batch rule 3).

### Open / deferred (grill before the batch)
- How cutscenes are skipped and shared in co-op, and the rivals' first crew roster and look: at the rival crews grill.
- How a bounty is calculated, and what it changes (prices, who attacks you): at the bounty grill.
- Gear-upgrade costs, caps and how renaming shows in co-op: in the economy's numbers, tuned in play.
- **The intro sequence is redesigned in 1.19** (Zach, 2026-10-19), on the cutscene system the rival crews need: it
  sets up the world (the Marines, rival crews, the sea's great powers, the First Sea's end) and the captain's goal
  and motivation. Grill it with the rest of 1.19.
- **Fighting in the water** (Zach, 2026-10-19): swimmers get an attack (a knife stab, a short harpoon or similar,
  plus diving moves), so a captain can fight back against sharks and morays (a shark's break-off at half health
  comes sooner) and fight in the sea at all. Built with 1.19's captain-style AI so the **rivals and the Admiralty can
  fight underwater too** (chasing a captain who dives, duels in the shallows). It's the root of the Seafarer tree's
  "fighting underwater" (docs/devil_fruits_plan.md). Today a swimmer sheathes their weapon (swim_state.gd) and sea
  threats can only be hit from the deck or the shore.
- **The weapons' enemy pass** (Zach, 2026-10-21; moved out of 1.18.3): grunt roles for the kinds built in 1.18.3
  (spearman, hammer brute, twin-axe berserker, greatsword, black-leg fighter), each a cut-down moveset you learn to
  read, dropping its weapon. Built alongside 1.19's captain-style AI, so the Admiralty and rival crews can field them
  too (docs/weapons_plan.md).

- **Two- and three-sword style for the katana** (Zach, 2026-10-21): a late katana passive lets the off hand carry a
  second katana (two-sword style becomes the katana's default pattern once owned); a very late passive adds a third
  slot only for three-sword style (the third blade held in the mouth). Three-sword style is **not** a new default
  pattern: you fight two-sword until you toggle it on; while on it drains energy, buffs you slightly and swaps in a
  few move variants, and a few katana skills need it on to use. Design it with the katana's mastered guard (1.18.4)
  and preview the numbers first (gates, drain, buff, which skills need it). New tech: a mouth attach point, its guard
  and carry, the variants' poses, the toggle synced in co-op.

## Perf session before 1.19 (Zach, 2026-10-20)
After 1.18.1 ships, before the 1.19 batch, in order, each with a before/after bench by the lead:
1. **Refresh the bench** (a tooling window, no agents running): new stops (Brinehollow's terrace and farmland, the
   capital's plaza and market street, a chain island village, at sea and in a storm, a crowded fight), CROWD measured,
   no screenshot in the first sample, hitch counts; re-baseline on the min-spec PC.
2. **Threaded rendering** (rendering/driver/threads/thread_model): move the render CPU (the bench's "draw", ~35% of
   the frame) off the main thread; check stability (co-op, island builds, the held map's viewport).
3. **Occlusion culling in towns** (occluders from the kit's buildings, the capital first) + **a shadow-caster audit**
   (small props off the sun's shadow pass: 613 of 1,556 draws; shadow distance/cascades).
4. **Far actors fully off** past a range (processing and bodies off, not only asleep: the "far" ablation's ~1.2 ms).
5. **The long tail** (quick GDScript wins found in the v1181_before probe): sky_birds.gd 0.38 ms, sea_spray.gd 0.29 ms,
   dev_capture.gd 0.12 ms/tick (make sure it does nothing in release builds), and whatever else the refreshed probe
   shows at 0.1-0.4 ms for little visible effect.
Bar: no visible loss of detail; GPU has headroom (1.45 ms), the frame is CPU-bound. **Not now** (Zach, 2026-10-20): a
   GDExtension; the animator + skinning is only ~2 ms of a ~20 ms frame, and C++ would slow development (toolchain, the
   web build, native crashes). Revisit only if one pure-maths kernel dominates after the session. Later, if still needed: central
update managers, and the hottest per-frame code (animator, spring chains, wave sampling) as a GDExtension.
**Ships as 1.18.2** (Zach, 2026-10-20): a simple, short release: no blog/news post; a brief entry in the release
notes and the README history; on the roadmap timeline, fold it into the 1.18.1 card (one card for 1.18.1-1.18.2, an
"added" line for the performance work) rather than a card of its own; version 1.18.2, what's new one line; tag and push.

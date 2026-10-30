# 1.27 part two: Strongholds and Driftfruits (preview for Zach's OK, 2026-10-30)

The cities pass (C1-C5) is done. This is the rest of 1.27. The decisions are already in docs/v1_27_plan.md
"Decided (2026-10-29)": an open fortress with an escalating alarm, the brig on a wipe, a winnable Vice Admiral and an
Admiral you grab and run from, one stronghold and one named fortress per chain, one great power, 6 fruits each once per
save, tiered sources, enemy users, fruits as items, all the costs plus the Seafarer tree, and fruit trees built like
weapon trees. The build order (steps 1-7) is there too.

**This doc is the previews that list still owes** (feel systems get numbers before they're built): the fortress and
its alarm, the prizes and bounty, the great power, the 3 new fruits, the fruit trees over the mastery curve, sources
and prices, the costs, and the Seafarer tree. **Nothing here is built.** Every number is a first pass to tune in play.
The questions for Zach are at the end.

What exists today and gets reused:
- Admiralty ships, patrols, blockades and chases (1.19-1.26.1) and the arrest and brig (`scripts/ai/admiralty_brig.gd`).
- Captain-style AI (rivals, officers, hunters) and Bounty (tiers Wanted 5k, Notorious 20k, Infamous 60k, Dreaded 150k).
- 1.25.5's hideouts and pickets, GruntCamp, and 1.26's weapon-tree plumbing (mastery 1-30, alternates, variants,
  ultimates, crew techniques).
- Ember, Wolf and Vine with their starting moves, passives and a fruit tab (Ember's tree is mastery 1-20 today).
- The sea's curse text (`DevilFruits.CURSE`).
- The level cap is 40.

---

## A. The stronghold (build steps 1-2)

### Its name (one per chain, rolled from the chain's seed; never repeated in a save)
Gallowmere Bastion, Saltmarch Citadel, Ironveil Hold, Graveshoal Keep, Bellweather Fort, Coldharrow Bastion,
Thornwick Battery, Saint Odran's Rock. The Admiralty's own name for each is on the captured orders ("Bastion G-4").

### The island (fixed parts, rolled joins)
A rock island with cliffs on three sides. Around 260 m across (a chain island is 300-500 m), so the whole raid stays
inside one sleep range.

| Zone | What it is | Ways in |
|---|---|---|
| Harbour and sea gate | A walled basin with a portcullis on the water, two moored Admiralty ships, and cranes | Sail in loud. Or **swim under the sea gate**: a non-user's route, closed to fruit users |
| Outer wall | Three bastions with cannons that fire on your ship inside 250 m, and walkways | **Climb a weak point**, rolled 1-2 per fortress: a collapsed buttress, a scaffold, a drain grating |
| Main gate | A gatehouse with a drawbridge, at the end of the cliff road | **Loud**: break it with the ship's cannons or a powder keg |
| Lower yard | Barracks, drill yard, mess, a forge | The alarm bell is here. The barracks are where reinforcement waves come from |
| Inner gate | A second gatehouse with a lever room on the wall | Open now; it shuts at Lockdown. The lever or the Stranger's lead opens it again |
| The keep | 3 floors and a roof: officers' rooms, a records room (orders, the chain's Admiralty chart), the Vice Admiral's office | Inner gate, or the roof from the wall walk |
| Armoury vault | Under the keep, behind a key the Vice Admiral or the quartermaster carries | Holds the prize |
| The brig | Cells by the sea wall | Where a wiped crew wakes up; the break-out is 1.25's |

### The garrison (solo; each extra captain adds +5 marines and +1 officer)
- 22 marines on patrol routes and posts, 4 of them riflemen on the walls.
- 3 officers: a quartermaster with the vault key, a gunnery lieutenant on the wall's cannons, and a commodore in the keep.
- The Vice Admiral is in the keep's office.
- Levels: the chain's last island's level +2. Officers are +3 over that, the Vice Admiral +5.

### The alarm ladder (seen = suspicious; a fight that lasts, or the bell rung, = alarm)
| Stage | Starts when | What happens |
|---|---|---|
| 0 Quiet | You arrive unseen | Patrols on their routes. Quiet kills from behind or in smoke don't raise anything |
| 1 Suspicious | A body is found, a shot is heard, or someone glimpses you | That area searches for 30 s, then calms back to Quiet if it finds nobody |
| 2 Alarm | Someone sees you for 1.5 s and reaches the bell, or you fight in the open for 8 s | The bell rings. A wave of 4 marines comes every 45 s (at most 4 waves), and the wall cannons turn on your ship |
| 3 Lockdown | 3 min after the Alarm | The inner gate shuts and the vault seals until the quartermaster's key or the lever room opens it |
| 4 He comes down | 6 min after the Alarm, or when you reach the keep's top floor | The Vice Admiral comes to you, with a cutscene beat |
- Silencing the bell (an interact by the bell, under fire) holds off the next wave by 45 s.
- A wipe sends the crew to the brig with their kit. The fortress stays at Alarm, and the garrison is topped back up to
  half.

### The fights at the top
- **The Vice Admiral** is a captain-style boss. A named rank ("Vice Admiral Hask Morrow" style, rolled) with a weapon
  kind and two signature techniques, and a fruit if a solid one is free in the pool (step 5). Beating them is the win.
- **The Admiral** comes if the crew's top level is 32+ or any captain is Dreaded (150k). They come on 1 raid in 2 that
  qualifies, arriving by sea once the vault is open. You **grab the prize and run**: reach your ship and get 400 m out.
  The Admiral is unbeatable before 2.0. Their attacks are huge and telegraphed (a set piece, not a wall), and they
  break off at 400 m.

### The prize and the bounty
- **The armoury vault:** one **named legendary weapon** with a trait (list below), plus a chest of the chain's best
  tier. Once fruits are back, also the chain's legendary fruit if one is free.
- **Bounty:** new Bounty.TABLE entries: "vice_admiral" 25,000, "stronghold" 40,000 for the vault taken, and
  "admiral_escape" 20,000. A full raid is around +65,000, which takes a mid-game crew from Notorious to Infamous.
- **The chain afterwards:** Admiralty patrols in this chain halve for 3 in-game days. The fortress rebuilds its
  garrison but keeps its vault empty.

### The legendary weapons (one per stronghold, picked from the chain's seed; none repeats in a save)
| Weapon | Kind | Trait |
|---|---|---|
| Gallowsbane | cutlass | a perfect parry fires a flying slash back |
| Mourning Moon | katana | an iai draw at full charge cuts twice (a second cut 0.3 s later) |
| Old Thunder | greatsword | a finisher calls a shockwave that staggers in a ring |
| The Widowmaker | flintlock | every 4th shot is a piercing round |
| Saint's Knuckle | hammer | a heavy hit on a guard breaks it at once |
| Bosun's Promise | axe | kills refill 15% stamina |
| Quiet Tide | dagger | a hit from behind never raises the alarm (made for strongholds) |
| Hellmouth | cannon | grapeshot sets fires |

---

## B. The great power (build step 6), tied to the Doge's line

**Prince Corvo Malatesta, "the Lagoon Prince"**: the pirate prince who taxes the Doge's ships (the Doge already names
him). He is a duellist in a ruined noble's finery, with a rapier-style cutlass and a main-gauche (the dual kind), and
he eats one of the legendary fruits (the Storm Fruit if Zach takes it, below).

- **His hideout:** a sea fortress built on a drowned palace in shallows, with half-sunk halls, gondola docks and a
  hall where he holds court. Its own island in the canal city's chain (or the nearest chain to it).
- **His crew:** a picket of 2 ships, around 18 pirates, and 2 named lieutenants (the "Gilded Twins").
- **The Doge's line:** step 2, escort a convoy past his ships. Step 3, his hideout.
- **Beating him:**
  - +100,000 bounty.
  - His raids stop: no more pirate prince ships, and the lagoon's convoys are safe.
  - His waters open: his hideout becomes a friendly port with a shady merchant.
  - His fruit is freed into the pool.
- **If he wins:** he takes a share of your gold (10%) and sends you back to the lagoon. He's a duellist, not a jailer.

---

## C. The six fruits (build steps 3 and 5)

### Tiers (sources follow the tier; see D)
| Fruit | Type | Tier | Its feel |
|---|---|---|---|
| **Bubble Fruit** (new) | paramecia | **joke** | Soap bubbles: slick floors that trip enemies, a bubble you float in, a bubble shield, foam that scrubs away buffs. Funny but useful |
| Wolf Fruit | zoan | solid | A hybrid form, claws, pounces, a howl that rallies the crew |
| Vine Fruit | paramecia | solid | Snares, swings, a thorn wall, healing in the sun |
| **Iron Fruit** (new) | paramecia | solid | Turn parts of your body to iron: a guard nothing staggers, iron fists, a cannonball dive. Heavy and slow, the tank's fruit |
| Ember Fruit | logia | **legendary** | Fire: a fire fist, rings, a flame body you can't touch |
| **Storm Fruit** (new) | logia | **legendary** | Lightning: a blink-step, chain lightning, a thundercloud over the field. The great power's fruit |

### A fruit's tree (the weapons' shape: mastery 1-30, 3 branches, techniques, 2 ultimates with one equipped, an alternate, a variant pick, a crew technique)
Ember as the worked example, by the mastery level each node opens at:

| Mastery | Node | Kind |
|---|---|---|
| 1 | Fire Fist + Flame Body (the passive dodge) | root |
| 2 | Fire Ring | tech |
| 4 | Running Blaze: a sprint attack, a flaming shoulder charge | move |
| 6 | Ember Dive: an air attack, a fireball slam | move |
| 8 | Ember Field | tech |
| 11 | Smoldering Body | mech |
| 13 | Heat Haze: your dodges blur enemies' aim, 20% more misses | passive (slot) |
| 15 | Pillar of Flame | tech |
| 18 | alternate: Fire Gun, a rapid volley in place of Fire Fist | alt |
| 20 | the Blaze's Way, a variant pick: **Wildfire** (burns spread) or **Hearth** (your fire heals the crew a little) | variant |
| 22 | crew technique: **Bonfire**, with any crewmate's finisher | crew |
| 25 | Ultimate 1: **Sunfall**, a falling sun on a marked area | ult |
| 30 | Ultimate 2: **Hellmouth**, a fire tornado you steer | ult |

Steps between, as on the weapons: +5% fire damage a step (5), burn length (3), energy from fire hits (3), technique
cooldowns (3).

The other five, in brief (branches, then the techniques, then the two ultimates):
- **Wolf** (Fang / Hunt / Pack): Rending Fang, Pounce, Howl (rally the crew), Moon Leap; ultimates Blood Moon (a
  frenzy) and Pack of Shadows (spectral wolves).
- **Vine** (Snare / Grove / Thorn): Vine Snare, Vine Swing, Thorn Wall, Strangler Grove; ultimates World Root (the
  ground erupts) and Bloom (heal the crew and root enemies).
- **Iron** (Guard / Fist / Weight): Iron Guard (no stagger), Iron Fist, Cannonball Dive, Anvil Drop; ultimates Iron
  Maiden (a counter-stance) and Meteor (a leap and an impact).
- **Bubble** (Slick / Float / Pop): Slick Floor, Bubble Float, Bubble Shield, Scrub (strips buffs); ultimates Bubble
  Prison (traps a target) and Foam Flood (the whole area slips).
- **Storm** (Bolt / Cloud / Step): Thunder Step (a blink), Chain Lightning, Thundercloud, Static Guard; ultimates Wrath
  of the Sky (bolts on everyone marked) and Eye of the Storm (you become the storm).

Mastery rises with fruit use, like a weapon. Mastery 30 takes about as long as a weapon's.

---

## D. Sources, the pool and prices (build steps 3 and 5)

| Tier | Where it can be found | Chance |
|---|---|---|
| Joke | a rare chest on a chain island past the 3rd | 2% a chest, while it's free |
|  | a rare-gear merchant | in stock on 1 visit in 4, 25,000 gold |
|  | a collector's quest | once per save |
| Solid | an island boss's hoard | 12% |
|  | a hideout's vault (1.25.5) | 25% |
|  | an officer who ate it | when they're beaten |
| Legendary | a stronghold's vault | when that legendary is free |
|  | the great power | only Storm |
- **The pool:** each fruit once per save. Held = in someone's bag, eaten by a captain, or eaten by an enemy. When an
  enemy user dies, the fruit is freed. It turns up in 1-3 in-game days in a source of its tier on another island, and
  a tavern rumour points toward it.
- **Enemy users** (step 5):
  - An officer at Notorious+ has a 1 in 4 chance to have eaten a free joke or solid fruit.
  - A Vice Admiral eats a free solid fruit.
  - The great power holds Storm.
  - Rivals don't eat fruits (decided below).
- **Selling an uneaten fruit** (to a rare-gear merchant): joke 15,000, solid 60,000, legendary 200,000 gold.

---

## E. The costs (build step 4; docs/devil_fruits_plan.md, with numbers)
- **In the sea:** a fruit user sinks slowly, with a breath meter of 28 s. A crewmate dives, grabs them (F) and swims
  them up at 60% speed. On deck you're weakened for 3 s.
- **Waist-deep standing water:** powers off and 30% slower. Chest-deep: sinking starts.
- **Storms:** a wave over the deck takes 30% of a fruit user's energy.
- **The rescue gear:**
  - A life ring (thrown from the rail, about 12 m).
  - A rope-and-hook (from the rail, hauls a sinking crewmate up).
  - The life buoy quick item (saves you once; 400 gold).
- **Solo:** sinking is a death. You wake in the cabin, and your bag washes up on the nearest shore, marked on the chart.
- **Enemies use it:** pirates shove a fruit user toward the rail (a shove move on grunts near a rail). Seastone nets and
  cuffs wait for the Marines pass (not 1.27).

## F. The Seafarer tree (captains without a fruit; it closes for good when you eat one)
An Adventure tree from the Adventure pool. The nodes open by captain level:

| Level | Node | Cost | What it does |
|---|---|---|---|
| 3 | Strong Swimmer | 1 | swim 20% faster |
| 5 | Deep Breath | 1 | 50% more breath underwater |
| 8 | Treasure Diver | 2 | glints on the seabed within 25 m; searching underwater is twice as quick |
| 10 | Sea Legs | 1 | no stagger on a pitching deck; climbing aboard is 40% faster |
| 13 | Rescue Swimmer | 2 | carry a crewmate at full swim speed |
| 16 | Undertow | 2 | fight in the water: your weapon's light combo works while swimming |
| 20 | Boarding Dive | 2 | from the water, leap onto an enemy ship's deck alongside |
| 24 | Spray | 2 | storm spray refills stamina |
| 28 | Maelstrom | 3 | (the tree's ultimate) a whirlpool round you that drags enemies off decks into the sea |
Total: 16 points. Haki leaning toward non-users is not in 1.27 (Haki's numbers are their own pass).

---

## Questions for Zach (the frontier)
1. **The 3 new fruits:** Bubble (joke), Iron (solid), Storm (legendary)? Or other ideas (a Clock, a Mirror, a Sand)?
2. **Ember's tier:** legendary (logia, as in the source), so Ember and Storm are the two legendaries? The alternative
   is two new legendaries and Ember as solid.
3. **The great power:** Prince Corvo Malatesta, tied to the Doge's line, a duellist with the Storm Fruit, his hideout a
   drowned palace? Or an Emperor-style brute, separate from the lagoon?
4. **Rivals eating fruits between meetings:** yes (a rival you beat twice might come back with Iron), or only
   officers, Vice Admirals and the great power?
5. **The swim-under route:** keep the sea gate as a route only non-users can take? It makes the costs matter inside
   raids.
6. **The alarm and the garrison:** do the numbers in A read right (22 marines plus 3 officers solo, a wave of 4 every
   45 s, Lockdown at 3 min, the Vice Admiral at 6)? These get tuned in play either way.

## Decided (Zach, 2026-10-30)
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| The 3 new fruits | **Bubble** (joke), **Iron** (solid), **Storm** (legendary) | Each plays unlike the existing three | - |
| Ember's tier | **Legendary**: 1 joke / 3 solid / 2 legendary (Ember, Storm) | A logia, as in the source; Ember comes only from strongholds | - |
| The great power | **Prince Corvo Malatesta, the Lagoon Prince**: a duellist with the Storm Fruit, a drowned-palace hideout, the end of the Doge's line | Ties the canal city's purpose to the raid | - |
| Enemy users | **Officers, Vice Admirals and the great power only**; rivals stay weapon-only | Zach's pick | If the pool feels static |
| Sea gate | **Swim-under for non-users only** | The fruit's cost matters inside a raid; the Seafarer build gets its own way in | - |
| Numbers | **This preview's numbers are the first pass**, tuned in play | - | Play-testing |
Next: build step 1 (the fortress, the place), then the steps in docs/v1_27_plan.md order.

## Zach's direction (2026-10-30, after the preview): supersedes parts of A and C

### The stronghold, reshaped (replaces A's "open fortress" shape where they differ)
- **A large fortress of distinct districts**, a Dark Souls 3 / Elden Ring legacy-dungeon place: big buildings with rooms
  that hold **chaotic boss fights and wave fights**. A **30-60 minute raid**, WoW-dungeon-like in pace.
- **Tuned for a squad of 3+**; anyone can still do it solo (single-player stays possible, scaled down).
- **Enemies keep respawning through the zone** (outside set encounter rooms and boss arenas) **until the main boss is
  beaten**; then they stop.
- **The Admiralty's emergency broadcast** once it's cleared and the main boss is down.
- **The bombardment** (Zach: its own Driftwake name, not "Buster Call"; see preview v2): 2 minutes after the boss falls, a countdown starts; at zero the Admiralty's fleet surrounds the
  island and your ship and **barrages the whole place** with huge explosive shells (big fireball blasts) that set
  everything around you on fire. You get out with the prize.
- Still to settle (next discussion): the districts and their order, the encounter rooms and bosses (the Vice Admiral as
  the main boss?), how the alarm/stealth idea fits a respawning zone, checkpoints/the brig on a wipe in a 30-60 min run,
  the escape from the bombardment (to the ship and out, with the ship under fire).

### The Driftfruits, fully reworked (replaces C's weapon-tree copy)
Today's moves, costs, progression, mixing with weapons and looks are all outdated: redo them.
- **Mastery by use that evolves the powers themselves**, not just unlocks: an ability gains new triggers, passives,
  speed and features as you master the fruit. Zach's examples:
  - A logia's **bullets pass through you**: first an activated ability (a short window), later it **happens on its own
    now and then**, finally **always on**.
  - **Flight**: first a short phase-dash/hover on an ability; later hover longer and phase through material briefly on
    Space; finally it's part of your dash, and **holding Space dematerialises you into free flight for energy**.
- **Every fruit has an awakening**: an awakened form/state that does more (the top of its mastery).
- **Balance against the weapons:** Zach's lean: **combat points also buy fruit progression**, so a captain chooses
  between weapon and fruit growth. To preview with numbers.
- **Controls (an idea, not settled):** a fruit hotbar on a held modifier (hold Alt: Q, E, R, LMB, RMB become fruit
  powers). Alternatives to preview.
- The six fruits stay (Bubble, Wolf, Vine, Iron, Ember, Storm) unless the rework says otherwise.

## Stronghold preview v2 (2026-10-30, from Zach's direction; for his OK, nothing built)
A **legacy dungeon** on its own island: one fortress, seven districts, a hub with two wings that each hold a seal, the
bridge they open, and the keep. Roughly a 45-55 minute run for a crew of 3. Built from what exists: grunt roles
(sword, rifle, shield, horn-blower, brute, elites), captain-style AI for officers, GruntCamp-style spawners, the brig,
the Admiralty's ships and rings, FX fire and blasts.

**The bombardment's name:** not "Buster Call" (Zach). It's **the Scouring** (Zach, 2026-10-30).

### The map (Gallowmere Bastion as the example; the parts are fixed, names and dressing rolled per chain)
```
                        [7 THE KEEP]  <- the Vice Admiral; the vault under it
                             |
               [5 THE BRIDGE OF JUDGEMENT]  <- opens with both seals
                   /         |          \
   [3 THE ARSENAL]  ---  [2 THE LOWER WARD]  ---  [4 THE PRISON TOWER]
    seal 1: the              (the hub)              seal 2: the Warden;
    Commodore                    |                  the brig is here
                          [1 THE LANDING]          [6 THE SIGNAL SPIRE]
                     harbour, sea gate, beach      optional, off the bridge
```
| # | District | What it is | The fight it holds | ~min |
|---|---|---|---|---|
| 1 | **The Landing** | The harbour basin, the sea gate (swim under: non-users), a beach under the cliffs with a scaling route, and the harbour battery | **The Battery**: hold the gun platform while waves land by boat and the wall guns fire on your ship. Once it's taken, the guns are silent | 5 |
| 2 | **The Lower Ward** (hub) | Barracks streets, the mess hall, the drill yard, stairs up to the two wings, and a lift (a shortcut, opened from above) | **The Mess Hall**: a sealed brawl, 3 waves, tables and benches flying. Mini-boss **the Drill Sergeant**, a brute with a whistle that calls squads | 8 |
| 3 | **The Arsenal** | A cannon foundry: furnaces, molten channels, powder magazines, and gantries over the casting pit | Boss **the Gunnery Commodore**: a cannon officer in the casting hall. Powder kegs chain-explode, the floor channels flood with molten iron in turns, and gun crews reload around him. **Seal 1** | 10 |
| 4 | **The Prison Tower** | A tower of cell blocks round a hollow core, with lifts, catwalks and the brig. Seastone bars drain fruit users nearby | Boss **the Warden**: chains and a seastone net (a fruit user caught is powerless for 4 s), and he releases a cell block of brutes at half health. **Seal 2** | 10 |
| 5 | **The Bridge of Judgement** | A long stone bridge over a chasm between two towers, with crossfire from galleries | **The Gauntlet**: cross under rifle fire while horn-blowers bring squads down from both ends. Cover is the statues; the galleries can be climbed and cleared | 5 |
| 6 | **The Signal Spire** (optional) | A climb up a lattice tower to the broadcast room | Clearing it and wrecking the transmitter **delays the bombardment by 60 s** and stops reinforcements through the hub. An elite pair guards it | 5 |
| 7 | **The Keep** | The command hall over the vault: three tiers, galleries and a war map table | Final boss **the Vice Admiral**, in 3 phases: the duel; then the hall's guard joins and the galleries open fire; then a desperate last phase (his fruit if he has one, or a signature technique). The vault key drops | 10 |

### Spawns: the fortress refills until its master falls
- Each district has **spawn doors** (barracks doors, boat landings and lifts). A dead patrol comes back after 90 s from
  a door no captain can see, at least 25 m from any captain.
- **Live caps per district:** 10 solo, then +4 per captain beyond the first (22 for 4).
- **Sealed fights** (the Battery, the Mess Hall, the Gauntlet and the boss arenas): the gates drop when you enter, the
  waves are fixed, nothing respawns inside, and once beaten they stay beaten.
- A district whose officer is down is **secured**: its spawns slow to half.
- **Everything stops when the Vice Admiral dies.**
- **Stealth is the opening, not the whole raid.** Arriving unseen (the sea gate, the cliffs) skips the Battery's first
  two waves and starts the hub on patrol rather than at arms. Once the bell rings, spawns run 1.5x faster and
  horn-blowers join. There's no going back to quiet.

### Scaling (tuned for 3; soloable)
| Captains | Enemy health | Wave sizes | Boss health | Boss pace |
|---|---|---|---|---|
| 1 | x0.55 | x0.6 | x0.5 | slower combos, longer tells |
| 2 | x0.8 | x0.8 | x0.75 | - |
| 3 | x1.0 | x1.0 | x1.0 | - |
| 4 | x1.2 | x1.25 | x1.3 | one more add per wave |
Levels: the chain's last island +2, officers +3, the Vice Admiral +5.

### Checkpoints and a wipe
- **Muster points:** one per district, where you **cut down the Admiralty's flag and raise your own** (an interact,
  shared with the crew). A dead captain whose crew is still up gets back up at the nearest raised flag after 20 s.
- **A wipe** (the whole crew down) sends you **to the brig in the Prison Tower** with your kit. Breaking out (1.25's) is
  about a minute, then the lift takes you back to your last flag.
  - The district you wiped in refills.
  - A boss you wiped on resets to full health.
  - Secured districts stay secured.

### The end: the broadcast and the bombardment
1. **The Vice Admiral falls:** a slow-motion beat, all spawns stop, and the garrison that's left breaks and runs.
2. **The emergency broadcast**, at once: a transmission banner and voice: "All ships. Gallowmere has fallen. The
   Scouring is ordered." With the Spire wrecked, it comes through static.
3. **2:00 of grace** to open the vault (the prize: the legendary weapon, the chain's best chest, and a legendary fruit
   once fruits land) and loot.
4. **The countdown, 2:00 on screen** (+60 s if the Spire was wrecked), then **the bombardment**:
   - 10 Admiralty warships ring the island at 320 m (Admiralty's ring code), with your ship inside the ring.
   - **A shell every 1.2 s.** Each is telegraphed by a ground-warning circle 2 s ahead; every third is aimed at a
     captain. Huge fireball blasts (FX: a blast, a flash light from the budget, a ring and debris) start **fires that
     spread** (fire zones, about 8 s, catching on nearby wood) and smoke.
   - The island burns: fire and smoke on every district within 60 s, and towers drop rubble you have to dodge.
   - **The escape:** reach the ship (the harbour or a beach longboat), sail out through a gap in the ring under
     broadsides, and get past 500 m. Then a "Survived the Scouring" banner, +20,000 bounty, and the chain's
     Admiralty patrols halve for 3 days.
5. **At high level** (top captain 32+ or Dreaded): **an Admiral leads the bombardment** and lands on the island once it
   starts. He's unbeatable before 2.0 and you run (as decided). He breaks off at the ring.

### Budget
- At most 24 live enemies in the whole fortress (14 solo).
- Districts sleep when no captain is inside or near (ActorSleep, like FaunaSpawner's LOD).
- Shells come from a pool, with one flash light at a time.
- Fires are MultiMesh flame cards with a capped count.

### Questions for Zach
1. **The bombardment's name:**
   - **the Ashfall Order** (the working name)
   - **the Iron Verdict**
   - **the Scouring**
   - **Judgement Tide**
   - or one of his own.
2. **The wipe:** the brig in the Prison Tower and a breakout back to your flag, or **straight back to your last flag**
   (no brig in the raid; the brig stays for being arrested at sea)?
3. **Dying in the bombardment:** keep the prize and wake on your ship out at sea (generous), or **lose the vault's prize
   and wash ashore** (harsh; a reason to run)?
4. **Prisoners:** freeing a cell block in the Prison Tower gives a few temporary pirate allies for that district. In, or
   out?
5. **After the raid:** the fortress stays a **burnt ruin** (a place to revisit, with salvage and no garrison) or
   **rebuilds** after some days with a new Vice Admiral (a repeatable raid)?

## Decided: the stronghold (Zach, 2026-10-30)
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| The bombardment's name | **The Scouring** | Its own Driftwake name, not "Buster Call" | - |
| A wipe | **The brig in the Prison Tower**, a breakout (about a minute), then back to your last flag; a boss you wiped on resets | Failure becomes a scene | - |
| Death in the Scouring | **Keep the prize, wake on the ship out at sea** | A 45+ minute run shouldn't vanish | If escaping feels pointless |
| After the raid | **It stays a burnt ruin**: one raid per chain, revisitable for salvage, no garrison | Zach's pick | - |
| Prisoners as temporary allies | **In** (**assumed**; not asked yet) | Chaos in the Prison Tower | Zach's word |
| The map, spawns, scaling, flags, timings | Preview v2's, as the first pass | - | Tune in play |

## Driftfruit rework preview (2026-10-30, from Zach's direction; for his OK, nothing built)

### The model: powers that grow into you
Each fruit has **5 powers**. Each power has **three forms**, and you earn them by using it:

| Form | What it is | How you get it |
|---|---|---|
| **I. Active** | On the fruit bar: a press, energy and a cooldown | Learned (bought) on the fruit's tree |
| **II. Reflex** | It also fires **by itself** when its moment comes (with an inner cooldown); pressing it still works and is stronger | The power used **150 times** and fruit mastery **12** |
| **III. Nature** | **Always on**, part of how your body works. Its bar slot frees up for something else, or it becomes a bigger version | The power used **400 times** and fruit mastery **24** |

- Use counts are per power: grinding one power doesn't evolve the others. Mastery gates the forms, so no fruit
  reaches Nature in its first hours.
- **Awakening** (mastery 30 and the fruit's **trial**, a quest to beat a strong fight using only the fruit):
  - The **awakened state**: hold the fruit key for 30 s. It drains energy, every power is at Nature and more, and the
    world around you changes (a logia's element covers the ground, a zoan goes full beast, a paramecia bends the
    place).
  - Plus one permanent awakened passive.

### Ember worked through (logia, legendary)
| Power | I. Active | II. Reflex | III. Nature |
|---|---|---|---|
| **Flame Body** | Flicker: 1.5 s where bullets and blades pass through you (25 energy, 12 s) | A hit that would land has a 30% chance to pass through (6 s inner cooldown) | **Bullets always pass through you**; blades 25% |
| **Fire Fist** | A flaming projectile punch | Hold to charge a bigger one, and a dodge's end throws one by itself | Twin fists, and your basic punches set burning |
| **Blaze Step** (flight) | A short flame dash with a 1.2 s hover | Hover 3 s; Space mid-dash **phases through a thin wall or door** | **Your dash is a flame burst; hold Space to fly** (8 energy a second) |
| **Fire Ring** | A ring of fire round you | Landing from a jump rings by itself | An ember aura burns anyone who stays close |
| **Pillar of Flame** | A pillar under a marked enemy | It erupts under anyone who knocks you down | A second pillar follows the first |
**Awakened, "Sunborn":** flight costs nothing, everything you touch leaves burning ground, and your ultimate's cooldown
resets.

The other five follow the same pattern:
- **Storm:** Thunder Step blink, then blink-chaining after dodges, then a lightning dash.
- **Iron:** Iron Guard, then auto-guard against heavies, then no stagger from anything below a technique.
- **Wolf:** the hybrid form, a pounce, scent tracking.
- **Vine:** a snare, then snares on enemies who hit you, then thorns.
- **Bubble:** a bubble shield, then bubbles popping round you when you're hit, then floating falls.

### Balance against the weapons (the fork)
- **Today:** every weapon and the fruit earn their own points from their own mastery. A fruit never competes with a
  weapon.
- **Zach's lean, a shared "combat" pool:** every captain level gives **3 combat points** (120 by level 40), spent on
  any weapon tree or the fruit tree. A weapon tree costs about 60 to complete and a fruit about 70. So level 40 buys
  one weapon tree and most of a fruit, or two weapon trees: a real choice.
  - Mastery still gates **what** you can buy; the shared points decide **how much**.
  - The forms (I to III) come from use, not points, so a fruit you use a lot still grows.
- **Energy:** fruit powers use energy (the existing bar), weapons stamina. Using both drains both.

### Controls: three options to mock
| Option | How it plays | Good | Cost |
|---|---|---|---|
| **A. Hold Alt (Zach's idea)** | Hold Alt and Q/E/R/LMB/RMB become the 5 fruit powers; let go and they're the weapon's again | Weapon and fruit both fully on hand; mixes into combos | Two bars to learn; a held key in the middle of a fight |
| **B. Fruit stance (V toggles)** | V switches weapon stance and fruit stance; in fruit stance LMB/RMB are the fruit's own attacks (punches, claws, bolts) and Q/E/R its powers | Clear modes, like the Wolf's hybrid today; easy to read | Swapping takes a beat; less mixing |
| **C. One mixed loadout** | The 6 skill slots hold weapon skills and fruit powers as you like | One bar, already built (1.26's loadouts) | Fruits compete with weapon skills for slots and feel smaller |
**Recommended: A**, with Nature forms off the bar, because they're always on (so the fruit bar never feels crowded).

### Questions for Zach
1. **Points:** a shared combat pool (one weapon tree and most of a fruit by level 40) or keep separate pools?
2. **Controls:** A (hold Alt), B (fruit stance), or C (one mixed loadout)?
3. **Evolving a form:** by each power's own use plus mastery (as above), or by fruit mastery alone?
4. **Awakening:** mastery 30 and a trial quest, or mastery 30 alone?

## Decided: the Driftfruit rework (Zach, 2026-10-30)
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Points | **A shared combat pool**: 3 points a level, spent on any weapon tree or the fruit (about one weapon tree and most of a fruit by level 40) | A real build choice between weapons and fruit | Tune in play |
| Controls | **A fruit stance (V)**: V toggles weapon and fruit stance. In fruit stance LMB/RMB are the fruit's own attacks and Q/E/R its powers | Clear modes, like the Wolf's hybrid today | If switching feels slow mid-fight |
| Evolving a power | **By its own use plus fruit mastery**: Reflex at 150 uses and mastery 12, Nature at 400 uses and mastery 24 | The powers you lean on grow first | Tune in play |
| Awakening | **At mastery 30 alone**; no trial quest | Zach's pick | - |
| The model | Preview's: 5 powers a fruit, Active / Reflex / Nature, the awakened state for 30 s with a permanent passive | - | - |
Next for fruits: the five powers and their three forms for each of the six fruits (Ember's done above), then build step 3.

## The six fruit kits (preview, 2026-10-30; for Zach's OK)
In fruit stance (V):
- **LMB** is the fruit's light chain and **RMB** its heavy.
- **Q/E/R** hold three of the five powers. The other two sit on the stance's **Shift+Q / Shift+E**, or become Nature and
  leave the bar.
- Forms: **I** Active, **II** Reflex (fires by itself; 150 uses and mastery 12), **III** Nature (always on; 400 uses and
  mastery 24).
- Ember's table is above.

### Storm (logia, legendary): the Lagoon Prince's
Stance attacks: LMB crackling jabs that chain 2 m to a second foe; RMB a thunderclap palm (stagger, ring).
| Power | I | II | III |
|---|---|---|---|
| **Thunder Step** | A 9 m blink, leaving a spark trail that shocks | After a dodge, a free blink toward the nearest foe | Your dash is a blink, and passes through thin walls |
| **Chain Lightning** | A bolt that jumps 4 foes | It leaps from you to anyone who hits you | Every 4th stance hit chains by itself |
| **Thundercloud** | A cloud for 8 s, striking a random foe each second | It forms over you when your health falls under 30% | A small cloud follows you, striking now and then |
| **Static Guard** | 3 s: melee attackers are shocked and stunned | A perfect block shocks the attacker | Guns misfire near you (25%) |
| **Lightning Flight** | Ride a bolt 15 m upward and across | Hover in a storm (the weather's) | **Hold Space: fly as lightning** (energy) |
Awakened, "Tempest Crown": the weather turns to storm around you, bolts strike every foe you mark, and flight is free.

### Iron (paramecia, solid): the tank
Stance attacks: LMB heavy iron punches (slow, big poise damage); RMB an iron-shoulder charge.
| Power | I | II | III |
|---|---|---|---|
| **Iron Guard** | 3 s: no stagger, half damage | It hardens by itself against a heavy or technique (8 s inner cooldown) | Nothing below a technique staggers you |
| **Iron Fist** | A charged punch that breaks guards and shields | Your parries hit back with it | Every finisher breaks a guard |
| **Cannonball Dive** | Leap and crash down (ring, knockdown) | A fall of over 4 m lands as one | Your landing from any jump shocks the ground |
| **Anvil** | Drop an iron anvil on a marked foe | It drops on anyone who grabs you | Grabs and shoves can't move you |
| **Iron Skin** | 10 s: bullets bounce off | It covers you by itself for 2 s when shot from behind | Bullets do half damage, always |
Awakened, "Living Fortress": you go wholly iron for 30 s, every blow lands as an Iron Fist, and you walk through
cannonfire.
(Iron sinks like a stone in the sea: the deep-water weakness is worse for it, a 20 s breath meter.)

### Wolf (zoan, solid)
Stance = the hybrid form (today's V): LMB claws, RMB a lunging bite.
| Power | I | II | III |
|---|---|---|---|
| **Pounce** | Leap 8 m onto a foe, pinning them for 1.5 s | Pounce onto anyone fleeing at low health | Your sprint attack is a pounce |
| **Howl** | The crew gets +15% damage and fear shakes nearby grunts | It howls by itself when a crewmate goes down | Crewmates near you deal +5% always |
| **Scent** | Marks every foe and cache within 40 m for 10 s | Hidden foes nearby are always marked | You see tracks: enemies' trails and buried caches |
| **Rending Fang** | A bleeding bite combo | Bites bleed on crits by themselves | Every claw hit bleeds |
| **Moon Leap** | A huge leap (wall tops, rooftops) | A double jump | You climb walls in the hybrid form |
Awakened, "Full Moon": a full wolf for 30 s, huge and fast; every hit tears.

### Vine (paramecia, solid)
Stance attacks: LMB vine whips (reach 4 m); RMB a vine yank that pulls a foe in.
| Power | I | II | III |
|---|---|---|---|
| **Vine Snare** | Roots a foe for 2 s | Snares whoever hits you (6 s inner cooldown) | Your stance hits slow their target |
| **Vine Swing** | A vine grapple to any surface | You catch yourself on a vine when falling | Grapple anywhere, at no energy cost |
| **Thorn Wall** | A wall of thorns that blocks and cuts | Thorns rise round you when you're surrounded (4+ foes) | You trail thorns as you dodge |
| **Strangler Grove** | A patch that roots and strangles | It spreads from every fallen foe | Plants near you heal you |
| **Photosynthesis** | 6 s: heal fast in sunlight | Heals by itself out of combat (today's passive) | Sunlight always heals you slowly, in combat too |
Awakened, "Verdant Lord": the ground round you grows a forest for 30 s that fights at your side.

### Bubble (paramecia, joke but useful)
Stance attacks: LMB soap bubbles that pop (small damage, a slip chance); RMB a big bubble that traps a grunt for 2 s.
| Power | I | II | III |
|---|---|---|---|
| **Slick Floor** | A soapy patch where foes slip and fall | You leave suds when you dodge | Foes that chase you slip now and then |
| **Bubble Float** | Float in a bubble for 4 s (over water too) | Falls become a slow float | You can cross water in a bubble (but not dive) |
| **Bubble Shield** | Absorbs the next 3 hits | A shield forms by itself when you're downed once a fight | One hit in five pops a bubble instead of you |
| **Scrub** | Washes buffs off a foe and burning off you | It scrubs a debuff off you by itself | Burning and bleeding never stick to you |
| **Foam Flood** | A wave of foam knocks foes down and away | Popped bubbles leave foam | Your footprints foam (foes slip on your trail) |
Awakened, "Bath Time": the area floods with foam for 30 s; foes slip constantly, and you skate.

## Decided: where the stronghold is (Zach, 2026-10-30)
- **A new island, outside the sea chain:** optional, missable, skippable. It isn't on the route (no "next" links into
  or out of it), the log pose never points to it, and it's **off the chart until you hear of it** (captured orders, a
  rumour, the Queen's line).
- Built after the chain from its own rng (`hash([chain seed, "stronghold"])`), so no existing island's roll changes.

## The stronghold's look (Zach, 2026-10-30): docs/art/stronghold_reference.webp
Nothing like the capital: no limestone, no cone roofs. What the reference shows:
- **Stone:** blue-grey stone and cobbles, an industrial navy's fortress.
- **The Verdict:** two colossal square towers side by side, a full circle cut where they meet near the top, and the
  towers going on above it. The tallest thing in the sea; it should make you feel small and worried.
- **Towers:** many tall square towers with flat or open lantern tops, lit windows, and blue banners with the
  Admiralty's emblem.
- **Walls and bridges:** sea walls straight out of the water from rocks, and arched viaduct bridges between towers.
- **Approaches:** a grand stair up to a huge portcullis gate between torches.
- **Industry:** iron gantries and cranes with hanging crates, and wooden docks.

## Stronghold bosses preview (Zach, 2026-10-30: replaces preview v2's Drill Sergeant / Commodore / Warden / Vice Admiral)
Zach's direction:
- **Three tough bosses through the fortress:** a **Lieutenant**, then a **Captain**, then **the Commodore**, who commands
  the whole fortress and is the end boss.
- **The Commodore** is a fusion of a player AI (CaptainBrain: weapons, skills, abilities and movement, like a rival
  captain) and a traditional scripted boss fight with **phases**.

All three are captain-style AIs (player.tscn with a brain, like 1.19's officers), each with its own arena gimmick, run
by a small phase controller (`StrongholdBoss`: health thresholds -> a phase's loadout, adds, arena changes, a cutscene
beat; the host runs it, the phases go over as one event). Numbers are a first pass, for the squad of 3; solo scales by
preview v2's table.

| Boss | Where | Seal | Kit (weapon, skills) | Phases | Arena gimmick |
|---|---|---|---|---|---|
| **Lieutenant Varro Kesh** | the Casting Hall (the Arsenal) | seal 1 | cutlass + flintlock (the Corsair tree), 2 techniques | **2:** at 50%, he kicks the furnace sluices open | the floor's channels run with molten iron in turns (telegraphed glow, then a burning strip), a powder keg or two |
| **Captain Ilse Marrow** | the Prison Tower's yard and its cell block | seal 2 | a greatsword or polearm, heavy, 3 techniques, a seastone net (a fruit user caught is powerless 4 s) | **2:** at 50%, she opens a cell block: 3 brutes join, and she takes the high catwalk with a rifle a while | catwalks over the hollow core; fall and you take the stair up again |
| **Commodore Aurel Vane** | the Command Hall (the Verdict's base) | (the end) | everything a captain has: a katana + pistol, 4 techniques, an ultimate, dodges, parries, blocks, his movement | **3** (below) | the hall changes each phase |

### The Commodore's three phases
1. **The Duel (100-65%):**
   - He fights you like a rival captain: katana, parries, a technique every few seconds, the ultimate once.
   - The Hall Guard stands at the walls and doesn't join.
   - A captain alone on him gets a proper 1v1.
2. **The Fortress Answers (65-30%):**
   - A beat: he steps back to the dais, rings the bell, and the galleries open: riflemen fire from them and two waves of
     marines come in.
   - He switches to pistol and katana, fights from the dais, and uses a new technique (a cross-slash wave across the
     hall).
   - The braziers flare: fire zones on the floor's quarters in turn.
3. **The Verdict (30-0%):**
   - Another beat: the war table breaks, and he draws a second blade (dual wield, faster).
   - **If he holds a fruit** (step 5: a solid one from the pool), he eats or uses it here and fights with its powers.
   - Otherwise a signature: "Final Judgement", an ultimate that sweeps the hall in three telegraphed lines.
   - No more adds. Enraged: shorter cooldowns and +20% speed.
   - He can't be staggered by light hits; poise breaks only on techniques.

**On his death:** a slow-motion beat. The broadcast follows, then the Scouring (decided).
**Health (squad of 3, around level 22):**
- the Lieutenant 6x a rival captain's;
- the Captain 8x;
- the Commodore 12x across his phases.
Solo: x0.5 (preview v2).

### Questions for Zach
1. **Names and kits:** Kesh (cutlass + pistol, molten floor), Marrow (heavy blade, seastone net, catwalks), Vane
   (katana + pistol, then dual, then a fruit if he has one): right, or other weapon kinds?
2. **Order:** the Lieutenant and the Captain are the two seals (either order, any route), and the Commodore at the
   top. Or a strict order (the Lieutenant first, then the Captain)?
3. **The Vice Admiral:** the earlier plan's top boss is now the Commodore. Keep the Vice Admiral out, or have them
   arrive with the Scouring (instead of, or as well as, the Admiral at high level)?

## Decided: the stronghold bosses (Zach, 2026-10-30)
| Decision | Choice |
|---|---|
| Bosses | **Lieutenant Varro Kesh** (the Casting Hall, cutlass and pistol, a molten floor), **Captain Ilse Marrow** (the Prison Tower, a heavy blade, a seastone net, catwalks), **Commodore Aurel Vane** (the Command Hall, the end boss: a captain AI with three scripted phases), as previewed |
| Order | **Two seals, any order:** the Lieutenant and the Captain each hold a seal in a wing; both open the bridge to the Commodore |
| The Vice Admiral | **Arrives with the Scouring:** leads its fleet after the Commodore falls (lands at high level; you run), alongside the Admiral at the top levels |

## Zach's direction (2026-10-30, night): officers in the crowds, the pacing, the Admiral at the escape
- **Officers in the crowds:** player-AI Admiralty officers (captain-style AI: weapons, skills, movement) sprinkled in
  among the grunts, **detuned a little** (fewer skills, slower to use them, less health than a rival captain).
  - Waves (squad respawns, encounter waves) have a **% chance to bring an officer**, with a **cap of 5 officers alive
    at once** across the whole fortress.
- **Pacing:** officers and grunt waves are **spread over the raid's duration and space**: you meet them as you
  advance, district by district, never 50 at once.
  - The feel is **One Piece: Burning Blood-style crowd plowing**: big crowds of weak marines you cut through, broken
    up by tougher fighters and set-piece events.
  - Inspired by the show's **Enies Lobby** (the bridge run, the Tower of Justice, the Buster Call) and **Impel Down**
    (levels of a prison, breaking out, its warden).
- **The Admiral at the Scouring:**
  - He comes ashore and **chases the crew down, trying to stop them near their ship**. Very tanky, with wild
    abilities, but **slow and intentional, not an instant kill**.
  - He **blinks in front of whoever runs for the ship** (any crewmate) and **knocks them back**.
  - Wear him down to about **2/3 of his health** and he **says something and leaves**; then you can escape.
  - Replaces "unbeatable, just run": he's a gate you push through, not a wall.

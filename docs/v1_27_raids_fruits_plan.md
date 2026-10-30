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
- **The Buster Call:** 2 minutes after the boss falls, a countdown starts; at zero the Admiralty's fleet surrounds the
  island and your ship and **barrages the whole place** with huge explosive shells (big fireball blasts) that set
  everything around you on fire. You get out with the prize.
- Still to settle (next discussion): the districts and their order, the encounter rooms and bosses (the Vice Admiral as
  the main boss?), how the alarm/stealth idea fits a respawning zone, checkpoints/the brig on a wipe in a 30-60 min run,
  the escape from the Buster Call (to the ship and out, with the ship under fire).

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

# v1.26: the post-playtest overhaul

## What it is

Zach's 2-hour co-op playtest of 1.25 (to level 12-13) found problems at sea, in combat and in the island loop. This
release fixes the sea and combat problems and reworks the island loop, the Brinehollow opening, starter weapons and
weapon variants. It ships as one release (1.26), the first to go out through the in-game updater.

What the playtest found:
- **Sea:**
  - never met a pirate crew, and pirate ships were rare
  - Admiralty patrols far too often; they could never catch the ship and said "escaped" mid-fight
  - Marines turn broadside mid-chase and fall behind
- **Hunters:** they spawn on top of you, are too fast, use skills too often and have little health
- **Capture:** in the jail, co-op guests are invisible and can't see the grunts
- **Blockade:** too small, easy to sail round, can't be destroyed
- **Combat:**
  - knockback and ragdolls far too often for players and enemies alike, so chains break
  - knockback too strong
  - enemies back off from a downed captain
  - launchers (black leg's knock-up and the like) don't work on player-based enemies
- **Island loop:**
  - chain-island side quests and minibosses feel unconnected and unrewarding
  - you often hit bosses before finding the village
  - quests give no XP
- **Brinehollow opening:**
  - too many "go talk to X" steps
  - most of the island never comes into the story
  - new players don't know which weapons exist

## Decided (2026-10-29)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Release split | One release, 1.26, with everything | Zach's call | - |
| Island loop | Not gated. Side quests and the miniboss feed the island's arc: each is a lead that weakens the villain (a lieutenant gone, intel, a shortcut, an ally in the showdown, fewer men). The showdown is open any time but harder with nothing done. Finishing the island pays a big crew-wide reward (XP, bounty, chest) | Side work felt unrewarding and disconnected | Play test |
| XP in co-op | Quests are now worth XP. Quest completions and boss kills give full XP to every captain on the same island, wherever they are. Ordinary kills stay shared within 40 m (Net.XP_RANGE) | Crewmates split up on an island | - |
| Starter weapon | A new captain starts unarmed. Vey's training yard has a rack with every weapon kind, each tried on the dummies, and you keep one. The rest are bought in shops later | Players never learned the options; mastery starts on the weapon they want | - |
| Weapon variants | One alternate per slot (aerial, sprint attack, right-click), three per weapon kind, unlocked at mastery milestones and swapped freely in the menu | Choice without doubling the animation work | **Preview first:** the list per kind with its mastery levels, for Zach's OK |
| Bounty hunters | Announced first (a banner plus a sail or a villager's warning), then the hunter lands 30-60 s later and walks in from a distance with an intro line. Slower, tankier, skills on longer cooldowns: a longer fight that's easier to start | Arrivals were jarring; fights too fast and too short | Tune in play |
| Marine chase | Forward-facing bow chasers and sail-shredding chain shot while on course. Broadsides only once alongside. Harpoons stay the pirates' signature | Turning broadside lost them the chase | - |
| Blockade | Three ships in a wide arc round the parked ship, with no way round. Sinking or disabling any one (cannons, boarding, abilities) opens a gap; the other two chase | It was small and could be sailed round | - |
| Brinehollow opening | About 45-60 min, ~18-22 steps across the whole island (lighthouse, ruins, cliffs, forest, the far side), fewer chained "talk to X" steps. The weapon rack comes early, after an unarmed brawl | Zach: back-and-forth talks, places never visited | **Preview first:** the step list, for Zach's OK |
| Old saves' bounty | Left as it is; only new deeds use the new values | Zach's call | - |
| Sea and bounty pacing | The table proposed after the playtest: patrol ship 1,000; patrols none/420/300/240 s by tier; 5 min quiet after a patrol is beaten or lost; pursuers at the crew's top speed +1 for a 90 s chase; the hunt holds while a captain is on or near either deck (no false "Escaped"); MAX_ATTACKERS counts only pirates; leg zones ~180 m off the route and two per leg more often; the rival crew gets its island before an officer | Diagnosed from the code and Zach's save | **assumed**, tune in play |
| Combat knockback | The table proposed after the playtest: grunt poise 50, elite 80; a break is a 1.3 s stagger, with a ragdoll only from 25+ weight blows, ultimates or crumples; knockdown throw 2.5-4.5 m/s; hitstun shove at most 2.5; grunt rush and sweep stagger players, and only the red-glow attack and big hits floor them; players get 60 poise and 4 s immunity after going down; enemies circle close and wait by a downed captain; rivals and officers are launched and juggled once their poise breaks | Diagnosed from the code | **assumed**, tune in play |

### Round 2 (2026-10-29): villages, healing, juggles, the rename

Zach's further notes:
- The Edy infuse in the kicking stance shows on the hands and arms, not the feet and shins.
- Only one black-leg ability juggles.
- Villages:
  - they all look alike: the same square every time and a few houses, with only two interiors that have anything in them
  - NPCs are clumped in the tavern or in a group outside
  - smiths, ateliers and shipwrights have no icons
- Too few names, titles and lines (Old Pell and Headmaster Pakua show up everywhere).
- There's no consistent way to heal.
- He wants a compass to crewmates and objectives.
- He wants unique places that make finding a village feel like a reward.
- He wants the One Piece rename finished.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Navigation | The existing compass strip (`scripts/ui/compass_strip.gd`) is always on and shows crewmates (name and distance), the active quest or arc objective, the village and discovered places. No minimap | Cheap, readable, PS1-fitting | - |
| Healing | A tonic flask: 3 charges, each about 40% health over 1 s, refilled at inns, the ship's galley and campfires. Charges and strength go up through Cooking mastery or vendors. Food, meals and the 1%/s calm regen stay | No consistent heal before | Tune in play |
| Juggles | Every weapon kind gets at least one launcher (a technique or its alternate right-click) | Only black leg's one ability juggled | - |
| Unique places | Every village rolls one unique place from a pool of about 8-10 (library, onsen, fine restaurant, legendary swordsmith...), with no repeats along a chain until the pool runs out. Each has its own reward or mechanic, and a rumour hints at it before you arrive | Finding a village should feel like a reward | **Preview first:** the pool, with each place's mechanic and reward |
| Talking to NPCs | (1) Gossip turns up leads for the island's arc (the villain's weak spot, the miniboss's lair, a cache). (2) Tavern games: dice, arm wrestling, a drinking contest, fishing bets, for gold and reputation | Talking had no point | **Preview first:** the games and their stakes |
| Shops and vendors | Every vendor (store, smith, atelier, cookhouse, shipwright) has an enterable shop with an interior dressed for the trade, and stands at their counter day and night with no schedule. Market stall vendors stay at their stalls. Wandering folk keep their schedules. Every vendor has a map and compass icon | Vendors were never where they should be; interiors went unused | - |
| Village variety | More layouts and plaza shapes, more dressed interiors, bigger name, title and line pools per theme | Villages looked copy-pasted, and the same names kept showing up | My call in the build |
| Rename scope | Finish docs/originality_plan.md: (1) rename internal ids and files (sea_king → leviathan, devil_fruits → driftfruits, log_pose → lodestone, the haki ids → will...) with a save and co-op migration for old ids; (2) the site, README and the GitHub notes for v1.8-v1.17; (3) name the rest (the Warlords/Emperors-style powers, Admiralty ranks). No visual reskin pass | Zach: "fully rename everything" | **Preview first:** the names for (3) |
| Public repo | Stays public for now; decide when the Steam page is near | The updater and site use GitHub Releases | Before the Steam page |

### Round 3 (2026-10-29): the Edy tree, a mock first

Zach's notes on today's Edy (1.23-1.24 Will paths):
- It's confusing: what passives are and how to get them isn't clear (he had none after a whole run).
- Having to buy every variant to move up a tier felt bad.
- He misses the old ranks earned by use (pre-1.23: Coat → Hardened → Ryuo, Foresight → Second Sight → Future Sight).
- He wants Foresight to level up over time on purpose, as an ability that works by itself.

What he asked for:
- One big Edy tree with every path as a branch, points spent down each branch in order.
- Four node kinds: stats, passive abilities, equipped passives, and equipped abilities with ranks earned by use.
- After that, a pass on the Edy types and their effect looks.

**Mock:** https://claude.ai/artifact/91LwPHU2X7A7vxbLCP6ifa (shared with Zach for iteration).
- Seven branches (Iron Will, Sense, Captain's Will, Tide, Tempo, Fury, Bond), 7 nodes each, 105 points in all.
- Four kinds: stat, passive (always on), passive (equipped), ability (on the bar).
- Ranks I-III by use (e.g. Infuse → Hardened at 120 infused blows → Overflow at 400; Foresight always on → Second
  Sight at 40 auto-dodges → Future Sight at 150).
- No variants to buy.
- Slots: 2 / 3 at level 15 / 4 at level 25 equipped passives; 2 / 3 at level 20 bar abilities.
- Points: 1 a level from level 4, plus 1 a boss or arc villain (~19 at level 15, ~59 at level 40, about half the tree).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Edy tree shape | **Not decided:** iterate on the mock with Zach first | Feel systems get a preview first | After the mock is OK'd |
| Edy type looks | A pass after the tree; the mock sketches the five current looks on a kicking leg as a starting point | Zach: the types and looks aren't what he wants yet | Next round |
| Tree shape (v2 mock) | A round constellation with the Edy core (the type's edge, free) in the middle and seven branches round it. Each branch splits into two paths that meet again. Shared **bridge nodes** sit between neighbours (a stat inside, a passive further out), reachable from either side. Learn anything linked to what you own | Zach: a big circular branching map, not so linear | Mock review |
| Switching passives off | Every always-on passive has an on/off switch (Wave Walk, Second Step, Foresight...) | Zach | - |
| Weapon effects and the Edy look | Every attack and ability keeps its current plain look and effects (weapon progression unchanged). The Edy tree gets an 8th branch, **Infusion** (between Bond and Iron Will), with two switchable skills: **Edy Techniques** (techniques and ultimates carry the Edy type's look and +8% damage, +2 energy each) and **Edy Strikes** (plain attacks carry it too, +5% damage, 0.5 energy a blow, going plain at 0 energy). The rest of the branch makes infusion stronger and cheaper: Deep Well +15 max energy, Steady Flow +20% energy regen, Dense Edy +6% infused damage and +2 Reinforce defense, Second Wind 0.3 energy back per infused hit, and Brimming (free infusion above 80% energy). Bridges: Shared Well / Kindred Edy (Bond), Tempered / Edy Armour (Iron Will). The goal: a captain who specs into Edy and energy can keep both infusions on all fight | Zach | Mock review; numbers tuned in play |

### Fixes with no design question
- Jail in co-op: guests invisible, grunts unseen by guests.
- Hunters spawning on top of the captain.
- The kicking stance's Edy infuse belongs on the feet and shins, not the hands and arms.
- The two arc lines that still shout "Marines!", plus the site and README's "Marine" / "Grand Line".
- A false "Escaped" while a captain boards an enemy ship or swims (DECK isn't counted as pursuing; `_crew_ship` needs a
  captain aboard).

### Open / deferred
- Preview the weapon variants list (per kind, with mastery levels) before building them.
- Preview the new Brinehollow step list (places, order, what each step teaches) before building it.
- Preview the island-completion reward and what each kind of lead does to a showdown, with numbers.
- Zach may still have more playtest notes to add.

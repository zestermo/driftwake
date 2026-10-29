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

### Fixes with no design question
- Jail in co-op: guests invisible, grunts unseen by guests.
- Hunters spawning on top of the captain.
- A false "Escaped" while a captain boards an enemy ship or swims (DECK isn't counted as pursuing; `_crew_ship` needs a
  captain aboard).

### Open / deferred
- Preview the weapon variants list (per kind, with mastery levels) before building them.
- Preview the new Brinehollow step list (places, order, what each step teaches) before building it.
- Preview the island-completion reward and what each kind of lead does to a showdown, with numbers.
- Zach may still have more playtest notes to add.

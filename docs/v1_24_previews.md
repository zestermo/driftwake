# v1.24 previews (for Zach's OK before building)

1.24 = combat & gear. Already decided, built without a preview: the native SpringChains port with the cape's motion on
all cloth/hair/accessories (building now), the clothing pass (clipping, textures, physics, shapes, more skins), and the
ranged weapon kinds as docs/weapons_plan.md decided them (long guns: aimed shot + blunderbuss spread, a butt stroke;
the cannon: explosive splash, recoil, long reload; the slingshot: trick ammo). Each needs your call below.

## 1. Armour and clothing stats

Today gear is looks plus a defence number on armour. Proposal: **every piece has a weight and up to two stats**, so
what you wear is a build choice, not just a look.

| Slot | Light (cloth) | Medium (leather) | Heavy (mail, plate) |
|---|---|---|---|
| Head | +3% crit | +4 defence | +8 defence, -3% stamina regen |
| Torso / vest | +5% stamina | +8 defence, +3% damage | +16 defence, +10% poise |
| Coat | +5% energy regen | +6 defence, +5% swim speed | +12 defence, -5% move speed |
| Hands | +4% attack speed | +3% damage | +6 defence, +8% block |
| Legs / feet | +5% move speed | +4 defence, +5% dodge distance | +10 defence, -4% move speed |
| Accessory | one trait from a pool (earring: +5% gold; eyepatch: +3% crit; sash: +5% stamina...) | | |

- **Weight:** the total of what you wear sets your dodge (light: a long roll; heavy: a short hop that keeps your guard)
  and swim speed (heavy sinks you slower in a fight, swims worse).
- **Rarity** (white to gold) scales the numbers (x1, x1.15, x1.3, x1.5, x1.75) and gives purple and up a second stat.
- **Sets:** 3 pieces of a named set give a small bonus (the Admiralty set: +10% vs Admiralty; the corsair set: +1 air step).
- Clothes keep their dyes and looks; the stats ride on the piece.

**Call: weight + up to two stats a piece, with sets?**

## 2. New Will paths (docs/v1_24_plan.md)

Each 5 nodes like today's paths (tier 1: 1 point; tier 2: 2, from 4 spent; tier 3: 3, from 8 spent) plus a passive.

| Path | Tier 1 | Tier 2 | Tier 3 | Passive |
|---|---|---|---|---|
| **Tide** | Deep Breath (breath x2, swim +30%) | Wave Walk (6 steps across water) / Swell (a wave knocks boarders off your deck) | Call the Wind (30 s of +25% sail speed, 3 min cooldown) | Helm Sense: -20% hull damage while you steer |
| **Tempo** | Second Step (+1 air step) | Cancel (dash out of a combo's recovery) / Flow (unhit: +attack speed, stacks to +20%) | Still Point (3 s where everything else moves at half speed, 2 min) | Light on Your Feet: +8% move speed |
| **Fury** | Red Mist (+1% damage per 4% health missing) | Berserk (10 s: heal 4% of damage dealt, take +20%) | Unbowed (once a fight, refuse to fall: 1 health and 2 s untouchable) | Thick Blood: bleed and burn halved |
| **Bond** | Link (tether to a crewmate in 15 m: share 15% of the damage they take) | Joint Gauge (hits near each other fill it) / Shelter (step in front of a downed crewmate: they take nothing) | Twin Finisher (spend the gauge: a two-person finisher from your two weapons) | Crew's Strength: +4% damage per crewmate within 20 m |

Upgrades to today's paths: Iron Will gains Mirror Guard (a perfect block reflects the blow) and Stomp (breaks shields);
Sense gains Weak Point (shows boss parts), Ambush Sense, Glimpse (3 s seeing chests/foes through walls); Captain's Will
gains Intimidate (weak foes surrender or flee: no loot, bounty up), Rally (crew aura +10% damage), Plant the Flag
(an area where your crew regenerates).

Solo: Bond links to your ship's crew deck (shelter works on yourself once a fight).

**Call: these four paths and nodes?**

## 3. Crew techniques (docs/v1_24_plan.md table)

Own key (**C**), cooldown **90 s** (60 s for the quick ones: Pincer, Covering Fire), a prompt zone 3 m round you for 6 s
where a crewmate presses **F** to join. The table of one per weapon kind is in docs/v1_24_plan.md (Skyward Kick for
black leg, Guardian Stance for katana, Crossed Blades, Hurl, Pole Vault, Anvil, Shield Wall, Pincer, Covering Fire,
Human Cannonball). Solo: the techniques that need a crewmate work with an AI rival or a downtime dummy only in the
training yard; in the field, solo players get each weapon's **self version** (black leg's kick launches you off a wall,
katana's guard is a counter stance).

**Call: key C, 90 s, a 6 s join zone, and solo self-versions?**

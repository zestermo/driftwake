# 1.20 beasts and bosses: the move lists (for Zach's OK before building)

Proposed for every boss and roamer on the beast sheet (`tools/dev/beastsheet.gd`, numbers as there). Decisions this
works from: docs/v1_20_plan.md "Decided (2026-10-23)" (openings after big moves, less knockback, slopes, the rebuild
list). Tuning numbers are starting points, tuned in play.

## Where it starts
- **11 of 17 are reskins of two bodies.** The alpha boar's three moves (charge, gore, stomp) are all that the
  behemoth, great bear, ice golem, basilisk, stag king, elder treant, rimeback, dune strider and Wild Hunt do; the
  stalker's five (stalk, pounce, claws, lash, roar) are the snow leopard's and sand lion's. That's the copy-paste.
- The five with their own move sets (ape, serpent, mantis, sandworm, scorpion) are also the bodies you kept.
- The sandworm's dive repeats 2-3 times in a row in phases 2-3 (the spam).

## Rules for every beast
- **Each kind has its own moves.** The shared base (JungleBeast: phases, poise, staggers, strikes judged on each
  captain's machine, co-op snapshots) stays; moves move out of the alpha boar into each kind.
- **4-6 moves each**, at least two of them its own (nobody else has them). A move never runs twice in a row; a
  phase adds moves or changes them, it doesn't just repeat one faster.
- **Tells:** a big move winds up 0.6-0.9 s (a rear-up, a glow, a ground marker for area hits); a quick one 0.35 s.
- **Openings:** every big move ends in a recovery of 1.0-1.6 s (stuck, winded, off-balance), hits there count
  double toward a stagger. A stagger at each third of its poise (2-3 s, it can be juggled once).
- **Knockback:** each beast has **one** move that throws you off your feet (its signature big hit). Everything else
  pushes you back or staggers you (you stay up and can dodge out).
- **Slopes:** lunges and charges follow the ground (no flying off a ridge, no stopping on a rise); a charge stops at
  a drop; arenas and roaming paths are placed off steep ground.
- **Phases:** 60% and 30% (as now). Each phase adds a move and a look change (a roar, cracked armour, a glow).

Legend: **NEW** a move it doesn't have today; *kept* today's, polished; **KO** its one knockdown.

---

## Jungle

### 1. The Silverback (ape) - kept body
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Swipe *kept* | arm drawn back 0.35 s | a sweeping backhand in front | short: 0.5 s |
| Slam *kept* **KO** | both fists up, chest beat 0.8 s | double-fist slam, ring of dust 4 m | 1.4 s, fists stuck in the ground |
| Leap *kept* | crouch, looks at you 0.7 s | jumps onto your spot, ground marker | 1.2 s, lands heavily |
| Throw *kept* | rips up a rock 0.9 s | a thrown boulder, lane on the ground | 0.8 s after the throw |
| Climb *kept* (phase 2) | roars, climbs the canopy | drops onto you from above (marker) | 1.6 s on its back |
| Grab **NEW** (phase 3) | low lunge 0.6 s | catches you, shakes, throws you (mash to break) | 1.2 s after it throws |

### 2. The Strangler (serpent, jungle / forest / snow) - kept body
Your note: it barely enters the arena. Now it crosses it.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Strike *kept* | head draws back, hiss 0.4 s | a fast bite in a line | 0.6 s head down |
| Sweep *kept* | coils to one side 0.6 s | tail sweep in an arc (jump it) | 0.8 s |
| **The train** **NEW** **KO** | bursts out of the brush at the arena's edge, ground rumble + dust line 0.9 s | charges straight across the whole arena and out the far side, then back on another line, 2-3 passes | 1.6 s after the last pass, its head on the ground (the weak moment) |
| Coil *kept* | circles you fast | wraps round you, squeezes (dodge out before it closes) | 1.0 s |
| Spit *kept* (phase 2) | throat swells 0.6 s | venom arcs, puddles that sting | 0.8 s |
| Tree *kept* (phase 3) | spirals up a trunk | drops onto you (marker) | 1.6 s, stunned |
Per theme: forest moss-green, snow white with frost on its back (the snow one's spit freezes instead of poisons).

### 3. The Shade (stalker, jungle / forest) - kept body
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Stalk *kept* | fades into the shadows | circles you half-seen, rustling | - |
| Pounce *kept* **KO** | eyes flash, crouch 0.6 s | leaps onto you | 1.2 s, it overshoots and turns |
| Claws *kept* | paw raised 0.35 s | two quick swipes | 0.6 s |
| Lash *kept* | tail flicks 0.5 s | a tail whip behind it | 0.6 s |
| Feint **NEW** (phase 2) | a pounce tell | stops short, then a real pounce from the side | 1.2 s |
| Shadow rush **NEW** (phase 3) | vanishes | three fast dashes past you from the dark | 1.4 s, panting |

### 4. The Mantis Queen - kept body
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Scythe *kept* | arms raised 0.4 s | a double cut in front | 0.6 s |
| Snap *kept* | arms fold 0.35 s | a fast pincer grab (push, no grab) | 0.5 s |
| Whirl *kept* **KO** | spreads wings, buzz 0.8 s | spins across the ground in a line | 1.4 s, dizzy |
| Display *kept* | wings flare | a scare: you're slowed for 1 s if facing it | - |
| Flit *kept* | wings blur | hops back out of reach | - |
| Brood **NEW** (phase 2) | taps the ground | 3 small mantises drop from the canopy | while they're up |

### 5. The Thornback (behemoth, jungle roamer) - **rebuilt body**
A huge armoured grazer that ignores you until you pick a fight. Thorny back, low head.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Gore *kept* | head low, snort 0.5 s | a horn toss in front (push) | 0.8 s |
| Charge *kept* **KO** | paws the ground 0.9 s | a long straight charge, stops at a tree or drop | 1.6 s stuck / stumbling |
| Thorn shake **NEW** | back spines rise 0.6 s | shakes, spines fly in a ring 5 m | 1.0 s |
| Tail club **NEW** | tail lifts behind | a sweep behind it (stops you sneaking up) | 0.8 s |
| Wallow **NEW** (phase 2) | rolls onto its side | crushes the ground beside it | 1.4 s on its back (weak belly) |

---

## Snow

### 6. The White Shade (snow leopard) - kept body
Today a recoloured stalker. Its own identity: the snow, high ground, ambushes.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Claws *kept* | paw raised 0.35 s | two quick swipes | 0.6 s |
| Pounce *kept* **KO** | crouch, tail twitch 0.6 s | a long leap | 1.2 s |
| Snow dive **NEW** | burrows into a drift | moves under the snow (a moving bump), bursts up under you | 1.2 s shaking off snow |
| Ledge leap **NEW** | climbs onto a rock or ice shelf | springs down from above (marker) | 1.2 s |
| Whiteout **NEW** (phase 2) | roars, flurry | a burst of snow: you can't see it for 2 s, then a pounce | 1.2 s |

### 7. The Bear King (great bear) - **rebuilt body**
A real bear: hump, heavy head, it stands up.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Maul **NEW** | rears on its hind legs 0.6 s | two downward swipes | 0.8 s |
| Body slam **NEW** **KO** | stands tall, roars 0.9 s | falls forward onto you | 1.6 s, getting back up |
| Charge *kept* | head down 0.7 s | a short charge (push) | 1.0 s |
| Swat **NEW** | sideways glance 0.35 s | a fast side paw (counters flanking) | 0.5 s |
| Fish-scoop **NEW** (phase 2) | digs at the snow | flings a snow chunk (lane) | 0.8 s |
| Frenzy **NEW** (phase 3) | foams, eyes red | 4-swipe chain, each a step forward | 1.6 s winded |

### 8. The Ice Golem - **rebuilt body**
A walking heap of ice and stone on two legs (not a pig): a cracked core glowing in its chest.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Hammer fist **NEW** | arm raised, frost gathers 0.7 s | an overhead smash, ice shards spread | 1.2 s, fist stuck |
| Stomp *kept* | lifts a leg 0.6 s | a frost ring 4 m (push) | 0.8 s |
| Ice wall **NEW** | hands to the ground 0.8 s | a line of ice spikes rises toward you | 1.0 s |
| Avalanche **NEW** **KO** (phase 2) | hugs itself, core flares 0.9 s | bursts: an ice ring 7 m | 1.6 s, the core open (hit it for double) |
| Reform **NEW** (phase 3) | collapses into rubble | rebuilds 2 m away, flinging ice | 1.2 s half-formed |

### 9. The Rimeback (snow roamer) - **rebuilt body**
A woolly tusked giant (mammoth-like), slow and calm until you hit it.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Tusk sweep **NEW** | head swings back 0.6 s | a wide tusk arc in front | 0.8 s |
| Trample **NEW** **KO** | trumpets, rears 0.9 s | charges, stomping (each step a small ring) | 1.6 s winded |
| Trunk toss **NEW** | trunk reaches 0.5 s | grabs snow, throws (lane) | 0.8 s |
| Herd call **NEW** (phase 2) | trumpets long | two calves charge you | while they're up |

---

## Desert

### 10. The Sand King (sandworm) - kept body
Your note: it spams the same move in stages 2 and 3. No move twice in a row; each phase adds one.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Erupt *kept* | sand ring trembles under you 0.9 s | bursts up from below | 1.4 s risen, bite reachable |
| Bite *kept* | rears, mouth opens 0.5 s | a lunging bite | 1.0 s, its head on the sand |
| Slam *kept* **KO** | towers, sways 0.8 s | crashes down along a line | 1.6 s lying across the ground (run up its back) |
| Dive *kept* | sinks | swims under the sand (a moving mound): **once**, then something else | - |
| Spit *kept* (phase 2) | throat bulges 0.6 s | a sand-and-acid spray in a cone | 0.8 s |
| Sinkhole **NEW** (phase 2) | spins under the arena's middle | the ground funnels toward a pit for 4 s (run out) | 1.2 s, its head in the pit |
| Twin **NEW** (phase 3) | two mounds | a second, smaller worm surfaces with it for one round | while it's up |

### 11. The Dune Emperor (giant scorpion) - kept body
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Pinch *kept* | claws open 0.4 s | a double pincer snap (push) | 0.6 s |
| Sting *kept* **KO** | tail arches high 0.7 s | stabs your spot, poison pool | 1.4 s, the stinger stuck |
| Sweep *kept* | turns side-on 0.5 s | a tail sweep behind and around | 0.8 s |
| Ambush *kept* | buries itself | bursts up under you (marker) | 1.2 s |
| Venom spray **NEW** (phase 2) | tail quivers 0.6 s | sprays in an arc, slows you | 0.8 s |
| Molt **NEW** (phase 3) | shell cracks | sheds its armour: faster, takes more damage | - |

### 12. The Basilisk - **rebuilt body**
A long-necked desert lizard, frilled, with a petrifying gaze (today a boar).
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Tail whip **NEW** | tail curls 0.5 s | a whip in a wide arc | 0.8 s |
| Bite *kept as gore* | head back 0.4 s | a snapping lunge | 0.6 s |
| Gaze **NEW** | frill flares, eyes glow 0.8 s | a cone: facing it, you're slowed to a crawl for 2 s (look away to avoid) | 1.0 s, frill folded |
| Burrow run **NEW** **KO** | dives into the sand | rushes under the sand and erupts at you | 1.4 s |
| Sun bask **NEW** (phase 2) | climbs a rock, frill wide | heals while it basks unless hit (a race) | knocked off: 1.6 s |

### 13. The Sand Lion - **rebuilt body**
A maned desert lion (today the stalker's body): pride, roars, rushes.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Claws *kept* | paw raised 0.35 s | two swipes | 0.6 s |
| Pounce *kept* **KO** | crouch 0.6 s | a leap | 1.2 s |
| Roar *kept* | mane flares 0.7 s | a cone of sand and sound: pushes you back, staggers if close | 1.0 s |
| Maul **NEW** | rears 0.5 s | stands and rakes twice | 0.8 s |
| Pride **NEW** (phase 2) | roars long | two lionesses join (smaller, flanking) | while they're up |

### 14. The Dune Strider (desert roamer) - **rebuilt body**
A tall long-legged desert grazer (not a camel): lean, fast, a kicker.
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Back kick **NEW** **KO** | ears flat, weight forward 0.6 s | a two-leg kick behind | 1.2 s |
| Rear stamp **NEW** | rears 0.6 s | both front hooves down in front | 0.8 s |
| Sprint **NEW** | turns away | runs off and comes back in a long arc (a charge) | 1.2 s |
| Spit *(from the strangler's)* | head back | a glob that blinds for 1 s | 0.6 s |

---

## Forest

### 15. The Stag King - kept body
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Antler charge *kept* **KO** | lowers its crown 0.9 s | a long charge, stops at trees | 1.6 s, antlers caught in a tree if it hits one |
| Rear kick **NEW** | rears 0.5 s | front hooves down | 0.8 s |
| Antler sweep **NEW** | head turns 0.5 s | a wide antler arc | 0.8 s |
| Bloom **NEW** (phase 2) | flowers on the antlers glow | roots burst in a ring round it | 1.0 s |
| Call of the wood **NEW** (phase 3) | bellows | red deer stampede across the arena (lanes) | 1.2 s |

### 16. The Elder Treant - **rebuilt body**
A walking tree, two legs of roots, long branch arms (today a bear under a bush).
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Branch sweep **NEW** | arm draws back, leaves rustle 0.6 s | a long low sweep | 1.0 s |
| Root slam **NEW** **KO** | both arms up 0.9 s | slams, roots erupt in a line | 1.6 s, arms in the ground |
| Grasping roots **NEW** | its feet glow 0.7 s | roots hold you in place 1 s (dodge out) | 0.8 s |
| Seed pods **NEW** (phase 2) | shakes its canopy | pods drop and burst (markers) | 1.0 s |
| Saplings **NEW** (phase 3) | plants a root | two treantlings rise | while they're up |
Weak: fire hurts it double; its bark turns blows from the front (hit from behind or after a recovery).

### 17. The Wild Hunt (forest roamer, at night) - kept body
| Move | Tell | What it does | Opening |
|---|---|---|---|
| Spectral charge *kept* **KO** | antlers flare cyan 0.8 s | a charge that passes through trees | 1.2 s, it flickers |
| Hounds **NEW** | howl | two ghost hounds harry you | while they're up |
| Vanish *kept* | fades | reappears behind you | 0.8 s as it forms |
| Antler lash **NEW** | head low 0.5 s | a cyan antler sweep | 0.8 s |
Spirit: immune to firearms (docs/v1_20_plan.md).

---

## Order to build (pending OK)
1. The shared quadruped rig and the alpha boar's moves moved into each kind (no behaviour change yet).
2. The rebuilt bodies one at a time (7 bear, 8 golem, 9 rimeback, 12 basilisk, 13 sand lion, 14 strider, 16 treant,
   5 behemoth), each shown on the beast sheet before its moves.
3. Each beast's moves (this list), one theme at a time, landed as unstable 1.19.x builds.
4. Then the arenas (canopy, ice cave, ruin, grove).

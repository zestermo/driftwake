# Weapons for 1.26: the sheet

**Assumed: not previewed with Zach.** Every line below is a first design, built to be played and tuned. Spec:
docs/v1_26_plan.md round 4 ("Connected weapon branches", "Two ultimates", "Crew technique variants", "Scope across 17
weapons"). Wave 1 (built first): cutlass, katana, black leg, pistol, polearm, greatsword. Wave 2: the other eleven.

## How each piece works in the tree (all 17 trees)

- **Two ultimates.** The middle branch splits after its second element node (25): ultimate A (today's) up the left with
  its lead-up node, ultimate B up the right with its own. Each lead-up costs 3, each ultimate 8 (+3 for the level). Buy
  one or both; R holds one, swapped in the skills menu out of a fight ("Not mid-fight" while a foe is on you).
- **Second crew technique.** A variant node "Crew Technique" (Guard/first branch, mastery 12, 5 points): its versions are
  today's crew technique and the new one; switch which one C plays in the menu, anywhere. Kinds:
  - **setup:** you pin, trip or hold the foe you aim at (a long stagger, 2 s); your crewmate's next blow on it within
    4 s is the finisher (x2.5, unblockable, knocks down). Solo: you play both halves.
  - **combined:** both of you strike the foe you aim at from opposite sides on the same beat (the crewmate's machine
    blinks or fires); the merged hit bursts on everyone round it. Solo: one captain, both strikes, a little lighter.
  - **support:** marks on both captains (a shared shield turning the next blows, energy traded, a haul to your side).
    Solo: the mark on you alone.
- **Three alternates.** Variant nodes that come by themselves at mastery **8 (aerial), 14 (sprint attack), 20
  (right-click)**, free; each switches between the standard move and the alternate, anywhere in the menu. The standard
  stays the default (old saves and builds play as they did).
- **A launcher.** At least one move per weapon throws a light foe up (HitData.launch, Juggle). Weapons that had none
  get it in an alternate.
- **Bridges.** Four nodes per tree between its branches (left/middle and middle/right): a stat inside (3 points) and a
  passive further out (slotted, 3 points). Buyable once you own a node it's linked to on either side.

Milestones: 8 / 14 / 20 for the alternates (assumed; 8 is the first mid-tree technique, 20 the late passives).

## Wave 1

### Cutlass (sword) - the sea: spray and foam
- **Ultimate B: Undertow.** Plant the blade: a whirlpool 8 m round you drags every foe in for 1.5 s, each cut as it
  arrives; one rising cut flings them all up and the sea crashes down on them. Lead-ups: A *Kraken's Call* (ultimate
  charges 10% faster), B *Deep Current* (+8% cutlass technique damage).
- **Crew: Crossed Cutlasses (combined).** You and your crewmate cut across the foe from opposite sides at once: an X of
  sea foam bursts on everyone round it. Solo: *Double Cross* (through them and back).
- **Aerial (8): Anchor Drop.** Point down, a straight drop onto the foe you look at: a spike and a ring of spray.
- **Sprint (14): Boarding Hook.** Slide in low and rip the blade up under them: a launcher.
- **Right-click (20): Broadside Sweep.** A wide turning cut that drives everyone round you back, instead of the thrust.
- **Launcher:** Boarding Hook; Undertow's rising cut.
- **Bridges:** Guard-Tide *Sea Legs* (+3 defense, wider parry), *Counter-current* (passive: parry window and techniques
  cut deeper); Tide-Swagger *Salt Edge* (+6% technique damage), *High Seas* (passive: energy per hit and quicker techniques).

### Katana - pale steel light and falling petals
- **Ultimate B: Moonlit Severance.** Sheathe, a breath, one draw along a 14 m line: the world goes pale and a beat later
  everything on the line splits and falls. A line, where Thousand Petals is a circle. Lead-ups: A *Still Water*
  (ultimate charges 10% faster), B *Long Breath* (+8% katana technique damage).
- **Crew: Blade and Sheath (setup).** The scabbard sweeps their legs (pinned 2 s); your crewmate's next blow on them is
  an execution. Solo: *Sheath Strike* (the trip, then your own draw).
- **Aerial (8): Heron Dive.** A falling draw through the foe you look at, landing past them.
- **Sprint (14): Wind Step.** A dash through with a rising draw: a launcher.
- **Right-click (20): Mirror Draw.** No charge: two quick draws, cut, sheathe, cut.
- **Launcher:** Wind Step.
- **Bridges:** Guard-Iai *Settled Grip* (+3 defense, wider parry), *Clear Water* (passive: counters and techniques cut
  deeper); Iai-Blade *Honed* (+6% technique damage), *Drawn Breath* (passive: energy per hit, quicker techniques).

### Black Leg - heat: a red-hot leg, crimson flame
- **Ultimate B: Volcano Course.** Stamp the ground five times: it erupts under up to five foes within 8 m, each one
  thrown up, and you chase the last with a burning heel that spikes it down. Lead-ups: A *Mise en Place* (ultimate
  charges 10% faster), B *Hot Stove* (+8% black-leg technique damage).
- **Crew: Double Course (combined).** You and your crewmate kick the foe from opposite sides at once: an X of fire, and
  it's thrown high. Solo: *Scissor Kick* (both legs).
- **Aerial (8): Meteor Heel.** A heel dropped straight down onto the foe you look at: a spike and a ring of heat.
- **Sprint (14): Sliding Shank.** A sliding kick at the shins that takes them off their feet.
- **Right-click (20): Flambe Lift.** A flipping rising kick: a launcher, instead of the guillotine heel.
- **Launcher:** Rising Heel (already); Flambe Lift; Volcano Course.
- **Bridges:** Guard-Fire *Calloused* (+3 defense, wider parry), *Simmer* (passive: techniques kick harder, parries
  wider); Fire-Flow *Searing Pace* (+6% technique damage), *Service* (passive: energy per kick, quicker techniques).

### Pistol - gold flashes and powder smoke
- **Ultimate B: Golden Ricochet.** Time slows; one gilded ball bounces between every foe within 16 m (up to 8), harder at
  each bounce, ending in a gold burst. Lead-ups: A *Dance Card* (ultimate charges 10% faster), B *Gilt Rounds* (+8%
  pistol technique damage).
- **Crew: Powder Share (support).** Toss your crewmate a loaded pistol: both reloaded at once, they get 25 energy, and
  both hit 20% harder for 8 s. Solo: *Hot Reload* (reloaded, 12 energy, the 8 s for you).
- **Aerial (8): Spiral Shot.** A spin in the air firing at up to three foes below.
- **Sprint (14): Slide Shot.** A slide on one hip, two shots into whoever's ahead.
- **Right-click (20): Barrel Lift.** The pistol butt up under the chin and a shot after them: a launcher.
- **Launcher:** Barrel Lift.
- **Bridges:** Tricks-Shots *Quick Hands* (faster reloads, +3 defense), *Showman* (passive: technique damage, energy per
  hit); Shots-Close *Steady Wrist* (+6% technique damage), *Close Call* (passive: point-blank harder, quicker techniques).

### Polearm - lightning
- **Ultimate B: Heaven's Pike.** Hurl the spear straight up: it comes down on the reticle as a bolt, and a 6 m storm
  strikes everyone in it five times. Lead-ups: A *Gathering Storm* (ultimate charges 10% faster), B *Lightning Rod* (+8%
  polearm technique damage).
- **Crew: Pinned (setup).** Sweep them and pin them under the shaft (2 s); your crewmate's next blow is the thunderclap.
  Solo: *Ground Pin* (the sweep, then the point driven down).
- **Aerial (8): Spinning Descent.** The pole whirled under you as you drop, cutting all round on the way down.
- **Sprint (14): Skyward Pike.** Plant and heave the head up through them: a launcher.
- **Right-click (20): Halberd Hook.** Hook the foe ahead and haul them in to your feet, instead of the skewer.
- **Launcher:** Skyward Pike.
- **Bridges:** Guard-Storm *Iron Shaft* (+3 defense, wider parry), *Static* (passive: techniques harder, parries wider);
  Storm-Reach *Long Arm* (+6% technique damage), *Thunderhead* (passive: energy per hit, quicker techniques).

### Greatsword - wind, jade crescents
- **Ultimate B: Eye of the Storm.** Blade out at arm's length, a cyclone 7 m round you drags them in for 2 s, then one
  full turn throws them all up and a downdraft slams them. Lead-ups: A *Rising Gale* (ultimate charges 10% faster), B
  *Stormfront* (+8% greatsword technique damage).
- **Crew: Lift and Cleave (setup).** The flat lifts the foe off its feet (held 2 s); your crewmate's next blow cleaves it
  down. Solo: *Lift and Fall* (your own cleave).
- **Aerial (8): Gale Glide.** Blade out behind, a long glide forward and down, cutting through all it passes.
- **Sprint (14): Wind Shear.** A flat rising sweep at the run: a launcher.
- **Right-click (20): Whirlwind Draw.** No charge: two turning sweeps that throw them back.
- **Launcher:** Wind Shear; Eye of the Storm.
- **Bridges:** Bulwark-Gale *Broad Back* (+3 defense, wider parry), *Weathered* (passive: techniques harder, defense);
  Gale-Momentum *Heft of Wind* (+6% technique damage), *Second Breath* (passive: energy per hit, quicker techniques).

## Wave 2

### Dual Wield - twin currents, cyan and violet, crossing in an X
- **Ultimate B: Twin Comet.** Leap, both blades crossed, dive onto the reticle: an X of light cuts 10 m out both ways.
- **Crew: Blade Wall (support).** Both of you guard each other: the next two blows on each of you are turned. Solo:
  *Whirling Guard* (two blows turned).
- **Aerial (8): Falling Scissors** (a crossed spike). **Sprint (14): Twin Rush** (a dash with two cuts).
  **Right-click (20): Rising Twins** (two upward cuts: a launcher).
- **Bridges:** *Paired Guard*, *Undertow Step*, *Crossing Edge II*, *Dancer's Breath*.

### Axe - embers and splintered stone
- **Ultimate B: Executioner's Moon.** One held overhead wind-up nothing interrupts, then a single chop: a 10 m fissure of
  fire and one huge blow on the foe in front.
- **Crew: Chopping Block (setup).** Hook their legs out (pinned); your crewmate's next blow is the chop. Solo: *Woodsman*.
- **Aerial: Woodsman's Drop** (a crack line). **Sprint: Shoulder Charge** (bowls them over). **Right-click: Uppercut
  Hew** (a rising chop: a launcher).
- **Bridges:** *Thick Neck*, *Stoked*, *Hot Edge*, *Bloodwarm*.

### Dagger - shadow, black wisps and crimson sparks
- **Ultimate B: Blood Moon Mark.** Every foe within 12 m marked; for 6 s each of your hits on a marked one opens all its
  wounds at once, and then they all fall.
- **Crew: Smoke and Mirrors (support).** Both of you vanish a moment (untouchable 1.5 s); each one's next hit is a sure
  crit. Solo: *Vanish*.
- **Aerial: Shadow Drop** (out from behind the foe below). **Sprint: Hamstring** (a slide through the legs, bleeding, a
  trip). **Right-click: Throat Flip** (an upward slash: a launcher that bleeds).
- **Bridges:** *Light Step*, *Ghost Cut*, *Red Thread*, *Night Breath*.

### Twin Daggers - venom, green motes
- **Ultimate B: Serpent's Nest.** A ring of venom pools out 7 m; you dart between everyone in it eight times.
- **Crew: Twin Viper (combined).** You spiral the foe from opposite sides, a crossed rip at the end. Solo: *Viper Spiral*.
- **Aerial: Coiled Strike** (a spike). **Sprint: Snake Slide** (a trip at the shins, bleeding). **Right-click: Fang Lift**
  (a scissor upward: a launcher).
- **Bridges:** *Supple*, *Coil*, *Venom Edge*, *Cold Blood*.

### Hammer - earth, sandstone and stone spikes
- **Ultimate B: Mountain Breaker.** Three slams walking forward, a wall of stone heaving up along each, the last throwing
  everything up.
- **Crew: Hammer and Anvil (combined).** Both strike the same foe at once: it's sent flying, bowling others. Solo: *Anvil
  Strike*.
- **Aerial: Pendulum Drop** (over the top, a crack line). **Sprint: Battering Ram** (a shove through the line).
  **Right-click: Upheaval** (a golf swing upward: a launcher).
- **Bridges:** *Stone Hide*, *Bedrock*, *Rolling Weight*, *Groundswell*.

### Twin Axes - frost, rime and ice chips
- **Ultimate B: Avalanche.** Both axes thrown down into a 6 m field of ice; you crash in after, the field freezes them
  and shatters.
- **Crew: Hook and Hew (setup).** Both beards hook their legs (pinned); your crewmate hews. Solo: *Hew*.
- **Aerial: Frost Fall** (both chopped down, an ice ring). **Sprint: Reaver's Sweep** (a low spinning chop, a trip).
  **Right-click: Rising Hooks** (both hooked up under the chin: a launcher).
- **Bridges:** *Winter Coat*, *Numb*, *Black Ice*, *Cold Fury*.

### Corsair - black powder: scarlet, gold, dark smoke
- **Ultimate B: Powder Trail.** Run a ring round them laying powder, then one shot into it: the ring blows up under them.
- **Crew: Hold Them Steady (setup).** The blade binds them (pinned); your crewmate's next blow gets a point-blank shot.
  Solo: *Bind and Fire*.
- **Aerial: Powder Leap** (a shot down for a hop, a cut on the way down). **Sprint: Boarding Rush** (a charge ending in a
  shot). **Right-click: Rising Shot** (a rising cut and a shot up into them: a launcher).
- **Bridges:** *Gunwale*, *Swagger*, *Powder Edge*, *Prize Money*.

### Long Gun - starlight, silver and moon-blue
- **Ultimate B: Constellation.** One shot straight up splits into stars that fall on up to eight foes within 20 m.
- **Crew: Pin and Shoot (setup).** Nail the foe's foot (pinned); your crewmate's next blow is the finisher. Solo: *Nail*.
- **Aerial: Scatter Down** (a cone of shot straight below). **Sprint: Bayonet Rush** (a stabbing charge).
  **Right-click: Butt Lift** (the stock up under the chin: a launcher).
- **Bridges:** *Shoulder Strap*, *Calm*, *Polaris*, *Night Watch*.

### Cannon - brimstone, sulphur-yellow and violet smoke
- **Ultimate B: Hellfire Barrage.** Braced, five shells walked from your feet out to the reticle, each burst bigger.
- **Crew: Double Barrel (combined).** Both fire into the same foe at once: one merged blast twice the size. Solo: *Double
  Charge*.
- **Aerial: Shell Drop** (a shell fired down ahead). **Sprint: Ram and Fire** (the muzzle into them and a blast).
  **Right-click: Barrel Upswing** (the barrel swung up: a launcher).
- **Bridges:** *Iron Shoulders*, *Powder Keg*, *Hot Barrel*, *Sulphur*.

### Slingshot - hot-pink and tangerine sparks
- **Ultimate B: Fireworks Finale.** A stone straight up bursts into a 10 m shower of sparks that stagger everyone under it.
- **Crew: Pouch Pass (support).** Toss your crewmate trick pellets: both get energy and hit harder for 8 s. Solo: *Sleight*.
- **Aerial: Bounce Shot** (a stone glancing between three). **Sprint: Skid Spin** (a spinning slide and stones out).
  **Right-click: Kick-up** (a stone kicked up and slung under the chin: a launcher).
- **Bridges:** *Nimble Fingers*, *Prankster's Luck*, *Spark*, *Wild Streak*.

### Unarmed - rushing wind and rings of air
- **Ultimate B: Typhoon Rush.** Two seconds of fists walking forward in a ring of wind; the last throws them up and you
  hammer them down.
- **Crew: Hold Him Down (setup).** Grab a foe in a full nelson (held 2 s); your crewmate's next blow lands huge. Solo:
  *Suplex*.
- **Aerial: Hammer Fists** (a double-fist spike). **Sprint: Flying Knee** (a knee that staggers). **Right-click: Dragon
  Uppercut** (a dipping uppercut: a launcher, like the fourth punch already is).
- **Bridges:** *Iron Jaw*, *Breath Control*, *Heavy Hands II*, *Wind in the Fists*.

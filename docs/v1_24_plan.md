# v1.24: combat & gear (Zach, 2026-10-26)

## What it is
The combat and gear update that 1.23 pushed back: the remaining weapons and items, armour and clothing stats, the full
clothing pass (textures, clipping, physics, shapes; more skins and variants), the native SpringChains port with the
cape's motion on all cloth, hair and accessories (docs/v1_23_plan.md "Cloth and hair physics, native"), plus two new
pieces decided while 1.23 was building: new Will paths and crew techniques.

## Decided (2026-10-26)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Will vs Driftfruits | **Will = what you've earned** (discipline, nerve, reputation: it sharpens what you already do: weapon, body, senses, crew, ship); **a Driftfruit = what you've become** (elements, transformations, matter; paid for with the sea weakness). A power that makes fire/ice/vines or changes your body is a fruit's | Keeps fruits worth their trade-off | - |
| New Will paths | **Tide Will** (the sea's: long breath, fast swimming, a few steps across the waves, a swell that throws boarders off the deck, a wind burst for the sails; passive: less hull damage while you steer), **Tempo Will** (extra air steps, dash-cancels out of combos, a flow meter that builds while unhit and speeds attacks, a top tier where the world slows), **Fury Will** (harder hits at low health, a berserk state that heals per hit but drops the guard, once a fight refuse to fall), **Bond Will** (link with a crewmate: share a slice of damage, build a joint gauge for a two-person finisher; solo: linked to the ship's crew) | More than the three borrowed from One Piece | Preview first (feel system) |
| Upgrades to today's paths | **Iron Will**: a perfect-block window that reflects the blow; a ground stomp that breaks shields. **Sense**: see breakable boss parts and weak points, ambush warnings, a short look at hidden chests and foes through walls. **Captain's Will**: Intimidate (weak foes surrender or flee: their loot lost, bounty up), Rally (a crew buff aura), plant your flag to hold ground | - | Preview first |
| Crew techniques | **Every weapon kind has at least one crew technique**: its own key (separate from techniques 1-5, the ultimate and normal moves), a cooldown of about 1-3 minutes. Using it opens a **zone with a prompt** where a crewmate walks up, sees a range indicator and presses a button to join. Examples: **black leg**: launch a crewmate along a direction/angle you aim (onto a big creature, over an obstacle: Sanji kicking Zoro); **katana**: stand guard over a crewmate, and when they're attacked you retaliate for them. Fun for combat and exploration | Crewmates interacting in fights, the One Piece crew feel | Preview first: one per weapon |

## Crew technique ideas (one per weapon kind, for the preview)
| Weapon | Crew technique | What the crewmate does |
|---|---|---|
| Black leg | **Skyward Kick**: aim a launch arc | steps onto your raised foot (prompt), gets kicked along the arc; lands with a free plunge |
| Katana | **Guardian Stance**: you guard a crewmate for 8 s | anyone striking them eats an iai counter from you |
| Cutlass | **Crossed Blades**: you brace a blade at shoulder height | they vault off it into a leaping slash (and over walls) |
| Axe | **Hurl**: swing them by the arm | thrown into a crowd, landing in a ground slam |
| Polearm | **Pole Vault**: plant the polearm | they run up it and vault far (gaps, ledges, onto a boss) |
| Hammer | **Anvil**: you swing low | they stand on the head and are batted skyward |
| Greatsword | **Shield Wall**: the flat raised as a wall | blocks shots for crewmates behind it; they can fire over it |
| Dual blades / daggers | **Pincer**: mark a foe | the crewmate's next hit on it and yours strike together for a crit |
| Pistol / corsair | **Covering Fire**: you suppress an area | crewmates inside take less damage and reload faster |
| Fists | **Human Cannonball**: cup your hands | they launch from your grip (shorter, faster than the kick) |
| Driftfruit | the fruit's own (a vine bridge, a flame dash a crewmate rides) | per fruit |

## Previews approved (Zach, 2026-10-26)
docs/v1_24_previews.md approved as written: armour/clothing weight + up to two stats a piece, rarity scaling, 3-piece
sets; the four Will paths (Tide, Tempo, Fury, Bond) and the upgrades to Iron, Sense and Captain's Will; crew techniques
on **the crouch key** (Zach, 2026-10-26: in combat stance crouch does nothing else, nobody crouches mid-fight; out of combat it still crouches), 90 s (60 s quick ones), a 6 s join zone (F), solo self-versions.

## Status (2026-10-27, paused for usage)
- On main: native SpringChains + cloth/hair nets, crew techniques (all 10 + sparring partner), gear stats + clothing
  pass, the defence curve cap (gold heavy ~50%). Will paths was mid-landing (branch worktree-agent-ac3890f9e415fc8e6).
- Ranged weapons: stopped mid-build; long guns piece committed on branch worktree-agent-a6c07f1cb2b6f6a17 (3 commits,
  not landed). Resume: land that branch, then the cannon, slingshot and their crew techniques.
- Before tagging 1.24: prepush (incl. nettest for crew techniques and Bond), the Web preset's exclude
  (`, driftwake_native.gdextension, bin/*`), rebuild the editor DLL (native/: `py -m SCons platform=windows
  target=template_debug custom_api_file=extension_api.json -j10` with the editor closed).

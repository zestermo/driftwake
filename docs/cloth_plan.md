# Cloth plan: rolling mode A (with its safety net) out to every drape

Status: plan only (2026-10-17). Capes and the cloak run mode A with the net since this date (docs/dev_notes.md, "capes:
mode A with its safety net"). Nothing below is built yet. **No cloth physics tests** (Zach, 2026-10-17: they'd flake
and stop runs): each round is proved with capelab renders and metrics run by hand, and judged by Zach in game.

## What A and the net are, in one paragraph

Every drape is a `SpringChains` (scripts/npc/spring_chains.gd): chains of points under an anchor joint, each segment a
bone the cloth mesh is skinned to. Mode A (`use_tuned`) is the old verlet solver with four fixes: each 60 Hz step runs
against the anchor where it was at that step's moment in the frame, the drawn shape is blended between the last two
steps in the anchor's space (no 60 Hz stepping on a 144 Hz screen), heavier damping and a softer rest pull, and several
constraint passes a step (lengths, the body's capsules against whole segments at several probes, a back plane). The net
(`net`, `_net_clear`) works on the drawn shape only, never the simulation: a segment whose sheet comes within
`CUSHION` of the legs is swung back about its root just enough to keep an eased gap, none goes into the hips, nothing
ends in front of the back plane, no segment swings past level (`NET_SWING`, the top one `NET_SWING_TOP`), a sheet's
edge chain stays on its side of the middle (`set_side`), and each turn follows its target at a limited rate (in fast,
out slower) so a jumping target can't pop the hem. So where the cloth is clear of the body, A with the net is A
exactly (capelab: the hem differs < 0.5 mm on every untouched frame).

Each drape needs, from that machinery: an anchor, A's settings per chain (`use_tuned(back, k, d, passes, collide)`
today sets one set for the whole SpringChains), the net's shape (which capsules, the plane or a cylinder, the probe
lines across the sheet each chain carries: `set_probes`), and the net's swing direction (capes swing back about x;
skirt panels swing out along their own radius).

## The generalisation to build first (one piece, before any drape)

1. **Per-chain settings.** `use_tuned` becomes per chain (`tune(ci, k, d)`), passes per SpringChains. Today's caller
   (capes) keeps its numbers.
2. **Per-chain net shape.** A chain's net gets `net_axis` (the axis its segments swing about when pushed off: capes
   x, a skirt panel the tangent of the hips at its angle) and `net_out` (the outward direction the plane check uses:
   capes +z, a skirt panel its radius). The back plane becomes per chain: "the chain's points stay outside a plane
   through `net_min` along `net_out`" (capes: the back's plane; skirts: the hips' cylinder at that angle; tails: the
   coat's back).
3. **A cylinder limit for hip drapes.** For skirts and hakama the net checks each chain against a vertical cylinder
   round the hips (radius per height = the hips' rings plus the drape's top offset), points never inside it, plus the
   legs as today. Per-sector limits: a panel may swing out freely but not in past the cylinder and not round into its
   neighbour's angle by more than half a sector (no crossing panels).
4. **capelab per drape.** `capelab.gd` takes a drape name (`cape`, `cloak`, `tails`, `skirt`, `hakama`, `hair`) and an
   outfit for it; the metrics are the same (penetration by legs/hips/plane, hem jitter, settle, swing, ms, frames the
   net touched and how far it moved the hem against the same frame without it), the strips/sheets/GIFs the same.

## The drapes, one round each

### 1. Coat tails (longcoat, captain, admiral, duster, frock, haori; `_cloth_sectors` from the coats in `_coat`)

- **Anchor:** the hips (already: `_cloth_sectors` hangs from `h.hips`). Thigh swing drives tails far more than the
  cape's torso anchor does; keep the hips.
- **Settings:** A with damping 0.25, rest pull k 0.1 (tails are stiffer than a cape: a coat's tails hold their flare),
  4 passes; collide thighs and shins (today also hips: keep hips for the net only, the solver's hips push twisted
  panels sideways, as it did the cape).
- **Net shape:** per sector. Back sectors (100-260 deg): the coat's own back as a plane per panel (the panel's radius at
  its angle, `net_out` = that radius), legs with the cushion. Front sectors (open front, 32-100 and 260-328): the
  thigh in front of them with the cushion, the cylinder behind them (never in through the hips). Probes: the four
  verts across each panel (`_cloth_sectors` builds 4 across).
- **body_builder.gd:** `_cloth_sectors` gets a `mode` argument (A or the old solver) and sets per-chain probes and net
  axes; `_coat` passes A for every coat; the captain/admiral trim hem rides the last bone as now.
- **Risks:** panels aren't tied to each other: gaps open between neighbours when one is pushed by a leg and the next
  isn't (visible as slits in a long coat at a lunge). Mitigation in the net: clamp a panel's swing to its neighbours'
  plus a few degrees (a soft coupling in the drawn shape only), or a fifth seam vertex shared and averaged between two
  panels' edge bones. Long coats at a sprint are the stress case.
- **Lab round:** capelab `tails` with the long coat (the longest tails) and the captain's coat: A0 vs A vs A+net; the
  sheet from behind and the side at run, turn, stop, spin; the gap between panels measured (max angle between
  neighbouring panels' edge rows).

### 2. Skirts (`_skirt`, 6 sectors) and the tunic/doublet skirts (`_cloth_sectors` from tops)

- **Anchor:** the hips.
- **Settings:** damping 0.3, k 0.12, 4 passes (a skirt should fall back fast: Zach's "precise, readable" bar).
- **Net shape:** the hips cylinder per sector (points never inside the cylinder at their height), the legs with the
  cushion; each panel's swing axis is the tangent at its angle (pushed out along its radius, not "back"). Front
  panels get the thigh's cushion, which is what lets a stride lift the skirt rather than cut through it.
- **body_builder.gd:** `_skirt` and the top skirts call `_cloth_sectors` with A; `_cloth_sectors` builds the cylinder
  radii from `_hips_hw()` / `_hips_hd()` per row (it already computes `aw`, `ad` per row: the net's cylinder is
  those minus the flare).
- **Risks:** the same panel gaps, worse on a full skirt (six panels, all moving): needs the neighbour clamp from
  round 1. A kneel or sit (`sit_ground`) folds the thighs up through the front panels: the net must give up gracefully
  (the "no turn clears it: left as it is" rule) rather than flip panels.
- **Lab round:** capelab `skirt` (fem body, skirt) and the sit/kneel poses as stills; panel gaps; the walk cadence
  (the hem should swing with the stride, not lag a beat).

### 3. Hakama (`_hakama`, 6 sectors to mid-shin)

- **Anchor:** the hips.
- **Settings:** damping 0.35, k 0.14 (heavy pleated cloth), 4 passes.
- **Net shape:** the cylinder and the legs like the skirt, but the hakama is trousers: each leg's panels should follow
  that leg. Split the six sectors into a left and a right group; a group's net uses only its own leg's capsules with
  the cushion and the other leg as a hard limit, so the two legs' panels don't cross between the legs.
- **body_builder.gd:** `_hakama` passes the side per sector; `_cloth_sectors` takes a per-sector collide list.
- **Risks:** mid-shin length means the shins sweep the hem at every step: the most net activity of any drape (cost and
  hem jitter). The lab must show the jitter mean stays near A's.
- **Lab round:** capelab `hakama` (the katana stance's draw and the cutlass spin: wide stances), jitter and net frames.

### 4. Sash tails and the apron (`_belts` sash tail on the torso, `_apron` on the hips)

- **Anchor:** as now (torso for the sash knot's tail, hips for the apron).
- **Settings:** the sash tail damping 0.25, k 0.08, 3 passes; the apron like a skirt's front panel.
- **Net shape:** the sash tail: the thigh on its side with the cushion, no plane (it hangs at the side); the apron: the
  thighs with the cushion and a plane in front of the hips (`net_out` -z).
- **Risks:** small; the sash tail shares the torso's SpringChains with mode-A0 drapes, so it needs its own SpringChains
  (as the cape got) or the per-chain settings from the generalisation.
- **Lab round:** stills in capelab with a sash and an apron; numbers only (they're small enough to judge from the
  sheet).

### 5. Long hair: the old strand styles and the HairFlow locks (head anchor)

Two kinds now (main, 2026-10-17): the old styles (`_hair*`, `_tails`, `_ponytail`, braids: a few chains, one per
strand or tail, 4-28 bones) and the HairFlow lock styles (`scripts/npc/hair_flow.gd`: cascade, high_tail, waves,
princess, court_bun, twin_low, half_bun, mane). HairFlow builds many locks but simulates few chains: **guide chains**
every ~30 deg per mass (`sim.add_chain`, colliders head, torso and its `hair_sh` capsule across the shoulders), each
lock ring skinned to its guide's bone at that height (rings above the guide to a never-posed `hair_root` bone), and
tails as one centre-line chain each (`_bundle`). So A applies to the guides and tails only, not per lock: that keeps
the cost to 31-86 bones' worth of chains per head rather than thousands of rings.

- **Anchor:** the head (both kinds already hang from `h.head`).
- **Settings:** A with damping 0.2, rest pull k 0.1, **2 passes** (many chains per head: cost is the risk), and above
  all the render blend between steps: today's hair steps at 60 Hz on a fast screen, the same stepping jitter the cape
  had (A0's p95 13 cm a frame at 144 Hz on the cape; hair shows it as shimmer). Tails (`_bundle`, ponytails, braids):
  damping 0.15, k 0.06 (they should swing more than a mass).
- **Net shape:** no cushion (hair rests on the shoulders and back, touching is right): hard limits only, against the
  head, the torso and HairFlow's `hair_sh` capsule (the old styles' colliders list grows it too); a plane at the back
  of the neck for back masses (HairFlow's "on the back, >= 138 deg" locks) so a mass never swings in through the neck;
  front-of-shoulder locks (HairFlow's fwd locks) get the chest plane instead; the swing limit (no guide up past level
  outside a jump, the top segment less). Probes: a guide carries a band of locks round its arc, so its probes are the
  band's ends (half the ~30 deg spacing either side at the guide's radius); a tail's probes its thickness.
- **body_builder.gd / hair_flow.gd:** the head's SpringChains goes to mode A with per-chain settings (the
  generalisation); HairFlow's `_mass` and `_bundle` call `set_probes` and the per-chain net shape for each guide;
  HairFlow's `_clear_body` ellipse (the rest shape's clearance) and the net's limits should be the same body: build
  the net's capsules from the same arm joints and torso collider.
- **Risks:** cost first. A long HairFlow style is ~10-20 guides plus tails: A's passes plus the net's probe checks on
  every guide could reach 0.3-0.5 ms a head in GDScript. Measure in the lab before anything else; if high: the net
  only on guides longer than the neck, 2 passes, the drawn net at 60 Hz with its turns interpolated, and HairFlow's
  far LOD (its notes want one before crowds wear these) sleeping the net with the body. Second: the old styles' short
  chains and HairFlow's guides mixed in one SpringChains need per-chain settings, or each kind its own SpringChains.
  Third: guides aren't tied to each other, like skirt panels: neighbouring guides pulled apart open the band between
  them (locks skinned to different guides separate): the neighbour clamp from round 1 applies here too.
- **Lab round:** capelab `hair` with cascade, princess, mane and high_tail (the longest and the heaviest tail) and the
  old long, hime and twintails: the head turn, sprint-stop and the cutlass spin; jitter, ms per head, frames the net
  touched; renders from behind and the side (hairstudio's lineup for stills).

## Order

1. The generalisation (per-chain settings, per-chain net axis/out, the cylinder, capelab per drape). One piece, landed
   with capes unchanged (capelab cape numbers identical before/after).
2. Coat tails (the most worn drape, the cape's nearest cousin, and it proves the panel-gap fix).
3. Skirts (same panel machinery, the cylinder).
4. Hakama (left/right groups on top of the skirt).
5. Sash tails and aprons (small, quick once 1-3 exist).
6. Long hair, the old styles and the HairFlow locks (different shape and the cost question; last so the net is
   mature; HairFlow is on main now, a prototype not yet in the random pools, so it can move to A before crowds wear it).

Each round: A0 vs A vs A+net in capelab on the same script, the sheet, the GIFs, the numbers, then Zach plays it (walk,
sprint, sharp turns, stops, jumps, the cutlass spin, a sit) before the next. Perf at every round: the drape's ms per
character from the lab and a Brinehollow bench (`bench.ps1`) when the drape is on NPCs (coats and skirts are: villagers
wear them, so rounds 2-4 move the bench; capes didn't).

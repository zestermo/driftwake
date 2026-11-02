extends RefCounted
## The coral atoll's numbers (docs/v1_28_plan.md "Islands"): first guesses, tuned in play. Every atoll file reads its
## tunings from here.

# --- the chain ---
## Rolled apart (like the fog and volcanic isles): this chance on a regular island, from this layer on.
const WEIGHT := 0.2
const FROM_LAYER := 2
const RADIUS := [400.0, 500.0]

# --- the land (atoll_land.gd) ---
## The ring of islets and sandbars: its width in from the coast (m), wobbling by bearing this much.
const RING_W := [48.0, 64.0]
const RING_WOBBLE := 0.22
## Islets along the ring: how many humps go round it, the mask over which a stretch is an islet, their crest (m).
const ISLETS := [5, 8]
const ISLET_AT := 0.46
const ISLET_H := [2.2, 3.6]
## A sandbar between islets: its floor under the sea (wading: SWIM_ENTER_DEPTH is 1.15) and its crest.
const BAR_Y := -0.5
const BAR_CREST := 0.32
## Passes through the ring where the sea runs in (a swim), how deep, how wide (rad on the ring).
const PASSES := [1, 2]
const PASS_Y := -2.8
const PASS_HALF := 0.035
## The lagoon: its floor (m under the sea), the floor's noise, the coral heads rising from it toward the surface.
const LAGOON_Y := [-1.9, -2.6]
const LAGOON_EDGE := 14.0
const HEADS_Y := -0.7
const HEADS_AT := 0.62
## The reef flat outside the ring (m wide, its depth) and the drop-off past it to the open sea's floor.
const REEF_FLAT := 14.0
const REEF_Y := -1.1
const DROP := 22.0
## The base land under the islets (low: the tidal flat round the boss is this, give or take its roll).
const BASE := 0.9
## Islets inside the lagoon (motu): how many, how far out (of the island's radius), their radius. Its caves are theirs.
const MOTU := [2, 4]
const MOTU_OUT := [0.36, 0.5]
const MOTU_R := [30.0, 42.0]
## (the first is the big one, room for a cave in its coral)
const MOTU_BIG := [58.0, 70.0]
## Kept this far from the village and off the causeway (they turn round the lagoon until they are).
const MOTU_KEEP := 150.0
## The causeway: a sandbar from the village's lagoon shore to the boss's flat, its half width, and the swims across it.
const CAUSEWAY_HW := 4.5
const CAUSEWAY_GAPS := [1, 2]
const CAUSEWAY_GAP := 4.0
## The boss's tidal flat: this far from the lagoon's middle, away from the village (of the lagoon's radius).
const BOSS_OUT := 0.22
## The blue hole: a deep round sink in the lagoon floor (radius, depth), this far out (of the lagoon's radius).
const HOLE_R := [14.0, 19.0]
const HOLE_Y := [-13.0, -17.0]
const HOLE_OUT := [0.35, 0.6]
## Where the village sits across the ring (0 the sea's edge .. 1 the lagoon's) and how far round from the dock (rad).
const VILLAGE_U := 0.62
const VILLAGE_TURN := 0.16
## The village's islet: the ring widened round it to this radius, its ground this high.
const VILLAGE_R := 70.0
const VILLAGE_Y := 2.5

# --- the stilt town (atoll_town.gd) ---
## Its boardwalk out over the lagoon from the village's shore: the main walk's length, the deck's height and half width.
const TOWN_WALK := [34.0, 46.0]
const TOWN_DECK_Y := 1.6
const TOWN_HW := 1.3
## Huts on piles along it, the fishing platforms at its ends.
const TOWN_HUTS := [5, 8]
const TOWN_PLATFORMS := 3

# --- places (atoll_places.gd) ---
const WRECK_R := 16.0
const PEARL_R := 14.0
const HOLE_PLACE_R := 20.0
## Pearl oysters on a pearl bed, coral gardens round the blue hole.
const PEARL_BEDS := [4, 6]
const HOLE_GARDENS := [3, 5]

# --- life (atoll_life_fx.gd) ---
## Fish shoals in the lagoon (each a MultiMesh of little fish turning on the GPU) and how many fish in one.
const SHOALS := [6, 10]
const SHOAL_FISH := [18, 30]
const SHOAL_SEE := 120.0

# --- the beasts ---
const HERMIT_HP := 2100.0
## Its shell's health (each blow on the shell is taken at SHELL_K; the body under it at full once it's off).
const HERMIT_SHELL := 900.0
const HERMIT_SHELL_K := 0.35
const HERMIT_BODY_K := 1.6
## Hurt this much since it last hid: it scuttles off and pulls in to hide (healing a little, its shell back to this much).
const HERMIT_HIDE_AT := 0.18
const HERMIT_HIDE_S := 3.2

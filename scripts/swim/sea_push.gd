extends RefCounted
## What the sea does to a swimmer besides holding them up (SwimState reads it every tick): rip currents
## (SeaCurrents), the surf at a shore shoving you in on each breaking crest with a current along the beach,
## a storm's swell carrying you with it and wearing you out, and cold water round a snow island sapping
## stamina. All of it read from the sea as it is (the shore maps, the swell, the storm cells): nothing here
## changes the waves.

## A breaking crest's shove toward the beach (m/s at a full crest), from SURF_DEPTH.y m deep in to SURF_DEPTH.x.
const SURF_PUSH := 4.2
const SURF_DEPTH := Vector2(0.3, 3.2)
## The current along the beach in the surf zone, the way the swell runs along it.
const LONGSHORE := 0.5
## Storms: the swell's drift with it and the shove down each wave's face (m/s at a full storm), and the extra
## stamina a second it costs to keep your head up in it.
const STORM_DRIFT := 0.9
const STORM_SHOVE := 4.0
const STORM_DRAIN := 3.0
## Cold water: stamina a second, and how much less comes back while you're in it.
const COLD_DRAIN := 4.5
const COLD_REGEN := 0.7
const COLD_THEMES := {"snow": 1.0}


## The rips' pull at `p` (flat m/s).
static func rip(tree: SceneTree, p: Vector3) -> Vector3:
	var sc := tree.get_first_node_in_group("sea_currents")
	return sc.rip_at(p) if sc else Vector3.ZERO


## How far into a surf zone `p` is (0 out at sea or up the beach .. 1), and which way is in to the beach.
static func surf_zone(p: Vector3) -> Array:
	var sh: Vector4 = Ocean.shore_at(p.x, p.z)
	if sh.z <= 0.05:
		return [0.0, Vector3.ZERO]
	var k := sh.z * smoothstep(SURF_DEPTH.x * 0.5, SURF_DEPTH.x * 2.0, sh.x) * (1.0 - smoothstep(SURF_DEPTH.y * 0.6, SURF_DEPTH.y, sh.x))
	if k <= 0.0:
		return [0.0, Vector3.ZERO]
	var gx := float(Ocean.shore_at(p.x + 1.0, p.z).y) - float(Ocean.shore_at(p.x - 1.0, p.z).y)
	var gz := float(Ocean.shore_at(p.x, p.z + 1.0).y) - float(Ocean.shore_at(p.x, p.z - 1.0).y)
	var inward := Vector3(-gx, 0.0, -gz)
	if inward.length() < 0.01:
		return [0.0, Vector3.ZERO]
	return [k, inward.normalized()]


## The surf at `p`: [shove + longshore current (flat m/s), crest 0..1 (a breaker on you near 1)].
static func surf(p: Vector3) -> Array:
	var z := surf_zone(p)
	var k: float = z[0]
	if k <= 0.0:
		return [Vector3.ZERO, 0.0]
	var inward: Vector3 = z[1]
	var sh: Vector4 = Ocean.shore_at(p.x, p.z)
	var h := float(Ocean.shore_swell(p.x, p.z, Ocean.clock(), sh)) * float(Ocean.amp_mult)
	var crest := clampf(h / 0.45, 0.0, 1.0)
	var along := Vector3(-inward.z, 0.0, inward.x)
	var sd: Vector2 = Ocean.swell_dir()
	if along.dot(Vector3(sd.x, 0.0, sd.y)) < 0.0:
		along = -along
	return [inward * SURF_PUSH * crest * crest * k + along * LONGSHORE * k, crest * k]


## How stormy the sea is at `p` (0 calm .. ~1.5 in a storm cell under a gale).
static func storm_k(p: Vector3) -> float:
	return clampf((float(Ocean.amp_mult) - 1.0) / 0.8 + (float(Ocean.local_swell(p.x, p.z)) - 1.0) / 1.1, 0.0, 1.5)


## A storm's swell at `p`: carried along with it and shoved down the face of each wave (flat m/s).
static func storm(p: Vector3, k: float) -> Vector3:
	if k <= 0.02:
		return Vector3.ZERO
	var sd: Vector2 = Ocean.swell_dir()
	var n: Vector3 = Ocean.get_wave_normal(p)
	return (Vector3(sd.x, 0.0, sd.y) * STORM_DRIFT + Vector3(n.x, 0.0, n.z) * STORM_SHOVE) * k


## How cold the water is at `p` (0 .. 1: round a snow island, fading out past its coast).
static func cold(tree: SceneTree, p: Vector3) -> float:
	var z: Array = KitStyle.around(tree, p)
	return float(COLD_THEMES.get(str(z[0]), 0.0)) * float(z[1])

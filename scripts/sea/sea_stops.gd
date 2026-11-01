class_name SeaStops
extends RefCounted
## The sea stops between islands (docs/v1_28_plan.md, The sea): rolled per sea leg by Chain.sea_stop (rare early,
## more often later, never guaranteed; the Admiralty lieutenant more often for a wanted crew), placed by SeaLegs on
## open water near the route and built here as the leg's "Stop" node (the same name and seed on every screen).

## Clearance a stop wants round it (m) and how far off the route it may lie.
const ROOM := 70.0
const LANE := 160.0
## Debug and tests: every leg gets this stop ("" rolls as usual).
static var force := ""


## The crew's bounty tier (its hottest captain's: bounties ride in the captains' snapshots, so every screen agrees).
static func crew_tier(tree: SceneTree) -> int:
	var t := 0
	for c in tree.get_nodes_in_group("players"):
		t = maxi(t, Bounty.tier_of(int(c.get("bounty")) if c.get("bounty") != null else 0))
	return t


static func kind_for(c: Chain, from: int, to: int, tree: SceneTree) -> String:
	if force != "":
		return force
	return c.sea_stop(from, to, crew_tier(tree))


## (F4's spawn list) A stop of `kind` out on the water ahead of `at` (the host's; not mirrored to guests).
static func debug_spawn(tree: SceneTree, kind: String, at: Vector3, yaw: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "DebugStop%d" % Engine.get_physics_frames()
	tree.current_scene.add_child(holder)
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var p := at + fwd * 48.0
	return build(holder, kind, Vector2(p.x, p.z), maxi(6, int(tree.get_first_node_in_group("player").progression.level)), randi() % 100000)


## The stop's node under `leg` (null for a kind not built yet).
static func build(leg: Node3D, kind: String, at: Vector2, level: int, seed_value: int) -> Node3D:
	match kind:
		"merchant":
			var m := MerchantShip.new().setup(Vector3(at.x, 0.0, at.y), level, seed_value)
			m.name = "Stop"
			leg.add_child(m)
			m.place(Vector3(at.x, 0.0, at.y), float(seed_value % 628) * 0.01)
			return m
	return null

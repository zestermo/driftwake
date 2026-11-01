class_name GadgetMarks
extends RefCounted
## Foes and caches marked on the compass (1.28): by the marking spyglass (what's in view within its reach) and the
## lantern bomb (what its light falls on). Each screen keeps its own list; the marker's screen sends the marked nodes'
## keys to the crew (Player.net_event "gadget_use"), so a whole crew sees them. Drawn by the CompassStrip (foes a red
## pip, caches a gold diamond, with how far). Expiry is game time (PlayerState.now_s); nothing runs per frame here.

## Net key (or instance id for an unkeyed node) -> {"node", "until", "kind": "foe" | "cache"}
static var marks: Dictionary = {}


## Mark `nodes` (foes or caches, by group) for `secs`.
static func mark(nodes: Array, secs: float) -> void:
	var until := PlayerState.now_s() + secs
	for n in nodes:
		var nd := n as Node3D
		if nd == null or not is_instance_valid(nd):
			continue
		var k := _key(nd)
		marks[k] = {"node": nd, "until": maxf(until, float(marks.get(k, {}).get("until", 0.0))), "kind": kind_of(nd)}
		(Engine.get_main_loop() as SceneTree).root.get_node("FX").ring(nd.global_position + Vector3(0, 0.1, 0), Vector3.UP, 1.1, Color(1.0, 0.35, 0.3, 0.9) if kind_of(nd) == "foe" else Color(1.0, 0.82, 0.3, 0.9), 0.35, 0.08)


## Mark the nodes behind `keys` (Net.key_of) for `secs`: a crewmate's marks arriving here.
static func mark_keys(keys: Array, secs: float) -> void:
	var nodes: Array = []
	for k in keys:
		var n: Node = _net().node_of(str(k))
		if n:
			nodes.append(n)
	mark(nodes, secs)


static func kind_of(n: Node) -> String:
	return "cache" if n.is_in_group("loot_bags") else "foe"


## The live marks ([node, kind]); the dead, gone and run out are dropped.
static func live() -> Array:
	var now := PlayerState.now_s()
	var out: Array = []
	for k in marks.keys():
		var m: Dictionary = marks[k]
		var n = m["node"]
		if not is_instance_valid(n) or not (n as Node).is_inside_tree() or now > float(m["until"]) or (n.has_method("is_dead") and n.is_dead()):
			marks.erase(k)
			continue
		out.append([n, str(m["kind"])])
	return out


static func is_marked(n: Node) -> bool:
	return live().any(func(e): return e[0] == n)


static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func _key(n: Node) -> String:
	var k: String = _net().key_of(n)
	return k if k != "" else str(n.get_instance_id())


## What the spyglass sees from `p`'s camera within `reach`: foes and unopened chests in front (a 60-degree cone) with
## a clear line to them.
static func in_view(p: Node3D, reach: float) -> Array:
	var cam := p.get_viewport().get_camera_3d()
	var from: Vector3 = cam.global_position if cam else p.global_position + Vector3.UP * 1.6
	var fwd: Vector3 = -cam.global_basis.z if cam else -p.global_basis.z
	var space := p.get_world_3d().direct_space_state
	var out: Array = []
	for g in ["enemies", "loot_bags"]:
		for e in p.get_tree().get_nodes_in_group(g):
			var n := e as Node3D
			if n == null or not n.is_visible_in_tree() or (n.has_method("is_dead") and n.is_dead()):
				continue
			if g == "loot_bags" and str(n.get("save_id")) == "" and not bool(n.get("floating")):
				continue
			var to: Vector3 = n.global_position + Vector3.UP * 0.8 - from
			if n.global_position.distance_to(p.global_position) > reach or to.normalized().dot(fwd) < 0.5:
				continue
			var q := PhysicsRayQueryParameters3D.create(from, n.global_position + Vector3.UP * 0.8, 1, [p.get_rid()])
			var h := space.intersect_ray(q)
			if not h.is_empty() and (h["collider"] as Node) != n and (h["position"] as Vector3).distance_to(n.global_position) > 1.5:
				continue
			out.append(n)
	return out

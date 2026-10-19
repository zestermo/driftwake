class_name ActionWheel
extends RefCounted
## The action wheel's entries (hold N: the things the captain can do where they are). Features add
## their own with register(); the wheel shows those whose `available` says yes, in `order`.
##
##   ActionWheel.register("cook", "Cook", "", _aboard, _cook_aboard, 30)
##
## Callables are methods (a node's, or a script's static funcs), never lambdas: a lambda from another
## script left in this static table crashes Godot at exit.
## label: a String, or a Callable(p) -> String for one that changes ("Make camp" / "Rest by the fire").
## icon: a texture path ("" = none). available: Callable(p: Player) -> bool. run: Callable(p: Player).
## Registering an id again replaces it.
## place(p) says where the captain is: "island" (ashore), "town" (a town's streets), "ship" (aboard
## the crew's ship), "helm" (at her wheel: lash it), "" (swimming, at a gun, in the air: the wheel shows nothing).

static var _entries: Dictionary = {}
static var _built := false


static func register(id: String, label, icon: String, available: Callable, run: Callable, order := 100) -> void:
	_entries[id] = {"label": label, "icon": icon, "available": available, "run": run, "order": order}


static func unregister(id: String) -> void:
	_entries.erase(id)


static func has(id: String) -> bool:
	return _entries.has(id)


## The ids the wheel shows for `p` now, in order.
static func entries_for(p: Node) -> Array:
	ensure_builtins()
	var out: Array = []
	for id in _entries:
		if (_entries[id]["available"] as Callable).call(p):
			out.append(id)
	out.sort_custom(func(a, b):
		var oa: int = _entries[a]["order"]
		var ob: int = _entries[b]["order"]
		return oa < ob or (oa == ob and str(a) < str(b)))
	return out


static func label_of(id: String, p: Node) -> String:
	var l = _entries[id]["label"]
	return str((l as Callable).call(p)) if l is Callable else str(l)


static func icon_of(id: String) -> Texture2D:
	var path: String = _entries[id]["icon"]
	return load(path) as Texture2D if path != "" else null


static func run(id: String, p: Node) -> void:
	(_entries[id]["run"] as Callable).call(p)


static func place(p: Node) -> String:
	if p.context == Player.Context.HELM:
		return "helm"
	if p.context != Player.Context.ON_FOOT or p.is_swimming():
		return ""
	var tree := p.get_tree()
	var ship := tree.get_first_node_in_group("ship") as Ship
	if ship and ship.owned() and ship.aboard(p.global_position):
		return "ship"
	if not p.is_on_floor():
		return ""
	var wg := tree.get_first_node_in_group("world_gen")
	if wg and wg.starter_island and p.get_node("/root/Music").in_village(tree, p.global_position):
		return "town"
	return "island"


## The wheel's centre words for a place.
static func place_name(where: String) -> String:
	return {"island": "Ashore", "town": "In town", "ship": "Aboard", "helm": "At the helm"}.get(where, "Nothing here")


## The entries this feature brings: making camp, and sailing downtime's (Downtime: lashing the helm, training...).
## (A feature that registered one of these ids first keeps its own.)
static func ensure_builtins() -> void:
	if _built:
		return
	_built = true
	if not has("camp"):
		register("camp", _camp_label, "", _camp_ok, Camp.make, 10)
	Downtime.register_wheel()


static func _camp_label(p: Node) -> String:
	return "Rest by the fire" if Camp.near(p) else "Make camp"


static func _camp_ok(p: Node) -> bool:
	return place(p) == "island" and p.is_free()

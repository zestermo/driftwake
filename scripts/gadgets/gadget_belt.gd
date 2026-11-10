class_name GadgetBelt
extends Node
## A captain's gadget belt (1.28): the blueprints they know, the gadgets they've built (each at a tier, with its
## charges), and the slots they carry: one on the belt alone, GadgetData.BAG_SLOTS with a gadget bag (GadgetBag, an
## item in the bag; 1.28.1). U fires the selected slot's gadget (whatever weapon is held, on foot and free, mid-jump
## too); O (GadgetWheel) takes up the next filled slot, and held E (ItemWheel, 1.31) shows them to pick one; without a bag it says a bag
## carries more. Gadgets off the slots stay built (the workbench lists them; a bag gained takes them up).
## Charges are spent per use and refilled at a workbench or camp;
## a short cooldown (game time: PlayerState.now_s) follows every use. Saved with the captain (SaveGame "gadgets").
## Nothing here runs per frame: cooldowns are timestamps, the HUD polls.
## Co-op: each captain's own. The throw plays on every screen from the thrower's event (Player.net_event
## "gadget"); the pouch on the back and the bag (its colour, the flap open) ride the snapshot's flags.

signal changed

## The lob's length, and when in it the gadget leaves the hand.
const LOB := 0.42
const RELEASE := 0.52
## Auto-aim: the foe closest to the line of sight within the throw's range and this cone.
const AIM_DOT := 0.8
const GADGET_STATE := preload("res://scripts/player_states/gadget_state.gd")
const SKIMMER_STATE := preload("res://scripts/player_states/skimmer_state.gd")

var player: Node
## blueprint id -> true
var known: Dictionary = {}
## gadget id -> {"tier": 0-2, "charges": n}
var owned: Dictionary = {}
var slots: Array = [""]
var sel := 0
## The bag colour picked last (worn first when more than one is carried).
var bag_pref := ""
## The flap is open while the wheel is up, and a moment after a cycle (game time).
var wheel_open := false
var open_until := -1.0
const OPEN_SECS := 0.9
## gadget id -> game time (s) it's ready again
var ready_at: Dictionary = {}
## The diving helmet worn: until (game time) and its breath factor (SwimState).
var helmet_until := -1.0
var helmet_k := 1.0
## The auto-reel on the rod: bites it still reels in, and how much faster (FishState).
var reel_left := 0
var reel_k := 0.0
## The ship gadget picked at the wheel (an index into ShipGadgets.fitted).
var ship_sel := 0


func breath_k() -> float:
	return helmet_k if PlayerState.now_s() < helmet_until else 1.0


func gadget() -> String:
	return str(slots[sel])


func tier_of(gid: String) -> int:
	return int(owned[gid]["tier"]) if owned.has(gid) else -1


func charges(gid: String) -> int:
	return int(owned[gid]["charges"]) if owned.has(gid) else 0


func max_charges(gid: String) -> int:
	return int(GadgetData.tier_val(gid, "charges", tier_of(gid)))


func cooldown_left(gid: String) -> float:
	return maxf(float(ready_at.get(gid, 0.0)) - PlayerState.now_s(), 0.0)


func cooldown_len(gid: String) -> float:
	return float(GadgetData.tier_val(gid, "cd", tier_of(gid)))


## Build (or set) gadget `gid` at `tier` with full charges, and put it on the belt's first free slot.
func give(gid: String, tier: int) -> void:
	owned[gid] = {"tier": tier, "charges": int(GadgetData.tier_val(gid, "charges", tier))}
	# (a ship gadget is fitted to her, fired from the wheel: no belt slot)
	if not gid in slots and GadgetData.GADGETS[gid]["kind"] != "ship":
		var i := slots.find("")
		if i >= 0:
			slots[i] = gid
			if gadget() == "":
				sel = i
	_changed()


func refill(gid: String) -> void:
	owned[gid]["charges"] = max_charges(gid)
	_changed()


## Put `gid` in slot `i` (taken off any other slot it was in; "" empties it).
func put(i: int, gid: String) -> void:
	var was := slots.find(gid)
	if gid != "" and was >= 0:
		slots[was] = ""
	slots[i] = gid
	_changed()


func cycle() -> void:
	if player.current_state_name() == "Helm":
		ShipGadgets.cycle(player)
		return
	if capacity() <= 1:
		player.call("_toast", "A gadget belt or a gadget bag lets you carry more")
		return
	for k in range(1, slots.size() + 1):
		var i := (sel + k) % slots.size()
		if slots[i] != "":
			sel = i
			break
	pick(sel)


## Slot `i` taken up (O's tap, the wheel): its name said, the bag's flap thrown open a moment.
func pick(i: int) -> void:
	sel = i
	if gadget() != "":
		player.call("_toast", "%s %s" % [GadgetData.GADGETS[gadget()]["name"], GadgetData.TIER_NAMES[tier_of(gadget())]])
	player.get_node("/root/FX").sfx("blip", player.global_position, -14.0, 0.05, 1.3)
	open_until = PlayerState.now_s() + OPEN_SECS
	_bag_look()
	get_tree().create_timer(OPEN_SECS + 0.05, false, true).timeout.connect(_bag_look)
	changed.emit()


## How many gadgets the captain carries: one, BELT_SLOTS with a gadget belt in the bag, BAG_SLOTS with a gadget bag.
func capacity() -> int:
	if bag_colour() != "":
		return GadgetData.BAG_SLOTS
	return GadgetData.BELT_SLOTS if player.inventory_component.count(GadgetData.BELT_ITEM) > 0 else GadgetData.SLOTS


## The colour of the bag carried ("" none): the one picked last if it's still in the bag.
func bag_colour() -> String:
	var inv = player.inventory_component
	if bag_pref != "" and inv.count(GadgetBag.item_id(bag_pref)) > 0:
		return bag_pref
	for c in GadgetBag.ORDER:
		if inv.count(GadgetBag.item_id(c)) > 0:
			return c
	return ""


## Is the gadget belt item carried (its pouch worn)?
func has_belt() -> bool:
	return player.inventory_component.count(GadgetData.BELT_ITEM) > 0


func bag_open() -> bool:
	return wheel_open or PlayerState.now_s() < open_until


func _bag_look() -> void:
	var body: Humanoid = player.body_model
	if body and body.bag_colour != "" and body.bag_open != bag_open():
		GadgetBag.set_open(body, bag_open())


## (1.30) Ready-made packs of `gid` carried in the bag.
func packs(gid: String) -> int:
	return player.inventory_component.count(Gadgets.kit_id(gid)) if GadgetData.KITS.has(gid) else 0


var _unpacking := false


## (1.30) A pack of a gadget not built yet becomes it, Mk I with full charges, on a free slot (its blueprint learned).
## The rest stay in the bag as refills (fire). Deferred: it changes the inventory from its own changed signal.
func unpack() -> void:
	_unpacking = false
	for gid in GadgetData.KITS.keys():
		if owned.has(gid) or packs(gid) <= 0:
			continue
		player.inventory_component.remove_item(ItemDB.get_item(Gadgets.kit_id(gid)), 1)
		known["bp_" + gid] = true
		give(gid, 0)
		var nm: String = GadgetData.GADGETS[gid]["name"]
		if gid in slots:
			player.call("_toast", "%s on your belt (%s)" % [nm, Glyphs.of("gadget_fire").to_upper()])
		else:
			player.call("_toast", "%s built: no room on the belt (a gadget belt or bag carries more; swap at a workbench)" % nm)


## The slots fitted to what's carried (a bag gained or lost; an older save's three slots): shrinking keeps the first
## filled ones (the rest stay built, off the slots); growing takes up the built gadgets off them. The bag worn to match.
func fit() -> void:
	if not _unpacking:
		_unpacking = true
		unpack.call_deferred()
	var cap := capacity()
	if slots.size() != cap:
		var cur := gadget() if sel < slots.size() else ""
		var keep: Array = slots.filter(func(g): return g != "")
		if cap > slots.size():
			for gid in owned.keys():
				if not gid in keep and GadgetData.GADGETS[gid]["kind"] != "ship":
					keep.append(gid)
		keep.resize(mini(keep.size(), cap))
		while keep.size() < cap:
			keep.append("")
		slots = keep
		sel = maxi(slots.find(cur), 0) if cur != "" else 0
		if gadget() == "":
			var f := slots.find_custom(func(g): return g != "")
			sel = maxi(f, 0)
		_changed()
	elif player.body_model and player.body_model.bag_colour != bag_colour():
		_changed()


## The selected gadget used. False (and a word why) when it can't be.
func fire() -> bool:
	if player.current_state_name() == "Helm":
		return ShipGadgets.fire(player)
	var gid := gadget()
	if gid == "":
		player.call("_toast", "No gadget on the belt: build one at a workbench")
		return false
	# (the diving helmet goes on in the water too, and the skimmer launches from it)
	var swim_ok: bool = gid in ["diving_helmet", "skimmer"] and player.current_state_name() == "Swim"
	if not (player.is_free() or swim_ok) or player.body_model.current_action() in ["gd_lob", "gd_spy"]:
		return false
	if cooldown_left(gid) > 0.0:
		return false
	if max_charges(gid) > 0 and charges(gid) <= 0:
		if packs(gid) <= 0:
			player.call("_toast", "Out of %s: refill at a workbench or a camp" % GadgetData.GADGETS[gid]["name"])
			return false
		player.inventory_component.remove_item(ItemDB.get_item(Gadgets.kit_id(gid)), 1)
		refill(gid)
		player.call("_toast", "A fresh pack of %s (%d left)" % [GadgetData.KITS[gid][0], packs(gid)])
	var why: Array = GADGET_STATE.reason(player, gid, tier_of(gid))
	if why[0] != "":
		player.call("_toast", why[0])
		return false
	if max_charges(gid) > 0:
		owned[gid]["charges"] = charges(gid) - 1
	ready_at[gid] = PlayerState.now_s() + cooldown_len(gid)
	_changed()
	if GadgetData.GADGETS[gid].get("throw", false):
		_lob(gid, tier_of(gid))
	elif gid == "skimmer":
		player.state_machine.force_state("Skimmer", {"tier": tier_of(gid), "at": why[1]})
	elif GadgetData.GADGETS[gid]["kind"] == "traversal" or gid in ["lockpick", "charge"]:
		player.state_machine.force_state("Gadget", {"id": gid, "tier": tier_of(gid), "at": why[1]})
	else:
		GadgetUtility.use(player, gid, tier_of(gid))
	return true


## The traversal gadgets' state ("Gadget"), put on the captain's state machine (its nodes come from player.tscn; this
## one is added here, the way the machine itself registers a child).
func _ready() -> void:
	var sm: StateMachine = player.get_node("StateMachine")
	for e in [[GADGET_STATE, "Gadget"], [SKIMMER_STATE, "Skimmer"]]:
		var st: Node = (e[0] as GDScript).new()
		st.name = e[1]
		st.player = player
		st.input_buffer = player.get_node("InputBuffer")
		sm.add_child(st)
		sm.states[str(e[1]).to_lower()] = st
		st.transitioned.connect(sm._on_child_transitioned)
	player.inventory_component.inventory_changed.connect(fit)


func _lob(gid: String, t: int) -> void:
	# (the decoy stands short of the foes, between them and you, rather than on one)
	var to := aim_point(float(GadgetData.tier_val(gid, "range", t)), gid != "decoy")
	var flat: Vector3 = to - player.global_position
	flat.y = 0.0
	if flat.length() > 0.1:
		player.player_model.rotation.y = atan2(-flat.x, -flat.z)
	var body: Humanoid = player.body_model
	body.show_left_prop(GadgetModels.mesh(gid, t))
	body.play("gd_lob", LOB)
	get_tree().create_timer(LOB * RELEASE, false, true).timeout.connect(func():
		if body.current_action() != "gd_lob":
			return
		body.hide_left_prop()
		var from: Vector3 = player.global_position + Vector3(0, 1.75, 0) - player.player_model.global_basis.z * 0.3
		GadgetThrow.launch(get_tree(), gid, t, from, to, player)
		player.get_node("/root/Net").event(player, "gadget", [gid, t, from, to]))


## Where a throw of reach `r` lands: on the foe nearest the camera's line within reach, else straight ahead
## (the camera's way) at 70% of the reach, dropped to the ground.
func aim_point(r: float, foes := true) -> Vector3:
	var at: Vector3 = player.global_position
	var fwd: Vector3 = -player.player_model.global_basis.z
	var cam := player.get_viewport().get_camera_3d()
	if cam:
		fwd = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best: Node3D = null
	var best_dot := AIM_DOT
	for e in player.get_tree().get_nodes_in_group("enemies") if foes else []:
		var n := e as Node3D
		if n == null or not n.visible:
			continue
		var d := n.global_position - at
		d.y = 0.0
		if d.length() > r or d.length() < 0.5:
			continue
		var dot := fwd.dot(d.normalized())
		if dot > best_dot:
			best_dot = dot
			best = n
	if best:
		return best.global_position
	return _ground(at + fwd * r * 0.7)


func _ground(p: Vector3) -> Vector3:
	var space := player.get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 12.0, 1)
	var h := space.intersect_ray(q)
	return h["position"] if not h.is_empty() else p


## The belt's best tier (the pouch's look), -1 with nothing built.
func best_tier() -> int:
	var b := -1
	for gid in slots:
		if gid != "":
			b = maxi(b, tier_of(gid))
	return b


func _changed() -> void:
	wear(player.body_model, maxi(best_tier(), 0) if has_belt() else -1)
	var body: Humanoid = player.body_model
	if body and body.bag_colour != bag_colour():
		GadgetBag.wear(body, bag_colour(), bag_open())
	changed.emit()


## The gadget belt's pouch of canisters on `body`'s back at `tier` (-1: none; worn while the gadget belt item is carried,
## its look the best tier slotted). Humanoid.apply_look wears it again on a rebuild.
static func wear(body: Humanoid, tier: int) -> void:
	if body == null:
		return
	body.pouch_tier = tier
	var old := body.torso.get_node_or_null("GadgetPouch")
	if old:
		body.torso.remove_child(old)
		old.queue_free()
	if tier < 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "GadgetPouch"
	mi.mesh = GadgetModels.pouch(tier)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 40.0
	body.torso.add_child(mi)
	var s := body.lantern_spot
	# (1.29: a backpack's bedroll hangs where it sat: the pouch moves to the front of the right hip, ahead of the lantern)
	if body.look.get("backpack", false):
		mi.position = Vector3(Vector2(s.x, s.z).length() + 0.015, s.y + 0.01, -0.05)
		mi.rotation.y = PI * 0.5
		return
	mi.position = Vector3(0.0, s.y + 0.01, absf(s.z) / sin(0.4) * 0.92 + 0.02)


## Another captain's throw arriving on this screen (Player.net_event "gadget").
static func remote(p: Node, args: Array) -> void:
	# (1.30) a planted charge: [id, tier, normal, at]
	if GadgetData.GADGETS[str(args[0])].get("plant", false):
		GadgetZone.spawn(p.get_tree(), str(args[0]), int(args[1]), args[3], p, args[2])
		return
	GadgetThrow.launch(p.get_tree(), str(args[0]), int(args[1]), args[2], args[3], p)


func to_dict() -> Dictionary:
	return {"known": known.keys(), "owned": owned.duplicate(true), "slots": slots.duplicate(), "sel": sel, "bag": bag_pref}


## (a 1.28 save had three belt slots: with no bag the first filled one stays on and the rest stay built, off the slots)
func from_dict(d: Dictionary) -> void:
	known.clear()
	for id in d.get("known", []):
		known[str(id)] = true
	owned = (d.get("owned", {}) as Dictionary).duplicate(true)
	slots = (d.get("slots", [""]) as Array).duplicate()
	sel = clampi(int(d.get("sel", 0)), 0, slots.size() - 1)
	bag_pref = str(d.get("bag", ""))
	var was: int = slots.filter(func(g): return g != "").size()
	fit()
	_changed()
	var off: int = was - slots.filter(func(g): return g != "").size()
	if off > 0:
		player.call("_toast", "The belt carries one gadget now: your other %d wait, built, until you carry a gadget bag" % off)

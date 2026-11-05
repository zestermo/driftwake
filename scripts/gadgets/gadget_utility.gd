class_name GadgetUtility
extends RefCounted
## The utility gadgets used straight from the belt (1.28; GadgetBelt.fire, numbers in GadgetData):
##   spyglass       raised to the eye a moment (gd_spy): every foe and unopened chest in view within the tier's reach is
##                  marked on the compass for its secs (GadgetMarks), and the crew get the same marks
##   diving_helmet  put on: breath underwater lasts the tier's x for its secs (SwimState spends breath / breath_k)
##   auto_reel      clipped to the rod: the next tier's catches bite themselves in (no need to strike in the window) and
##                  reel faster (FishState: reel_k)
## (The lockpick is a GadgetState; the lantern bomb and decoy are thrown.)
## Co-op: each captain's own; what the crew sees goes out as Player.net_event "gadget_use" [id, tier, args].

const SPY_LEN := 0.9
const SPY_AT := 0.45


static func use(p: Node, gid: String, t: int) -> void:
	match gid:
		"spyglass":
			_spyglass(p, t)
		"diving_helmet":
			p.gadgets.helmet_until = PlayerState.now_s() + float(GadgetData.tier_val(gid, "secs", t))
			p.gadgets.helmet_k = float(GadgetData.tier_val(gid, "breath", t))
			wear_helmet(p.body_model, t, float(GadgetData.tier_val(gid, "secs", t)))
			_net().fx("bubbles", [p.global_position + Vector3(0, 1.8, 0), 6])
			_net().fx("sfx", ["clack", p.global_position + Vector3(0, 1.8, 0), -6.0, 0.05, 0.7])
			p.call("_toast", "Diving helmet on: breath x%s for %d s" % [Gadgets._num(p.gadgets.helmet_k), int(GadgetData.tier_val(gid, "secs", t))])
			_net().event(p, "gadget_use", [gid, t, []])
		"auto_reel":
			p.gadgets.reel_left = int(GadgetData.tier_val(gid, "catches", t))
			p.gadgets.reel_k = float(GadgetData.tier_val(gid, "reel", t))
			_fx().sfx("clack", p.global_position + Vector3(0, 1.2, 0), -6.0, 0.05, 1.4)
			p.call("_toast", "Auto-reel on your rod: the next %d bites reel themselves" % p.gadgets.reel_left)


static func _spyglass(p: Node, t: int) -> void:
	var body: Humanoid = p.body_model
	body.show_left_prop(GadgetModels.mesh("spyglass", t))
	body.play("gd_spy", SPY_LEN)
	_net().event(p, "gadget_use", ["spyglass", t, []])
	p.get_tree().create_timer(SPY_LEN * SPY_AT, false, true).timeout.connect(func():
		if not is_instance_valid(p):
			return
		var secs := float(GadgetData.tier_val("spyglass", "secs", t))
		var seen := GadgetMarks.in_view(p, float(GadgetData.tier_val("spyglass", "reach", t)))
		GadgetMarks.mark(seen, secs)
		_fx().sfx("blip_high", p.global_position + Vector3(0, 1.7, 0), -6.0, 0.02, 1.2)
		var foes := seen.filter(func(n): return GadgetMarks.kind_of(n) == "foe").size()
		var caches := seen.size() - foes
		p.call("_toast", "Marked %d foe%s, %d cache%s" % [foes, "" if foes == 1 else "s", caches, "" if caches == 1 else "s"] if not seen.is_empty() else "Nothing marked in view")
		if not seen.is_empty():
			_net().event(p, "gadget_use", ["marks", t, [seen.map(func(n): return _net().key_of(n)).filter(func(k): return k != ""), secs]]))
	p.get_tree().create_timer(SPY_LEN, false, true).timeout.connect(func():
		if is_instance_valid(body) and body.current_action() != "gd_spy":
			return
		if is_instance_valid(body):
			body.hide_left_prop())


## Another captain's gadget used, arriving on this screen (Player.net_event "gadget_use").
static func remote(p: Node, args: Array) -> void:
	var t := int(args[1])
	match str(args[0]):
		"spyglass":
			p.body_model.show_left_prop(GadgetModels.mesh("spyglass", t))
			p.get_tree().create_timer(SPY_LEN, false, true).timeout.connect(func():
				if is_instance_valid(p):
					p.body_model.hide_left_prop())
		"marks":
			GadgetMarks.mark_keys(args[2][0], float(args[2][1]))
		"diving_helmet":
			wear_helmet(p.body_model, t, float(GadgetData.tier_val("diving_helmet", "secs", t)))
		"ship":
			var ship := p.get_tree().get_first_node_in_group("ship") as Ship
			var k := str(args[2][1])
			if ship:
				ShipGadgets.apply(ship, str(args[2][0]), t, _net().node_of(k) as Node3D if k != "" else null, p)


## The copper helmet on `body`'s head for `secs` (then it comes off in a puff).
static func wear_helmet(body: Humanoid, t: int, secs: float) -> void:
	var old := body.head.get_node_or_null("DivingHelmet")
	if old:
		body.head.remove_child(old)
		old.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "DivingHelmet"
	mi.mesh = GadgetModels.helmet(t)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	body.head.add_child(mi)
	mi.position = HELMET_AT
	mi.scale = Vector3.ONE * 0.2
	mi.create_tween().tween_property(mi, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	body.get_tree().create_timer(secs, false).timeout.connect(func():
		if is_instance_valid(mi):
			_fx().puff(mi.global_position, "dust", 3, 0.4, 0.4, Color(1, 1, 1, 0.6), 0.3)
			mi.queue_free())


## Where the helmet sits on the head (its local space).
const HELMET_AT := Vector3(0, 0.1, 0)


static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func _fx() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("FX")

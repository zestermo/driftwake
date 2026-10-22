extends SceneTree
## Afterimage (Acrobatics 18): the dodge leaves a decoy where you stood; the grunt after you goes for it and its blow
## shatters it (well before the decoy would fade); a second dodge straight after leaves none (once every 6 s).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var step := 0
var until := 0
var fails := 0
var spot := Vector3.ZERO
var lured_seen := false
var swung_at := 0
var broke_at := -1


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass",
		"grunts": [{"post": Vector3(0, 0, -3.5), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func decoys() -> Array:
	return get_nodes_in_group("decoys")


func _physics_process(_d: float) -> bool:
	if step >= 2 and g != null:
		if g._lure != null:
			lured_seen = true
		if broke_at < 0 and decoys().is_empty() and lured_seen:
			broke_at = Engine.get_physics_frames()
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			g = stage.camp.grunts[0]
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.progression.owned["ac_afterimage"] = true
			g.alert()
			until = TK.wait_secs(1.2)
		1:
			p.state_machine.force_state("Idle", {})
			g._release_token()
			g._set_state(3)  # CIRCLE
			g._cooldown = 5.0
			spot = p.global_position
			swung_at = Engine.get_physics_frames()
			TK.press("move_right")
			TK.act("dodge")
			until = TK.wait_ticks(3)
		2:
			TK.release("move_right")
			check("the dodge left a decoy", decoys().size() == 1)
			check("where you stood", not decoys().is_empty() and decoys()[0].spot.distance_to(spot) < 0.5)
			check("the grunt goes for it", g._lure != null)
			until = TK.wait_secs(1.5)
		3:
			var secs := float(broke_at - swung_at) / Engine.physics_ticks_per_second
			print("   decoy struck after %.2f s" % secs)
			check("its blow shattered the decoy before it faded", broke_at > 0 and secs < 1.55)
			check("back on you afterwards", g._lure == null)
			TK.act("dodge")
			until = TK.wait_ticks(3)
		4:
			check("no second decoy within 6 s", decoys().is_empty())
			return TK.done(fails)
	step += 1
	return false

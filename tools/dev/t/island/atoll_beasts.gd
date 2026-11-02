extends SceneTree
## The coral atoll's beasts on their move tables (atoll_croc.gd, atoll_tidemaw.gd): the theme's miniboss and roamer are
## its own; each, woken on the light stage with the captain 9 m off, lands a blow and fights by at least MIN_MOVES of
## its own moves (taken to its last phase partway), never the same twice running; their close blows speak the tell
## language (a fan on the ground as a cone winds up).
const TK := preload("res://tools/dev/test_kit.gd")
const KINDS := ["salt_croc", "tidemaw"]
const MIN_MOVES := 3
const FIGHT_S := 16.0
var stage
var p
var step := 0
var until := 0
var fails := 0
var ki := 0
var beast
var t := 0.0
var seq: Array = []
var was := ""
var low := false
var landed := false
var th


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _hp() -> float:
	return p.get_node("HealthComponent").current_health


func _process(d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			th = load("res://scripts/island/themes/island_themes.gd").of("atoll")
			check("its own miniboss and roamer: %s, %s" % [th.minis, th.roamers], th.minis == ["salt_croc"] and th.roamers == ["tidemaw"]
				and str(th.beasts["tidemaw"]["script"]).contains("atoll_") and str(th.beasts["salt_croc"]["script"]).contains("atoll_"))
			step = 1
		1:
			var kind: String = KINDS[ki]
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			p.global_position = Vector3(0, p.global_position.y, 0)
			p.reset_physics_interpolation()
			var at: Vector3 = p.global_position + Vector3(0, 0, -9.0)
			beast = load(th.beasts[kind]["script"]).new()
			beast.setup({"post": at, "yaw": 0.0, "level": 6, "name": th.beasts[kind]["names"][0]})
			stage.add_child(beast)
			beast.global_position = at
			seq = []
			was = ""
			low = false
			t = 0.0
			until = TK.wait_ticks(10)
			step = 2
		2:
			if ki == 0:
				TK.calm(beast, Vector3.ZERO)
				var table: Dictionary = beast._table()
				beast._table_begin("bite", table["bite"])
				var fans: Array = root.find_children("ArcWarn*", "", true, false)
				check("the croc's bite lays a fan on the ground as it winds up (%d)" % fans.size(), fans.size() >= 1)
				beast.set_physics_process(true)
			beast.alert()
			step = 3
		3:
			t += d
			if p.global_position.y > beast.global_position.y + 1.5:
				p.global_position = beast.global_position + beast._fwd() * 4.0 + Vector3.UP * 0.2
				p.reset_physics_interpolation()
			p.get_node("HealthComponent").current_health = maxf(_hp(), 50000.0)
			if _hp() < 99999.0:
				landed = true
			if beast.move != "" and beast.move != was:
				seq.append(beast.move)
			was = beast.move
			if not low and t > FIGHT_S * 0.45:
				low = true
				beast.health.current_health = beast.health.max_health * 0.22
				beast._phase_check()
			if t < FIGHT_S:
				return false
			var kinds := {}
			var twice := false
			for i in range(seq.size()):
				kinds[seq[i]] = true
				if i > 0 and seq[i] == seq[i - 1]:
					twice = true
			check("%s lands a blow and fights by its own moves: %s" % [KINDS[ki], str(seq)], landed and kinds.size() >= MIN_MOVES and not twice)
			landed = false
			beast.queue_free()
			ki += 1
			if ki >= KINDS.size():
				return TK.done(fails)
			step = 1
			until = TK.wait_secs(0.5)
	return false

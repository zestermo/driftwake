extends SceneTree
## Every beast boss and roamer reworked in 1.20 (docs/v1_20_beasts.md) fights by its own move list: each woken on the
## light stage with the captain 9 m off (invulnerable) lands a blow, uses at least MIN_MOVES different moves over a fight
## (taken to its last phase partway, so its phase moves come), and never starts the same move twice in a row.
## KINDS grows as each kind's moves land.
const TK := preload("res://tools/dev/test_kit.gd")
## [theme, kind]
const KINDS := [["snow", "great_bear"], ["snow", "ice_golem"], ["snow", "snow_leopard"], ["forest", "elder_treant"], ["jungle", "stalker"], ["desert", "sand_lion"]]
const MIN_MOVES := 3
const FIGHT_S := 16.0
var stage
var p
var step := 0
var until := 0
var fails := 0
var ki := 0
var beast
var hp0 := 0.0
var t := 0.0
var seq: Array = []
var was := ""
var low := false


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
			root.get_node("Weather").night = 1.0
			step = 1
		1:
			var th = load("res://scripts/island/themes/island_themes.gd").of(KINDS[ki][0])
			var kind: String = KINDS[ki][1]
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
			hp0 = _hp()
			until = TK.wait_ticks(10)
			step = 2
		2:
			beast.alert()
			step = 3
		3:
			t += d
			# (the captain stands still: lifted onto a beast's back, put down in front of it again)
			if p.global_position.y > beast.global_position.y + 1.5:
				p.global_position = beast.global_position + beast._fwd() * 4.0 + Vector3.UP * 0.2
				p.reset_physics_interpolation()
			p.get_node("HealthComponent").current_health = maxf(_hp(), 50000.0)
			if beast.move != "" and beast.move != was:
				seq.append(beast.move)
			was = beast.move
			# halfway: down to its last phase, so the phase moves come
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
			check("%s lands a blow and fights by its own moves: %s" % [KINDS[ki][1], str(seq)], _hp() < 99999.0 and kinds.size() >= MIN_MOVES and not twice)
			beast.queue_free()
			ki += 1
			if ki >= KINDS.size():
				return TK.done(fails)
			step = 1
			until = TK.wait_secs(0.5)
	return false

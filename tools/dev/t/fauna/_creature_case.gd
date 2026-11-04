extends SceneTree
## What every 1.30 creature test checks (tools/dev/t/fauna/<kind>.gd extends this and fills case()): the kind is in its
## theme's pool on some islands, not all (unless it's a place's own); it builds; a level scales its health; it winds
## up (S.TELL, the red glow) before it strikes (S.ATTACK) and the blow lands on a captain standing near it; it dies,
## dropping what its table says; told by the spawner's LOD it's far, it sleeps (no process, no physics).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var c
var step := 0
var until := 0
var fails := 0
var S: Dictionary
var cfg: Dictionary
var seen_tell := false
var tell_then_attack := false
var hp0 := 0.0
var landed := false


## {"theme", "kind", "args", "pool" (false: not rolled, a place's own), "at" (from the captain), "night", "prep" (fn(c)), "watch" (fn(c) each frame)}
func case() -> Dictionary:
	return {}


func _initialize() -> void:
	TK.seed_of(self)
	cfg = case()
	# (night needs Weather running: the stage named "World")
	stage = TK.stage(self, {"hud": false, "weather": cfg.get("night", false)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if c and is_instance_valid(c) and step == 2:
		if cfg.has("watch"):
			(cfg["watch"] as Callable).call(c)
		if c.state == S.TELL:
			seen_tell = true
		elif c.state == S.ATTACK and seen_tell:
			tell_then_attack = true
		if p.health_component.current_health < hp0 or str(p.current_state_name()) == "Grabbed":
			landed = true
	if TK.ticking(until):
		return false
	var kind: String = cfg["kind"]
	var ground := Vector3(0, stage.GROUND_Y, 0)
	match step:
		0:
			S = load("res://scripts/enemies/fauna/creature.gd").S
			p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			hp0 = p.health_component.current_health
			var FS = load("res://scripts/island/fauna_spawner.gd")
			if cfg.get("pool", true):
				var n := 0
				for s in range(30):
					n += 1 if FS.roll(cfg["theme"], s * 101).has(kind) else 0
				check("%s live on some %s islands, not all (%d of 30)" % [kind, cfg["theme"], n], n > 3 and n < 30)
			if cfg.get("night", false):
				var wx = root.get_node("Weather")
				wx.set_world_time(wx.time_at(23.0))
			var lv = FS.make(cfg["theme"], kind)
			lv.setup(ground + Vector3(40, 0, 40), cfg.get("args", {}))
			lv.level = 12
			lv.name = "Leveled"
			stage.add_child(lv)
			c = FS.make(cfg["theme"], kind)
			var at: Vector3 = ground + cfg.get("at", Vector3(0, 0, -6.0))
			c.setup(at, cfg.get("args", {}))
			c.name = kind
			c.position = at + Vector3.UP * 0.2
			stage.add_child(c)
			until = TK.wait_ticks(4)
		1:
			var lv = stage.get_node("Leveled")
			check("a %s builds (%d parts)" % [kind, c._parts.size()], c.kind == kind and c._parts.size() >= 3)
			check("...a level-12 one is tougher (%.0f > %.0f)" % [lv.health.max_health, c.health.max_health], lv.health.max_health > c.health.max_health)
			lv.queue_free()
			if cfg.has("prep"):
				(cfg["prep"] as Callable).call(c)
			hp0 = p.health_component.current_health
			until = TK.wait_secs(float(cfg.get("secs", 14.0)))
		2:
			check("...it winds up (its tell) before it strikes", tell_then_attack)
			check("...and the blow lands on the captain", landed)
			if str(p.current_state_name()) == "Grabbed":
				p.state_machine.force_state("Idle", {})
			for d in c.drops:
				check("...its drop %s is an item" % d[0], load("res://scripts/loot/item_db.gd").get_item(str(d[0])) != null)
			check("...it has a drop table", not c.drops.is_empty())
			# (each captain rolls their own: a trophy part a third as often as the table says, Loot.roll_drops)
			var got := 0
			for k in range(40):
				got += 1 if not load("res://scripts/items/loot.gd").roll_drops(c.drops).is_empty() else 0
			check("...which drops something now and then (%d of 40 kills)" % got, got > 0)
			var hit := HitData.new()
			hit.damage = 99999.0
			hit.knockback_force = 6.0
			c.hurtbox.take_hit(hit, p)
			check("...it dies", c.is_dead())
			until = TK.wait_ticks(6)
		3:
			var far = load("res://scripts/island/fauna_spawner.gd").make(cfg["theme"], kind)
			far.setup(Vector3(0, stage.GROUND_Y, 80), cfg.get("args", {}))
			far.position = Vector3(0, stage.GROUND_Y + 0.2, 80)
			stage.add_child(far)
			far.set_lod(far.LOD_SLEEP)
			until = TK.wait_ticks(3)
		4:
			var far = stage.get_child(stage.get_child_count() - 1)
			check("...and far off it sleeps", not far.is_physics_processing() and not far.is_processing())
			return TK.done(fails)
	step += 1
	return false

extends RefCounted
## The suites' seeds and physics-tick waits (no class_name, no autoloads by name: a --script compiles before either).
## A suite's fixed seed gives way to `run_tests.ps1 <suite> -Seed N` (DRIFTWAKE_SEED); "SEED n" shows the runner which ran.

const DEFAULT_SEED := 4242


static func seed_of(tree: SceneTree, fixed := DEFAULT_SEED) -> int:
	var env := OS.get_environment("DRIFTWAKE_SEED")
	var s := int(env) if env != "" else fixed
	use_seed(tree, s)
	return s


## A suite that loops over seeds: its own list, or just the one -Seed asked for.
static func seeds_of(fixed: Array) -> Array:
	var env := OS.get_environment("DRIFTWAKE_SEED")
	return [int(env)] if env != "" else fixed.duplicate()


## The global rng and GameManager's chain (before the world loads, or before its islands are rebuilt).
static func use_seed(tree: SceneTree, s: int) -> void:
	seed(s)
	tree.root.get_node("GameManager").chain_seed = s
	print("SEED %d" % s)


## The physics tick `n` from now: a step waits while ticking(it) (frames and seconds stretch under load, ticks don't).
static func wait_ticks(n: int) -> int:
	return Engine.get_physics_frames() + n


static func wait_secs(s: float) -> int:
	return wait_ticks(roundi(s * Engine.physics_ticks_per_second))


static func ticking(until: int) -> bool:
	return Engine.get_physics_frames() < until


## The light test stage (tools/dev/stage.gd; its header lists the opts) as the current scene, instead of the
## generated world. Call it in _initialize; the test waits for `stage.up` before its first step.
static func stage(tree: SceneTree, opts := {}) -> Node3D:
	var s: Node3D = load("res://tools/dev/stage.gd").new()
	s.build(opts)
	tree.root.add_child.call_deferred(s)
	return s


## Press and release an input action (one tap).
static func act(a: String) -> void:
	press(a)
	release(a)


static func press(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	Input.parse_input_event(e)


static func release(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = false
	Input.parse_input_event(e)


## A foe made a fair target for the next check: still (its AI off until `wake`), fresh poise (not immune to a
## knockdown from the last case), not mid-swing or guarding, full health, facing `face` (north by default).
## Most load flakes in effect tests were a grunt doing something of its own mid-check.
static func calm(g: Node, face := Vector3.FORWARD) -> void:
	g.set_physics_process(false)
	if "poise" in g and g.poise != null:
		g.poise._immune_until = -1
		g.poise.value = g.poise.full
	if "hitbox" in g and g.hitbox != null:
		g.hitbox.deactivate()
	if g.has_method("_set_state") and "S" in g:
		g._set_state(g.S.IDLE)
	if "velocity" in g:
		g.velocity = Vector3.ZERO
	if "health" in g and g.health != null:
		g.health.current_health = g.health.max_health
	if g is Node3D and face != Vector3.ZERO:
		var at: Vector3 = g.global_position - face
		at.y = g.global_position.y
		g.look_at(at, Vector3.UP)
		g.reset_physics_interpolation()


## Let a calmed foe's AI run again.
static func wake(g: Node) -> void:
	g.set_physics_process(true)


## A captain ready to cast anything: full energy, every cooldown cleared, out of whatever state it was in.
static func ready_caster(p: Node) -> void:
	p.power.energy = p.power.max_energy()
	p.power.cooldowns.clear()


## The test's last line ("RESULT OK" / "RESULT FAILED (n)"); _process returns it to quit.
static func done(fails: int) -> bool:
	print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
	return true

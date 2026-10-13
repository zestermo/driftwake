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

extends "res://tools/dev/fidelity.gd"
## Island fidelity, report only (phase 0): Brinehollow and three chain seeds' first
## islands through fidelity.gd's metrics, each gated metric's lowest ratio printed;
## passes regardless. Phase 3 makes it a gate (every gated metric >= 0.8 of
## Brinehollow's, the build and draw-call budgets). Report: tools/dev/out/fidelity/test/.


func _initialize():
	test_mode = true
	var tk = load("res://tools/dev/test_kit.gd")
	seeds = tk.seeds_of([777, 31337, 4242])
	tk.seed_of(self, int(seeds[0]))
	out_dir = "res://tools/dev/out/fidelity/test"
	change_scene_to_file("res://scenes/world/world.tscn")

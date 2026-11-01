extends RollerBug
## Ember beetles (the volcanic isle's): the roller's brain - curl up, roll at you, unroll dazed - in a black-and-gold
## pill bug whose plates glow with heat in their seams. Killed, it bursts in a shower of embers and a crack of fire.


func _setup(args: Dictionary) -> void:
	super._setup(args)
	kind = "ember_beetle"
	morph = 2
	max_hp = 60.0
	drops = [["chitin_shard", 0.6, 1]]


func _build() -> void:
	super._build()
	var ember := _glow(Color(1.0, 0.45, 0.1))
	_part(_body, "Seams", Vector3.ZERO, "ember_seams", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		for i in range(6):
			var z := lerpf(0.36, -0.3, i / 5.0)
			var w := 0.36 - absf(z) * 0.18
			var h := 0.3 - absf(z) * 0.2
			mb.add_box(ember, Transform3D(Basis(Vector3.RIGHT, -z * 0.5), Vector3(0, h * 0.99, z + 0.05)), Vector3(w * 0.8, 0.025, 0.02), 1.0, Color.WHITE, false, false))
	_part(_ball, "BallSeams", Vector3.ZERO, "ember_ball_seams", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		for i in range(6):
			var a := TAU * i / 6.0 + TAU / 12.0
			mb.add_box(ember, Transform3D(Basis(Vector3.RIGHT, a), Vector3(0, 0.0, 0.36)), Vector3(0.5, 0.03, 0.03), 1.0, Color.WHITE, false, false))


func _cry_death() -> void:
	Net.fx("embers", [global_position + Vector3.UP * 0.4, Vector3.UP, 18])
	Net.fx("sfx", ["fire_burst", global_position, -4.0, 0.1])

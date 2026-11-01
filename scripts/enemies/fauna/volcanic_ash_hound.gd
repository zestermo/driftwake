extends Wolf
## Ash hounds (the volcanic isle's packs): the wolves' pack brain - the lead's howl, circling at a lunge's length, one
## lunge at a time - in lean soot-dark hounds with a line of embers smouldering down the back. Their bite burns
## (embers on a landed bite).


func _setup(args: Dictionary) -> void:
	super._setup(args)
	kind = "ash_hound"
	morph = 2
	skin_tex = "fur"


func _build() -> void:
	super._build()
	var ember := _glow(Color(1.0, 0.42, 0.1))
	_part(_body, "Embers", Vector3(0, 0.16, 0), "ash_embers" + ("_lead" if lead else ""), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		for k in range(6):
			var z := -0.4 + k * 0.15
			mb.add_cylinder(ember, Transform3D(Basis(Vector3.RIGHT, 2.5), Vector3(0, 0.02, z)), 0.03, 0.0, 0.16, 4, 1.0, Color.WHITE, false))


func _landed(target: Node, data: HitData) -> void:
	super._landed(target, data)
	FX.embers((target as Node3D).global_position + Vector3.UP * 0.8, Vector3.UP, 8)

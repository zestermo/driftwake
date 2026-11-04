extends Boar
## Thorn-backed boars (the forest, 1.30): the fairy-tale wood's own boar, grown over - moss for a hide and a ridge of
## bramble thorns down its back, curved like a briar's, pale at the points. Shorter tempered than the common boar: it
## comes for you from further off, paws (the tell: head down, dust off the hoof) and charges, and its charge knocks
## you flat. Its back is armoured in thorns: a blow from behind or above mostly turns on them (sparks of bark), so
## sidestep the charge and take it in the flank or the face.

const MOSS := Color(0.2, 0.26, 0.13)
const THORN := Color(0.36, 0.24, 0.14)
const TIP := Color(0.85, 0.8, 0.62)


func _setup(args: Dictionary) -> void:
	super._setup(args)
	kind = "thorn_boar"
	hostile = true
	young = false
	tusker = bool(args.get("lead", false))
	herd = int(args.get("pack", -1))
	size_k = 1.35 if tusker else 1.1
	max_hp = 190.0 if tusker else 130.0
	xp = 120 if tusker else 75
	coins = Vector2i(2, 5)
	drops = [["boar_haunch", 0.7, 1], ["tusk", 0.4, 1], ["timber", 0.2, 1]]


func _moves() -> Array:
	return [[22.0, 8.5, Vector3(0.9, 0.85, 0.75), Vector3(0, 0.45, -0.8), true, 0.5],
		[28.0, 9.5, Vector3(0.95, 0.9, 0.8), Vector3(0, 0.45, -0.8), true, 0.55]]


func _build() -> void:
	super._build()
	var skin := _skin()
	_part(_body, "Thorns", Vector3.ZERO, "thorns" + ("_t" if tusker else ""), func(mb: MeshBuilder, rng: RandomNumberGenerator):
		# moss over the back and flanks
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0.0)), Vector3(0.3, 0.14, 0.62), rng, 0.25, 3, 7, 1.0, MOSS)
		for s in [-1.0, 1.0]:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.24, 0.05, 0.1)), Vector3(0.08, 0.14, 0.4), rng, 0.3, 3, 5, 1.0, MOSS.darkened(0.2))
		# the briar ridge: curved thorns in two rows down the spine, tallest over the shoulders, a few on the flanks
		for i in range(14):
			var f := lerpf(-0.45, 0.55, i / 13.0)
			var h := 0.16 + 0.14 * sin(clampf((0.6 - f) / 1.1, 0.0, 1.0) * PI)
			for s in [-1.0, 1.0]:
				var base := Vector3(s * 0.07 + rng.randf_range(-0.02, 0.02), 0.28, f)
				var tip := base + Vector3(s * 0.06, h, 0.1 + rng.randf_range(0.0, 0.08))
				mb.add_tube(skin, PackedVector3Array([base, base.lerp(tip, 0.5) + Vector3(0, 0, -0.04), tip]), 0.035, 0.004, 4, 1.0, THORN)
				mb.add_box(skin, Transform3D(Basis.IDENTITY, tip), Vector3(0.015, 0.03, 0.015), 1.0, TIP, false, false)
		for k in range(8):
			var s := -1.0 if k % 2 == 0 else 1.0
			var base := Vector3(s * 0.27, rng.randf_range(-0.05, 0.15), rng.randf_range(-0.3, 0.45))
			mb.add_tube(skin, PackedVector3Array([base, base + Vector3(s * 0.1, 0.05, 0.06)]), 0.025, 0.004, 3, 1.0, THORN))


## Its back is thorns: a blow from behind it mostly turns.
func _armor(_hit: HitData, dir: Vector3) -> float:
	return 0.45 if dir.dot(_fwd()) > 0.35 else 1.0


func _hurt(hit: HitData, attacker: Node, dir: Vector3) -> bool:
	if dir.dot(_fwd()) > 0.35:
		Net.fx("debris", [global_position + Vector3.UP * 0.7 * size_k, Vector3.UP, 5, THORN, 3.0])
	return super._hurt(hit, attacker, dir)


func _brain(delta: float) -> void:
	var p := _target()
	# (shorter tempered: it comes from further off)
	if state in [S.IDLE, S.WANDER] and p and _player_ok(p) and flat(p.global_position - global_position).length() < Stealth.range_for(p, global_position, _fwd(), 7.5):
		provoke(p)
		_alarm()
		return
	super._brain(delta)


func _charge_speed() -> float:
	return 10.5

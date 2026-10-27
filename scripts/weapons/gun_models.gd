class_name GunModels
## The meshes of the 1.24 ranged kinds (WeaponDesigns.build sends them here), in the frame every two-handed weapon uses:
## the right hand at the origin, the weapon along -Z, its underside (trigger guard, grip) toward -Y.

## Where a long gun's bore runs above the hand (m), and its stock back to the butt plate behind it.
const LG_BORE := 0.035
const LG_STOCK := 0.34


## A long gun's barrel length (the muzzle this far ahead of the hand, along -Z).
static func lg_barrel(design: String) -> float:
	return float((WeaponDesigns.DESIGNS["longgun"] as Dictionary).get(design, {}).get("barrel", 1.0))


## Long guns: a full wooden stock from the butt plate behind the hand to the forestock under the barrel, the lock on
## the right side, brass bands; the blunderbuss flares to a bell, the fowler has two barrels side by side, the jezail's
## stock drops in a deep curve.
static func longgun(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := WeaponDesigns._mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "planks")
	var wood := PSXMat.lit("planks", WeaponDesigns._c(p, "wood", Color(0.58, 0.36, 0.2)))
	var fit: Material = m["fit"]
	var steel: Material = fit if bool(p.get("brass_barrel", false)) else m["blade"]
	var along := Basis(Vector3.RIGHT, -PI * 0.5)
	var bl := WeaponDesigns._f(p, "barrel", 1.0)
	var r := WeaponDesigns._f(p, "r", 0.017)
	var sides := int(p.get("sides", 6))
	var n := int(p.get("barrels", 1))
	var y := LG_BORE
	# the barrel (or two)
	if n == 2:
		for x in [-r, r]:
			mb.add_cylinder(steel, Transform3D(along, Vector3(x, y, -0.02)), r, r * 0.92, bl, sides, 2.0)
	else:
		var flare := WeaponDesigns._f(p, "flare", 0.0)
		if flare > 0.0:
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, y, -0.02)), r * 1.15, r * 1.25, bl * 0.7, sides, 2.0)
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, y, -0.02 - bl * 0.7)), r * 1.25, flare, bl * 0.3, 8, 2.0, Color.WHITE, false)
		else:
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, y, -0.02)), r * 1.12, r * 0.95, bl, sides, 2.0)
			mb.add_cylinder(fit, Transform3D(along, Vector3(0, y, -0.02 - bl + 0.03)), r * 1.25, r * 1.25, 0.025, sides, 2.0)
			# the front sight
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, y + r + 0.008, -bl + 0.05)), Vector3(0.006, 0.014, 0.012), 2.0)
	# the forestock under it, the ramrod beneath, brass bands round both
	var fore := bl * (0.45 if p.has("flare") else 0.72)
	var fw := 0.05 + (0.02 if n == 2 else 0.0)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, y - r - 0.006, -0.03 - fore * 0.5)), Vector3(fw, 0.034, fore), 2.0)
	mb.add_cylinder(m["blade"], Transform3D(along, Vector3(0, y - r - 0.026, -0.06)), 0.005, 0.005, fore * 0.95, 4, 2.0)
	for k in [0.35, 0.68, 0.98]:
		mb.add_box(fit, Transform3D(Basis(), Vector3(0, y - 0.006, -0.03 - fore * k)), Vector3(fw + 0.008, r * 2.0 + 0.03, 0.02), 2.0)
	# the lock on the right side, the hammer cocked above it, the trigger and its guard below the hand
	mb.add_box(m["blade"], Transform3D(Basis(), Vector3(0.026, 0.02, -0.03)), Vector3(0.008, 0.035, 0.12), 2.0)
	mb.add_box(m["blade"], Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.024, 0.06, 0.0)), Vector3(0.012, 0.045, 0.016), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.04, -0.02)), Vector3(0.012, 0.012, 0.11), 2.0)
	mb.add_box(m["blade"], Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, -0.028, -0.01)), Vector3(0.006, 0.03, 0.006), 2.0)
	# the wrist round the hand, then the stock dropping back to the butt plate
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.005, 0.0)), Vector3(0.042, 0.05, 0.12), 2.0)
	var drop := 0.32 if bool(p.get("curve", false)) else 0.16
	var stock_c := Vector3(0, -0.025 - drop * 0.12, 0.06 + LG_STOCK * 0.5)
	mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, drop), stock_c), Vector3(0.046, 0.085, LG_STOCK), 2.0)
	mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, drop * 0.6), stock_c + Vector3(0, -0.045, 0.03)), Vector3(0.044, 0.06, LG_STOCK * 0.8), 2.0)
	var butt := Vector3(0, -0.05 - drop * 0.18, 0.06 + LG_STOCK)
	mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, drop), butt), Vector3(0.05, 0.13, 0.016), 2.0)
	if bool(p.get("curve", false)):
		# the jezail's inlay down its stock
		for k in [0.25, 0.5, 0.75]:
			mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, drop), stock_c + Vector3(0.024, 0, (k - 0.5) * LG_STOCK)), Vector3(0.004, 0.03, 0.03), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(-0.026, 0.02, -0.03)), Vector3(0.008, 0.03, 0.03), 2.0)


## Where a cannon's bore runs above the hand (m) and how far its breech reaches back behind the hand (over the shoulder).
const CN_BORE := 0.13
const CN_BREECH := 0.38


static func cn_len(design: String) -> float:
	return float((WeaponDesigns.DESIGNS["cannon"] as Dictionary).get(design, {}).get("len", 1.05))


## The muzzle's mouth in the cannon's frame.
static func cn_muzzle(design: String) -> Vector3:
	return Vector3(0, CN_BORE, CN_BREECH - cn_len(design))


## Hand cannons: a fat barrel along the top running back over the shoulder, a pistol grip under it for the right hand
## and a front grip for the left, a wooden pad where it rests on the shoulder, reinforcing rings and a swelled muzzle;
## the dragon cannon's mouth is a dragon's jaws.
static func cannon(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := WeaponDesigns._mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "planks")
	var wood := PSXMat.lit("planks_dark", WeaponDesigns._c(p, "wood", Color(0.5, 0.32, 0.2)))
	var fit: Material = m["fit"]
	var body := PSXMat.lit("metal", WeaponDesigns._c(p, "barrel", Color(1.05, 0.74, 0.4)) * (WeaponDesigns.TIER_BLADE[tier] if tier >= 5 else Color.WHITE))
	var along := Basis(Vector3.RIGHT, -PI * 0.5)
	var ln := WeaponDesigns._f(p, "len", 1.05)
	var r := WeaponDesigns._f(p, "r", 0.075)
	var y := CN_BORE
	var z0 := CN_BREECH
	var mz := z0 - ln
	# the barrel, thick at the breech, the muzzle swelled and open
	mb.add_cylinder(body, Transform3D(along, Vector3(0, y, z0)), r * 1.15, r, ln * 0.85, 8, 0.6, Color.WHITE, false, true)
	mb.add_cylinder(body, Transform3D(along, Vector3(0, y, z0 - ln * 0.85)), r, r * 1.3, ln * 0.15, 8, 0.6, Color.WHITE, false)
	mb.add_cylinder(PSXMat.flat(Color(0.06, 0.05, 0.05)), Transform3D(along, Vector3(0, y, mz + 0.03)), r * 0.7, r * 0.7, 0.02, 8, 2.0)
	for k in [0.12, 0.42, 0.7]:
		mb.add_cylinder(fit, Transform3D(along, Vector3(0, y, z0 - ln * k)), r * 1.2, r * 1.2, 0.035, 8, 2.0)
	# the cascabel knob behind the breech, the touch-hole, a sight
	mb.add_cylinder(body, Transform3D(along, Vector3(0, y, z0 + 0.07)), r * 0.35, r * 0.6, 0.07, 6, 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, y + r * 1.1, z0 - 0.08)), Vector3(0.02, 0.02, 0.03), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, y + r * 1.3, mz + 0.08)), Vector3(0.008, 0.025, 0.012), 2.0)
	# the shoulder pad under the breech, the pistol grip under the hand, the front grip ahead of it
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, y - r - 0.02, z0 - 0.14)), Vector3(0.07, 0.05, 0.26), 2.0)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, y - r - 0.01, -0.02)), Vector3(0.05, 0.04, 0.2), 2.0)
	mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, -0.01, 0.01)), Vector3(0.042, 0.13, 0.05), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0.035, -0.05)), Vector3(0.012, 0.012, 0.08), 2.0)
	mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, y - r - 0.06, -0.3)), Vector3(0.038, 0.12, 0.045), 2.0)
	if bool(p.get("dragon", false)):
		var head := Vector3(0, y, mz)
		mb.add_box(fit, Transform3D(Basis(), head + Vector3(0, r * 0.9, -0.05)), Vector3(r * 1.6, r * 0.7, 0.14), 2.0)
		mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, -0.4), head + Vector3(0, -r * 0.9, -0.06)), Vector3(r * 1.4, r * 0.5, 0.14), 2.0)
		for s in [-1.0, 1.0]:
			mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, 0.5), head + Vector3(s * r * 0.6, r * 1.4, 0.02)), Vector3(0.02, 0.08, 0.02), 2.0)
			mb.add_box(PSXMat.glow(Color(1.0, 0.25, 0.1), 2.5), Transform3D(Basis(), head + Vector3(s * r * 0.75, r * 1.1, -0.04)), Vector3(0.012, 0.016, 0.016), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0.0, y + r * 1.15, z0 - ln * 0.42)), Vector3(0.03, 0.02, 0.03), 2.0)


## A slingshot's fork: its prong tips (the band's ends) this far up out of the fist and out to each side.
const SL_TIP := 0.17
const SL_W := 0.05


static func sl_w(design: String) -> float:
	return float((WeaponDesigns.DESIGNS["slingshot"] as Dictionary).get(design, {}).get("w", SL_W))


## Slingshots: a handle in the fist (along +Z), the fork's two prongs up out of the top of it to the band's ends, a
## leather pouch hanging between them (the drawn band is GunMoves.sling_band's); the beetle slingshot wears a horn.
static func slingshot(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := WeaponDesigns._mats(p, tier, Color(1.0, 0.78, 0.4), Color(0.4, 0.28, 0.18), "leather")
	var wood := PSXMat.lit(str(p.get("tex", "planks")), WeaponDesigns._c(p, "wood", Color(0.62, 0.44, 0.26)))
	var fit: Material = m["fit"]
	var w := WeaponDesigns._f(p, "w", SL_W)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0, 0.03)), Vector3(0.03, 0.03, 0.17), 2.0)
	mb.add_box(m["grip"], Transform3D(Basis(), Vector3(0, 0, 0.02)), Vector3(0.034, 0.034, 0.1), 2.0)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0, -0.065)), Vector3(0.04, 0.032, 0.04), 2.0)
	var base := Vector3(0, 0, -0.07)
	for s in [-1.0, 1.0]:
		var end := Vector3(s * w, 0, -SL_TIP)
		var d := end - base
		mb.add_box(wood, Transform3D(Basis(Vector3.UP, -atan2(d.x, -d.z)), (base + end) * 0.5), Vector3(0.022, 0.024, d.length() + 0.02), 2.0)
		mb.add_box(fit, Transform3D(Basis(), end + Vector3(0, 0, -0.008)), Vector3(0.026, 0.028, 0.018), 2.0)
	# the band slack between the tips, the pouch in the middle of it
	mb.add_box(PSXMat.lit("leather", WeaponDesigns._c(p, "band", Color(0.35, 0.22, 0.14))), Transform3D(Basis(), Vector3(0, 0.03, -SL_TIP + 0.01)), Vector3(w * 2.0, 0.008, 0.012), 2.0)
	mb.add_box(PSXMat.lit("leather", Color(0.45, 0.3, 0.18)), Transform3D(Basis(), Vector3(0, 0.05, -SL_TIP + 0.01)), Vector3(0.04, 0.02, 0.03), 2.0)
	if bool(p.get("horn", false)):
		# the beetle's: a horn swept up off the fork's crotch and a shell plate on the handle
		mb.add_cone(fit, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.015, -0.08)), 0.02, 0.2, 5)
		mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.02, 0.0)), Vector3(0.04, 0.02, 0.12), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0, -0.02, -0.065)), Vector3(0.02, 0.02, 0.02), 2.0)

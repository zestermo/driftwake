class_name WeaponDesigns
extends RefCounted
## Every look a cutlass, katana, axe or pistol comes in, built from a handful of
## numbers (blade length and curve, guard, head, barrels, colours), and its
## tier worn on it: blued fittings at rare, a purple gem at epic, gold at
## legendary, a crimson blade at ultra, an obsidian one at supreme.
##
## A weapon's model is "<kind>:<design>:<tier>" (ItemData.model()), the same
## string the mesh carries (co-op rebuilds it from that). Each design is an
## item of its own (id DESIGNS[kind][design]["id"]: ItemDB makes them from
## the kind's base item); tiers come on top (ItemDB.tiered).

const BASE_ITEM := {"cutlass": "cutlass", "katana": "katana", "axe": "boarding_axe", "pistol": "pistol"}

## design -> {id, name, desc, dmg (x the base item's), worth (x its value), build numbers...}
const DESIGNS := {
	"cutlass": {
		"sabre": {"id": "naval_sabre", "name": "Naval Sabre", "desc": "A long, slim officer's blade with a steel stirrup guard. Reach over weight.",
			"dmg": 1.0, "worth": 1.5, "len": 0.66, "tip": 0.3, "w": 0.055, "curve": 0.16, "guard": "stirrup",
			"fit": Color(0.8, 0.83, 0.88), "grip": Color(0.92, 0.88, 0.78), "grip_tex": "leather", "pommel": "cap"},
		"scimitar": {"id": "scimitar", "name": "Scimitar", "desc": "A broad blade sweeping into a deep curve. Cuts like a wave breaking.",
			"dmg": 1.05, "worth": 1.6, "len": 0.42, "tip": 0.36, "w": 0.075, "taper": 1.35, "curve": 0.55, "guard": "cross", "guard_size": 0.15,
			"fit": Color(1.0, 0.78, 0.4), "grip": Color(0.62, 0.12, 0.1), "grip_tex": "fabric", "pommel": "ball"},
		"broadsword": {"id": "broadsword", "name": "Broadsword", "desc": "Straight, wide and heavy, with a basket of iron round the hand.",
			"dmg": 1.12, "worth": 1.8, "len": 0.74, "tip": 0.1, "w": 0.075, "curve": 0.0, "guard": "basket",
			"fit": Color(0.55, 0.55, 0.58), "grip": Color(0.3, 0.2, 0.12), "grip_tex": "leather", "pommel": "ball"},
		"rapier": {"id": "rapier", "name": "Rapier", "desc": "A needle of a sword behind a steel cup. Quick to the point, slow to break.",
			"dmg": 0.95, "worth": 1.7, "len": 0.88, "tip": 0.08, "w": 0.024, "th": 0.016, "curve": 0.0, "guard": "cup",
			"fit": Color(0.82, 0.84, 0.9), "grip": Color(0.18, 0.14, 0.12), "grip_tex": "leather", "pommel": "ball"},
		"falchion": {"id": "falchion", "name": "Falchion", "desc": "Short and wide with a clipped point. Chops through rope, oars and pirates.",
			"dmg": 1.1, "worth": 1.4, "len": 0.44, "tip": 0.14, "w": 0.095, "taper": 1.15, "curve": 0.1, "clip": true, "guard": "cross", "guard_size": 0.18,
			"fit": Color(0.5, 0.48, 0.45), "grip": Color(0.35, 0.22, 0.12), "grip_tex": "planks_dark", "pommel": "cap"},
		"hanger": {"id": "hunting_hanger", "name": "Hunting Hanger", "desc": "A short hunting sword with a shell guard and a stag-horn grip.",
			"dmg": 0.95, "worth": 1.2, "len": 0.36, "tip": 0.16, "w": 0.06, "curve": 0.18, "guard": "shell",
			"fit": Color(1.0, 0.78, 0.4), "grip": Color(0.86, 0.8, 0.66), "grip_tex": "bark", "pommel": "cap"},
		"dao": {"id": "dao", "name": "Dao", "desc": "A broad single-edged sabre from far-off waters, a red tassel at the ring.",
			"dmg": 1.05, "worth": 1.6, "len": 0.46, "tip": 0.24, "w": 0.07, "taper": 1.3, "curve": 0.3, "guard": "disc",
			"fit": Color(1.0, 0.78, 0.4), "grip": Color(0.14, 0.12, 0.12), "grip_tex": "fabric", "pommel": "ring", "tassel": Color(0.8, 0.12, 0.1)},
		# (unique: only the brood queen's hoard has it)
		"chitin": {"id": "queens_fang", "name": "Queen's Fang", "desc": "A blade of the brood queen's own chitin, its edge still weeping venom. Every cut poisons.",
			"dmg": 1.15, "worth": 3.0, "len": 0.5, "tip": 0.34, "w": 0.08, "taper": 1.25, "curve": 0.45, "guard": "cross", "guard_size": 0.17,
			"blade": Color(0.45, 0.32, 0.55), "venom": Color(0.5, 1.0, 0.25), "fit": Color(0.3, 0.2, 0.35), "grip": Color(0.2, 0.32, 0.18),
			"grip_tex": "leather", "pommel": "ball", "unique": true, "poison": 5.0},
	},
	"katana": {
		"uchigatana": {"id": "uchigatana", "name": "Uchigatana", "desc": "A fighting katana in red cord, a square guard edged in brass.",
			"dmg": 1.03, "worth": 1.4, "tsuba": "square", "wrap": Color(0.62, 0.1, 0.1), "fit": Color(1.0, 0.78, 0.4)},
		"nodachi": {"id": "nodachi", "name": "Nodachi", "desc": "A field sword half again as long as a katana. Reach that ends arguments.",
			"dmg": 1.12, "worth": 1.8, "len": 1.08, "curve": 0.42, "wrap": Color(0.16, 0.13, 0.17), "fit": Color(0.45, 0.42, 0.42)},
		"tachi": {"id": "tachi", "name": "Tachi", "desc": "An old court blade with a deep curve and a flowered guard, wrapped in white.",
			"dmg": 1.05, "worth": 1.6, "curve": 0.5, "tsuba": "flower", "wrap": Color(0.9, 0.88, 0.82), "fit": Color(1.0, 0.78, 0.4)},
		# (dark blued steel, not black: a black blade is Supreme's alone)
		"kuro": {"id": "kuro_katana", "name": "Kuro Katana", "desc": "Dark blued steel with a pale edge, in black cord. It drinks the light.",
			"dmg": 1.08, "worth": 1.9, "blade": Color(0.42, 0.5, 0.68), "wrap": Color(0.08, 0.08, 0.09), "fit": Color(0.35, 0.33, 0.35)},
		"wakizashi": {"id": "wakizashi", "name": "Wakizashi", "desc": "The short companion blade. Quick in close quarters below decks.",
			"dmg": 0.95, "worth": 1.0, "len": 0.58, "curve": 0.22, "wrap": Color(0.18, 0.22, 0.4), "fit": Color(0.45, 0.42, 0.42)},
		"ninjato": {"id": "ninjato", "name": "Ninjato", "desc": "A straight blade with a square guard. Made for the dark, not for show.",
			"dmg": 1.0, "worth": 1.3, "len": 0.74, "curve": 0.0, "tsuba": "square", "wrap": Color(0.1, 0.1, 0.11), "fit": Color(0.3, 0.3, 0.3)},
	},
	"axe": {
		"hatchet": {"id": "hatchet", "name": "Hatchet", "desc": "A carpenter's axe. Short, light, and it's seen more pirates than planks.",
			"dmg": 0.92, "worth": 0.6, "haft": 0.58, "head": "hatchet", "wood": Color(0.78, 0.6, 0.4)},
		"bearded": {"id": "bearded_axe", "name": "Bearded Axe", "desc": "Its long beard hooks a shield or a rail and pulls.",
			"dmg": 1.04, "worth": 1.2, "head": "bearded", "wood": Color(0.55, 0.38, 0.24)},
		"double": {"id": "double_axe", "name": "Double Axe", "desc": "Two heads, back to back. Every swing is a forehand.",
			"dmg": 1.1, "worth": 1.5, "head": "double", "wood": Color(0.45, 0.3, 0.2), "bands": true},
		"cleaver": {"id": "ships_cleaver", "name": "Ship's Cleaver", "desc": "The cook's, once. A slab of iron on a short handle.",
			"dmg": 1.0, "worth": 0.9, "haft": 0.62, "head": "cleaver", "wood": Color(0.3, 0.22, 0.16)},
		"war": {"id": "war_axe", "name": "War Axe", "desc": "A crescent blade, a spike behind and a spike ahead, on a banded haft.",
			"dmg": 1.12, "worth": 1.8, "haft": 1.0, "head": "war", "wood": Color(0.35, 0.24, 0.16), "bands": true},
	},
	"pistol": {
		"duelling": {"id": "duelling_pistol", "name": "Duelling Pistol", "desc": "A long, true barrel and a silver lock. Made for one shot that counts.",
			"dmg": 1.05, "worth": 1.6, "barrel": 0.46, "r": 0.017, "sides": 8, "wood": Color(0.4, 0.24, 0.14), "fit": Color(0.85, 0.87, 0.9)},
		"blunderbuss": {"id": "blunderbuss_pistol", "name": "Blunderbuss Pistol", "desc": "A brass bell of a muzzle. Aiming is a suggestion.",
			"dmg": 1.12, "worth": 1.5, "barrel": 0.34, "r": 0.024, "flare": 0.055, "brass_barrel": true, "wood": Color(0.62, 0.4, 0.22)},
		"double": {"id": "double_pistol", "name": "Double-Barrel Pistol", "desc": "Two barrels side by side. Twice the argument.",
			"dmg": 1.08, "worth": 1.7, "barrel": 0.34, "r": 0.017, "barrels": 2, "wood": Color(0.5, 0.3, 0.18)},
		"pepperbox": {"id": "pepperbox", "name": "Pepperbox", "desc": "A cluster of short barrels turning round the lock.",
			"dmg": 1.0, "worth": 1.6, "barrel": 0.2, "r": 0.011, "barrels": 5, "wood": Color(0.3, 0.2, 0.14)},
		"dragon": {"id": "dragon_pistol", "name": "Dragon Pistol", "desc": "Brass from lock to muzzle, the muzzle a dragon's open jaws.",
			"dmg": 1.1, "worth": 2.0, "barrel": 0.32, "r": 0.022, "brass_barrel": true, "dragon": true, "wood": Color(0.25, 0.14, 0.1), "fit": Color(1.15, 0.9, 0.4)},
	},
}

## Each tier's fittings (guards, bands, locks) and gem; ultra and supreme
## colour the blade itself.
const TIER_FIT := [Color(), Color(), Color(0.55, 0.72, 1.15), Color(0.42, 0.38, 0.5), Color(1.35, 1.05, 0.35),
	Color(0.32, 0.12, 0.12), Color(1.35, 1.35, 1.42)]
const TIER_GEM := [Color(), Color(), Color(), Color(0.7, 0.3, 1.0), Color(1.0, 0.82, 0.25), Color(1.0, 0.18, 0.15), Color(0.85, 0.75, 1.0)]
const TIER_BLADE := [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color(1.25, 0.42, 0.4), Color(0.17, 0.16, 0.21)]

static var _icons: Dictionary = {}


## The designs anyone might carry, find or buy (unique ones left out).
static func designs_of(kind: String) -> Array:
	var d: Dictionary = DESIGNS.get(kind, {})
	return d.keys().filter(func(k): return not bool((d[k] as Dictionary).get("unique", false)))


## A design of `kind` picked at random (the base included: key "").
static func random_design(kind: String, rng: RandomNumberGenerator) -> String:
	var all: Array = [""] + designs_of(kind)
	return str(all[rng.randi() % all.size()])


## Every design's item id (to drop, stock or roll loot from), the base's too.
static func item_ids(kind: String) -> Array:
	var out: Array = [str(BASE_ITEM[kind])]
	for d in designs_of(kind):
		out.append(str(DESIGNS[kind][d]["id"]))
	return out


## Where an axe's head sits along its haft (z in the weapon's frame).
static func axe_head_z(model: String) -> float:
	var p: Dictionary = (DESIGNS["axe"] as Dictionary).get(model.get_slice(":", 1), {})
	return -(_f(p, "haft", 0.9) - 0.22)


## A katana's scabbard in the blade's own frame: the same chain of segments
## as its blade (length and curve), a little roomier, past the point.
static func saya(model: String) -> ArrayMesh:
	var p: Dictionary = (DESIGNS["katana"] as Dictionary).get(model.get_slice(":", 1), {})
	var lacquer := PSXMat.lit("leather", Color(0.13, 0.11, 0.12))
	var horn := PSXMat.lit("metal", Color(0.85, 0.72, 0.45))
	var cord := PSXMat.lit("fabric", Color(0.7, 0.14, 0.12))
	var mb := MeshBuilder.new()
	var curve := _f(p, "curve", 0.32)
	var segs := 5
	var seg := _f(p, "len", 0.82) / segs
	var h := _f(p, "w", 0.033) + 0.018
	var at := Vector3(0, 0, -0.06)
	var b := Basis()
	for i in range(segs):
		b = Basis(Vector3.RIGHT, curve * pow((i + 0.5) / segs, 1.6))
		mb.add_box(lacquer, Transform3D(b, at + b * Vector3(0, 0, -seg * 0.5)), Vector3(0.03, h - 0.002 * i, seg + 0.012), 2.0)
		at += b * Vector3(0, 0, -seg)
	mb.add_box(lacquer, Transform3D(b, at + b * Vector3(0, 0, -0.06)), Vector3(0.028, h - 0.012, 0.12), 2.0)
	mb.add_box(horn, Transform3D(b, at + b * Vector3(0, 0, -0.13)), Vector3(0.032, h - 0.008, 0.03), 2.0)
	mb.add_box(horn, Transform3D(Basis(), Vector3(0, 0, -0.052)), Vector3(0.036, h + 0.005, 0.024), 2.0)
	mb.add_box(cord, Transform3D(Basis(), Vector3(0, 0, -0.13)), Vector3(0.036, h + 0.005, 0.02), 2.0)
	return mb.commit()


## Any weapon's item id: a kind, then one of its designs.
static func random_item(rng: RandomNumberGenerator) -> String:
	var ids := item_ids(str(BASE_ITEM.keys()[rng.randi() % BASE_ITEM.size()]))
	return str(ids[rng.randi() % ids.size()])


## (ItemDB, loading) the design items, made from each kind's base item.
static func make_items(items: Dictionary) -> void:
	for kind in DESIGNS.keys():
		var base: ItemData = items[BASE_ITEM[kind]]
		base.icon = icon(base.model())
		for d in (DESIGNS[kind] as Dictionary).keys():
			var spec: Dictionary = DESIGNS[kind][d]
			var it := base.duplicate() as ItemData
			it.id = str(spec["id"])
			it.display_name = str(spec["name"])
			it.description = str(spec["desc"])
			it.design = d
			it.damage_mult = base.damage_mult * float(spec["dmg"])
			it.value = maxi(int(round(base.value * float(spec["worth"]))), 1)
			it.poison = float(spec.get("poison", 0.0))
			it.icon = icon(it.model())
			items[it.id] = it


# --------------------------------------------------------------------------
# Building one
# --------------------------------------------------------------------------
static func _f(p: Dictionary, key: String, def: float) -> float:
	return float(p.get(key, def))


static func _c(p: Dictionary, key: String, def: Color) -> Color:
	return p.get(key, def)


## Materials for a design at a tier: blade, edge, fittings, grip, gem (or null).
static func _mats(p: Dictionary, tier: int, fit_def: Color, grip_def: Color, grip_tex: String) -> Dictionary:
	var blade_tint: Color = _c(p, "blade", Color.WHITE) * TIER_BLADE[tier] if tier >= 5 else _c(p, "blade", Color.WHITE)
	var fit: Color = TIER_FIT[tier] if tier >= 2 else _c(p, "fit", fit_def)
	var edge: Material
	if tier >= 5:
		edge = PSXMat.glow(TIER_GEM[tier], 2.5)
	elif p.has("venom"):
		edge = PSXMat.glow(p["venom"], 1.8)
	else:
		edge = PSXMat.lit("metal", blade_tint.lightened(0.35) * 1.15)
	return {
		"blade": PSXMat.lit("metal", blade_tint),
		"edge": edge,
		"fit": PSXMat.lit("metal", fit),
		"grip": PSXMat.lit(str(p.get("grip_tex", grip_tex)), _c(p, "grip", grip_def)),
		"gem": PSXMat.glow(TIER_GEM[tier], 2.0) if tier >= 3 else null,
	}


## The mesh for a model string ("<kind>:<design>:<tier>", or just "<kind>").
static func build(model: String) -> ArrayMesh:
	var parts := model.split(":")
	var kind := parts[0]
	var design := parts[1] if parts.size() > 1 else ""
	var tier := clampi(int(parts[2]), 0, 6) if parts.size() > 2 else 0
	var p: Dictionary = (DESIGNS.get(kind, {}) as Dictionary).get(design, {})
	var mb := MeshBuilder.new()
	match kind:
		"katana":
			_katana(mb, p, tier)
		"axe":
			_axe(mb, p, tier)
		"pistol":
			_pistol(mb, p, tier)
		_:
			_sword(mb, p, tier)
	var m := mb.commit()
	m.set_meta("model", model)
	return m


## A blade as a chain of segments from `start` along -Z, curving toward +Y
## (the spine) as it goes, its edge strip along -Y. Returns the tip point.
static func _blade(mb: MeshBuilder, m: Dictionary, start: Vector3, length: float, w: float, th: float, curve: float,
		taper: float, segs: int, clip: bool) -> Vector3:
	var at := start
	var seg := length / segs
	var a := 0.0
	for i in range(segs):
		var k := (i + 0.5) / segs
		a = curve * pow(k, 1.6)
		var b := Basis(Vector3.RIGHT, a)
		var dir := b * Vector3(0, 0, -1)
		var bw := w * lerpf(1.0, taper, k)
		var c := at + dir * seg * 0.5
		mb.add_box(m["blade"], Transform3D(b, c), Vector3(th, bw, seg + 0.012), 2.0)
		mb.add_box(m["edge"], Transform3D(b, c + b * Vector3(0, -bw * 0.5, 0)), Vector3(th * 0.6, bw * 0.16, seg + 0.012), 2.0)
		at += dir * seg
	# the point: two narrowing steps on along the same line, the edge sweeping
	# up to the spine (a clipped point: the spine coming down to the edge)
	var b := Basis(Vector3.RIGHT, a)
	var dir := b * Vector3(0, 0, -1)
	var side := -1.0 if clip else 1.0
	var tw := w * taper
	for step in [[0.55, 0.05], [0.25, 0.04]]:
		var sw := tw * float(step[0])
		var sl := float(step[1])
		var c := at + dir * sl * 0.5 + b * Vector3(0, side * (tw - sw) * 0.5, 0)
		mb.add_box(m["blade"], Transform3D(b, c), Vector3(th, sw, sl + 0.006), 2.0)
		at += dir * sl
	return at


## Cutlasses and their kin: one-handed, grip at the origin, knuckles toward -Y.
static func _sword(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "planks_dark")
	var w := _f(p, "w", 0.07)
	var th := _f(p, "th", 0.025)
	_blade(mb, m, Vector3(0, 0, -0.09), _f(p, "len", 0.56) + _f(p, "tip", 0.28), w, th, _f(p, "curve", 0.2),
		_f(p, "taper", 1.0), 4, bool(p.get("clip", false)))
	var fit: Material = m["fit"]
	match str(p.get("guard", "knuckle")):
		"cross":
			var gs := _f(p, "guard_size", 0.2)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.08)), Vector3(0.035, gs, 0.035), 2.0)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(), Vector3(0, s * gs * 0.5, -0.09)), Vector3(0.045, 0.03, 0.05), 2.0)
		"stirrup":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.01, -0.08)), Vector3(0.03, 0.13, 0.03), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.075, 0.03)), Vector3(0.02, 0.02, 0.2), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.04, 0.13)), Vector3(0.02, 0.07, 0.02), 2.0)
		"cup":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.12)), 0.03, 0.065, 0.05, 8, 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.06)), Vector3(0.02, 0.2, 0.02), 2.0)
			mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.07, 0.0)), Vector3(0.018, 0.018, 0.16), 2.0)
		"shell":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.02, -0.1)), 0.02, 0.045, 0.025, 7, 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.08)), Vector3(0.03, 0.11, 0.03), 2.0)
		"basket":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.085)), Vector3(0.1, 0.15, 0.02), 2.0)
			for x in [-0.045, 0.045]:
				for y in [-0.06, 0.06]:
					mb.add_box(fit, Transform3D(Basis(), Vector3(x, y, 0.02)), Vector3(0.012, 0.012, 0.2), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.06, 0.12)), Vector3(0.1, 0.012, 0.012), 2.0)
		"disc":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.1)), 0.05, 0.05, 0.015, 8, 2.0)
		_:
			# the knuckle bow
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.08)), Vector3(0.05, 0.16, 0.05), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.07, 0.03)), Vector3(0.04, 0.03, 0.2), 2.0)
	mb.add_box(m["grip"], Transform3D(Basis(), Vector3(0, 0, 0.04)), Vector3(0.042, 0.048, 0.17), 2.0)
	var end := Vector3(0, 0, 0.13)
	match str(p.get("pommel", "cap")):
		"ball":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), end - Vector3(0, 0, 0.0)), 0.03, 0.03, 0.045, 6, 2.0)
		"ring":
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(), end + Vector3(0, s * 0.03, 0.03)), Vector3(0.012, 0.012, 0.07), 2.0)
			mb.add_box(fit, Transform3D(Basis(), end + Vector3(0, 0, 0.065)), Vector3(0.012, 0.07, 0.012), 2.0)
			if p.has("tassel"):
				mb.add_box(PSXMat.lit("fabric", p["tassel"]), Transform3D(Basis(), end + Vector3(0, -0.06, 0.07)), Vector3(0.02, 0.1, 0.02), 2.0)
		_:
			mb.add_box(fit, Transform3D(Basis(), end), Vector3(0.05, 0.055, 0.025), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0.0, 0, -0.08)), Vector3(0.055, 0.03, 0.03), 2.0)


## Katanas: the right hand at the origin behind the guard, a long wrapped
## hilt back to the pommel (the left hand at +0.17), the blade along -Z.
static func _katana(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "fabric")
	var wrap := PSXMat.lit("fabric", _c(p, "wrap", Color(0.16, 0.13, 0.17)))
	var fit: Material = m["fit"]
	var iron: Material = PSXMat.lit("metal", Color(0.32, 0.3, 0.3)) if tier < 2 else fit
	mb.add_box(wrap, Transform3D(Basis(), Vector3(0, 0, 0.115)), Vector3(0.034, 0.04, 0.27), 2.0)
	# the cord's diamonds down the hilt
	for z in [0.03, 0.09, 0.15, 0.21]:
		mb.add_box(fit, Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0, 0, z)), Vector3(0.024, 0.024, 0.012), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, 0.255)), Vector3(0.038, 0.044, 0.02), 2.0)
	match str(p.get("tsuba", "round")):
		"square":
			mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0, -0.03)), Vector3(0.075, 0.08, 0.012), 2.0)
		"flower":
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.024)), 0.04, 0.04, 0.012, 8, 2.0)
			for k in range(4):
				var b := Basis(Vector3.BACK, PI * 0.5 * k + PI * 0.25)
				mb.add_box(fit, Transform3D(b, Vector3(0, 0, -0.03) + b * Vector3(0, 0.045, 0)), Vector3(0.022, 0.022, 0.012), 2.0)
		_:
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.024)), 0.046, 0.046, 0.012, 8, 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.05)), Vector3(0.016, 0.04, 0.025), 2.0)
	_blade(mb, m, Vector3(0, 0, -0.06), _f(p, "len", 0.82), _f(p, "w", 0.033), 0.012, _f(p, "curve", 0.32), 0.92, 5, false)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0, 0, 0.268)), Vector3(0.02, 0.024, 0.012), 2.0)


## Axes: the haft back past the hand, the head out toward -Y (the knuckle
## side, as a sword's edge) near the far end.
static func _axe(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "planks_dark")
	var wood := PSXMat.lit("planks_dark", _c(p, "wood", Color(1, 1, 1)))
	var steel: Material = m["blade"]
	var edge: Material = m["edge"]
	var fit: Material = m["fit"]
	var haft := _f(p, "haft", 0.9)
	var hz := -(haft - 0.22)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0, 0.13 - haft * 0.5)), Vector3(0.05, 0.05, haft), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, 0.1)), Vector3(0.06, 0.06, 0.05), 2.0)
	if bool(p.get("bands", false)):
		for z in [hz * 0.3, hz * 0.6]:
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, z)), Vector3(0.058, 0.058, 0.025), 2.0)
	# The head is laid out with its bit toward +y and mirrored to -y as it's
	# placed: the bit leads the swing on the knuckle side, like a sword's edge.
	var hb := func(mat: Material, ang: float, pos: Vector3, size: Vector3) -> void:
		mb.add_box(mat, Transform3D(Basis(Vector3.RIGHT, -ang), Vector3(pos.x, -pos.y, pos.z)), size, 2.0)
	match str(p.get("head", "boarding")):
		"hatchet":
			hb.call(steel, 0.0, Vector3(0, 0.07, hz), Vector3(0.035, 0.14, 0.1))
			hb.call(edge, 0.0, Vector3(0, 0.145, hz), Vector3(0.025, 0.02, 0.13))
		"bearded":
			hb.call(steel, 0.0, Vector3(0, 0.07, hz), Vector3(0.04, 0.14, 0.11))
			hb.call(steel, 0.45, Vector3(0, 0.15, hz + 0.06), Vector3(0.035, 0.1, 0.22))
			hb.call(edge, 0.2, Vector3(0, 0.205, hz + 0.04), Vector3(0.025, 0.02, 0.28))
		"double":
			hb.call(fit, 0.0, Vector3(0, 0, hz), Vector3(0.06, 0.07, 0.09))
			for s in [-1.0, 1.0]:
				hb.call(steel, 0.0, Vector3(0, s * 0.1, hz), Vector3(0.035, 0.13, 0.12))
				hb.call(steel, 0.0, Vector3(0, s * 0.16, hz), Vector3(0.03, 0.06, 0.24))
				hb.call(edge, 0.0, Vector3(0, s * 0.195, hz), Vector3(0.022, 0.02, 0.26))
		"cleaver":
			hb.call(steel, 0.0, Vector3(0, 0.1, hz - 0.06), Vector3(0.03, 0.22, 0.3))
			hb.call(edge, 0.0, Vector3(0, 0.215, hz - 0.06), Vector3(0.02, 0.02, 0.3))
		"war":
			hb.call(steel, 0.0, Vector3(0, 0.07, hz), Vector3(0.04, 0.13, 0.1))
			for s in [-1.0, 1.0]:
				hb.call(steel, s * 0.55, Vector3(0, 0.17, hz + s * 0.07), Vector3(0.035, 0.08, 0.17))
				hb.call(edge, s * 0.55, Vector3(0, 0.2, hz + s * 0.085), Vector3(0.025, 0.02, 0.17))
			hb.call(steel, 0.3, Vector3(0, -0.09, hz + 0.02), Vector3(0.03, 0.16, 0.035))
			hb.call(steel, 0.0, Vector3(0, 0, hz - 0.12), Vector3(0.03, 0.03, 0.14))
		_:
			hb.call(steel, 0.0, Vector3(0, 0.1, hz), Vector3(0.04, 0.26, 0.16))
			hb.call(steel, 0.25, Vector3(0, 0.22, hz - 0.06), Vector3(0.035, 0.14, 0.22))
			hb.call(edge, 0.25, Vector3(0, 0.29, hz - 0.08), Vector3(0.025, 0.02, 0.22))
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0, 0, hz)), Vector3(0.062, 0.035, 0.035), 2.0)


## Pistols: barrel(s) forward above the hand, a curved grip below.
static func _pistol(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "planks")
	var wood := PSXMat.lit("planks", _c(p, "wood", Color(0.75, 0.5, 0.3)))
	var fit: Material = m["fit"]
	var steel: Material = fit if bool(p.get("brass_barrel", false)) else m["blade"]
	var bl := _f(p, "barrel", 0.36)
	var r := _f(p, "r", 0.022)
	var n := int(p.get("barrels", 1))
	var sides := int(p.get("sides", 6))
	var along := Basis(Vector3.RIGHT, -PI * 0.5)
	var muzzle := Vector3(0, 0.06, -0.05 - bl)
	if n == 1:
		var flare := _f(p, "flare", 0.0)
		if flare > 0.0:
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, 0.06, -0.05)), r, r * 1.1, bl * 0.72, sides, 2.0)
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, 0.06, -0.05 - bl * 0.72)), r * 1.1, flare, bl * 0.28, sides, 2.0)
		else:
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, 0.06, -0.05)), r, r * 0.9, bl, sides, 2.0)
		mb.add_cylinder(fit, Transform3D(along, muzzle + Vector3(0, 0, 0.03)), r * 1.25, r * 1.25, 0.02, sides, 2.0)
	elif n == 2:
		for x in [-r, r]:
			mb.add_cylinder(steel, Transform3D(along, Vector3(x, 0.06, -0.05)), r, r, bl, sides, 2.0)
		mb.add_box(fit, Transform3D(Basis(), muzzle + Vector3(0, 0, 0.03)), Vector3(r * 4.4, r * 2.4, 0.02), 2.0)
	else:
		mb.add_cylinder(fit, Transform3D(along, Vector3(0, 0.06, -0.03)), r * 3.0, r * 3.0, 0.05, 8, 2.0)
		for k in range(n):
			var a := TAU * k / n
			mb.add_cylinder(steel, Transform3D(along, Vector3(cos(a) * r * 2.0, 0.06 + sin(a) * r * 2.0, -0.05)), r, r, bl, 6, 2.0)
	if bool(p.get("dragon", false)):
		var head := muzzle + Vector3(0, 0, -0.01)
		mb.add_box(fit, Transform3D(Basis(), head + Vector3(0, 0.012, -0.02)), Vector3(0.055, 0.035, 0.07), 2.0)
		mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, -0.35), head + Vector3(0, -0.02, -0.03)), Vector3(0.05, 0.015, 0.07), 2.0)
		for s in [-1.0, 1.0]:
			mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, 0.5), head + Vector3(s * 0.018, 0.04, 0.015)), Vector3(0.012, 0.04, 0.012), 2.0)
			mb.add_box(PSXMat.glow(Color(1.0, 0.2, 0.1), 2.5), Transform3D(Basis(), head + Vector3(s * 0.029, 0.02, -0.025)), Vector3(0.006, 0.01, 0.01), 2.0)
	# stock, grip and lock
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.05, -0.1)), Vector3(0.045 + (0.02 if n == 2 else 0.0), 0.05, 0.22), 2.0)
	mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.03, 0.03)), Vector3(0.045, 0.16, 0.06), 2.0)
	mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.1, 0.07)), Vector3(0.055, 0.04, 0.07), 2.0)
	mb.add_box(m["blade"], Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.1, 0.02)), Vector3(0.02, 0.05, 0.02), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0.0, -0.04)), Vector3(0.01, 0.04, 0.05), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.13, 0.085)), Vector3(0.03, 0.02, 0.03), 2.0)


# --------------------------------------------------------------------------
# Icons: the mesh itself, seen side on and laid corner to corner
# --------------------------------------------------------------------------
## Rough colours of the textures weapons use (icons are made headless too,
## where textures have no pixels to read).
const TEX_TONE := {"metal": Color(0.62, 0.63, 0.66), "planks_dark": Color(0.33, 0.23, 0.15), "planks": Color(0.56, 0.4, 0.25),
	"fabric": Color(0.75, 0.72, 0.68), "leather": Color(0.5, 0.36, 0.24), "bark": Color(0.45, 0.35, 0.25)}
const ICON := 24


static func icon(model: String) -> Texture2D:
	if _icons.has(model):
		return _icons[model]
	var mesh := build(model)
	var tris: Array = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var rot := Transform2D(-PI * 0.25, Vector2.ZERO)
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var col := _tone(mesh.surface_get_material(s))
		for i in range(0, verts.size() - 2, 3):
			var pts: Array = []
			for j in range(3):
				var v: Vector3 = verts[i + j]
				var q: Vector2 = rot * Vector2(-v.z, -v.y)
				pts.append(q)
				lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
				hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
			var nx := absf(norms[i].x)
			var shade := 0.55 + 0.45 * nx + 0.15 * norms[i].y
			tris.append([pts, col * shade, (verts[i].x + verts[i + 1].x + verts[i + 2].x) / 3.0])
	tris.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	var k := (ICON - 3.0) / maxf(span, 0.001)
	var off := Vector2(ICON, ICON) * 0.5 - (lo + hi) * 0.5 * k
	var img := Image.create(ICON, ICON, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for t in tris:
		var a: Vector2 = t[0][0] * k + off
		var b: Vector2 = t[0][1] * k + off
		var c: Vector2 = t[0][2] * k + off
		var col: Color = t[1]
		col.a = 1.0
		var x0 := clampi(int(floor(minf(a.x, minf(b.x, c.x)))), 0, ICON - 1)
		var x1 := clampi(int(ceil(maxf(a.x, maxf(b.x, c.x)))), 0, ICON - 1)
		var y0 := clampi(int(floor(minf(a.y, minf(b.y, c.y)))), 0, ICON - 1)
		var y1 := clampi(int(ceil(maxf(a.y, maxf(b.y, c.y)))), 0, ICON - 1)
		var any := false
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
					img.set_pixel(x, y, col)
					any = true
		# (thin parts - a rapier's blade - still get their pixel)
		if not any:
			var m := (a + b + c) / 3.0
			img.set_pixel(clampi(int(m.x), 0, ICON - 1), clampi(int(m.y), 0, ICON - 1), col)
	# a dark outline, like the painted icons
	var out := img.duplicate() as Image
	for y in range(ICON):
		for x in range(ICON):
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < ICON and n.y < ICON and img.get_pixel(n.x, n.y).a > 0.0:
					out.set_pixel(x, y, Color(0.08, 0.055, 0.04))
					break
	var tex := ImageTexture.create_from_image(out)
	_icons[model] = tex
	return tex


static func _tone(mat: Material) -> Color:
	var sm := mat as ShaderMaterial
	var tint: Color = sm.get_shader_parameter("albedo_color")
	var em = sm.get_shader_parameter("emission_color")
	if em != null and float(sm.get_shader_parameter("emission_energy")) > 0.0:
		return (em as Color).lightened(0.2)
	var tex = sm.get_shader_parameter("albedo_tex")
	var tone: Color = TEX_TONE.get((tex as Texture2D).resource_path.get_file().get_basename(), Color(0.6, 0.6, 0.6)) if tex else Color.WHITE
	return Color(tone.r * tint.r, tone.g * tint.g, tone.b * tint.b)

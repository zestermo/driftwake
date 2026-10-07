class_name ShipKit
extends RefCounted
## What the shipwright (Tackett's yard, Brinehollow) has done to our ship:
## refits bought with gold and her paint, colours, flag and figurehead. A
## plain Dictionary (GameManager.ship_kit, saved; the host's in co-op):
##   {"armour": bool, "guns": bool, "sails": bool, "rudder": bool,
##    "hull": i, "sail": i, "field": i, "emblem": i, "mark": i, "figure": i}
## Ship.apply_kit puts it on the hull.

## [id, name, what it does, gold]
const REFITS := [
	["armour", "Iron-strapped hull", "Iron straps on her planks: 40% more hull", 220],
	["guns", "Third pair of guns", "Two more swivel guns aft: three a side", 180],
	["sails", "Larger sail", "A bigger mainsail: 15% faster", 150],
	["rudder", "Balanced rudder", "She turns 30% sharper", 120],
]
const HULL_PAINT := [["Tarred", Color.WHITE], ["Pitch black", Color(0.38, 0.38, 0.42)], ["Oxblood", Color(1.35, 0.5, 0.42)],
	["Navy", Color(0.6, 0.8, 1.35)], ["Sea green", Color(0.65, 1.15, 0.8)], ["Whitewash", Color(1.9, 1.85, 1.7)]]
const SAILS := [["Canvas", Color(0.95, 0.92, 0.82)], ["Black", Color(0.24, 0.24, 0.27)], ["Crimson", Color(1.0, 0.32, 0.28)],
	["Navy", Color(0.35, 0.45, 0.85)], ["Sand", Color(1.0, 0.86, 0.55)]]
const FIELDS := [["Red", Color(0.7, 0.1, 0.08)], ["Black", Color(0.08, 0.08, 0.09)], ["Navy", Color(0.1, 0.16, 0.42)],
	["Green", Color(0.1, 0.38, 0.2)], ["Gold", Color(0.85, 0.65, 0.15)], ["White", Color(0.92, 0.9, 0.84)]]
const EMBLEMS := ["None", "Skull", "Crossed swords", "Anchor", "Star"]
const MARKS := [["Bone", Color(0.95, 0.93, 0.86)], ["Black", Color(0.08, 0.08, 0.09)], ["Gold", Color(0.95, 0.75, 0.2)],
	["Red", Color(0.75, 0.1, 0.08)]]
const FIGURES := ["None", "Mermaid", "Lion", "Sea serpent", "Eagle"]

const FLAG_W := 48
const FLAG_H := 30


static func fresh() -> Dictionary:
	return {"armour": false, "guns": false, "sails": false, "rudder": false,
		"hull": 0, "sail": 0, "field": 0, "emblem": 0, "mark": 0, "figure": 0}


## A saved kit over the defaults (older saves have none).
static func merged(saved: Dictionary) -> Dictionary:
	var k := fresh()
	k.merge(saved, true)
	return k


static func refit(id: String) -> Array:
	for r in REFITS:
		if r[0] == id:
			return r
	return []


## The flag as painted: the field, a little cloth noise, the emblem.
static func flag_image(kit: Dictionary) -> Image:
	var img := Image.create(FLAG_W, FLAG_H, false, Image.FORMAT_RGBA8)
	var field: Color = FIELDS[int(kit["field"])][1]
	var mark: Color = MARKS[int(kit["mark"])][1]
	var emblem := int(kit["emblem"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in range(FLAG_H):
		for x in range(FLAG_W):
			var c := field.darkened(rng.randf() * 0.12)
			if _emblem_at(emblem, Vector2(x + 0.5, y + 0.5)):
				c = mark.darkened(rng.randf() * 0.08)
			img.set_pixel(x, y, c)
	return img


static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t))


static func _emblem_at(emblem: int, p: Vector2) -> bool:
	var c := Vector2(FLAG_W * 0.5, FLAG_H * 0.5)
	match emblem:
		1:
			# skull over crossbones
			var on := p.distance_to(c + Vector2(0, -3)) < 6.5 or (absf(p.x - c.x) < 3.5 and p.y > c.y and p.y < c.y + 5.0)
			if p.distance_to(c + Vector2(-2.5, -3)) < 1.8 or p.distance_to(c + Vector2(2.5, -3)) < 1.8:
				on = false
			for s in [-1.0, 1.0]:
				if _seg(p, c + Vector2(-11, 3 * s + 6), c + Vector2(11, -3 * s + 6)) < 1.3:
					on = true
			return on
		2:
			# two cutlasses crossed, hilts down
			for s in [-1.0, 1.0]:
				var tip := c + Vector2(10 * s, -10)
				var hilt := c + Vector2(-7 * s, 8)
				if _seg(p, tip, hilt) < 1.2:
					return true
				var g := hilt.lerp(tip, 0.15)
				var across := Vector2(-(tip - hilt).y, (tip - hilt).x).normalized() * 2.5
				if _seg(p, g - across, g + across) < 0.9:
					return true
			return false
		3:
			# anchor: ring, shank, stock, arms
			if absf(p.distance_to(c + Vector2(0, -9)) - 2.0) < 0.9:
				return true
			if _seg(p, c + Vector2(0, -7), c + Vector2(0, 9)) < 1.1 or _seg(p, c + Vector2(-5, -5), c + Vector2(5, -5)) < 0.9:
				return true
			var d := p.distance_to(c + Vector2(0, 2))
			return absf(d - 7.0) < 1.1 and p.y > c.y + 4.0
		4:
			# a five-pointed star
			var q := p - c
			var a := atan2(q.y, q.x) + PI * 0.5
			var k := fposmod(a, TAU / 5.0) / (TAU / 5.0)
			return q.length() < lerpf(10.0, 4.2, 1.0 - absf(k - 0.5) * 2.0)
	return false


## The figurehead under the bowsprit (local -z forward, origin on the stem).
static func figurehead(kind: int) -> MeshInstance3D:
	if kind <= 0:
		return null
	var gilt := PSXMat.lit("bark", Color(1.7, 1.35, 0.6))
	var paint := PSXMat.lit("bark", Color(1.6, 1.4, 1.2))
	var mb := MeshBuilder.new()
	match kind:
		1:
			# a mermaid leaning out, arms back, tail curling up the stem
			mb.add_box(paint, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.55, -0.35)), Vector3(0.36, 0.7, 0.26), 1.0)
			mb.add_box(paint, Transform3D(Basis(), Vector3(0, 1.0, -0.62)), Vector3(0.26, 0.3, 0.26), 1.0)
			mb.add_box(gilt, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 1.05, -0.45)), Vector3(0.32, 0.4, 0.12), 1.0)
			for s in [-1.0, 1.0]:
				mb.add_box(paint, Transform3D(Basis(Vector3.FORWARD, s * 0.5), Vector3(s * 0.25, 0.6, -0.2)), Vector3(0.1, 0.5, 0.1), 1.0)
			mb.add_box(gilt, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.1, -0.1)), Vector3(0.3, 0.6, 0.24), 1.0)
			mb.add_box(gilt, Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(0, -0.25, 0.15)), Vector3(0.5, 0.12, 0.3), 1.0)
		2:
			# a lion's head, mane and all
			mb.add_cylinder(gilt, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.6, -0.1)), 0.55, 0.45, 0.4, 8, 1.0)
			mb.add_box(gilt, Transform3D(Basis(), Vector3(0, 0.6, -0.6)), Vector3(0.5, 0.5, 0.5), 1.0)
			mb.add_box(gilt, Transform3D(Basis(), Vector3(0, 0.5, -0.9)), Vector3(0.3, 0.25, 0.25), 1.0)
			for s in [-1.0, 1.0]:
				mb.add_box(gilt, Transform3D(Basis(), Vector3(s * 0.2, 0.9, -0.5)), Vector3(0.12, 0.14, 0.1), 1.0)
		3:
			# a sea serpent rearing, jaws open
			mb.add_box(gilt, Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0, 0.2, -0.2)), Vector3(0.3, 0.6, 0.3), 1.0)
			mb.add_box(gilt, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 0.75, -0.42)), Vector3(0.26, 0.6, 0.26), 1.0)
			mb.add_box(gilt, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 1.1, -0.72)), Vector3(0.3, 0.2, 0.6), 1.0)
			mb.add_box(gilt, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.92, -0.75)), Vector3(0.24, 0.1, 0.5), 1.0)
			mb.add_card(PSXMat.lit("leather", Color(1.5, 0.4, 0.35)), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.9, -0.3)), 0.6, 0.35)
		4:
			# an eagle, wings swept back along the bow
			mb.add_box(paint, Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.55, -0.4)), Vector3(0.36, 0.6, 0.36), 1.0)
			mb.add_box(paint, Transform3D(Basis(), Vector3(0, 0.95, -0.6)), Vector3(0.24, 0.24, 0.3), 1.0)
			mb.add_box(gilt, Transform3D(Basis(), Vector3(0, 0.9, -0.82)), Vector3(0.1, 0.1, 0.2), 1.0)
			for s in [-1.0, 1.0]:
				mb.add_box(gilt, Transform3D(Basis(Vector3.UP, s * 0.5) * Basis(Vector3.FORWARD, s * 0.3), Vector3(s * 0.45, 0.65, -0.1)), Vector3(0.7, 0.08, 0.4), 1.0)
	return mb.to_instance("FigureMesh")

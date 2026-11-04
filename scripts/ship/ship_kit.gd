class_name ShipKit
extends RefCounted
## What the shipwright (Tackett's yard, Brinehollow) has done to our ship:
## each upgrade line's level (ShipLines) and her paint, colours, flag and
## figurehead. A plain Dictionary (GameManager.ship_kit, saved; the host's in co-op):
##   {<line id>: level, ..., "hull": i, "sail": i, "field": i, "emblem": i, "mark": i, "figure": i}
## Ship.apply_kit puts it on the hull.

const HULL_PAINT := [["Tarred", Color.WHITE], ["Pitch black", Color(0.38, 0.38, 0.42)], ["Oxblood", Color(1.35, 0.5, 0.42)],
	["Navy", Color(0.6, 0.8, 1.35)], ["Sea green", Color(0.65, 1.15, 0.8)], ["Whitewash", Color(1.9, 1.85, 1.7)]]
const SAILS := [["Canvas", Color(0.95, 0.92, 0.82)], ["Black", Color(0.24, 0.24, 0.27)], ["Crimson", Color(1.0, 0.32, 0.28)],
	["Navy", Color(0.35, 0.45, 0.85)], ["Sand", Color(1.0, 0.86, 0.55)]]
const FIELDS := [["Red", Color(0.7, 0.1, 0.08)], ["Black", Color(0.08, 0.08, 0.09)], ["Navy", Color(0.1, 0.16, 0.42)],
	["Green", Color(0.1, 0.38, 0.2)], ["Gold", Color(0.85, 0.65, 0.15)], ["White", Color(0.92, 0.9, 0.84)]]
const EMBLEMS := ["None", "Skull", "Crossed swords", "Anchor", "Star", "Kraken", "Trident", "Rose", "Sun", "Wave", "Raven"]
const MARKS := [["Bone", Color(0.95, 0.93, 0.86)], ["Black", Color(0.08, 0.08, 0.09)], ["Gold", Color(0.95, 0.75, 0.2)],
	["Red", Color(0.75, 0.1, 0.08)]]
const FIGURES := Figureheads.NAMES
## (1.29) Four more paint channels (Ship.apply_kit): her rails and trim, her masts and spars, her deck's stain, and a
## stripe down her sides with accents on her stern in a second colour (0: none). The first of each is her old look.
const RAILS := [["Natural", Color(0.85, 0.65, 0.35)], ["Dark varnish", Color(0.5, 0.34, 0.22)], ["Red", Color(0.9, 0.28, 0.22)],
	["White", Color(1.4, 1.35, 1.25)], ["Black", Color(0.26, 0.25, 0.27)], ["Gold", Color(1.3, 1.0, 0.45)], ["Sea green", Color(0.5, 0.9, 0.7)]]
const SPARS := [["Natural", Color.WHITE], ["Stained", Color(0.6, 0.48, 0.38)], ["Painted black", Color(0.3, 0.3, 0.32)], ["Painted white", Color(1.6, 1.55, 1.45)]]
const DECKS := [["Pale", Color.WHITE], ["Honey", Color(1.12, 0.92, 0.62)], ["Dark oak", Color(0.62, 0.5, 0.4)], ["Weathered grey", Color(0.82, 0.84, 0.86)]]
const STRIPES := [["None", Color.WHITE], ["White", Color(1.5, 1.45, 1.35)], ["Red", Color(0.8, 0.15, 0.1)], ["Gold", Color(1.0, 0.75, 0.25)],
	["Navy", Color(0.15, 0.22, 0.5)], ["Black", Color(0.1, 0.1, 0.11)], ["Sea green", Color(0.2, 0.55, 0.4)]]
## (1.29) The jolly roger builder: a skull, what's crossed behind it and a headpiece, drawn into the flag (and on the
## sail) in the mark colour; "skull" 0 keeps the plain emblem (EMBLEMS).
const SKULLS := ["None (the emblem)", "Round", "Grinning", "Horned", "Cracked"]
const CROSSED := ["Nothing", "Bones", "Cutlasses", "Pistols", "Keys", "Oars", "Tridents"]
const HEADPIECES := ["None", "Straw hat", "Bandana", "Tricorn", "Crown", "Horns"]

const FLAG_W := 48
const FLAG_H := 30


static func fresh() -> Dictionary:
	var k := {"hull": 0, "sail": 0, "field": 0, "emblem": 0, "mark": 0, "figure": 0,
		"rail": 0, "spar": 0, "deck": 0, "stripe": 0, "skull": 0, "crossed": 0, "headpiece": 0}
	for id in ShipLines.LINES.keys():
		k[id] = 0
	return k


## (1.30) Her looks: the crew's, whichever ship she is (ShipClasses.switch_to carries them over; a laid-up ship keeps none).
const LOOKS := ["hull", "sail", "field", "emblem", "mark", "figure", "rail", "spar", "deck", "stripe", "skull", "crossed", "headpiece"]


## A saved kit over the defaults (older saves have none; their one-time
## refits are bools, each its line's matching level). (1.30) A laid-up ship's own looks from before go: the crew's are
## the ship she sails.
static func merged(saved: Dictionary) -> Dictionary:
	var k := fresh()
	k.merge(saved, true)
	for id in ShipLines.LINES.keys():
		k[id] = ShipLines.from_saved(id, k[id])
	if k.has("fleet"):
		var fleet: Dictionary = (k["fleet"] as Dictionary).duplicate(true)
		for c in fleet:
			for key in LOOKS:
				(fleet[c] as Dictionary).erase(key)
		k["fleet"] = fleet
	return k


## The flag as painted: the field, a little cloth noise, the emblem (or her jolly roger).
static func flag_image(kit: Dictionary) -> Image:
	var img := Image.create(FLAG_W, FLAG_H, false, Image.FORMAT_RGBA8)
	var field: Color = FIELDS[int(kit["field"])][1]
	var mark: Color = MARKS[int(kit["mark"])][1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in range(FLAG_H):
		for x in range(FLAG_W):
			var c := field.darkened(rng.randf() * 0.12)
			if _mark_at(kit, Vector2(x + 0.5, y + 0.5)):
				c = mark.darkened(rng.randf() * 0.08)
			img.set_pixel(x, y, c)
	return img


## Is flag pixel `p` the mark colour: the jolly roger's (a skull chosen) or the emblem's.
static func _mark_at(kit: Dictionary, p: Vector2) -> bool:
	if int(kit.get("skull", 0)) > 0:
		return _jolly_at(kit, p) > 0
	return _emblem_at(int(kit["emblem"]), p)


## The jolly roger at flag pixel `p`: 1 the mark, -1 cut back to the field (sockets, nose, teeth, a crack), 0
## neither. Back to front: what's crossed, the skull, the headpiece.
static func _jolly_at(kit: Dictionary, p: Vector2) -> int:
	var c := Vector2(FLAG_W * 0.5, FLAG_H * 0.5 + 1.0)
	var on := 0
	if _crossed_at(int(kit.get("crossed", 0)), p, c):
		on = 1
	var s := _skull_at(int(kit.get("skull", 0)), p, c)
	if s != 0:
		on = s
	if _head_at(int(kit.get("headpiece", 0)), p, c):
		on = 1
	return on


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
		5:
			# a kraken: a round head, four tentacles writhing down
			if p.distance_to(c + Vector2(0, -5)) < 5.5:
				return p.distance_to(c + Vector2(-2, -5)) > 1.2 and p.distance_to(c + Vector2(2, -5)) > 1.2
			if p.y > c.y - 1.0 and p.y < c.y + 11.0:
				for i in range(4):
					var x0 := -6.0 + i * 4.0 + (p.y - c.y) * (-0.35 if i < 2 else 0.35)
					if absf(p.x - (c.x + x0 + sin((p.y - c.y) * 0.7 + i) * 1.6)) < 1.1:
						return true
			return false
		6:
			# a trident: the shaft, the crossbar, three prongs
			if _seg(p, c + Vector2(0, -11), c + Vector2(0, 11)) < 1.1 or _seg(p, c + Vector2(-6, -3), c + Vector2(6, -3)) < 1.0:
				return true
			for s in [-1.0, 1.0]:
				if _seg(p, c + Vector2(6 * s, -3), c + Vector2(6 * s, -10)) < 1.0:
					return true
			return false
		7:
			# a rose: the bloom (its fold a ring inside), the stem, a leaf
			var d := p.distance_to(c + Vector2(0, -3))
			if d < 6.0:
				return absf(d - 3.0) > 0.6
			return _seg(p, c + Vector2(0, 3), c + Vector2(0, 11)) < 1.0 or _seg(p, c + Vector2(0, 7), c + Vector2(4, 5)) < 1.3
		8:
			# a sun: a disc and eight rays
			var q := p - c
			if q.length() < 5.0:
				return true
			for k in range(8):
				var dir := Vector2.from_angle(k * TAU / 8.0)
				if _seg(p, c + dir * 7.0, c + dir * 10.5) < 1.0:
					return true
			return false
		9:
			# a wave: a rolling crest curling over
			if absf(p.x - c.x) < 12.0 and absf(p.y - (c.y + 4.0 + sin((p.x - c.x) * 0.35) * 2.5)) < 1.3:
				return true
			return absf(p.distance_to(c + Vector2(4, -2)) - 4.0) < 1.0 and p.y < c.y + 1.0
		10:
			# a raven in flight: body, head, beak, two wings, the tail
			var q := p - c
			if pow(q.x / 7.0, 2.0) + pow((q.y - 1.0) / 3.0, 2.0) < 1.0 or p.distance_to(c + Vector2(-7, -1)) < 2.5:
				return true
			return (_seg(p, c + Vector2(-9.5, -1), c + Vector2(-12, 0)) < 0.8 or _seg(p, c + Vector2(-2, -1), c + Vector2(3, -10)) < 1.6
				or _seg(p, c + Vector2(1, -1), c + Vector2(9, -8)) < 1.6 or _seg(p, c + Vector2(6, 2), c + Vector2(11, 4)) < 1.2)
	return false


## The skull: 1 bone, -1 a socket, the nose, a gap between teeth, a crack; 0 off it.
static func _skull_at(kind: int, p: Vector2, c: Vector2) -> int:
	var q := p - c
	var cran := Vector2(q.x / 6.4, (q.y + 2.5) / 5.6).length() < 1.0
	var jaw := absf(q.x) < (3.6 if kind != 2 else 4.6) and q.y > 0.5 and q.y < 5.2
	if not (cran or jaw):
		if kind == 3:
			# horns curling up off the crown
			for sx in [-1.0, 1.0]:
				var h := Vector2(q.x * sx, q.y)
				if h.x > 4.0 and h.x < 9.0 and absf(h.y - (-6.5 - (h.x - 4.0) * 0.9 + pow(h.x - 4.0, 2.0) * 0.12)) < 1.3 - (h.x - 4.0) * 0.15:
					return 1
		return 0
	# eye sockets and the nose
	for sx in [-1.0, 1.0]:
		var e := q - Vector2(sx * 2.5, -2.2)
		if Vector2(e.x / 1.7, e.y / (1.9 if kind != 2 else 1.5)).length() < 1.0:
			return -1
	if absf(q.x) < (0.9 - (q.y - 0.4) * 0.3) and q.y > 0.0 and q.y < 1.6:
		return -1
	# the teeth: gaps down the jaw (the grinning one's wide, a gap-toothed row)
	if q.y > 3.0 and q.y < 5.2:
		var step := 1.5 if kind != 2 else 1.25
		if fposmod(q.x + 0.5, step) < 0.45:
			return -1
		if kind == 2 and absf(q.y - 3.8) < 0.35:
			return -1
	if kind == 4:
		# a crack from the crown down to the left socket
		var t := clampf((q.y + 7.5) / 5.0, 0.0, 1.0)
		if absf(q.x - (1.2 - t * 2.6 + sin(t * 9.0) * 0.6)) < 0.45 and q.y < -2.5:
			return -1
	return 1


## What's crossed behind the skull (corner to corner), with their ends.
static func _crossed_at(kind: int, p: Vector2, c: Vector2) -> bool:
	if kind <= 0:
		return false
	for sx in [-1.0, 1.0]:
		# from low on one side to high on the other
		var a := c + Vector2(-11.5 * sx, 9.0)
		var b := c + Vector2(11.5 * sx, -7.0)
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		match kind:
			1:
				# bones: a shaft and a pair of knuckles at each end
				if _seg(p, a, b) < 1.0:
					return true
				for e in [a, b]:
					if p.distance_to(e + n * 1.2) < 1.3 or p.distance_to(e - n * 1.2) < 1.3:
						return true
			2:
				# cutlasses: a broad blade curving to the point, a guard across, the grip and a round pommel
				var t := clampf((p - a).dot(d) / a.distance_to(b), 0.0, 1.0)
				var along: Vector2 = a.lerp(b, t) + n * sin(t * PI * 0.9) * 0.9 * sx
				if t > 0.22 and p.distance_to(along) < 1.45 - t * 1.0:
					return true
				var g := a.lerp(b, 0.22)
				if _seg(p, g - n * 2.0, g + n * 2.0) < 0.75 or _seg(p, a + d * 1.2, g) < 0.75 or p.distance_to(a + d * 0.6) < 1.1:
					return true
			3:
				# pistols: a barrel, a curved grip at the low end dropping away
				if _seg(p, a.lerp(b, 0.25), b) < 0.9:
					return true
				if _seg(p, a.lerp(b, 0.25), a.lerp(b, 0.25) + (n * sx * -1.0 - d) * 3.2) < 1.3:
					return true
			4:
				# keys: a ring at the low end, a shaft, a bit at the top
				if absf(p.distance_to(a + d * 1.5) - 1.8) < 0.7:
					return true
				if _seg(p, a + d * 3.3, b) < 0.7:
					return true
				if _seg(p, b - d * 1.0, b - d * 1.0 + n * 2.0) < 0.8 or _seg(p, b - d * 2.6, b - d * 2.6 + n * 1.6) < 0.8:
					return true
			5:
				# oars: a loom and a broad blade at the top
				if _seg(p, a, b) < 0.75:
					return true
				var bl := b - d * 2.6
				if Vector2((p - bl).dot(d) / 3.0, (p - bl).dot(n) / 1.4).length() < 1.0:
					return true
			6:
				# tridents: a shaft, a crossbar and three prongs at the top
				if _seg(p, a, b) < 0.75:
					return true
				var x := b - d * 3.0
				if _seg(p, x - n * 2.2, x + n * 2.2) < 0.7:
					return true
				for k in [-2.2, 2.2]:
					if _seg(p, x + n * k, x + n * k + d * 2.8) < 0.65:
						return true
	return false


## The headpiece on the skull's crown.
static func _head_at(kind: int, p: Vector2, c: Vector2) -> bool:
	var q := p - c
	match kind:
		1:
			# a straw hat: a wide brim, a round crown, a band (cut back)
			if absf(q.y + 7.0) < 0.9 and absf(q.x) < 10.5:
				return true
			return Vector2(q.x / 5.5, (q.y + 8.6) / 2.6).length() < 1.0 and q.y < -7.0 and absf(q.y + 8.0) > 0.45
		2:
			# a bandana: a band over the crown, knotted at the side with two tails
			if q.y > -9.0 and q.y < -5.6 and Vector2(q.x / 7.0, (q.y + 4.0) / 5.2).length() < 1.08:
				return true
			return _seg(p, c + Vector2(6.2, -6.0), c + Vector2(9.5, -3.0)) < 0.8 or _seg(p, c + Vector2(6.2, -6.0), c + Vector2(10.0, -6.2)) < 0.8
		3:
			# a tricorn: three corners up, a low crown
			# (the brim thin in the middle, sweeping up into a point at each side; a rounded crown over it)
			var ax := absf(q.x)
			if ax < 9.5 and q.y < -6.0 and q.y > -6.0 - (1.0 + pow(ax / 9.5, 3.0) * 4.5):
				return true
			return Vector2(q.x / 4.2, (q.y + 7.0) / 3.2).length() < 1.0 and q.y < -6.0
		4:
			# a crown: a band and five points
			if absf(q.y + 7.4) < 0.9 and absf(q.x) < 6.0:
				return true
			for k in range(5):
				var x := -5.0 + k * 2.5
				if q.y < -8.0 and q.y > -11.2 and absf(q.x - x) < (1.0 - (-8.0 - q.y) * 0.3):
					return true
			return false
		5:
			# horns: two great curves up from the temples
			for sx in [-1.0, 1.0]:
				var h := Vector2(q.x * sx, q.y)
				if h.x > 3.5 and h.x < 10.5:
					var y := -5.5 - pow(h.x - 3.5, 1.4) * 0.75
					if absf(h.y - y) < 1.5 - (h.x - 3.5) * 0.17:
						return true
			return false
	return false


## The crew's emblem (or jolly roger) alone, for the main sail: its mark colour where the flag's is, clear elsewhere;
## null with neither. Square (EMBLEM_PX), centred as on the flag.
const EMBLEM_PX := 30
static func sail_emblem_image(kit: Dictionary) -> Image:
	if int(kit.get("emblem", 0)) <= 0 and int(kit.get("skull", 0)) <= 0:
		return null
	var mark: Color = MARKS[int(kit["mark"])][1]
	var img := Image.create(EMBLEM_PX, EMBLEM_PX, false, Image.FORMAT_RGBA8)
	var off := Vector2(FLAG_W * 0.5 - EMBLEM_PX * 0.5, FLAG_H * 0.5 - EMBLEM_PX * 0.5)
	for y in range(EMBLEM_PX):
		for x in range(EMBLEM_PX):
			var on := _mark_at(kit, Vector2(x + 0.5, y + 0.5) + off)
			img.set_pixel(x, y, mark if on else Color(mark.r, mark.g, mark.b, 0.0))
	return img


## The figurehead under the bowsprit (Figureheads: local -z forward, origin on the stem).
static func figurehead(kind: int) -> MeshInstance3D:
	return Figureheads.build(kind)

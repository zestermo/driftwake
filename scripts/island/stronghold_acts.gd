class_name StrongholdActs
extends RefCounted
## The stronghold run's acts (1.30, docs/v1_30_plan.md round 3: "land and breach the gate; the two seals in either order;
## the keep and Vane; the vault; the Scouring escape"). What the acts need that the fortress didn't have:
##   Gate      the Landing's way up: the gatehouse at the grand stair's head has its portcullis down ("sh_gate_open").
##             The winch on the stair beside it raises it (WINCH_SECS of a captain staying at it while the Landing's
##             garrison and boats come at them); the lever inside opens it for whoever got in another way (the west
##             cove's drain to the prison, a grapple up the ward's front wall); a powder charge blows it (ChargeTarget).
##   Balcony   the Verdict's roof: a deck jutting from the Command Hall's top over its door (BALCONY at ROOF_Y), where
##             Commodore Vane makes his stand from phase 2 as the Scouring is ordered; the hoist (an iron cage) in the
##             hall carries captains up and down.
##   Ledges    grapple points (GrapplePoints.add_ledge) on the ward's front wall, the prison's sea wall over the cove and
##             the arsenal's east wall: the ways in round the gate.
##   Supplies  a supply chest (Gadgets.supply_crate) in the Barracks.
##   ACTS      the debug menu's act jumps (F4): the crew there with the flags the act needs.

const BALCONY := Rect2(-16.0, -62.0, 32.0, 12.0)
const ROOF_Y := 63.2
## The roof terrace's slab: the Command Hall's top, round the Verdict's second stage (StrongholdShell.SPIRE_STAGES[0]).
const TERRACE := 49.6
const HOIST_DOWN := Vector2(17.0, -70.0)
const HOIST_UP := Vector2(12.0, -59.0)
const GATE_AT := Vector2(0.0, 18.6)
const GATE_W := 13.0
const GATE_H := 8.0
const WINCH := Vector2(-4.8, 22.6)
const LEVER := Vector2(5.5, 15.4)
const WINCH_SECS := 8.0
const WINCH_R := 2.8
const LEDGES := [Vector3(-22.0, 18.0, 18.6), Vector3(22.0, 18.0, 18.6), Vector3(-34.0, 18.0, 18.6), Vector3(34.0, 18.0, 18.6),
	Vector3(-108.6, 20.0, -28.0), Vector3(-108.6, 20.0, 2.0), Vector3(108.6, 20.0, -30.0), Vector3(108.6, 20.0, 4.0)]
const SUPPLY_AT := Vector2(38.5, 8.0)
## [label, where (frame xz), the flags it needs]
const ACTS := [
	["Act 1: breach the gate (the Landing)", Vector2(0.0, 44.0), []],
	["Act 2: the Arsenal (Kesh's foundry)", Vector2(62.0, -23.0), ["sh_gate_open"]],
	["Act 2: the prison yard (Marrow's riot)", Vector2(-55.0, -4.0), ["sh_gate_open"]],
	["Act 3: the keep (Vane's hall)", Vector2(0.0, -56.0), ["sh_gate_open", "sh_seal_arsenal", "sh_seal_prison"]],
	["Act 3: the Verdict's roof", Vector2(0.0, -54.0), ["sh_gate_open", "sh_seal_arsenal", "sh_seal_prison"]],
	["Act 4: the vault (Vane beaten)", Vector2(0.0, -96.0), ["sh_gate_open", "sh_seal_arsenal", "sh_seal_prison", "sh_seal_keep"]],
]


## The acts' pieces under the island's City node (every machine).
static func build(isl: Node3D) -> Array:
	var gate := Gate.new()
	isl.city.add_child(gate)
	var bal := _balcony()
	isl.city.add_child(bal)
	for pair in [[HOIST_DOWN, 30.0, HOIST_UP, ROOF_Y, "Ride the hoist up to the Verdict's roof"],
			[HOIST_UP, ROOF_Y, HOIST_DOWN, 30.0, "Ride the hoist down to the Command Hall"]]:
		isl.city.add_child(_hoist(isl, pair[0], pair[1], pair[2], pair[3], pair[4]))
	for q: Vector3 in LEDGES:
		GrapplePoints.add_ledge(isl.city, q)
	var gm := isl.get_node("/root/GameManager")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["sh_supply", int(gm.chain_seed)])
	var stacks: Array = []
	Gadgets.supply_crate(stacks, rng)
	var items: Array = stacks.map(func(s): return [(s as ItemStack).item.id, (s as ItemStack).quantity])
	var key := "sh_supply_%d" % int(gm.chain_seed)
	CityCaches.place(isl.city, [{"xf": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(SUPPLY_AT.x, 12.0, SUPPLY_AT.y)), "key": key, "items": items}])
	return [gate, bal]


## The roof's deck over the Command Hall's door: stone on iron brackets, a parapet round its three open sides, braziers
## at its front corners; and the terrace slab round the Verdict's second stage it joins.
static func _balcony() -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "VerdictBalcony"
	var stone := PSXMat.lit("stone_brick", Color(0.62, 0.66, 0.72))
	var dark := PSXMat.lit("stone_brick", Color(0.38, 0.4, 0.45))
	var iron := PSXMat.lit("metal", Color(0.3, 0.31, 0.34))
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var c := BALCONY.get_center()
	var boxes: Array = [
		[Vector3(c.x, ROOF_Y - 0.45, c.y), Vector3(BALCONY.size.x, 0.9, BALCONY.size.y), stone],
		[Vector3(c.x, ROOF_Y + 0.55, BALCONY.end.y - 0.3), Vector3(BALCONY.size.x, 1.1, 0.6), dark],
		[Vector3(BALCONY.position.x + 0.3, ROOF_Y + 0.55, c.y), Vector3(0.6, 1.1, BALCONY.size.y), dark],
		[Vector3(BALCONY.end.x - 0.3, ROOF_Y + 0.55, c.y), Vector3(0.6, 1.1, BALCONY.size.y), dark],
		[Vector3(0.0, ROOF_Y - 0.1, StrongholdPlan.KEEP.y), Vector3(TERRACE, 0.2, TERRACE), null],
	]
	for bx in boxes:
		if bx[2] != null:
			mb.add_box(bx[2], Transform3D(Basis(), bx[0]), bx[1], 0.5)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bx[1]
		cs.shape = sh
		cs.position = bx[0]
		b.add_child(cs)
	for x: float in [-12.0, -4.0, 4.0, 12.0]:
		var a := Vector3(x, ROOF_Y - 0.9, BALCONY.end.y - 1.0)
		var e := Vector3(x, ROOF_Y - 6.0, BALCONY.position.y + 0.2)
		mb.add_box(iron, Transform3D(Basis.looking_at(e - a, Vector3.UP), (a + e) * 0.5), Vector3(0.5, 0.5, a.distance_to(e)), 0.5)
	for x: float in [BALCONY.position.x + 0.8, BALCONY.end.x - 0.8]:
		mb.add_cylinder(iron, Transform3D(Basis(), Vector3(x, ROOF_Y + 1.5, BALCONY.end.y - 0.8)), 0.45, 0.3, 0.6, 8, 0.5)
		mb.add_box(PSXMat.glow(Color(1.0, 0.5, 0.15), 2.0), Transform3D(Basis(), Vector3(x, ROOF_Y + 1.95, BALCONY.end.y - 0.8)), Vector3(0.5, 0.4, 0.5), 1.0)
	var mi := mb.to_instance("BalconyMesh")
	mi.visibility_range_end = 900.0
	b.add_child(mi)
	return b


## A hoist landing: an iron cage on a chain with its lever; F carries the captain to the other landing (each captain
## on their own machine).
static func _hoist(isl: Node3D, at: Vector2, y: float, to: Vector2, to_y: float, prompt: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Hoist_%d" % int(y)
	n.position = Vector3(at.x, y, at.y)
	var iron := PSXMat.lit("metal", Color(0.3, 0.31, 0.34))
	var mb := MeshBuilder.new()
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			mb.add_box(iron, Transform3D(Basis(), Vector3(cx * 1.1, 1.3, cz * 1.1)), Vector3(0.12, 2.6, 0.12), 0.5)
	for yy: float in [0.05, 2.6]:
		mb.add_box(iron, Transform3D(Basis(), Vector3(0, yy, 0)), Vector3(2.3, 0.1, 2.3), 0.5)
	mb.add_box(iron, Transform3D(Basis(), Vector3(0, 2.6 + 3.0, 0)), Vector3(0.08, 6.0, 0.08), 0.5)
	var mi := mb.to_instance("Cage")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 120.0
	n.add_child(mi)
	var use := Interactable.new()
	use.name = "Use"
	use.collision_layer = 512
	use.collision_mask = 0
	use.prompt_text = prompt
	use.gesture = "lever"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	cs.shape = sph
	use.add_child(cs)
	use.position = Vector3(0, 1.1, 0)
	n.add_child(use)
	use.interacted.connect(func(p: Player):
		var dest: Vector3 = isl.city_global(to, to_y + 0.3)
		var net := n.get_node("/root/Net")
		net.fx("sfx", ["rope", p.global_position, -2.0, 0.05, 0.8])
		p.global_position = dest
		p.reset_physics_interpolation()
		p.velocity = Vector3.ZERO
		net.fx("dust_ring", [dest, 10, 0.7]))
	return n


## (debug builds, the F4 menu) The crew to act `i`: the stronghold built, the flags it needs, our captain there.
static func jump(p: Player, i: int) -> void:
	var w := p.get_tree().get_first_node_in_group("world_gen")
	var id: int = w.chain().stronghold_id()
	if not w.chain_islands.has(id):
		await p.debug_to_island(id)
	if not w.chain_islands.has(id):
		return
	var isl: Node3D = w.chain_islands[id]
	var a: Array = ACTS[i]
	for f in a[2]:
		p.get_node("/root/Net").world_flag(str(f))
	var q: Vector2 = a[1]
	var g := StrongholdPlan.ground(q)
	var y := ROOF_Y if i == 4 else (g if g > -INF else 30.0)
	p.state_machine.force_state("Idle", {})
	p.global_position = isl.city_global(q, y + 0.5)
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	p.get_tree().call_group("hud", "show_toast", "Debug: %s" % str(a[0]))


## The Landing's gate: the gatehouse's portcullis down until "sh_gate_open" (the winch, the lever inside, a charge).
class Gate extends Node3D:
	var bars: StaticBody3D
	var _winch: Interactable
	var _lever: Interactable
	var _charge: ChargeTarget
	var _winding := false
	## (this machine's captain) how far the winch has it up, 0..1
	var progress := 0.0
	var _lift := 0.0

	func _ready() -> void:
		name = "Gate"
		position = Vector3(GATE_AT.x, 12.0, GATE_AT.y)
		bars = StaticBody3D.new()
		bars.name = "Portcullis"
		add_child(bars)
		var iron := PSXMat.lit("metal", Color(0.3, 0.31, 0.34))
		var mb := MeshBuilder.new()
		mb.all_faces = true
		var n := int(GATE_W / 0.75)
		for k in range(n + 1):
			mb.add_box(iron, Transform3D(Basis(), Vector3(-GATE_W * 0.5 + k * GATE_W / n, GATE_H * 0.5, 0)), Vector3(0.16, GATE_H, 0.16), 0.5)
		for yy: float in [0.6, GATE_H * 0.4, GATE_H * 0.75]:
			mb.add_box(iron, Transform3D(Basis(), Vector3(0, yy, 0)), Vector3(GATE_W, 0.18, 0.2), 0.5)
		for k in range(n):
			mb.add_box(iron, Transform3D(Basis(), Vector3(-GATE_W * 0.5 + (k + 0.5) * GATE_W / n, -0.15, 0)), Vector3(0.08, 0.3, 0.08), 0.5)
		var mi := mb.to_instance("Bars")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 400.0
		bars.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(GATE_W, GATE_H, 0.5)
		cs.shape = sh
		cs.position = Vector3(0, GATE_H * 0.5, 0)
		bars.add_child(cs)
		_charge = ChargeTarget.attach(bars, Vector3(0.0, 1.3, 0.3), Vector3(0, 0, 1), {"needs": 1, "remove": false, "mark": true})
		_charge.breached.connect(func(_by: Node):
			if Net.is_host() or not Net.active:
				Net.world_flag("sh_gate_open"))
		_winch = _use("Winch", WINCH, StrongholdPlan.ground(WINCH), "Work the winch (stay at it: the gate rises)", func(_p: Player):
			_winding = true)
		_lever = _use("Lever", LEVER, 12.0, "Pull the gate's lever", func(_p: Player):
			Net.world_flag("sh_gate_open"))
		var wm := MeshBuilder.new()
		wm.add_cylinder(PSXMat.lit("planks_dark"), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.9, 0)), 0.45, 0.45, 1.6, 8, 0.5)
		wm.add_box(iron, Transform3D(Basis(), Vector3(0.9, 0.9, 0)), Vector3(0.1, 1.2, 0.1), 0.5)
		var wi := wm.to_instance("WinchDrum")
		wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_winch.get_parent().add_child(wi)
		if open():
			_charge.breach_now()
			_lift = 1.0
			_show()

	func _use(nm: String, q: Vector2, y: float, prompt: String, cb: Callable) -> Interactable:
		var holder := Node3D.new()
		holder.name = nm
		add_child(holder)
		holder.global_position = get_parent().to_global(Vector3(q.x, y, q.y))
		var u := Interactable.new()
		u.name = "Use"
		u.collision_layer = 512
		u.collision_mask = 0
		u.prompt_text = prompt
		u.gesture = "lever"
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.6
		cs.shape = sph
		u.add_child(cs)
		u.position = Vector3(0, 1.1, 0)
		holder.add_child(u)
		u.interacted.connect(cb)
		return u

	func open() -> bool:
		var gm := get_node_or_null("/root/GameManager")
		return gm != null and gm.world_flags.has("sh_gate_open")

	func _process(delta: float) -> void:
		if open():
			_winding = false
			if not _charge.done:
				_charge.breach_now()
			if _lift < 1.0:
				_lift = minf(_lift + delta / 2.0, 1.0)
				_show()
			return
		if _winding:
			var me := get_tree().get_first_node_in_group("player") as Player
			var near := me != null and me.is_standing() and me.global_position.distance_to(_winch.global_position) < WINCH_R
			if not near:
				_winding = false
				get_tree().call_group("hud", "show_prompt", "", -1.0)
				return
			progress = minf(progress + delta / WINCH_SECS, 1.0)
			get_tree().call_group("hud", "show_prompt", "Winching the portcullis up... stay at it", progress)
			if int(progress * 8.0) != int((progress - delta / WINCH_SECS) * 8.0):
				FX.sfx("rope", _winch.global_position, -6.0, 0.1, 0.8)
			if progress >= 1.0:
				_winding = false
				get_tree().call_group("hud", "show_prompt", "", -1.0)
				Net.world_flag("sh_gate_open")
				Net.banner("The gate is up", "The Lower Ward is open: the stair to the keep's seals.")
			_lift = progress * 0.35
			_show()

	func _show() -> void:
		bars.position.y = _lift * (GATE_H - 0.4)
		bars.collision_layer = 0 if open() else 1
		_winch.enabled = not open()
		_lever.enabled = not open()

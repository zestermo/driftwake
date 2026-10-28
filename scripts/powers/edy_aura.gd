class_name EdyAura
extends Node
## An Edy aura on a body (EdyTypes): three layers in the captain's type's colour and shape, faded in, burning for
## `secs`, faded out.
##   rim     every mesh of the part gets a thin additive shell (the same mesh pushed out along its normals): a glowing
##           outline, Storm's veins crawling over it (shaders/psx/edy_aura.gdshader)
##   flame   a camera-facing card a little behind the body: the tall teardrop of rising tongues round the silhouette
##           (shaders/psx/edy_flame.gdshader), blended so it reads in daylight
##   ground  a disc underfoot in the type's shape (shaders/psx/edy_ground.gdshader): it sits on the ground, not on the
##           captain: when their feet leave it, it lingers where they stood for a moment and fades; it comes back when
##           they land
## Parts: "arms" (Infuse: the rim on the forearms, hands and what's held), "body" (a big Edy move's flare: rim and
## flame), "reinforce" (rim, flame and ground). Shown on every screen through FX.edy_aura (Net.fx). A second call on a
## body with one running extends it and widens it to the bigger part. `flash_on` brightens it for a moment (Reinforce
## shrugging off a blow). A draw per shell and two cards while it lasts; the CPU only fades it. Sound: a held aura
## (Infuse, Reinforce: HUM_MIN or longer) channels its type's hum (edy_hum_<type>, looped, faded with it); a short
## flare whooshes once (edy_flash).

const RIM := preload("res://shaders/psx/edy_aura.gdshader")
const FLAME := preload("res://shaders/psx/edy_flame.gdshader")
const GROUND := preload("res://shaders/psx/edy_ground.gdshader")
const LOOKS := {"haze": 0, "crackle": 1, "shimmer": 2, "lightning": 3, "swirl": 4}
const RANK := {"arms": 0, "body": 1, "reinforce": 2}
const FADE_IN := 0.18
const FADE_OUT := 0.45
const FLASH_DECAY := 3.0
## The flame card (metres, round the body's feet) and the ground disc's radius.
const CARD := Vector2(1.7, 3.0)
## Infuse's flames off each hand (and the blade in it).
const HAND_CARD := Vector2(0.55, 0.9)
const DISC := 1.5
## A held aura hums; shorter ones are flares and whoosh.
const HUM_MIN := 3.0
const HUM_DB := -10.0
## The ground disc: how fast it fades after the feet leave it, and comes back on landing.
const GROUND_OUT := 4.0
const GROUND_IN := 7.0

var part := "body"
var left := 0.0
var _t := 0.0
var _flash := 0.0
var _rim: ShaderMaterial
var _flame: ShaderMaterial
var _ground: ShaderMaterial
var _hand: ShaderMaterial
var _shells: Array[MeshInstance3D] = []
var _cards: Array[MeshInstance3D] = []
var _disc: MeshInstance3D
var _mover: CharacterBody3D
var _ground_k := 0.0
var _last_y := 0.0
var _hum: AudioStreamPlayer3D


## The aura on `body` (a Humanoid) for `secs`, in `color` and `look` (EdyTypes' look name).
static func show_on(body: Node3D, which: String, secs: float, color: Color, look: String) -> EdyAura:
	if body == null or not is_instance_valid(body):
		return null
	var a := body.get_node_or_null("EdyAura") as EdyAura
	if a == null:
		a = EdyAura.new()
		a.name = "EdyAura"
		a.part = which
		a._make_mats()
		body.add_child(a)
	elif int(RANK.get(which, 1)) > int(RANK.get(a.part, 1)):
		a.part = which
	a.left = maxf(a.left, secs)
	for m in [a._rim, a._flame, a._ground, a._hand]:
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("look", int(LOOKS.get(look, 0)))
	a._rim.set_shader_parameter("grow", 0.03)
	a._build(body)
	if secs >= HUM_MIN:
		a._start_hum(body, look)
	else:
		var fx := body.get_node_or_null("/root/FX")
		if fx:
			fx.sfx("edy_flash", body.global_position + Vector3(0, 1.0, 0), -6.0, 0.08)
	return a


## The type's channelling hum, looped on the body while the aura's held (its type from the look name).
func _start_hum(body: Node3D, look: String) -> void:
	var typ := ""
	for id in EdyTypes.TYPES:
		if str(EdyTypes.TYPES[id]["look"]) == look:
			typ = id
	var path := "res://assets/audio/edy_hum_%s.wav" % typ
	if typ == "" or not ResourceLoader.exists(path):
		return
	if _hum == null or not is_instance_valid(_hum):
		_hum = AudioStreamPlayer3D.new()
		_hum.name = "EdyHum"
		_hum.bus = "SFX"
		_hum.unit_size = 5.0
		_hum.max_distance = 40.0
		body.add_child(_hum)
		_hum.position = Vector3(0, 1.0, 0)
	var st := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / 2
	_hum.stream = st
	_hum.volume_db = -60.0
	_hum.play()


## The aura on `body` brightens for a moment.
static func flash_on(body: Node3D) -> void:
	var a := body.get_node_or_null("EdyAura") as EdyAura if body else null
	if a:
		a._flash = 1.0


func _make_mats() -> void:
	_rim = ShaderMaterial.new()
	_rim.shader = RIM
	_flame = ShaderMaterial.new()
	_flame.shader = FLAME
	_ground = ShaderMaterial.new()
	_ground.shader = GROUND
	_hand = ShaderMaterial.new()
	_hand.shader = FLAME
	_hand.set_shader_parameter("behind", 0.05)
	_hand.set_shader_parameter("girth", 1.3)
	for m in [_rim, _flame, _ground, _hand]:
		m.set_shader_parameter("strength", 0.0)


func _build(body: Node3D) -> void:
	_clear()
	for mi in _meshes(body):
		var s := MeshInstance3D.new()
		s.name = "EdyShell"
		s.mesh = mi.mesh
		s.material_override = _rim
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.skin:
			s.skin = mi.skin
			s.skeleton = NodePath("../" + str(mi.skeleton))
		mi.add_child(s)
		_shells.append(s)
	if part == "arms":
		# Infuse: small tongues off each hand and up what it holds
		for k in ["hand_r", "hand_l"]:
			var h = body.get(k)
			if h is Node3D:
				var hq := QuadMesh.new()
				hq.size = HAND_CARD
				hq.center_offset = Vector3(0, HAND_CARD.y * 0.5 - 0.25, 0)
				_card(h, hq, _hand, "EdyHand")
		return
	var q := QuadMesh.new()
	q.size = CARD
	q.center_offset = Vector3(0, CARD.y * 0.5 - 0.15, 0)
	_card(body, q, _flame, "EdyFlame")
	if part == "reinforce":
		var d := QuadMesh.new()
		d.size = Vector2.ONE * DISC * 2.0
		d.orientation = PlaneMesh.FACE_Y
		_disc = _card(body, d, _ground, "EdyGround")
		_disc.top_level = true
		_disc.global_position = body.global_position + Vector3(0, 0.04, 0)
		var n: Node = body
		while n and not (n is CharacterBody3D):
			n = n.get_parent()
		_mover = n as CharacterBody3D


func _card(body: Node3D, mesh: Mesh, mat: Material, n: String) -> MeshInstance3D:
	var c := MeshInstance3D.new()
	c.name = n
	c.mesh = mesh
	c.material_override = mat
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (the card is turned to the camera in its shader: keep it from being culled at its own bounds)
	c.extra_cull_margin = 2.0
	body.add_child(c)
	_cards.append(c)
	return c


func _clear() -> void:
	for s in _shells + _cards:
		if is_instance_valid(s):
			s.queue_free()
	_shells.clear()
	_cards.clear()
	_disc = null


## The part's meshes: arms (the forearms, hands, the arm skin and what's held) or every mesh on the body.
func _meshes(body: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var roots: Array = [body]
	if part == "arms":
		roots = []
		for k in ["fore_r", "hand_r", "fore_l", "hand_l"]:
			var b = body.get(k)
			if b is Node3D:
				roots.append(b)
		var torso = body.get("torso")
		if torso is Node3D and (torso as Node3D).get_node_or_null("ArmBody") is MeshInstance3D:
			out.append((torso as Node3D).get_node("ArmBody"))
	for r in roots:
		if r is MeshInstance3D and not str(r.name).begins_with("Edy"):
			out.append(r)
		for c in (r as Node).find_children("*", "MeshInstance3D", true, false):
			if not str(c.name).begins_with("Edy") and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).visible:
				out.append(c)
	return out


## (the shells hang off the body's meshes: they go with the aura however it's removed)
func _exit_tree() -> void:
	_clear()
	if _hum and is_instance_valid(_hum):
		_hum.queue_free()


func _process(delta: float) -> void:
	_t += delta
	left -= delta
	_flash = maxf(_flash - delta * FLASH_DECAY, 0.0)
	var k := minf(_t / FADE_IN, 1.0) if left > 0.0 else clampf(1.0 + left / FADE_OUT, 0.0, 1.0)
	_rim.set_shader_parameter("strength", k * (1.0 + _flash))
	if _hum and is_instance_valid(_hum):
		_hum.volume_db = HUM_DB + linear_to_db(maxf(k, 0.001))
	_flame.set_shader_parameter("strength", k)
	_flame.set_shader_parameter("flash", _flash)
	_ground.set_shader_parameter("strength", k * _ground_k)
	if is_instance_valid(_disc):
		var body := get_parent() as Node3D
		# on the ground: under the feet; off it, left where they stood, fading
		# (a crewmate's captain on this screen is a puppet with no floor test: still in height means grounded)
		var y := body.global_position.y
		var local: bool = _mover != null and bool(_mover.get("is_local"))
		var grounded := _mover == null or (_mover.is_on_floor() if local else absf(y - _last_y) < 1.2 * delta)
		_last_y = y
		if grounded:
			_disc.global_position = body.global_position + Vector3(0, 0.04, 0)
		_ground_k = move_toward(_ground_k, 1.0 if grounded else 0.0, delta * (GROUND_IN if grounded else GROUND_OUT))
	_hand.set_shader_parameter("strength", k)
	if left <= -FADE_OUT:
		queue_free()

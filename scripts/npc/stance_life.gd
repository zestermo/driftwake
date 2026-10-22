class_name StanceLife
## The combat stance's life on top of each weapon's guard (Humanoid._locomotion, armed and standing): the feet
## planted on the floor while the guard is up (Humanoid._foot_ik reads `plant`), and a breathing sway with each
## weapon's rhythm (heavy slow and deep, daggers quick), or the fist's bounce. Everything here reads the body's
## synced inputs (stance, armed, speed) and its own clock, so a co-op puppet shows the same.

## Side-on stances: the hips' turn in the guard (y+ = the right hip forward), added to the guard while it's up and
## taken out again under a full-body move (Humanoid._process), so the moves keep the square start they were made from.
const HIPS := {"sword": Vector3(0, 0.55, 0), "sword_pistol": Vector3(0, 0.5, 0), "pistol": Vector3(0, 0.25, 0)}
## Stance -> [breaths a second as rad/s, depth]. Unlisted stances take "".
const BREATH := {"": [2.4, 1.0], "sword": [2.4, 1.0], "sword_pistol": [2.4, 1.0], "dual_sword": [2.5, 1.0],
	"katana": [2.0, 1.1], "axe": [1.9, 1.4], "dagger": [3.6, 0.8], "dual_dagger": [3.8, 0.8], "pistol": [2.2, 0.8],
	"dual_pistol": [2.2, 0.8], "polearm": [2.0, 1.2], "hammer": [1.5, 1.7], "greatsword": [1.7, 1.5], "dual_axe": [2.0, 1.4]}
## The settle after an attack: its last segment back to the guard overshoots it a little and comes back
## (Humanoid._keys; the move's own length, nothing added). Stance -> the overshoot (Humanoid._back's c1).
const SETTLE := {"": 1.7, "dagger": 1.3, "dual_dagger": 1.3, "fist": 1.4, "axe": 2.2, "dual_axe": 2.2, "hammer": 2.5,
	"greatsword": 2.4, "polearm": 1.9, "katana": 1.8, "black_leg": 1.5}
## The fist's (and black-leg's) bounce: hops a second (rad/s of |sin|), how high the hips rise, how far the feet leave the floor.
const BOUNCE := [4.4, 0.034, 0.02]


## The main-hand dagger's grip: reversed (Humanoid.REVERSE_GRIP) in the one dagger's guard and either dagger set's
## run, twirled to the normal grip in the first TWIRL_OUT s of any move (the moves are keyed for it; their trails
## start later), back after it ends.
const TWIRL_OUT := 0.06
const TWIRL_IN := 0.16


## Run carries: the weapon carried while running forward (over RUN_ON m/s, kept down to RUN_OFF; a strafe, a 45 deg
## diagonal or a backpedal keeps the guard; SPRINT_ONLY stances carry only at a sprint), instead of the guard or the
## swinging run arms. Any move takes over at once.
const RUN_ON := 3.2
const RUN_OFF := 2.6
const CARRY_IN := 0.15
## Stances that keep the guard at any walking speed and direction and carry only at a sprint, the guard staying under
## the sprint (Humanoid._locomotion) so the carry blends in from it.
const SPRINT_ONLY := ["sword", "sword_pistol", "dual_sword", "axe"]
## Stance -> the carry's arms (the chest's frame; `swing` scales the stride's swing added to the shoulders' x).
const CARRIES := {
	# the cutlass in the hand hanging at the right side, the blade trailed back and out from the hip, its flat turned
	# up to the camera behind (2026-10-21: the arm swung back behind the hip read as the sword dragged down behind)
	"sword": {"arm_r": Vector3(-0.2, 0, 0.3), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(-2.6, 0.5, 1.0), "swing": 0.35},
	"sword_pistol": {"arm_r": Vector3(-0.2, 0, 0.3), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(-2.6, 0.5, 1.0), "swing": 0.35},
	"dual_sword": {"arm_r": Vector3(-0.2, 0, 0.3), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(-2.6, 0.5, 1.0),
		"arm_l": Vector3(-0.2, 0, -0.3), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3(-2.6, -0.5, -1.0), "swing": 0.35},
	# the axe over the right shoulder, the head behind it
	"axe": {"arm_r": Vector3(0.35, 0.25, 0.3), "fore_r": Vector3(2.2, 0, 0), "hand_r": Vector3(0.1, 0, 0), "swing": 0.0},
	# reverse grip, the blades back along the forearms, arms pumping hard
	"dagger": {"fore_r": Vector3(1.55, 0, 0), "hand_r": Vector3(-1.1, 0, 0), "fore_l": Vector3(1.45, 0, 0), "swing": 1.35},
	"dual_dagger": {"fore_r": Vector3(1.55, 0, 0), "hand_r": Vector3(-1.1, 0, 0), "fore_l": Vector3(1.55, 0, 0), "hand_l": Vector3(-1.1, 0, 0), "swing": 1.35},
	# the gun low at the side, muzzle down, swinging with the stride
	"pistol": {"arm_r": Vector3(-0.05, 0, 0.16), "fore_r": Vector3(0.45, 0, 0), "swing": 0.5},
}


## Each frame (locomotion, on the ground): eases `carry_w` toward carrying.
static func carry_weight(h, delta: float) -> void:
	var on: bool = h.stance in CARRIES and h.armed and h._action.is_empty() and not h._gait_back \
		and absf(h._travel_ang) < 0.6 and h.ground_speed > (RUN_OFF if h.carry_w > 0.5 else RUN_ON) \
		and (h.sprinting or h.stance not in SPRINT_ONLY)
	h.carry_w = move_toward(h.carry_w, 1.0 if on else 0.0, delta / CARRY_IN)


## The carry over the pose `p` (the guard or the run's arms): the chest and head back to the run's (`gait`, when the
## guard replaced them), the carry's arms, swinging with the stride (`s` = its sine).
static func carry(h, p: Dictionary, gait: Dictionary, s: float) -> void:
	var k := Humanoid._ease(h.carry_w)
	if k <= 0.0:
		return
	if not gait.is_empty():
		for j in ["hips", "torso", "head", "arm_l", "fore_l", "arm_r", "fore_r", "hand_r", "hand_l"]:
			p[j] = (p[j] as Vector3).lerp(gait[j], k)
	var c: Dictionary = CARRIES[h.stance]
	var sw := float(c["swing"])
	for j in c.keys():
		if j == "swing":
			continue
		var v: Vector3 = c[j]
		if j.begins_with("arm_"):
			v.x += s * 0.35 * sw * (1.0 if j == "arm_r" else -1.0)
		p[j] = (p[j] as Vector3).lerp(v, k)
	# (the pumping arms: the run's own swing, made bigger)
	if sw > 1.0:
		for j in ["arm_r", "arm_l"]:
			if not c.has(j):
				p[j] = (p[j] as Vector3) + Vector3((p[j] as Vector3).x * (sw - 1.0) * k, 0, 0)


## Adds the breathing (or the bounce) to the guard pose `p`; returns the lift to add. `still` 1 standing .. 0 moving.
static func breathe(h, p: Dictionary, still: float) -> float:
	if still <= 0.0:
		h.plant_up = 0.0
		return 0.0
	if h.stance in ["fist", "black_leg"]:
		var hop := absf(sin(h._t * BOUNCE[0]))
		h.plant_up = hop * BOUNCE[2] * still
		p["torso"] += Vector3(0.03 * hop, 0, 0) * still
		p["arm_l"] += Vector3(-0.05 * hop, 0, 0) * still
		p["arm_r"] += Vector3(-0.05 * hop, 0, 0) * still
		return (hop * BOUNCE[1] - 0.01) * still
	h.plant_up = 0.0
	var br: Array = BREATH.get(h.stance, BREATH[""])
	var k := float(br[1]) * still
	var b := sin(h._t * float(br[0]))
	var sway := sin(h._t * float(br[0]) * 0.5 + 0.7)
	# breathing in: the chest rises and opens, the shoulders lift; out: it sinks back over bent knees
	p["torso"] += Vector3(0.035 * b, 0.0, 0.02 * sway) * k
	p["head"] += Vector3(-0.025 * b, 0, -0.012 * sway) * k
	p["hips"] += Vector3(0, 0, -0.015 * sway) * k
	p["arm_r"] += Vector3(0.03 * b, 0, 0.03 * b) * k
	p["arm_l"] += Vector3(0.03 * b, 0, -0.03 * b) * k
	return (0.014 * b - 0.012) * k


## Each frame after the pose: the dagger's grip turned toward reversed or normal.
static func grip(h, delta: float) -> void:
	var w: MeshInstance3D = h.weapon
	if w == null or not is_instance_valid(w) or w.get_parent() != h.hand_r or Humanoid.kind_of(w) != "dagger" \
		or h.stance not in ["dagger", "dual_dagger"]:
		h.grip_flip = 0.0
		return
	var rev: bool = h.armed and h._action.is_empty() and (h.stance == "dagger" or h.carry_w > 0.5)
	h.grip_flip = move_toward(h.grip_flip, 1.0 if rev else 0.0, delta / (TWIRL_IN if rev else TWIRL_OUT))
	w.basis = Basis(Vector3.UP, PI * Humanoid._ease(h.grip_flip))

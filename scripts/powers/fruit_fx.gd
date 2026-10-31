class_name FruitFX
## The Driftfruit powers' look (1.27, FruitCastState): each fruit's signature in three beats (driftwake-fx layering):
## the wind-up (the power gathering in the body: windup), the release on the strike key (release), and for the
## ultimates the moment (a slow beat, a flash, a pillar). Everything goes through Net.fx so every screen sees it;
## slow motion, camera kick and shake stay on our own screen. Each power's own impact (a ring where it lands, the bolt,
## the crater) stays in its PowerComponent function.

## [core, accent] per fruit: the body of the effect and its sparks.
const COLS := {
	"storm": [Color(0.72, 0.84, 1.0), Color(1.0, 0.95, 0.5)],
	"gust": [Color(0.85, 0.97, 0.92), Color(0.55, 0.85, 0.78)],
	"wolf": [Color(0.9, 0.16, 0.12), Color(0.25, 0.04, 0.05)],
	"bear": [Color(0.78, 0.58, 0.38), Color(0.45, 0.3, 0.2)],
	"vine": [Color(0.4, 0.8, 0.28), Color(0.85, 0.95, 0.4)],
	"iron": [Color(0.74, 0.76, 0.82), Color(1.0, 0.68, 0.32)],
	"bubble": [Color(0.8, 0.95, 1.0), Color(1.0, 0.75, 0.95)],
	"clockwork": [Color(0.98, 0.8, 0.4), Color(0.62, 0.45, 0.2)],
	"echo": [Color(0.6, 0.82, 0.96), Color(0.95, 0.97, 1.0)],
	"ember": [Color(1.0, 0.55, 0.15), Color(1.0, 0.9, 0.4)],
}
## Each fruit's sound at the release (FX.SOUNDS), and at an ultimate's moment.
const SOUND := {"storm": "jelly_zap", "gust": "whoosh_big", "wolf": "slice_heavy", "bear": "punch_heavy", "vine": "whoosh",
	"iron": "clash", "bubble": "blip_high", "clockwork": "clack", "echo": "bell", "ember": "fire_burst"}
const ULT_SOUND := {"storm": "cannon_hit", "gust": "whoosh_big", "wolf": "howl", "bear": "roar", "vine": "wood_crack",
	"iron": "cannon_hit", "bubble": "splash_big", "clockwork": "bell", "echo": "bell", "ember": "fire_blast"}


static func core(fruit: String) -> Color:
	return (COLS.get(fruit, [Color.WHITE, Color.WHITE]) as Array)[0]


static func accent(fruit: String) -> Color:
	return (COLS.get(fruit, [Color.WHITE, Color.WHITE]) as Array)[1]


## Where the hands are, about, for a pose at its strike: in front of the chest along `dir`, up for the sky poses, low
## for the ground ones.
static func hand_at(p: Node3D, dir: Vector3, pose: String) -> Vector3:
	var chest := p.global_position + Vector3(0, 1.25, 0)
	match pose:
		"df_sky", "df_uppercut", "df_burst":
			return chest + Vector3(0, 0.95, 0) + dir * 0.2
		"df_slam", "df_stomp":
			return p.global_position + Vector3(0, 0.15, 0) + dir * 0.7
		"df_self", "df_roar":
			return chest + dir * 0.35
	return chest + dir * 0.85


## The power gathering in the body over `secs` (the wind-up): drawn in to the hands, and each fruit's own tell.
static func windup(p: Node3D, fruit: String, pose: String, dir: Vector3, secs: float, ult: bool) -> void:
	var net := p.get_node("/root/Net")
	var c := core(fruit)
	var a := accent(fruit)
	var chest := p.global_position + Vector3(0, 1.2, 0)
	var hand := hand_at(p, dir, pose)
	net.fx("gather", [hand, 2.6 if ult else 1.3, c, secs, 22 if ult else 12])
	match fruit:
		"storm":
			# lightning crawling over the body, more of it the bigger the power
			for i in range(5 if ult else 3):
				var o := Vector3(randf_range(-0.5, 0.5), randf_range(-0.6, 0.7), randf_range(-0.5, 0.5))
				net.fx("bolt", [chest + o, chest + o + Vector3(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)), a, 0.04, secs])
		"gust":
			net.fx("vortex", [p, secs + 0.15, 1.2 if not ult else 2.4, 2.2, c])
			net.fx("gust", [p.global_position + Vector3(0, 0.3, 0), Vector3.UP, 10, 3.0])
		"wolf":
			net.fx("shadow_wisps", [chest, Vector3.UP, 12 if ult else 7, c, 2.5])
		"bear":
			net.fx("dust_ring", [p.global_position, 14 if ult else 8, 0.9])
			net.fx("shadow_wisps", [chest, Vector3.UP, 6, a, 2.0])
		"vine":
			net.fx("petals", [chest, Vector3.UP, 12 if ult else 6, c, 2.0])
			net.fx("ground_vines", [p.global_position, dir])
		"iron":
			net.fx("sparkle", [hand, 14 if ult else 8, c])
			net.fx("muzzle_sparks", [hand, Vector3.UP, 8, a])
		"bubble":
			net.fx("bubbles", [hand, 10 if ult else 5])
			net.fx("sparkle", [hand, 6, a])
		"clockwork":
			# rings turning round the hands: a clock being wound
			for i in range(3 if ult else 2):
				var n := dir.rotated(Vector3.UP, i * 0.9).normalized()
				net.fx("ring", [hand, n, 0.5 + i * 0.25, c, secs, 0.05])
		"echo":
			for i in range(3):
				net.fx("ring", [hand, dir, 0.25 + i * 0.3, c, secs * (0.5 + i * 0.25), 0.04])
		"ember":
			net.fx("flame", [hand, 12 if ult else 6, 0.5, 0.4, 0.2])
	if ult:
		net.fx("motes", [p.global_position + Vector3(0, 0.2, 0), Vector3.UP, 16, c, 3.0])
		net.fx("sfx", ["haki", p.global_position, -6.0, 0.03, 0.8])


## The release on the strike key: the shock leaving the hands along `dir`, a glint, the ground answering for the
## ground poses, and the fruit's sound. Local juice (shake, slow motion) only on the caster's screen.
static func release(p: Node3D, fruit: String, pose: String, dir: Vector3, ult: bool) -> void:
	var net := p.get_node("/root/Net")
	var c := core(fruit)
	var a := accent(fruit)
	var hand := hand_at(p, dir, pose)
	net.fx("star_glint", [hand, 1.2 if ult else 0.7, a, 0.2])
	match pose:
		"df_thrust", "df_pull", "df_sweep":
			net.fx("punch_wind", [hand, dir, 3.6 if ult else 2.6, c, ult])
		"df_slam", "df_stomp":
			net.fx("dust_ring", [p.global_position, 20, 1.3])
			net.fx("debris", [p.global_position + dir * 0.6, Vector3.UP, 10, a])
			net.fx("ground_crack", [p.global_position, dir, 5.0, c])
		"df_uppercut", "df_sky":
			net.fx("speed_lines", [hand, Vector3.UP, c, 10])
		"df_spin", "df_roar":
			net.fx("ring", [p.global_position + Vector3(0, 1.0, 0), Vector3.UP, 3.6, c, 0.32, 0.3])
			net.fx("ring", [p.global_position + Vector3(0, 0.1, 0), Vector3.UP, 4.4, a, 0.4, 0.1])
		"df_dash", "df_leap":
			net.fx("speed_lines", [p.global_position + Vector3(0, 1.0, 0), dir if pose == "df_dash" else Vector3.UP, c, 12])
			net.fx("afterimage", [p.get("body_model"), c])
		"df_self", "df_burst":
			net.fx("ring", [p.global_position + Vector3(0, 0.1, 0), Vector3.UP, 2.4, c, 0.45, 0.14])
	# each fruit's own mark on the release
	match fruit:
		"storm":
			for i in range(4):
				net.fx("bolt", [hand, hand + dir * randf_range(1.2, 2.6) + Vector3(randf_range(-0.9, 0.9), randf_range(-0.5, 0.9), randf_range(-0.9, 0.9)), c, 0.1, 0.2, randi()])
		"gust":
			net.fx("gust", [hand, dir, 14, 7.0])
		"wolf", "bear":
			net.fx("cut_lines", [hand, 5 if fruit == "wolf" else 3, c, 0.4])
		"vine":
			net.fx("petals", [hand, dir, 10, c, 4.0])
		"iron":
			net.fx("muzzle_sparks", [hand, dir, 16, a])
		"bubble":
			net.fx("bubbles", [hand, 12])
		"clockwork":
			net.fx("ring", [hand, dir, 1.4, c, 0.35, 0.12])
		"echo":
			for i in range(3):
				net.fx("ring", [hand + dir * i * 1.2, dir, 0.8 + i * 0.5, c, 0.3 + i * 0.1, 0.1])
		"ember":
			net.fx("flame", [hand, 16, 0.7, 0.5, 0.3])
			net.fx("embers", [hand, dir, 10, c, 4.0])
	net.fx("sfx", [str(SOUND.get(fruit, "whoosh")), hand, -3.0, 0.08, 1.0])
	if p.get("is_local"):
		p.call("cam_shake", 0.35 if pose in ["df_slam", "df_stomp", "df_hug"] else 0.15, 0.25)
	if ult:
		moment(p, fruit)


## An ultimate's moment: a beat of slow motion, the camera kicked, the screen washed in the fruit's colour, a pillar of
## it, and the fruit's big sound.
static func moment(p: Node3D, fruit: String) -> void:
	var net := p.get_node("/root/Net")
	var c := core(fruit)
	column(p, p.global_position, fruit, 7.0, 1.4)
	net.fx("screen_flash", [p.global_position, Color(c.r, c.g, c.b, 0.18), 0.2])
	net.fx("sfx", [str(ULT_SOUND.get(fruit, "cannon_hit")), p.global_position, 0.0, 0.03, 0.85])
	if p.get("is_local"):
		p.get_node("/root/CombatManager").apply_slowmo(0.3, 0.35)
		p.call("cam_kick", 0.6, 0.8)
		p.call("cam_shake", 0.5, 0.45)


## Where a power lands (`size` about its radius in m, `dir` the way it travelled): a flash and a light in the fruit's
## colour, its signature shape, and what's left after (dust, sparks, petals). Called from the PowerComponent functions
## at every place a power strikes, so a cast and its forms look the same.
static func impact(p: Node3D, at: Vector3, fruit: String, size: float = 1.0, dir: Vector3 = Vector3.ZERO) -> void:
	var net := p.get_node("/root/Net")
	var c := core(fruit)
	var a := accent(fruit)
	var up := at + Vector3(0, 0.9, 0)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.05 else -p.global_basis.z
	net.fx("star_glint", [up, 0.8 + size * 0.4, a, 0.22])
	net.fx("flash", [up, 1.2 + size * 0.6, c.lightened(0.4), "glint", 0.22])
	net.fx("flash_light", [up, c, 7.0, 4.0 + size * 3.0, 0.3])
	net.fx("ring", [at + Vector3(0, 0.08, 0), Vector3.UP, 1.2 + size * 1.6, c, 0.4, 0.32])
	net.fx("ring", [at + Vector3(0, 0.12, 0), Vector3.UP, 0.6 + size * 0.8, c.lightened(0.5), 0.25, 0.22])
	match fruit:
		"storm":
			# bolts down out of nowhere onto it, crackling out along the ground
			for i in range(2 + int(size)):
				var top := at + Vector3(randf_range(-0.6, 0.6), 4.5 + randf() * 2.5, randf_range(-0.6, 0.6))
				net.fx("bolt", [up, top, c, 0.1 + 0.04 * size, 0.22, randi()])
			for i in range(3):
				var out := at + Vector3.UP * 0.1 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * (1.0 + size)
				net.fx("bolt", [at + Vector3.UP * 0.1, out, a, 0.05, 0.18, randi()])
		"gust":
			net.fx("gust", [at + Vector3.UP * 0.4, flat if dir != Vector3.ZERO else Vector3.UP, 18, 8.0])
			net.fx("puff_ring", [at, "dust_low", 8, 0.4, 1.0 + size * 0.4, 0.7, Color.WHITE, 6.0 + size * 2.0])
			net.fx("speed_lines", [up, Vector3.UP, c, 8])
		"wolf":
			net.fx("cut_lines", [up, 4 + int(size * 2.0), c, 0.45, randi()])
			net.fx("shadow_wisps", [up, Vector3.UP, 10, c, 3.0])
		"bear":
			net.fx("heavy_dust", [at, 14, 0.9 + size * 0.3])
			net.fx("debris", [at, Vector3.UP, 10, a, 6.0])
			for i in range(3):
				net.fx("ground_crack", [at, flat.rotated(Vector3.UP, i * TAU / 3.0), 1.5 + size, Color(0, 0, 0, 0), randi()])
		"vine":
			net.fx("ground_vines", [at, flat])
			net.fx("petals", [up, Vector3.UP, 14, c, 4.0])
			net.fx("petals", [up, Vector3.UP, 6, a, 3.0])
		"iron":
			for i in range(4):
				net.fx("muzzle_sparks", [up, Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized(), 10, a])
			net.fx("debris", [at, Vector3.UP, 8, c, 5.0])
			net.fx("heavy_dust", [at, 10, 0.8 + size * 0.3])
		"bubble":
			net.fx("bubbles", [up, 10 + int(size * 4.0)])
			net.fx("water_ring", [at + Vector3.UP * 0.05, 0.8 + size, 0.8])
			net.fx("droplets", [up, Vector3.UP, 10, c, 4.0])
		"clockwork":
			for i in range(3):
				net.fx("ring", [up, Vector3.UP.rotated(Vector3.RIGHT, 0.4 * i), 0.5 + 0.35 * i + size * 0.3, c if i % 2 == 0 else a, 0.5, 0.06])
			net.fx("motes", [up, Vector3.UP, 10, c, 2.0])
		"echo":
			for i in range(4):
				net.fx("ring", [up, flat if dir != Vector3.ZERO else Vector3.UP, 0.4 + i * (0.4 + size * 0.2), c, 0.25 + i * 0.08, 0.06])
			net.fx("ring", [at + Vector3(0, 0.05, 0), Vector3.UP, 1.5 + size * 1.5, a, 0.5, 0.05])
		"ember":
			net.fx("fire_ring", [at, 0.8 + size, 20 + int(size * 10.0)])
			net.fx("flame", [up, 14, 0.8, 0.5, 0.3 + size * 0.2])
			net.fx("embers", [up, Vector3.UP, 12, c, 5.0])


## A column of the fruit's power going up at `at` (ultimates and awakenings): rings rising and widening up it, lines
## streaming up, motes drifting off. In the fruit's own colours (FX.light_pillar is fire's, gold at its core).
static func column(p: Node3D, at: Vector3, fruit: String, height: float = 6.0, radius: float = 1.2) -> void:
	var net := p.get_node("/root/Net")
	var c := core(fruit)
	var a := accent(fruit)
	for i in range(5):
		var h := 0.2 + height * float(i) / 5.0
		net.fx("ring", [at + Vector3(0, h, 0), Vector3.UP, radius * (0.6 + 0.2 * i), c if i % 2 == 0 else a, 0.35 + 0.08 * i, 0.12])
	net.fx("speed_lines", [at + Vector3(0, height * 0.4, 0), Vector3.UP, c, 16, height, 0.35])
	net.fx("motes", [at + Vector3(0, 0.4, 0), Vector3.UP, 18, c, 4.0])
	net.fx("flash_light", [at + Vector3(0, 1.5, 0), c, 6.0, 8.0, 0.4])

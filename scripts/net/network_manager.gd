extends Node
## Co-op multiplayer ("Net" autoload): a listen server over ENet. One player
## hosts (their world, their enemies, their save); up to three friends join
## with a character from their own save slots.
##
## Who simulates what:
## * Every captain is simulated on its own player's machine (movement,
##   states, input) and sent to the others ~20 times a second; the other
##   machines show a puppet (the same Player scene with is_local = false)
##   played back a tenth of a second in the past, so it moves smoothly.
## * The host runs the enemies, the world and the loot rolls. Clients show
##   enemy puppets. A client's hit on an enemy is detected on the client
##   (what you saw is what you hit) and applied on the host.
## * Hits on a captain are decided on that captain's own machine: an enemy's
##   swing hits you if it touches you on your screen, so dodges, parries and
##   blocks are judged against what you saw.
## * The ship belongs to whoever is at the helm (the host when nobody is).
##
## Single player never touches the network: `active` stays false, is_host()
## is true and every helper falls back to the plain local behaviour.

signal status_changed(text: String)
## Client: the host let us in - load the world now.
signal accepted
signal failed(reason: String)
signal roster_changed

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 3
const PROTOCOL := 2
const SNAP_RATE := 20.0
## Puppets are shown this far in the past (seconds), between two snapshots.
const INTERP := 0.1
const PLAYER_SCENE := "res://scenes/player/player.tscn"
## Kill experience goes to everyone this close to the kill.
const XP_RANGE := 40.0
const CONNECT_TIMEOUT := 10.0
## What clients may ask the host to do to an enemy (see ask_host).
const HOST_CALLS := ["parried", "vine_yank", "rooted", "burn", "alert", "net_knock", "net_push"]

var active: bool = false
var hosting: bool = false
## peer id -> Player (yours and the puppets)
var players: Dictionary = {}
## peer id -> what that player told us about their captain (name, look...)
var roster: Dictionary = {}
var local_player: Node = null
var world_ready: bool = false
## Who simulates the ship (peer id).
var ship_owner: int = 1
## Our captain, as sent to the others when joining (name, look).
var my_info: Dictionary = {}
## Round trip to the host, seconds (clients).
var rtt: float = 0.0
## Everyone's round trip in ms (the host collects them and passes them on).
var pings: Dictionary = {}
## Who sits where (cannons): node key -> net id. The host hands them out.
var seats: Dictionary = {}
var _pings_t: float = 0.0
## Client: the save slot we joined with.
var join_slot: int = 0
var last_error: String = ""

var _peer: ENetMultiplayerPeer
var _offset: float = 0.0
var _have_offset: bool = false
var _best_rtt: float = INF
var _ping_t: float = 0.0
var _snap_t: float = 0.0
var _connect_t: float = 0.0
var _events: Array = []
var _applying: bool = false
var _receiving: bool = false
var _cache: Dictionary = {}
var _buffers: Dictionary = {}
var _waiting_hello: Array = []
var _pending_spawns: Array = []
var _pending_sync: Dictionary = {}
var _pending_place: Vector3 = Vector3.INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -50
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


# ==========================================================================
# Queries
# ==========================================================================
func is_host() -> bool:
	return not active or hosting


func is_client() -> bool:
	return active and not hosting


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


## More than one captain in the session.
func coop() -> bool:
	return active and roster.size() > 1


## The shared session clock (seconds): the host's clock, everywhere.
func time() -> float:
	return Time.get_ticks_usec() * 0.000001 + _offset


func render_time() -> float:
	return time() - INTERP


## Every captain in the world (just yours in single player).
func all_players() -> Array:
	var out: Array = []
	if not active or players.is_empty():
		var gm := get_node_or_null("/root/GameManager")
		if gm and gm.player and is_instance_valid(gm.player) and gm.player.is_inside_tree():
			out.append(gm.player)
		return out
	for p in players.values():
		if p and is_instance_valid(p) and p.is_inside_tree():
			out.append(p)
	return out


## Nearest captain to `pos` that passes `ok` (a Callable taking the player),
## preferring `keep` unless another is clearly (30%) closer.
func nearest_player(pos: Vector3, ok: Callable = Callable(), keep: Node = null) -> Node:
	var best: Node = null
	var best_d := INF
	var keep_d := INF
	for p in all_players():
		if ok.is_valid() and not bool(ok.call(p)):
			continue
		var d := (p as Node3D).global_position.distance_to(pos)
		if p == keep:
			keep_d = d
		if d < best_d:
			best_d = d
			best = p
	if keep != null and keep_d < INF and keep_d < best_d * 1.3 + 1.0:
		return keep
	return best


## Enemies get tougher with more captains around: x1, x1.6, x2.2, x2.8.
func hp_scale() -> float:
	return 1.0 + 0.6 * float(crew_size() - 1)


func crew_size() -> int:
	return maxi(roster.size(), 1) if active else 1


## How many extra attackers an enemy group lets swing at once (3-4 captains
## keep more of the crew busy).
func extra_attackers() -> int:
	return clampi(crew_size() - 2, 0, 2)


## Round trip to the host in ms for a captain (the host itself: 0).
func ping_ms(id: int) -> int:
	if id == 1:
		return 0
	if id == my_id() and not hosting:
		return int(rtt * 1000.0)
	return int(pings.get(id, -1))


# ==========================================================================
# Hosting and joining
# ==========================================================================
func host_game(port: int = DEFAULT_PORT) -> int:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		last_error = "Couldn't open port %d (%s)" % [port, error_string(err)]
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	active = true
	hosting = true
	_offset = 0.0
	_have_offset = true
	ship_owner = 1
	roster = {1: my_info.duplicate(true)}
	world_ready = false
	# hosting from inside a running game (pause menu)
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.player and is_instance_valid(gm.player) and gm.player.is_inside_tree():
		world_ready = true
		register_local(gm.player)
	roster_changed.emit()
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> int:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		last_error = "Couldn't connect (%s)" % error_string(err)
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	active = true
	hosting = false
	world_ready = false
	_have_offset = false
	_best_rtt = INF
	_connect_t = CONNECT_TIMEOUT
	status_changed.emit("Connecting to %s..." % address)
	return OK


## Close the session (back to single player).
func leave() -> void:
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var was := active
	active = false
	hosting = false
	world_ready = false
	for id in players.keys():
		var p = players[id]
		if p and is_instance_valid(p) and not p.is_local:
			p.queue_free()
	players.clear()
	roster.clear()
	pings.clear()
	seats.clear()
	_events.clear()
	_buffers.clear()
	_cache.clear()
	_waiting_hello.clear()
	_pending_spawns.clear()
	_pending_sync = {}
	_pending_place = Vector3.INF
	ship_owner = 1
	_connect_t = 0.0
	if local_player and is_instance_valid(local_player):
		local_player.input_locked = false
	local_player = null
	if was:
		roster_changed.emit()


func _on_connected() -> void:
	_connect_t = 0.0
	status_changed.emit("Connected - waiting for the host...")
	_hello.rpc_id(1, PROTOCOL, my_info)


func _on_connect_failed() -> void:
	last_error = "Couldn't reach the host"
	leave()
	failed.emit(last_error)


func _on_server_gone() -> void:
	last_error = "The host closed the session"
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.player and is_instance_valid(gm.player):
		SaveGame.save(gm.player)
	leave()
	failed.emit(last_error)
	_back_to_title.call_deferred()


func _back_to_title() -> void:
	var tree := get_tree()
	if tree.current_scene and tree.current_scene.scene_file_path != SaveGame.TITLE_SCENE:
		tree.paused = false
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.show_title_message(last_error)
		if GameMenu.is_open():
			GameMenu.close()
		tree.change_scene_to_file(SaveGame.TITLE_SCENE)


func _on_peer_connected(_id: int) -> void:
	pass  # the newcomer introduces itself with _hello


func _on_peer_disconnected(id: int) -> void:
	_despawn(id)
	pings.erase(id)
	if hosting:
		var freed := false
		for k in seats.keys():
			if int(seats[k]) == id:
				seats.erase(k)
				freed = true
		if freed:
			_seats.rpc(seats)
	if hosting:
		_despawn_all.rpc(id)
		if ship_owner == id:
			_set_ship_owner(1)
		_rescale_enemies()


## Client -> host: who I am.
@rpc("any_peer", "call_remote", "reliable")
func _hello(proto: int, info: Dictionary) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if proto != PROTOCOL:
		_rejected.rpc_id(id, "Different game version")
		return
	if not world_ready:
		_waiting_hello.append([id, info])
		return
	_accept(id, info)


func _accept(id: int, info: Dictionary) -> void:
	roster[id] = info
	_welcome.rpc_id(id, roster, time())
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	last_error = reason
	leave()
	failed.emit(reason)


## Host -> new client: you're in (here's everyone, and the clock).
@rpc("authority", "call_remote", "reliable")
func _welcome(r: Dictionary, host_t: float) -> void:
	roster = r
	if not _have_offset:
		_offset = host_t - Time.get_ticks_usec() * 0.000001
	status_changed.emit("Joining...")
	roster_changed.emit()
	accepted.emit()


## Our world finished loading (GameManager, after the save is applied).
func world_loaded() -> void:
	if not active:
		return
	world_ready = true
	if local_player:
		local_player.name = "P%d" % my_id()
	if hosting:
		for h in _waiting_hello:
			_accept(int(h[0]), h[1])
		_waiting_hello.clear()
	else:
		_in_world.rpc_id(1, _player_info())
	for s in _pending_spawns:
		_spawn_puppet(int(s[0]), s[1])
	_pending_spawns.clear()
	if not _pending_sync.is_empty():
		_apply_world_sync(_pending_sync)
		_pending_sync = {}
	if _pending_place != Vector3.INF:
		_place_local(_pending_place)
		_pending_place = Vector3.INF


func _player_info() -> Dictionary:
	var info := my_info.duplicate(true)
	if local_player and is_instance_valid(local_player) and local_player.has_method("net_info"):
		info.merge(local_player.net_info(), true)
	return info


## Client -> host: my world is up, put me in.
@rpc("any_peer", "call_remote", "reliable")
func _in_world(info: Dictionary) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	roster[id] = info
	# everyone already here, to the newcomer
	var me := _player_info()
	roster[1] = me
	_spawn_remote.rpc_id(id, 1, me)
	for pid in players.keys():
		if pid != 1 and pid != id and roster.has(pid):
			_spawn_remote.rpc_id(id, pid, roster[pid])
	# the newcomer, to everyone (and here)
	_spawn_puppet(id, info)
	for pid in roster.keys():
		if pid != 1 and pid != id:
			_spawn_remote.rpc_id(pid, id, info)
	_world_sync.rpc_id(id, _world_state())
	var spot := Vector3.INF
	if local_player and is_instance_valid(local_player):
		var lp := local_player as Node3D
		spot = lp.global_position + lp.global_basis.x * 1.5 + Vector3.UP * 0.3
	_place.rpc_id(id, spot)
	_rescale_enemies()
	roster_changed.emit()
	var nm := str(info.get("name", "A captain"))
	get_tree().call_group("hud", "show_toast", "%s came aboard" % nm)


@rpc("authority", "call_remote", "reliable")
func _spawn_remote(id: int, info: Dictionary) -> void:
	roster[id] = info
	roster_changed.emit()
	if not world_ready:
		_pending_spawns.append([id, info])
		return
	_spawn_puppet(id, info)


@rpc("authority", "call_remote", "reliable")
func _despawn_all(id: int) -> void:
	_despawn(id)


func _despawn(id: int) -> void:
	var p = players.get(id)
	if p and is_instance_valid(p) and not p.is_local:
		var nm := str(roster.get(id, {}).get("name", "A captain"))
		get_tree().call_group("hud", "show_toast", "%s left" % nm)
		p.queue_free()
	players.erase(id)
	roster.erase(id)
	_buffers.erase("P%d" % id)
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _place(pos: Vector3) -> void:
	if pos == Vector3.INF:
		return
	if not world_ready:
		_pending_place = pos
		return
	_place_local(pos)


func _place_local(pos: Vector3) -> void:
	if local_player and is_instance_valid(local_player):
		var lp := local_player as Node3D
		lp.global_position = pos
		lp.set("velocity", Vector3.ZERO)
		lp.reset_physics_interpolation()


## The local captain entered the world (Player._ready via GameManager).
func register_local(p: Node) -> void:
	local_player = p
	if active:
		players[my_id()] = p
		if world_ready:
			p.name = "P%d" % my_id()


func _spawn_puppet(id: int, info: Dictionary) -> void:
	if id == my_id() or (players.has(id) and is_instance_valid(players[id])):
		return
	var parent: Node = local_player.get_parent() if local_player and is_instance_valid(local_player) else get_tree().current_scene
	if parent == null:
		return
	var p = (load(PLAYER_SCENE) as PackedScene).instantiate()
	p.is_local = false
	p.net_id = id
	p.net_profile = info
	p.name = "P%d" % id
	parent.add_child(p)
	var lp := local_player as Node3D
	p.global_position = lp.global_position if lp else Vector3.ZERO
	players[id] = p


# ==========================================================================
# Clock
# ==========================================================================
func _process(delta: float) -> void:
	if not active:
		return
	if _connect_t > 0.0:
		_connect_t -= delta
		if _connect_t <= 0.0 and not hosting and roster.is_empty():
			last_error = "No answer from the host"
			leave()
			failed.emit(last_error)
			return
	if not hosting:
		_ping_t -= delta
		if _ping_t <= 0.0 and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_ping_t = 0.25 if not _have_offset else 1.0
			_ping.rpc_id(1, Time.get_ticks_usec() * 0.000001, int(rtt * 1000.0))
	elif roster.size() > 1:
		_pings_t -= delta
		if _pings_t <= 0.0:
			_pings_t = 2.0
			_pings.rpc(pings)
	if not world_ready:
		return
	_snap_t += delta
	if _snap_t >= 1.0 / SNAP_RATE:
		_snap_t = fmod(_snap_t, 1.0 / SNAP_RATE)
		_send_snapshots()
	_apply_events()


@rpc("any_peer", "call_remote", "unreliable")
func _ping(client_t: float, my_ms: int = -1) -> void:
	if hosting:
		var id := multiplayer.get_remote_sender_id()
		if my_ms > 0:
			pings[id] = my_ms
		_pong.rpc_id(id, client_t, time())


@rpc("authority", "call_remote", "unreliable")
func _pings(p: Dictionary) -> void:
	for id in p.keys():
		if int(id) != my_id():
			pings[int(id)] = int(p[id])


@rpc("authority", "call_remote", "unreliable")
func _pong(client_t: float, host_t: float) -> void:
	var now := Time.get_ticks_usec() * 0.000001
	var r := now - client_t
	var off := host_t + r * 0.5 - now
	rtt = r if rtt == 0.0 else lerpf(rtt, r, 0.2)
	if not _have_offset:
		_offset = off
		_have_offset = true
		_best_rtt = r
		return
	_best_rtt = minf(_best_rtt * 1.02, r)
	# trust the quick round trips most
	var k := 0.25 if r <= _best_rtt * 1.3 else 0.03
	_offset = lerpf(_offset, off, k)


# ==========================================================================
# Node keys (paths from the world scene: the same on every machine)
# ==========================================================================
func key_of(n: Node) -> String:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return ""
	var cs := get_tree().current_scene
	if cs == null:
		return ""
	return str(cs.get_path_to(n))


func node_of(key: String) -> Node:
	if key == "":
		return null
	var n = _cache.get(key)
	if n != null and is_instance_valid(n) and (n as Node).is_inside_tree():
		return n
	var cs := get_tree().current_scene
	n = cs.get_node_or_null(NodePath(key)) if cs else null
	if n:
		_cache[key] = n
	else:
		_cache.erase(key)
	return n


# ==========================================================================
# Snapshots: continuous state, interpolated on the other machines
# ==========================================================================
func _send_snapshots() -> void:
	var items: Array = []
	if local_player and is_instance_valid(local_player) and local_player.is_inside_tree():
		items.append(key_of(local_player))
		items.append(local_player.net_pack())
	var ship := _ship()
	if ship and ship_owner == my_id():
		items.append(key_of(ship))
		items.append(ship.net_pack())
	if hosting:
		for n in get_tree().get_nodes_in_group("net_sync"):
			if n.has_method("net_pack") and (n as Node).is_inside_tree():
				items.append(key_of(n))
				items.append(n.net_pack())
	# sent in packets that fit the network's MTU (a fragmented unreliable
	# packet is lost whole if any piece is)
	var t := time()
	var chunk: Array = []
	var size := 0
	for i in range(0, items.size() - 1, 2):
		var sz := var_to_bytes([items[i], items[i + 1]]).size()
		if size + sz > SNAP_BUDGET and not chunk.is_empty():
			_snap.rpc(t, chunk)
			chunk = []
			size = 0
		chunk.append(items[i])
		chunk.append(items[i + 1])
		size += sz
	if not chunk.is_empty():
		_snap.rpc(t, chunk)


const SNAP_BUDGET := 1100


@rpc("any_peer", "call_remote", "unreliable")
func _snap(t: float, items: Array) -> void:
	var from := multiplayer.get_remote_sender_id()
	var own := "P%d" % from
	var ship_key := key_of(_ship()) if ship_owner == from else ""
	for i in range(0, items.size() - 1, 2):
		var key := str(items[i])
		# only the host speaks for enemies; captains only for themselves
		if from != 1 and key != own and key != ship_key:
			continue
		_push(key, t, items[i + 1])


func _push(key: String, t: float, data) -> void:
	var buf: Array = _buffers.get(key, [])
	if not buf.is_empty() and t <= float(buf[-1][0]):
		return
	buf.append([t, data])
	if buf.size() > 40:
		buf.pop_front()
	_buffers[key] = buf


## The snapshots around now - INTERP for a node: [older, newer, blend] (the
## newest twice once we've run past it), or [] before the first one.
func sample(n: Node) -> Array:
	var buf: Array = _buffers.get(key_of(n), [])
	if buf.is_empty():
		return []
	var rt := render_time()
	while buf.size() > 2 and float(buf[1][0]) <= rt:
		buf.pop_front()
	var a: Array = buf[0]
	if buf.size() == 1 or rt <= float(a[0]):
		return [a[1], a[1], 0.0]
	var b: Array = buf[1]
	if rt >= float(b[0]):
		return [b[1], b[1], 0.0]
	return [a[1], b[1], clampf((rt - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)]


## Seconds since the newest snapshot for a node was sent (INF = never).
func snapshot_age(n: Node) -> float:
	var buf: Array = _buffers.get(key_of(n), [])
	return INF if buf.is_empty() else time() - float(buf[-1][0])


# ==========================================================================
# Events: one-shot happenings, played at the same delay as the snapshots
# ==========================================================================
## Tell the other machines' copy of `n` to run net_event(what, args).
func event(n: Node, what: String, args: Array = []) -> void:
	if not active or _applying or not world_ready:
		return
	var k := key_of(n)
	if k != "":
		_ev.rpc(time(), k, what, _enc(args))


@rpc("any_peer", "call_remote", "reliable")
func _ev(t: float, key: String, what: String, args: Array) -> void:
	_events.append([t, 0, key, what, args])


## Run an FX here and on everyone else's screen (at the puppets' delay).
func fx(method: String, args: Array = []) -> Variant:
	var r = FX.callv(method, args)
	if active and not _applying and world_ready and method != "wither_vines":
		_fxr.rpc(time(), method, _enc(args))
	return r


@rpc("any_peer", "call_remote", "reliable")
func _fxr(t: float, method: String, args: Array) -> void:
	_events.append([t, 1, "", method, args])


## Run one of the `_all_*` methods below here now and on every other
## machine (at the puppets' delay).
func everyone(method: String, args: Array = []) -> void:
	callv(method, args)
	if active and world_ready:
		_allr.rpc(time(), method, args)


@rpc("any_peer", "call_remote", "reliable")
func _allr(t: float, method: String, args: Array) -> void:
	if method.begins_with("_all_"):
		_events.append([t, 2, "", method, args])


func _apply_events() -> void:
	if _events.is_empty():
		return
	var rt := render_time()
	var keep: Array = []
	_applying = true
	for e in _events:
		if float(e[0]) > rt:
			keep.append(e)
			continue
		match int(e[1]):
			0:
				var n := node_of(str(e[2]))
				if n and n.has_method("net_event"):
					var args = _dec(e[4])
					if args != null:
						n.call("net_event", str(e[3]), args)
			1:
				_apply_fx(str(e[3]), e[4])
			2:
				if has_method(str(e[3])):
					callv(str(e[3]), e[4])
	_applying = false
	_events = keep


func _apply_fx(method: String, raw: Array) -> void:
	var args = _dec(raw)
	if args == null or not FX.has_method(method):
		return
	# limb vines that were held "until withered" fade on their own here
	match method:
		"arm_vines":
			while args.size() < 2:
				args.append("r")
			if args.size() < 3:
				args.append(1.2)
			elif float(args[2]) < 0.0:
				args[2] = 1.2
		"limb_vines":
			if args.size() < 2:
				args.append(1.2)
			elif float(args[1]) < 0.0:
				args[1] = 1.2
	FX.callv(method, args)


## Arguments over the wire: nodes become keys, HitData a plain array.
func _enc(args: Array) -> Array:
	var out: Array = []
	for a in args:
		if a is Node:
			out.append({"@n": key_of(a)})
		elif a is HitData:
			out.append({"@h": hit_pack(a)})
		elif a is Array:
			out.append(_enc(a))
		elif a is Object:
			out.append(null)
		else:
			out.append(a)
	return out


## null when a node argument doesn't exist here (the call is dropped).
func _dec(args: Array):
	var out: Array = []
	for a in args:
		if a is Dictionary and (a as Dictionary).has("@n"):
			var n := node_of(str(a["@n"]))
			if n == null:
				return null
			out.append(n)
		elif a is Dictionary and (a as Dictionary).has("@h"):
			out.append(hit_unpack(a["@h"]))
		elif a is Array:
			var sub = _dec(a)
			if sub == null:
				return null
			out.append(sub)
		else:
			out.append(a)
	return out


func applying() -> bool:
	return _applying


# ==========================================================================
# Hits
# ==========================================================================
func hit_pack(h: HitData) -> Array:
	return [h.damage, h.knockback_force, h.hitstop_duration, h.camera_shake_intensity, h.stagger_duration,
		h.knockdown, h.ranged, h.dot, h.unblockable, h.haki, h.siege]


func hit_unpack(a: Array) -> HitData:
	var h := HitData.new()
	if a.size() < 10:
		return h
	h.damage = float(a[0])
	h.knockback_force = float(a[1])
	h.hitstop_duration = float(a[2])
	h.camera_shake_intensity = float(a[3])
	h.stagger_duration = float(a[4])
	h.knockdown = bool(a[5])
	h.ranged = bool(a[6])
	h.dot = bool(a[7])
	h.unblockable = bool(a[8])
	h.haki = bool(a[9])
	h.siege = a.size() > 10 and bool(a[10])
	return h


## Hurtbox.take_hit asks first: a hit on another machine's captain goes to
## that machine; a client's hit on an enemy goes to the host. Returns true
## when the hit was sent away (don't apply it here).
func route_hit(hurtbox: Node, data: HitData, attacker: Node) -> bool:
	if not active or _receiving or not world_ready:
		return false
	var o := hurtbox.owner
	if o is Player:
		if o.is_local:
			return false
		_hit_player.rpc_id(o.net_id, key_of(hurtbox), hit_pack(data), key_of(attacker))
		return true
	if hosting:
		return false
	if o and o.is_in_group("net_sync"):
		var apos := (attacker as Node3D).global_position if attacker is Node3D else Vector3.INF
		_hit_enemy.rpc_id(1, key_of(hurtbox), hit_pack(data), key_of(attacker), apos)
		# the blow's feedback is ours (we landed it)
		if attacker == local_player and data.camera_shake_intensity > 0.0 and not data.dot:
			CombatManager.apply_camera_shake(data.camera_shake_intensity)
		return true
	return false


## A hitbox touching another machine's captain is that machine's business
## (it sees the same swing and decides).
func ignore_overlap(hurtbox: Node) -> bool:
	return active and hurtbox.owner is Player and not hurtbox.owner.is_local


@rpc("any_peer", "call_remote", "reliable")
func _hit_enemy(hk: String, hd: Array, ak: String, apos: Vector3 = Vector3.INF) -> void:
	if not hosting:
		return
	var hb := node_of(hk)
	if hb == null or not hb.has_method("take_hit"):
		return
	var at := node_of(ak)
	# blasts hit "from" a point (the knockback pushes away from it): stand a
	# proxy there when the attacker isn't a captain
	if not (at is Player) and apos != Vector3.INF:
		at = _proxy()
		(at as Node3D).global_position = apos
	_receiving = true
	hb.call("take_hit", hit_unpack(hd), at)
	_receiving = false


var _proxy_node: Node3D


func _proxy() -> Node3D:
	if _proxy_node == null or not is_instance_valid(_proxy_node) or not _proxy_node.is_inside_tree():
		_proxy_node = Node3D.new()
		_proxy_node.name = "NetHitOrigin"
		get_tree().current_scene.add_child(_proxy_node)
	return _proxy_node


@rpc("any_peer", "call_remote", "reliable")
func _hit_player(hk: String, hd: Array, ak: String) -> void:
	var hb := node_of(hk)
	if hb == null or not (hb.owner is Player) or not hb.owner.is_local:
		return
	var h := hit_unpack(hd)
	# dodging (no hurtbox right now) lets it pass, like it would locally
	if not hb.get("monitorable") and not h.dot:
		return
	_receiving = true
	hb.call("take_hit", h, node_of(ak))
	_receiving = false


## Clients forward enemy calls (parried, vine_yank...) to the host. Use as
## `if Net.forward(self, "parried", [by]): return` at the top of the method.
func forward(n: Node, method: String, args: Array = []) -> bool:
	if not is_client() or _receiving or not world_ready:
		return false
	_ask.rpc_id(1, key_of(n), method, _enc(args))
	return true


@rpc("any_peer", "call_remote", "reliable")
func _ask(key: String, method: String, args: Array) -> void:
	if not hosting or not (method in HOST_CALLS):
		return
	var n := node_of(key)
	var a = _dec(args)
	if n and a != null and n.has_method(method):
		_receiving = true
		n.callv(method, a)
		_receiving = false


## A gunshot along from-to: everyone checks their own captain (the host right
## away, the others at the puppets' delay, when they see the shot).
## Returns true if a captain stood on the line (on the host's screen).
func shot(from: Vector3, to: Vector3, data: HitData, shooter: Node, radius: float = 0.45) -> bool:
	var hit_any := false
	for p in all_players():
		if _on_line(p, from, to, radius):
			hit_any = true
	_all_shot(from, to, hit_pack(data), key_of(shooter), radius)
	if active and world_ready:
		_allr.rpc(time(), "_all_shot", [from, to, hit_pack(data), key_of(shooter), radius])
	return hit_any


func _on_line(p: Node, from: Vector3, to: Vector3, radius: float) -> bool:
	var a := (p as Node3D).global_position + Vector3(0, 0.2, 0)
	var b := (p as Node3D).global_position + Vector3(0, 1.75, 0)
	var pts := Geometry3D.get_closest_points_between_segments(from, to, a, b)
	return (pts[0] as Vector3).distance_to(pts[1] as Vector3) < radius


func _all_shot(from: Vector3, to: Vector3, hd: Array, sk: String, radius: float) -> void:
	var p := local_player if active else null
	if p == null:
		var gm := get_node_or_null("/root/GameManager")
		p = gm.player if gm else null
	if p == null or not is_instance_valid(p):
		return
	var hb := p.get_node_or_null("Hurtbox")
	if hb == null or not hb.monitorable or not _on_line(p, from, to, radius):
		return
	_receiving = true
	hb.take_hit(hit_unpack(hd), node_of(sk))
	_receiving = false


# ==========================================================================
# Rewards (rolled on the host, collected by each captain for themselves)
# ==========================================================================
func award_xp(amount: int, at: Vector3, reach: float = XP_RANGE) -> void:
	if not active:
		GameManager.award_xp(amount, at)
		return
	everyone("_all_xp", [amount, at, reach])


func _all_xp(amount: int, at: Vector3, reach: float = XP_RANGE) -> void:
	var p := local_player as Node3D
	if p == null or not is_instance_valid(p):
		return
	if at == Vector3.INF or p.global_position.distance_to(at) <= reach:
		GameManager.award_xp(amount, at)


func coins(at: Vector3, count: int) -> void:
	if not active:
		CoinPickup.spawn(get_tree(), at, count)
		return
	everyone("_all_coins", [at, count])


func _all_coins(at: Vector3, count: int) -> void:
	CoinPickup.spawn(get_tree(), at, count)


## A dropped weapon: everyone gets their own to pick up.
func drop_item(id: String, at: Vector3, yaw: float) -> void:
	if not active:
		_all_drop(id, at, yaw)
		return
	everyone("_all_drop", [id, at, yaw])


func _all_drop(id: String, at: Vector3, yaw: float) -> void:
	var item := ItemDB.get_item(id)
	if item == null:
		return
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var st := ItemStack.new()
	st.item = item
	st.quantity = 1
	var items: Array[ItemStack] = [st]
	bag.setup(items, false)
	get_tree().current_scene.add_child(bag)
	bag.global_position = at
	var mi := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi:
		mi.mesh = Props.weapon_mesh(item.weapon_model)
		mi.rotation = Vector3(PI * 0.5, yaw, 0)
		mi.position = Vector3(0, 0.06, 0)


# --------------------------------------------------------------------------
# Dropped items (shared bags): the host keeps what's in them
# --------------------------------------------------------------------------
var _drop_seq: int = 0
var _local_drop_seq: int = 0


## Drop items on the ground ([[item_ref, qty], ...]). Single player: a plain
## bag. Co-op: a bag every captain sees; the host owns its contents.
func drop_items(stacks: Array, at: Vector3) -> void:
	if not active or not world_ready:
		_local_drop_seq += 1
		_make_drop("L%d" % _local_drop_seq, stacks, at, false)
		return
	if hosting:
		_host_drop(stacks, at)
	else:
		_drop_req.rpc_id(1, stacks, at)


@rpc("any_peer", "call_remote", "reliable")
func _drop_req(stacks: Array, at: Vector3) -> void:
	if hosting:
		_host_drop(stacks, at)


func _host_drop(stacks: Array, at: Vector3) -> void:
	_drop_seq += 1
	var id := "D%d" % _drop_seq
	_make_drop(id, stacks, at, true)
	_drop_spawn.rpc(id, stacks, at)


@rpc("authority", "call_remote", "reliable")
func _drop_spawn(id: String, stacks: Array, at: Vector3) -> void:
	if world_ready:
		_make_drop(id, stacks, at, true)


func _make_drop(id: String, stacks: Array, at: Vector3, shared: bool) -> Node:
	var cs := get_tree().current_scene
	if cs == null or cs.get_node_or_null("Drop_" + id):
		return null
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	for e in stacks:
		var it := SaveGame.item_from(e[0])
		if it:
			var st := ItemStack.new()
			st.item = it
			st.quantity = int(e[1])
			items.append(st)
	if items.is_empty():
		bag.free()
		return null
	bag.setup(items, false)
	if shared:
		bag.shared_id = id
	bag.name = "Drop_" + id
	cs.add_child(bag)
	bag.global_position = at
	var mi := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi:
		var only: ItemData = items[0].item if items.size() == 1 else null
		if only and only.is_weapon():
			mi.mesh = Props.weapon_mesh(only.weapon_model)
			mi.rotation = Vector3(PI * 0.5, randf() * TAU, 0)
			mi.position = Vector3(0, 0.06, 0)
		elif only and only.devil_fruit != "":
			mi.mesh = Props.devil_fruit_mesh("devil_fruit_" + only.devil_fruit)
			mi.position = Vector3(0, 0.1, 0)
		else:
			mi.mesh = Props.sack_mesh()
			mi.position = Vector3.ZERO
	return bag


func _shared_bag(id: String) -> LootBag:
	var cs := get_tree().current_scene
	return cs.get_node_or_null("Drop_" + id) as LootBag if cs else null


## Take from a shared bag: the host checks it's still there, then hands it over.
func bag_take(bag: LootBag, item: ItemData, qty: int) -> void:
	if hosting or not active:
		var got := _host_take(bag.shared_id, SaveGame.item_ref(item), qty)
		if got > 0 and local_player:
			local_player.inventory_component.add_item(item, got)
	else:
		_take_req.rpc_id(1, bag.shared_id, SaveGame.item_ref(item), qty)


@rpc("any_peer", "call_remote", "reliable")
func _take_req(id: String, ref: Array, qty: int) -> void:
	if not hosting:
		return
	var got := _host_take(id, ref, qty)
	if got > 0:
		_take_ok.rpc_id(multiplayer.get_remote_sender_id(), ref, got)


func _host_take(id: String, ref: Array, qty: int) -> int:
	var bag := _shared_bag(id)
	var item := SaveGame.item_from(ref)
	if bag == null or item == null:
		return 0
	var i := bag.find_stack(item)
	if i < 0:
		return 0
	var got := mini(qty, bag.contents[i].quantity)
	bag._remove(i, got)
	var r := bag.refs()
	_bag_contents.rpc(id, r)
	bag.set_contents(r)
	return got


@rpc("authority", "call_remote", "reliable")
func _take_ok(ref: Array, qty: int) -> void:
	var item := SaveGame.item_from(ref)
	if item and local_player and is_instance_valid(local_player):
		local_player.inventory_component.add_item(item, qty)


## Put something into a shared bag (it already left our bag).
func bag_store(bag: LootBag, item: ItemData, qty: int) -> void:
	if hosting or not active:
		_host_store(bag.shared_id, SaveGame.item_ref(item), qty)
	else:
		_store_req.rpc_id(1, bag.shared_id, SaveGame.item_ref(item), qty)


@rpc("any_peer", "call_remote", "reliable")
func _store_req(id: String, ref: Array, qty: int) -> void:
	if hosting:
		_host_store(id, ref, qty)


func _host_store(id: String, ref: Array, qty: int) -> void:
	var bag := _shared_bag(id)
	var item := SaveGame.item_from(ref)
	if item == null:
		return
	if bag == null:
		# gone meanwhile (someone emptied it): drop it fresh where it was
		return
	bag.add_stack(item, qty)
	var r := bag.refs()
	_bag_contents.rpc(id, r)
	bag.set_contents(r)


@rpc("authority", "call_remote", "reliable")
func _bag_contents(id: String, r: Array) -> void:
	var bag := _shared_bag(id)
	if bag:
		bag.set_contents(r)


## A damage number over something, on every screen.
func damage_number(amount: float, at: Vector3) -> void:
	if active:
		everyone("_all_number", [amount, at])
	else:
		_all_number(amount, at)


func _all_number(amount: float, at: Vector3) -> void:
	var n: Node = (load("res://scenes/effects/damage_number.tscn") as PackedScene).instantiate()
	get_tree().current_scene.add_child(n)
	n.call("setup", amount, at)


## Burning thornbrush, burning for everyone.
func burned(node_name: String) -> void:
	if active and not _burning and world_ready:
		_burn_all.rpc(node_name)


var _burning: bool = false


@rpc("any_peer", "call_remote", "reliable")
func _burn_all(node_name: String, instant: bool = false) -> void:
	_burning = true
	for b in get_tree().get_nodes_in_group("burnable"):
		if str((b as Node).name) == node_name and not bool(b.get("burned")):
			GameManager.mark_burned(node_name)
			if instant:
				b.call("burn_away_instantly")
			else:
				b.call("ignite")
	_burning = false


## Take a Devil Fruit out of a chest: false if someone in this world already
## has (the host keeps the list; a client's claim is sent there).
func claim_fruit(item_id: String) -> bool:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return true
	if gm.fruit_claims.has(item_id):
		return false
	var who: String = local_player.display_name() if local_player and is_instance_valid(local_player) else "captain"
	gm.fruit_claims[item_id] = who
	if active and world_ready:
		if hosting:
			_fruit_claimed.rpc(item_id, who)
		else:
			_claim_fruit.rpc_id(1, item_id, who)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _claim_fruit(item_id: String, who: String) -> void:
	if not hosting:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm and not gm.fruit_claims.has(item_id):
		gm.fruit_claims[item_id] = who
		_fruit_claimed.rpc(item_id, who)


@rpc("authority", "call_remote", "reliable")
func _fruit_claimed(item_id: String, who: String) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.fruit_claims[item_id] = who


# ==========================================================================
# Downed captains
# ==========================================================================
func revive(id: int) -> void:
	if id == my_id():
		if local_player:
			local_player.revive()
	elif active:
		_revive.rpc_id(id, my_id())


@rpc("any_peer", "call_remote", "reliable")
func _revive(by: int) -> void:
	if local_player and is_instance_valid(local_player):
		local_player.revive()
		var nm := str(roster.get(by, {}).get("name", "A crewmate"))
		get_tree().call_group("hud", "show_toast", "%s got you back up" % nm)


## Anyone else still on their feet?
func others_standing() -> bool:
	for p in all_players():
		if p != local_player and p.has_method("is_standing") and p.is_standing():
			return true
	return false


# ==========================================================================
# Map markers (G / middle mouse): "look here" for the whole crew
# ==========================================================================
## Mark a spot (or an enemy: `target` follows it) for everyone.
func mark(pos: Vector3, target: Node = null) -> void:
	var tk := ""
	if target and is_instance_valid(target) and target.is_inside_tree():
		tk = key_of(target)
	everyone("_all_mark", [my_id(), pos, tk])


func _all_mark(id: int, pos: Vector3, tk: String) -> void:
	var nm := "You" if id == my_id() else str(roster.get(id, {}).get("name", "Crewmate"))
	var t: Node = node_of(tk) if tk != "" else null
	get_tree().call_group("hud", "add_marker", id, nm, pos, t)


## The crew colour of a captain (markers, name tags).
func crew_color(id: int) -> Color:
	var cols := [Color(1.0, 0.85, 0.3), Color(0.45, 0.85, 1.0), Color(0.6, 1.0, 0.45), Color(1.0, 0.55, 0.85)]
	var ids: Array = roster.keys()
	ids.sort()
	var i := ids.find(id)
	return cols[maxi(i, 0) % cols.size()]


# ==========================================================================
# Seats (cannons): one captain each, handed out by the host
# ==========================================================================
func seat_holder(n: Node) -> int:
	if not active:
		return 0
	return int(seats.get(key_of(n), 0))


## Ask for a seat. True = it's yours now (host / single player); a client
## gets its answer later (Player.take_seat).
func request_seat(n: Node) -> bool:
	if not active:
		return true
	var k := key_of(n)
	if hosting:
		var h := int(seats.get(k, 0))
		if h != 0 and h != my_id() and players.has(h):
			get_tree().call_group("hud", "show_toast", "A crewmate is on that gun")
			return false
		_set_seat(k, my_id())
		return true
	_want_seat.rpc_id(1, k)
	return false


func release_seat(n: Node) -> void:
	if not active:
		return
	var k := key_of(n)
	if int(seats.get(k, 0)) != my_id():
		return
	if hosting:
		_set_seat(k, 0)
	else:
		seats.erase(k)
		_drop_seat.rpc_id(1, k)


func _set_seat(k: String, id: int) -> void:
	if id == 0:
		seats.erase(k)
	else:
		seats[k] = id
	_seats.rpc(seats)


@rpc("any_peer", "call_remote", "reliable")
func _want_seat(k: String) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	var h := int(seats.get(k, 0))
	if h != 0 and h != id and players.has(h):
		_seat_denied.rpc_id(id)
		return
	_set_seat(k, id)
	_seat_granted.rpc_id(id, k)


@rpc("any_peer", "call_remote", "reliable")
func _drop_seat(k: String) -> void:
	if hosting and int(seats.get(k, 0)) == multiplayer.get_remote_sender_id():
		_set_seat(k, 0)


@rpc("authority", "call_remote", "reliable")
func _seats(s: Dictionary) -> void:
	seats = s.duplicate()


@rpc("authority", "call_remote", "reliable")
func _seat_granted(k: String) -> void:
	var n := node_of(k)
	if n and local_player and is_instance_valid(local_player):
		local_player.take_seat(n)


@rpc("authority", "call_remote", "reliable")
func _seat_denied() -> void:
	get_tree().call_group("hud", "show_toast", "A crewmate is on that gun")


# ==========================================================================
# The ship
# ==========================================================================
func _ship() -> Node:
	return get_tree().get_first_node_in_group("ship")


## Take the wheel (clients ask the host; the answer comes back as the new owner).
func request_helm() -> bool:
	if not active or hosting:
		if ship_owner == 1 or ship_owner == my_id() or not players.has(ship_owner):
			_set_ship_owner(my_id())
			return true
		get_tree().call_group("hud", "show_toast", "Someone else has the wheel")
		return false
	_want_helm.rpc_id(1)
	return false


func release_helm() -> void:
	if not active:
		return
	if hosting:
		if ship_owner == 1:
			return
		_set_ship_owner(1)
	elif ship_owner == my_id():
		_drop_helm.rpc_id(1, _ship().net_pack() if _ship() else [])


@rpc("any_peer", "call_remote", "reliable")
func _want_helm() -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	var host_steering: bool = local_player != null and is_instance_valid(local_player) and local_player.current_state_name() == "Helm"
	if (ship_owner == 1 and not host_steering) or ship_owner == id or not players.has(ship_owner):
		_set_ship_owner(id)
		_helm_granted.rpc_id(id)
	else:
		_helm_denied.rpc_id(id)


@rpc("any_peer", "call_remote", "reliable")
func _drop_helm(state: Array) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if ship_owner == id:
		var ship := _ship()
		if ship and not state.is_empty():
			ship.net_take_over(state)
		_set_ship_owner(1)


@rpc("authority", "call_remote", "reliable")
func _helm_granted() -> void:
	if local_player and is_instance_valid(local_player):
		local_player.take_helm()


@rpc("authority", "call_remote", "reliable")
func _helm_denied() -> void:
	get_tree().call_group("hud", "show_toast", "Someone else has the wheel")


func _set_ship_owner(id: int) -> void:
	var prev := ship_owner
	ship_owner = id
	var ship := _ship()
	if ship and prev != id and id == my_id():
		ship.net_take_over([])
	if hosting:
		_ship_owner.rpc(id, ship.net_pack() if ship and prev == my_id() else [])


@rpc("authority", "call_remote", "reliable")
func _ship_owner(id: int, state: Array) -> void:
	var prev := ship_owner
	ship_owner = id
	var ship := _ship()
	if ship and id == my_id() and prev != id:
		ship.net_take_over(state)


## Everyone: the host changed the weather override / skipped time.
func _all_weather(s: int, at: float, offset: float) -> void:
	var w := get_node_or_null("/root/Weather")
	if w:
		w.net_apply(s, at, offset)


## Host: the crew's ship hull changed.
func ship_hull(v: float) -> void:
	if hosting and world_ready:
		_hull.rpc(v)


@rpc("authority", "call_remote", "reliable")
func _hull(v: float) -> void:
	var ship := _ship()
	if ship and ship.has_method("net_hull"):
		ship.net_hull(v)


# ==========================================================================
# Joining a running world
# ==========================================================================
func _world_state() -> Dictionary:
	var ents: Array = []
	for n in get_tree().get_nodes_in_group("net_sync"):
		ents.append(key_of(n))
	var spawners := {}
	for s in get_tree().get_nodes_in_group("net_spawner"):
		spawners[key_of(s)] = s.net_gen()
	var gm := get_node_or_null("/root/GameManager")
	var drops: Array = []
	for b in get_tree().current_scene.find_children("Drop_D*", "", false, false):
		if b is LootBag and (b as LootBag).shared_id != "":
			drops.append([(b as LootBag).shared_id, (b as LootBag).refs(), (b as Node3D).global_position])
	var ship := _ship()
	return {"ents": ents, "spawners": spawners, "burned": gm.burned.keys() if gm else [], "ship_owner": ship_owner,
		"fruits": gm.fruit_claims.duplicate() if gm else {}, "drops": drops, "seats": seats.duplicate(),
		"hull": float(ship.get("hull")) if ship else 0.0, "weather": _weather_state()}


func _weather_state() -> Array:
	var w := get_node_or_null("/root/Weather")
	return [int(w.forced), float(w.forced_at), float(w.world_offset)] if w else []


@rpc("authority", "call_remote", "reliable")
func _world_sync(state: Dictionary) -> void:
	if not world_ready:
		_pending_sync = state
		return
	_apply_world_sync(state)


func _apply_world_sync(state: Dictionary) -> void:
	ship_owner = int(state.get("ship_owner", 1))
	seats = (state.get("seats", {}) as Dictionary).duplicate()
	var wst: Array = state.get("weather", [])
	var wn := get_node_or_null("/root/Weather")
	if wn and wst.size() >= 3:
		wn.net_apply(int(wst[0]), float(wst[1]), float(wst[2]))
	var ship := _ship()
	if ship and ship.has_method("net_hull") and state.has("hull"):
		ship.net_hull(float(state["hull"]))
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.fruit_claims = (state.get("fruits", {}) as Dictionary).duplicate()
	var sp: Dictionary = state.get("spawners", {})
	for k in sp.keys():
		var s := node_of(str(k))
		if s and s.has_method("net_set_gen"):
			s.net_set_gen(sp[k])
	for nm in state.get("burned", []):
		_burn_all(str(nm), true)
	for d in state.get("drops", []):
		_make_drop(str(d[0]), d[1], d[2], true)
	# enemies the host no longer has (killed before we came)
	var alive := {}
	for k in state.get("ents", []):
		alive[str(k)] = true
	for n in get_tree().get_nodes_in_group("net_sync"):
		if not alive.has(key_of(n)):
			(n as Node).queue_free()


func _rescale_enemies() -> void:
	if not hosting:
		return
	var k := hp_scale()
	for n in get_tree().get_nodes_in_group("net_sync"):
		if n.has_method("net_rescale"):
			n.net_rescale(k)


## Spawners (camps, nests) tell clients when a new wave appears.
func spawned(spawner: Node, gen) -> void:
	if hosting and world_ready:
		_spawner_gen.rpc(key_of(spawner), gen)


@rpc("authority", "call_remote", "reliable")
func _spawner_gen(key: String, gen) -> void:
	var s := node_of(key)
	if s and s.has_method("net_set_gen"):
		s.net_set_gen(gen)


# ==========================================================================
# Menus don't stop the world in co-op
# ==========================================================================
func set_paused(on: bool) -> void:
	if active:
		get_tree().paused = false
		if local_player and is_instance_valid(local_player):
			local_player.input_locked = on
	else:
		get_tree().paused = on

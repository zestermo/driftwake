# Driftwake — Co-op Multiplayer Plan (1–4 player crew)

Status: **phases 0–5 built + round 8 co-op polish** on branch `multiplayer` (2026-10-04, after commit b03ef0d). Phase 6 (online transport beyond direct ENet) is still open. The original plan is kept below; "Implementation notes" at the end say what was actually built and where it differs.

## 1. Goal

Drop-in co-op for 1–4 players: a friend joins your world, you sail one ship together, clear camps, fight bosses, each with your own character, fruit, skills and gear. Single player must keep working exactly as now (it becomes "a session with one player").

## 2. Architecture

**Listen server (one player hosts) with Godot's built-in high-level multiplayer** (MultiplayerAPI + ENetMultiplayerPeer, transport swappable later). No dedicated server, no rollback netcode.

| Thing | Who decides | Why |
|---|---|---|
| Your own movement, states, animations | **Your machine** | Precise control; co-op, so cheating isn't a concern. |
| Enemies (AI, HP, states), loot rolls, world state | **Host** | One brain per enemy; everyone sees the same fight. |
| The ship | **Whoever is at the helm** (host when nobody is) | Steering with no lag. |
| Your hits on an enemy | Detected on the **attacker's** machine → applied on the host | Hits land where you see them. Host still owns guard/block/HP. |
| An enemy hit on you (dodge, parry, block) | **Victim's** machine | I-frames and the parry window are judged against what *you* saw. |
| Cosmetics (ragdolls, hair/cloth, FX) | Every machine locally | Only the *event* that triggers them is sent. |

## 3. Decisions (Zach, 2026-10-04)
1. **Chest loot: instanced.** Every captain opens every chest once (chests are simply local to each machine; opened chests are character data).
2. **Devil fruits: one per world.** Host-arbitrated claim when a fruit is taken out of a chest (first claim wins; the host saves the claims). A crewmate who opens the same chest later finds it without the fruit.
3. **Characters: portable.** Join any world with a character from your own save slots.
4. **Fruit from another world: ignored for now** ("we will worry about this issue at another time"). A joining character keeps whatever fruit it has; no checks.
5. **Online: ENet now, decide later.** Direct IP + port 24680 (LAN, or port-forward for internet). Steam or a relay can replace the peer in Phase 6.
6. **Defaults confirmed:** friendly fire off; nothing pauses with 2+ players; knocked out + teammate revive (~20 s); one shared crew ship.

## 4. Remaining work (Phase 6 and later)
- Online transport: Steam (GodotSteam peer, lobbies + invites) or a free relay/NAT punch (noray / WebRTC). Only `Net.host_game` / `Net.join_game` create the peer, so this is a contained change. (Zach, 2026-10-05: not now.)
- Latency/packet-loss simulation to tune INTERP and parry fairness (not now).
- Cross-world fruit rule (deferred by Zach).
- Still open: quick chat/emotes; boarders and boss crew aren't recreated for someone who joins mid-fight; puppet ragdolls of enemies still simulate locally at the start.
- Done 2026-10-05 (round 8): ping display (party list + own ping), crew map markers (G / middle mouse), kneel while reviving, Observation Haki sense on the targeted captain's screen, puppet wolf aura, 3-4 player tuning (HP x1/1.6/2.2/2.8, more attack turns, bigger boarding parties). Co-op content: crew-manned cannons with host-arbitrated seats, pirate ships (host-run), Captain Morrow boss (AoEs judged per machine), shared hull damage.

## 5. Implementation notes (what was built)

**Net autoload** (`scripts/net/network_manager.gd`). All RPCs live on `/root/Net`. Join flow: client `_hello` → host `_welcome` (roster + clock) → client loads the world with its own save slot → `world_loaded()` → `_in_world` → host spawns puppets on every machine, sends a world sync (live enemies, spawner waves, burnt brush, fruit claims, ship owner) and places the newcomer next to the host. Hosting also works from inside a running game (pause menu → Host Co-op). Title screen → Co-op: Host (pick a save) or Join (IP + pick a save); a disconnect sends you back to the title with the reason.

**Shared clock**: `Net.time()` = host clock via ping/pong offset; `Ocean.clock()` uses it, so swell, ship heave and swim depth match on every screen.

**Replication**: node keys are paths from the world scene (local player renamed `P<id>`, enemies named `G<wave>_<i>` / `B<spot>_<gen>`). Snapshots at 20 Hz (unreliable, chunked under the MTU), shown 0.1 s in the past and interpolated. One-shot events (`Net.event` → `net_event`), FX (`Net.fx`) and rewards (`Net.everyone`) play at the same delay so they line up with what you see.

**Players**: the other captains are the same Player scene with `is_local = false` (no state machine, input, camera or component processing; not in the `"player"` group, so every old "the player" lookup still means you; all captains are in `"players"`). Snapshot: position (ship-local on deck), yaw, lean, state name, HP, flags (haki coat, knocked out, grounded), the Humanoid's animation inputs and held gear (`HumanoidSync`), and the vine rope end. Humanoid one-shot actions, ragdolls and get-ups are mirrored (`Humanoid.net_sync`). Gear/hybrid changes send the new look. Fireballs, flying slashes, vine seeds and burning ground spawn harmless copies on other machines (the owner's copy deals the damage); burns show on every screen.

**Combat**: `Hurtbox.take_hit` → `Net.route_hit` (a hit on another machine's captain goes to that machine; a client's hit on an enemy goes to the host, with the blast origin). Hitboxes ignore other machines' captains (they decide for themselves). Enemy calls from clients (`parried`, `vine_yank`, `rooted`) are forwarded to the host. Gunshots are broadcast as lines and each captain checks their own body. Hitstop is off in co-op (the world can't freeze for one player); shake plays on the attacker's screen.

**Enemies**: host-run (group `net_sync`); clients show puppets that play back snapshots and swing their own copy of the enemy hitbox at the replicated moment, so it can hit you on your screen. Targeting picks the nearest valid captain with stickiness; camp attack turns are handed out per targeted captain (squad cap +2); HP × (1 + 0.5 per extra captain), rescaled on join/leave. Camps and nests respawn only on the host (clearance checked against every captain) and tell clients the new wave. XP goes to every captain within 40 m of a kill; coins and weapon drops spawn for each captain separately.

**Knocked out**: with a crewmate still standing, 0 HP knocks you down for 20 s; a crewmate holds F next to you for 2.5 s to revive you at 30% HP; if time runs out or everyone is down, the usual death + respawn at the ship. HUD: crew list (name, HP, down) and a prompt with progress; nameplates over crewmates.

**Ship**: owned by the helmsman (host by default); the owner simulates and sends the pose, everyone else rides it as a moving platform. Taking the wheel asks the host; leaving hands it back.

**Saves**: playing as a guest saves your character into your slot but keeps that slot's own world (burnt brush, fruit claims, ship and player position); loading as a guest skips the world parts. Each save gets a `char_id`.

**Menus**: in co-op, menus and the character creator don't pause; your captain just stands still (`Player.input_locked`). Load Game is blocked in a session; Quit to Title leaves it.

**Tests**: `tools/nettest.sh [godot|godot47] [""|late|three|hostquit]` runs a host and a client (plus a second client for `three`) headless on localhost: puppets both ways, enemy sync, hits each way, gunshots, kill rewards, knocked out + revive, mirrored actions, fruit claims, spawner waves, burning brush, the helm, guest saves, leaving and the host quitting. All single-player suites still pass on 4.6.3 and 4.7.2.

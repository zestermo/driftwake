---
name: driftwake-coop
description: >
  Make anything in Driftwake work in co-op (1-4 captains, listen server): the Net autoload
  (scripts/net/network_manager.gd), who simulates what (each captain on their own machine, the
  host runs enemies and the world, the helmsman sails the ship), node identity (key_of/node_of),
  snapshots and puppets (net_pack, Net.sample, HumanoidSync, deck-relative positions), one-shot
  events (Net.event / net_event), effects on every screen (Net.fx), "everyone" calls
  (Net.everyone("_all_*")), hits and shots across machines, host-arbitrated requests (seats, the
  helm, fruit claims, shared bags and the ship's storage), joining a running world (world sync),
  guest saves, and the co-op test (nettest.ps1, netclient.gd, nettest_node.gd). Use when adding
  or changing anything a second player must see or affect, when Zach reports a co-op bug ("my
  friend doesn't see...", "desync", "the guest can't..."), or when touching network_manager.gd.
---

# Driftwake co-op

A listen server over ENet: one player hosts their world, up to three join with a captain from
their own save. Single player never touches the network: `Net.active` is false, `is_host()` is
true and every helper falls back to plain local behaviour, so **co-op code paths must also
work with `active == false`**. Roadmap and design notes: `docs/multiplayer_plan.md`.

## Who simulates what

- **Each captain** on their own machine (input, states, movement), sent ~20 times a second
  (`SNAP_RATE`); the others show a puppet (the same Player scene, `is_local = false`) played
  `INTERP` 0.1 s in the past.
- **The host** runs enemies, spawners, loot rolls, ship damage and the world. Clients show
  enemy puppets.
- **The ship** belongs to whoever is at the helm (`Net.ship_owner`, the host otherwise); every
  machine runs the same sailing sim and eases toward the owner's state.
- **Hits on a captain** are decided on that captain's machine (dodges and parries are judged on
  what you saw). **A client's hit on an enemy** is detected on the client and applied on the
  host (`route_hit` -> `_hit_enemy`).

## The channels (pick the right one)

| Need | Use | Notes |
|---|---|---|
| Continuous state (positions, poses, HP) | `net_pack()` on the node, read with `Net.sample(n)` -> `[older, newer, blend]` | sent for the local player, the ship (owner) and, on the host, everything in group `net_sync` |
| Only the newest state (things that run their own copy) | `Net.latest(n)` | the ship |
| A position that may be on a deck | `Net.deck_pack(p)` / `Net.deck_unpack(p, key)` | relative to the hull it's on, so riders move with it on every screen |
| A one-shot on a specific node (die, fire, vanish, sense) | `Net.event(node, "what", args)` -> `node.net_event(what, args)` elsewhere | played at the snapshot delay, in step with the puppet |
| A visible/audible effect | `Net.fx("method", args)` instead of `FX.method(...)` | runs here and on every other screen |
| The same change on every machine | `Net.everyone("_all_thing", args)` | the method must live on Net and start with `_all_`; it runs here now and elsewhere at the delay |
| A client asking the host to do something to an enemy | `if Net.forward(self, "method", [args]): return` at the top of the method | the method must be listed in `HOST_CALLS` |
| Something only one player may have | request/grant RPCs, host decides | seats (`request_seat`), the helm (`request_helm`), `claim_fruit`, shared bags (`bag_take`/`bag_store`) |
| A gunshot | `Net.shot(from, to, data, shooter)` | each machine checks its own captain on the line |
| XP, coins, damage numbers | `Net.award_xp`, `Net.coins`, `Net.damage_number` | |

Arguments go through `_enc`/`_dec`: nodes become keys, `HitData` a plain array, other objects
are dropped. An event whose node doesn't exist on the receiver is skipped.

## Identity: key_of / node_of

A node is named on the wire by its path from the world scene (`Net.key_of(n)`,
`Net.node_of(key)`). **Every node another machine must find needs the same path everywhere**:
give runtime-made nodes deterministic names (`"Drop_" + id`, seeded spawns, fixed child names),
never Godot's `@Node3D@123` auto-names, and build them in the same order on every machine.

## RPCs

All RPCs live on `/root/Net` (the same path on every machine); keep new ones there.
- Requests: `@rpc("any_peer", "call_remote", "reliable")`, and check `if not hosting: return`
  in the handler (anyone can call it).
- Host to clients: `@rpc("authority", "call_remote", "reliable")`.
- Snapshots are `unreliable` and packed under `SNAP_BUDGET` (an MTU-sized packet).
- `Net.applying()` is true while replaying someone else's event/fx: don't re-broadcast then
  (the helpers already guard this).

## Making a thing co-op

- **An enemy or world entity** (the pirate grunt is the reference: `scripts/enemies/pirate_grunt.gd`):
  `add_to_group("net_sync")`, `net_puppet = Net.is_client()`, host: `net_pack()` (fixed-size
  array; deck-relative position via `deck_pack`), client: `_net_update` from `Net.sample(self)`,
  `net_event` for one-shots, `net_rescale(k)` for HP with more captains (`Net.hp_scale()`).
  Spawners: group `net_spawner`, `net_gen()/net_set_gen()`, `Net.spawned(self, gen)`.
- **A new Humanoid pose flag** (climbing, kneeling, manning...): add it to
  `HumanoidSync.FIELDS` (`scripts/net/humanoid_sync.gd`) or puppets won't show it.
- **A new player state or action**: the state name rides the player's snapshot; body actions
  (`Humanoid.play`/`hold`) are sent as Humanoid events automatically when `net_sync` is on (and
  throttled for poses replayed every frame); one-shot visuals go through `Net.fx`.
- **World state a guest can change** (burn brush, open, anchor, work the pump, summon): send it
  to the host (request RPC or `everyone`), let the host apply it, and add it to
  `_world_state()` / `_apply_world_sync()` so a captain who joins later sees it.
- **Shared containers**: `LootBag.shared_id` ("storage" is the ship's chest, `Drop_*` for
  dropped items); the host keeps the contents and pushes `_bag_contents` to everyone.
- **Menus** don't pause the world in co-op (`Net.set_paused` locks your input instead).

## Saves

The host's save holds the world. A guest's save keeps their captain only (level, gear, fruit,
loot) and their own world untouched (`SaveGame._guest`). The ship's storage in co-op is the
host's; a guest's own storage stays in their save.

## Testing

- `.\tools\dev\nettest.ps1` runs a headless host and client on localhost (modes: `late` join,
  `three` with a watcher, `hostquit`, `water`). Logs: `tools/dev/out/logs/net*.log`.
- The client side is `tools/dev/netclient.gd` (a step machine: `go(n)`, `st_t`, `check()`);
  it asks the host things through `tools/dev/nettest_node.gd`: `tn.ask("name", args)`, wait
  for `tn.got("name")`, read `tn.replies["name"]`. Add a command by adding a `"name":` branch
  to `_run()` in nettest_node.gd (it runs on the host and returns the reply).
- Add a check for every co-op feature: the guest does it, the host sees it (and back).
  `run_tests.ps1 -Changed` says when co-op code changed and nettest should run.
- Puppet visuals: `coopshot` renders two captains side by side.

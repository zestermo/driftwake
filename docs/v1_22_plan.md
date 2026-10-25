# v1.22: Crews and Parties

## What it is

Crews of up to five captains that last: a named crew saved in the host's world, a party panel that shows every
crewmate's state at a glance, quests that pay the whole crew, and maps and markers that work with a full party
(crewmates, the ship and tracked quests on the map, cleaner on-screen markers, shared waypoints and pins, a better
held map). Built on what's there: the crew journal (one per crew, the host decides every change), party rows (colour,
name, HP, ping), ping markers on G (`MarkerLayer`), the held map with fog of war, `Net.MAX_CLIENTS` 3 today.

A UI mock of the party panel, the Crew tab and the map's markers goes to Zach for his OK before anything is built
(feel systems get a preview first).

## Decided (2026-10-25)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Crew size | Up to **5** captains (`Net.MAX_CLIENTS` 4) | Zach (2026-10-24) | - |
| What a crew is | **A named crew** saved in the host's world: its name, its flag (the ship's), a roster of everyone who's sailed with it, the host as Captain. Crewmates rejoin as crew. **No gameplay roles** yet | Zach | Roles wanted later |
| Party panel | **Status at a glance**: name and colour, HP and stamina, where they are (aboard, which island, distance and an arrow), state icons (downed, swimming, at the helm, in a fight); ping stays | Zach | After the mock |
| Quest rewards | **The whole crew**: every captain in the game gets their share of gold and items at a turn-in, wherever they are (today: only those present) | Zach | - |
| Maps and markers | **All four**: crew on the map (crewmates, the ship, everyone's tracked quests, on the held map and the compass/minimap, labelled); cleaner on-screen markers (stack, fade, distance, no clutter in a fight with five); map polish (clear icons and a legend, labels, zoom and pan); shared waypoints | Zach | After the mock |
| Joining | **Roster quick-join**: today's direct join, plus a "Rejoin crew" list of the crews you've sailed with (the host's last address), one click. No servers | Zach | - |
| Crew screen | **A Crew tab** in the pause menu: the crew's name (the Captain renames it), its flag (opens the ship's paint), the roster (here now, sailed with us, last seen), a kick for the Captain | Zach | - |
| Waypoints | **Anyone** sets one shared course or meeting point (one per captain, in their colour); the Captain's drawn bigger | Zach | - |
| UI mock | **Approved** (2026-10-25): the party panel top left (a line and an HP bar each, where or what on the right, a downed row red with distance and arrow), the compass strip with crew, waypoints and quest, small labelled markers collapsing into "+N more", the Crew tab (name and flag, aboard now with pings and the Captain's kick, sailed with us), "Rejoin crew" on the title screen, the held map (crew in their colours, the ship, waypoints with the Captain's bigger, pins labelled with who set them, quests, a legend; drag to pan, scroll to zoom, right click a pin, F a waypoint) | Zach | - |
| Map pins | **Always shared**: every pin a captain sets is the crew's | Zach (over the recommended private + shared) | If five captains clutter it |
| Loot (Zach, 2026-10-25) | **Approved tables.** Kills: grunts/rival crewmen 60% coins, their own weapon **2%** at the island's tier; beasts/fauna no coins, their own material ~15%; mini-bosses always coins, weapon 25% (+1 tier 10%); bosses: a hoard chest. Chests rolled per captain around the island's tier: ordinary gold + 0-2 local supplies + weapon/gear **25%** (tier -1 35%, tier 50%, +1 13%, +2 2%); hidden/dive/map gold + treasure + 1-2 supplies + **50%** (tier 60%, +1 35%, +2 5%); boss hoard gold + treasure + 1-2 supplies + **always 1** (tier 70%, +1 27%, +2 3%), clamped 1-4. Brinehollow: the den strongbox a random pistol/cutlass/dagger/hatchet, green 85% blue 15% (no fixed blue pistol); its other hand-placed chests rolled like ordinary ones plus their story item. Purple/gold, traits and uniques only on tier 3+ islands (level 17+) and from vendors; every source rolls from its own themed pool (pirates, Admiralty, desert, snow, jungle, fog isle, artisans) | Zach | In play |
| The crew's emblem (Zach, 2026-10-25) | **On the centre of the main sail** (the flag's emblem in its mark colour, moving with the canvas as it billows and furls) and **more emblem choices** for the flag and sail | Zach | - |

### Open / deferred

- Pins: a cap per captain (about 8, oldest goes) and who can remove one (its setter or the Captain). **assumed**
- Scaling for a fifth captain: today's formula carried on (hp_scale 1 + 0.6 per extra captain, extra attackers,
  boarders per captain), tuned in play. **assumed**
- Every ship carries the whole crew of five (deck jobs, bunks as respawn spots shared). **assumed**
- Piece 1 built (2026-10-25): crews of five (nettest five), the named crew's data, the Crew tab. Left of it: "Rejoin crew"
  on the title screen. Then the loot rework, the sail emblem and new emblems, the party panel and the rest.
- More emblems: about six new ones (a kraken, a trident, a rose, a sun, a wave, a raven), drawn like today's on the
  48x30 flag. **assumed**
- Building starts after the weekly usage reset (Zach, 2026-10-25), a piece at a time.
- Releases: unstable 1.21.x pieces, then the stable 1.22, like 1.21. Order: the mock first; then 5 captains and the
  named crew (save, roster, quick-join, the Crew tab); the party panel; whole-crew rewards; crew on the map and
  waypoints/pins; on-screen markers; map polish. **assumed**
- Co-op standard for all of it: the host decides crew state (name, roster, kicks, rewards, pins and waypoints go
  through `Net.everyone`), saved in the host's world and sent to a captain who joins.

# Driftwake in the browser (Web export) and its site

Written 2026-10-09. Godot 4.7.2 (`$env:GODOT`), branch `worktree-agent-a28049e5df2525d16`.

## Where it stands

| Step | State |
|---|---|
| Feasibility audit (below) | done |
| "Web" export preset, thread-less, Compatibility | done (`export_presets.cfg`, preset.1) |
| Web gates in game code | done, all behind `OS.has_feature("web")` (list below) |
| Pack export (no templates needed) | done: **6.9 MB** `.pck`, clean (no tools/docs/"Claude outputs") |
| Compatibility renderer on desktop (ANGLE/D3D11, Chrome's backend on Windows) | rendered: no shader errors, two visual differences (below) |
| Full web export and a boot in the browser | **blocked: the web export templates aren't installed** |
| Site (`web/site/`), hosting files, build + serve scripts | done |

**To unblock:** install the Godot 4.7.2 export templates: in the editor, Editor > Manage Export
Templates > Download and Install, or download
`https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`
and use Install from File. Only Windows templates are there now
(`%APPDATA%\Godot\export_templates\4.7.2.stable\windows_*`); the web ones are
`web_nothreads_release.zip` / `web_nothreads_debug.zip` (and the threaded `web_release.zip` ...).
Then `.\tools\dev\build_web.ps1` and `.\tools\dev\serve_web.ps1`, open http://localhost:8060/play/.

## Decisions

- **Renderer:** Compatibility (WebGL 2). The Web export can't run Forward+ or Mobile;
  `rendering/renderer/rendering_method.web` isn't set in project.godot, so it takes its default,
  `gl_compatibility`. No `.mobile`/`.web` overrides exist. Desktop stays Forward+.
- **Threads: the thread-less export** (`variant/thread_support=false`). Reasons below.
- **Physics:** Jolt, unchanged.
- **Co-op:** off in the browser (menus say desktop-only). The path to browser co-op is at the end.
- **Hosting:** Netlify first (no per-file size cap that the .wasm hits); Cloudflare Pages works
  if the .wasm fits its 25 MiB per-file limit (likely not with the stock template, see Size).

## Feasibility audit

### Renderer: Compatibility (WebGL 2)

Shaders (all compiled and drew under `--rendering-method gl_compatibility --rendering-driver opengl3_angle`,
which is ANGLE over D3D11, the same path Chrome takes for WebGL on Windows):

| Shader | Uses | Compatibility |
|---|---|---|
| `shaders/psx/psx_lit.gdshader`, `psx_lit_fade`, `psx_lit_body.gdshaderinc` | vertex snap via `POSITION`, `IN_SHADOW_PASS` (l.35, 42), global uniforms `psx_snap_res`/`psx_affine` (`psx_common.gdshaderinc` l.5-7), dither `discard` (fade), emission, `filter_nearest_mipmap_anisotropic` | works. Anisotropic filtering needs `EXT_texture_filter_anisotropic`; without it the sampler falls back to plain mipmaps. |
| `psx_cutout.gdshader` | alpha scissor, snap | works |
| `scenes/ocean/ocean.gdshader` | transparent `blend_mix` + `depth_draw_always` (l.4), 3 wave evaluations per vertex x 6 waves (l.196-203), uniform arrays `wake[40]`, `waves[6]` (l.18, 61), globals `sky_haze`/`fog_range` (l.157-159), shoal maps (L8 images) | works; it **looks different** (below) and is the heaviest vertex shader on a WebGL budget |
| `scenes/island/terrain.gdshader` | 6 nearest-mip samplers, world-space dither, snap | works |
| `shaders/psx/psx_sky.gdshader` | sky shader, fbm clouds (2 x 5 octaves per pixel), `TIME` | works; sunset matched Forward+ closely. Sky is `PROCESS_MODE_INCREMENTAL`, radiance 32 (`scripts/world/weather.gd` l.228-229), ambient from colour (l.231) so the radiance map barely matters |
| `shaders/psx/psx_post.gdshader` | canvas_item `hint_screen_texture` (l.7), `FRAGCOORD`, Bayer array | works (back-buffer copy in Compatibility). PSX pixelation, dither and the HUD looked right |
| `shaders/psx/slash_trail.gdshader` | **instance uniforms** `edge_override`, `progress`, `fade` (l.12-16) | compiled and ran in the ANGLE run. Only a handful of trails exist at once, far from the instance-uniform cap CLAUDE.md notes; psx_lit already avoids them (`psx_lit_body.gdshaderinc` l.16-20). Watch for missing sword trails on the first boot. |
| `shaders/world/cloud_puff.gdshader`, `scenes/world/cloud.gdshader`, `shaders/world/godray.gdshader` | unshaded, blend_mix/add, MultiMesh (`cloud_spawner.gd` l.69-82, godrays `weather.gd` l.563-583) | works |

Other rendering features in use:

- **Global shader uniforms** (`[shader_globals]` in project.godot): supported.
- **Environment** (`scenes/world/world.tscn` l.39-58): linear tonemap, ambient from colour,
  reflections off (`reflected_light_source = 1`), **depth fog** (`fog_mode = 1`). No SDFGI, SSAO,
  SSIL, SSR, glow or volumetric fog anywhere in the game (only `tools/dev` shot scripts touch
  environment effects), so none of the Forward+-only features are lost.
- **Shadows:** only the sun casts them (world.tscn l.71; PSSM 2 splits, 120 m). Supported.
- **Lights:** OmniLight3D/SpotLight3D from props (`props.gd` l.429, 641, 649, 743), buildings
  (`buildings.gd` l.686), the ship's lamp (`ship.gd` l.1173), fires (`burnable.gd` l.84,
  `fire_zone.gd` l.65, `fireball.gd` l.63), caves (`brood_cave.gd` l.618, 753), the fort
  (`redtide_fort.gd` l.562). None cast shadows. Compatibility draws each extra light on an object
  as another pass and caps lights per object (`rendering/limits/opengl/max_lights_per_object`,
  8 by default): **Brinehollow at night is the costliest place in the browser.**
- **Particles:** the rain is a `GPUParticles3D` (`weather.gd` l.493, 2200 particles, align-Y).
  Compatibility runs GPU particles (transform feedback); it rendered in the ANGLE run. Effects
  are CPUParticles3D.
- **3D resolution scale:** `psx_settings.gd` l.131 renders the 3D at the PSX grid's size through
  `scaling_3d_scale`; Compatibility does that with bilinear scaling, which the post pass then
  samples one texel per cell, so the result is the same.
- **No RenderingDevice, compute or CompositorEffects** anywhere.

What the ANGLE run showed (shots in `tools/dev/out/webcompat/` and `tools/dev/out/webfwd/`, same
weathershot script, RTX 4060 laptop, 1280x720):

1. **The sea is brighter and more cyan** in Compatibility (compare `wx_noon.png`): the transparent
   sea blends over the sky behind it, and Compatibility blends in the 8-bit sRGB buffer where
   Forward+ blends in linear HDR, so the ~18% of sky that shows through the near sea lifts it a lot.
   The horizon haze also reads more turquoise. Fix when it matters: on web only, push the ocean
   material's `near_alpha` up (0.82 -> ~0.92) and/or darken `deep_color`/`shallow_color` a step;
   judge it in the browser.
2. **Speed:** about 40 fps against 60-66 with Forward+ for the same shots, ~2,100-2,500 draw calls.
   WebGL adds validation cost per call on top of this, so expect the browser to be CPU-bound on
   draw calls: lower-end laptops will sit around 20-30 fps in Brinehollow. Levers, all web-only:
   the 640x360 preset by default (less fill), shorter draw distances for props/vegetation,
   fewer far islands, and merging static props per island (draw calls).
3. Sunset, night, rain, storm, clouds, godrays, the PSX post pass and the HUD all look right.

### Threads: thread-less vs threaded

WorkerThreadPool work in the game:

- island preparation for the chain (`scripts/island/world_generator.gd` l.145, waited for l.151-153);
  dev notes: a 310 m island is ~1.3 s on a worker, 430 m ~2.2 s (native code speed);
- bodies built ahead (`scripts/npc/humanoid.gd` l.372, `prebuild`), tens of ms each;
- navigation meshes (`scripts/world/nav_baker.gd` l.91, `bake_from_source_geometry_data_async`);
- the threaded scene load in `scripts/ui/loading_screen.gd` l.51.

| | Thread-less (chosen) | Threaded |
|---|---|---|
| Headers | none | COOP + COEP on the game page (SharedArrayBuffer) |
| Where it runs | any static host, any iframe (itch.io too), Safari/iOS included | hosts that let you set headers; cross-origin embeds need CORP; Safari has had trouble with threaded Godot builds |
| WorkerThreadPool | runs each task on the calling (main) thread at `add_task`; mutexes are no-ops. Nothing breaks. | real worker threads |
| Island chain | **the whole prepare runs in one frame: an estimated 2-5 s freeze** when the log pose sets and the next islands are built (WASM is slower than native) | built in the background as on desktop |
| Bodies, navmesh | hitch where they're asked for (prebuild becomes "build now") | background |
| Audio | "Sample" playback (WebAudio plays the sounds, so a long frame doesn't crackle), but no bus effects | full Godot mixer on its own thread |

Thread-less wins on reach and simplicity, and audio stays clean through the freezes. The cost is
the island freeze. The fix for that belongs in game code later (desktop benefits too): make
`GenIsland.prepare` resumable in slices (a few ms a frame) when `OS.has_feature("web")`, or show
a "charting the sea..." card while it runs. To switch to threads instead: set
`variant/thread_support=true` in the preset, install `web_release.zip`, uncomment the COOP/COEP
block in `web/site/_headers`, and serve with `serve_web.ps1 -Threads`.

### Physics: Jolt

Jolt has been a built-in engine module since Godot 4.4 and the official templates (web included)
are built with it; in a thread-less build its job system runs on the main thread. If a template ever lacked it, Godot would print an error and fall back to Godot
Physics (the setting names an engine that isn't there). Check the browser console on the first
boot for a physics-engine error.

### Co-op

ENet (`scripts/net/network_manager.gd` l.67, 191, 219) needs UDP sockets, which browsers don't
give pages. In the web build `host_game`/`join_game` return `ERR_UNAVAILABLE` with
"Co-op needs the desktop build", the title's Co-op button reads "Co-op (desktop only)" and is
disabled, and the pause menu has no "Host Co-op". See the end of this file for the path to
browser co-op.

### Saves and settings

`user://` is IndexedDB in the browser (Godot syncs it after a file opened for writing closes).
Saves (`scripts/game/save_game.gd`), settings (`settings.gd`), the character
(`character_look.gd`), `whats_new_seen.txt` and `last_host.txt` all go through FileAccess /
DirAccess on `user://` paths, which work there. Two gaps:

- A closed tab sends no `NOTIFICATION_WM_CLOSE_REQUEST`, so "save on quit"
  (`game_manager.gd` l.125) never ran. The web build now also saves when the page is hidden
  (`visibilitychange`: switching tabs, minimising, closing), on top of the 2-minute autosave.
- `perf_monitor.gd` keeps `user://perf.log` open and only flushes, so in the browser the log
  never reaches IndexedDB. Harmless; F8's overlay works.

Saves live per browser and per site: clearing site data deletes them, and a new domain starts empty.

### Audio

- Web playback is "Sample" by default (`audio/general/default_playback_type.web`): each stream is
  decoded once and handed to WebAudio. Bus volume and mute work (the Options sliders), **bus
  effects don't**, so the master **HardLimiter** (`settings.gd` l.134) does nothing in the
  browser. Loud moments (a broadside with a roar and music) may clip. If they do: lower the web
  master default a little, or switch the project to Stream playback on web (the limiter works,
  but in a thread-less build the mixer runs on the main thread and crackles when a frame is long,
  e.g. the island freeze).
- To check on the first boot: the QOA-compressed `.wav` imports (`compress/mode=2`, all 97)
  decode for samples, the take randomizers (`fx.gd` l.80, `AudioStreamRandomizer`) play, and
  music resume (`music.gd` l.84, `get_playback_position`) picks up where it was; if sample mode
  reports 0 the calm tracks just restart.
- Autoplay: browsers start audio only after a click or key. The play page's "Set sail" button is
  that click, and starting the engine from it unlocks the AudioContext, so the title music plays.

### Input

- **Ctrl+W closes the tab** and no page can stop it (Chrome reserves it). Dodge is Left Ctrl and
  forward is W, so dodging while running would close the game. The web build binds dodge to
  **C** instead (`settings.gd`, `InputMap`), the controls screen and the loading tip say C.
  Swimming's duck-under uses the same action.
- **Mouse look** uses pointer lock. A page can only lock the pointer after a click; the camera
  rig already re-captures on a click (`camera_rig.gd` l.86-89), so the first click into the game
  takes the mouse (and swings, once). **Esc** always releases the lock in the browser and may
  not reach the game, so in the web build losing the lock while playing opens the pause menu
  (`game_menu.gd` `_process`, with a 300 ms guard so the same Esc doesn't close it again).
- **F-keys:** release exports turn off every debug key that browsers also use (F5 reload, F6, F7,
  F9, F10, F12 devtools: all behind `OS.is_debug_build()`). F2/F3 (PSX preset, dither), F4 (state
  label) and F8 (perf overlay) work. **F11** is the browser's own fullscreen; use Alt+Enter or
  Options > Fullscreen in-game.
- **Fullscreen:** only from a click or key press. A saved "fullscreen on" setting is reset at
  startup in the browser (`psx_settings.gd`); the play page's "Set sail" button can go fullscreen
  (checkbox, on by default).
- Tab, Space, arrows: Godot cancels the browser's default for keys it receives.

### Window, size and DPI

- Canvas resize policy 2 (adaptive): the canvas fills the browser window, the 800x450 UI canvas
  stretches as on desktop (`window/stretch/mode="canvas_items"`, aspect expand).
- HiDPI is on, so on a 2x screen the canvas has twice the pixels; the 3D is still drawn at the
  PSX grid's size (`scaling_3d_scale`, clamped to 0.25 at the smallest), so this costs little.

### Debug tools

DevCapture (F12) is off in release builds (`dev_capture.gd` l.27). In a debug web export F12
opens the browser's devtools instead, and captures would land in IndexedDB where nobody can
reach them; use the browser console (debug exports print there) for web bugs.

### Export size

- **`.pck`: 6.87 MB** (measured with `--export-pack "Web"`; 838 files: scripts, scenes, 97 QOA
  sounds, 6 Ogg tracks, lossless PSX textures, fonts). The exclude filter keeps out `tools/*`,
  `docs/*`, `web/*`, `addons/godot_mcp/*` and **`Claude outputs/*`**.
- **`.wasm`: not measured yet** (needs the templates). Godot 4.x's stock web template is roughly
  35-45 MB, about 9-11 MB gzipped. `build_web.ps1` prints the sizes (raw and gzipped) after each
  export and flags any file over 25 MiB.
- Textures are imported lossless (`compress/mode=0`), so no VRAM compression format is needed:
  the preset keeps desktop S3TC on and mobile ETC2/ASTC off without losing anything on phones.
- **Desktop finding:** the "Windows Desktop" preset has an empty `exclude_filter`, so its pack is
  **47.9 MB**, most of it the 68 MB of PNG/GIF in `Claude outputs/` (imported, so exported), plus
  tools and docs. Adding `tools/*, docs/*, Claude outputs/*, addons/godot_mcp/*` there (as
  CLAUDE.md asks) would bring it near 7 MB. Not changed here.

## What changed in game code (all behind `OS.has_feature("web")`)

| File | Change |
|---|---|
| `scripts/net/network_manager.gd` | `host_game`/`join_game` refuse in the browser (`WEB_NO_COOP`) |
| `scripts/ui/title_screen.gd` | Co-op button disabled, "Co-op (desktop only)"; no Quit |
| `scripts/ui/game_menu.gd` | no "Host Co-op" / "Quit Game"; pause on lost pointer lock; controls list shows C for dodge |
| `scripts/game/settings.gd` | dodge bound to C (not Ctrl) |
| `scripts/ui/loading_screen.gd` | the roll tip says (C) |
| `scripts/psx/psx_settings.gd` | a saved fullscreen setting is reset at startup instead of failing |
| `scripts/game/game_manager.gd` | saves when the page is hidden (`JavaScriptBridge`, `visibilitychange`); the close-request save moved into `_save_on_exit()` (same behaviour on desktop) |

No shader changes: nothing failed to compile under Compatibility.

## Building and trying it locally

```powershell
.\tools\dev\build_web.ps1                # export (release) to web\build, copy to web\site\play, print sizes
.\tools\dev\build_web.ps1 -DebugBuild    # debug export: script errors and prints in the browser console
.\tools\dev\serve_web.ps1                # http://localhost:8060/ (site) and /play/ (game); Ctrl+C stops
.\tools\dev\serve_web.ps1 -Threads       # adds COOP/COEP (only for a threaded export)
```

The export uses `web/shell/play.html` as its HTML shell (the loading screen: downloads the game
with a progress bar, then "Set sail" starts it, which also unlocks audio and can go
fullscreen). `web/` has a `.gdignore`, so Godot never imports the site or the build.
`web/build/` and `web/site/play/` are gitignored.

First boot checklist (things only the browser can answer): load time, the console (no errors;
no physics-engine fallback), the title music, New Game > Brinehollow, a fight (C dodges, Esc
pauses), the sloop under sail (watch fps with F8), the log pose setting on the first island
(the freeze), saving, then reload and Continue.

## The site (`web/site/`)

Plain HTML/CSS, no build step:

- `index.html` + `style.css`: logo, pitch, a "Play in browser" button (`play/`), a disabled
  "Download for Windows" placeholder (`#download`), four screenshots from `docs/media`
  (`img/*.jpg`, ~1.1 MB total), features, controls, the desktop/browser notes. The hero backdrop
  `img/dusk.svg` redraws the title screen's dusk (`title_screen.gd` `_draw`).
- `play/`: the export, copied in by `build_web.ps1`.
- `fonts/`: Pixelify Sans and Silkscreen (OFL, licences alongside), self-hosted.
- `favicon.svg`, `_headers` (Netlify and Cloudflare Pages both read it): `.wasm` as
  `application/wasm`, `.wasm`/`.pck` revalidated every visit (their names never change between
  builds, so long caching would serve stale builds; a 304 is cheap), fonts and images cached,
  COOP/COEP commented out for a threaded build.
- `netlify.toml` (repo root): publish `web/site`, no build command (Netlify's builders have no
  Godot): build locally, then deploy.

To put the Windows build on the page later: upload the .zip somewhere (a GitHub release is
simplest) and point both "Download for Windows" buttons at it, removing `aria-disabled`.

## Deploying (nothing has been deployed, signed up for or logged in to)

### Netlify

1. `.\tools\dev\build_web.ps1` (so `web\site\play\` has the game).
2. Either:
   - **Drag and drop:** app.netlify.com > Add new site > Deploy manually, drop the `web\site` folder.
   - **CLI:** `npm install -g netlify-cli` (once), `netlify login`, then from the repo root
     `netlify deploy` (a draft URL to try) and `netlify deploy --prod`. The first run asks to
     create or link a site; `netlify.toml` already says to publish `web/site`.
3. **Custom domain:** Site configuration > Domain management > Add a domain. Either point the
   domain's nameservers at Netlify DNS, or at your registrar add a CNAME for `www` to
   `<site>.netlify.app` and an A/ALIAS record for the apex as Netlify shows. **HTTPS:** Netlify
   issues a Let's Encrypt certificate by itself once DNS resolves (Domain management > HTTPS;
   "Verify DNS configuration" if it waits).
4. Each new build: rebuild, then drag the folder again or `netlify deploy --prod`.

Git-linked Netlify deploys won't have `play/` (it's gitignored and Netlify can't run Godot), so
use the manual/CLI route, or later a GitHub Action that installs Godot + templates, runs the
export and calls `netlify deploy`.

### Cloudflare Pages

1. Build as above. Check the sizes `build_web.ps1` prints: **Pages refuses any file over 25 MiB**,
   and the stock `.wasm` is likely over it (the `.pck`, 6.9 MB, is fine).
2. `npm install -g wrangler` (once), `wrangler login`, then
   `wrangler pages deploy web/site --project-name driftwake` (the first run creates the project),
   or the dashboard: Workers & Pages > Create > Pages > Upload assets, drop `web\site`.
3. Custom domain: the project > Custom domains > Set up a domain (easiest when the domain's DNS
   is on Cloudflare; otherwise a CNAME to `<project>.pages.dev`). HTTPS is automatic.
4. `_headers` applies as on Netlify.

If the `.wasm` is over 25 MiB, in order of effort:

- host on Netlify instead (no such cap), or
- put `index.wasm` (and the .pck if it ever grows past the limit) in a Cloudflare R2 bucket with a
  public custom domain and CORS for the site's origin, and point the engine at it: in
  `web/shell/play.html`, override `executable` in the config passed to `new Engine(...)` with the
  bucket URL's base (the engine fetches `<executable>.wasm`); the small files stay on Pages, or
- build a smaller custom web template (SCons: `platform=web target=template_release threads=no
  optimize=size_extra lto=full` with a build profile that drops modules the game doesn't use) and
  set it as `custom_template/release`; that usually lands well under 25 MiB.

## The path to browser co-op (not built)

The game's networking already goes through Godot's MultiplayerAPI (RPCs on `/root/Net`,
`MultiplayerPeer` signals); only peer creation is ENet-specific (`network_manager.gd`
`host_game`/`join_game`, and the ENet timeout tweak at l.316). Browsers offer two transports:

- **WebSocketMultiplayerPeer:** TCP, so the unreliable 20 Hz snapshots arrive in order with
  head-of-line stalls on a bad connection; fine for 4 captains. A browser can't host a WebSocket
  server, so either the host is always a desktop build listening on `wss://` (needs a TLS
  certificate and port forwarding: unrealistic for players), or a **relay** forwards packets
  between peers in a room. A relay is small: a headless Godot server or ~200 lines of Node/Go on
  Fly.io, Railway or a $5 VPS, or a Cloudflare Worker with a Durable Object per room (WebSocket
  hibernation keeps it cheap).
- **WebRTCMultiplayerPeer (recommended):** peer-to-peer data channels, reliable and unreliable
  like ENet, so the snapshot design keeps working. The host keeps the server role
  (`create_server()` on the host, `create_client(id)` on guests). Needs a **signalling server**
  (a few WebSocket messages per join: a Cloudflare Worker + Durable Object keyed by a room code
  fits), public STUN, and a TURN fallback for strict NATs (Cloudflare Calls TURN, Twilio, or
  coturn on a VPS). Browsers have WebRTC built in; the desktop build needs the `webrtc-native`
  GDExtension (then `variant/extensions_support` stays off on web, the desktop preset carries
  the extension), and desktop and browser captains can sail together.
- UI: replace "host address" with a 6-letter room code from the signalling server.
- Keep ENet for desktop-to-desktop LAN games, picked when both ends are desktop.

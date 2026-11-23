# CylinderRunner — Agent Handoff / Memory Bank

Last updated: 2026-11-24. Read this before editing. Keep it current after each
coding task. The project `AGENTS.md` specifically requires updating this file.

## Project snapshot

- Godot 4.7.2 stable, GDScript, Mobile renderer, landscape Android target.
- Viewport 1280x720; stretch aspect `expand` for differing landscape ratios.
- Startup scene: `scenes/main.tscn`; no external art assets.
- Cylinder radius 8; pooled track sections extend continuously along -Z.
- Capsule height 2, radius .45; no physics body, gravity or collision shapes.
- Nominal run speed 18 units/s, angular steering speed 130 degrees/s.
- Main run loop reuses Z=-20..-120 and shifts player/camera by 100 units.
  This is a fixed prototype loop; no track generation.

## Controls and state

- Desktop: A/D and left/right arrows steer; Q switches surfaces; R restarts after
  GAME OVER. Forward auto-runs while alive.
- Touch (`scenes/player.tscn` child `TouchInput`): horizontal drag rotates;
  double tap requests the existing Q switch. Default sensitivity 360 degrees per
  screen width; thresholds and sensitivity are Inspector properties. A second
  finger may double tap during primary finger steering. Touch cancellation/focus
  loss clears gesture state. Mouse-from-touch is off; optionally enable
  `pointing/emulate_touch_from_mouse` to test on desktop.
- Surface state is `CylinderRunnerPlayer.SurfaceState` in `scripts/runner.gd`.
  Inside center radius=7/local up inward. Outside center radius=9/local up outward.
  Right steering remains local +X on both surfaces.
- Q starts a 0.25 sec switch, cooldown .15 sec by default. Both gameplay surfaces
  remain vulnerable during the animation: source surface until transition ends,
  destination afterward. Player continues moving and steering throughout.
- Transition timing: `scripts/surface_transition.gd`. Rendering: camera's live
  secondary SubViewport and `scripts/surface_phase_view.gd`, a live dissolve with
  cyan ripple. No GPU readback/frozen screenshot, flat full-screen veil, or camera
  travel through the wall. Preserve these distinctions when modifying transitions.
- Camera follows player local up, quaternion smoothing, priority 10. Separate live
  source-view camera/proxy is enabled only during transitions.

## Phase 5 obstacle foundation (legacy course fixture)

- Main instantiates `scenes/obstacle_course.tscn`, a fixed course with:
  - Partial inner: 0 deg, 100 deg width, Z=-40.
  - Full inner 360 deg ring: Z=-65.
  - Partial outer: 0 deg, 110 deg width, Z=-90.
  - Partial inner: 180 deg, 100 deg width, Z=-112.
- Reusable `scenes/obstacle.tscn`, `scripts/obstacle.gd`: configurable kind,
  angular center/width, Z, shared cylinder radius, height and depth. Red inner,
  amber outer arc prisms; default height 2.4, depth 1.2. No external assets.
- Placement is separate from `scripts/obstacle_collision.gd`. Main binds the
  sweep callable to the player and syncs cylinder radius with tunnel and obstacles.
- Collision is a swept capsule envelope in unwrapped angle/Z coordinates. It pads
  Z with capsule radius and angle with capsule silhouette, checks periodic angle
  copies at 0/360, and repeats fixed obstacles across the existing Z loop. It
  returns earliest time fraction (INF means no hit), so high-speed forward motion
  cannot skip a barrier. Contact can conservatively include capsule corner grazes.
- During switching, source surface is checked until exact transition completion;
  destination is checked for the remainder. No transition invulnerability.
- On collision `end_run()` stops all movement, cancels phase, restores source
  surface if death happens mid-transition, then emits `died`.
- `scripts/run_status.gd` displays GAME OVER and Restart. R, button click, or native
  ScreenTouch press/release restarts without mouse emulation. Reset restores inside
  state, Z/angle, camera, transition cooldown, and pending touch state.

## File map

- Core: `project.godot`, `scenes/main.tscn`, `scripts/main.gd`.
- Player/input: `scenes/player.tscn`, `scripts/runner.gd`, `scripts/touch_input.gd`.
- Camera: `scenes/runner_camera.tscn`, `scripts/runner_camera.gd`.
- Switch: `scripts/surface_transition.gd`, `scripts/surface_phase_view.gd`.
- Environment: `scenes/tunnel.tscn`, `scripts/tunnel.gd`.
- Obstacles: `scenes/obstacle.tscn`, `scripts/obstacle.gd`,
  `scenes/obstacle_course.tscn`, `scripts/obstacle_collision.gd`.
- Restart UI: `scripts/run_status.gd`.
- User-facing controls, playtests, Android deployment steps: `README.md`.

## Validation and known limits

All four automated test scripts have passed on Godot 4.7.2:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/prototype_validation.gd
godot --headless --path . --script res://tests/transition_validation.gd
godot --headless --path . --script res://tests/touch_validation.gd
godot --headless --path . --script res://tests/obstacle_validation.gd
godot --path . --script res://tests/obstacle_capture.gd
```

Obstacle suite covers partial avoidance/hit, full ring, outside filtering, all
cardinal/seam angles, capsule padding, 1000 units/s, loop crossing, source/destination
surface timing, restart by R/native touch, and completing the fixed course through
a loop. Touch suite covers 3 resolutions, 30/60/144 FPS, real dispatched touch
and cancellation, tap/drag separation, cooldown, second-finger switching and mouse
filtering. Earlier free-running suites explicitly disable obstacle collision.

Rendered D3D12 Forward Mobile captures for the phase, obstacles and GAME OVER were
visually inspected. Captures are ignored under `.godot/validation/`. Godot emits a
sandbox root certificate-store error; it does not block editor import, tests or
rendering. Godot was run with command-local `APPDATA=.godot/validation/appdata`.
Android build/device performance and manual phone play remain unverified.

Do not add coins, scoring, power-ups, menus or difficulty progression
unless requested. For Phase 6, retain obstacle definitions independent of collision
and validate wrap/switch interactions before replacing the fixed course.


## Phase 6 current architecture (supersedes fixed-course startup notes)

- main.tscn now uses Generator + an initially empty Obstacles root. main.gd binds
  a sweep wrapper that generates the entire proposed movement path + 200 units
  ahead BEFORE collision. It retires segments after movement (priority 20).
- track_generator.gd pools track_segment.tscn instances, one shared tunnel mesh,
  two reusable obstacle nodes/segment and cached meshes/materials per pattern.
  Default length 80; opening segment clear; row at each subsequent midpoint.
  Keep 200 ahead; retire segments with rear edge >30 behind. Normal pool <=7 in
  tests; exceptional huge frames can increase retained peak pool allocation.
- patterns/standard.tres + obstacle_pattern_library.gd: native exported library
  with 11 patterns, each declaring safe surface/angle and up to two simultaneous
  obstacles. Validated against capsule angular envelope +10deg margin. Invalid
  entries rejected. Pattern format and names documented in README.
- Spacing: max(minimum length, speed * (PI/angular_speed + 8/steering_response +
  transition_duration + switch_cooldown + reaction_time) + full collision slab),
  rounded to marking period 10. Settings are sampled at startup. Restart scene
  after changing movement, sizes, spacing or library. No difficulty progression.
- Player movement/camera/touch logic unchanged. loop_length=1000 now implements
  floating origin: generator moves segments/obstacle Z/cursor on existing wrap
  signal. Seed/pattern index do NOT reset at a coordinate wrap.
- Collision repeat_track=false on generated main scene; invisible pool obstacles
  skipped. repeat_track=true remains default for legacy_main.tscn fixture.
- run_status.restart invokes main.restart_course after player reset. Generator
  reseeds and reuses the pool; same seed restores sequence. Live phase behavior
  and source-until-completion collision rule preserved.
- Debug Inspector: seed_value=1337, forced_patterns repeats library indices,
  debug_log prints seed/index/id/Z; active/pool and last 64 history entries inspectable.
- Existing main was preserved as scenes/legacy_main.tscn + scripts/legacy_main.gd.
  Older tests/captures target that fixture; generation tests target main.tscn.

Validation performed: all five suites pass. Generation suite verifies every ordered
pair of 11 supplied patterns at forward speeds 18/40/80 at 60 FPS (363 navigated
cases), each initial approach, plus three seeded 10,000-frame collision-enabled
runs, pool/rebase coverage, deterministic restart and different seeds. These tests
validate routes for specified configurations, not arbitrary custom content or all
possible player states. Existing controller tests retain 30/60/144 FPS coverage.
Mobile renderer generated_track.png inspected; native Android/performance untested.
Resource library is preloaded for export. Standard Godot certificate-store sandbox
error remains non-blocking. Documentation-only old references to fixed geometry
apply to the legacy fixture. No Phase 7 or unrelated systems implemented.

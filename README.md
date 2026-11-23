# CylinderRunner

Godot 4.7.2 / GDScript / Mobile renderer. 1280 x 720 landscape. Procedural radius-8,
length-200 cylinder; capsule runs along -Z with mathematical surface attachment.
No external assets, conventional gravity, obstacles, scoring or touch controls.

## Play

Open project.godot and press F5. A/D or Left/Right steer; Q switches between the
blue interior and copper exterior. F8 stops. Capsule center radius is 7 inside,
9 outside; feet meet the wall and local +Y points away from the selected surface.

Switching uses a 0.25-second phase dissolve: a live source view blends into the
live destination view with a small cyan ripple. The camera transfers between safe
endpoints, never traversing the wall or rolling 180 degrees on screen. The source
image is frozen briefly while the destination keeps moving forward. There is no
opaque color veil. Angle holds during the phase; held steering resumes afterward.
Repeated Q presses are ignored during the phase and its 0.15-second cooldown.
Tune transition_duration and switch_cooldown on Player.

## Components

- scenes/main.tscn / scripts/main.gd: startup, shared radius and Z-loop setup.
- scenes/player.tscn / scripts/runner.gd: movement, surface state and attachment.
- scenes/tunnel.tscn / scripts/tunnel.gd: two visible cylinder faces and markings.
- scenes/runner_camera.tscn / scripts/runner_camera.gd: normal quaternion follow,
  local-up framing, and safe endpoint setup during phase switches.
- scripts/surface_transition.gd: replaceable timing, easing and cooldown logic.
- scripts/surface_phase_view.gd: live viewport dissolve and ripple presentation.

The fixed track reuses Z=-20 to -120 with a matching camera shift. No geometry is
created during a run. Keep component transforms unscaled. Camera inward_height
means local-up offset (outward when outside). If changing camera range or track
length, preserve sufficient margin to hide both tunnel ends.

## Verification

With the Godot console executable on PATH:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/prototype_validation.gd
godot --headless --path . --script res://tests/transition_validation.gd
New-Item -ItemType Directory -Force .godot/validation | Out-Null
godot --path . --script res://tests/phase_capture.gd
```

The first suite checks settled surface movement; the second checks timed phase
behavior at 30/60/144 FPS. Rendered checks save 32 phase samples and reject flat
frames. Captures are ignored by Git under .godot/validation.

Manual test: press Q at the bottom, each side and ceiling. Repeat while holding
D and A, after full revolutions and near a Z loop. You should see the capsule and
track dissolve between views, a brief cyan ripple, no flat screen or animated
camera spin, continuous forward travel and resumed steering. Mash Q to verify
input locking. Try both directions.

Desktop import, both suites and rendered checks pass. Representative rendered
frames were visually inspected. Android hardware and manual keyboard playtesting
remain unverified. The phase captures a single GPU image per switch; profile this
on Android. The sandbox reports a non-blocking certificate-store access error.

Read PROJECT_CONTEXT.md for current decisions and validation. AGENTS.md asks future
coding sessions to read and maintain that file.


Continuous-motion update: forward movement stays at the configured speed on every
frame, normal steering now works during the phase, and the camera keeps its forward
follow offset at the switch. The source side is rendered live without synchronous
GPU image capture. Verify by watching tunnel rings while pressing Q, with and
without A/D held; both views should continue moving through the dissolve.

## Touch controls and Android testing

Horizontal finger travel rotates the player: by default one viewport-width of
travel requests 360 degrees. Repeated drags allow unlimited revolutions. Touch
rotation uses the player's existing smoothing response and local-right direction,
so rightward drags feel consistent inside/outside. Holding a stationary finger
adds no movement. A/D, arrows and Q remain available and can combine with touch.

Double-tap near the same point to switch. Each tap must finish within 0.25 seconds;
the pair must finish within 0.30 seconds. Moving farther than 1.5% of the viewport's
shorter side makes the gesture a drag, even if it returns to its starting point.
The proximity limit is 8% of the shorter side. Pairs are consumed once; the existing
transition lock/cooldown decides whether the switch is accepted. A second finger
can double-tap while the first drags. Extra fingers never take over an active drag.

Tune sensitivity, drag_threshold, tap_max_duration, double_tap_interval and
 double_tap_distance on Player/TouchInput in scenes/player.tscn. Input recognition
lives in scripts/touch_input.gd; it emits rotation/switch signals and never changes
the camera. Touch cancellation or focus loss clears gestures and pending rotation.
The viewport now expands to fit different landscape ratios; travel is normalized
using the actual viewport dimensions. Landscape orientation is retained.

### Desktop simulation

1. In Project Settings, enable Advanced Settings if needed, then Input Devices >
   Pointing > Emulate Touch From Mouse (pointing/emulate_touch_from_mouse).
2. Keep Emulate Mouse From Touch OFF. The controller handles ScreenTouch/ScreenDrag
   only; mouse events are never processed as a second input path.
3. Run F5, hold the left mouse button and drag horizontally. Release and double-click
   with minimal movement to switch. A click-and-drag must never switch.
4. Test right/left drags inside and outside, repeated swipes for full revolutions,
   rapid double-clicks during cooldown, and continued movement during the phase.
5. Disable Emulate Touch From Mouse again for the phone build. It is OFF by default.
   Single-mouse simulation cannot reproduce two simultaneous fingers; use a phone
   for second-finger double-tapping while dragging.

### Real Android phone

Install matching Godot 4.7.2 export templates and configure the Java/Android SDK
paths in Editor Settings > Export > Android. Follow the engine version's
[Android export setup](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).
Add an Android export preset under Project > Export, mark it Runnable, and choose
a unique package identifier. Enable Developer Options/USB debugging on the phone,
connect USB and authorize the computer. Use Godot's Android remote-deploy button to
build/install/run a debug APK; see
[one-click deploy](https://docs.godotengine.org/en/latest/tutorials/export/one-click_deploy.html).
No SDK paths, signing secrets or APK are added to this repository.

Check landscape on a narrow and wide screen; compare equal fractional-width drags.
Test single taps, small jitter, long presses, drags that return to their start,
double-taps, a third tap after a double-tap, and a second finger double-tapping
while the first steers. Background/resume the app mid-drag and confirm no stuck
rotation. Monitor FPS during switching on the target phone.

### Automated touch validation

`godot --headless --path . --script res://tests/touch_validation.gd`

Checks proportional travel at 1280x720, 2560x1440 and 2400x1080 and 30/60/144 FPS,
tap/drag separation, pair consumption, cooldown, second-finger switching,
orientation-relative steering, real Godot touch dispatch and cancellation, ignored
mouse events, expired/distant taps and long presses. Headless import and all three
regression suites pass. Transition framing assertions now use normalized viewport
coordinates instead of assuming 1280x720. Real phone/manual mouse tests remain
unverified; the existing non-blocking certificate-store error remains.

## Phase 5: fixed obstacles and game over

Four editable instances live in scenes/obstacle_course.tscn:

| Instance | Surface | Center angle | Width | Z |
| --- | --- | --- | --- | --- |
| PartialInner | Inside | 0 degrees | 100 degrees | -40 |
| FullInner | Inside | any | 360 degrees | -65 |
| PartialOuter | Outside | 0 degrees | 110 degrees | -90 |
| SecondInner | Inside | 180 degrees | 100 degrees | -112 |

Red obstacles are inside; amber obstacles are outside. The default height is 2.4
units and depth is 1.2 units. These are lightweight arc prisms with emissive
placeholder materials. FullInner is a ring blocking every reachable inner running
angle; its central opening is not reachable with the current controller.

Reusable scenes/obstacle.tscn and scripts/obstacle.gd expose kind, angle_degrees,
width_degrees, z_position, cylinder_radius, height and depth. Main synchronizes the
shared radius. Edit the course instances to change placement. No random generation
or spawning system has been added; the existing fixed longitudinal loop remains.

scripts/obstacle_collision.gd is separate from placement. It sweeps each movement
segment in unwrapped angular/Z coordinates and returns the earliest hit fraction.
Z bounds include capsule radius; angular bounds include the capsule silhouette
using its height and radius. This is a deliberately conservative envelope at
corners rather than mesh-perfect capsule physics. Angle copies handle 0/360 seams;
Z copies handle the existing loop, even when a frame crosses the wrap. Sweeping
prevents high forward speeds from skipping thin obstacles.

Collision surface differs from the immediate visual phase transfer: the SOURCE
surface remains vulnerable until the 0.25-second transition finishes. The collision
sweep splits its time interval at completion, so a large frame cannot skip source
or destination checks. Switch early: beginning Q/double-tap immediately in front of
a barrier is not an invulnerability action. Death cancels the phase and shows the
contact surface. No conventional gravity or physics collision bodies were added.

On hit the player stops at the swept contact and GAME OVER appears. Press R, click
Restart, or tap Restart to reset position, angle, inside state, transition cooldown,
camera follow and touch gesture state. Touch restart directly handles screen-touch
press/release, so it works with mouse-from-touch emulation disabled.

### Playtest

- F5 without steering: hit the first red arc; confirm GAME OVER and no movement.
- R/tap Restart: confirm initial inside pose and working controls.
- Steer about a quarter-turn off the starting floor to avoid the first arc.
- Switch outside before the full red ring (allow the transition to complete).
- Stay away from the amber outer arc, or switch inside early to avoid it.
- Steer around the final red inner arc if inside. Continue through the fixed loop.
- Try switching too late into either barrier: the source surface must still hit.

### Checks performed

```powershell
godot --headless --path . --script res://tests/obstacle_validation.gd
godot --path . --script res://tests/obstacle_capture.gd
```

Obstacle tests passed at 30/60/144 FPS, cardinal/seam positions, capsule edges,
1000 units/second (test override), loop crossings, both transition directions and
mid-frame completion. Verified steering avoidance, full-ring inevitability inside,
source vulnerability, destination collision, R and native touch restart, restored
input/camera state, and completion of the four-obstacle course plus wrap.

The three earlier suites still pass; their free-running fixtures explicitly disable
Collision to isolate the systems they test. Godot 4.7.2 import passed without
script/resource errors. Launched D3D12 Forward Mobile and inspected four obstacle
views and game over. Captures: .godot/validation/obstacle_*.png. Real Android hardware
and manual gameplay remain unverified. Certificate-store environment error persists.

## Phase 6: procedural endless track (current startup)

F5 now runs a seeded segment stream. The fixed Phase 5 course remains in
scenes/legacy_main.tscn for regression tests. The tunnel is composed of reusable
scenes/track_segment.tscn instances sharing a mesh. Default segments are 80 units
long, with one obstacle row in the middle. The first segment is clear. Generation
keeps at least 200 units ahead and retires whole segments more than 30 units behind.
Two obstacle nodes per pooled segment are reused; meshes/materials are cached per
pattern. Hidden pooled obstacles are excluded from collision.

scripts/track_generator.gd owns generation, seed, pooling and spacing. The player
still uses its existing wrap signal, now every 1000 units solely to keep coordinates
small: all active segments, obstacles and the generation cursor shift by the same
amount. Pattern indices keep increasing; content is not repeated at the wrap.
Generated collision uses actual obstacle positions, with periodic Z copies disabled.
Large movement frames are populated before the collision sweep runs.

### Library and connection rules

patterns/standard.tres is a native Godot resource containing 11 configurable pattern
dictionaries. Each defines id, surface (0 inside/1 outside), angle (safe route in
degrees), and obstacles (up to two [kind, center_degrees, width_degrees] entries).
Kinds: 0 partial inner, 1 full inner, 2 partial outer. All obstacles occupy the same
row, using existing height 2.4/depth 1.2 and colors. The library includes four inner
arcs, one inner ring, two outer arcs, two opposed-surface patterns, and two ring +
outer-arc combinations. It is preloaded so Android export includes the resource.

The validator rejects blocked safe routes, accounting for capsule angular size and
an extra 10-degree margin. Connection spacing budgets a worst-case half-turn,
8/steering_response seconds of acceleration/braking allowance, switch duration,
cooldown, configurable reaction_time and capsule/depth clearance. Segment length
is the larger of this computed spacing (rounded to 10 units) and the minimum.
Speed and pattern distributions do not progress with distance.

This is conservative spacing plus tested route transitions, not a general planner.
Every ordered pair in the supplied 11-pattern library passed simulated navigation
using real movement, switches and collision at forward speeds 18/40/80, 60 FPS
(363 cases). Every initial pattern is also reachable from reset in these tests.
Three seeded 10,000-frame runs passed with collision enabled. This establishes
routes for those tested configurations, not survival for every player action,
custom pattern, device frame rate or modified controller configuration.

### Reproduce and inspect

Select Generator in main.tscn:

- seed_value (default 1337): same seed/controller/library repeats on restart.
- forced_patterns: optional repeating zero-based library indices, e.g. [9,7,4,2].
- debug_log: prints seed, logical segment index, pattern id and current Z.
- minimum_segment_length and reaction_time: constant spacing controls.
- pattern_library: replace/edit the resource to author patterns.

Remote Inspector exposes active/pool arrays, segment indices/pattern indices and
history (last 64 assignments). Restart via R/button resets RNG, logical cursor,
player and camera, reusing pool instances. Stop/relaunch the game after editing
speed, steering response, capsule size, library or spacing: geometry and spacing
are built at scene initialization, not dynamically retuned for Phase 7 yet.

### Validation and limitations

`godot --headless --path . --script res://tests/generation_validation.gd`

Checks pair routes, initial approaches, spacing, seed repeat/difference, restart,
object reuse, long-run coverage, rebasing, bounded history and ordinary pool size
(no more than seven segments in the tested runs). Existing four suites pass using
the preserved legacy fixture. Editor import passed. generation_capture.gd launches
Mobile rendering and writes .godot/validation/generated_track.png; that capture was
visually inspected. No native phone test or Android performance profile was run.

A single extreme frame/teleport can temporarily enlarge the pool to cover the whole
swept path; its peak allocation is retained for reuse. The source viewport still
adds rendering cost only during phase switching. The existing sandbox certificate
store error remains non-blocking. No scoring, coins, power-ups or progression added.

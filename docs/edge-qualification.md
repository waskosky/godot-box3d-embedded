# Post-preview-4 physics and browser findings

These checks use the unchanged preview-4 runtime `14a4f86` and its matching
native/ordinary/static artifacts. They extend the recorded scope; they do not
turn the experimental release into production certification.

## Separate terrain tiles and motor sleeping

The normal native suite adds one focused tile regression (49 tests total).
Its 24 cases cover capsule/box traversal in both directions across separate
coplanar mesh fixtures and continuous-mesh controls, on floors, walls and
ceilings. All pass with the release's unmodified macOS CI library. Equivalent
Node-entry exports, with unchanged physics setup and assertions, also pass in
Chromium and Firefox using both matching Release Web profiles.
The focused exports request one physics worker; the ordinary profile also
enforces one. This does not change the separately recorded eight-worker static
smoke/workload receipt for the release.

Split tiles show up to about 3.4 cm height error and slightly less progress;
continuous-mesh controls show about 0.5 cm. Adjacency is not welded between
fixtures. See [terrain limitations](behavior-differences.md#separate-terrain-tiles-are-not-one-welded-mesh).

`test_project/benchmarks/motor_sleep_probe.gd` confirms that an enabled motor
can sleep under default thresholds. A unit-inertia rotor capped at 0.001 impulse
per tick reaches about 0.029 rad/s before sleeping around tick 28; its
sleeping-disabled control keeps accelerating. A strong motor remains active;
a 0.005 rad/s target can sleep. Live reversal wakes the supported body but
does not override subsequent sleep policy. Keep the existing native hinge
direction convention and use `can_sleep = false` selectively for rotors that
must continue running slowly; no global sleep or solver policy was changed.

## Thin-hull CCD is an open engine defect

The new CCD check found a real failure. A radius-0.1 sphere requests oblique
velocity `(60, -600, 0)` toward a 40 m by 25 mm by 40 m box. Box3D clamps the
speed to its native limit (about 398 m/s normal velocity here). At a settled
30 Hz with four native substeps, CCD first stops its center at approximately
`y=0.095`. The next contact response takes it to `y=-0.0173`, then pushes it
toward the plate's underside (`y=-0.121` after eight ticks). Initial TOI is
detected; the failure occurs during subsequent response. The precise native
solver correction is not yet implemented.

The focused Godot checks include box/sphere movers, primitive/one-sided mesh
targets, rotated frames and 30/120 Hz. Their first cross-platform
[CI candidate](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43605539126)
fails the CCD check (Linux reports 49/50). An initial local pass was misleading:
the new Engine tick rate had not yet reached the physics space. The reproduction
now waits for the actual requested step before launching. It then fails
consistently natively and in both Release Web profiles in Chromium and Firefox.
Static worker-main execution is not exempt.

The independent C program
`test_project/benchmarks/ccd_thin_hull_repro.c` reproduces the same 30 Hz failure
without Godot or a browser. Both original-maintainer Box3D `3fc20f5` (the current
upstream adapter pin) and `be8c731` (preview 4) reproduce it, so the terrain
upgrade did not introduce this case. The same small C reproduction passes at
60/120 Hz with four substeps, and at 30 Hz with eight substeps. These are
bounded controls, not a universal fix or a reason to silently double the
adapter's simulation work. The adapter's default remains four substeps.

This is not exclusively a 30 Hz problem. A bounded native C parameter probe
also puts a radius-0.01 sphere at requested normal speed 300 m/s fully below
the plate at 60 and 120 Hz (final center about `-0.0353` and `-0.0474`). Passing
the larger sphere's 60/120 Hz controls is not general high-speed CCD acceptance.

Run the deliberately failing Godot reproduction with:

```sh
godot --headless --path test_project --script res://benchmarks/ccd_geometry_probe.gd
```

For the C program, build the pinned Box3D library with matching single precision
and compile the file against it, for example after the normal CMake build:

```sh
cc -std=c17 -I box3d/include test_project/benchmarks/ccd_thin_hull_repro.c \
  build/box3d/src/libbox3d.a -lm -lpthread -o build/ccd-thin-hull
build/ccd-thin-hull
build/ccd-thin-hull 4 0.01 300
```

Default four-substep execution returns failure for this known case. Passing
`8` selects the original larger-sphere comparison; optional further arguments
select radius and requested normal speed. None is a production qualification. Keep the assertions
intact and promote the reproduction to the normal regression suite when a
native fix exists. Do not claim that the green normal suite resolves this bug.

## Browser lifetime, visuals and performance

Headed Firefox 150.0.2 completes all six representative construction/movement/
cleanup cycles with no errors and stable node/resource counts. Both inspected
workload frames are readable. The host is contended (load averages about
6.8 to 10.8); the renderer is privacy-masked as "Radeon R9 200 Series, or
similar", not the identity of this machine's GPU. The old report's heuristic
hardware-eligible flag must not be treated as hardware qualification. The
runner now excludes that masked identity. Warm-up to submitted smoke frame
takes 38.538 seconds and first active workload is observed after another
38.401 seconds; these are diagnostics, not accepted startup budgets.

The first ordinary headed Firefox reload attempt passes 13 loads, then times
out on the next at the unchanged 90-second deadline, without an engine error.
It does not qualify 20 reloads. A repeat explicitly foregrounding each load
passes all 21 loads (initial plus 20 reloads), all 17 checks per load, and
60.001 seconds of post-PASS observation. Its final inspected text and geometry
are complete. The original failure remains recorded; this is foreground
desktop coverage, not background/resume or proof that intermittent glyph loss
is fixed. The runner now distinguishes requested from performed observation.

Headed Chromium (bundled default, explicit Metal and installed Chrome) cannot
launch within the bounded probe. Headless/software graphics do not close the
hardware gap. The earlier WebKit scene/canvas shader failure remains open.
No physical Android device is listed by adb and no physical iPhone is connected.
Real-GPU budgets, mobile and background/resume still require other evidence.

Local receipts, source/artifact hashes and frames are retained under
`build/validation/` in the qualification worktrees. Preview-4 compiler manifests
and published binary/template bytes are unchanged. Prioritize the native CCD
response investigation before further performance tuning or production claims.

---
title: Web preview qualification
---

# Web preview qualification

Current functionally qualified physics snapshot: `14a4f861352737838b40d722430e5184e6275d20`.
Download the matching native editor addon, static bundle or ordinary Web package
from [Web preview 4](https://github.com/waskosky/godot-box3d-embedded/releases/tag/v0.2.7-embedded.4).
This is an experimental development milestone, not production, rendered-frame,
hardware performance or physical-device certification. Earlier releases and
their immutable evidence are retained below for comparison and rollback.
Documentation and regression-only follow-ups do not change the tested physics
source or replace its artifact identity. Ordinary Web CI does not qualify static embedding.

## Web preview 4 (2026-11-14)

Runtime source `14a4f86` uses original-maintainer Box3D `be8c731` and adds
dense-mesh support, internal-edge adjacency with original ray-face indices,
and world-anchored pin/hinge/slider joints with deferred endpoint lifecycle.
It retains preview 3's filters/materials and hinge impulse correction. The
dependency remains `https://github.com/erincatto/box3d.git`.

- [Native qualification](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43560483117):
  all 48 physics tests on Linux, Windows and universal macOS, Godot 4.3
  compatibility, scalar UBSan runtime, macOS ASan runtime and sanitizer builds.
- [Ordinary Web](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43560485742):
  matching Debug/Release side modules and templates, Chromium smoke and complete
  packaging.
- [Static worker-main Web](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43560488286):
  newly linked Debug/Release templates pass 16 physics/backend checks in both
  Chromium and Firefox. Both Release workloads complete six construction,
  movement and cleanup cycles with stable post-warm-up node/resource counts.

The static template SHA-256 values are:

- Release: `2e4e825facbcfd1cc1b58eedc282674174d25287d572e16c8cf726f71bff3e55`
- Debug: `f2e00e978f98edbe12ad10e3b979bde550c5cf6bb8381e178926196d18874be1`

The combined smoke fixture adds the submitted-result-frame fence. It passes
all 17 physics/backend/render-submission checks against those exact static
templates in both browsers and both targets. Ordinary Release passes all 17
checks plus a reload with the exact CI side module and template, including
Firefox HTTP 304 revalidation. Fixture/export receipts and inspected frames are
included with the qualification evidence. No physics assertions were relaxed.
The final integration merge `02f3c88` also passes
[native CI](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43582081830)
and [ordinary Web CI](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43582081836).
Runtime inputs are unchanged from the separately qualified frozen binaries;
original compiler build manifests remain intact. Refreshed support documentation
is identified by `RELEASE_DOCUMENTATION.json`.

Large terrain construction and live shared-resource edits cost more. Adjacency
is within one mesh, not between separate terrain tiles. See the
[terrain tradeoff](box3d-terrain-evaluation.md#construction-tradeoff) and
[world-joint conventions](behavior-differences.md#ignored-joint-parameters).
Do not mix preview 4 native libraries or Web files with preview 3 templates.

These functional browser receipts use software graphics. Some inspected frames
retain missing glyphs despite all markers passing. WebKit's full-scene
scene/canvas shader failures also reproduce with official templates and
GodotPhysics without Box3D; WebKit acceptance still fails. Real-GPU visual and
performance acceptance, physical Android/iPhone, startup/frame/memory budgets
and background/resume remain open. See the
[capture investigation](web-capture-diagnosis.md) and
[release acceptance guide](release-qualification.md). Preview 3 remains available
for rollback; this release is still experimental, not production certification.

## Web preview 3 (2026-11-14)

The runtime source `c91a27b` combines live collision layer/mask refiltering,
live material updates and Godot-style mixing, staged joint setup and wake-up
fixes, corrected hinge impulse units, scaling warnings and ASan runtime CI.
It retains the original-maintainer Box3D pin `f36d061`; the newer mesh/terrain
dependency experiment is separate and is not included in this release.
In particular, preview 3 retains the old 512-triangle per-convex-body contact
cache and mesh-edge snagging reproduced by the new candidate's focused tests.
The general smoke does not cover those cases; see [mesh contact limits](behavior-differences.md#mesh-contact-limits-in-preview-3).

The [native pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43416087425)
passes all 46 tests on Linux x86-64, Windows x86-64 and universal macOS, plus
Godot 4.3 compatibility, Linux scalar UBSan runtime, macOS ASan runtime and the
separate ASan/UBSan compile/link check. The
[ordinary Web pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43416087703)
passes its Chromium smoke and complete package checks.

The [matching static workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43544498126)
builds clean source `c91a27b`, then passes all 14 smoke checks in Release and
Debug in both Chromium and Firefox, with no captured errors. Both Release
workloads finish all six physics/cleanup cycles with stable post-cleanup node
and resource counts. These are Linux software-GL observations, not hardware
timing or whole-memory leak qualifications. The template SHA-256 values are:

- Release: `b1f29f03c13c90020e22a8d340b780b9107bf31de3f27d20215dcafe2b1b1639`
- Debug: `8c8b7d2d0358d16b8a496c5d251c629d91421de54dd2be49ea1c81efcf5c6aee`

All four smoke captures were inspected. Release Chromium shows readable final
PASS text and scene geometry. Release Firefox and Debug Chromium retain missing
glyphs, and Debug Firefox shows the initial overlay despite passing console
results. Their cause is unconfirmed; the captures are not clean rendered-frame
acceptance. Real-GPU browsers, WebKit, physical Android/iPhone, cold/warm startup,
sustained pacing, memory growth and background/resume remain open gates.

When moving from preview 2, revisit [material tuning](behavior-differences.md#physics-materials)
and [hinge motor limits](behavior-differences.md#hinge-motor-impulse-budget).
An unchanged motor impulse cap permits 60 times the previous maximum torque at
60 Hz and time scale 1. Preserve desired torque with
`max_impulse = desired_torque * actual_physics_step_seconds`.

The release retains original build manifests and unchanged runtime hashes.
`QUALIFICATION.json`, the qualification ZIP and `SHA256SUMS` identify the
matching artifacts and evidence. Refreshed support documentation is identified
separately by `RELEASE_DOCUMENTATION.json`; its revision does not replace the
runtime source recorded in the original manifests. ASan instruments the adapter
and Box3D, not the official engine or cached godot-cpp archive, and does not
establish native leak detection. Follow [release qualification](release-qualification.md)
before changing an application's coordinated immutable dependency pins.

## Hinge motor units candidate (2026-11-09)

Candidate `e644782e88512fecfe64166281bd143b24189909` adds the focused
[hinge impulse fix (#46)](https://github.com/bearlikelion/godot-box3d/pull/46) to
the integration feed. It uses the actual full physics step to convert an angular
impulse cap into native torque. See [motor units and retuning](behavior-differences.md#hinge-motor-impulse-budget)
before adopting it; the old direct torque mapping made the same numerical cap
60 times weaker at 60 Hz / time scale 1.

On the same macOS 15.7.1 x86-64 / Godot 4.7 host, all 46 downstream native tests
pass. The standalone upstream branch, using upstream's unchanged Box3D pin,
passes all 36 native tests. The new quantitative regression covers 30/60/120 Hz,
runtime time-scale changes, a rotated axis, live/zero caps, motor disabling and
reversal, and two dynamic endpoints. Eight strength cases fail on the previous
binary. Existing high-strength hinge fixtures were retuned to preserve their
original 100 Nm at 60 Hz; their assertions were not loosened.

The new impulse regression and the joint setup/limit/wake-up regression also
pass with the adapter and Box3D instrumented by AddressSanitizer. This is focused
sanitizer coverage, not a new full-suite ASan or leak-detection receipt.

A clean ordinary Web export of `23a156b` passes all 14 smoke checks in local
headless Chromium (12.633 seconds) and Firefox (85.988 seconds), with no captured
errors. Both frames were inspected and show readable PASS text and geometry.
The later sampling-bound change affects only the native regression, not the
tested adapter or Web fixture. The export manifest records all three fixture
hashes and the unchanged dynamic template hash listed below. The side module is
`625c59a3de160310d5a5e17bddb22d54e4b46e1d35d8d579b7431117aa2cc580`.
These contended/headless timings are not startup or hardware acceptance.

The previous `75ee90b` candidate's
[static qualification completed successfully](https://github.com/waskosky/godot-box3d-embedded/actions/runs/42568959069),
but that does not qualify the new motor mapping. The new
[static workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/42671462450)
and [ordinary Web workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/42671461394)
initially reported GitHub internal server errors before their jobs could start.
The November 11 retries of both completed successfully. The
[native pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/42671461380)
also completed successfully, including all 46 tests in each runtime job.
Upstream PR CI remains a separate receipt. These candidate results were later
superseded by preview 3's matching live-filter snapshot above.

## Advancing readiness candidate (2026-11-09)

Candidate `75ee90bcbb4484c54d426c4852e079db07f420ed` is on `integration/next`,
not in preview 2's frozen binaries. It adds live material updates and Godot-style
rough/absorbent mixing, joint setup/wake-up fixes, scaling diagnostics and macOS
AddressSanitizer runtime CI. The focused upstream submissions are
[#44](https://github.com/bearlikelion/godot-box3d/pull/44) and
[#45](https://github.com/bearlikelion/godot-box3d/pull/45).

On macOS 15.7.1 x86-64 with Godot 4.7, all 45 native tests pass both normally and
with the adapter and Box3D instrumented by AddressSanitizer. The official engine
and cached 4.3 godot-cpp archive are not instrumented. Runtime preload/init and
the instrumented library were checked separately. This is not a leak-detector or
whole-engine safety receipt. Both independent upstream branches also pass their
36-test native suites against upstream's unchanged Box3D pin.

A clean ordinary Release Web export of `75ee90b`, built with Emscripten 4.0.20
and the existing 4.3 bindings archive, passes all 13 checks in local headless
Chromium and Firefox. The added live material and joint scenarios finish inside
the existing 180-frame movement window. They reproduced a sleeping hinge stuck
at its old limit before the wake fix; native sleeping hinge, slider and pin
regressions now cover that behavior too.

The ordinary template hash remains
`ffe2600af69db329d8a68f5a4872b8d00ae2e4b0536d3a789bf4ee8182b2cac9`;
the candidate side module is
`f1d0130c799029ed4d7717abc198ae97b56b54bf2e8e43fabc7c728918467dc0`.
Chromium's first observation was 14.112 seconds; a separate three-load run
passed in 35.618 / 34.226 / 30.070 seconds with a ten-second final observation.
Firefox passed in 79.091 seconds. No errors were captured, and both final frames
had readable text and visible geometry. These deliberately contended-host
observations establish functionality, not startup improvement or hardware budgets.

Matching static qualification is running separately in
[this candidate's static workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/42568959069).
The [ordinary Web CI](https://github.com/waskosky/godot-box3d-embedded/actions/runs/42568954433)
and two jobs in [native CI](https://github.com/waskosky/godot-box3d-embedded/actions/runs/42568954415)
encountered HTTP 504 errors downloading Godot, before those jobs could test the
candidate; an ordinary Web retry hit the same download failure. Those are not
passing receipts. At this checkpoint, downstream `main` remains `6a4002c` and
preview 2 remains unchanged. Require complete cross-platform and matching static
results before promoting this candidate to the reviewed baseline.

The [terrain diagnostic](heightmap-geometry.md#bounded-construction-diagnostic)
records the bounded 65/129/257-grid construction measurements. Non-unit scaling,
world-anchored joints, hinge motor impulse/torque conversion, debug-contact
collection and hardware/device qualification remain separate work.

## Web preview 2 (2026-11-06)

The release freezes the already-qualified `47cc6a0` source. Native editor
libraries for Linux x86-64, Windows x86-64 and universal macOS come from the
[matching native pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/41268466894).
Its ordinary Web and static Debug/Release bundles retain the original build
manifests and binary/template hashes. Refreshed documentation is identified
separately in `RELEASE_DOCUMENTATION.json`, and the release ZIP checksums cover
that packaging. `QUALIFICATION.json` links the source, CI runs and artifact
hashes; the qualification ZIP retains the browser reports and captures.

The preview includes the large-surface motion fix below and the October 28
shape-cast corrections: clear casts return `[1.0, 1.0]`, initial overlaps are
ignored, and obstacles later in the sweep remain detectable. The independent
upstream shape-cast submission is [PR #43](https://github.com/bearlikelion/godot-box3d/pull/43).
The downstream focused regression replaces overlapping assertions in the older
query test; this test organization does not change the released binaries.

Using the exact CI-built static Release template, local headless Chromium
passes all eleven checks on the initial load and 20 reloads, followed by a
60-second observation without captured errors. The initial observation is
7.233 seconds to physics PASS; subsequent loads range from 5.683 to 6.350
seconds. The final settled capture has readable text and visible scene geometry.
These headless/software-rendered observations do not establish hardware budgets
or resolve the separate Linux CI glyph artifacts.

Headless Firefox 151 also completes all six workload cycles with stable cleanup
counts and no captured errors, using the same template with one requested
physics worker. First active workload is observed at 40.079 seconds in a fresh
context and 38.810 seconds after the unchanged smoke warms that context. The
workloads finish in 169.747 and 171.997 seconds under the existing 180-second
limit; the warm-up smoke itself passes all eleven checks in 31.607 seconds.
Loaded/final captures are readable and show completed cleanup. Both startup
observations exceed the provisional 10-second fresh / 5-second warm goals,
and both reports retain `hardware_timing_eligible=false`. Host load and headless
rendering prevent attributing these observations to an isolated solver cost.
Earlier incomplete runs remain in the record and are not reclassified.

The November 6 local hardware probe still cannot launch headed Chromium,
Firefox or WebKit on a blank page. No physical Android or Apple devices are
connected. Headless WebKit also times out during launch before loading Godot.
These environment limits leave hardware timing, visual acceptance
and physical-device qualification open; the earlier software-GL results remain
the release's established browser coverage.

## Large-surface motion refinement (2026-10-31)

The adapter now advances using witness separation along GJK's normal. This
prevents tangential closest-point error from inflating the gap, overshooting a
surface and discarding an otherwise valid native cast. It addresses
[upstream issue #41](https://github.com/bearlikelion/godot-box3d/issues/41);
the independent upstream candidate is [PR #42](https://github.com/bearlikelion/godot-box3d/pull/42).
Dependency pins and contact tolerances are unchanged.

Both upstream and downstream changed from 444 misses to zero in the same
3,920-query diagnostic sweep on Godot 4.7/macOS. The new focused regression
passes 768 cylinder/box checks against large boxes and world boundaries,
including floors, slopes, walls, ceilings and clear or separating motion.
All 42 downstream native tests passed locally. The upstream candidate passes
all 36 tests locally and in Linux/Windows CI, with a passing macOS CI build.

The ordinary Web pipeline passes all eleven Chromium smoke checks, including
54 large-surface queries, in 5.837 seconds. The updated fixture runs these
queries alongside the existing 180-frame movement scene, preserving its duration.
Local headless Chromium also passes all eleven checks using the official
Godot 4.7 dynamic-link template; its 38.913-second observation is not a startup
performance qualification.

The static workflow restored the engine compilation cache, rebuilt matching
archives and hosts, and passed every smoke check under Xvfb/software GL:

| Target | Browser | Physics smoke | Seconds to physics PASS |
|---|---|---|---:|
| Release | Chromium | All eleven checks pass | 6.095 |
| Release | Firefox | All eleven checks pass | 7.078 |
| Debug | Chromium | All eleven checks pass | 6.961 |
| Debug | Firefox | All eleven checks pass | 6.303 |

Both Release workloads complete all six construction/movement/cleanup cycles
with the active `Box3DPhysicsServer3D`, no captured errors and stable cleanup
counts of seven nodes and three resources. First active workload is observed
at 2.836 seconds in Chromium and 3.973 seconds in Firefox. Both reports mark
`hardware_timing_eligible=false`; these CI observations do not establish device
performance budgets.

The ordinary capture, four static smoke frames and both workload loaded/final
pairs were inspected. Release Firefox and Debug Chromium smoke captures still
show missing glyphs; the other smoke captures and both completed workload
captures have readable text. This repeats the earlier software-GL limitation
and is not visual acceptance on target hardware.

The retained manifest identifies clean source `47cc6a0`, the original
`erincatto/box3d` repository and the unchanged dependency tuple. The bundle
checksum and all six enclosed archive/template hashes were verified. The
static template SHA-256 values are:

- Release: `82e703175cfb0ab33cf138faa91099b63db5d7d9ce3ec88f6ba059d899fcbccf`
- Debug: `dad1635f86792f800ca5cec6b921bf1c03106643bd12900c6af9c7c4363c6e34`

The exported `smoke_test.gd` hash is
`fd75f6ad08c600bacffdab321a33cae7c04abc7bd718f7f2e092b8f1339b03dd`.
The workload fixture retains its earlier hash. Keep these receipts with the
browser results when selecting a deployment pin.

## Consistency refresh (2026-10-28)

Consistency candidate: `9a4c0daa603753888e469ec6cf2717b0b4693a9a`.
The [static workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40746990330), [native build and physics suite](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40746980906), and [ordinary Web pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40746981088) retain this earlier snapshot's separate qualification evidence.

The refresh aligns ray and Viewport-picking regressions with the focused
upstream candidates while preserving the fork's Box3D pin and heightmap mesh
fallback. Internal recovery rays retain initial hits; public shape casts
explicitly ignore initial overlaps. A no-hit `cast_motion()` now returns
`[1.0, 1.0]` rather than an empty result. Native checks also verify that ignoring
an initial overlap does not hide an obstacle farther along the path. The Web
scene covers unobstructed and initially overlapping shape casts in its existing
direct-query check.

All 41 native tests passed locally on Godot 4.7/macOS and in CI on Linux,
Windows and macOS, plus the Godot 4.3 compatibility and UBSan runs. The combined
ASan/UBSan build also passed (build coverage, not an ASan runtime claim).
Ordinary Web CI passed all ten Chromium smoke checks in 5.642 seconds and
produced its package; its captured result text and scene geometry were inspected.

Static Web CI restored the engine compilation cache, rebuilt the matching
archives/hosts, and passed all four smoke runs under Xvfb/software GL:

| Target | Browser | Physics smoke | Seconds to physics PASS |
|---|---|---|---:|
| Release | Chromium | All ten checks pass | 5.469 |
| Release | Firefox | All ten checks pass | 5.418 |
| Debug | Chromium | All ten checks pass | 4.277 |
| Debug | Firefox | All ten checks pass | 4.868 |

Both Release workloads completed six construction/movement/cleanup cycles with
the active `Box3DPhysicsServer3D`, no captured errors and stable cleanup counts
of seven nodes and three resources. First active workload was observed at
1.693 seconds in Chromium and 2.879 seconds in Firefox. Both reports explicitly
mark `hardware_timing_eligible=false`; these are CI observations, not device
performance budgets.

All four smoke frames and both workload loaded/final pairs were inspected.
The final workload frames show completed cleanup with readable text. Missing
glyphs recur in Release Firefox and Debug Chromium smoke captures, while the
other two smoke captures are readable. This is not isolated to Firefox and
does not establish hardware visual acceptance. Capture timing versus a
rendering defect still needs a controlled comparison.

The retained manifest identifies clean source `9a4c0da`, the original Box3D
repository and unchanged dependency pins. The bundle checksum and enclosed
artifact hashes were verified. Tested template SHA-256 values are:

- Release: `fdfcef88cd7976157f5868136c2bfd4e49f6c949b9b0cb03d0b7fdde739c36e2`
- Debug: `4caecb6e0ad75d8e0d1cd11b64be5db90035514b411c3900d6cb102079018996`

The exported `smoke_test.gd` hash is
`61a2548d39d89971f39af896ed9859317ec59cd94d3fe53029a9fc1351428415`;
the unchanged workload fixture retains the hash recorded below. Documentation
follow-ups do not replace this exact tested source/artifact identity.

## Earlier automated static results (2026-10-25)

Automation source: `ddcb1659b9adc707f83fb5fd821da85e20f5f5fd`.
The earlier [static workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243192), [native build and physics suite](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243167), and [ordinary Web pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243207) retain that source's separate qualification evidence.

The initial [Linux static run](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40237979182) built both hosts and passed Release Chromium's ten checks. Headless Firefox could not create a WebGL2 context (`AllowWebgl2:false`), so it never started Godot. The retry uses headed browsers under Xvfb with an explicit Mesa software-rendering configuration. Its results remain ineligible for hardware timing claims.

The retry passed on source `ddcb165`. Both compiled templates, their matching static archives, dependency versions and build flags are recorded in the retained `BUILD_MANIFEST.json`. Engine compilation was restored from the previously saved cache; both targets still ran their archive build and SCons dependency checks.

| Target | Browser | Physics smoke | Seconds to physics PASS |
|---|---|---|---:|
| Release | Chromium | All ten checks pass | 7.369 |
| Release | Firefox | All ten checks pass | 9.531 |
| Debug | Chromium | All ten checks pass | 7.497 |
| Debug | Firefox | All ten checks pass | 6.641 |

Both Release workloads completed all six construction/movement/cleanup cycles, reported the active `Box3DPhysicsServer3D`, and retained stable node/resource cleanup counts. Neither captured an engine/browser error. First active workload was observed at 3.102 seconds in Chromium and 4.647 seconds in Firefox; these are single CI observations, not device startup budgets.

All four smoke frames and both workload loaded/final frames were inspected. Three-dimensional geometry and completed workload cleanup were visible. Firefox's software-rendered captures showed incomplete text/glyph updates despite passing console checks; those captures do not establish visual acceptance on target hardware. A persistent rendering defect versus capture timing still needs investigation on a settled, hardware-rendered frame.

The tested CI template hashes are:

- Release: `973eb4f48852cf30a88ada03346e7b6c118a053d0e7f32f09bf06a198b91e08d`
- Debug: `61fd4c2312584f41e9d3056b4b53f500f7fd08f1b3b6ead555e2f3ef6b0b9c29`

These results qualify bounded physics behavior and cleanup under the stated software-GL configuration. They do not replace the local observations below or establish hardware frame pacing, total live memory, visual correctness, or mobile acceptance.

## Workload routing

The first standalone worker-main workload attempt ran the ordinary smoke instead of the requested workload. In this host, `JavaScriptBridge.eval()` reads the worker's URL and globals. The workload flag belongs to the browser page.

The candidate reads page query parameters and publishes status through Godot's proxied `JavaScriptBridge.get_interface()` objects. The runner still requires the full six-cycle result and stable cleanup; an ordinary smoke PASS cannot satisfy that check. Physics construction and assertions were unchanged by this routing fix. Export manifests retain these fixture hashes:

- `smoke_test.gd`: `a763c33812e8a48b68266c8b5cf7c21e57b8afe636ab95333d68d25b292445da`
- `stress_test.gd`: `1c56d4da45325e67b6a7a50bd1907b384d2ea516553fa6adb60b3055895920bb`

## Local comparison (2026-10-25)

These exports used source `18fc237e80b87f55bc41b2573b6f615adcb032ae`. The later automation candidate changes CI display configuration and runner options; its C++ physics adapter and fixture assertions are unchanged.

The representative workload creates 16 characters, 128 rigid bodies and two 65 × 65 terrain owners. Each run requests six ten-second active periods with world construction and cleanup between them. The same scene and assertions were exported for both host profiles; only the requested physics worker count differs.

The host was macOS 15.7.1, x86_64, with four physical/eight logical CPU cores and Playwright 1.61.0. Chromium 149 used SwiftShader; Firefox 151 reported an Intel-family renderer. The host had competing activity, with observed one-minute load averages from 7.8 to 26.0. Headed browsers could not launch even a blank page. All measurements below are headless and have `hardware_timing_eligible=false`.

Before measuring, provisional desktop goals were recorded: first active workload within 10 seconds for a fresh context and five seconds after warm-up; frame p95 within 20 ms and p99 within 33.4 ms; active page-timer p99 within 50 ms. Functional acceptance separately requires all six cycles and stable post-warm-up cleanup.

| Browser | Profile | Workers requested | Fresh first active (s) | Warm first active (s) | Workload result |
|---|---|---:|---:|---:|---|
| Chromium | Ordinary extension | 1 | 4.136 | 3.417 | Both runs pass 6/6 cycles and cleanup |
| Chromium | Static worker-main | 1 | 4.327 | 2.706 | Both runs pass 6/6 cycles and cleanup |
| Chromium | Static worker-main | 4 | 4.505 | — | Passes 6/6 cycles and cleanup |
| Chromium | Static worker-main | 8 | 4.280 | — | Passes 6/6 cycles and cleanup |
| Firefox | Ordinary extension | 1 | 51.059 | 52.589 | Timeouts after 5/6 and 4/6 cycles |
| Firefox | Static worker-main | 1 | 70.190 | 47.438 | Both time out after 4/6 cycles |
| Firefox | Static worker-main | 4 | 69.161 | — | Timeout after 3/6 cycles |
| Firefox | Static worker-main | 8 | 51.229 | — | Timeout after 5/6 cycles |

All six Chromium runs completed with no captured engine/browser errors and stable node/resource cleanup after the first-cycle warm-up. All six Firefox runs exceeded the unchanged 180-second limit. No physics failure was reported before those timeouts, but partial cycles do not pass lifetime acceptance. Selected loaded and final frames were inspected, including a Chromium completion and Firefox's incomplete cleanup state.

Fresh means a new browser context, not a flushed operating-system cache. Warm means the unchanged ten-check smoke first passed in the same browser context, followed by workload navigation. Each startup cell is one observation, and first active is a polled workload state rather than first useful frame or isolated compilation time.

## Local follow-up (2026-10-28)

This diagnostic reused the earlier `18fc237` static single-worker export, not
the newer consistency candidate. Playwright 1.61.0 was retained on the same
macOS host. Firefox, Chromium and WebKit all timed out launching a blank headed
browser within 15 seconds, before any Godot or physics code loaded. The browser
session issue remains unresolved; unrelated host processes were left alone.

Headless Firefox 151 passed all ten smoke checks in 47.675 seconds. A capture
taken three seconds after completion had readable text and visible scene
geometry. The workload's loaded/final captures also had readable text, but its
final capture was an incomplete cleanup state, not a completed six-cycle run.
These local captures do not reproduce the earlier Linux software-GL glyph
artifacts, and do not establish whether those artifacts were persistent or
capture-timing related.

The unchanged 180-second workload deadline was exceeded again. First active
workload was observed at 83.932 seconds, with one-minute host load averages
of 14.1 at start and 24.4 at finish. No physics assertion failure was observed
before timeout, but partial progress is not a passing workload result. The
Intel-family renderer identification does not make this contended, headless
run hardware-timing eligible. Startup, frame pacing and visual acceptance
still need an idle host with a working headed browser.

## Interpretation and remaining gates

The local runs do not establish the frame-pacing budget. After the first cycle, worst per-cycle frame p95 ranged from about 252–349 ms in the ordinary Chromium runs and 271–744 ms in static Chromium runs. The renderers, host contention and screenshot overhead preclude a hardware capacity claim. Increasing physics workers did not produce a dependable improvement in this environment.

Page scheduling was better in the single-worker static observations: fresh-context active timer p99 was about 286 ms versus 535 ms for ordinary Chromium, and 36 ms versus 162 ms for ordinary Firefox. These are limited, contended observations; a 20 ms page timer is not an input-to-display latency test. The Firefox static workload remained incomplete, and startup was not consistently improved by static embedding.

Retain raw JSON, export manifests, template hashes and screenshots with these results. The local Release template SHA-256 was `c19dfcbceb3fdc2bf7bd7055b56a64abde4196bf87d9373c58f60ee49ca9bf34`. CI builds have their own manifests and hashes; do not substitute this local artifact for a CI-built host.

The next performance investigation should profile Firefox startup and long frames on an otherwise idle host with a working headed browser, measuring compilation, rendering, page input and actual physics work separately. The current observations do not isolate a Box3D solver defect or certify a leak-free process. Wasm capacity and browser heap samples do not include all live native/GPU allocation.

Physical Android/Chrome and iPhone/Safari, WebKit, background/resume, application-specific controllers/terrain, and sustained performance/memory budgets remain separate gates. Follow [release qualification](release-qualification.md) before changing an application's immutable deployment pin.

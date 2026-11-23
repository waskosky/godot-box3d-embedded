# CCD impact-to-response correction

This native engine correction addresses the thin-surface failure
recorded in [preview 4](edge-qualification.md#thin-hull-ccd-is-an-open-engine-defect).
The already-published preview-4 binaries/templates are unchanged and affected.

## Cause and correction

The time-of-impact calculation stopped rounded shapes at a core distance of
`max(linearSlop, radiusA + radiusB - linearSlop)`. That deliberately overlaps
their surfaces. CCD retained their incoming velocity for the next step's
contact response. An overlapping contact uses the soft position-bias solve
before position integration. Its compliance can allow a small, fast body to
cross a thin surface before the subsequent hard velocity solve stops it.
The next manifold can then select the other side of the surface.

The correction uses `radiusA + radiusB + linearSlop` for **time of impact**.
Its root-finding tolerance is only a quarter of that positive surface gap.
Solid triangle sweeps also include `B3_MESH_REST_OFFSET` in the triangle proxy
radius, matching the offset subtracted by mesh/heightfield manifolds. Without
that term, a geometrically positive gap can still be zero or negative in
solver space; the first candidate fixed thin boxes but the mesh regression
correctly remained red. Sensor sweeps do not receive the solid rest offset.
The next step consequently starts separated and uses the existing hard
speculative constraint before position integration. The gap is consumed by
that solve; it is not a persistent collision margin. Friction, restitution,
angular response, solver iteration counts and native four-substep defaults
are unchanged. The separate shape-cast/query target is also unchanged.

This is orientation-independent, shared by convex/mesh/heightfield TOI paths,
and adds no extra casts, solver passes, allocations or per-contact storage.
It is not a floor-specific position clamp or a change to bullet velocities.
Exact trajectories/hashes can change because impact timing changes; do not
expect replay compatibility with uncorrected binaries.

## Build and dependency policy

`box3d` and `dependencies.lock` now pin the maintained
[`waskosky/box3d`](https://github.com/waskosky/box3d) fork. The correction lives
directly in its `src/distance.c` and `src/shape.c`, based on upstream `be8c731`.
Both CMake and SCons compile the same pinned source. The former
`scripts/prepare_box3d.py` overlay has been removed; the engine fork owns the fix
and its native regression, so upstream acceptance is not a release gate.
Review upstream updates while retaining that coverage; do not switch the
dependency back to uncorrected upstream code.

Normal native, ordinary Web and static Web build commands require no new
option. Build matching native editor libraries and Web artifacts from the
same source. A static host **must be relinked**; copying a new side module or
archive beside an old template cannot update its embedded physics engine.
Package receipts identify the native fork URL and immutable source pin.

The first maintained native baseline, used by preview 5, was `f3c62759239f662fb9c8463c1108cfb2f74047ef`.
Its corrected `distance.c` and `shape.c` are byte-for-byte identical to the
source-overlay runtime qualified below; moving the correction does not introduce
another physics change. The fork owns the 774-case regression and keeps all
determinism assertions enabled. Local native Release runs pass all 29 test groups
in single and double precision, with these updated CCD trajectory baselines:

| Precision | Ragdoll sleep step / hash | Mesh-drop sleep step / hash |
|---|---|---|
| Single | 324 / `8CDCDB2A` | 188 / `53CC9371` |
| Double | 368 / `B2E77EF9` | 188 / `4A875B5D` |

These replace the uncorrected trajectories, not the worker-count or SIMD
repeatability assertions. The original overlay evidence below retains its
historical upstream-suite result; it is not the fork's current test baseline.

The [native fork CI](https://github.com/waskosky/box3d/actions/runs/43633021834)
passes all 19 jobs: native tests across Linux/macOS/Windows compilers and ARM64,
optimized and double-precision variants, address/thread/memory sanitizer paths,
Emscripten compilation, and sample builds. The checked goldens agree across the
tested native configurations. This is not replay compatibility with old binaries.

## Fork-source qualification

Adapter runtime `c76c13045bbf2a498697fc4ace8c6a9c56b09f6d` builds the pinned
native fork directly, without the former source overlay. Qualification on
2026-11-14 includes the following; the subsequent qualification/attribution
documentation commit does not change this runtime.

- [Native adapter CI](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43633172731):
  Linux, Windows, universal macOS, minimum Godot 4.3, ASan and scalar UBSan
  runtime checks each pass all 774 native controls and all 50 Godot tests.
- [Ordinary Web](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43633175287):
  fresh extension/template builds, all 18 Chromium smoke markers, and packaging
  pass. The package manifest records the maintained fork URL and native pin,
  with no source-overlay dependency; the downloaded bundle checksum verifies.
- [Static worker-main Web](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43633178086):
  freshly linked Release and Debug templates pass all 18 required smoke markers
  in Chromium and Firefox. The Release workload passes six cycles per browser,
  requesting eight physics workers, with stable cleanup counts and no reported
  errors. Its package receipt identifies `waskosky/box3d` and the exact native
  pin above; the downloaded bundle checksum verifies. The Release template hash
  is `e748f401c84b6effaaf7f5f719d766fb6955d36ae3e2b3e181eba315f98ec492`.

Visual inspection of these static Release frames again found readable text in
Chromium and missing-glyph segments in Firefox. The ordinary Chromium capture
also has missing-glyph segments, consistent with the previously recorded
[intermittent text defect](web-capture-diagnosis.md). This source-ownership
migration does not fix that rendering limitation. These software-graphics runs
do not establish real-device performance budgets or replace published preview-4
artifacts.

## Focused regressions

- `test_project/tests/ccd_geometry_test.gd`: 144 cases at applied 30/60/120 Hz,
  two sizes, sphere/box/capsule movers, thin hull and one-sided mesh targets,
  floors/walls/ceilings/oblique frames. Checks finite authoritative positions,
  support-side containment, stopping response and preserved tangential travel.
  It waits for the requested physics step before launching, avoiding the
  startup-rate coverage bug in the earlier diagnostic.
- `box3d/test/test_ccd_response.c`: 774 independent native
  cases across sizes, speeds, 1/4/8 substeps and hull/mesh/heightfield targets,
  plus four-worker static, kinematic and dynamic targets, restitution and grazing
  controls. CMake's `check-ccd-response` target runs them; the normal headless
  runner includes it. The engine's own test suite runs the same `CCDResponseTest`;
  there is no second copy of those controls in the adapter.
- The Web smoke scene requires 18 small-projectile response cases on thin boxes
  and meshes, on floors, walls and ceilings with sphere/box/capsule movers, in
  addition to its prior physics checks. It does not change the scene's tick rate.
- The original small standalone `ccd_thin_hull_repro.c` remains available;
  the former GDScript benchmark now delegates to the normal regression.

The uncorrected native control passes only 264/774 cases; the corrected native
control passes 774/774. The new Godot regression also fails against the
unchanged preview-4 library. These negative controls demonstrate that the
tests exercise the defect rather than just detecting a loaded backend.

The original source-overlay qualification described below used a pristine
upstream checkout, before the correction moved into the native fork.
The local scalar Debug build also passes all 774 controls with UBSan enabled.
Of the 28 upstream core test groups, 27 pass unchanged. The remaining group
first asserts the old exact ragdoll trajectory: the corrected single-precision
run sleeps at step 324 with hash `8CDCDB2A`, versus upstream's 277/`5E042B6E`.
Mesh-drop also changes to step 188/hash `53CC9371`. A separately retained
copy of that test, with only old-golden assertions excluded, passes all its
worker-count and SIMD-width equality checks. No original test or assertion in
the dependency checkout is modified. This is local repeatability evidence,
not a claim of an unchanged upstream suite or cross-platform replay identity.

## Original source-overlay qualification

Runtime candidate `bf68b12767d311587c3781a7bda843c552d3c108` was tested on
2026-11-14. The final documentation-only follow-up does not change that runtime.

- Native: [the complete CI matrix passed](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43624789084),
  covering Linux, Windows, universal macOS, minimum Godot 4.3 compatibility,
  ASan and scalar UBSan runtime checks. The normal suite has 50 tests, including
  the 144-case CCD regression, and runs the 774 native controls first. Local
  Godot 4.7 also passes all 50 tests with a freshly built extension.
- Ordinary Web: [build, Chromium smoke and packaging passed](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43624791769).
  All 18 required smoke markers pass, including the thin-hull/mesh response
  contract. The captured final frame was also visually checked.
- The same ordinary-Web artifacts also pass the full 144-case CCD fixture in
  local Chromium 148.0.7778.96 and Firefox 150.0.2. Only the fixture's entry point
  and scene-tree access were adapted for Web export; its physics assertions were
  unchanged. This ordinary build enforces one physics worker.
- Static worker-main Web: [matching Debug/Release builds and browser qualification passed](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43625406853).
  Both targets pass all 18 smoke markers in Chromium and Firefox. The Release
  workload also passes six cycles per browser with stable cleanup counts and
  no reported errors. These CI runs use software graphics, not device budgets.
  The artifact contains matching archives, templates, hashes, and browser receipts.
- That exact static Release template also passes the full 144-case fixture in
  local Chromium 148.0.7778.96 and Firefox 150.0.2, requesting eight physics
  workers. Its SHA-256 is
  `7c80e56560accec13079f1bd58b952281d7d9557f80bfc1af0f05b5a99c43c16`.

Visual inspection of the static Release frames found complete readable text in
Chromium, but the Firefox frame still has the previously recorded missing-glyph
segments despite passing physics/console checks. This is not a rendering fix;
the [separate capture investigation](web-capture-diagnosis.md) remains relevant.

Do not interpret these bounded checks as arbitrary-scale CCD, real-device or
production certification. Physical mobile/GPU budgets and the previously
recorded rendering/background-resume limitations remain open. The published
preview-4 artifacts have not been replaced; use matching newly built artifacts.

# CCD impact-to-response correction

This downstream source correction addresses the native thin-surface failure
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

`box3d` and `dependencies.lock` still pin original-maintainer
`erincatto/box3d` at `be8c731`. `scripts/prepare_box3d.py` verifies the upstream
`distance.c` checksum and stages a corrected copy in the build directory.
Both CMake and SCons compile that copy instead of the original. The submodule
stays clean, including static-template builds; a dependency/source change
fails closed until this correction is reviewed. CRLF checkouts are supported.

Normal native, ordinary Web and static Web build commands require no new
option. Build matching native editor libraries and Web artifacts from the
same source. A static host **must be relinked**; copying a new side module or
archive beside an old template cannot update its embedded physics engine.
Package receipts identify the source overlay as well as the upstream pin.

## Focused regressions

- `test_project/tests/ccd_geometry_test.gd`: 144 cases at applied 30/60/120 Hz,
  two sizes, sphere/box/capsule movers, thin hull and one-sided mesh targets,
  floors/walls/ceilings/oblique frames. Checks finite authoritative positions,
  support-side containment, stopping response and preserved tangential travel.
  It waits for the requested physics step before launching, avoiding the
  startup-rate coverage bug in the earlier diagnostic.
- `test_project/benchmarks/ccd_response_controls.c`: 288 independent native
  cases across sizes, speeds and 1/4/8 substeps, plus four-worker static,
  kinematic and dynamic targets, restitution and grazing controls. CMake's
  `check-ccd-response` target runs them; the normal headless runner includes it.
- The Web smoke scene requires a small-projectile response check on floors,
  walls and ceilings with sphere/box/capsule movers, in addition to its prior
  physics checks. It does not change the scene's tick rate.
- The original small standalone `ccd_thin_hull_repro.c` remains available;
  the former GDScript benchmark now delegates to the normal regression.

The uncorrected native control passes only 102/288 cases; the corrected native
control passes 288/288. The new Godot regression also fails against the
unchanged preview-4 library. These negative controls demonstrate that the
tests exercise the defect rather than just detecting a loaded backend.

Matching full-suite and browser build receipts are recorded after candidate
qualification. Do not interpret these bounded checks as arbitrary-scale CCD,
real-device or production certification. Physical mobile/GPU budgets and the
previously recorded rendering/background-resume limitations remain open.

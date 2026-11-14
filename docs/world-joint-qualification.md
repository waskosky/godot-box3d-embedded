# World-joint integration qualification

The integration candidate adds one-body pin, hinge and slider constraints and
their endpoint lifecycle handling. Empty body B means a world-space frame;
each space shares one lazily created shapeless static endpoint. It also retains
the [newer terrain contacts and construction tradeoff](box3d-terrain-evaluation.md).
This is an experimental functional milestone, not production certification.

## Matching runtime

Clean runtime source `14a4f861352737838b40d722430e5184e6275d20` passes:

- [Native qualification](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43560483117):
  all 48 physics tests on Linux, Windows and universal macOS, minimum-Godot
  compatibility, address/undefined-behavior runtime checks and sanitizer builds.
- [Ordinary Web](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43560485742):
  extension, matching dynamic-link templates, browser smoke and complete package.
- [Static worker-main Web](https://github.com/waskosky/godot-box3d-embedded/actions/runs/43560488286):
  newly linked Release and Debug templates pass all 16 physics checks in
  Chromium and Firefox. Both Release browsers complete six sustained
  construction/movement/cleanup cycles with stable post-warm-up node/resource
  counts and no captured errors. This is not a whole-memory leak proof.

Static template SHA-256 values:

- Release: `2e4e825facbcfd1cc1b58eedc282674174d25287d572e16c8cf726f71bff3e55`
- Debug: `f2e00e978f98edbe12ad10e3b979bde550c5cf6bb8381e178926196d18874be1`

The capture corrections were merged at
`f92922af05b4052ebcfa767d40310d512ef2674f` without changing `src`, Box3D,
dependency pins or runtime build inputs. Its ordinary export passes all 17
physics/render-submission checks plus a reload in both browsers, including
Firefox HTTP 304 revalidation. Export manifests identify fixture and runtime
hashes separately. A submitted frame is not a pixel-correctness certificate.

The combined fixture also passes all 17 checks in both browsers against each
new static template above. Those export manifests retain their original source
and dirty-state flags; documentation-only edits during the Debug export do not
change the fixture hashes. Both profiles' frames were inspected and retain the
same intermittent text artifacts. Runtime and test source are unchanged from
the separately identified qualified revisions; support documentation is versioned
separately from the frozen runtime binaries.

## Focused behavior and limits

The new native fixture covers either NodePath slot, non-origin/rotated frames,
asymmetric hinge limits and live reversal, pin-anchor edits, slider travel,
deferred construction, cross-space convergence, space destruction, reattachment
and endpoint deletion/rebinding. A weak rotated rotor with sleeping disabled
isolates the full-tick impulse budget; this does not change native sleep policy.
Existing physics assertions and Web movement windows were not relaxed.

Hinge angle/motor direction still uses Box3D's B-relative-to-A convention.
Unsupported tuning and scaling remain unsupported; see the
[behavior guide](behavior-differences.md#ignored-joint-parameters).

The [capture investigation](web-capture-diagnosis.md) records intermittent glyph
loss despite successful physics/frame markers. A full WebKit scene reproduces
scene/canvas vertex-shader errors with official Godot templates and GodotPhysics,
without Box3D. A simple label-only control renders, and letting the Box3D scene
continue can yield physics PASS despite shader errors. The overall WebKit run
still fails; backend startup or physics success does not excuse rendering errors.
Headed WebKit also reproduces the shader failure on this host.

Physical Android/iPhone, real-GPU visual acceptance, application-specific
startup/frame/memory budgets and background/resume remain open. This qualified
runtime is included in [preview 4](web-preview.md#web-preview-4-2026-11-14) and
promoted to the reviewed downstream baseline. Preview 3 remains available for
rollback. Keep the native addon, chosen Web profile and build receipts together;
do not mix these newer runtime artifacts with preview 3 templates.

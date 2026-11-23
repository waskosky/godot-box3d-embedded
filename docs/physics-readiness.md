# Physics readiness

This is a validated development milestone, not production certification.
Downstream `main` records the reviewed baseline and its stated qualification;
`integration/next` combines independent candidates for downstream testing;
upstream pull requests remain based directly on upstream `main`.

The [Web preview qualification](web-preview.md) records the current static Debug/Release CI results and the separate local browser workload comparison, including its failed Firefox deadlines and unqualified hardware/device budgets.

The [capture investigation](web-capture-diagnosis.md) separates physics PASS,
render submission, cached-navigation handling and the still-unresolved glyph
artifacts. A successful console check is not a visual acceptance result.

## Behavioral coverage

The native suite exercises actual Godot bodies and queries, including:

- Geometric recovery for sphere/capsule/box/cylinder/convex shapes against
  primitives, slopes, trimeshes, heightmap resources and world boundaries.
- Centered heightmap bounds, non-flat heights/cell diagonals, body/attachment
  rotations, rigid support and NaN holes. The [heightmap adapter](heightmap-geometry.md)
  uses a static mesh fallback, not Box3D's compressed native heightfield path.
- Compound shape indices/transforms, disabled slots, competing floor/wall
  normals, collision priority and per-call body/object exclusions.
- Read-only motion queries, margin shells, separation-ray recovery/casting,
  grounded terrain traversal and rigid loads on idle/moving characters.
- Swept cylinder/box contacts against large boxes and world boundaries, including
  translated starts, slopes, walls, ceilings and clear or separating motion.
- Animated kinematic platform carry, clean stops and small linear/angular
  targets; motion collisions report the platform's velocity.
- Direct-query penetration pairs, mesh/heightmap targets, margins, rest normals
  and rotating contact velocity; unobstructed shape casts and initial-overlap
  exclusion without hiding later obstacles; ray inside/backface flags and input
  face indices.
- Viewport body/area picking, runtime toggles and an unpickable foreground
  object, without filtering ordinary scripted rays.
- Floor-angle classification, descending steps, rough rotated heightmaps,
  hole-boundary falls and moving/rotating platform jump detachment.
- CCD against a thin wall, rotated off-center impulse/inertia, sleep/wake,
  sustained finite states and repeated body creation/removal.
- Sleeping rigid bodies wake after a position or rotation change; rewriting
  the current physics pose leaves them asleep.
- Separate coplanar terrain tiles in both directions on floors, walls and
  ceilings, with continuous-mesh controls and bounded support height.
- Live material friction/restitution edits and rough/absorbent mixing; staged
  hinge/slider setup, motor reversal, live limit changes, sleeping-body wake-up,
  connected-node teardown and setters after native joint destruction.
- Quantitative hinge motor impulse budgets across 30/60/120 Hz, time-scale
  changes, rotated axes, live edits and equal/opposite dynamic endpoint response.
- World-anchored pin/hinge/slider constraints in either NodePath slot, non-origin
  rotated frames, asymmetric hinge limits, live edits and the world-hinge motor
  budget. Deferred RID creation, cross-space endpoints, space destruction,
  reattachment and deletion/rebinding exercise the same endpoint lifecycle.

Run the complete native suite with a matching Godot executable:

```sh
GODOT_BIN=/path/to/godot JOBS=4 scripts/run_headless_tests.sh
```

The [Web smoke scene](../WEB_QUICKSTART.md#verify-the-included-smoke-project)
checks live character slopes/terrain, large-surface motion, loads and platform movement as well as
rigid settling, areas, hinges and separation rays. The advancing smoke also
checks live material edits and hinge/slider limits within its existing movement
window. Run the same release export
in Chromium, Firefox and WebKit. Its small character-query timing is diagnostic:
it is not a device-performance or memory-growth qualification.

The opt-in [desktop Web workload](web-stress.md) adds repeated terrain/body
construction, sustained movement and cleanup measurements to that same export.
The [native terrain diagnostic](heightmap-geometry.md#bounded-construction-diagnostic)
isolates construction and shared-resource update costs without imposing a
machine-specific timing assertion on normal tests.

Use `test_project/benchmarks/scaling_probe.gd` as an opt-in diagnostic of live
fixture/query differences. Unsupported scaling is warned about, not normalized
or implicitly declared supported. The [behavior notes](behavior-differences.md)
also explain finite world boundaries and material migration.

## Moving meshes and jointed bodies

The [native pin](../dependencies.lock) includes these fixes beyond preview 5:

- A lifting or tilting triangle mesh can contact a rigid body that was initially separated from it. The native triangle cache tracks the visitor relative to the mesh. Previously, a moving mesh could pass through a stationary cube even though a box platform picked it up. See [Box3D #231](https://github.com/erincatto/box3d/issues/231).
- Freezing and unfreezing a hub connected to sleeping bodies preserves both joints without a kick. The engine wakes the connected islands before transferring any joint. See [Box3D #235](https://github.com/erincatto/box3d/issues/235).
- A native body with a baked compound or heightfield must stay static. Asking to make it dynamic or kinematic is a no-op; unrelated bodies keep simulating. The [native regression](https://github.com/waskosky/box3d/blob/8520de94af99dafa7d5e78ea4ff8401aadddf547/test/test_body.c#L704) also passed as WebAssembly in Chromium and Firefox. The Godot browser scene does not exercise this native API directly: the adapter uses ordinary shape attachments and a mesh-backed heightmap. See [Box3D #234](https://github.com/erincatto/box3d/issues/234).

The browser smoke now requires the mesh elevator to pick up a separated cube and a sleeping brick to remain asleep on an unchanged pose but fall after it is lifted. These checks do not qualify moving concave *dynamic* bodies. The published preview 5 binaries are unchanged.

**Qualified Godot 4.7 development builds (2026-11-23):** adapter [`5decf84`](https://github.com/waskosky/godot-box3d-embedded/commit/5decf84c549405fbeb3d94c2b1fcb8fcf100d9e8), native [`8520de9`](https://github.com/waskosky/box3d/commit/8520de94af99dafa7d5e78ea4ff8401aadddf547). Download the named artifacts from these runs:

- [Static worker-main: `godot-box3d-embedded-static-web`](https://github.com/waskosky/godot-box3d-embedded/actions/runs/45147938595). Both newly linked templates passed all 20 smoke checks in Chromium and Firefox. Each browser also completed six Release workload cycles with stable post-cleanup node and resource counts after warm-up. Select the Debug and Release templates as described in the [static setup](static-embedding.md#use-the-prebuilt-preview).
- [Ordinary Web: `godot-box3d-web-release`](https://github.com/waskosky/godot-box3d-embedded/actions/runs/45147938812). The same Release extension also passed all 20 smoke checks with the official Godot 4.7 template in Chromium and Firefox. Follow the [Web quick start](../WEB_QUICKSTART.md).
- [Matching editor binaries](https://github.com/waskosky/godot-box3d-embedded/actions/runs/45147939721): put the binary for your OS in `addons/godot-box3d/bin/`. The adapter passed 51 headless tests and 774 native CCD controls; the [engine's own matrix](https://github.com/waskosky/box3d/actions/runs/45147864245) passed all 19 jobs.

Keep the Web ZIP, checksum, and build manifest together. Actions downloads expire; if a bundle is no longer available, rebuild from the adapter commit above. This is a development build, not a new tagged release or a physical-device qualification.

Native replay snapshots include the cached bounds. Play old native recordings with their original engine; new builds reject the old snapshot format rather than interpreting world-space bounds as mesh-local bounds. This does not change Godot scenes or project files.

## Remaining acceptance gates

The [CCD response correction](ccd-response.md) moves the former known-failing
diagnostic into the normal native suite and adds a required browser response
check. It fixes the reproduced thin-surface handoff without increasing native
substeps. Published preview 4 binaries remain uncorrected; source builds and
their matching native/Web qualification must not be confused with that release.
This bounded coverage is not a guarantee for arbitrary speed, scale or geometry.

1. Test physical Android and iPhone/Safari devices, including repeated scene
   reloads and background/resume. Desktop WebKit is only a browser sanity check.
2. Qualify sustained frame pacing, memory and body/contact churn on named
   representative scenes and devices under explicit, unchanged budgets.
3. Validate each embedding host's exact static template and matching native
   authority before changing its immutable dependency pin. The static archives
   alone are not runtime or whole-deployment proof.
   The [optional worker-host readback patch](web-worker-readback.md) has recorded
   desktop coverage on its stated source commit; it does not certify a newer
   physics pin, mobile devices or the host's Firefox cold-start budget.
4. Qualify the actual game's controller and terrain sizes. Focused transition
   regressions do not certify arbitrary stair-climbing behavior or the
   memory/construction cost of large terrain meshes.
5. Address remaining adapter/API gaps for a named consumer. Keep unsupported dynamic concave
   bodies, concave sensor visitors, non-uniform scaling, soft bodies and unmapped
   joint parameters explicit; do not imply support from unrelated passing tests.

Keep regressions focused on observable physics behavior. Add a small reproduction
for each new failure rather than expanding a generic test framework or declaring
all Godot/Box3D behavior equivalent.

Use the [release qualification guide](release-qualification.md) to record one
candidate's exact artifacts, target devices and measured budgets.

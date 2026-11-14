# Box3D mesh/terrain correctness candidate

This isolated branch evaluates original-maintainer Box3D commit
`be8c7318901dbb14b9fbb26fe0a7a48850f53b0e` (November 13), including the
[mesh ghost-contact work](https://github.com/erincatto/box3d/pull/212) and its
follow-up fixes. The dependency URL remains `https://github.com/erincatto/box3d.git`.
It starts from downstream `c91a27b`; preview 3 retains its tested `f36d061` pin.
This is not a new release or qualified static host.

## Focused integration

The mesh builder shares exactly equal input vertices and requests native edge
identification. It does not weld merely nearby vertices or close small gaps.
Both concave meshes and the existing heightmap mesh fallback use this path,
including copies with an attachment transform baked in. Adjacency is within
one mesh, not between separate fixtures or terrain tiles.

Ray hits retain original Godot face indices through an explicit per-mesh map,
including BVH reordering, degenerate-face removal and live shared-resource edits.
This replaces the old unwelded-vertex-index encoding. Coincident identical
duplicate triangles resolve to their first input face. Heightmap face indices
remain `-1`. The existing recovery helper is adapted to the native triangle/hull
manifold API; this change does not switch character controllers or opt into
the new concurrent static-query workaround.

## Reproduction and native checks

On macOS x86-64 / official Godot 4.7, the previous matching CI binary reproduces
three failures in `mesh_terrain_contacts_test.gd`: a sphere falls through a dense
mesh after the native 512-triangle warning, and a capsule and box snag while
crossing internal edges. The dense resource has 8,192 triangles; a unit body's
bounds overlap roughly 2,048 of them.

With the candidate, both dense support bodies settle at approximately `y=0.505`.
The seam bodies traverse about 6.6 units with ordinary world damping, without
leaving the flat surface. The full 47-test native suite passes. The extended
ray regression checks shared vertices, a discarded degenerate face, shared and
transformed attachments, backface hits and live input-face reordering.

The local CMake check compiles the full adapter and Box3D against the existing
Godot 4.3 bindings archive; it is not a fresh bindings or sanitizer receipt.
Logs are under `build/validation/` and `build/native-validation/` locally.

The Web fixture adds one dense-support/seam check inside the existing movement
window; it does not extend that window or relax existing physics assertions.
An ordinary Release Web export of clean code source `4643510` passes all 15
checks in local headless Chromium and Firefox, with no captured errors and a
two-second post-PASS observation. The local harness uses Playwright 1.60.0;
CI retains its own pinned tools. Observed time to physics PASS is 17.449 seconds
in Chromium and 40.780 seconds in Firefox on this contended host, not a startup
or hardware performance qualification.

The export uses the CI-built Godot 4.7 dynamic-link template, SHA-256
`3f0ee7c6a4e3813b4ab266a1eead55ed5dcb91b84c2f5736b6dc05f69ed5d08d`.
Its candidate side module is
`0afa4735e145aa8b062b29a3853e19e48213cc0db4eb826b2a5ec7a07f19e713`.
The export manifest retains fixture and runtime hashes. Later branch merges
and README changes only carry preview 3 documentation; they do not change
the tested adapter or fixture. Full cross-platform/sanitizer and matching
static Debug/Release qualification remain pending. Keep this candidate separate
until those checks complete, and retain the device/visual/performance limits.

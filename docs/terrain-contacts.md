# Mesh contact update candidate

This branch starts directly from upstream `f073c2d` and updates original-maintainer
Box3D from `3fc20f5` to `be8c731`. It keeps the dependency at
`https://github.com/erincatto/box3d`; there is no alternate engine fork.

The newer engine removes its old 512-overlapping-triangle contact-cache limit
and improves mesh ghost contacts. Native adjacency requires shared vertex IDs,
so the adapter shares exactly equal input vertices and enables edge identification.
It does not weld merely nearby vertices or connect separate mesh fixtures.
Godot's reversed triangle winding and transformed attachment baking are retained.
The same builder serves the existing heightmap mesh fallback.

The existing recovery helper is adapted to the newer triangle/hull manifold API.
This does not opt into concurrent static queries, add a new controller, or
change the upstream adapter's existing ray face-index behavior. The independent
ray-option/face-index work remains separate; an eventual combination needs its
explicit BVH-to-input-face mapping, not the old unwelded vertex encoding.

`mesh_terrain_contacts_test.gd` covers an 8,192-triangle resource with about
2,048 triangles under each unit body's bounds, plus capsule/box traversal over
internal edges on a transformed mesh. All 36 native tests pass locally on
macOS x86-64 with official Godot 4.7. The local full adapter/engine build reuses
the pinned Godot 4.3 bindings archive; it is not a fresh bindings, cross-platform,
sanitizer or Web qualification receipt.

Adjacency has construction and storage costs. Measure large shared/transformed
terrain and avoid unnecessary live rebuilds; this correctness update is not a
blanket performance claim. A separately isolated native thin-hull CCD response
failure reproduces on both the old and new engine pins at 30 Hz. It is not
introduced or fixed by this mesh update. Production/device acceptance remains
separate from these focused regressions.

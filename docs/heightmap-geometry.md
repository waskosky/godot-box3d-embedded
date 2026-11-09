# Heightmap geometry

`HeightMapShape3D` uses a grid centered on the shape origin, with one-unit sample
spacing and row-major heights. Local attachment translations and rotations must
move the collision surface just as they move its Godot debug geometry.

If a project added an offset to compensate for the old corner-origin collision
bug, remove that workaround when adopting this candidate.

The pinned Box3D heightfield API creates a corner-origin grid and cannot apply a
fixture-local transform. The adapter therefore builds a centered static mesh:
identity attachments share its geometry, and transformed attachments reuse the
existing owned-mesh baking/lifetime path. The original height array remains the
resource's data. Grid cells use Godot's diagonal and winding; triangles touching
non-finite heights are omitted, so NaN vertices create holes without entering
the native mesh builder. An entirely empty grid creates no collision fixture.

This fixes collision placement; it is not the compressed native-heightfield
fast path. Mesh construction and baked copies can use more memory on large maps.
Qualify representative terrain sizes before treating this as a performance
improvement. Dynamic concave bodies and concave sensor visitors remain unsupported.

`test_project/tests/heightmap_geometry_test.gd` checks independently calculated
surface heights/normals, both sides of the centered grid, bounds, shared owners,
body/attachment rotations, an attachment move, rigid support, a non-planar cell,
NaN holes and an all-hole grid. Live shared-resource invalidation is a separate
adapter concern; the integrated lifecycle candidate covers it without bundling
that unrelated change into this geometry candidate.

## Bounded construction diagnostic

After building the native addon, run the opt-in profile outside the regression suite:

```sh
/path/to/godot --headless --path test_project \
  --script res://benchmarks/heightmap_profile.gd -- --grid=257 --cycles=3
```

It times resource construction, an identity owner, a translated/rotated attachment,
live replacement of the shared height data and cleanup. Rays verify the updated
surface placement for both owners. `TERRAIN_PROFILE` contains machine-readable
results. Godot static-memory values exclude Box3D/GPU allocations; use an external
process-memory measurement too, and do not interpret retained capacity as a leak.

On 2026-11-09 UTC, three cycles per size with Godot 4.7 and the Release adapter
on macOS 15.7.1 / Intel i7-6820HQ / 16 GB RAM gave these diagnostic ranges:

| Grid / triangles per owner | Resource | Identity owner | Baked owner | Shared update | Process peak RSS |
|---|---:|---:|---:|---:|---:|
| 65 / 8,192 | 5.8–6.8 ms | 3.3–5.7 ms | 6.4–6.9 ms | 5.3–5.8 ms | 100.1 MiB |
| 129 / 32,768 | 26.7–30.8 ms | 14.4–15.1 ms | 29.1–30.9 ms | 22.5–24.8 ms | 107.2 MiB |
| 257 / 131,072 | 121.8–137.8 ms | 68.9–70.1 ms | 140.3–167.4 ms | 109.8–118.3 ms | 147.1 MiB |

All placement checks passed. After each cycle, counts returned to one node and
two resources; the report itself retains small dictionaries. Peak RSS, measured
with `/usr/bin/time -l` in a separate process for each grid, includes the engine,
both owners, allocator capacity and all three cycles. This was a contended host,
not a comparative benchmark, Web timing budget or proof of leak freedom.

The results support measuring real terrain sizes before choosing chunking,
background construction or a native-heightfield path. No terrain representation
or scheduling behavior is changed by this diagnostic.

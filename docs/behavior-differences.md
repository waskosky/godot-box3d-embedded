---
title: Behavior differences
---

# Behavior differences

Places where the underlying engine or current adapter behaves differently from Godot's built-in physics.

How `CharacterBody3D` recovers from overlaps is covered separately in [Character motion recovery]({{ '/character-motion/' | relative_url }}).

## Separation rays are query-only

`SeparationRayShape3D` participates in direct shape queries and in `body_test_motion`, including `CharacterBody3D` floor snap and `slide_on_slope`. It does not create a Box3D fixture, so attaching one to a `RigidBody3D` or `Area3D` does not add ordinary contacts or monitoring events.

This keeps the zero-width ray from changing body mass or generating regular collision response. Use it for character motion, which is its intended Godot use; use a finite convex shape when a simulated body or area needs contacts.

An embedded ray endpoint still participates in overlap recovery when
`collide_separation_ray` is false. That flag only gates the requested-motion
cast for non-sliding rays; `slide_on_slope` rays also participate in casting.

## `Area3D` does not detect trimesh or heightmap bodies

In Box3D a concave shape (`ConcavePolygonShape3D`) or `HeightMapShape3D` can never act as a sensor *visitor*, by design, since testing an arbitrary mesh against a sensor is too expensive.

So an `Area3D` silently ignores a body whose shape is a trimesh or heightmap: no `body_entered` or `body_exited` fires for it. Godot's built-in physics and Jolt both report such a body on the first physics frame.

If you need a body to be detected by an area, give it a convex shape. A trimesh may still be used *as* an `Area3D`'s own shape to detect convex bodies passing through it.

## Direct query contacts and rays

`collide_shape()` uses native contact manifolds for convex queries against live
primitive, mesh and heightmap fixtures. It returns world-space pairs with the
query-surface point first and target-surface point second. Overlapping pairs
encode the penetration vector; positive-distance contacts within a query margin
use closest surface points. Result caps, collision masks and exclusions apply.

`get_rest_info()` selects the deepest contact, reports a target-surface point and
outward normal, and includes angular motion in the target's contact velocity.
It checks the supplied pose and ignores `motion`. These queries are read-only.
`cast_motion()` honors margin and backs its safe fraction off by native linear
slop; safe and unsafe fractions need not be identical.
It ignores targets overlapped at the starting pose while still detecting later obstacles; use `collide_shape()` to inspect initial overlaps. An unobstructed cast returns `[1.0, 1.0]`, not an empty result.

Ray queries honor `hit_from_inside`. Concave ray hits report the original input
triangle index, rather than the reordered native BVH index. A backface ray hit
requires both `hit_back_faces` and the concave resource's `backface_collision`;
heightmap rays use the query's backface flag. This ray support does not make
Box3D's simulated concave fixtures two-sided: their physical contacts and
character recovery remain one-sided.

## Shape queries need a convex query shape

`intersect_shape`, `cast_motion`, `collide_shape`, `rest_info`, and `body_test_motion` build a point-cloud proxy of the shape being queried *with*. Trimesh, heightmap, and world-boundary shapes have no finite point cloud.

Passing one of those as the query shape returns no results. They work normally as targets in the world.
This is the current query adapter's support boundary, not a claim that Box3D
cannot collide a convex body with those fixtures. Separation rays have their own
query-only implementation.

## Viewport picking and scripted rays

Viewport physics picking honors `CollisionObject3D.input_ray_pickable` for bodies and areas, including changes at runtime. Unpickable objects do not block picking an eligible object behind them. This flag does not filter ordinary scripted `intersect_ray()` queries or change physical collisions.

## Physics materials

The adapter supplies Box3D mixing callbacks matching Godot's `PhysicsMaterial`
contract. Ordinary friction takes the lower coefficient; a rough material takes
precedence, and two rough materials take the higher coefficient. Restitution is
the sum clamped to 0..1, with absorbent materials subtracting their bounce.
The callbacks use only native coefficient/flag values and can run on physics workers.

Changing a material resource or replacing an override updates existing fixtures,
without rebuilding their geometry, mass or contact-monitor ownership. Future
attachments and re-enabled shapes use the same current material.

This changes older addon behavior, which used Box3D's geometric-mean friction and
maximum restitution. Revisit material tuning made specifically for those rules.
Matching these combine rules does not promise identical trajectories across solvers.

## Collision transform scaling

Use unit-scale body and collision attachment transforms, and change dimensions
on `Shape3D` resources. Scaled, mirrored and sheared transforms emit a warning;
they are not supported consistently across live fixtures and direct queries.
Sphere radii ignore basis scale, capsules can scale endpoints without their
radii, and live hulls discard scale when extracting rotations while query hull
points use the full basis. Mesh attachment baking alone is not general scaling
support. No normalization or partial scaling implementation is introduced here.

## World boundaries are finite

`WorldBoundaryShape3D` is represented by a finite plate extending 5,000 units
from its center along each surface axis, with 10 units of thickness behind the
plane. It is not an infinite solid half-space: its edges and underside are real
collision surfaces. The large-surface motion fix improves contact refinement
inside this representation; it does not change that geometric limitation.

## Ignored joint parameters

Godot's joint API exposes parameters Box3D has no equivalent for, including `HingeJoint3D`'s `LIMIT_RELAXATION` and `LIMIT_SOFTNESS`, `PinJoint3D`'s `IMPULSE_CLAMP`, and most of `SliderJoint3D`'s per-axis tuning (Box3D's prismatic joint is a pure 1-DOF slider).

Setting one logs a warning and is ignored, rather than silently mapping onto something that behaves differently.

Supported live joint edits wake the constrained bodies, including motor reversal,
limit edits, pin anchors and spring changes. Repeated identical motor, limit,
spring and anchor writes leave sleeping bodies alone. Setters do not call through native handles destroyed when
a connected body leaves its space.

The current wrappers require two bodies; a single-body joint anchored to the
world is not implemented.

## Hinge motor impulse budget

`HingeJoint3D.motor/max_impulse` is an angular impulse cap per full Godot physics
tick, not a torque. The adapter converts it to Box3D's maximum torque using the
actual space step: `torque = max_impulse / step_seconds`. Box3D's substeps share
that tick budget; it is not multiplied by the substep count. Runtime tick-rate
and time-scale changes are handled without rewriting the requested parameter.
The getter continues to return the original impulse value.

This intentionally strengthens motors compared with the old direct torque
mapping: at 60 Hz and time scale 1, a value of 1 now means up to 1 angular
impulse per tick (60 Nm), rather than 1 Nm. Retune old scenes accordingly. To
request a constant torque, set the impulse cap to `desired_torque * step_seconds`;
holding an impulse cap fixed while changing tick rate does not hold torque fixed.

Zero impulse and a disabled motor add no motor impulse. Negative/non-finite caps
are rejected; zero-duration steps do not divide by zero. Deleted native joints
are discarded from the space's limit records before use. Unchanged torque limits
are not rewritten each tick, and refreshing limits does not wake sleeping bodies.

The focused regression measures angular velocity changes with known inertia on
a rotated hinge, 30/60/120 Hz, multiple time scales, live edits, reversal and two
dynamic endpoints. It verifies a per-tick budget, not exact trajectory parity with
GodotPhysics3D's iterative solver.

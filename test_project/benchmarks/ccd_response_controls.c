// Native controls for the CCD -> speculative-contact handoff, independent of Godot.
#include <box3d/box3d.h>
#include <box3d/collision.h>
#include <box3d/math_functions.h>
#include <math.h>
#include <stdio.h>

static int run_case(int rate, int substeps, float radius, float speed, int kind,
		b3BodyType target_type, int workers, float restitution, bool grazing, int geometry) {
	b3WorldDef world_def = b3DefaultWorldDef();
	world_def.gravity = b3Vec3_zero;
	world_def.workerCount = workers;
	b3WorldId world = b3CreateWorld(&world_def);
	b3BodyDef target_def = b3DefaultBodyDef();
	target_def.type = target_type;
	target_def.position = (b3Pos){50, 40, 0};
	if (geometry == 2) target_def.position = (b3Pos){30, 40, -20};
	target_def.enableSleep = false;
	b3BodyId target = b3CreateBody(world, &target_def);
	b3Transform offset = b3Transform_identity;
	offset.p.y = -0.0125f;
	b3BoxHull plate = b3MakeTransformedBoxHull(20, 0.0125f, 20, offset);
	b3ShapeDef shape_def = b3DefaultShapeDef();
	shape_def.density = 50000;
	shape_def.baseMaterial.friction = 0;
	shape_def.baseMaterial.restitution = restitution;
	b3MeshData *mesh = NULL;
	b3HeightFieldData *height_field = NULL;
	if (geometry == 1) {
		b3Vec3 vertices[] = {{-20, 0, -20}, {-20, 0, 20}, {20, 0, -20}, {20, 0, 20}};
		int32_t indices[] = {0, 1, 2, 2, 1, 3};
		b3MeshDef mesh_def = {.vertices = vertices, .indices = indices, .vertexCount = 4, .triangleCount = 2, .identifyEdges = true};
		mesh = b3CreateMesh(&mesh_def, NULL, 0);
		b3CreateMeshShape(target, &shape_def, mesh, (b3Vec3){1, 1, 1});
	} else if (geometry == 2) {
		float heights[4] = {0};
		b3HeightFieldDef height_def = {.heights = heights, .scale = {40, 1, 40}, .countX = 2, .countZ = 2,
			.globalMinimumHeight = -1, .globalMaximumHeight = 1};
		height_field = b3CreateHeightField(&height_def);
		b3CreateHeightFieldShape(target, &shape_def, height_field);
	} else {
		b3CreateHullShape(target, &shape_def, &plate.base);
	}
	float support = kind == 2 ? 2 * radius : radius;
	b3BodyDef body_def = b3DefaultBodyDef();
	body_def.type = b3_dynamicBody;
	body_def.position = (b3Pos){49, 40 + (grazing ? support + 0.01f : 2), 0};
	body_def.enableSleep = false;
	body_def.isBullet = true;
	body_def.linearDamping = 0;
	body_def.motionLocks.angularX = true;
	body_def.motionLocks.angularY = true;
	body_def.motionLocks.angularZ = true;
	b3BodyId body = b3CreateBody(world, &body_def);
	shape_def.density = 1;
	if (kind == 0) {
		b3Sphere sphere = {.center = {0, 0, 0}, .radius = radius};
		b3CreateSphereShape(body, &shape_def, &sphere);
	} else if (kind == 1) {
		b3BoxHull cube = b3MakeCubeHull(radius);
		b3CreateHullShape(body, &shape_def, &cube.base);
	} else {
		b3Capsule capsule = {.center1 = {0, -radius, 0}, .center2 = {0, radius, 0}, .radius = radius};
		b3CreateCapsuleShape(body, &shape_def, &capsule);
	}
	float dt = 1.0f / rate;
	b3World_Step(world, dt, substeps);
	b3World_Step(world, dt, substeps);
	float target_speed = target_type == b3_kinematicBody ? 0.5f : 0;
	b3Body_SetLinearVelocity(target, (b3Vec3){0, target_speed, 0});
	b3Body_SetLinearVelocity(body, (b3Vec3){0.1f * speed, grazing ? 0 : -speed, 0});
	int failed = 0;
	float min_y = 10, max_rebound = 0;
	for (int tick = 0; tick < 8; ++tick) {
		b3World_Step(world, dt, substeps);
		b3Pos position = b3Body_GetPosition(body);
		b3Pos target_position = b3Body_GetPosition(target);
		b3Vec3 velocity = b3Body_GetLinearVelocity(body);
		float y = (float)(position.y - target_position.y);
		min_y = fminf(min_y, y);
		max_rebound = fmaxf(max_rebound, velocity.y - target_speed);
		failed |= !isfinite(y) || !isfinite(velocity.x) || !isfinite(velocity.y) || y < support - 0.003f;
	}
	b3Vec3 velocity = b3Body_GetLinearVelocity(body);
	float expected_tangent = 0.1f * speed;
	if (!grazing && speed * sqrtf(1.01f) > 400) {
		expected_tangent = 400 * 0.1f / sqrtf(1.01f);
	}
	failed |= fabsf(velocity.x - expected_tangent) > 0.05f;
	if (grazing) {
		failed |= fabsf(min_y - support - 0.01f) > 0.0001f || fabsf(velocity.y) > 0.001f;
	} else if (restitution == 0) {
		failed |= min_y > support + 0.006f || fabsf(velocity.y - target_speed) > 1.0f;
	} else {
		failed |= max_rebound < 0.45f * fminf(speed, 398.0f) || max_rebound > 0.55f * fminf(speed, 398.0f);
	}
	if (failed) {
		printf("FAIL rate=%d substeps=%d radius=%g speed=%g kind=%d target=%d geometry=%d workers=%d bounce=%g grazing=%d min_y=%g vx=%g vy=%g rebound=%g\n",
			rate, substeps, (double)radius, (double)speed, kind, target_type, geometry, workers, (double)restitution, grazing,
			(double)min_y, (double)velocity.x, (double)velocity.y, (double)max_rebound);
	}
	b3DestroyWorld(world);
	if (mesh) b3DestroyMesh(mesh);
	if (height_field) b3DestroyHeightField(height_field);
	return failed;
}

int main(void) {
	int failures = 0, cases = 0;
	const float radii[] = {0.01f, 0.05f, 0.1f};
	const float speeds[] = {100, 300, 600};
	const int substeps[] = {1, 4, 8};
	for (int rate = 30; rate <= 120; rate *= 2) {
		for (int r = 0; r < 3; ++r) {
			for (int s = 0; s < 3; ++s) {
				for (int n = 0; n < 3; ++n) {
					for (int kind = 0; kind < 3; ++kind) {
						for (int geometry = 0; geometry < 3; ++geometry) {
							failures += run_case(rate, substeps[n], radii[r], speeds[s], kind, b3_staticBody, 1, 0, false, geometry);
							cases++;
						}
					}
				}
			}
		}
		for (int kind = 0; kind < 3; ++kind) {
			for (int target = b3_staticBody; target <= b3_dynamicBody; ++target) {
				failures += run_case(rate, 4, 0.01f, 300, kind, (b3BodyType)target, 4, 0, false, 0);
				cases++;
			}
			failures += run_case(rate, 4, 0.01f, 300, kind, b3_staticBody, 1, 0.5f, false, 0);
			failures += run_case(rate, 4, 0.01f, 300, kind, b3_staticBody, 1, 0, true, 0);
			cases += 2;
		}
	}
	printf("Native CCD response controls: %d/%d passed\n", cases - failures, cases);
	return failures != 0;
}

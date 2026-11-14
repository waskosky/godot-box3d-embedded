#include <box3d/box3d.h>
#include <box3d/collision.h>
#include <box3d/math_functions.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// Uncorrected upstream fails: initial TOI is caught, then response crosses the plate.
// Both downstream build systems include the correction; this reproducer must pass.
int main(int argc, char **argv) {
	int substeps = argc > 1 ? atoi(argv[1]) : 4;
	float radius = argc > 2 ? (float)atof(argv[2]) : 0.1f;
	float speed = argc > 3 ? (float)atof(argv[3]) : 600.0f;
	if (substeps < 1 || !isfinite(radius) || !isfinite(speed) || radius <= 0 || speed <= 0) {
		return 2;
	}
	int failures = 0;
	for (int rate = 30; rate <= 120; rate *= 2) {
		b3WorldDef world_def = b3DefaultWorldDef();
		world_def.gravity = b3Vec3_zero;
		world_def.workerCount = 1;
		b3WorldId world = b3CreateWorld(&world_def);
		b3BodyDef ground_def = b3DefaultBodyDef();
		ground_def.position = (b3Pos){50, 40, 0};
		b3BodyId ground = b3CreateBody(world, &ground_def);
		b3Transform offset = b3Transform_identity;
		offset.p.y = -0.0125f;
		b3BoxHull hull = b3MakeTransformedBoxHull(20, 0.0125f, 20, offset);
		b3ShapeDef shape_def = b3DefaultShapeDef();
		shape_def.baseMaterial.friction = 0;
		b3CreateHullShape(ground, &shape_def, &hull.base);
		b3BodyDef body_def = b3DefaultBodyDef();
		body_def.type = b3_dynamicBody;
		body_def.position = (b3Pos){49, 42, 0};
		body_def.enableSleep = false;
		body_def.isBullet = true;
		body_def.linearDamping = 0;
		b3BodyId body = b3CreateBody(world, &body_def);
		b3Sphere sphere = {.center = {0, 0, 0}, .radius = radius};
		b3CreateSphereShape(body, &shape_def, &sphere);
		float dt = 1.0f / rate;
		b3World_Step(world, dt, substeps);
		b3World_Step(world, dt, substeps);
		b3Body_SetLinearVelocity(body, (b3Vec3){0.1f * speed, -speed, 0});
		for (int tick = 0; tick < 8; ++tick) {
			b3World_Step(world, dt, substeps);
			b3Pos position = b3Body_GetPosition(body);
			b3Vec3 velocity = b3Body_GetLinearVelocity(body);
			printf("rate=%d substeps=%d radius=%.4f requested_normal_speed=%.1f tick=%d x=%.8f y=%.8f vx=%.8f vy=%.8f\n", rate, substeps, (double)radius, (double)speed, tick,
					(double)position.x - 50, (double)position.y - 40, (double)velocity.x, (double)velocity.y);
			failures += position.y < 39.97;
		}
		b3DestroyWorld(world);
	}
	return failures > 0;
}

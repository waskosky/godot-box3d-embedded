extends SceneTree
## Diagnostic of unsupported transforms, not a specification for their behavior.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var records: Array[Dictionary] = []
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.0
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	for shape in [box, sphere, capsule]:
		for scale_value in [Vector3.ONE, Vector3(2, 2, 2), Vector3(2, 1, 1), Vector3(-1, 1, 1)]:
			var body: StaticBody3D = StaticBody3D.new()
			var collision: CollisionShape3D = CollisionShape3D.new()
			collision.shape = shape
			collision.scale = scale_value
			body.add_child(collision)
			root.add_child(body)
			await physics_frame
			await physics_frame
			var state: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(4, 0, 0), Vector3.ZERO)
			var hit: Dictionary = state.intersect_ray(ray)
			var target: StaticBody3D = StaticBody3D.new()
			target.position.x = 8
			var target_collision: CollisionShape3D = CollisionShape3D.new()
			var target_box: BoxShape3D = BoxShape3D.new()
			target_box.size = Vector3(0.2, 4, 4)
			target_collision.shape = target_box
			target.add_child(target_collision)
			root.add_child(target)
			await physics_frame
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.from_scale(scale_value), Vector3(5, 0, 0))
			query.motion = Vector3(3, 0, 0)
			var fractions: PackedFloat32Array = state.cast_motion(query)
			records.append({"shape": shape.get_class(), "scale": str(scale_value), "fixture_positive_x": hit.get("position", Vector3.INF).x, "cast_fractions": Array(fractions)})
			target.free()
			body.free()
			await physics_frame
	print("SCALING_PROBE: ", JSON.stringify(records))
	quit()

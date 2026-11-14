extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _mesh(min_x: float, max_x: float) -> ConcavePolygonShape3D:
	var faces: PackedVector3Array = PackedVector3Array()
	for x: int in range(int(min_x), int(max_x)):
		for z: int in range(-3, 3):
			var a: Vector3 = Vector3(x, 0, z)
			var b: Vector3 = a + Vector3.RIGHT
			var c: Vector3 = a + Vector3.BACK
			faces.append_array(PackedVector3Array([a, b, c, b, b + Vector3.BACK, c]))
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


func _run() -> void:
	print("Active physics backend: ", PhysicsServer3D.get_class())
	if PhysicsServer3D.get_class() != "Box3DPhysicsServer3D":
		print("RESULT: FAIL - Box3D backend is not active")
		quit(1)
		return
	var cases: Array[Dictionary] = []
	var owners: Array[StaticBody3D] = []
	for orientation: int in range(3):
		for split: bool in [false, true]:
			for direction: float in [-1.0, 1.0]:
				var frame: Transform3D = Transform3D(Basis(Vector3.BACK, orientation * PI / 2), Vector3(50 + cases.size() * 12, 12, 0))
				var meshes: Array[ConcavePolygonShape3D] = []
				if split:
					meshes.append(_mesh(-6, 0))
					meshes.append(_mesh(0, 6))
				else:
					meshes.append(_mesh(-6, 6))
				for mesh: ConcavePolygonShape3D in meshes:
					var terrain: StaticBody3D = StaticBody3D.new()
					terrain.transform = frame
					var collision: CollisionShape3D = CollisionShape3D.new()
					collision.shape = mesh
					terrain.add_child(collision)
					root.add_child(terrain)
					owners.append(terrain)
				for kind: int in range(2):
					var body: RigidBody3D = RigidBody3D.new()
					body.transform = frame * Transform3D(Basis(), Vector3(-4 * direction, 0.51, -1 if kind == 0 else 1))
					body.gravity_scale = 0.0
					body.constant_force = -frame.basis.y * 9.8
					body.can_sleep = false
					body.lock_rotation = true
					body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
					body.linear_damp = 0.0
					var material: PhysicsMaterial = PhysicsMaterial.new()
					material.friction = 0.0
					body.physics_material_override = material
					var collision: CollisionShape3D = CollisionShape3D.new()
					if kind == 0:
						var capsule: CapsuleShape3D = CapsuleShape3D.new()
						capsule.radius = 0.25
						capsule.height = 1.0
						collision.shape = capsule
					else:
						collision.shape = BoxShape3D.new()
					body.add_child(collision)
					root.add_child(body)
					cases.append({"body": body, "frame": frame, "orientation": orientation, "split": split, "direction": direction, "kind": kind, "max_height_error": 0.0})
	for tick: int in range(30):
		await physics_frame
	for item: Dictionary in cases:
		item.body.linear_velocity = item.frame.basis.x * item.direction * 3.0
	for tick: int in range(180):
		await physics_frame
		for item: Dictionary in cases:
			var local: Vector3 = item.frame.affine_inverse() * item.body.position
			item.max_height_error = maxf(item.max_height_error, absf(local.y - 0.5))
			_check(local.is_finite() and item.body.linear_velocity.is_finite(), "finite terrain traversal")
	for item: Dictionary in cases:
		var local: Vector3 = item.frame.affine_inverse() * item.body.position
		print("Tile contacts orientation=", item.orientation, " split=", item.split, " direction=", item.direction, " shape=", item.kind, " local=", local, " height_error=", item.max_height_error)
		_check(local.x * item.direction > 4.5, "capsule/box crosses the central edge in either direction")
		_check(item.max_height_error < 0.05, "coplanar floor/wall/ceiling tiles retain bounded support height")
		item.body.queue_free()
	for terrain: StaticBody3D in owners:
		terrain.queue_free()
	await process_frame
	await physics_frame
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " - separate terrain tiles and continuous-mesh controls on floors, walls and ceilings")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("RESULT: FAIL - ", message)

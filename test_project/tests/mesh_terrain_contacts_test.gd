extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _dense_support()
	await _seam_traversal()
	if failures == 0:
		print("RESULT: PASS - dense mesh support and capsule/box seam traversal")
	quit(1 if failures > 0 else 0)


func _grid(size: float, cells: int) -> ConcavePolygonShape3D:
	var faces: PackedVector3Array = PackedVector3Array()
	for z in range(cells):
		for x in range(cells):
			var a: Vector3 = Vector3(size * (float(x) / cells - 0.5), 0, size * (float(z) / cells - 0.5))
			var b: Vector3 = a + Vector3(size / cells, 0, 0)
			var c: Vector3 = a + Vector3(0, 0, size / cells)
			var d: Vector3 = a + Vector3(size / cells, 0, size / cells)
			faces.append_array(PackedVector3Array([a, b, c, b, d, c]))
	var mesh: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	mesh.set_faces(faces)
	return mesh


func _body(shape: Shape3D, at: Vector3) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.position = at
	body.lock_rotation = true
	body.can_sleep = false
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0
	body.physics_material_override = material
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body


func _dense_support() -> void:
	# Each unit body's bounds overlap about 2,048 of this mesh's 8,192 triangles,
	# well beyond the old native contact-cache capacity of 512.
	var mesh: ConcavePolygonShape3D = _grid(2.0, 64)
	var bodies: Array[RigidBody3D] = []
	var floors: Array[StaticBody3D] = []
	for index in range(2):
		var floor_body: StaticBody3D = StaticBody3D.new()
		floor_body.position.x = index * 5.0
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = mesh
		floor_body.add_child(collision)
		root.add_child(floor_body)
		floors.append(floor_body)
		var shape: Shape3D = SphereShape3D.new() if index == 0 else BoxShape3D.new()
		bodies.append(_body(shape, Vector3(index * 5.0, 1.25, 0)))
	for frame in range(180):
		await physics_frame
		for body in bodies:
			_check(body.position.is_finite() and body.linear_velocity.is_finite(), "dense support stays finite")
	for index in range(bodies.size()):
		var body: RigidBody3D = bodies[index]
		print("Dense mesh body %d: y=%.6f velocity=%s" % [index, body.position.y, body.linear_velocity])
		_check(absf(body.position.y - 0.5) < 0.04 and body.linear_velocity.length() < 0.1,
				"dense mesh supports sphere/box at its surface: %d" % index)
		body.queue_free()
	for floor_body in floors:
		floor_body.queue_free()
	await process_frame
	await physics_frame


func _seam_traversal() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.position = Vector3(20, 0, 0)
	floor_body.rotation.y = 0.31
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.position = Vector3(0.3, 0, -0.2)
	collision.rotation.y = -0.17
	collision.shape = _grid(12.0, 12)
	floor_body.add_child(collision)
	root.add_child(floor_body)
	var transform: Transform3D = floor_body.global_transform * collision.transform
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.0
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3.ONE
	var bodies: Array[RigidBody3D] = [
		_body(capsule, transform * Vector3(-4, 0.51, -1)),
		_body(box, transform * Vector3(-4, 0.51, 1)),
	]
	for frame in range(30):
		await physics_frame
	for body in bodies:
		body.linear_velocity = transform.basis * Vector3(3, 0, 0)
	var worst_height_error: float = 0
	for frame in range(150):
		await physics_frame
		for body in bodies:
			_check(body.position.is_finite() and body.linear_velocity.is_finite(), "seam traversal stays finite")
			worst_height_error = maxf(worst_height_error, absf(body.position.y - 0.5))
	for index in range(bodies.size()):
		var local: Vector3 = transform.affine_inverse() * bodies[index].position
		print("Seam body %d: local=%s velocity=%s" % [index, local, bodies[index].linear_velocity])
		# Keep normal world damping: unobstructed travel is about 6.6 units.
		_check(local.x > 2.0, "capsule/box traverses internal mesh edges without snagging: %d" % index)
		bodies[index].queue_free()
	_check(worst_height_error < 0.08, "flat internal edges do not kick bodies off the surface")
	floor_body.queue_free()
	await process_frame
	await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("RESULT: FAIL - ", message)

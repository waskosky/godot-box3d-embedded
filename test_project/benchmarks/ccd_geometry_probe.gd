extends SceneTree
# Deliberately failing native-engine reproduction; see docs/edge-qualification.md.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Active physics backend: ", PhysicsServer3D.get_class())
	if PhysicsServer3D.get_class() != "Box3DPhysicsServer3D":
		print("RESULT: FAIL - Box3D backend is not active")
		quit(1)
		return
	var original_rate: int = Engine.physics_ticks_per_second
	for rate: int in [30, 120]:
		Engine.physics_ticks_per_second = rate
		await _check_impacts(rate)
	Engine.physics_ticks_per_second = original_rate
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " - oblique sphere/box CCD against primitive and one-sided mesh surfaces at 30/120 Hz")
	quit(0 if failures == 0 else 1)


func _check_impacts(rate: int) -> void:
	var cases: Array[Dictionary] = []
	var terrain_owners: Array[StaticBody3D] = []
	for mesh: bool in [false, true]:
		for rotated: bool in [false, true]:
			for box: bool in [false, true]:
				var basis: Basis = Basis(Vector3(0.3, 0.8, 0.5).normalized(), 0.7) if rotated else Basis()
				var frame: Transform3D = Transform3D(basis, Vector3(50 + cases.size() * 60, 40, 0))
				var terrain: StaticBody3D = StaticBody3D.new()
				terrain.transform = frame
				var collision: CollisionShape3D = CollisionShape3D.new()
				if mesh:
					var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
					shape.set_faces(PackedVector3Array([Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, -20), Vector3(20, 0, 20), Vector3(-20, 0, 20)]))
					collision.shape = shape
				else:
					var shape: BoxShape3D = BoxShape3D.new()
					shape.size = Vector3(40, 0.025, 40)
					collision.position.y = -0.0125
					collision.shape = shape
				terrain.add_child(collision)
				root.add_child(terrain)
				terrain_owners.append(terrain)
				var body: RigidBody3D = RigidBody3D.new()
				body.transform = frame * Transform3D(Basis(), Vector3(-1, 2, 0))
				body.gravity_scale = 0.0
				body.can_sleep = false
				body.continuous_cd = true
				body.lock_rotation = true
				body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
				body.linear_damp = 0.0
				var material: PhysicsMaterial = PhysicsMaterial.new()
				material.friction = 0.0
				body.physics_material_override = material
				collision = CollisionShape3D.new()
				if box:
					var shape: BoxShape3D = BoxShape3D.new()
					shape.size = Vector3.ONE * 0.2
					collision.shape = shape
				else:
					var shape: SphereShape3D = SphereShape3D.new()
					shape.radius = 0.1
					collision.shape = shape
				body.add_child(collision)
				root.add_child(body)
				cases.append({"body": body, "frame": frame, "mesh": mesh, "rotated": rotated, "box": box})
	await physics_frame
	await physics_frame
	# Wait for the requested step so startup at the previous rate cannot hide the defect.
	var applied_step: float = 0.0
	for attempt in range(12):
		await physics_frame
		applied_step = PhysicsServer3D.body_get_direct_state(cases[0].body.get_rid()).step
		if absf(applied_step - 1.0 / rate) < 0.000001:
			break
	_check(absf(applied_step - 1.0 / rate) < 0.000001, "requested CCD tick rate reaches the physics space")
	print("CCD requested rate=", rate, " applied step=", applied_step)
	for item: Dictionary in cases:
		item.body.linear_velocity = item.frame.basis * Vector3(60, -600, 0)
	for tick: int in range(8):
		await physics_frame
		for item: Dictionary in cases:
			var local: Vector3 = item.frame.affine_inverse() * item.body.position
			_check(local.is_finite() and item.body.linear_velocity.is_finite() and local.y > -0.03, "CCD target crossing: rate=%s mesh=%s rotated=%s box=%s tick=%s local=%s velocity=%s" % [rate, item.mesh, item.rotated, item.box, tick, local, item.body.linear_velocity])
	for item: Dictionary in cases:
		var local: Vector3 = item.frame.affine_inverse() * item.body.position
		var velocity: Vector3 = item.frame.basis.inverse() * item.body.linear_velocity
		print("CCD rate=", rate, " mesh=", item.mesh, " rotated=", item.rotated, " box=", item.box, " local=", local, " velocity=", velocity)
		_check(local.y > -0.03 and local.y < 0.2 and local.x > -0.5 and absf(velocity.y) < 1.0, "CCD produces an observed stopping contact and tangential travel")
		item.body.queue_free()
	for terrain: StaticBody3D in terrain_owners:
		terrain.queue_free()
	await process_frame
	await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("RESULT: FAIL - ", message)

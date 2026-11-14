extends SceneTree
# CCD must hand impacts to contact response without crossing thin surfaces.

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
	for rate: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		for radius: float in [0.1, 0.01]:
			await _check_impacts(rate, radius)
	Engine.physics_ticks_per_second = original_rate
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " - 144 CCD response cases: sphere/box/capsule, thin hull/mesh, floor/wall/ceiling/oblique, two sizes, 30/60/120 Hz")
	quit(0 if failures == 0 else 1)


func _check_impacts(rate: int, radius: float) -> void:
	var cases: Array[Dictionary] = []
	var terrain_owners: Array[StaticBody3D] = []
	for mesh: bool in [false, true]:
		for orientation: int in range(4):
			for kind: int in range(3):
				var basis: Basis = [Basis(), Basis(Vector3.FORWARD, PI / 2), Basis(Vector3.RIGHT, PI), Basis(Vector3(0.3, 0.8, 0.5).normalized(), 0.7)][orientation]
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
				if kind == 1:
					var shape: BoxShape3D = BoxShape3D.new()
					shape.size = Vector3.ONE * (2.0 * radius)
					collision.shape = shape
				elif kind == 2:
					var shape: CapsuleShape3D = CapsuleShape3D.new()
					shape.radius = radius
					shape.height = 4.0 * radius
					collision.shape = shape
				else:
					var shape: SphereShape3D = SphereShape3D.new()
					shape.radius = radius
					collision.shape = shape
				body.add_child(collision)
				root.add_child(body)
				cases.append({"body": body, "frame": frame, "mesh": mesh, "orientation": orientation, "kind": kind})
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
	print("CCD requested rate=", rate, " applied step=", applied_step, " radius=", radius, " cases=", cases.size())
	var speed: float = 600.0 if radius == 0.1 else 300.0
	for item: Dictionary in cases:
		item.body.linear_velocity = item.frame.basis * Vector3(0.1 * speed, -speed, 0)
	for tick: int in range(8):
		await physics_frame
		for item: Dictionary in cases:
			var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(item.body.get_rid())
			var local: Vector3 = item.frame.affine_inverse() * state.transform.origin
			_check(local.is_finite() and state.linear_velocity.is_finite() and local.y > radius - 0.003, "CCD target crossing: rate=%s radius=%s mesh=%s orientation=%s kind=%s tick=%s local=%s velocity=%s" % [rate, radius, item.mesh, item.orientation, item.kind, tick, local, state.linear_velocity])
	for item: Dictionary in cases:
		var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(item.body.get_rid())
		var local: Vector3 = item.frame.affine_inverse() * state.transform.origin
		var velocity: Vector3 = item.frame.basis.inverse() * state.linear_velocity
		_check(local.y > radius - 0.003 and local.y < 2.0 * radius + 0.01 and local.x > -0.5 and absf(velocity.y) < 1.0 and velocity.x > 20.0, "CCD stopping contact preserves tangential travel: rate=%s radius=%s mesh=%s orientation=%s kind=%s local=%s velocity=%s" % [rate, radius, item.mesh, item.orientation, item.kind, local, velocity])
		item.body.queue_free()
	for terrain: StaticBody3D in terrain_owners:
		terrain.queue_free()
	await process_frame
	await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("RESULT: FAIL - ", message)

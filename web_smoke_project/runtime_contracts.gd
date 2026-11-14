extends Node3D
## Small live-edit scenarios that finish inside the existing smoke movement window.

var complete: bool = false
var materials_ok: bool = true
var joints_ok: bool = true
var hinge_impulse_ok: bool = false
var mesh_contacts_ok: bool = false
var world_joints_ok: bool = false
var ccd_response_ok: bool = false


func _ready() -> void:
	position.x = 70
	_world_joint_contract()
	_ccd_response_contract()
	_run()


func _ccd_response_contract() -> void:
	# Small, fast rounded shapes expose the post-TOI failure even at 60/120 Hz.
	# Keep the smoke scene's tick rate unchanged so its other contracts stay valid.
	var cases: Array[Dictionary] = []
	for surface in 6:
		var orientation: int = surface % 3
		for kind in 3:
			var basis: Basis = [Basis(), Basis(Vector3.FORWARD, PI / 2), Basis(Vector3.RIGHT, PI)][orientation]
			var frame := Transform3D(basis, Vector3(150 + 60 * cases.size(), 100, 0))
			var wall := StaticBody3D.new()
			wall.transform = frame
			wall.collision_layer = 256
			wall.collision_mask = 256
			var collision: CollisionShape3D
			if surface >= 3:
				collision = CollisionShape3D.new()
				var mesh := ConcavePolygonShape3D.new()
				mesh.set_faces(PackedVector3Array([Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, -20), Vector3(20, 0, 20), Vector3(-20, 0, 20)]))
				collision.shape = mesh
			else:
				collision = _box(Vector3(40, 0.025, 40))
				collision.position.y = -0.0125
			wall.add_child(collision)
			add_child(wall)
			var body := RigidBody3D.new()
			body.transform = frame * Transform3D(Basis(), Vector3(-1, 2, 0))
			body.collision_layer = 256
			body.collision_mask = 256
			body.continuous_cd = true
			body.can_sleep = false
			body.gravity_scale = 0.0
			body.lock_rotation = true
			body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
			body.linear_damp = 0.0
			var material := PhysicsMaterial.new()
			material.friction = 0.0
			body.physics_material_override = material
			collision = CollisionShape3D.new()
			if kind == 0:
				var sphere := SphereShape3D.new()
				sphere.radius = 0.01
				collision.shape = sphere
			elif kind == 1:
				var capsule := CapsuleShape3D.new()
				capsule.radius = 0.01
				capsule.height = 0.04
				collision.shape = capsule
			else:
				collision = _box(Vector3.ONE * 0.02)
			body.add_child(collision)
			add_child(body)
			cases.append({"body": body, "wall": wall, "frame": frame})
	await get_tree().physics_frame
	await get_tree().physics_frame
	for item in cases:
		item.body.linear_velocity = item.frame.basis * Vector3(30, -300, 0)
	var ok := true
	for tick in 8:
		await get_tree().physics_frame
		for item in cases:
			var state := PhysicsServer3D.body_get_direct_state(item.body.get_rid())
			# The fixtures are children of this translated contract node.
			var local: Vector3 = (global_transform * item.frame).affine_inverse() * state.transform.origin
			ok = ok and local.is_finite() and state.linear_velocity.is_finite() and local.y > 0.007
	for item in cases:
		var state := PhysicsServer3D.body_get_direct_state(item.body.get_rid())
		var local: Vector3 = (global_transform * item.frame).affine_inverse() * state.transform.origin
		var velocity: Vector3 = item.frame.basis.inverse() * state.linear_velocity
		ok = ok and local.y < 0.03 and local.x > -0.5 and absf(velocity.y) < 1.0 and velocity.x > 20.0
		item.body.queue_free()
		item.wall.queue_free()
	ccd_response_ok = ok


func _world_joint_contract() -> void:
	var bodies: Array[RigidBody3D] = []
	var joints: Array[Joint3D] = []
	var frames: Array[Transform3D] = []
	for kind in 3:
		var body := RigidBody3D.new()
		body.position = Vector3(kind * 4, 5, 40)
		body.rotation.y = 0.6
		body.gravity_scale = 0.0
		body.can_sleep = false
		body.collision_layer = 0
		body.collision_mask = 0
		body.add_child(_box(Vector3.ONE))
		add_child(body)
		var joint: Joint3D
		if kind == 0:
			joint = PinJoint3D.new()
		elif kind == 1:
			joint = HingeJoint3D.new()
		else:
			joint = SliderJoint3D.new()
		joint.transform = body.transform
		add_child(joint)
		joint.node_b = joint.get_path_to(body)
		if kind == 1:
			joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -0.2)
			joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, 0.35)
			joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 1.0)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 2.0)
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
		elif kind == 2:
			joint.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, -0.4)
			joint.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.4)
		bodies.append(body)
		joints.append(joint)
		frames.append(body.global_transform)
	await get_tree().physics_frame
	for index in bodies.size():
		bodies[index].apply_central_impulse(frames[index].basis * Vector3(3, 2, 1))
	var ok := true
	for frame in 150:
		await get_tree().physics_frame
		if frame == 70:
			var hinge_relative := frames[1].affine_inverse() * bodies[1].global_transform
			var slider_relative := frames[2].affine_inverse() * bodies[2].global_transform
			ok = bodies[0].global_position.distance_to(frames[0].origin) < 0.04 and absf(hinge_relative.basis.get_euler().z + 0.35) < 0.04 and absf(slider_relative.origin.x - 0.4) < 0.04
			PhysicsServer3D.pin_joint_set_local_b(joints[0].get_rid(), frames[0].origin + Vector3.UP)
			joints[1].set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -2.0)
			bodies[2].apply_central_impulse(frames[2].basis * Vector3(-8, 0, 0))
	var hinge_relative := frames[1].affine_inverse() * bodies[1].global_transform
	var slider_relative := frames[2].affine_inverse() * bodies[2].global_transform
	world_joints_ok = ok and bodies[0].global_position.distance_to(frames[0].origin + Vector3.UP) < 0.04 and hinge_relative.origin.length() < 0.04 and absf(hinge_relative.basis.get_euler().z - 0.2) < 0.04 and absf(slider_relative.origin.x + 0.4) < 0.04 and Vector2(slider_relative.origin.y, slider_relative.origin.z).length() < 0.04
	print("World joints: pin=", bodies[0].global_position, " hinge=", hinge_relative.basis.get_euler(), " slider=", slider_relative.origin)


func _box(size: Vector3) -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	return collision


func _run() -> void:
	var mesh_bodies: Array[RigidBody3D] = _mesh_contract()
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.position.y = -0.5
	floor_body.collision_layer = 128
	floor_body.collision_mask = 128
	floor_body.add_child(_box(Vector3(40, 1, 10)))
	var floor_material: PhysicsMaterial = PhysicsMaterial.new()
	floor_material.friction = 0.0
	floor_body.physics_material_override = floor_material
	add_child(floor_body)
	var slider_body: RigidBody3D = RigidBody3D.new()
	slider_body.position.y = 0.5
	slider_body.collision_layer = 128
	slider_body.collision_mask = 128
	slider_body.lock_rotation = true
	slider_body.can_sleep = false
	slider_body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	slider_body.linear_damp = 0.0
	slider_body.add_child(_box(Vector3.ONE))
	var slider_material: PhysicsMaterial = PhysicsMaterial.new()
	slider_body.physics_material_override = slider_material
	add_child(slider_body)
	var balls: Array[RigidBody3D] = []
	var ball_materials: Array[PhysicsMaterial] = []
	for index in 2:
		var ball: RigidBody3D = RigidBody3D.new()
		ball.position = Vector3(-5 + index * 3, 4, 3)
		ball.collision_layer = 128
		ball.collision_mask = 128
		var collision: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.4
		collision.shape = sphere
		ball.add_child(collision)
		var material: PhysicsMaterial = PhysicsMaterial.new()
		material.bounce = 0.8 if index == 1 else 0.0
		material.absorbent = index == 1
		ball.physics_material_override = material
		add_child(ball)
		balls.append(ball)
		ball_materials.append(material)
	var anchor: StaticBody3D = StaticBody3D.new()
	anchor.position.z = 10
	add_child(anchor)
	var rotor: RigidBody3D = RigidBody3D.new()
	rotor.position = anchor.position
	rotor.gravity_scale = 0.0
	rotor.collision_layer = 0
	rotor.collision_mask = 0
	rotor.add_child(_box(Vector3.ONE))
	add_child(rotor)
	var hinge: HingeJoint3D = HingeJoint3D.new()
	hinge.position = anchor.position
	add_child(hinge)
	hinge.node_a = hinge.get_path_to(anchor)
	hinge.node_b = hinge.get_path_to(rotor)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -0.3)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, 0.3)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	# Preserve the fixture's original 100 Nm strength at its default 60 Hz.
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 100.0 / 60.0)
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 2.0)
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	var weak_rotor: RigidBody3D = RigidBody3D.new()
	weak_rotor.position = Vector3(0, 0, 14)
	weak_rotor.gravity_scale = 0.0
	weak_rotor.can_sleep = false
	weak_rotor.collision_layer = 0
	weak_rotor.collision_mask = 0
	weak_rotor.inertia = Vector3.ONE
	weak_rotor.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	weak_rotor.angular_damp = 0.0
	weak_rotor.add_child(_box(Vector3.ONE))
	add_child(weak_rotor)
	var weak_hinge: HingeJoint3D = HingeJoint3D.new()
	weak_hinge.position = weak_rotor.position
	add_child(weak_hinge)
	weak_hinge.node_a = weak_hinge.get_path_to(anchor)
	weak_hinge.node_b = weak_hinge.get_path_to(weak_rotor)
	weak_hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 10.0)
	weak_hinge.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.001)
	weak_hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	var initial_spin: float = 0.0
	var carriage: RigidBody3D = RigidBody3D.new()
	carriage.position = Vector3(0, 0, 12)
	carriage.gravity_scale = 0.0
	carriage.collision_layer = 0
	carriage.collision_mask = 0
	carriage.add_child(_box(Vector3.ONE))
	add_child(carriage)
	var slider: SliderJoint3D = SliderJoint3D.new()
	slider.position = carriage.position
	add_child(slider)
	slider.node_a = slider.get_path_to(anchor)
	slider.node_b = slider.get_path_to(carriage)
	slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, -0.4)
	slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.4)
	var bounced: Array[bool] = [false, false]
	for frame in 150:
		await get_tree().physics_frame
		for index in balls.size():
			bounced[index] = bounced[index] or balls[index].linear_velocity.y > 2.0
		if frame == 10:
			for index in range(1, mesh_bodies.size()):
				mesh_bodies[index].linear_velocity = Basis(Vector3.UP, 0.14) * Vector3(3, 0, 0)
			initial_spin = weak_rotor.angular_velocity.z
			slider_body.linear_velocity = Vector3(4, 0, 0)
			ball_materials[0].bounce = 0.8
			carriage.linear_velocity.x = 3.0
		elif frame == 40:
			hinge_impulse_ok = absf(weak_rotor.angular_velocity.z - initial_spin - 0.03) < 0.002
			materials_ok = materials_ok and slider_body.linear_velocity.x > 3.5
			floor_material.friction = 1.0
		elif frame == 85:
			materials_ok = materials_ok and absf(slider_body.linear_velocity.x) < 0.2
			floor_material.friction = 0.0
			slider_material.rough = true
			slider_body.linear_velocity = Vector3(4, 0, 0)
			joints_ok = rotor.rotation.z > 0.2 and rotor.rotation.z < 0.4 and carriage.position.x > 0.3 and carriage.position.x < 0.5
			print("Live joints forward: hinge=", rotor.rotation.z, " slider=", carriage.position)
			hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -2.0)
			carriage.linear_velocity.x = -3.0
	materials_ok = materials_ok and absf(slider_body.linear_velocity.x) < 0.2 and bounced[0] and not bounced[1]
	joints_ok = joints_ok and rotor.rotation.z < -0.2 and rotor.rotation.z > -0.4 and carriage.position.x < -0.3 and carriage.position.x > -0.5
	print("Live joints reverse: hinge=", rotor.rotation.z, " slider=", carriage.position)
	mesh_contacts_ok = absf(mesh_bodies[0].position.y - 0.5) < 0.04
	for index in range(1, mesh_bodies.size()):
		var local: Vector3 = Basis(Vector3.UP, -0.14) * (mesh_bodies[index].position - Vector3(0, 0, 30))
		mesh_contacts_ok = mesh_contacts_ok and local.x > 1.8 and absf(local.y - 0.5) < 0.08
	complete = true


func _mesh_contract() -> Array[RigidBody3D]:
	var bodies: Array[RigidBody3D] = []
	for floor_index in range(2):
		var floor_body: StaticBody3D = StaticBody3D.new()
		floor_body.position.z = 20 + floor_index * 10
		floor_body.rotation.y = 0.14 if floor_index == 1 else 0
		floor_body.collision_layer = 256
		floor_body.collision_mask = 256
		var faces: PackedVector3Array = PackedVector3Array()
		var cells: int = 64 if floor_index == 0 else 12
		var size: float = 2.0 if floor_index == 0 else 12.0
		for z in range(cells):
			for x in range(cells):
				var a: Vector3 = Vector3(size * (float(x) / cells - 0.5), 0, size * (float(z) / cells - 0.5))
				var b: Vector3 = a + Vector3(size / cells, 0, 0)
				var c: Vector3 = a + Vector3(0, 0, size / cells)
				var d: Vector3 = a + Vector3(size / cells, 0, size / cells)
				faces.append_array(PackedVector3Array([a, b, c, b, d, c]))
		var mesh: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		mesh.set_faces(faces)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = mesh
		floor_body.add_child(collision)
		add_child(floor_body)
	for index in range(3):
		var body: RigidBody3D = RigidBody3D.new()
		body.position = Vector3(0, 1.25, 20) if index == 0 else Basis(Vector3.UP, 0.14) * Vector3(-4, 0.51, -1 if index == 1 else 1) + Vector3(0, 0, 30)
		body.lock_rotation = true
		body.can_sleep = false
		body.collision_layer = 256
		body.collision_mask = 256
		var material: PhysicsMaterial = PhysicsMaterial.new()
		material.friction = 0
		body.physics_material_override = material
		var collision: CollisionShape3D = CollisionShape3D.new()
		if index == 0:
			collision.shape = SphereShape3D.new()
		elif index == 1:
			var capsule: CapsuleShape3D = CapsuleShape3D.new()
			capsule.radius = 0.25
			capsule.height = 1.0
			collision.shape = capsule
		else:
			collision.shape = BoxShape3D.new()
		body.add_child(collision)
		add_child(body)
		bodies.append(body)
	return bodies

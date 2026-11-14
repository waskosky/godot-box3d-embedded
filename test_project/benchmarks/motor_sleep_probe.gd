extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases: Array[Dictionary] = [
		{"name": "weak_default_sleep", "cap": 0.001, "can_sleep": true, "speed": 10.0},
		{"name": "weak_sleep_disabled", "cap": 0.001, "can_sleep": false, "speed": 10.0},
		{"name": "strong_default_sleep", "cap": 0.1, "can_sleep": true, "speed": 10.0},
		{"name": "slow_target_default_sleep", "cap": 0.1, "can_sleep": true, "speed": 0.005},
		{"name": "no_motor", "cap": 0.0, "can_sleep": true, "speed": 0.0},
	]
	for index in range(cases.size()):
		var item: Dictionary = cases[index]
		var body: RigidBody3D = RigidBody3D.new()
		body.position = Vector3(20 + index * 5, 5, 0)
		body.gravity_scale = 0.0
		body.inertia = Vector3.ONE
		body.collision_layer = 0
		body.collision_mask = 0
		body.can_sleep = item.can_sleep
		body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.angular_damp = 0.0
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = BoxShape3D.new()
		body.add_child(collision)
		root.add_child(body)
		var joint: HingeJoint3D = HingeJoint3D.new()
		joint.position = body.position
		root.add_child(joint)
		joint.node_a = joint.get_path_to(body)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, item.cap)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, item.speed)
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, item.cap > 0.0)
		item.body = body
		item.joint = joint
		item.first_sleep_tick = -1
		item.peak_before_edit = 0.0
	await physics_frame
	for tick in range(180):
		await physics_frame
		for item: Dictionary in cases:
			var body: RigidBody3D = item.body
			if not body.position.is_finite() or not body.angular_velocity.is_finite():
				print("RESULT: FAIL - non-finite motor state")
				quit(1)
				return
			if body.sleeping and item.first_sleep_tick == -1:
				item.first_sleep_tick = tick
			if tick < 90:
				item.peak_before_edit = maxf(item.peak_before_edit, absf(body.angular_velocity.z))
			if tick == 89:
				item.sleeping_before_edit = body.sleeping
				item.omega_before_edit = body.angular_velocity.z
				item.joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -item.speed)
			if tick == 91:
				item.sleeping_after_edit = body.sleeping
	for item: Dictionary in cases:
		var result: Dictionary = {"name": item.name, "cap": item.cap, "can_sleep": item.can_sleep, "target_speed_before_edit": item.speed, "first_sleep_tick": item.first_sleep_tick, "peak_abs_omega_before_edit": item.peak_before_edit, "sleeping_before_edit": item.sleeping_before_edit, "omega_before_edit": item.omega_before_edit, "sleeping_after_edit": item.sleeping_after_edit, "final_sleeping": item.body.sleeping, "final_omega": item.body.angular_velocity.z}
		print("MOTOR_SLEEP_PROBE ", JSON.stringify(result))
		item.joint.free()
		item.body.free()
	print("RESULT: PASS - bounded motor sleep observations; no sleep-policy or solver-parity assertion")
	quit(0)

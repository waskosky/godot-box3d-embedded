extends SceneTree
## Opt-in construction diagnostic; not a frame-time or total-memory acceptance test.

var grid: int = 129
var cycles: int = 3
var failures: int = 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--grid="):
			grid = int(argument.trim_prefix("--grid="))
		elif argument.begins_with("--cycles="):
			cycles = int(argument.trim_prefix("--cycles="))
	call_deferred("_run")


func _run() -> void:
	if grid < 3 or grid > 513 or cycles < 1 or cycles > 6 or PhysicsServer3D.get_class() != &"Box3DPhysicsServer3D":
		push_error("Require Box3D, grid 3..513 and cycles 1..6")
		quit(1)
		return
	var records: Array[Dictionary] = []
	for cycle in cycles:
		records.append(await _cycle())
	print("TERRAIN_PROFILE: ", JSON.stringify({
		"grid": grid, "triangles_per_owner": 2 * (grid - 1) * (grid - 1),
		"owners": 2, "cycles": records, "failures": failures,
		"godot": Engine.get_version_info().string, "os": OS.get_name(),
		"godot_static_memory_excludes_box3d_and_gpu": true,
	}))
	quit(1 if failures > 0 else 0)


func _cycle() -> Dictionary:
	var record: Dictionary = {"godot_static_before": OS.get_static_memory_usage()}
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(grid * grid)
	for z in grid:
		for x in grid:
			heights[z * grid + x] = 0.1 * sin(x * 0.1) * cos(z * 0.1)
	var start: int = Time.get_ticks_usec()
	var terrain: HeightMapShape3D = HeightMapShape3D.new()
	terrain.map_width = grid
	terrain.map_depth = grid
	terrain.map_data = heights
	record.resource_ms = (Time.get_ticks_usec() - start) / 1000.0
	var owners: Array[StaticBody3D] = []
	for index in 2:
		start = Time.get_ticks_usec()
		var body: StaticBody3D = StaticBody3D.new()
		body.position.x = index * (grid + 4)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = terrain
		if index == 1:
			collision.position.y = 0.25
			collision.rotation.y = 0.2
		body.add_child(collision)
		root.add_child(body)
		owners.append(body)
		record["identity_owner_ms" if index == 0 else "baked_owner_ms"] = (Time.get_ticks_usec() - start) / 1000.0
	record.godot_static_loaded = OS.get_static_memory_usage()
	await physics_frame
	heights.fill(0.5)
	start = Time.get_ticks_usec()
	terrain.map_data = heights
	record.shared_update_ms = (Time.get_ticks_usec() - start) / 1000.0
	await physics_frame
	var state: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	for index in owners.size():
		var center: Vector3 = owners[index].position
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center + Vector3.UP * 2, center - Vector3.UP * 2)
		var hit: Dictionary = state.intersect_ray(ray)
		if hit.get("collider") != owners[index] or absf(hit.get("position", Vector3.ZERO).y - (0.5 + index * 0.25)) > 0.02:
			failures += 1
			push_error("Updated heightmap lost collision placement")
	start = Time.get_ticks_usec()
	for body in owners:
		body.free()
	owners.clear()
	terrain = null
	heights.clear()
	record.cleanup_ms = (Time.get_ticks_usec() - start) / 1000.0
	await process_frame
	await physics_frame
	record.godot_static_after = OS.get_static_memory_usage()
	record.nodes_after = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	record.resources_after = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	return record

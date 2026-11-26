extends Node3D

const ARENA_HALF := 24.2

@onready var spawn_points_node: Node3D = $SpawnPoints


func get_randomized_spawns(count: int) -> Array[Vector3]:
	var markers: Array[Vector3] = []
	if spawn_points_node != null:
		for child in spawn_points_node.get_children():
			if child is Node3D:
				markers.append(child.global_position)

	if markers.is_empty():
		markers.append(Vector3.ZERO)

	markers.shuffle()
	var result: Array[Vector3] = []
	for i in count:
		var base_pos: Vector3 = markers[i % markers.size()]
		var jx := randf_range(-0.5, 0.5)
		var jz := randf_range(-0.5, 0.5)
		var candidate := Vector3(
			clampf(base_pos.x + jx, -ARENA_HALF + 1.2, ARENA_HALF - 1.2),
			base_pos.y,
			clampf(base_pos.z + jz, -ARENA_HALF + 1.2, ARENA_HALF - 1.2)
		)
		if not is_position_clear(candidate, 0.45):
			candidate = base_pos
		result.append(candidate)
	return result


func is_position_clear(pos: Vector3, radius: float = 0.45) -> bool:
	if not is_inside_tree():
		return true
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, Vector3(pos.x, 1.0, pos.z))
	query.collision_mask = 3 # SolidWalls (Layer 1) | LaserWalls (Layer 2)
	return space_state.intersect_shape(query, 1).is_empty()

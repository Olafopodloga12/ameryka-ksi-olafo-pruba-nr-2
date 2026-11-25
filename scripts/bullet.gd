extends Node3D

signal hit_pierog(bullet_id: String, victim_id: int)

const ARENA_HALF := 24.2

var bullet_id: String = ""
var velocity: Vector3 = Vector3.ZERO
var life: float = 2.2
var _is_authoritative: bool = false
var _killer_id: int = 1
var _players_ref: Dictionary = {}


func setup(p_id: String, start_pos: Vector3, dir: Vector3, speed: float, p_killer_id: int, p_is_auth: bool, p_players: Dictionary) -> void:
	bullet_id = p_id
	global_position = start_pos
	velocity = dir.normalized() * speed
	_killer_id = p_killer_id
	_is_authoritative = p_is_auth
	_players_ref = p_players


func _physics_process(delta: float) -> void:
	var old_pos := global_position
	var new_pos := old_pos + velocity * delta
	life -= delta

	# 1. Bounds check
	if absf(new_pos.x) > ARENA_HALF or absf(new_pos.z) > ARENA_HALF or new_pos.y < 0.08 or new_pos.y > 6.0 or life <= 0.0:
		queue_free()
		return

	# 2. Solid wall / floor sweep check (Layer 1 only — passes through translucent laser gates!)
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var query := PhysicsRayQueryParameters3D.create(old_pos, new_pos, 1)
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			queue_free()
			return

	global_position = new_pos

	# 3. Pieróg hit check (authoritative check + visual cleanup)
	for pid in _players_ref.keys():
		if int(pid) == _killer_id:
			continue
		var p = _players_ref[pid]
		if is_instance_valid(p) and p.alive:
			var dist_xz := Vector2(global_position.x - p.global_position.x, global_position.z - p.global_position.z).length()
			if dist_xz < 1.35 and global_position.y >= 0.08 and global_position.y <= 2.5:
				if _is_authoritative:
					hit_pierog.emit(bullet_id, int(pid))
				queue_free()
				return

extends CharacterBody3D

signal shot_requested(origin: Vector3, dir: Vector3)
signal twarog_requested(pos: Vector3)

const ARENA_HALF := 24.2

var player_id: int = 1
var player_name: String = "Gracz"
var is_killer: bool = false
var is_local: bool = false
var alive: bool = true

# Movement & Sprint
var base_speed: float = 6.0
var sprint_multiplier: float = 1.6
var stamina: float = 1.0
var max_stamina: float = 1.0
var stamina_drain: float = 0.3
var stamina_regen: float = 0.15
var is_sprinting: bool = false
var is_slowed: bool = false

# Third-Person Camera state (Olafo Killer)
var tpp_yaw: float = 0.0
var tpp_pitch: float = -0.05

# Remote interpolation target
var target_position: Vector3 = Vector3.ZERO

# Gun visual recoil animation state
var _gun_pivot: Node3D = null
var _gun_mesh: Node3D = null
var _muzzle_flash: MeshInstance3D = null
var _muzzle_light: OmniLight3D = null
var _gun_shoot_timer: float = 0.0
const GUN_SHOOT_DURATION := 0.55

var _aura_mesh: MeshInstance3D = null
var _camera_ref: Camera3D = null
var _tex_killer: Texture2D
var _tex_pierog: Texture2D
var _tex_dead: Texture2D

@onready var sprite: Sprite3D = $BillboardSprite
@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var name_viewport: SubViewport = $NameViewport
@onready var name_sprite: Sprite3D = $NameSprite
@onready var name_label: Label = $NameViewport/BadgeControl/BadgePanel/NameLabel
@onready var badge_panel: PanelContainer = $NameViewport/BadgeControl/BadgePanel


func setup(p_id: int, p_name: String, p_is_killer: bool, p_is_local: bool, cam: Camera3D) -> void:
	player_id = p_id
	player_name = p_name
	is_killer = p_is_killer
	is_local = p_is_local
	_camera_ref = cam

	base_speed = 8.5 if is_killer else 6.0
	# Layer 3 = Players; Mask 1 = SolidWalls for Killer (passes through red laser walls Layer 2!),
	# Mask 3 (Layer 1 | Layer 2) = Pierogi blocked by both solid walls & red laser forcefields!
	collision_layer = 4
	collision_mask = 1 if is_killer else 3


func _ready() -> void:
	_tex_killer = load("res://olafo killer.png")
	_tex_pierog = load("res://pierog.png")
	_tex_dead = load("res://dead_pierog.png")

	_apply_sprite_texture(_tex_killer if is_killer else _tex_pierog)
	_setup_nameplate()

	if is_killer:
		_create_killer_ring()
		_create_gun_model()


func _apply_sprite_texture(tex: Texture2D) -> void:
	if tex == null or sprite == null:
		return
	sprite.texture = tex
	var h := float(tex.get_height())
	if h > 0.0:
		sprite.pixel_size = 2.0 / h
	sprite.position.y = 1.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.double_sided = true


func _setup_nameplate() -> void:
	var rubik_font: Font = load("res://RubikIso-Regular.ttf")
	if rubik_font != null:
		name_label.add_theme_font_override("font", rubik_font)
	name_label.text = player_name

	var border_col := Color("#ff0055") if is_killer else Color("#00f0ff")
	var text_col := Color("#ff3377") if is_killer else Color("#ffffff")
	name_label.add_theme_color_override("font_color", text_col)
	name_label.add_theme_color_override("font_shadow_color", border_col)
	name_label.add_theme_constant_override("shadow_outline_size", 8)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.09, 0.85)
	sb.border_color = border_col
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	badge_panel.add_theme_stylebox_override("panel", sb)

	name_sprite.texture = name_viewport.get_texture()
	name_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_sprite.no_depth_test = true
	name_sprite.render_priority = 10
	name_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


func _create_killer_ring() -> void:
	# Thin neon red laser ring under Olafo Killer
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.96
	torus.outer_radius = 1.05
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.15, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.0, 0.33, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position.y = 0.04
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_aura_mesh = ring


func _create_gun_model() -> void:
	_gun_pivot = Node3D.new()
	_gun_pivot.position = Vector3(0.0, 1.05, 0.0)

	_gun_mesh = Node3D.new()
	_gun_mesh.position = Vector3(0.62, 0.0, -0.32)
	_gun_pivot.add_child(_gun_mesh)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#242830")
	body_mat.roughness = 0.3
	body_mat.metallic = 0.85

	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color("#111317")
	barrel_mat.roughness = 0.15
	barrel_mat.metallic = 0.95

	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color("#3d2010")
	grip_mat.roughness = 0.75

	# Receiver (aligned forward along -Z)
	var receiver := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(0.12, 0.16, 0.38)
	receiver.mesh = r_box
	receiver.material_override = body_mat
	_gun_mesh.add_child(receiver)

	# Barrel pointing towards -Z
	var barrel := MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 0.045
	b_cyl.bottom_radius = 0.045
	b_cyl.height = 0.34
	barrel.mesh = b_cyl
	barrel.material_override = barrel_mat
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0.0, 0.04, -0.30)
	_gun_mesh.add_child(barrel)

	# Grip angled backward
	var grip := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	g_box.size = Vector3(0.10, 0.22, 0.12)
	grip.mesh = g_box
	grip.material_override = grip_mat
	grip.rotation.x = 0.35
	grip.position = Vector3(0.0, -0.13, 0.06)
	_gun_mesh.add_child(grip)

	# Muzzle flash
	_muzzle_flash = MeshInstance3D.new()
	var f_sphere := SphereMesh.new()
	f_sphere.radius = 0.18
	f_sphere.height = 0.36
	var f_mat := StandardMaterial3D.new()
	f_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	f_mat.albedo_color = Color(1.0, 0.72, 0.0, 0.95)
	f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_muzzle_flash.mesh = f_sphere
	_muzzle_flash.material_override = f_mat
	_muzzle_flash.position = Vector3(0.0, 0.04, -0.52)
	_muzzle_flash.visible = false
	_gun_mesh.add_child(_muzzle_flash)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color("#ff6600")
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 4.0
	_muzzle_light.position = Vector3(0.0, 0.04, -0.55)
	_gun_mesh.add_child(_muzzle_light)

	_gun_pivot.visible = false
	add_child(_gun_pivot)


func trigger_gun_shot(dir: Vector3) -> void:
	if _gun_pivot == null:
		return
	_gun_pivot.visible = true
	_gun_shoot_timer = GUN_SHOOT_DURATION
	# Yaw so gun's -Z barrel aligns with shot direction (dir.x, dir.z)
	_gun_pivot.rotation.y = atan2(-dir.x, -dir.z)
	_gun_mesh.position = Vector3(0.62, 0.0, -0.32)
	_gun_mesh.rotation = Vector3.ZERO
	if _muzzle_flash != null:
		_muzzle_flash.visible = true
	if _muzzle_light != null:
		_muzzle_light.light_energy = 3.5


func handle_mouse_motion(relative: Vector2) -> void:
	if not is_local or not alive or not is_killer:
		return
	# Non-inverted third-person camera:
	# Right mouse moves yaw right (clockwise -> decreasing Y rotation)
	# Up mouse (negative relative.y) looks UP (+pitch)
	tpp_yaw -= relative.x * 0.003
	tpp_pitch -= relative.y * 0.003
	tpp_pitch = clampf(tpp_pitch, -0.55, 0.55)


func get_aim_direction() -> Vector3:
	var aim_basis := Basis(Vector3.UP, tpp_yaw) * Basis(Vector3.RIGHT, tpp_pitch)
	return (aim_basis * Vector3(0.0, 0.0, -1.0)).normalized()


func get_flat_shoot_direction() -> Vector3:
	# Bullet always stays level on Y (dir.y == 0), while XZ aim follows mouse yaw
	return Vector3(-sin(tpp_yaw), 0.0, -cos(tpp_yaw)).normalized()


func set_spawn_position(pos: Vector3) -> void:
	global_position = pos
	target_position = pos


func set_remote_target(pos: Vector3) -> void:
	target_position = pos


func update_player(delta: float, can_move: bool) -> void:
	_update_gun_animation(delta)

	if not alive:
		return

	if is_local:
		_update_local_movement(delta, can_move)
	else:
		# Smooth remote interpolation
		var t := minf(12.0 * delta, 1.0)
		global_position = global_position.lerp(target_position, t)


func _update_local_movement(delta: float, can_move: bool) -> void:
	if not can_move:
		velocity = Vector3.ZERO
		return

	var input_x := 0.0
	var input_z := 0.0
	if Input.is_action_pressed("move_forward"):
		input_z -= 1.0
	if Input.is_action_pressed("move_back"):
		input_z += 1.0
	if Input.is_action_pressed("move_left"):
		input_x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_x += 1.0

	var move_dir := Vector3.ZERO
	if is_killer:
		# TPP controls: W = along look yaw forward, S = back, A = left, D = right
		var fwd := Vector3(-sin(tpp_yaw), 0.0, -cos(tpp_yaw)).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		move_dir = fwd * (-input_z) + right * input_x
	else:
		# Pieróg top-down controls: W = -Z, S = +Z, A = -X, D = +X
		move_dir = Vector3(input_x, 0.0, input_z)

	if move_dir.length() > 0.001:
		move_dir = move_dir.normalized()

	var want_sprint := Input.is_action_pressed("sprint")
	var speed := base_speed

	if is_killer:
		is_sprinting = want_sprint
		if is_sprinting:
			speed *= sprint_multiplier
		if is_slowed:
			speed *= 0.42 # -58% slowdown inside Twaróg!
	else:
		if want_sprint and stamina > 0.0 and move_dir.length() > 0.001:
			is_sprinting = true
			speed *= sprint_multiplier
			stamina = maxf(0.0, stamina - stamina_drain * delta)
		else:
			is_sprinting = false
			stamina = minf(max_stamina, stamina + stamina_regen * delta)

	var target_vel := move_dir * speed
	velocity.x = lerpf(velocity.x, target_vel.x, minf(12.0 * delta, 1.0))
	velocity.z = lerpf(velocity.z, target_vel.z, minf(12.0 * delta, 1.0))
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	global_position.x = clampf(global_position.x, -ARENA_HALF, ARENA_HALF)
	global_position.z = clampf(global_position.z, -ARENA_HALF, ARENA_HALF)


func update_local_camera(delta: float, cam: Camera3D) -> void:
	if cam == null or not is_local or not alive:
		return

	if is_killer:
		var look_dir := get_aim_direction()
		var pivot := global_position + Vector3(0.0, 1.85, 0.0)
		var cam_dist := 3.8
		# Desired camera centered behind Olafo + slight elevation
		var desired_cam := pivot - look_dir * cam_dist + Vector3(0.0, 0.35, 0.0)
		desired_cam.y = maxf(desired_cam.y, 0.45)

		# Raycast against SolidWalls (Layer 1) so camera NEVER enters walls or obstacles!
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(pivot, desired_cam, 1)
		query.exclude = [get_rid()]
		var hit := space_state.intersect_ray(query)
		var final_cam := desired_cam
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var to_pivot := (pivot - desired_cam).normalized()
			final_cam = hit_pos + to_pivot * 0.42
			if final_cam.distance_to(pivot) < 0.55:
				final_cam = pivot + (desired_cam - pivot).normalized() * 0.55
		final_cam.y = maxf(final_cam.y, 0.4)

		cam.global_position = final_cam
		cam.look_at(pivot + look_dir * 20.0, Vector3.UP)
	else:
		# Pieróg classic top-down / isometric camera
		var target_cam := global_position + Vector3(0.0, 14.0, 10.0)
		var t := minf(6.0 * delta, 1.0)
		cam.global_position = cam.global_position.lerp(target_cam, t)
		cam.look_at(global_position, Vector3.UP)


func _update_gun_animation(delta: float) -> void:
	if _gun_pivot == null or _gun_shoot_timer <= 0.0:
		return

	_gun_shoot_timer -= delta
	if _gun_shoot_timer <= 0.0:
		_gun_shoot_timer = 0.0
		_gun_pivot.visible = false
		if _muzzle_flash != null:
			_muzzle_flash.visible = false
		if _muzzle_light != null:
			_muzzle_light.light_energy = 0.0
		_gun_mesh.rotation = Vector3.ZERO
		_gun_mesh.position = Vector3(0.62, 0.0, -0.32)
		return

	var elapsed := GUN_SHOOT_DURATION - _gun_shoot_timer
	if elapsed > 0.08:
		if _muzzle_flash != null:
			_muzzle_flash.visible = false
		if _muzzle_light != null:
			_muzzle_light.light_energy = 0.0

	# Recoil kick: barrel flips UP (+X rotation lifts -Z up) then settles back DOWN
	if elapsed <= 0.12:
		var p := elapsed / 0.12
		_gun_mesh.rotation.x = 0.65 * sin(p * (PI * 0.5))
		_gun_mesh.position.z = -0.32 + 0.14 * p
	elif elapsed <= 0.36:
		var p := (elapsed - 0.12) / 0.24
		_gun_mesh.rotation.x = 0.65 * cos(p * (PI * 0.5))
		_gun_mesh.position.z = -0.18 - 0.14 * p
	else:
		var p := (elapsed - 0.36) / (GUN_SHOOT_DURATION - 0.36)
		_gun_mesh.rotation.x = -0.25 * p
		_gun_mesh.position.y = -0.15 * p


func kill_player() -> void:
	if not alive:
		return
	alive = false
	collision_mask = 0
	collision_layer = 0
	_apply_sprite_texture(_tex_dead)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(sprite, "modulate:a", 0.4, 0.4)
	tw.parallel().tween_property(name_sprite, "modulate:a", 0.4, 0.4)
	if _aura_mesh != null:
		_aura_mesh.visible = false

extends Node3D

var puddle_id: String = ""
var radius: float = 2.4
var life: float = 12.0
var max_life: float = 12.0

var _mat: StandardMaterial3D = null
static var _cached_texture: ImageTexture = null


func setup(p_id: String, p_radius: float = 2.4, p_duration: float = 12.0) -> void:
	puddle_id = p_id
	radius = p_radius
	life = p_duration
	max_life = p_duration


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)

	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = _get_twarog_texture()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	_mat.roughness = 0.9

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = plane
	mesh_inst.material_override = _mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_inst)

	rotation.y = randf() * TAU
	position.y = 0.03


func _process(delta: float) -> void:
	life -= delta
	if life < 2.0 and _mat != null:
		_mat.albedo_color.a = maxf(0.0, (life / 2.0) * 0.95)
	if life <= 0.0:
		queue_free()


func contains_xz(pos: Vector3) -> bool:
	var dx := pos.x - global_position.x
	var dz := pos.z - global_position.z
	return sqrt(dx * dx + dz * dz) < radius


static func _get_twarog_texture() -> ImageTexture:
	if _cached_texture != null:
		return _cached_texture

	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(sz * 0.5, sz * 0.5)

	# Paint soft organic splat + curds
	for y in sz:
		for x in sz:
			var d := Vector2(x, y) - center
			var ang := atan2(d.y, d.x)
			var edge := 46.0 + sin(ang * 4.0 + 1.0) * 7.0 + cos(ang * 2.0) * 4.0
			var dist := d.length()
			if dist < edge:
				var falloff := clampf(1.0 - (dist / edge), 0.0, 1.0)
				var alpha := clampf(falloff * 2.4, 0.0, 0.96)
				img.set_pixel(x, y, Color(0.98, 0.98, 0.95, alpha))

	# Draw organic white/cream twaróg curds
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for _i in 45:
		var ang := rng.randf() * TAU
		var dist := rng.randf() * 38.0
		var cx := int(center.x + cos(ang) * dist)
		var cy := int(center.y + sin(ang) * dist)
		var cr := rng.randi_range(2, 4)
		var col := Color(1, 1, 1, 1) if (_i % 2 == 0) else Color(0.96, 0.95, 0.89, 1)
		for dy in range(-cr, cr + 1):
			for dx in range(-cr, cr + 1):
				if dx * dx + dy * dy <= cr * cr:
					var px := cx + dx
					var py := cy + dy
					if px >= 0 and px < sz and py >= 0 and py < sz:
						img.set_pixel(px, py, col)

	_cached_texture = ImageTexture.create_from_image(img)
	return _cached_texture

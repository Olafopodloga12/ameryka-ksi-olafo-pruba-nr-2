@tool
extends StaticBody3D

@export var wall_size: Vector3 = Vector3(4.5, 3.1, 0.32):
	set(value):
		wall_size = value
		_rebuild_visuals()


func _ready() -> void:
	_rebuild_visuals()


func _rebuild_visuals() -> void:
	if not is_inside_tree():
		return

	var col: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if col != null:
		var shape := BoxShape3D.new()
		shape.size = wall_size
		col.shape = shape
		col.position = Vector3(0.0, wall_size.y * 0.5, 0.0)

	var glass: MeshInstance3D = get_node_or_null("GlassMesh")
	if glass != null:
		var g_box := BoxMesh.new()
		g_box.size = Vector3(wall_size.x, wall_size.y, maxf(0.08, wall_size.z * 0.45))
		glass.mesh = g_box
		glass.position = Vector3(0.0, wall_size.y * 0.5, 0.0)

		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(1.0, 0.04, 0.18, 0.30)
		b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		b_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		b_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		b_mat.emission_enabled = true
		b_mat.emission = Color(1.0, 0.04, 0.22)
		b_mat.emission_energy_multiplier = 1.4
		glass.material_override = b_mat

	var bar_mat := StandardMaterial3D.new()
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.albedo_color = Color(1.0, 0.18, 0.35, 0.95)
	bar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for idx in 5:
		var bar: MeshInstance3D = get_node_or_null("LaserBar%d" % (idx + 1))
		if bar != null:
			var bar_box := BoxMesh.new()
			bar_box.size = Vector3(wall_size.x, 0.06, 0.08)
			bar.mesh = bar_box
			bar.position = Vector3(0.0, wall_size.y * (0.1 + float(idx) * 0.2), 0.0)
			bar.material_override = bar_mat

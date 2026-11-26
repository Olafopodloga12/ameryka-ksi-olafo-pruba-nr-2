@tool
extends StaticBody3D

@export var block_size: Vector3 = Vector3(2.5, 3.2, 2.5):
	set(value):
		block_size = value
		_apply_geometry()

@export var body_color: Color = Color("#101528"):
	set(value):
		body_color = value
		_apply_materials()

@export var neon_color: Color = Color("#00f0ff"):
	set(value):
		neon_color = value
		_apply_materials()

@onready var _col: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var _mesh_inst: MeshInstance3D = get_node_or_null("BodyMesh")
@onready var _cap_inst: MeshInstance3D = get_node_or_null("NeonCap")


func _ready() -> void:
	_apply_geometry()
	_apply_materials()


func _apply_geometry() -> void:
	if not is_inside_tree():
		return
	if _col != null:
		var shape := BoxShape3D.new()
		shape.size = block_size
		_col.shape = shape
		_col.position = Vector3(0.0, block_size.y * 0.5, 0.0)

	if _mesh_inst != null:
		var box := BoxMesh.new()
		box.size = block_size
		_mesh_inst.mesh = box
		_mesh_inst.position = Vector3(0.0, block_size.y * 0.5, 0.0)

	if _cap_inst != null:
		var cap := BoxMesh.new()
		cap.size = Vector3(block_size.x * 0.98, 0.09, block_size.z * 0.98)
		_cap_inst.mesh = cap
		_cap_inst.position = Vector3(0.0, block_size.y + 0.045, 0.0)


func _apply_materials() -> void:
	if not is_inside_tree():
		return
	if _mesh_inst != null:
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = body_color
		b_mat.roughness = 0.3
		b_mat.metallic = 0.6
		_mesh_inst.material_override = b_mat

	if _cap_inst != null:
		var c_mat := StandardMaterial3D.new()
		c_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c_mat.albedo_color = neon_color
		_cap_inst.material_override = c_mat

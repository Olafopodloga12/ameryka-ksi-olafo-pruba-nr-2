@tool
extends Node3D

@export var beam_color: Color = Color(1.0, 0.0, 0.33, 0.85):
	set(value):
		beam_color = value
		_update_mat()

@export var move_speed: float = 0.4
@export var move_range: float = 4.0

var _base_z: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_z = position.z
	_update_mat()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	position.z = _base_z + sin(_time * move_speed) * move_range


func _update_mat() -> void:
	if not is_inside_tree():
		return
	var mesh_inst: MeshInstance3D = get_node_or_null("BeamMesh")
	if mesh_inst == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = beam_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat

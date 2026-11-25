extends Node3D

const ARENA_SIZE := 50.0
const ARENA_HALF := 24.2

const OBSTACLES := [
	# Central pillars
	{ "x": -3.5, "z": -3.5, "w": 2.5, "d": 2.5 },
	{ "x":  3.5, "z": -3.5, "w": 2.5, "d": 2.5 },
	{ "x": -3.5, "z":  3.5, "w": 2.5, "d": 2.5 },
	{ "x":  3.5, "z":  3.5, "w": 2.5, "d": 2.5 },

	# Central cross barriers
	{ "x":  0.0, "z": -11.0, "w": 7.0, "d": 1.5 },
	{ "x":  0.0, "z":  11.0, "w": 7.0, "d": 1.5 },
	{ "x": -11.0, "z": 0.0,  "w": 1.5, "d": 7.0 },
	{ "x":  11.0, "z": 0.0,  "w": 1.5, "d": 7.0 },

	# North-West Zone
	{ "x": -14.0, "z": -15.0, "w": 12.0, "d": 1.5 },
	{ "x": -18.0, "z": -8.0,  "w": 1.5,  "d": 10.0 },
	{ "x": -8.0,  "z": -6.0,  "w": 1.5,  "d": 6.0 },
	{ "x": -14.0, "z": -4.0,  "w": 2.5,  "d": 2.5 },
	{ "x": -20.0, "z": -18.0, "w": 3.0,  "d": 3.0 },

	# North-East Zone
	{ "x":  14.0, "z": -15.0, "w": 12.0, "d": 1.5 },
	{ "x":  18.0, "z": -8.0,  "w": 1.5,  "d": 10.0 },
	{ "x":  8.0,  "z": -6.0,  "w": 1.5,  "d": 6.0 },
	{ "x":  14.0, "z": -4.0,  "w": 2.5,  "d": 2.5 },
	{ "x":  20.0, "z": -18.0, "w": 3.0,  "d": 3.0 },

	# South-West Zone
	{ "x": -14.0, "z":  15.0, "w": 12.0, "d": 1.5 },
	{ "x": -18.0, "z":  8.0,  "w": 1.5,  "d": 10.0 },
	{ "x": -8.0,  "z":  6.0,  "w": 1.5,  "d": 6.0 },
	{ "x": -14.0, "z":  4.0,  "w": 2.5,  "d": 2.5 },
	{ "x": -20.0, "z":  18.0, "w": 3.0,  "d": 3.0 },

	# South-East Zone
	{ "x":  14.0, "z":  15.0, "w": 12.0, "d": 1.5 },
	{ "x":  18.0, "z":  8.0,  "w": 1.5,  "d": 10.0 },
	{ "x":  8.0,  "z":  6.0,  "w": 1.5,  "d": 6.0 },
	{ "x":  14.0, "z":  4.0,  "w": 2.5,  "d": 2.5 },
	{ "x":  20.0, "z":  18.0, "w": 3.0,  "d": 3.0 },

	# Outer corner hiding spots
	{ "x": -7.0, "z": -20.0, "w": 4.0, "d": 1.5 },
	{ "x":  7.0, "z": -20.0, "w": 4.0, "d": 1.5 },
	{ "x": -7.0, "z":  20.0, "w": 4.0, "d": 1.5 },
	{ "x":  7.0, "z":  20.0, "w": 4.0, "d": 1.5 }
]

# Translucent red one-way laser walls: Olafo Killer walks right through (Layer 2 ignored),
# Pierogi are blocked (Layer 2 collides) so they cannot endlessly loop Olafo around pillars/zones!
const LASER_WALLS := [
	{ "x":   0.0, "z": -3.5, "w": 4.5, "d": 0.32 },
	{ "x":   0.0, "z":  3.5, "w": 4.5, "d": 0.32 },
	{ "x": -13.0, "z": -7.5, "w": 8.5, "d": 0.32 },
	{ "x":  13.0, "z": -7.5, "w": 8.5, "d": 0.32 },
	{ "x": -13.0, "z":  7.5, "w": 8.5, "d": 0.32 },
	{ "x":  13.0, "z":  7.5, "w": 8.5, "d": 0.32 }
]

const SPAWN_CANDIDATES := [
	Vector2(-16.0, -21.5),
	Vector2(  0.0, -19.0),
	Vector2( 16.0, -21.5),
	Vector2(-21.5, -10.0),
	Vector2( -5.0, -14.5),
	Vector2(  5.0, -14.5),
	Vector2( 21.5, -10.0),
	Vector2(-19.5,   0.0),
	Vector2( -7.0,   0.0),
	Vector2(  7.0,   0.0),
	Vector2( 19.5,   0.0),
	Vector2(-21.5,  10.0),
	Vector2( -5.0,  14.5),
	Vector2(  5.0,  14.5),
	Vector2( 21.5,  10.0),
	Vector2(-16.0,  21.5),
	Vector2(  0.0,  19.0),
	Vector2( 16.0,  21.5),
	Vector2(-13.5, -11.0),
	Vector2( 13.5, -11.0),
	Vector2(-13.5,  11.0),
	Vector2( 13.5,  11.0),
	Vector2(  0.0,   0.0),
	Vector2(-13.0, -20.0)
]

var _ambient_lasers: Array = []
var _time: float = 0.0


func _ready() -> void:
	_build_floor_and_grid()
	_build_boundary_walls()
	_build_obstacles()
	_build_one_way_laser_walls()
	_build_ambient_laser_beams()
	_build_corner_burger()


func _process(delta: float) -> void:
	_time += delta
	for entry in _ambient_lasers:
		var mesh: MeshInstance3D = entry["mesh"]
		var base_z: float = entry["base_z"]
		var speed: float = entry["speed"]
		mesh.position.z = base_z + sin(_time * speed) * 4.0


func get_randomized_spawns(count: int) -> Array[Vector3]:
	var pool := SPAWN_CANDIDATES.duplicate()
	pool.shuffle()
	var result: Array[Vector3] = []
	for i in count:
		var pt: Vector2 = pool[i % pool.size()]
		var jx := randf_range(-0.5, 0.5)
		var jz := randf_range(-0.5, 0.5)
		var candidate := Vector2(
			clampf(pt.x + jx, -ARENA_HALF + 1.2, ARENA_HALF - 1.2),
			clampf(pt.y + jz, -ARENA_HALF + 1.2, ARENA_HALF - 1.2)
		)
		if not _is_point_clear(candidate, 0.9):
			candidate = pt
		result.append(Vector3(candidate.x, 0.0, candidate.y))
	return result


func _is_point_clear(pt: Vector2, margin: float) -> bool:
	for obs in OBSTACLES:
		if absf(pt.x - float(obs["x"])) < float(obs["w"]) * 0.5 + margin and absf(pt.y - float(obs["z"])) < float(obs["d"]) * 0.5 + margin:
			return false
	for lw in LASER_WALLS:
		if absf(pt.x - float(lw["x"])) < float(lw["w"]) * 0.5 + margin and absf(pt.y - float(lw["z"])) < float(lw["d"]) * 0.5 + margin:
			return false
	return true


func _build_floor_and_grid() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(ARENA_SIZE + 4.0, 0.4, ARENA_SIZE + 4.0)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, -0.2, 0.0)
	floor_body.add_child(col_shape)

	var floor_mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_SIZE, ARENA_SIZE)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#070913")
	floor_mat.roughness = 0.6
	floor_mat.metallic = 0.25
	floor_mesh_inst.mesh = plane
	floor_mesh_inst.material_override = floor_mat
	floor_body.add_child(floor_mesh_inst)
	add_child(floor_body)

	# Sharp laser floor grid via ImmediateMesh
	var grid_inst := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.vertex_color_use_as_albedo = true
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_inst.mesh = im
	grid_inst.material_override = grid_mat
	grid_inst.position.y = 0.015
	grid_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := ARENA_SIZE * 0.5
	var cyan := Color(0.0, 0.94, 1.0, 0.42)
	var red := Color(1.0, 0.0, 0.33, 0.72)
	for i in range(-25, 26):
		var c := red if (i == 0 or abs(i) == 25) else cyan
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(float(i), 0.0, -half))
		im.surface_add_vertex(Vector3(float(i), 0.0, half))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(-half, 0.0, float(i)))
		im.surface_add_vertex(Vector3(half, 0.0, float(i)))
	im.surface_end()
	add_child(grid_inst)


func _build_boundary_walls() -> void:
	var wall_h := 3.5
	var wall_t := 1.0
	var offset := ARENA_HALF + wall_t * 0.5
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color("#0b1326")
	wall_mat.roughness = 0.35
	wall_mat.metallic = 0.5

	var trim_mat := StandardMaterial3D.new()
	trim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trim_mat.albedo_color = Color("#ff0055")

	_add_solid_box(ARENA_SIZE + wall_t * 2.0, wall_h, wall_t, 0.0, wall_h * 0.5, -offset, wall_mat, trim_mat)
	_add_solid_box(ARENA_SIZE + wall_t * 2.0, wall_h, wall_t, 0.0, wall_h * 0.5,  offset, wall_mat, trim_mat)
	_add_solid_box(wall_t, wall_h, ARENA_SIZE, -offset, wall_h * 0.5, 0.0, wall_mat, trim_mat)
	_add_solid_box(wall_t, wall_h, ARENA_SIZE,  offset, wall_h * 0.5, 0.0, wall_mat, trim_mat)


func _build_obstacles() -> void:
	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = Color("#101528")
	mat_a.roughness = 0.3
	mat_a.metallic = 0.6

	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = Color("#0a1020")
	mat_b.roughness = 0.3
	mat_b.metallic = 0.6

	var neon_cyan := StandardMaterial3D.new()
	neon_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	neon_cyan.albedo_color = Color("#00f0ff")

	var neon_red := StandardMaterial3D.new()
	neon_red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	neon_red.albedo_color = Color("#ff0055")

	var h := 3.2
	for i in OBSTACLES.size():
		var obs: Dictionary = OBSTACLES[i]
		var w := float(obs["w"])
		var d := float(obs["d"])
		var x := float(obs["x"])
		var z := float(obs["z"])
		var body_mat := mat_a if (i % 2 == 0) else mat_b
		var trim := neon_cyan if (i % 2 == 0) else neon_red
		_add_solid_box(w, h, d, x, h * 0.5, z, body_mat, trim)


func _add_solid_box(w: float, h: float, d: float, x: float, y: float, z: float, body_mat: Material, trim_mat: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 # Layer 1: blocks both Killer, Pierogi, bullets & camera
	body.collision_mask = 0
	body.position = Vector3(x, y, z)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, d)
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, h, d)
	mesh_inst.mesh = box
	mesh_inst.material_override = body_mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh_inst)

	# Glowing neon cap on top edge
	var cap_inst := MeshInstance3D.new()
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(w * 0.98, 0.09, d * 0.98)
	cap_inst.mesh = cap_box
	cap_inst.material_override = trim_mat
	cap_inst.position = Vector3(0.0, h * 0.5 + 0.045, 0.0)
	cap_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(cap_inst)

	add_child(body)


func _build_one_way_laser_walls() -> void:
	var barrier_mat := StandardMaterial3D.new()
	barrier_mat.albedo_color = Color(1.0, 0.04, 0.18, 0.30)
	barrier_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	barrier_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	barrier_mat.emission_enabled = true
	barrier_mat.emission = Color(1.0, 0.04, 0.22)
	barrier_mat.emission_energy_multiplier = 1.4

	var bar_mat := StandardMaterial3D.new()
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.albedo_color = Color(1.0, 0.18, 0.35, 0.95)
	bar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var wall_h := 3.1
	for lw in LASER_WALLS:
		var w := float(lw["w"])
		var d := float(lw["d"])
		var x := float(lw["x"])
		var z := float(lw["z"])

		var body := StaticBody3D.new()
		body.collision_layer = 2 # Layer 2: blocks Pierogi ONLY (Olafo & bullets ignore Layer 2)
		body.collision_mask = 0
		body.position = Vector3(x, wall_h * 0.5, z)

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(w, wall_h, d)
		col.shape = shape
		body.add_child(col)

		var glass := MeshInstance3D.new()
		var glass_box := BoxMesh.new()
		glass_box.size = Vector3(w, wall_h, d * 0.45)
		glass.mesh = glass_box
		glass.material_override = barrier_mat
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(glass)

		# Glowing red horizontal laser strips inside forcefield
		for bar_idx in 5:
			var bar_y := -wall_h * 0.4 + float(bar_idx) * (wall_h * 0.2)
			var bar := MeshInstance3D.new()
			var bar_box := BoxMesh.new()
			bar_box.size = Vector3(w, 0.06, 0.08)
			bar.mesh = bar_box
			bar.material_override = bar_mat
			bar.position = Vector3(0.0, bar_y, 0.0)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(bar)

		add_child(body)


func _build_ambient_laser_beams() -> void:
	var red_mat := StandardMaterial3D.new()
	red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red_mat.albedo_color = Color(1.0, 0.0, 0.33, 0.85)
	red_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var cyan_mat := StandardMaterial3D.new()
	cyan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan_mat.albedo_color = Color(0.0, 0.94, 1.0, 0.78)
	cyan_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var configs := [
		{ "y": 1.7, "z": -10.0, "angle":  0.25, "mat": red_mat,  "speed":  0.40 },
		{ "y": 2.2, "z":   8.0, "angle": -0.35, "mat": cyan_mat, "speed": -0.30 },
		{ "y": 1.3, "z":  16.0, "angle":  0.15, "mat": red_mat,  "speed":  0.50 },
		{ "y": 2.5, "z": -18.0, "angle": -0.20, "mat": cyan_mat, "speed": -0.40 }
	]

	for cfg in configs:
		var inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = 52.0
		inst.mesh = cyl
		inst.material_override = cfg["mat"]
		inst.rotation = Vector3(0.0, float(cfg["angle"]), PI * 0.5)
		inst.position = Vector3(0.0, float(cfg["y"]), float(cfg["z"]))
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		_ambient_lasers.append({ "mesh": inst, "base_z": float(cfg["z"]), "speed": float(cfg["speed"]) })


func _build_corner_burger() -> void:
	var burger := Node3D.new()

	var bun_mat := StandardMaterial3D.new()
	bun_mat.albedo_color = Color("#df9b52")
	bun_mat.roughness = 0.6

	var patty_mat := StandardMaterial3D.new()
	patty_mat.albedo_color = Color("#4a2412")
	patty_mat.roughness = 0.85

	var cheese_mat := StandardMaterial3D.new()
	cheese_mat.albedo_color = Color("#ffb800")
	cheese_mat.roughness = 0.4

	var lettuce_mat := StandardMaterial3D.new()
	lettuce_mat.albedo_color = Color("#44bb22")
	lettuce_mat.roughness = 0.7

	var tomato_mat := StandardMaterial3D.new()
	tomato_mat.albedo_color = Color("#dd2211")
	tomato_mat.roughness = 0.3

	var seed_mat := StandardMaterial3D.new()
	seed_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	seed_mat.albedo_color = Color("#fff6df")

	# 1. Bottom bun
	var bottom_bun := MeshInstance3D.new()
	var bb_cyl := CylinderMesh.new()
	bb_cyl.top_radius = 0.75
	bb_cyl.bottom_radius = 0.68
	bb_cyl.height = 0.22
	bottom_bun.mesh = bb_cyl
	bottom_bun.material_override = bun_mat
	bottom_bun.position.y = 0.11
	burger.add_child(bottom_bun)

	# 2. Patty
	var patty := MeshInstance3D.new()
	var p_cyl := CylinderMesh.new()
	p_cyl.top_radius = 0.80
	p_cyl.bottom_radius = 0.80
	p_cyl.height = 0.20
	patty.mesh = p_cyl
	patty.material_override = patty_mat
	patty.position.y = 0.28
	burger.add_child(patty)

	# 3. Cheddar cheese
	var cheese := MeshInstance3D.new()
	var ch_box := BoxMesh.new()
	ch_box.size = Vector3(1.22, 0.05, 1.22)
	cheese.mesh = ch_box
	cheese.material_override = cheese_mat
	cheese.position.y = 0.38
	cheese.rotation.y = PI * 0.25
	burger.add_child(cheese)

	# 4. Lettuce
	var lettuce := MeshInstance3D.new()
	var l_cyl := CylinderMesh.new()
	l_cyl.top_radius = 0.86
	l_cyl.bottom_radius = 0.82
	l_cyl.height = 0.08
	lettuce.mesh = l_cyl
	lettuce.material_override = lettuce_mat
	lettuce.position.y = 0.44
	burger.add_child(lettuce)

	# 5. Tomato slices
	for pos in [Vector3(-0.25, 0.51, 0.15), Vector3(0.28, 0.51, -0.15)]:
		var tom := MeshInstance3D.new()
		var t_cyl := CylinderMesh.new()
		t_cyl.top_radius = 0.42
		t_cyl.bottom_radius = 0.42
		t_cyl.height = 0.07
		tom.mesh = t_cyl
		tom.material_override = tomato_mat
		tom.position = pos
		burger.add_child(tom)

	# 6. Top bun (half dome)
	var top_bun := MeshInstance3D.new()
	var tb_sphere := SphereMesh.new()
	tb_sphere.radius = 0.80
	tb_sphere.height = 0.90
	tb_sphere.is_hemisphere = true
	top_bun.mesh = tb_sphere
	top_bun.material_override = bun_mat
	top_bun.position.y = 0.53
	burger.add_child(top_bun)

	# 7. Sesame seeds
	for i in 18:
		var seed := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 0.03
		s_mesh.height = 0.03
		seed.mesh = s_mesh
		seed.material_override = seed_mat
		seed.scale = Vector3(1.0, 0.4, 1.8)
		var r := 0.18 + randf() * 0.46
		var ang := randf() * TAU
		var sx := cos(ang) * r
		var sz := sin(ang) * r
		var sy := 0.53 + sqrt(maxf(0.0, 0.8 * 0.8 - sx * sx - sz * sz)) * 0.56
		seed.position = Vector3(sx, sy, sz)
		seed.rotation.y = randf() * PI
		burger.add_child(seed)

	# Warm point light
	var burger_light := OmniLight3D.new()
	burger_light.light_color = Color("#ffaa33")
	burger_light.light_energy = 1.0
	burger_light.omni_range = 3.5
	burger_light.position = Vector3(0.0, 0.9, 0.0)
	burger.add_child(burger_light)

	# Much smaller miniature scale tucked quietly in the NE corner
	burger.scale = Vector3(0.36, 0.36, 0.36)
	burger.position = Vector3(22.8, 0.0, -22.8)
	burger.rotation = Vector3(0.0, 0.6, 0.05)
	add_child(burger)

extends Control

var _time: float = 0.0

# Each beam: { y_ratio, angle_base, angle_amp, y_amp, speed, glint_speed, glint_offset }
var _beams := [
	{ "y_ratio": 0.16, "angle_base": -0.22, "angle_amp": 0.06, "y_amp": 45.0, "speed": 0.75, "glint_speed": 0.36, "glint_offset": 0.1 },
	{ "y_ratio": 0.48, "angle_base":  0.19, "angle_amp": 0.06, "y_amp": 55.0, "speed": 0.62, "glint_speed": 0.29, "glint_offset": 0.45 },
	{ "y_ratio": 0.80, "angle_base": -0.04, "angle_amp": 0.08, "y_amp": 45.0, "speed": 0.90, "glint_speed": 0.43, "glint_offset": 0.72 },
	{ "y_ratio": 0.32, "angle_base": -0.02, "angle_amp": 0.08, "y_amp": 60.0, "speed": 0.55, "glint_speed": 0.25, "glint_offset": 0.33 },
	{ "y_ratio": 0.65, "angle_base": -0.38, "angle_amp": 0.07, "y_amp": 50.0, "speed": 0.70, "glint_speed": 0.34, "glint_offset": 0.88 }
]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	# Dark cyber background
	draw_rect(Rect2(Vector2.ZERO, sz), Color("#090a14"))

	# Subtle laser grid
	var grid_col := Color(1.0, 0.0, 0.33, 0.065)
	var step := 50.0
	var x := 0.0
	while x < sz.x:
		draw_line(Vector2(x, 0.0), Vector2(x, sz.y), grid_col, 1.0)
		x += step
	var y := 0.0
	while y < sz.y:
		draw_line(Vector2(0.0, y), Vector2(sz.x, y), grid_col, 1.0)
		y += step

	# Soft cyber atmospheric glows
	draw_circle(Vector2(sz.x * 0.82, sz.y * 0.22), 180.0, Color(1.0, 0.0, 0.33, 0.045))
	draw_circle(Vector2(sz.x * 0.16, sz.y * 0.84), 210.0, Color(0.0, 0.94, 1.0, 0.035))

	# Long bright glowing red laser beams traversing the screen
	var half_len: float = maxf(sz.x, sz.y) * 1.4
	for b in _beams:
		var phase: float = _time * float(b["speed"])
		var cy: float = sz.y * float(b["y_ratio"]) + sin(phase) * float(b["y_amp"])
		var cx: float = sz.x * 0.5
		var angle: float = float(b["angle_base"]) + sin(phase * 0.85) * float(b["angle_amp"])
		var dir := Vector2(cos(angle), sin(angle))
		var center := Vector2(cx, cy)
		var p1 := center - dir * half_len
		var p2 := center + dir * half_len

		var alpha_pulse := 0.78 + 0.22 * sin(phase * 1.4)
		# Multi-layer bloom + white core
		draw_line(p1, p2, Color(1.0, 0.0, 0.2, 0.14 * alpha_pulse), 16.0, true)
		draw_line(p1, p2, Color(1.0, 0.05, 0.33, 0.38 * alpha_pulse), 7.0, true)
		draw_line(p1, p2, Color(1.0, 0.25, 0.5, 0.85 * alpha_pulse), 3.0, true)
		draw_line(p1, p2, Color(1.0, 0.96, 0.98, 0.92 * alpha_pulse), 1.4, true)

		# Traveling bright laser glint along beam
		var glint_t: float = fmod(_time * float(b["glint_speed"]) + float(b["glint_offset"]), 1.0)
		var glint_pos := p1.lerp(p2, glint_t)
		draw_circle(glint_pos, 10.0, Color(1.0, 0.1, 0.4, 0.45))
		draw_circle(glint_pos, 4.5, Color(1.0, 1.0, 1.0, 0.95))

extends CanvasLayer

signal resume_requested
signal leave_game_requested

@onready var hud_root: Control = $HUDRoot
@onready var timer_label: Label = $HUDRoot/TopCenterPanel/TimerLabel
@onready var role_panel: PanelContainer = $HUDRoot/TopLeftRolePanel
@onready var role_label: Label = $HUDRoot/TopLeftRolePanel/RoleLabel
@onready var alive_panel: PanelContainer = $HUDRoot/TopRightBox/AlivePanel
@onready var alive_label: Label = $HUDRoot/TopRightBox/AlivePanel/AliveLabel
@onready var kill_feed_vbox: VBoxContainer = $HUDRoot/TopRightBox/KillFeedVBox

# Bottom-right corner identical ability + stamina controls (0 gradients, angular!)
@onready var bottom_corner_vbox: VBoxContainer = $HUDRoot/BottomRightCorner
@onready var stamina_box: Control = $HUDRoot/BottomRightCorner/StaminaBox
@onready var stamina_fill: ColorRect = $HUDRoot/BottomRightCorner/StaminaBox/StaminaFill
@onready var stamina_label: Label = $HUDRoot/BottomRightCorner/StaminaBox/StaminaLabel

@onready var ability_box: Control = $HUDRoot/BottomRightCorner/AbilityBox
@onready var ability_bg: ColorRect = $HUDRoot/BottomRightCorner/AbilityBox/AbilityBg
@onready var ability_fill: ColorRect = $HUDRoot/BottomRightCorner/AbilityBox/AbilityFill
@onready var ability_border: Panel = $HUDRoot/BottomRightCorner/AbilityBox/AbilityBorder
@onready var ability_label: Label = $HUDRoot/BottomRightCorner/AbilityBox/AbilityLabel

@onready var slowed_panel: PanelContainer = $HUDRoot/SlowedBanner
@onready var spectator_panel: PanelContainer = $HUDRoot/SpectatorBanner

@onready var countdown_overlay: Control = $CountdownOverlay
@onready var countdown_label: Label = $CountdownOverlay/CountdownLabel

@onready var result_overlay: Control = $ResultOverlay
@onready var result_panel: PanelContainer = $ResultOverlay/ResultPanel
@onready var result_title: Label = $ResultOverlay/ResultPanel/ResultVBox/ResultTitle
@onready var result_subtitle: Label = $ResultOverlay/ResultPanel/ResultVBox/ResultSubtitle
@onready var result_stats: Label = $ResultOverlay/ResultPanel/ResultVBox/ResultStats
@onready var result_countdown: Label = $ResultOverlay/ResultPanel/ResultVBox/ResultCountdown

@onready var red_flash: ColorRect = $RedFlash
@onready var pause_overlay: Control = $PauseOverlay
@onready var btn_resume: Button = $PauseOverlay/PausePanel/PauseVBox/BtnResume
@onready var btn_leave_game: Button = $PauseOverlay/PausePanel/PauseVBox/BtnLeaveGame

var _is_killer_role: bool = false
var _rubik_font: Font = null
var _last_countdown: int = -1
var _ability_border_style: StyleBoxFlat = null
var _stamina_border_style: StyleBoxFlat = null


func _ready() -> void:
	_rubik_font = load("res://RubikIso-Regular.ttf")
	_apply_angular_styles()
	hide_all()

	btn_resume.pressed.connect(func(): resume_requested.emit())
	btn_leave_game.pressed.connect(func(): leave_game_requested.emit())


func _apply_angular_styles() -> void:
	if _rubik_font != null:
		timer_label.add_theme_font_override("font", _rubik_font)
		countdown_label.add_theme_font_override("font", _rubik_font)
		result_title.add_theme_font_override("font", _rubik_font)

	# Sharp rectangular StyleBoxes (0px corner radius, 0 gradients!)
	$HUDRoot/TopCenterPanel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.7), Color(0, 0.94, 1, 0.45), 2))
	alive_panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.7), Color(1, 1, 1, 0.35), 2))
	slowed_panel.add_theme_stylebox_override("panel", _box(Color(0.95, 0.85, 0.2, 0.94), Color(1, 1, 1, 1), 2))
	spectator_panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.82), Color(0.5, 0.55, 0.65, 0.7), 2))
	result_panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.12, 0.95), Color("#ff0055"), 3))
	$PauseOverlay/PausePanel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.12, 0.95), Color("#00f0ff"), 2))

	_ability_border_style = _box(Color(0, 0, 0, 0), Color("#ffffff"), 2)
	ability_border.add_theme_stylebox_override("panel", _ability_border_style)

	_stamina_border_style = _box(Color(0, 0, 0, 0), Color("#00ff66"), 2)
	$HUDRoot/BottomRightCorner/StaminaBox/StaminaBorder.add_theme_stylebox_override("panel", _stamina_border_style)

	for btn in [btn_resume, btn_leave_game]:
		var bg := Color("#ff0044") if btn == btn_leave_game else Color("#0a1f33")
		var bdr := Color("#ff3377") if btn == btn_leave_game else Color("#00f0ff")
		btn.add_theme_stylebox_override("normal", _box(bg, bdr, 2))
		btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.15), Color.WHITE, 2))
		btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.2), bdr, 2))


func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func hide_all() -> void:
	hud_root.visible = false
	countdown_overlay.visible = false
	result_overlay.visible = false
	slowed_panel.visible = false
	spectator_panel.visible = false
	red_flash.visible = false
	pause_overlay.visible = false
	_last_countdown = -1


func show_countdown(num: int) -> void:
	countdown_overlay.visible = true
	if num != _last_countdown:
		_last_countdown = num
		countdown_label.text = str(num)
		countdown_label.scale = Vector2(1.8, 1.8)
		countdown_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_countdown() -> void:
	countdown_overlay.visible = false
	_last_countdown = -1


func show_hud(is_killer: bool) -> void:
	_is_killer_role = is_killer
	hud_root.visible = true
	countdown_overlay.visible = false
	result_overlay.visible = false
	slowed_panel.visible = false
	spectator_panel.visible = false
	pause_overlay.visible = false

	# Zero emojis, angular role panel!
	if is_killer:
		role_label.text = "OLAFO KILLER"
		role_label.add_theme_color_override("font_color", Color("#ff2255"))
		role_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.01, 0.03, 0.8), Color("#ff2255"), 2))
		stamina_box.visible = false
		ability_bg.color = Color(0.12, 0.02, 0.03, 0.85)
		ability_fill.color = Color("#ff0044") # Flat solid fill (NO gradient!)
		_ability_border_style.border_color = Color("#ff0044")
	else:
		role_label.text = "PIEROG"
		role_label.add_theme_color_override("font_color", Color("#00f0ff"))
		role_panel.add_theme_stylebox_override("panel", _box(Color(0.01, 0.05, 0.1, 0.8), Color("#00f0ff"), 2))
		stamina_box.visible = true
		ability_bg.color = Color(0.02, 0.08, 0.14, 0.85)
		ability_fill.color = Color("#00f0ff") # Same identical solid bar style for Pieróg!
		_ability_border_style.border_color = Color("#00f0ff")


func update_timer(seconds: float) -> void:
	var secs := ceili(maxf(0.0, seconds))
	timer_label.text = str(secs)
	if secs <= 10:
		timer_label.add_theme_color_override("font_color", Color("#ff2255"))
	else:
		timer_label.add_theme_color_override("font_color", Color.WHITE)


func update_alive_count(alive: int, total: int) -> void:
	alive_label.text = "PIEROGI: %d/%d" % [alive, total]


func update_stamina(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	stamina_fill.anchor_right = f
	stamina_fill.offset_right = 0.0
	# Flat solid fill color (no gradient)
	stamina_fill.color = Color("#ff3333") if f < 0.3 else Color("#00ff66")


func update_ability_cooldown(remaining: float, total: float) -> void:
	var prefix := "PISTOLET [LPM / F]" if _is_killer_role else "TWAROG [E]"
	if remaining <= 0.0:
		ability_label.text = "%s: GOTOWY" % prefix
		ability_fill.anchor_right = 1.0
		ability_fill.offset_right = 0.0
		_ability_border_style.border_color = Color("#ffea00") if not _is_killer_role else Color("#ff4466")
		ability_fill.color = Color("#00f0ff") if not _is_killer_role else Color("#ff0044")
	else:
		ability_label.text = "%s: %.1fs" % [prefix, remaining]
		var pct := clampf((total - remaining) / total, 0.0, 1.0)
		ability_fill.anchor_right = pct
		ability_fill.offset_right = 0.0
		_ability_border_style.border_color = Color(0.55, 0.6, 0.7)
		ability_fill.color = Color(0.0, 0.45, 0.55) if not _is_killer_role else Color(0.55, 0.08, 0.18)


func show_slowed_banner(show_flag: bool) -> void:
	slowed_panel.visible = show_flag


func show_spectator(show_flag: bool) -> void:
	spectator_panel.visible = show_flag
	if show_flag:
		stamina_box.visible = false
		ability_box.visible = false
	else:
		ability_box.visible = true


func set_pause_visible(show_flag: bool) -> void:
	pause_overlay.visible = show_flag


func add_kill_feed(killer_name: String, victim_name: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.78), Color("#ff0055"), 2))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	var k_lbl := Label.new()
	k_lbl.text = killer_name
	k_lbl.add_theme_color_override("font_color", Color("#ff2255"))
	k_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(k_lbl)

	var sep := Label.new()
	sep.text = "->"
	sep.add_theme_color_override("font_color", Color.WHITE)
	sep.add_theme_font_size_override("font_size", 13)
	hbox.add_child(sep)

	var v_lbl := Label.new()
	v_lbl.text = victim_name
	v_lbl.add_theme_color_override("font_color", Color("#00f0ff"))
	v_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(v_lbl)

	kill_feed_vbox.add_child(panel)

	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)


func trigger_red_flash() -> void:
	red_flash.visible = true
	red_flash.color = Color(1.0, 0.0, 0.1, 0.55)
	var tw := create_tween()
	tw.tween_property(red_flash, "color:a", 0.0, 0.4)
	tw.tween_callback(func(): red_flash.visible = false)


func show_results(title_txt: String, subtitle_txt: String, stats_txt: String, title_col: Color, countdown_secs: float) -> void:
	result_overlay.visible = true
	result_title.text = title_txt
	result_title.add_theme_color_override("font_color", title_col)
	result_subtitle.text = subtitle_txt
	result_stats.text = stats_txt
	update_result_countdown(countdown_secs)


func update_result_countdown(remaining: float) -> void:
	result_countdown.text = "Powrót do lobby za %ds..." % ceili(maxf(0.0, remaining))

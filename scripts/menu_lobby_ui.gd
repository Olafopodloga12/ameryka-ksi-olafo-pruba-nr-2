extends Control

signal create_lobby_requested(nickname: String)
signal join_lobby_requested(code: String, nickname: String)
signal start_round_requested
signal leave_lobby_requested

@onready var menu_panel: VBoxContainer = $MainLayout/LeftColumn/MenuSection
@onready var lobby_panel: VBoxContainer = $MainLayout/LeftColumn/LobbySection
@onready var title_label_killer: Label = $MainLayout/LeftColumn/TitleBox/TitleKiller
@onready var title_label_vs: Label = $MainLayout/LeftColumn/TitleBox/TitleVs
@onready var title_label_pierogi: Label = $MainLayout/LeftColumn/TitleBox/TitlePierogi

@onready var nickname_input: LineEdit = $MainLayout/LeftColumn/MenuSection/NicknameInput
@onready var btn_create: Button = $MainLayout/LeftColumn/MenuSection/ButtonsRow/BtnCreate
@onready var btn_join_show: Button = $MainLayout/LeftColumn/MenuSection/ButtonsRow/BtnJoinShow
@onready var join_section: HBoxContainer = $MainLayout/LeftColumn/MenuSection/JoinSection
@onready var room_code_input: LineEdit = $MainLayout/LeftColumn/MenuSection/JoinSection/RoomCodeInput
@onready var btn_join: Button = $MainLayout/LeftColumn/MenuSection/JoinSection/BtnJoin
@onready var menu_error: Label = $MainLayout/LeftColumn/MenuSection/MenuError
@onready var menu_status: Label = $MainLayout/LeftColumn/MenuSection/MenuStatus

@onready var lobby_title: Label = $MainLayout/LeftColumn/LobbySection/LobbyTitle
@onready var room_code_btn: Button = $MainLayout/LeftColumn/LobbySection/RoomCodeRow/BtnRoomCode
@onready var player_count_label: Label = $MainLayout/LeftColumn/LobbySection/PlayerListTitle
@onready var player_list_vbox: VBoxContainer = $MainLayout/LeftColumn/LobbySection/PlayerListScroll/PlayerListVBox
@onready var btn_start: Button = $MainLayout/LeftColumn/LobbySection/BtnStart
@onready var lobby_status: Label = $MainLayout/LeftColumn/LobbySection/LobbyStatus
@onready var btn_leave: Button = $MainLayout/LeftColumn/LobbySection/BtnLeave

@onready var olafo_sprite: TextureRect = $MainLayout/RightColumn/OlafoContainer/OlafoIdleTexture

var _idle_time: float = 0.0
var _current_room_code: String = ""
var _copy_reset_timer: float = 0.0
var _rubik_font: Font = null


func _ready() -> void:
	_rubik_font = load("res://RubikIso-Regular.ttf")
	_apply_angular_laser_styles()

	nickname_input.text = "Gracz%d" % randi_range(100, 999)
	join_section.visible = false
	menu_error.visible = false
	menu_status.visible = false

	btn_create.pressed.connect(_on_create_pressed)
	btn_join_show.pressed.connect(_on_join_show_pressed)
	btn_join.pressed.connect(_on_join_pressed)
	btn_start.pressed.connect(func(): start_round_requested.emit())
	btn_leave.pressed.connect(func(): leave_lobby_requested.emit())
	room_code_btn.pressed.connect(_on_room_code_pressed)

	nickname_input.text_submitted.connect(_on_nickname_submitted)
	room_code_input.text_submitted.connect(func(_t): _on_join_pressed())

	show_menu()


func _process(delta: float) -> void:
	_idle_time += delta
	# Gentle vertical idle bobbing for Olafo on bottom-right (no red aura!)
	if olafo_sprite != null:
		var bob := sin(_idle_time * 2.5) * 14.0
		var s := 1.0 + 0.015 * sin(_idle_time * 2.5)
		olafo_sprite.position.y = bob
		olafo_sprite.scale = Vector2(s, s)

	if _copy_reset_timer > 0.0:
		_copy_reset_timer -= delta
		if _copy_reset_timer <= 0.0 and not _current_room_code.is_empty():
			room_code_btn.text = _current_room_code


func _apply_angular_laser_styles() -> void:
	# Apply RubikIso font to main headings
	if _rubik_font != null:
		title_label_killer.add_theme_font_override("font", _rubik_font)
		title_label_vs.add_theme_font_override("font", _rubik_font)
		title_label_pierogi.add_theme_font_override("font", _rubik_font)
		lobby_title.add_theme_font_override("font", _rubik_font)

	# Sharp 0px StyleBox helper
	var input_normal := _make_box(Color(0.0, 0.04, 0.1, 0.8), Color("#00f0ff"), 2)
	var input_focus := _make_box(Color(0.06, 0.02, 0.08, 0.9), Color("#ff0055"), 2)
	for le in [nickname_input, room_code_input]:
		le.add_theme_stylebox_override("normal", input_normal)
		le.add_theme_stylebox_override("focus", input_focus)

	_style_button(btn_create, Color("#ff0044"), Color("#ff3377"), Color.WHITE)
	_style_button(btn_join, Color("#ff0044"), Color("#ff3377"), Color.WHITE)
	_style_button(btn_start, Color("#ff0044"), Color("#ff3377"), Color.WHITE)
	_style_button(btn_join_show, Color("#0a1f33"), Color("#00f0ff"), Color("#00f0ff"))
	_style_button(btn_leave, Color("#2a111a"), Color("#661122"), Color("#ff88aa"))
	_style_button(room_code_btn, Color(1.0, 0.0, 0.33, 0.15), Color("#ff0055"), Color("#ff0044"))


func _make_box(bg: Color, border: Color, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _style_button(btn: Button, bg: Color, border: Color, text_col: Color) -> void:
	var normal := _make_box(bg, border, 2)
	var hover := _make_box(bg.lightened(0.15), border.lightened(0.2), 2)
	var pressed := _make_box(bg.darkened(0.2), border, 2)
	var disabled := _make_box(Color(0.15, 0.15, 0.2, 0.7), Color(0.3, 0.3, 0.35), 2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", text_col)


func show_menu() -> void:
	visible = true
	menu_panel.visible = true
	lobby_panel.visible = false
	$MainLayout/LeftColumn/TitleBox.visible = true


func show_lobby(code: String) -> void:
	visible = true
	menu_panel.visible = false
	lobby_panel.visible = true
	$MainLayout/LeftColumn/TitleBox.visible = false
	_current_room_code = code
	room_code_btn.text = code


func hide_ui() -> void:
	visible = false


func set_menu_busy(busy: bool, status_msg: String = "") -> void:
	btn_create.disabled = busy
	btn_join.disabled = busy
	if status_msg.is_empty():
		menu_status.visible = false
	else:
		menu_status.text = status_msg
		menu_status.visible = true


func show_menu_error(msg: String) -> void:
	menu_error.text = msg
	menu_error.visible = true
	menu_status.visible = false


func clear_menu_error() -> void:
	menu_error.visible = false


func update_lobby_players(players_arr: Array, host_id: int, local_is_host: bool) -> void:
	player_count_label.text = "GRACZE (%d)" % players_arr.size()
	for child in player_list_vbox.get_children():
		child.queue_free()

	for p in players_arr:
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.06, 0.12, 0.72)
		sb.border_color = Color(0.0, 0.94, 1.0, 0.35)
		sb.set_border_width_all(1)
		sb.border_width_left = 4
		sb.border_color = Color("#00f0ff")
		sb.set_corner_radius_all(0)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		row.add_child(hbox)

		var name_lbl := Label.new()
		name_lbl.text = str(p["name"])
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(name_lbl)

		if int(p["id"]) == host_id:
			var badge := Label.new()
			badge.text = "HOST"
			badge.add_theme_font_size_override("font_size", 12)
			badge.add_theme_color_override("font_color", Color.WHITE)
			var b_sb := StyleBoxFlat.new()
			b_sb.bg_color = Color("#ff0055")
			b_sb.set_corner_radius_all(0)
			b_sb.content_margin_left = 6
			b_sb.content_margin_right = 6
			b_sb.content_margin_top = 2
			b_sb.content_margin_bottom = 2
			badge.add_theme_stylebox_override("normal", b_sb)
			hbox.add_child(badge)

		player_list_vbox.add_child(row)

	btn_start.visible = local_is_host
	if local_is_host:
		lobby_status.text = "MOŻESZ ROZPOCZĄĆ RUNDĘ!"
	else:
		lobby_status.text = "CZEKAM NA ROZPOCZĘCIE RUNDY PRZEZ HOSTA..."


func _get_nickname() -> String:
	var n := nickname_input.text.strip_edges()
	if n.is_empty():
		n = "Gracz%d" % randi_range(100, 999)
		nickname_input.text = n
	return n


func _on_create_pressed() -> void:
	clear_menu_error()
	create_lobby_requested.emit(_get_nickname())


func _on_join_show_pressed() -> void:
	join_section.visible = not join_section.visible
	if join_section.visible:
		room_code_input.grab_focus()


func _on_join_pressed() -> void:
	clear_menu_error()
	var code := room_code_input.text.strip_edges()
	if code.length() < 4:
		show_menu_error("Wpisz poprawny 6-znakowy kod pokoju lub IP!")
		return
	join_lobby_requested.emit(code, _get_nickname())


func _on_nickname_submitted(_text: String) -> void:
	if join_section.visible:
		room_code_input.grab_focus()
	else:
		_on_create_pressed()


func _on_room_code_pressed() -> void:
	if not _current_room_code.is_empty():
		DisplayServer.clipboard_set(_current_room_code)
		room_code_btn.text = "SKOPIOWANO!"
		_copy_reset_timer = 1.2

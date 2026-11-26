extends Node3D

enum GameState { MENU, LOBBY, COUNTDOWN, PLAYING, RESULTS }

const KILL_DISTANCE := 1.6
const ROUND_TIME := 60.0
const COUNTDOWN_TIME := 3.0
const RESULT_TIME := 5.0
const TWAROG_COOLDOWN_TIME := 5.0
const GUN_COOLDOWN_TIME := 4.0
const NET_TICK_INTERVAL := 0.05 # 20 Hz

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const TWAROG_SCENE := preload("res://scenes/twarog_puddle.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")

var state: GameState = GameState.MENU
var players: Dictionary = {} # peer_id: int -> Player node
var local_player = null
var my_role: String = "pierog" # "killer" or "pierog"
var killer_id: int = 1

var round_timer: float = ROUND_TIME
var countdown_timer: float = COUNTDOWN_TIME
var result_timer: float = RESULT_TIME
var total_pierogi: int = 0
var alive_pierogi: int = 0

var twarog_cooldown: float = 0.0
var gun_cooldown: float = 0.0
var _net_tick_timer: float = 0.0

var is_spectating: bool = false
var _spectator_yaw: float = 0.0
var _spectator_pitch: float = -0.55
var _spectator_pos: Vector3 = Vector3(0.0, 10.0, 0.0)
var _is_paused: bool = false

var _twarog_puddles: Array = []

@onready var arena: Node3D = $Arena
@onready var camera: Camera3D = $Camera3D
@onready var player_light: OmniLight3D = $PlayerLight
@onready var players_container: Node3D = $PlayersContainer
@onready var fx_container: Node3D = $WorldFXContainer
@onready var menu_ui: Control = $MenuLayer/MenuLobbyUI
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	randomize()
	_setup_input_map()

	menu_ui.create_lobby_requested.connect(_on_create_lobby_requested)
	menu_ui.join_lobby_requested.connect(_on_join_lobby_requested)
	menu_ui.start_round_requested.connect(_on_start_round_requested)
	menu_ui.leave_lobby_requested.connect(_on_leave_lobby_requested)

	hud.resume_requested.connect(_on_resume_requested)
	hud.leave_game_requested.connect(_on_leave_game_requested)

	NetworkManager.lobby_created.connect(_on_lobby_created)
	NetworkManager.lobby_joined.connect(_on_lobby_joined)
	NetworkManager.lobby_join_failed.connect(_on_lobby_join_failed)
	NetworkManager.player_list_updated.connect(_on_player_list_updated)
	NetworkManager.disconnected_from_host.connect(_on_disconnected_from_host)
	NetworkManager.peer_left_game.connect(_on_peer_left_game)

	menu_ui.show_menu()
	hud.hide_all()


func _setup_input_map() -> void:
	_ensure_action("move_forward", [KEY_W, KEY_UP])
	_ensure_action("move_back", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("sprint", [KEY_SHIFT])
	_ensure_action("ability_twarog", [KEY_E])
	_ensure_action("shoot_gun", [KEY_F, KEY_SPACE])


func _ensure_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(action_name, ev):
			InputMap.action_add_event(action_name, ev)


func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.PLAYING:
		return

	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return

	if _is_paused:
		return

	# Mouse motion for Killer TPP or Spectator free cam
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_spectating:
			_spectator_yaw -= event.relative.x * 0.003
			_spectator_pitch -= event.relative.y * 0.003
			_spectator_pitch = clampf(_spectator_pitch, -1.35, 1.35)
		elif my_role == "killer" and is_instance_valid(local_player) and local_player.alive:
			local_player.handle_mouse_motion(event.relative)

	# Left click captures mouse (if freed) or shoots gun for Killer
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if (my_role == "killer" or is_spectating) and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if my_role == "killer" and not is_spectating:
				_try_shoot_gun()
		elif my_role == "killer" and not is_spectating:
			_try_shoot_gun()

	# Keyboard gun fire [F / Space]
	if event.is_action_pressed("shoot_gun") and my_role == "killer" and not is_spectating:
		_try_shoot_gun()

	# Keyboard Twarog spawn [E]
	if event.is_action_pressed("ability_twarog") and my_role == "pierog" and not is_spectating:
		_try_spawn_twarog()


func _process(delta: float) -> void:
	match state:
		GameState.MENU, GameState.LOBBY:
			# Subtle overview camera drift behind background menu
			var t := Time.get_ticks_msec() * 0.00025
			camera.global_position = Vector3(sin(t) * 16.0, 14.0, cos(t) * 16.0)
			camera.look_at(Vector3.ZERO, Vector3.UP)
		GameState.COUNTDOWN:
			_update_countdown(delta)
			_update_active_camera(delta)
		GameState.PLAYING:
			_update_playing(delta)
			_update_active_camera(delta)
		GameState.RESULTS:
			_update_results(delta)
			_update_active_camera(delta)


# === MENU & LOBBY FLOW ===

func _on_create_lobby_requested(nickname: String) -> void:
	menu_ui.set_menu_busy(true, "TWORZENIE LOBBY...")
	NetworkManager.create_lobby(nickname)


func _on_join_lobby_requested(code: String, nickname: String) -> void:
	menu_ui.set_menu_busy(true, "SZUKANIE POKOJU %s..." % code.to_upper())
	NetworkManager.join_lobby(code, nickname)


func _on_lobby_created(code: String) -> void:
	state = GameState.LOBBY
	menu_ui.set_menu_busy(false)
	menu_ui.show_lobby(code)


func _on_lobby_joined(code: String) -> void:
	state = GameState.LOBBY
	menu_ui.set_menu_busy(false)
	menu_ui.show_lobby(code)


func _on_lobby_join_failed(reason: String) -> void:
	menu_ui.set_menu_busy(false)
	menu_ui.show_menu_error(reason)


func _on_player_list_updated(players_arr: Array, host_id: int) -> void:
	menu_ui.update_lobby_players(players_arr, host_id, NetworkManager.is_host)


func _on_disconnected_from_host(reason: String) -> void:
	_cleanup_game()
	state = GameState.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide_all()
	menu_ui.set_menu_busy(false)
	menu_ui.show_menu()
	if not reason.is_empty():
		menu_ui.show_menu_error(reason)


func _on_leave_lobby_requested() -> void:
	_cleanup_game()
	NetworkManager.disconnect_lobby(false)
	state = GameState.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide_all()
	menu_ui.show_menu()


func _on_leave_game_requested() -> void:
	_on_leave_lobby_requested()


func _on_resume_requested() -> void:
	_is_paused = false
	hud.set_pause_visible(false)
	if state == GameState.PLAYING and (my_role == "killer" or is_spectating):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle_pause() -> void:
	_is_paused = not _is_paused
	hud.set_pause_visible(_is_paused)
	if _is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif my_role == "killer" or is_spectating:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_peer_left_game(peer_id: int) -> void:
	if state == GameState.PLAYING or state == GameState.COUNTDOWN:
		if players.has(peer_id):
			var p = players[peer_id]
			var was_alive_pierog: bool = is_instance_valid(p) and (not p.is_killer) and bool(p.alive)
			if is_instance_valid(p):
				p.queue_free()
			players.erase(peer_id)
			if was_alive_pierog:
				alive_pierogi = maxi(0, alive_pierogi - 1)
				hud.update_alive_count(alive_pierogi, total_pierogi)
				if NetworkManager.is_host and total_pierogi > 0 and alive_pierogi <= 0:
					_end_round("killer")


# === ROUND LIFECYCLE ===

func _on_start_round_requested() -> void:
	if not NetworkManager.is_host:
		return

	var plist := NetworkManager.get_player_list()
	if plist.is_empty():
		return

	var killer_idx := randi() % plist.size()
	var picked_killer_id := int(plist[killer_idx]["id"])
	var spawns: Array[Vector3] = arena.get_randomized_spawns(plist.size())

	var assignments: Array = []
	for i in plist.size():
		var info: Dictionary = plist[i]
		assignments.append({
			"id": int(info["id"]),
			"name": str(info["name"]),
			"is_killer": int(info["id"]) == picked_killer_id,
			"spawn": spawns[i]
		})

	_rpc_start_countdown.rpc(assignments, picked_killer_id)


@rpc("authority", "call_local", "reliable")
func _rpc_start_countdown(assignments: Array, picked_killer_id: int) -> void:
	_cleanup_game()
	state = GameState.COUNTDOWN
	countdown_timer = COUNTDOWN_TIME
	killer_id = picked_killer_id
	_is_paused = false

	menu_ui.hide_ui()
	hud.hide_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	total_pierogi = 0
	for a in assignments:
		var pid := int(a["id"])
		var is_local := (pid == NetworkManager.my_id)
		var is_k := bool(a["is_killer"])

		var p = PLAYER_SCENE.instantiate()
		p.setup(pid, str(a["name"]), is_k, is_local, camera)
		players_container.add_child(p)
		p.set_spawn_position(a["spawn"])
		players[pid] = p

		if is_local:
			local_player = p
			my_role = "killer" if is_k else "pierog"

		if not is_k:
			total_pierogi += 1

	alive_pierogi = total_pierogi
	hud.show_countdown(3)


func _update_countdown(delta: float) -> void:
	countdown_timer -= delta
	var num := ceili(countdown_timer)
	if num > 0:
		hud.show_countdown(num)

	if NetworkManager.is_host and countdown_timer <= 0.0:
		_rpc_start_round.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_start_round() -> void:
	state = GameState.PLAYING
	round_timer = ROUND_TIME
	twarog_cooldown = 0.0
	gun_cooldown = 0.0
	is_spectating = false
	_is_paused = false

	hud.hide_countdown()
	hud.show_hud(my_role == "killer")
	hud.update_timer(round_timer)
	hud.update_alive_count(alive_pierogi, total_pierogi)

	if my_role == "killer":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _update_playing(delta: float) -> void:
	# 1. Update players
	for pid in players.keys():
		var p = players[pid]
		if not is_instance_valid(p):
			continue
		if p.is_local:
			p.update_player(delta, not _is_paused)
			if my_role == "pierog" and p.alive:
				hud.update_stamina(p.stamina)
		else:
			p.update_player(delta, false)

	# 2. Update cooldowns & HUD ability bar
	if twarog_cooldown > 0.0:
		twarog_cooldown = maxf(0.0, twarog_cooldown - delta)
	if gun_cooldown > 0.0:
		gun_cooldown = maxf(0.0, gun_cooldown - delta)

	if my_role == "killer":
		hud.update_ability_cooldown(gun_cooldown, GUN_COOLDOWN_TIME)
	else:
		hud.update_ability_cooldown(twarog_cooldown, TWAROG_COOLDOWN_TIME)

	# 3. Check Twaróg puddle slowdown on Killer
	_update_twarog_slowdown()

	# 4. Dynamic player light
	if is_instance_valid(local_player) and local_player.alive:
		player_light.global_position = Vector3(local_player.global_position.x, 2.5, local_player.global_position.z)

	# 5. Spectator free-fly camera movement
	if is_spectating and not _is_paused:
		_update_spectator_movement(delta)

	# 6. Network tick (20 Hz)
	_net_tick_timer += delta
	if _net_tick_timer >= NET_TICK_INTERVAL:
		_net_tick_timer = 0.0
		if NetworkManager.is_host:
			_host_check_melee_kills()
			_host_broadcast_state()
		elif is_instance_valid(local_player) and local_player.alive:
			_rpc_client_position.rpc_id(1, local_player.global_position)

	# 7. Authoritative round timer
	if NetworkManager.is_host:
		round_timer -= delta
		hud.update_timer(round_timer)
		if round_timer <= 0.0:
			_end_round("pierogi" if total_pierogi > 0 else "sandbox")
	else:
		round_timer = maxf(0.0, round_timer - delta)
		hud.update_timer(round_timer)


func _update_active_camera(delta: float) -> void:
	if is_spectating:
		var look_basis := Basis(Vector3.UP, _spectator_yaw) * Basis(Vector3.RIGHT, _spectator_pitch)
		var look_dir := (look_basis * Vector3(0.0, 0.0, -1.0)).normalized()
		camera.global_position = _spectator_pos
		camera.look_at(_spectator_pos + look_dir * 10.0, Vector3.UP)
	elif is_instance_valid(local_player):
		local_player.update_local_camera(delta, camera)


func _update_spectator_movement(delta: float) -> void:
	var spd := 14.0
	var look_basis := Basis(Vector3.UP, _spectator_yaw) * Basis(Vector3.RIGHT, _spectator_pitch)
	var fwd := (look_basis * Vector3(0.0, 0.0, -1.0)).normalized()
	var right := Vector3(fwd.x, 0.0, fwd.z).normalized().cross(Vector3.UP).normalized()

	var move := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		move += fwd
	if Input.is_action_pressed("move_back"):
		move -= fwd
	if Input.is_action_pressed("move_right"):
		move += right
	if Input.is_action_pressed("move_left"):
		move -= right
	if Input.is_key_pressed(KEY_SPACE):
		move.y += 1.0
	if Input.is_key_pressed(KEY_SHIFT):
		move.y -= 1.0

	if move.length() > 0.001:
		_spectator_pos += move.normalized() * spd * delta
		_spectator_pos.x = clampf(_spectator_pos.x, -30.0, 30.0)
		_spectator_pos.z = clampf(_spectator_pos.z, -30.0, 30.0)
		_spectator_pos.y = clampf(_spectator_pos.y, 1.5, 25.0)


# === ABILITIES: GUN [LPM/F/SPACE] & TWAROG [E] ===

func _try_shoot_gun() -> void:
	if gun_cooldown > 0.0 or not is_instance_valid(local_player) or not local_player.alive:
		return

	var shoot_dir: Vector3 = local_player.get_flat_shoot_direction()
	var start_pos: Vector3 = local_player.global_position + Vector3(0.0, 1.15, 0.0) + shoot_dir * 0.9
	var b_id := "b_%d_%d" % [NetworkManager.my_id, Time.get_ticks_msec()]
	gun_cooldown = GUN_COOLDOWN_TIME

	_rpc_fire_gun.rpc(b_id, start_pos, shoot_dir)


@rpc("any_peer", "call_local", "reliable")
func _rpc_fire_gun(b_id: String, start_pos: Vector3, dir: Vector3) -> void:
	if state != GameState.PLAYING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = NetworkManager.my_id
	if sender != killer_id:
		return

	if players.has(killer_id):
		var kp = players[killer_id]
		if is_instance_valid(kp):
			kp.trigger_gun_shot(dir)

	var bullet = BULLET_SCENE.instantiate()
	bullet.setup(b_id, start_pos, dir, 36.0, killer_id, NetworkManager.is_host, players)
	if NetworkManager.is_host:
		bullet.hit_pierog.connect(_on_bullet_hit_pierog)
	fx_container.add_child(bullet)


func _on_bullet_hit_pierog(_bullet_id: String, victim_id: int) -> void:
	if not NetworkManager.is_host or state != GameState.PLAYING:
		return
	if players.has(victim_id):
		var victim = players[victim_id]
		if is_instance_valid(victim) and victim.alive:
			var k_name := str(players[killer_id].player_name) if players.has(killer_id) else "Olafo Killer"
			_rpc_player_killed.rpc(victim_id, k_name, victim.player_name)


func _try_spawn_twarog() -> void:
	if twarog_cooldown > 0.0 or not is_instance_valid(local_player) or not local_player.alive:
		return
	twarog_cooldown = TWAROG_COOLDOWN_TIME
	var pid := "tw_%d_%d" % [NetworkManager.my_id, Time.get_ticks_msec()]
	_rpc_spawn_twarog.rpc(pid, local_player.global_position)


@rpc("any_peer", "call_local", "reliable")
func _rpc_spawn_twarog(pid: String, pos: Vector3) -> void:
	if state != GameState.PLAYING:
		return
	var puddle = TWAROG_SCENE.instantiate()
	puddle.setup(pid, 2.4, 12.0)
	puddle.position = Vector3(pos.x, 0.03, pos.z)
	fx_container.add_child(puddle)
	_twarog_puddles.append(puddle)


func _update_twarog_slowdown() -> void:
	# Clean freed puddle refs
	_twarog_puddles = _twarog_puddles.filter(func(p): return is_instance_valid(p))

	if not players.has(killer_id):
		return
	var killer = players[killer_id]
	if not is_instance_valid(killer) or not killer.alive:
		if my_role == "killer":
			hud.show_slowed_banner(false)
		return

	var slowed := false
	for p in _twarog_puddles:
		if p.contains_xz(killer.global_position):
			slowed = true
			break

	killer.is_slowed = slowed
	if my_role == "killer":
		hud.show_slowed_banner(slowed)


# === NETWORK SYNC & KILLS ===

@rpc("any_peer", "unreliable_ordered")
func _rpc_client_position(pos: Vector3) -> void:
	if not NetworkManager.is_host or state != GameState.PLAYING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender):
		var p = players[sender]
		if is_instance_valid(p) and p.alive:
			p.set_remote_target(pos)
			p.global_position = pos


func _host_check_melee_kills() -> void:
	if not players.has(killer_id):
		return
	var killer = players[killer_id]
	if not is_instance_valid(killer) or not killer.alive:
		return

	for pid in players.keys():
		if int(pid) == killer_id:
			continue
		var p = players[pid]
		if is_instance_valid(p) and p.alive:
			var dist := Vector2(killer.global_position.x - p.global_position.x, killer.global_position.z - p.global_position.z).length()
			if dist < KILL_DISTANCE:
				_rpc_player_killed.rpc(int(pid), killer.player_name, p.player_name)


func _host_broadcast_state() -> void:
	var pstates: Dictionary = {}
	for pid in players.keys():
		var p = players[pid]
		if is_instance_valid(p):
			pstates[int(pid)] = {
				"pos": p.global_position,
				"alive": p.alive
			}
	_rpc_apply_game_state.rpc(pstates, round_timer, alive_pierogi)


@rpc("authority", "unreliable_ordered")
func _rpc_apply_game_state(pstates: Dictionary, srv_timer: float, srv_alive: int) -> void:
	if NetworkManager.is_host or state != GameState.PLAYING:
		return
	for pid in pstates.keys():
		var st: Dictionary = pstates[pid]
		if players.has(int(pid)):
			var p = players[int(pid)]
			if is_instance_valid(p):
				if not p.is_local:
					p.set_remote_target(st["pos"])
				if not bool(st["alive"]) and p.alive:
					p.kill_player()

	round_timer = srv_timer
	alive_pierogi = srv_alive
	hud.update_timer(round_timer)
	hud.update_alive_count(alive_pierogi, total_pierogi)


@rpc("authority", "call_local", "reliable")
func _rpc_player_killed(victim_id: int, killer_name: String, victim_name: String) -> void:
	if players.has(victim_id):
		var v = players[victim_id]
		if is_instance_valid(v) and v.alive:
			v.kill_player()

	hud.add_kill_feed(killer_name, victim_name)

	if victim_id == NetworkManager.my_id and not is_spectating:
		hud.trigger_red_flash()
		is_spectating = true
		hud.show_spectator(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if is_instance_valid(local_player):
			_spectator_pos = local_player.global_position + Vector3(0.0, 8.0, 0.0)
			_spectator_yaw = 0.0
			_spectator_pitch = -0.55

	alive_pierogi = 0
	for pid in players.keys():
		if int(pid) != killer_id and is_instance_valid(players[pid]) and players[pid].alive:
			alive_pierogi += 1
	hud.update_alive_count(alive_pierogi, total_pierogi)

	if NetworkManager.is_host and state == GameState.PLAYING and total_pierogi > 0 and alive_pierogi <= 0:
		_end_round("killer")


func _end_round(winner: String) -> void:
	if state != GameState.PLAYING:
		return
	var elapsed := ROUND_TIME - maxf(0.0, round_timer)
	_rpc_round_end.rpc(winner, elapsed, alive_pierogi, total_pierogi)


@rpc("authority", "call_local", "reliable")
func _rpc_round_end(winner: String, elapsed: float, srv_alive: int, srv_total: int) -> void:
	if state == GameState.RESULTS:
		return
	state = GameState.RESULTS
	result_timer = RESULT_TIME
	_is_paused = false
	hud.set_pause_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var title := ""
	var sub := ""
	var col := Color.WHITE
	if winner == "killer":
		title = "OLAFO KILLER WYGRYWA!"
		sub = "Wszystkie pierogi zostały wyeliminowane!"
		col = Color("#ff2255")
	elif winner == "pierogi":
		title = "PIEROGI WYGRYWAJĄ!"
		sub = "Pierogi przetrwały cały czas!"
		col = Color("#00f0ff")
	else:
		title = "KONIEC RUNDY TESTOWEJ"
		sub = "Powrót do lobby — zaproś znajomego kodem pokoju!"
		col = Color("#ffea00")

	var stats := "Czas rundy: %ds\nPierogi, które przeżyły: %d/%d" % [int(elapsed), srv_alive, srv_total]
	hud.show_results(title, sub, stats, col, result_timer)


func _update_results(delta: float) -> void:
	result_timer -= delta
	hud.update_result_countdown(result_timer)
	if result_timer <= 0.0:
		_cleanup_game()
		hud.hide_all()
		state = GameState.LOBBY
		menu_ui.show_lobby(NetworkManager.room_code)
		menu_ui.update_lobby_players(NetworkManager.get_player_list(), 1, NetworkManager.is_host)


func _cleanup_game() -> void:
	for pid in players.keys():
		if is_instance_valid(players[pid]):
			players[pid].queue_free()
	players.clear()
	local_player = null
	is_spectating = false
	_is_paused = false

	for child in fx_container.get_children():
		child.queue_free()
	_twarog_puddles.clear()

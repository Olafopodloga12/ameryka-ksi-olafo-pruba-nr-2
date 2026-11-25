extends Node

signal lobby_created(room_code: String)
signal lobby_joined(room_code: String)
signal lobby_join_failed(reason: String)
signal player_list_updated(players: Array, host_id: int)
signal disconnected_from_host(reason: String)
signal peer_left_game(peer_id: int)

const GAME_PORT_BASE := 7777
const GAME_PORT_MAX := 7790
const DISCOVERY_PORT_BASE := 7776
const DISCOVERY_PORT_MAX := 7785
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var is_host: bool = false
var room_code: String = ""
var my_name: String = "Gracz"
var my_id: int = 1
var game_port: int = GAME_PORT_BASE
var players: Dictionary = {} # peer_id: int -> { "id": int, "name": String }

var _discovery_server: UDPServer = null
var _discovery_client: PacketPeerUDP = null
var _searching: bool = false
var _search_elapsed: float = 0.0
var _search_retry_timer: float = 0.0
var _target_code: String = ""
var _joined_emitted: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	# Host: respond to LAN / localhost room code discovery pings
	if is_host and _discovery_server != null:
		_discovery_server.poll()
		while _discovery_server.is_connection_available():
			var peer: PacketPeerUDP = _discovery_server.take_connection()
			var packet: PackedByteArray = peer.get_packet()
			var msg := packet.get_string_from_utf8().strip_edges()
			if msg == "OLAFO_FIND:" + room_code:
				var reply := ("OLAFO_FOUND:%s:%d" % [room_code, game_port]).to_utf8_buffer()
				peer.put_packet(reply)

	# Client: poll for host discovery response
	if _searching and _discovery_client != null:
		_search_elapsed += delta
		_search_retry_timer += delta

		while _discovery_client.get_available_packet_count() > 0:
			var pkt := _discovery_client.get_packet()
			var sender_ip := _discovery_client.get_packet_ip()
			var msg := pkt.get_string_from_utf8().strip_edges()
			if msg.begins_with("OLAFO_FOUND:"):
				var parts := msg.split(":")
				if parts.size() >= 3 and parts[1] == _target_code:
					var found_port := int(parts[2])
					_stop_discovery_client()
					var connect_ip := sender_ip if not sender_ip.is_empty() else "127.0.0.1"
					_connect_enet_client(connect_ip, found_port)
					return

		if _search_elapsed >= 4.5:
			var missed := _target_code
			_stop_discovery_client()
			lobby_join_failed.emit("Nie znaleziono pokoju o kodzie: %s (w razie potrzeby wpisz IP:PORT)" % missed)
			return

		if _search_retry_timer >= 0.35:
			_search_retry_timer = 0.0
			_broadcast_find_packet(_target_code)


func _generate_code() -> String:
	var code := ""
	for i in 6:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	return code


func create_lobby(nickname: String) -> void:
	disconnect_lobby(false)
	my_name = nickname.strip_edges()
	if my_name.is_empty():
		my_name = "Gracz" + str(randi_range(100, 999))

	if OS.has_feature("web"):
		# Single-browser offline/local fallback if run in Web export without signaling relay
		room_code = _generate_code()
		is_host = true
		my_id = 1
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		players = { 1: { "id": 1, "name": my_name } }
		lobby_created.emit(room_code)
		player_list_updated.emit(get_player_list(), 1)
		return

	var peer := ENetMultiplayerPeer.new()
	var err := ERR_CANT_CREATE
	for port in range(GAME_PORT_BASE, GAME_PORT_MAX + 1):
		err = peer.create_server(port, 16)
		if err == OK:
			game_port = port
			break

	if err != OK:
		lobby_join_failed.emit("Nie udało się utworzyć serwera ENet (porty zajęte).")
		return

	room_code = _generate_code()
	is_host = true
	my_id = 1
	multiplayer.multiplayer_peer = peer
	players = { 1: { "id": 1, "name": my_name } }

	_start_discovery_server()
	lobby_created.emit(room_code)
	player_list_updated.emit(get_player_list(), 1)


func join_lobby(code_or_ip: String, nickname: String) -> void:
	disconnect_lobby(false)
	my_name = nickname.strip_edges()
	if my_name.is_empty():
		my_name = "Gracz" + str(randi_range(100, 999))

	var raw := code_or_ip.strip_edges()
	if raw.contains(".") or raw.contains(":"):
		var ip := raw
		var port := GAME_PORT_BASE
		if raw.contains(":"):
			var parts := raw.split(":")
			ip = parts[0]
			port = int(parts[1])
		room_code = raw
		_connect_enet_client(ip, port)
		return

	var code := raw.to_upper()
	if code.length() < 4:
		lobby_join_failed.emit("Wpisz poprawny 6-znakowy kod pokoju lub adres IP!")
		return

	room_code = code
	if OS.has_feature("web"):
		lobby_join_failed.emit("Dołączanie kodem LAN wymaga wersji desktopowej Godota.")
		return

	_target_code = code
	_searching = true
	_search_elapsed = 0.0
	_search_retry_timer = 0.0
	_discovery_client = PacketPeerUDP.new()
	_discovery_client.set_broadcast_enabled(true)
	_broadcast_find_packet(_target_code)


func _connect_enet_client(ip: String, port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		lobby_join_failed.emit("Nie można połączyć z hostem (%s:%d)" % [ip, port])
		return
	is_host = false
	_joined_emitted = false
	multiplayer.multiplayer_peer = peer


func _start_discovery_server() -> void:
	_stop_discovery_server()
	var srv := UDPServer.new()
	for port in range(DISCOVERY_PORT_BASE, DISCOVERY_PORT_MAX + 1):
		if srv.listen(port, "*") == OK:
			_discovery_server = srv
			return


func _stop_discovery_server() -> void:
	if _discovery_server != null:
		_discovery_server.stop()
		_discovery_server = null


func _stop_discovery_client() -> void:
	_searching = false
	if _discovery_client != null:
		_discovery_client.close()
		_discovery_client = null


func _broadcast_find_packet(code: String) -> void:
	if _discovery_client == null:
		return
	var data := ("OLAFO_FIND:" + code).to_utf8_buffer()
	for port in range(DISCOVERY_PORT_BASE, DISCOVERY_PORT_MAX + 1):
		_discovery_client.set_dest_address("127.0.0.1", port)
		_discovery_client.put_packet(data)
		_discovery_client.set_dest_address("255.255.255.255", port)
		_discovery_client.put_packet(data)


func disconnect_lobby(emit_signal_flag: bool = false) -> void:
	_stop_discovery_server()
	_stop_discovery_client()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	room_code = ""
	my_id = 1
	_joined_emitted = false
	players.clear()
	if emit_signal_flag:
		disconnected_from_host.emit("")


func get_player_list() -> Array:
	var arr: Array = []
	var ids := players.keys()
	ids.sort()
	for id in ids:
		arr.append(players[id])
	return arr


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_host and players.has(id):
		players.erase(id)
		_rpc_sync_lobby.rpc(players)
	peer_left_game.emit(id)


func _on_connected_to_server() -> void:
	my_id = multiplayer.get_unique_id()
	_rpc_register_player.rpc_id(1, my_name)


func _on_connection_failed() -> void:
	disconnect_lobby(false)
	lobby_join_failed.emit("Nie udało się połączyć z pokojem.")


func _on_server_disconnected() -> void:
	disconnect_lobby(false)
	disconnected_from_host.emit("Połączenie z hostem zostało utracone")


@rpc("any_peer", "reliable")
func _rpc_register_player(player_name: String) -> void:
	if not is_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	players[sender_id] = { "id": sender_id, "name": player_name }
	_rpc_sync_lobby.rpc(players)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_lobby(updated_players: Dictionary) -> void:
	players = updated_players.duplicate(true)
	if not is_host and not _joined_emitted:
		_joined_emitted = true
		lobby_joined.emit(room_code)
	player_list_updated.emit(get_player_list(), 1)

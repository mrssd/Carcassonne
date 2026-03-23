extends Node

signal session_updated
signal lobby_updated
signal status_changed(message: String)
signal action_failed(message: String)

const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 5
const GAME_SCENE_PATH := "res://scenes/main/Main.tscn"

var is_lan_match: bool = false
var expected_player_count: int = 2
var player_peer_ids: Array[int] = []
var player_usernames: Dictionary = {}
var local_username: String = "Player"

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func reset_session() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_lan_match = false
	expected_player_count = 2
	player_peer_ids.clear()
	player_usernames.clear()
	_emit_status("Offline")
	session_updated.emit()
	lobby_updated.emit()

func host_game(player_count: int, username: String, port: int = DEFAULT_PORT) -> Error:
	reset_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		_emit_status("Host failed on port %d" % port)
		return err

	multiplayer.multiplayer_peer = peer
	is_lan_match = true
	expected_player_count = clamp(player_count, 2, MAX_PLAYERS)
	local_username = _sanitize_username(username)
	player_peer_ids = [multiplayer.get_unique_id()]
	player_usernames[multiplayer.get_unique_id()] = local_username
	_emit_status("Hosting on port %d" % port)
	session_updated.emit()
	lobby_updated.emit()
	return OK

func join_game(address: String, username: String, port: int = DEFAULT_PORT) -> Error:
	reset_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_emit_status("Join failed")
		return err

	multiplayer.multiplayer_peer = peer
	is_lan_match = true
	local_username = _sanitize_username(username)
	_emit_status("Connecting to %s:%d" % [address, port])
	session_updated.emit()
	return OK

func is_host() -> bool:
	return is_lan_match and multiplayer.get_unique_id() == 1

func get_local_player_index() -> int:
	return player_peer_ids.find(multiplayer.get_unique_id())

func get_player_names() -> Array[String]:
	var names: Array[String] = []
	for peer_id in player_peer_ids:
		names.append(player_usernames.get(peer_id, "Player %d" % (names.size() + 1)))
	return names

func start_lan_match() -> void:
	if not is_host():
		return
	rpc("_begin_match", expected_player_count, player_usernames)

func request_place_tile(cell: Vector2i, rotation_count: int) -> void:
	if not is_lan_match:
		return
	if is_host():
		_handle_place_tile(multiplayer.get_unique_id(), cell, rotation_count)
	else:
		rpc_id(1, "_request_place_tile", cell, rotation_count)

func request_place_meeple(slot_id: String, feature: String) -> void:
	if not is_lan_match:
		return
	if is_host():
		_handle_place_meeple(multiplayer.get_unique_id(), slot_id, feature)
	else:
		rpc_id(1, "_request_place_meeple", slot_id, feature)

func request_skip_meeple() -> void:
	if not is_lan_match:
		return
	if is_host():
		_handle_skip_meeple(multiplayer.get_unique_id())
	else:
		rpc_id(1, "_request_skip_meeple")

func sync_drawn_tile(tile_name: String) -> void:
	if is_host():
		rpc("_show_drawn_tile", tile_name)

func sync_game_over(message: String) -> void:
	if is_host():
		rpc("_apply_game_over", message)

func get_turn_system() -> TurnSystem:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("TurnSystem") as TurnSystem

func get_game_manager() -> GameManager:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("GameManager") as GameManager

@rpc("any_peer", "reliable")
func _register_player(username: String) -> void:
	if not is_host():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not player_peer_ids.has(peer_id):
		player_peer_ids.append(peer_id)
		player_peer_ids.sort()
	player_usernames[peer_id] = _sanitize_username(username)
	_sync_lobby_state.rpc(player_peer_ids, expected_player_count, player_usernames)
	session_updated.emit()
	lobby_updated.emit()

@rpc("authority", "call_local", "reliable")
func _sync_lobby_state(peer_ids: Array[int], player_count: int, usernames: Dictionary) -> void:
	player_peer_ids = peer_ids.duplicate()
	expected_player_count = player_count
	player_usernames = usernames.duplicate(true)
	is_lan_match = true
	session_updated.emit()
	lobby_updated.emit()
	_emit_status("Connected players: %d / %d" % [player_peer_ids.size(), expected_player_count])

@rpc("authority", "call_local", "reliable")
func _begin_match(player_count: int, usernames: Dictionary) -> void:
	expected_player_count = player_count
	player_usernames = usernames.duplicate(true)
	GameManager.player_count = player_count
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

@rpc("any_peer", "reliable")
func _request_place_tile(cell: Vector2i, rotation_count: int) -> void:
	_handle_place_tile(multiplayer.get_remote_sender_id(), cell, rotation_count)

@rpc("any_peer", "reliable")
func _request_place_meeple(slot_id: String, feature: String) -> void:
	_handle_place_meeple(multiplayer.get_remote_sender_id(), slot_id, feature)

@rpc("any_peer", "reliable")
func _request_skip_meeple() -> void:
	_handle_skip_meeple(multiplayer.get_remote_sender_id())

@rpc("authority", "call_local", "reliable")
func _apply_place_tile(cell: Vector2i, rotation_count: int) -> void:
	var turn_system := get_turn_system()
	if turn_system != null:
		turn_system.apply_network_tile_placement(cell, rotation_count)

@rpc("authority", "call_local", "reliable")
func _apply_place_meeple(slot_id: String, feature: String) -> void:
	var turn_system := get_turn_system()
	if turn_system != null:
		turn_system.apply_network_meeple_placement(slot_id, feature)

@rpc("authority", "call_local", "reliable")
func _apply_skip_meeple() -> void:
	var turn_system := get_turn_system()
	if turn_system != null:
		turn_system.apply_network_skip_meeple()

@rpc("authority", "call_local", "reliable")
func _show_drawn_tile(tile_name: String) -> void:
	var turn_system := get_turn_system()
	if turn_system != null:
		turn_system.receive_network_draw(tile_name)

@rpc("authority", "call_local", "reliable")
func _apply_game_over(message: String) -> void:
	var game_manager := get_game_manager()
	if game_manager != null:
		game_manager.end_game(message)

@rpc("authority", "reliable")
func _notify_action_failed(message: String) -> void:
	action_failed.emit(message)
	_emit_status(message)

func _handle_place_tile(peer_id: int, cell: Vector2i, rotation_count: int) -> void:
	var turn_system := get_turn_system()
	if turn_system == null:
		return
	if turn_system.can_accept_tile_request(peer_id, cell, rotation_count):
		rpc("_apply_place_tile", cell, rotation_count)
	else:
		_notify_failed_peer(peer_id, "Tile placement rejected.")

func _handle_place_meeple(peer_id: int, slot_id: String, feature: String) -> void:
	var turn_system := get_turn_system()
	if turn_system == null:
		return
	if turn_system.can_accept_meeple_request(peer_id, slot_id, feature):
		rpc("_apply_place_meeple", slot_id, feature)
	else:
		_notify_failed_peer(peer_id, "Meeple placement rejected.")

func _handle_skip_meeple(peer_id: int) -> void:
	var turn_system := get_turn_system()
	if turn_system == null:
		return
	if turn_system.can_accept_skip_request(peer_id):
		rpc("_apply_skip_meeple")
	else:
		_notify_failed_peer(peer_id, "Skip rejected.")

func _notify_failed_peer(peer_id: int, message: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_notify_action_failed(message)
	else:
		rpc_id(peer_id, "_notify_action_failed", message)

func _on_connected_to_server() -> void:
	is_lan_match = true
	_emit_status("Connected to host")
	rpc_id(1, "_register_player", local_username)

func _on_connection_failed() -> void:
	reset_session()
	_emit_status("Connection failed")

func _on_server_disconnected() -> void:
	reset_session()
	_emit_status("Disconnected from host")

func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if player_peer_ids.has(id):
		player_peer_ids.erase(id)
		player_usernames.erase(id)
		_sync_lobby_state.rpc(player_peer_ids, expected_player_count, player_usernames)
		session_updated.emit()
		lobby_updated.emit()
	_emit_status("Peer disconnected")

func _emit_status(message: String) -> void:
	status_changed.emit(message)

func _sanitize_username(username: String) -> String:
	var cleaned := username.strip_edges()
	if cleaned.is_empty():
		return "Player"
	return cleaned.substr(0, 20)

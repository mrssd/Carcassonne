extends Node

signal session_updated
signal lobby_updated
signal status_changed(message: String)
signal action_failed(message: String)

const DEFAULT_PORT: int = 7000
const GAME_SCENE_PATH := "res://scenes/main/Main.tscn"

const NetworkSessionScript = preload("res://scripts/network/NetworkSession.gd")
const NetworkTurnCoordinatorScript = preload("res://scripts/network/NetworkTurnCoordinator.gd")

var session := NetworkSessionScript.new()
var turn_coordinator := NetworkTurnCoordinatorScript.new(self)

var is_lan_match: bool:
	get:
		return session.is_lan_match

var expected_player_count: int:
	get:
		return session.expected_player_count

var player_peer_ids: Array[int]:
	get:
		return session.player_peer_ids

var player_usernames: Dictionary:
	get:
		return session.player_usernames

var local_username: String:
	get:
		return session.local_username

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
	session.reset()
	_emit_status("Offline")
	session_updated.emit()
	lobby_updated.emit()

func host_game(player_count: int, username: String, port: int = DEFAULT_PORT) -> Error:
	reset_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetworkSessionScript.MAX_PLAYERS)
	if err != OK:
		_emit_status("Host failed on port %d" % port)
		return err

	multiplayer.multiplayer_peer = peer
	session.configure_host(multiplayer.get_unique_id(), player_count, username)
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
	session.configure_client(username)
	_emit_status("Connecting to %s:%d" % [address, port])
	session_updated.emit()
	return OK

func is_host() -> bool:
	return session.is_host(multiplayer.get_unique_id())

func get_local_player_index() -> int:
	return session.get_local_player_index(multiplayer.get_unique_id())

func get_player_names() -> Array[String]:
	return session.get_player_names()

func get_match_player_names(default_player_count: int) -> Array[String]:
	return turn_coordinator.get_match_player_names(default_player_count)

func should_defer_draw_to_host() -> bool:
	return turn_coordinator.should_defer_draw_to_host()

func should_block_local_input(current_player_index: int) -> bool:
	return turn_coordinator.should_block_local_input(current_player_index)

func submit_tile_placement(cell: Vector2i, rotation_count: int) -> bool:
	return turn_coordinator.submit_tile_placement(cell, rotation_count)

func submit_meeple_placement(slot_id: String, feature: String) -> bool:
	return turn_coordinator.submit_meeple_placement(slot_id, feature)

func submit_skip_meeple() -> bool:
	return turn_coordinator.submit_skip_meeple()

func on_tile_drawn(tile_name: String) -> void:
	var turn_system := get_turn_system()
	if turn_system == null:
		return
	turn_coordinator.sync_drawn_tile(turn_system.current_player_index, tile_name)

func sync_starting_tile(tile_name: String) -> void:
	if is_host():
		rpc("_apply_starting_tile", tile_name)

func on_game_over(message: String) -> bool:
	return turn_coordinator.sync_game_over(message)

func start_lan_match() -> void:
	if not is_host():
		return
	if player_peer_ids.size() < expected_player_count:
		_emit_status("Waiting for players: %d / %d" % [player_peer_ids.size(), expected_player_count])
		return
	rpc("_begin_match", player_peer_ids, expected_player_count, player_usernames)

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

func sync_drawn_tile(player_index: int, tile_name: String) -> void:
	if is_host():
		rpc("_show_drawn_tile", player_index, tile_name)

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
	session.register_peer(peer_id, username)
	_sync_lobby_state.rpc(player_peer_ids, expected_player_count, player_usernames)
	session_updated.emit()
	lobby_updated.emit()

@rpc("authority", "call_local", "reliable")
func _sync_lobby_state(peer_ids: Array[int], player_count: int, usernames: Dictionary) -> void:
	session.sync_lobby(peer_ids, player_count, usernames)
	session_updated.emit()
	lobby_updated.emit()
	_emit_status("Connected players: %d / %d" % [player_peer_ids.size(), expected_player_count])

@rpc("authority", "call_local", "reliable")
func _begin_match(peer_ids: Array[int], player_count: int, usernames: Dictionary) -> void:
	session.sync_lobby(peer_ids, player_count, usernames)
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
	turn_coordinator.apply_tile_placement(cell, rotation_count)

@rpc("authority", "call_local", "reliable")
func _apply_place_meeple(slot_id: String, feature: String) -> void:
	turn_coordinator.apply_meeple_placement(slot_id, feature)

@rpc("authority", "call_local", "reliable")
func _apply_skip_meeple() -> void:
	turn_coordinator.apply_skip_meeple()

@rpc("authority", "call_remote", "reliable")
func _show_drawn_tile(player_index: int, tile_name: String) -> void:
	turn_coordinator.receive_draw(player_index, tile_name)

@rpc("authority", "call_remote", "reliable")
func _apply_starting_tile(tile_name: String) -> void:
	var game_manager := get_game_manager()
	if game_manager != null:
		game_manager.receive_starting_tile(tile_name)

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
	if turn_coordinator.validate_tile_request(peer_id, cell, rotation_count):
		rpc("_apply_place_tile", cell, rotation_count)
	else:
		_notify_failed_peer(peer_id, "Tile placement rejected.")

func _handle_place_meeple(peer_id: int, slot_id: String, feature: String) -> void:
	if turn_coordinator.validate_meeple_request(peer_id, slot_id, feature):
		rpc("_apply_place_meeple", slot_id, feature)
	else:
		_notify_failed_peer(peer_id, "Meeple placement rejected.")

func _handle_skip_meeple(peer_id: int) -> void:
	if turn_coordinator.validate_skip_request(peer_id):
		rpc("_apply_skip_meeple")
	else:
		_notify_failed_peer(peer_id, "Skip rejected.")

func _notify_failed_peer(peer_id: int, message: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_notify_action_failed(message)
	else:
		rpc_id(peer_id, "_notify_action_failed", message)

func _on_connected_to_server() -> void:
	session.is_lan_match = true
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
		session.remove_peer(id)
		_sync_lobby_state.rpc(player_peer_ids, expected_player_count, player_usernames)
		session_updated.emit()
		lobby_updated.emit()
	_emit_status("Peer disconnected")

func _emit_status(message: String) -> void:
	status_changed.emit(message)

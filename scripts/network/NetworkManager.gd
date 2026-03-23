extends Node

signal session_updated
signal lobby_updated
signal status_changed(message: String)
signal game_snapshot_received(snapshot: Dictionary)
signal action_failed(message: String)

const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 5
const GAME_SCENE_PATH := "res://scenes/main/Main.tscn"

var is_lan_match: bool = false
var expected_player_count: int = 2
var player_peer_ids: Array[int] = []
var player_usernames: Dictionary = {}
var local_username: String = "Player"
var pending_snapshot: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# Tears down any active LAN session and clears cached lobby/game state.
func reset_session() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_lan_match = false
	expected_player_count = 2
	player_peer_ids.clear()
	player_usernames.clear()
	pending_snapshot.clear()
	_emit_status("Offline")
	session_updated.emit()
	lobby_updated.emit()

# Starts an ENet server and marks this peer as the lobby host.
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

# Connects to a host on the local network and waits for lobby sync.
func join_game(address: String, username: String, port: int = DEFAULT_PORT) -> Error:
	reset_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_emit_status("Join failed")
		return err

	multiplayer.multiplayer_peer = peer
	is_lan_match = true
	expected_player_count = 2
	local_username = _sanitize_username(username)
	_emit_status("Connecting to %s:%d" % [address, port])
	session_updated.emit()
	return OK

# Returns true when this peer owns the authoritative match state.
func is_host() -> bool:
	return is_lan_match and multiplayer.get_unique_id() == 1

# Maps the current peer ID to its assigned turn/player slot.
func get_local_player_index() -> int:
	return player_peer_ids.find(multiplayer.get_unique_id())

# Builds display-friendly player names from the current peer list.
func get_player_names() -> Array[String]:
	var names: Array[String] = []
	for peer_id in player_peer_ids:
		names.append(player_usernames.get(peer_id, "Player %d" % (names.size() + 1)))
	return names

# Tells every connected peer to leave the lobby and enter the game scene.
func start_lan_match() -> void:
	if not is_host():
		return
	rpc("_begin_match", expected_player_count)

# Broadcasts the full authoritative game snapshot to all peers.
func broadcast_game_snapshot(snapshot: Dictionary) -> void:
	if not is_host():
		return
	rpc("_receive_game_snapshot", snapshot)

# Sends a tile placement request to the host for validation.
func request_place_tile(cell: Vector2i, rotation_count: int) -> void:
	if not is_lan_match:
		return
	if is_host():
		_handle_place_tile(multiplayer.get_unique_id(), cell, rotation_count)
	else:
		rpc_id(1, "_request_place_tile", cell, rotation_count)

# Sends a meeple placement request to the host for validation.
func request_place_meeple(slot_id: String, feature: String) -> void:
	if not is_lan_match:
		return
	if is_host():
		_handle_place_meeple(multiplayer.get_unique_id(), slot_id, feature)
	else:
		rpc_id(1, "_request_place_meeple", slot_id, feature)

# Sends a meeple-skip request to the host for validation.
func request_skip_meeple() -> void:
	if not is_lan_match:
		return
	if is_host():
		_handle_skip_meeple(multiplayer.get_unique_id())
	else:
		rpc_id(1, "_request_skip_meeple")

# Locates the active GameManager in the current scene for host-side actions.
func get_game_manager() -> GameManager:
	return get_tree().get_first_node_in_group("game_manager") as GameManager

@rpc("any_peer", "reliable")
# Registers a newly connected client with the host's lobby state.
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
# Pushes the authoritative lobby roster and target player count to all peers.
func _sync_lobby_state(peer_ids: Array[int], player_count: int, usernames: Dictionary) -> void:
	player_peer_ids = peer_ids.duplicate()
	expected_player_count = player_count
	player_usernames = usernames.duplicate(true)
	is_lan_match = true
	session_updated.emit()
	lobby_updated.emit()
	_emit_status("Connected players: %d / %d" % [player_peer_ids.size(), expected_player_count])

@rpc("authority", "call_local", "reliable")
# Moves every peer from the lobby into the main game scene.
func _begin_match(player_count: int) -> void:
	expected_player_count = player_count
	GameManager.player_count = player_count
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

@rpc("authority", "call_local", "reliable")
# Stores the latest host snapshot so clients can rebuild the board state.
func _receive_game_snapshot(snapshot: Dictionary) -> void:
	pending_snapshot = snapshot.duplicate(true)
	game_snapshot_received.emit(pending_snapshot)

@rpc("authority", "reliable")
# Sends a validation failure back to the requesting peer.
func _notify_action_failed(message: String) -> void:
	action_failed.emit(message)
	_emit_status(message)

@rpc("any_peer", "reliable")
# Forwards a remote tile placement request to the host validator.
func _request_place_tile(cell: Vector2i, rotation_count: int) -> void:
	_handle_place_tile(multiplayer.get_remote_sender_id(), cell, rotation_count)

@rpc("any_peer", "reliable")
# Forwards a remote meeple placement request to the host validator.
func _request_place_meeple(slot_id: String, feature: String) -> void:
	_handle_place_meeple(multiplayer.get_remote_sender_id(), slot_id, feature)

@rpc("any_peer", "reliable")
# Forwards a remote skip request to the host validator.
func _request_skip_meeple() -> void:
	_handle_skip_meeple(multiplayer.get_remote_sender_id())

# Host-side entry point for validating and applying a tile placement.
func _handle_place_tile(peer_id: int, cell: Vector2i, rotation_count: int) -> void:
	var game_manager := get_game_manager()
	if game_manager == null:
		return
	if game_manager.handle_network_place_tile(peer_id, cell, rotation_count):
		broadcast_game_snapshot(game_manager.build_snapshot())
	else:
		_notify_failed_peer(peer_id, "Tile placement rejected.")

# Host-side entry point for validating and applying a meeple placement.
func _handle_place_meeple(peer_id: int, slot_id: String, feature: String) -> void:
	var game_manager := get_game_manager()
	if game_manager == null:
		return
	if game_manager.handle_network_place_meeple(peer_id, slot_id, feature):
		broadcast_game_snapshot(game_manager.build_snapshot())
	else:
		_notify_failed_peer(peer_id, "Meeple placement rejected.")

# Host-side entry point for validating and applying a meeple skip.
func _handle_skip_meeple(peer_id: int) -> void:
	var game_manager := get_game_manager()
	if game_manager == null:
		return
	if game_manager.handle_network_skip_meeple(peer_id):
		broadcast_game_snapshot(game_manager.build_snapshot())
	else:
		_notify_failed_peer(peer_id, "Skip rejected.")

# Routes a failure message back to the peer that triggered it.
func _notify_failed_peer(peer_id: int, message: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_notify_action_failed(message)
	else:
		rpc_id(peer_id, "_notify_action_failed", message)

# Tracks new peers joining the session.
func _on_peer_connected(_id: int) -> void:
	if is_host():
		_emit_status("Peer connected")

# Removes a departing peer and re-syncs the lobby roster.
func _on_peer_disconnected(id: int) -> void:
	if player_peer_ids.has(id):
		player_peer_ids.erase(id)
		player_usernames.erase(id)
		lobby_updated.emit()
		session_updated.emit()
	if is_host():
		_sync_lobby_state.rpc(player_peer_ids, expected_player_count, player_usernames)
	_emit_status("Peer disconnected")

# Completes client-side registration after connecting to a host.
func _on_connected_to_server() -> void:
	is_lan_match = true
	_emit_status("Connected to host")
	rpc_id(1, "_register_player", local_username)

# Handles a failed join attempt without leaving stale session state behind.
func _on_connection_failed() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_lan_match = false
	player_peer_ids.clear()
	player_usernames.clear()
	pending_snapshot.clear()
	session_updated.emit()
	lobby_updated.emit()
	_emit_status("Connection failed")

# Handles a lost host connection and resets the local LAN session state.
func _on_server_disconnected() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_lan_match = false
	player_peer_ids.clear()
	player_usernames.clear()
	pending_snapshot.clear()
	session_updated.emit()
	lobby_updated.emit()
	_emit_status("Disconnected from host")

# Emits status text for the menu and other UI surfaces.
func _emit_status(message: String) -> void:
	status_changed.emit(message)

func _sanitize_username(username: String) -> String:
	var cleaned := username.strip_edges()
	if cleaned.is_empty():
		return "Player"
	return cleaned.substr(0, 20)

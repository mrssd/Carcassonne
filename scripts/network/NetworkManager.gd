extends Node

signal session_updated
signal lobby_updated
signal status_changed(message: String)
signal action_failed(message: String)

const DEFAULT_PORT: int = 7000
const GAME_SCENE_PATH := "res://scenes/main/Main.tscn"
const MENU_SCENE_PATH := "res://scenes/menu/mainMenu.tscn"
const READY_TIMEOUT_MS: int = 12000

const EVENT_STARTING_TILE := "starting_tile"
const EVENT_DRAW_TILE := "draw_tile"
const EVENT_PLACE_TILE := "place_tile"
const EVENT_PLACE_MEEPLE := "place_meeple"
const EVENT_SKIP_MEEPLE := "skip_meeple"
const EVENT_GAME_OVER := "game_over"

const NetworkSessionScript = preload("res://scripts/network/NetworkSession.gd")
const NetworkTurnCoordinatorScript = preload("res://scripts/network/NetworkTurnCoordinator.gd")
const NetworkDiscoveryScript = preload("res://scripts/network/NetworkDiscovery.gd")

var session := NetworkSessionScript.new()
var turn_coordinator := NetworkTurnCoordinatorScript.new(self)
var discovery := NetworkDiscoveryScript.new()
var discovery_timer: float = 0.0
var discovered_servers: Array[Dictionary] = []

var current_match_id: int = 0
var loading_match_id: int = 0
var gameplay_match_id: int = 0
var match_loading: bool = false
var match_gameplay_started: bool = false
var local_scene_ready: bool = false
var local_scene_ready_match_id: int = 0
var gameplay_started_locally: bool = false
var ready_deadline_msec: int = 0
var expected_match_peer_ids: Array[int] = []
var ready_peer_ids: Array[int] = []
var state_sequence_counter: int = 0
var last_applied_state_sequence: int = 0
var pending_state_events := {}

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
	_debug_log("NetworkManager ready. peer_id=%d" % multiplayer.get_unique_id())

func _process(delta: float) -> void:
	if discovery == null:
		return

	if is_host():
		discovery_timer += delta
		if discovery_timer >= NetworkDiscoveryScript.BROADCAST_INTERVAL:
			discovery.broadcast_server(delta)
			discovery_timer = 0.0

	if is_host() and match_loading and not match_gameplay_started and ready_deadline_msec > 0:
		if Time.get_ticks_msec() >= ready_deadline_msec:
			_debug_log("Scene ready wait timed out for match %d. ready=%s expected=%s" % [loading_match_id, ready_peer_ids, expected_match_peer_ids])
			if ready_peer_ids.has(multiplayer.get_unique_id()):
				_begin_gameplay_for_loaded_match("timeout")
			else:
				_emit_status("Match start timed out while host was still loading")

func reset_session() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		_debug_log("Closing multiplayer peer")
		peer.close()
	multiplayer.multiplayer_peer = null
	session.reset()
	discovery.close()
	discovery_timer = 0.0
	_reset_match_flow_state()
	_emit_status("Offline")
	session_updated.emit()
	lobby_updated.emit()

func host_game(player_count: int, username: String, port: int = DEFAULT_PORT) -> Error:
	reset_session()

	var discovery_err := start_server_discovery(username, port)
	if discovery_err != OK:
		_debug_log("Discovery broadcast failed on host. err=%d" % discovery_err)
		_emit_status("Discovery broadcast failed")

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetworkSessionScript.MAX_PLAYERS)
	if err != OK:
		_debug_log("Host failed on port %d. err=%d" % [port, err])
		_emit_status("Host failed on port %d" % port)
		return err

	multiplayer.multiplayer_peer = peer
	session.configure_host(multiplayer.get_unique_id(), player_count, username)
	_debug_log("Hosting on port %d for %d players as '%s'" % [port, expected_player_count, local_username])
	_emit_status("Hosting on port %d" % port)
	session_updated.emit()
	lobby_updated.emit()
	return OK

func join_game(address: String, username: String, port: int = DEFAULT_PORT) -> Error:
	reset_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_debug_log("Join failed for %s:%d. err=%d" % [address, port, err])
		_emit_status("Join failed")
		return err

	multiplayer.multiplayer_peer = peer
	session.configure_client(username)
	_debug_log("Connecting to host %s:%d as '%s'" % [address, port, local_username])
	_emit_status("Connecting to %s:%d" % [address, port])
	session_updated.emit()
	return OK

func is_host() -> bool:
	return session.is_host(multiplayer.get_unique_id())

func start_server_discovery(username: String, port: int = DEFAULT_PORT) -> Error:
	return discovery.start_server_broadcast(username, port)

func start_client_discovery() -> Error:
	return discovery.start_client_discovery()

func get_discovered_servers() -> Array[Dictionary]:
	return discovery.get_available_servers()

func stop_discovery() -> void:
	discovery.close()

func get_local_player_index() -> int:
	return session.get_local_player_index(multiplayer.get_unique_id())

func get_player_names() -> Array[String]:
	return session.get_player_names()

func get_match_player_names(default_player_count: int) -> Array[String]:
	return turn_coordinator.get_match_player_names(default_player_count)

func should_defer_draw_to_host() -> bool:
	return turn_coordinator.should_defer_draw_to_host()

func should_block_local_input(current_player_index: int) -> bool:
	if not is_lan_match:
		return false
	if match_loading or not match_gameplay_started or not gameplay_started_locally:
		return true
	return turn_coordinator.should_block_local_input(current_player_index)

func submit_tile_placement(cell: Vector2i, rotation_count: int) -> bool:
	if not _can_submit_local_action("tile placement"):
		return false
	return turn_coordinator.submit_tile_placement(cell, rotation_count)

func submit_meeple_placement(slot_id: String, feature: String) -> bool:
	if not _can_submit_local_action("meeple placement"):
		return false
	return turn_coordinator.submit_meeple_placement(slot_id, feature)

func submit_skip_meeple() -> bool:
	if not _can_submit_local_action("skip meeple"):
		return false
	return turn_coordinator.submit_skip_meeple()

func on_tile_drawn(tile_name: String) -> void:
	var turn_system := get_turn_system()
	if turn_system == null:
		_debug_log("Host could not sync drawn tile because TurnSystem is missing")
		return
	_debug_log("Host drew tile '%s' for player_index=%d" % [tile_name, turn_system.current_player_index])
	turn_coordinator.sync_drawn_tile(turn_system.current_player_index, tile_name)

func sync_starting_tile(tile_name: String) -> void:
	if is_host():
		_broadcast_state_event(EVENT_STARTING_TILE, {"tile_name": tile_name})

func on_game_over(message: String) -> bool:
	return turn_coordinator.sync_game_over(message)

func start_lan_match() -> void:
	if not is_host():
		return
	if player_peer_ids.size() < expected_player_count:
		_emit_status("Waiting for players: %d / %d" % [player_peer_ids.size(), expected_player_count])
		return
	if match_loading or match_gameplay_started:
		_debug_log("Ignoring duplicate start_lan_match while match is already loading or active")
		return

	current_match_id += 1
	loading_match_id = current_match_id
	match_loading = true
	match_gameplay_started = false
	gameplay_started_locally = false
	local_scene_ready = false
	local_scene_ready_match_id = 0
	gameplay_match_id = 0
	state_sequence_counter = 0
	last_applied_state_sequence = 0
	pending_state_events.clear()
	expected_match_peer_ids = player_peer_ids.duplicate()
	ready_peer_ids.clear()
	ready_deadline_msec = Time.get_ticks_msec() + READY_TIMEOUT_MS
	_debug_log("Starting LAN match %d with peers=%s timeout_ms=%d" % [current_match_id, expected_match_peer_ids, READY_TIMEOUT_MS])
	rpc("_prepare_match_load", current_match_id, expected_match_peer_ids, expected_player_count, player_usernames)

func notify_game_scene_ready() -> void:
	if not is_lan_match:
		return
	if not match_loading and not match_gameplay_started:
		_debug_log("Ignoring scene ready outside match load. scene=%s" % _get_scene_name())
		return
	if local_scene_ready and local_scene_ready_match_id == loading_match_id:
		_debug_log("Ignoring duplicate local scene ready for match %d" % loading_match_id)
		return

	local_scene_ready = true
	local_scene_ready_match_id = loading_match_id
	_debug_log("Local game scene ready for match %d. scene=%s" % [loading_match_id, _get_scene_name()])
	if is_host():
		_record_ready_peer(multiplayer.get_unique_id())
	else:
		rpc_id(1, "_client_scene_ready", loading_match_id)
	if match_gameplay_started:
		_try_begin_local_gameplay()

func finish_local_match() -> void:
	_debug_log("Finishing local match state for match %d" % gameplay_match_id)
	_reset_match_flow_state()

func sync_drawn_tile(player_index: int, tile_name: String) -> void:
	if is_host():
		_broadcast_state_event(EVENT_DRAW_TILE, {
			"player_index": player_index,
			"tile_name": tile_name,
		})

func sync_game_over(message: String) -> void:
	if is_host():
		_broadcast_state_event(EVENT_GAME_OVER, {"message": message})

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

func get_board() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Board")

func get_ui_manager() -> UIManager:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("UI/UIPanel") as UIManager

@rpc("any_peer", "reliable")
func _register_player(username: String) -> void:
	if not is_host():
		_debug_log("Ignoring _register_player on non-host")
		return
	var peer_id := multiplayer.get_remote_sender_id()
	session.register_peer(peer_id, username)
	_debug_log("Registered peer %d as '%s'. lobby_peers=%s" % [peer_id, username, player_peer_ids])
	_sync_lobby_state.rpc(player_peer_ids, expected_player_count, player_usernames)
	session_updated.emit()
	lobby_updated.emit()

@rpc("authority", "call_local", "reliable")
func _sync_lobby_state(peer_ids: Array[int], player_count: int, usernames: Dictionary) -> void:
	session.sync_lobby(peer_ids, player_count, usernames)
	_debug_log("Lobby sync received. peers=%s expected=%d" % [player_peer_ids, expected_player_count])
	session_updated.emit()
	lobby_updated.emit()
	_emit_status("Connected players: %d / %d" % [player_peer_ids.size(), expected_player_count])

@rpc("authority", "call_local", "reliable")
func _prepare_match_load(match_id: int, peer_ids: Array[int], player_count: int, usernames: Dictionary) -> void:
	session.sync_lobby(peer_ids, player_count, usernames)
	current_match_id = max(current_match_id, match_id)
	loading_match_id = match_id
	gameplay_match_id = 0
	match_loading = true
	match_gameplay_started = false
	gameplay_started_locally = false
	local_scene_ready = false
	local_scene_ready_match_id = 0
	if is_host():
		ready_deadline_msec = Time.get_ticks_msec() + READY_TIMEOUT_MS
	else:
		ready_deadline_msec = 0
	expected_match_peer_ids = peer_ids.duplicate()
	ready_peer_ids.clear()
	state_sequence_counter = 0
	last_applied_state_sequence = 0
	pending_state_events.clear()
	GameManager.player_count = player_count
	_debug_log("Preparing match load. match_id=%d peers=%s local_peer=%d" % [match_id, peer_ids, multiplayer.get_unique_id()])
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

@rpc("any_peer", "reliable")
func _client_scene_ready(match_id: int) -> void:
	if not is_host():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if match_id != loading_match_id or not match_loading:
		_debug_log("Ignoring stale scene-ready from peer %d for match %d (loading=%d active=%s)" % [peer_id, match_id, loading_match_id, match_loading])
		return
	if not expected_match_peer_ids.has(peer_id):
		_debug_log("Ignoring scene-ready from unexpected peer %d for match %d" % [peer_id, match_id])
		return
	_debug_log("Received scene-ready from peer %d for match %d" % [peer_id, match_id])
	_record_ready_peer(peer_id)

@rpc("authority", "call_local", "reliable")
func _start_match_gameplay(match_id: int) -> void:
	if match_id != loading_match_id:
		_debug_log("Ignoring gameplay start for stale match %d (loading=%d)" % [match_id, loading_match_id])
		return
	match_loading = false
	match_gameplay_started = true
	gameplay_match_id = match_id
	ready_deadline_msec = 0
	_debug_log("Gameplay start authorized for match %d" % match_id)
	_try_begin_local_gameplay()

@rpc("authority", "call_local", "reliable")
func _cancel_match_start(match_id: int, message: String) -> void:
	if match_id != loading_match_id and match_id != gameplay_match_id:
		return
	_debug_log("Cancelling match %d. reason=%s" % [match_id, message])
	_reset_match_flow_state()
	_emit_status(message)
	_return_to_menu_if_needed()

@rpc("any_peer", "reliable")
func _request_place_tile(cell: Vector2i, rotation_count: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	_debug_log("Tile placement request from peer %d cell=%s rot=%d" % [peer_id, cell, rotation_count])
	_handle_place_tile(peer_id, cell, rotation_count)

@rpc("any_peer", "reliable")
func _request_place_meeple(slot_id: String, feature: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	_debug_log("Meeple placement request from peer %d slot=%s feature=%s" % [peer_id, slot_id, feature])
	_handle_place_meeple(peer_id, slot_id, feature)

@rpc("any_peer", "reliable")
func _request_skip_meeple() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	_debug_log("Skip request from peer %d" % peer_id)
	_handle_skip_meeple(peer_id)

@rpc("authority", "call_local", "reliable")
func _apply_state_event(match_id: int, sequence_id: int, event_type: String, payload: Dictionary) -> void:
	_queue_state_event(match_id, sequence_id, event_type, payload)

@rpc("authority", "reliable")
func _notify_action_failed(message: String) -> void:
	_debug_log("Action rejected: %s" % message)
	action_failed.emit(message)
	_emit_status(message)

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

func _handle_place_tile(peer_id: int, cell: Vector2i, rotation_count: int) -> void:
	if not _can_host_process_action(peer_id, "tile placement"):
		return
	if turn_coordinator.validate_tile_request(peer_id, cell, rotation_count):
		_debug_log("Approved tile placement from peer %d cell=%s rot=%d" % [peer_id, cell, rotation_count])
		_broadcast_state_event(EVENT_PLACE_TILE, {
			"cell": cell,
			"rotation_count": rotation_count,
		})
	else:
		_notify_failed_peer(peer_id, "Tile placement rejected.")

func _handle_place_meeple(peer_id: int, slot_id: String, feature: String) -> void:
	if not _can_host_process_action(peer_id, "meeple placement"):
		return
	if turn_coordinator.validate_meeple_request(peer_id, slot_id, feature):
		_debug_log("Approved meeple placement from peer %d slot=%s feature=%s" % [peer_id, slot_id, feature])
		_broadcast_state_event(EVENT_PLACE_MEEPLE, {
			"slot_id": slot_id,
			"feature": feature,
		})
	else:
		_notify_failed_peer(peer_id, "Meeple placement rejected.")

func _handle_skip_meeple(peer_id: int) -> void:
	if not _can_host_process_action(peer_id, "skip"):
		return
	if turn_coordinator.validate_skip_request(peer_id):
		_debug_log("Approved skip request from peer %d" % peer_id)
		_broadcast_state_event(EVENT_SKIP_MEEPLE, {})
	else:
		_notify_failed_peer(peer_id, "Skip rejected.")

func _notify_failed_peer(peer_id: int, message: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_notify_action_failed(message)
	else:
		rpc_id(peer_id, "_notify_action_failed", message)

func _broadcast_state_event(event_type: String, payload: Dictionary) -> void:
	if not is_host():
		return
	if not match_gameplay_started and event_type != EVENT_GAME_OVER:
		_debug_log("Refusing to broadcast %s before gameplay start" % event_type)
		return
	state_sequence_counter += 1
	var sequence_id := state_sequence_counter
	var target_match_id := loading_match_id
	if gameplay_match_id > 0:
		target_match_id = gameplay_match_id
	_debug_log("Broadcasting event seq=%d type=%s payload=%s" % [sequence_id, event_type, payload])
	rpc("_apply_state_event", target_match_id, sequence_id, event_type, payload)

func _queue_state_event(match_id: int, sequence_id: int, event_type: String, payload: Dictionary) -> void:
	if match_id != gameplay_match_id and not (event_type == EVENT_GAME_OVER and match_id == loading_match_id):
		_debug_log("Ignoring state event for stale match. incoming=%d local=%d/%d type=%s seq=%d" % [match_id, loading_match_id, gameplay_match_id, event_type, sequence_id])
		return
	if sequence_id <= last_applied_state_sequence:
		_debug_log("Ignoring duplicate state event seq=%d type=%s last=%d" % [sequence_id, event_type, last_applied_state_sequence])
		return
	pending_state_events[sequence_id] = {
		"type": event_type,
		"payload": payload.duplicate(true),
	}
	_debug_log("Queued state event seq=%d type=%s pending=%s" % [sequence_id, event_type, pending_state_events.keys()])
	_drain_state_events()

func _drain_state_events() -> void:
	while true:
		var next_sequence := last_applied_state_sequence + 1
		if not pending_state_events.has(next_sequence):
			return
		if not _can_apply_state_events_now():
			_debug_log("Waiting to apply seq=%d until scene gameplay is fully ready" % next_sequence)
			return
		var event: Dictionary = pending_state_events[next_sequence]
		pending_state_events.erase(next_sequence)
		if _apply_state_event_now(next_sequence, event.get("type", ""), event.get("payload", {})):
			last_applied_state_sequence = next_sequence
		else:
			_debug_log("State event seq=%d deferred because local dependencies are still unavailable" % next_sequence)
			pending_state_events[next_sequence] = event
			return

func _apply_state_event_now(sequence_id: int, event_type: String, payload: Dictionary) -> bool:
	match event_type:
		EVENT_STARTING_TILE:
			var game_manager := get_game_manager()
			if game_manager == null:
				return false
			_debug_log("Applying starting tile seq=%d tile=%s" % [sequence_id, payload.get("tile_name", "")])
			game_manager.receive_starting_tile(payload.get("tile_name", ""))
			return true
		EVENT_DRAW_TILE:
			_debug_log("Applying draw seq=%d player_index=%s tile=%s" % [sequence_id, payload.get("player_index", -1), payload.get("tile_name", "")])
			turn_coordinator.receive_draw(payload.get("player_index", -1), payload.get("tile_name", ""))
			return true
		EVENT_PLACE_TILE:
			_debug_log("Applying tile placement seq=%d cell=%s rot=%s" % [sequence_id, payload.get("cell", Vector2i.ZERO), payload.get("rotation_count", 0)])
			turn_coordinator.apply_tile_placement(payload.get("cell", Vector2i.ZERO), payload.get("rotation_count", 0))
			return true
		EVENT_PLACE_MEEPLE:
			_debug_log("Applying meeple placement seq=%d slot=%s feature=%s" % [sequence_id, payload.get("slot_id", ""), payload.get("feature", "")])
			turn_coordinator.apply_meeple_placement(payload.get("slot_id", ""), payload.get("feature", ""))
			return true
		EVENT_SKIP_MEEPLE:
			_debug_log("Applying skip seq=%d" % sequence_id)
			turn_coordinator.apply_skip_meeple()
			return true
		EVENT_GAME_OVER:
			var game_manager := get_game_manager()
			if game_manager == null:
				return false
			_debug_log("Applying game-over seq=%d message=%s" % [sequence_id, payload.get("message", "")])
			game_manager.end_game(payload.get("message", "Game over"))
			return true
		_:
			_debug_log("Unknown state event type '%s' at seq=%d" % [event_type, sequence_id])
			return true

func _can_apply_state_events_now() -> bool:
	if not local_scene_ready or not gameplay_started_locally:
		return false
	var game_manager := get_game_manager()
	var turn_system := get_turn_system()
	var board := get_board()
	var ui_manager := get_ui_manager()
	if game_manager == null or turn_system == null or board == null or ui_manager == null:
		return false
	if game_manager.has_method("has_started_match") and not game_manager.has_started_match():
		return false
	return true

func _record_ready_peer(peer_id: int) -> void:
	if ready_peer_ids.has(peer_id):
		_debug_log("Ignoring duplicate ready ack from peer %d for match %d" % [peer_id, loading_match_id])
		return
	ready_peer_ids.append(peer_id)
	ready_peer_ids.sort()
	_debug_log("Ready ack %d/%d for match %d. ready=%s expected=%s" % [ready_peer_ids.size(), expected_match_peer_ids.size(), loading_match_id, ready_peer_ids, expected_match_peer_ids])
	if _are_all_expected_peers_ready():
		_begin_gameplay_for_loaded_match("all_ready")

func _are_all_expected_peers_ready() -> bool:
	for peer_id in expected_match_peer_ids:
		if not ready_peer_ids.has(peer_id):
			return false
	return not expected_match_peer_ids.is_empty()

func _begin_gameplay_for_loaded_match(reason: String) -> void:
	if not is_host() or not match_loading or match_gameplay_started:
		return
	if not ready_peer_ids.has(multiplayer.get_unique_id()):
		_debug_log("Host cannot begin gameplay yet because local scene is not ready")
		return
	match_loading = false
	match_gameplay_started = true
	gameplay_match_id = loading_match_id
	ready_deadline_msec = 0
	_debug_log("Authorizing gameplay start for match %d reason=%s ready=%s expected=%s" % [gameplay_match_id, reason, ready_peer_ids, expected_match_peer_ids])
	rpc("_start_match_gameplay", gameplay_match_id)

func _try_begin_local_gameplay() -> void:
	if gameplay_started_locally:
		return
	if not local_scene_ready:
		_debug_log("Local gameplay start deferred until scene-ready ack is complete")
		return
	var game_manager := get_game_manager()
	if game_manager == null:
		_debug_log("Local gameplay start deferred because GameManager is not present yet")
		call_deferred("_try_begin_local_gameplay")
		return
	_debug_log("Beginning local gameplay for match %d" % gameplay_match_id)
	game_manager.begin_network_match()
	gameplay_started_locally = true
	call_deferred("_drain_state_events")

func _can_submit_local_action(action_name: String) -> bool:
	if not is_lan_match:
		return false
	if match_loading or not match_gameplay_started or not gameplay_started_locally:
		_debug_log("Blocked local %s because gameplay is not ready. loading=%s started=%s local_started=%s" % [action_name, match_loading, match_gameplay_started, gameplay_started_locally])
		return false
	return true

func _can_host_process_action(peer_id: int, action_name: String) -> bool:
	if not is_host():
		return false
	if match_loading or not match_gameplay_started:
		_debug_log("Rejecting %s from peer %d because gameplay has not started" % [action_name, peer_id])
		_notify_failed_peer(peer_id, "Match is not ready yet.")
		return false
	if not expected_match_peer_ids.has(peer_id):
		_debug_log("Rejecting %s from unexpected peer %d" % [action_name, peer_id])
		_notify_failed_peer(peer_id, "Peer is not part of this match.")
		return false
	return true

func _on_connected_to_server() -> void:
	session.is_lan_match = true
	_debug_log("Connected to host. local_peer=%d" % multiplayer.get_unique_id())
	_emit_status("Connected to host")
	rpc_id(1, "_register_player", local_username)

func _on_connection_failed() -> void:
	_debug_log("Connection to host failed")
	reset_session()
	_emit_status("Connection failed")
	_return_to_menu_if_needed()

func _on_server_disconnected() -> void:
	_debug_log("Disconnected from host")
	reset_session()
	_emit_status("Disconnected from host")
	_return_to_menu_if_needed()

func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	_debug_log("Peer disconnected: %d" % id)
	if player_peer_ids.has(id):
		session.remove_peer(id)
		_sync_lobby_state.rpc(player_peer_ids, expected_player_count, player_usernames)
		session_updated.emit()
		lobby_updated.emit()
	if match_loading and expected_match_peer_ids.has(id):
		expected_match_peer_ids.erase(id)
		ready_peer_ids.erase(id)
		_debug_log("Removed disconnected peer %d from match-load wait. ready=%s expected=%s" % [id, ready_peer_ids, expected_match_peer_ids])
		if expected_match_peer_ids.size() < 2:
			rpc("_cancel_match_start", loading_match_id, "Match cancelled: not enough players after disconnect.")
		elif _are_all_expected_peers_ready():
			_begin_gameplay_for_loaded_match("disconnect")
	elif match_gameplay_started and expected_match_peer_ids.has(id):
		expected_match_peer_ids.erase(id)
		_debug_log("Ending active match because peer %d disconnected" % id)
		_broadcast_state_event(EVENT_GAME_OVER, {"message": "Player disconnected. Match ended."})
	_emit_status("Peer disconnected")

func _return_to_menu_if_needed() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path != MENU_SCENE_PATH:
		get_tree().change_scene_to_file(MENU_SCENE_PATH)

func _reset_match_flow_state() -> void:
	current_match_id = 0
	loading_match_id = 0
	gameplay_match_id = 0
	match_loading = false
	match_gameplay_started = false
	local_scene_ready = false
	local_scene_ready_match_id = 0
	gameplay_started_locally = false
	ready_deadline_msec = 0
	expected_match_peer_ids.clear()
	ready_peer_ids.clear()
	state_sequence_counter = 0
	last_applied_state_sequence = 0
	pending_state_events.clear()

func _emit_status(message: String) -> void:
	status_changed.emit(message)

func _debug_log(message: String) -> void:
	print("[NetworkManager][peer=%d][scene=%s] %s" % [multiplayer.get_unique_id(), _get_scene_name(), message])

func _get_scene_name() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return "none"
	return scene.name

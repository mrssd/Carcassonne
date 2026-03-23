#is also new and now owns LAN
#gameplay orchestration: deciding whether non-host clients should wait for the
#host to draw, blocking local input when it is not the local player’s turn,
#forwarding placement/skip requests through the network, validating incoming
#requests against the active turn, and applying synced tile/meeple/skip actions
#back onto TurnSystem.


class_name NetworkTurnCoordinator
extends RefCounted

var network_manager: Node

func _init(manager: Node) -> void:
	network_manager = manager

func get_match_player_names(default_player_count: int) -> Array[String]:
	if network_manager.is_lan_match:
		return network_manager.get_player_names()

	var players: Array[String] = []
	for i in range(default_player_count):
		players.append("Player %d" % (i + 1))
	return players

func should_defer_draw_to_host() -> bool:
	return network_manager.is_lan_match and not network_manager.is_host()

func should_block_local_input(current_player_index: int) -> bool:
	return network_manager.is_lan_match and not is_local_players_turn(current_player_index)

func submit_tile_placement(cell: Vector2i, rotation_count: int) -> bool:
	if not network_manager.is_lan_match:
		return false
	network_manager.request_place_tile(cell, rotation_count)
	return true

func submit_meeple_placement(slot_id: String, feature: String) -> bool:
	if not network_manager.is_lan_match:
		return false
	network_manager.request_place_meeple(slot_id, feature)
	return true

func submit_skip_meeple() -> bool:
	if not network_manager.is_lan_match:
		return false
	network_manager.request_skip_meeple()
	return true

func sync_drawn_tile(tile_name: String) -> void:
	if network_manager.is_lan_match and network_manager.is_host():
		network_manager.sync_drawn_tile(tile_name)

func sync_game_over(message: String) -> bool:
	if network_manager.is_lan_match and network_manager.is_host():
		network_manager.sync_game_over(message)
		return true
	return false

func receive_draw(tile_name: String) -> void:
	var turn_system: TurnSystem = network_manager.get_turn_system()
	if turn_system != null:
		turn_system.show_drawn_tile_by_name(tile_name)

func apply_tile_placement(cell: Vector2i, rotation_count: int) -> void:
	var turn_system: TurnSystem = network_manager.get_turn_system()
	if turn_system != null:
		turn_system.commit_tile_placement(cell, rotation_count)

func apply_meeple_placement(slot_id: String, feature: String) -> void:
	var turn_system: TurnSystem = network_manager.get_turn_system()
	if turn_system != null:
		turn_system.commit_meeple_placement(slot_id, feature)

func apply_skip_meeple() -> void:
	var turn_system: TurnSystem = network_manager.get_turn_system()
	if turn_system != null:
		turn_system.commit_skip_meeple()

func validate_tile_request(peer_id: int, cell: Vector2i, rotation_count: int) -> bool:
	var turn_system: TurnSystem = network_manager.get_turn_system()
	if turn_system == null:
		return false
	if not _is_peer_turn(turn_system, peer_id):
		return false
	return turn_system.validate_tile_placement(cell, rotation_count)

func validate_meeple_request(peer_id: int, slot_id: String, feature: String) -> bool:
	var turn_system: TurnSystem = network_manager.get_turn_system()
	if turn_system == null:
		return false
	if not _is_peer_turn(turn_system, peer_id):
		return false
	return turn_system.validate_meeple_placement(slot_id, feature)

func validate_skip_request(peer_id: int) -> bool:
	var turn_system: TurnSystem = network_manager.get_turn_system()
	if turn_system == null:
		return false
	return _is_peer_turn(turn_system, peer_id) and turn_system.can_skip_meeple_phase()

func is_local_players_turn(current_player_index: int) -> bool:
	if not network_manager.is_lan_match:
		return true
	return network_manager.get_local_player_index() == current_player_index

func _is_peer_turn(turn_system: TurnSystem, peer_id: int) -> bool:
	if not network_manager.is_lan_match:
		return true
	if turn_system.current_player_index < 0 or turn_system.current_player_index >= network_manager.player_peer_ids.size():
		return false
	return network_manager.player_peer_ids[turn_system.current_player_index] == peer_id

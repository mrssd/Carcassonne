class_name GameManager extends Node

signal game_ended(message: String)

static var player_count: int = 2

@onready var board = $"../Board"
@onready var turn_system = $"../TurnSystem"
@onready var score_manager = $"../ScoreManager"

@export var tile_deck_resource: TileDeck

var tile_deck: TileDeck
var game_ended_flag: bool = false

func _ready() -> void:
	add_to_group("game_manager")
	if NetworkManager.is_lan_match:
		NetworkManager.game_snapshot_received.connect(_on_network_snapshot_received)
	if not NetworkManager.is_lan_match or NetworkManager.is_host():
		_initialize_deck()
	call_deferred("start_game")
		
## Initialize deck
# Loads the tile deck resource used for the current match.
func _initialize_deck() -> void:
	if tile_deck_resource:
		tile_deck = TileDeck.load_deck_from_resource(tile_deck_resource.resource_path)
	else:
		tile_deck = TileDeck.load_deck_from_resource("res://resources/tile_deck.tres")

## Game
# Starts a local game or applies the host snapshot on clients.
func start_game():
	if NetworkManager.is_lan_match and not NetworkManager.is_host():
		if not NetworkManager.pending_snapshot.is_empty():
			apply_snapshot(NetworkManager.pending_snapshot)
		return
	if tile_deck == null:
		_initialize_deck()
	_place_starting_tile()
	# Delegate player / turn initialization to TurnSystem
	if turn_system:
		turn_system.start_game()
	if NetworkManager.is_lan_match and NetworkManager.is_host():
		NetworkManager.broadcast_game_snapshot(build_snapshot())

## First tile
# Places the mandatory starting tile at the center of the board.
func _place_starting_tile() -> void:
	if board == null or tile_deck == null:
		return
	if board.tile_scene == null:
		push_error("Board.tile_scene not set!")
		return

	var starting_tile_data: CarcassonneTileData = tile_deck.draw_next_tile()
	if starting_tile_data == null:
		return

	## Placing the tile
	var tile_instance: Tile = board.tile_scene.instantiate()
	tile_instance.tile_data = starting_tile_data
	board.add_child(tile_instance)
	board.place_tile(Vector2i.ZERO, tile_instance)

## Game End
# Ends the match, shows the final message, then returns to the menu.
func end_game(message: String) -> void:
	game_ended_flag = true
	game_ended.emit(message)
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/menu/mainMenu.tscn")

# Validates a remote/local tile placement against the active player's turn.
func handle_network_place_tile(peer_id: int, cell: Vector2i, rotation_count: int) -> bool:
	if not _is_authorized_peer(peer_id):
		return false
	return turn_system.apply_network_tile_placement(cell, rotation_count)

# Validates a remote/local meeple placement against the active player's turn.
func handle_network_place_meeple(peer_id: int, slot_id: String, feature: String) -> bool:
	if not _is_authorized_peer(peer_id):
		return false
	return turn_system.apply_network_meeple_placement(slot_id, feature)

# Validates a remote/local skip request against the active player's turn.
func handle_network_skip_meeple(peer_id: int) -> bool:
	if not _is_authorized_peer(peer_id):
		return false
	return turn_system.apply_network_skip_meeple()

# Serializes the current host state into a snapshot for clients.
func build_snapshot() -> Dictionary:
	var tiles: Array[Dictionary] = []
	var meeples: Array[Dictionary] = []
	for cell in board.placed_tiles.keys():
		var tile: Tile = board.placed_tiles[cell]
		tiles.append({
			"cell": cell,
			"name": tile.tile_data.name,
			"rotation_count": tile.rotation_count,
		})
		for slot_id in tile.meeples.keys():
			var meeple: Meeple = tile.meeples[slot_id]
			meeples.append({
				"cell": cell,
				"slot_id": slot_id,
				"feature": meeple.feature_name,
				"owner_index": meeple.owner_index,
			})

	var current_tile_data: Dictionary = {}
	if turn_system.current_drawn_tile != null and turn_system.phase == TurnSystem.TurnPhase.PLACE_TILE:
		current_tile_data = {
			"name": turn_system.current_drawn_tile.tile_data.name,
			"rotation_count": turn_system.current_drawn_tile.rotation_count,
		}

	return {
		"tiles": tiles,
		"meeples": meeples,
		"current_player_index": turn_system.current_player_index,
		"phase": turn_system.phase,
		"game_active": turn_system.game_active,
		"remaining_meeples": turn_system.remaining_meeples.duplicate(),
		"scores": score_manager.scores.duplicate(),
		"current_tile": current_tile_data,
		"last_placed_cell": turn_system.last_placed_cell,
	}

# Rebuilds the local board, meeples, UI, and turn state from a host snapshot.
func apply_snapshot(snapshot: Dictionary) -> void:
	_clear_board()
	score_manager.scores = snapshot.get("scores", []).duplicate()
	turn_system.remaining_meeples = snapshot.get("remaining_meeples", []).duplicate()
	turn_system.current_player_index = snapshot.get("current_player_index", 0)
	turn_system.phase = snapshot.get("phase", TurnSystem.TurnPhase.DRAW_TILE)
	turn_system.game_active = snapshot.get("game_active", false)
	turn_system.last_placed_cell = snapshot.get("last_placed_cell", Vector2i.ZERO)
	turn_system.last_placed_tile = null
	turn_system.current_drawn_tile = null

	for tile_state in snapshot.get("tiles", []):
		var tile := _instantiate_tile(tile_state["name"], tile_state["rotation_count"])
		if tile == null:
			continue
		board.add_child(tile)
		board.place_tile(tile_state["cell"], tile)
		if tile_state["cell"] == turn_system.last_placed_cell:
			turn_system.last_placed_tile = tile

	for meeple_state in snapshot.get("meeples", []):
		var tile_at_cell: Tile = board.placed_tiles.get(meeple_state["cell"])
		if tile_at_cell == null:
			continue
		Meeple.try_place_on_tile_slot(
			tile_at_cell,
			meeple_state["slot_id"],
			meeple_state["feature"],
			meeple_state["owner_index"],
			turn_system.remaining_meeples,
			turn_system.MEEPLE_SCENE
		)
		turn_system.remaining_meeples[meeple_state["owner_index"]] += 1

	var current_tile_state: Dictionary = snapshot.get("current_tile", {})
	if turn_system.phase == TurnSystem.TurnPhase.PLACE_TILE and not current_tile_state.is_empty() and turn_system.is_local_players_turn():
		var current_tile := _instantiate_tile(current_tile_state["name"], current_tile_state["rotation_count"])
		if current_tile != null:
			board.add_child(current_tile)
			board.current_tile = current_tile
			turn_system.current_drawn_tile = current_tile
			turn_system.show_possible_placements(board.get_all_valid_placement(current_tile))
	else:
		board.current_tile = null
		turn_system.show_possible_placements([])

	if turn_system.phase == TurnSystem.TurnPhase.PLACE_MEEPLE and turn_system.last_placed_tile != null and turn_system.is_local_players_turn():
		Meeple.show_placement_hints(turn_system.last_placed_tile)
	else:
		Meeple.hide_placement_hints(turn_system.last_placed_tile)

	turn_system.turn_changed.emit(turn_system.get_current_player(), turn_system.current_player_index)
	turn_system.phase_changed.emit(turn_system.phase)
	score_manager.score_updated.emit(-1, -1)

# Removes all runtime tile nodes before rebuilding from a new snapshot.
func _clear_board() -> void:
	board.placed_tiles.clear()
	board.current_tile = null
	for child in board.get_children():
		if child is Tile:
			child.free()
	turn_system.show_possible_placements([])

# Recreates a tile instance from deck metadata and saved rotation.
func _instantiate_tile(tile_name: String, rotation_count: int) -> Tile:
	if board == null or board.tile_scene == null:
		return null
	var tile_data := TileDeck.create_tile_data_by_name(tile_name)
	if tile_data == null:
		return null
	var tile: Tile = board.tile_scene.instantiate()
	tile.tile_data = tile_data
	for _i in range(rotation_count):
		tile.rotate_clockwise()
	return tile

# Confirms that the requesting peer owns the active turn slot.
func _is_authorized_peer(peer_id: int) -> bool:
	if not NetworkManager.is_lan_match:
		return true
	if turn_system.current_player_index < 0 or turn_system.current_player_index >= NetworkManager.player_peer_ids.size():
		return false
	return NetworkManager.player_peer_ids[turn_system.current_player_index] == peer_id

# Applies new host snapshots received after the scene is already loaded.
func _on_network_snapshot_received(snapshot: Dictionary) -> void:
	if not is_inside_tree():
		return
	apply_snapshot(snapshot)

extends Node
class_name TurnSystem

signal turn_changed(player_name: String, player_index: int)
signal phase_changed(phase: int)
signal meeple_changed(player_index: int)

enum TurnPhase {
	DRAW_TILE,
	PLACE_TILE,
	PLACE_MEEPLE
}

var players = ["Player 1", "Player 2"]
var current_player_index := 0
var phase := TurnPhase.DRAW_TILE
var game_active: bool = false

const MEEPLE_SCENE: PackedScene = preload("res://scenes/meeple/Meeple.tscn")
const HIGHLIGHT_SCENE = preload("res://scenes/highlight/Highlight.tscn")

var meeples_per_player: int = 7
var remaining_meeples: Array = []
var highlight_nodes := []

@onready var board = $"../Board"
@onready var game_manager = $"../GameManager"
@onready var score_system = $"../ScoreSystem"
@onready var UI_manager = $"../UI/UIPanel"

var tile_deck: TileDeck
var current_drawn_tile: Tile = null
var last_placed_tile: Tile = null
var last_placed_cell: Vector2i = Vector2i.ZERO
var setup_complete: bool = false
var game_started_once: bool = false

func _ready() -> void:
	if score_system != null and not score_system.meeple_returned.is_connected(_on_meeple_returned):
		score_system.meeple_returned.connect(_on_meeple_returned)
	setup_complete = true
	print("TurnSystem: ready. board=%s ui=%s score=%s game_manager=%s" % [board != null, UI_manager != null, score_system != null, game_manager != null])


func start_game() -> void:
	if game_started_once:
		print("TurnSystem: ignoring duplicate start_game call")
		return
	if not is_runtime_ready():
		push_warning("TurnSystem.start_game called before dependencies were ready")
		return
	# Initialize players and meeples, wire score manager and deck, then start the first turn.
	players = NetworkManager.get_match_player_names(GameManager.player_count)

	# initialize meeples per player
	_init_meeples()

	# init score manager (if present)
	var sm = get_node_or_null("../ScoreManager")
	if sm != null:
		sm.init_scores(GameManager.player_count)
	elif game_manager != null and game_manager.score_manager != null:
		# fallback to GameManager's score_manager if present
		game_manager.score_manager.init_scores(GameManager.player_count)
	else:
		push_warning("TurnSystem.start_game: ScoreManager not found, skipping score initialization.")

	# wire the deck from GameManager if available
	if game_manager != null and game_manager.tile_deck != null:
		tile_deck = game_manager.tile_deck
	else:
		push_error("TurnSystem.start_game: tile_deck not available on GameManager")
		return

	game_active = true
	game_started_once = true
	current_player_index = 0
	phase = TurnPhase.DRAW_TILE
	print("TurnSystem: start_game players=%s lan=%s local_index=%d" % [players, NetworkManager.is_lan_match, NetworkManager.get_local_player_index()])
	start_turn()

func is_runtime_ready() -> bool:
	if not setup_complete:
		return false
	if board == null or game_manager == null or score_system == null or UI_manager == null:
		return false
	if UI_manager.has_method("is_setup_complete") and not UI_manager.is_setup_complete():
		return false
	return true

func _on_meeple_returned(player_index: int) -> void:
	if player_index >= 0 and player_index < remaining_meeples.size():
		remaining_meeples[player_index] += 1
		meeple_changed.emit(player_index)
		print("%s meeple returned (%d remaining)" % [players[player_index], remaining_meeples[player_index]])

func _init_meeples() -> void:
	remaining_meeples.clear()
	for i in range(players.size()):
		remaining_meeples.append(meeples_per_player)

func get_current_player() -> String:
	return players[current_player_index]

func start_turn() -> void:
	print("Turn started:", get_current_player())
	turn_changed.emit(get_current_player(), current_player_index)
	phase = TurnPhase.DRAW_TILE
	if NetworkManager.should_defer_draw_to_host():
		phase_changed.emit(phase)
		return
	draw_tile()

func draw_tile() -> void:
	if tile_deck == null:
		push_error("TurnSystem: tile_deck is null.")
		return

	if board == null or board.tile_scene == null:
		push_error("TurnSystem: board or board.tile_scene is not available.")
		return

	var draw_result := _draw_placeable_tile()
	if draw_result.is_empty():
		if UI_manager:
			UI_manager.show_hint("Game Over! No placeable tiles remain.")
		print("No placeable tiles remain. Game over!")
		game_active = false
		score_system.score_end_game(board)
		if not NetworkManager.on_game_over("No placeable tiles remain! Game Over!"):
			game_manager.end_game("No placeable tiles remain! Game Over!")
		return

	board.current_tile = draw_result["tile"]
	current_drawn_tile = board.current_tile

	phase = TurnPhase.PLACE_TILE
	_update_tile_preview_visibility(draw_result["valid_placements"])
	phase_changed.emit(phase)
	if UI_manager and _can_interact_with_current_turn():
		UI_manager.show_hint("Place the tile on a highlighted cell.\nRight-click or Q / E to rotate.")
	NetworkManager.on_tile_drawn(current_drawn_tile.tile_data.name)
	tile_deck.print_draw_pile()
	print("Tile drawn for", get_current_player())
	print("Place tile")

func _draw_placeable_tile() -> Dictionary:
	var attempts := tile_deck.get_draw_pile_size()

	for _i in range(attempts):
		var tile_data: CarcassonneTileData = tile_deck.draw_next_tile()
		if tile_data == null:
			return {}

		var tile_instance: Tile = board.tile_scene.instantiate()
		tile_instance.tile_data = tile_data.duplicate(true)
		board.add_child(tile_instance)

		var valid_placements = board.get_all_valid_placement(tile_instance)
		if not valid_placements.is_empty():
			return {
				"tile": tile_instance,
				"valid_placements": valid_placements,
			}

		board.remove_child(tile_instance)
		tile_instance.queue_free()
		tile_deck.return_drawn_tile(tile_data)

	return {}


# Refreshes the highlighted cells that show legal tile placements.
func show_possible_placements(valid_placements):
		#refresh the highlighted nodes
		for node in highlight_nodes:
			node.queue_free()
		highlight_nodes.clear()
		#new highlight
		for placement in valid_placements:
			var highlight = HIGHLIGHT_SCENE.instantiate()
			highlight.position = board.index_to_coord(placement["cell"])
			add_child(highlight)
			highlight_nodes.append(highlight)

# Handles local tile placement input or forwards it to the host.
func on_tile_placed() -> void:
	if not game_active:
		return
	if phase != TurnPhase.PLACE_TILE:
		return
	if board.current_tile == null:
		return

	var world_pos: Vector2 = board.current_tile.position
	var cell: Vector2i = board.coord_to_index(world_pos)
	if NetworkManager.submit_tile_placement(cell, board.current_tile.rotation_count):
		return
	_apply_current_tile_placement(cell)

func place_meeple(world_click: Vector2) -> void:
	var info: Dictionary = _get_closest_available_meeple_slot(world_click)
	if info.is_empty():
		if UI_manager:
			UI_manager.show_hint("That feature is already claimed.\nTry another spot or press SPACE to skip.")
		return
	if last_placed_tile != null and not last_placed_tile.can_place_meeple(info["slot_id"]):
		if UI_manager:
			UI_manager.show_hint("That meeple slot is already occupied.\nTry another spot or press SPACE to skip.")
		return
	if score_system.is_segment_claimed(board, last_placed_cell, info["feature"]):
		UI_manager.show_hint("That feature is already claimed.\nTry another spot or press SPACE to skip.")
		print("That feature is already claimed.")
		return
	if NetworkManager.submit_meeple_placement(info["slot_id"], info["feature"]):
		return
	var placed = Meeple.try_place_on_tile_slot(last_placed_tile, info["slot_id"], info["feature"], current_player_index, remaining_meeples, MEEPLE_SCENE)
	if placed:
		meeple_changed.emit(current_player_index)
		UI_manager.show_hint("Meeple placed! Turn ending...")
		Meeple.hide_placement_hints(last_placed_tile)
		end_meeple_phase()

# Finalizes scoring and advances the turn after meeple placement/skip.
func end_meeple_phase(advance_turn: bool = true) -> void:
	Meeple.hide_placement_hints(last_placed_tile)
	score_system.score_and_apply(board, last_placed_cell)
	last_placed_tile = null
	phase = TurnPhase.DRAW_TILE
	phase_changed.emit(phase)
	if advance_turn:
		end_turn()

func end_turn() -> void:
	print("Turn ended:", get_current_player())
	next_turn()
	start_turn()

func next_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()

func _input(event) -> void:
	if not game_active:
		return
	if NetworkManager.should_block_local_input(current_player_index):
		return

	if phase == TurnPhase.PLACE_TILE:
		if board.current_tile == null:
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				on_tile_placed()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				board.current_tile.rotate_clockwise()
				var valid_placements = board.get_all_valid_placement(current_drawn_tile)
				show_possible_placements(valid_placements)
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_Q:
				board.current_tile.rotate_counter_clockwise()
				var valid_placements = board.get_all_valid_placement(current_drawn_tile)
				show_possible_placements(valid_placements)
			elif event.keycode == KEY_E:
				board.current_tile.rotate_clockwise()
				var valid_placements = board.get_all_valid_placement(current_drawn_tile)
				show_possible_placements(valid_placements)
	elif phase == TurnPhase.PLACE_MEEPLE:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place_meeple(board.get_global_mouse_position())
		elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			UI_manager.show_hint("Skipping meeple placement. Turn ending...")
			print("Skipping meeple placement")
			if not NetworkManager.submit_skip_meeple():
				Meeple.hide_placement_hints(last_placed_tile)
				end_meeple_phase()

func validate_tile_placement(cell: Vector2i, rotation_count: int) -> bool:
	if not game_active or phase != TurnPhase.PLACE_TILE or board.current_tile == null:
		return false

	var original_rotation: int = board.current_tile.rotation_count
	_set_current_tile_rotation(rotation_count)
	var valid: bool = board.can_place(cell, board.current_tile)
	_set_current_tile_rotation(original_rotation)
	return valid

func validate_meeple_placement(slot_id: String, feature: String) -> bool:
	if not game_active or phase != TurnPhase.PLACE_MEEPLE or last_placed_tile == null:
		return false
	if current_player_index < 0 or current_player_index >= remaining_meeples.size():
		return false
	if remaining_meeples[current_player_index] <= 0:
		return false
	if not last_placed_tile.can_place_meeple(slot_id):
		return false
	if _get_feature_for_slot(last_placed_tile, slot_id) != feature:
		return false
	return not score_system.is_segment_claimed(board, last_placed_cell, feature)

func can_skip_meeple_phase() -> bool:
	return game_active and phase == TurnPhase.PLACE_MEEPLE

func show_drawn_tile_by_name(tile_name: String) -> void:
	if board.current_tile != null:
		board.current_tile.queue_free()
		board.current_tile = null

	var tile_data: CarcassonneTileData = TileDeck.create_tile_data_by_name(tile_name)
	if tile_data == null:
		return

	var tile_instance: Tile = board.tile_scene.instantiate()
	tile_instance.tile_data = tile_data
	board.add_child(tile_instance)
	board.current_tile = tile_instance
	current_drawn_tile = tile_instance
	phase = TurnPhase.PLACE_TILE
	_update_tile_preview_visibility(board.get_all_valid_placement(tile_instance))
	phase_changed.emit(phase)
	if UI_manager and _can_interact_with_current_turn():
		UI_manager.show_hint("Place the tile on a highlighted cell.\nRight-click or Q / E to rotate.")

func sync_current_player_index(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	if current_player_index == player_index:
		return
	current_player_index = player_index
	turn_changed.emit(get_current_player(), current_player_index)

func commit_tile_placement(cell: Vector2i, rotation_count: int) -> bool:
	if not game_active or phase != TurnPhase.PLACE_TILE or board.current_tile == null:
		return false

	while board.current_tile.rotation_count != rotation_count:
		board.current_tile.rotate_clockwise()

	return _apply_current_tile_placement(cell)

func commit_meeple_placement(slot_id: String, feature: String) -> bool:
	if not game_active or phase != TurnPhase.PLACE_MEEPLE or last_placed_tile == null:
		return false
	if score_system.is_segment_claimed(board, last_placed_cell, feature):
		return false
	var placed = Meeple.try_place_on_tile_slot(last_placed_tile, slot_id, feature, current_player_index, remaining_meeples, MEEPLE_SCENE)
	if not placed:
		return false
	meeple_changed.emit(current_player_index)
	Meeple.hide_placement_hints(last_placed_tile)
	end_meeple_phase(not (NetworkManager.is_lan_match and not NetworkManager.is_host()))
	return true

func commit_skip_meeple() -> bool:
	if not game_active or phase != TurnPhase.PLACE_MEEPLE:
		return false
	Meeple.hide_placement_hints(last_placed_tile)
	end_meeple_phase(not (NetworkManager.is_lan_match and not NetworkManager.is_host()))
	return true

# Commits the current floating tile to the board and enters meeple phase.
func _apply_current_tile_placement(cell: Vector2i) -> bool:
	if not board.can_place(cell, board.current_tile):
		if UI_manager:
			UI_manager.show_hint("Cannot place tile here – invalid placement.\nTry another highlighted cell.")
		print("Cannot place tile here – invalid placement.")
		return false
	board.place_tile(cell, board.current_tile)
	last_placed_tile = board.placed_tiles[cell]
	last_placed_cell = cell
	board.current_tile = null
	current_drawn_tile = null
	show_possible_placements([])
	_enter_meeple_phase()
	print("Tile placed. Left-click on this tile to place meeple, or press space to skip.")
	return true

func _set_current_tile_rotation(target_rotation: int) -> void:
	if board.current_tile == null:
		return
	var normalized_target := posmod(target_rotation, 4)
	while board.current_tile.rotation_count != normalized_target:
		board.current_tile.rotate_clockwise()

func _can_interact_with_current_turn() -> bool:
	return not NetworkManager.should_block_local_input(current_player_index)

func _update_tile_preview_visibility(valid_placements: Array) -> void:
	var show_preview := _can_interact_with_current_turn()
	if board.current_tile != null:
		board.current_tile.visible = show_preview
	show_possible_placements(valid_placements if show_preview else [])

func _enter_meeple_phase() -> void:
	phase = TurnPhase.PLACE_MEEPLE
	phase_changed.emit(phase)
	if last_placed_tile == null:
		return
	var available_slots := _get_available_meeple_slots(last_placed_tile)
	last_placed_tile.set_meta("allowed_meeple_slots", available_slots)
	if _can_interact_with_current_turn():
		Meeple.show_placement_hints(last_placed_tile, 24.0)
		if UI_manager:
			UI_manager.show_hint("Click a meeple position or press SPACE to skip.")

func _get_available_meeple_slots(tile: Tile) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if tile == null:
		return slots
	if tile.tile_data != null and tile.tile_data.meeple_positions.size() > 0:
		for base_key in tile.tile_data.meeple_positions.keys():
			var slot := _build_meeple_slot(tile, base_key)
			if not tile.can_place_meeple(slot["slot_id"]):
				continue
			if score_system.is_segment_claimed(board, last_placed_cell, slot["feature"]):
				continue
			slots.append(slot)
	else:
		var center_slot: Dictionary = {
			"offset": Vector2.ZERO,
			"feature": "center",
			"slot_id": "0_0_center"
		}
		if tile.can_place_meeple(center_slot["slot_id"]) and not score_system.is_segment_claimed(board, last_placed_cell, center_slot["feature"]):
			slots.append(center_slot)
	return slots

func _build_meeple_slot(tile: Tile, base_key: Vector2i) -> Dictionary:
	var feature := Meeple._resolve_segment(tile.tile_data, base_key, tile.rotation_count)
	return {
		"offset": Vector2(base_key.x, base_key.y) * 24.0,
		"feature": feature,
		"slot_id": "%d_%d_%s" % [base_key.x, base_key.y, feature]
	}

func _get_feature_for_slot(tile: Tile, slot_id: String) -> String:
	if tile == null:
		return "unknown"
	var parts: PackedStringArray = slot_id.split("_", false, 2)
	if parts.size() < 2:
		return "unknown"
	return Meeple._resolve_segment(tile.tile_data, Vector2i(int(parts[0]), int(parts[1])), tile.rotation_count)

func _get_closest_available_meeple_slot(world_click: Vector2) -> Dictionary:
	if last_placed_tile == null:
		return {}
	var best_slot: Dictionary = {}
	var best_dist: float = INF
	for slot in _get_available_meeple_slots(last_placed_tile):
		var world_candidate: Vector2 = last_placed_tile.to_global(slot["offset"])
		var dist: float = world_click.distance_to(world_candidate)
		if dist < best_dist:
			best_dist = dist
			best_slot = slot
	return best_slot

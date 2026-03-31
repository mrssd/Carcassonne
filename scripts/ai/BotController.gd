extends Node
class_name BotController

const MEEPLE_SCENE: PackedScene = preload("res://scenes/meeple/Meeple.tscn")

var board: Board
var score_system: Node
var turn_system: TurnSystem

func setup(p_turn_system: TurnSystem, p_board: Board, p_score_system: Node) -> void:
	turn_system = p_turn_system
	board = p_board
	score_system = p_score_system


# Main entry point — called by TurnSystem when it's a bot's turn
func take_turn(bot_type: String) -> void:
	var current_drawn_tile = turn_system.current_drawn_tile

	# Collect all valid (rotation, cell) combos across all 4 rotations
	var options = []
	for r in range(4):
		var placements = board.get_all_valid_placement(current_drawn_tile)
		for p in placements:
			options.append({"cell": p["cell"], "rotations": r})
		current_drawn_tile.rotate_clockwise()

	if options.is_empty():
		turn_system.end_meeple_phase()
		return

	var choice: Dictionary
	if bot_type == "greedy_bot":
		choice = _pick_best_placement(options)
	else:
		choice = options[randi() % options.size()]

	# Rotate tile to chosen orientation
	for _i in range(choice["rotations"]):
		current_drawn_tile.rotate_clockwise()

	# Place the tile
	board.current_tile.visible = true
	board.current_tile.position = board.index_to_coord(choice["cell"])
	turn_system.on_tile_placed()
	Meeple.hide_placement_hints(turn_system.last_placed_tile)

	await get_tree().create_timer(0.5).timeout

	# Meeple placement
	if bot_type == "greedy_bot":
		var best_meeple_coords = _greedy_evaluate_meeple()
		if best_meeple_coords == null:
			turn_system.end_meeple_phase()
		else:
			turn_system.place_meeple(best_meeple_coords)
	else:
		turn_system.end_meeple_phase()


# --- Greedy placement ---

func _pick_best_placement(options: Array) -> Dictionary:
	var high_score: float = -1
	var best_option = null
	var tile = turn_system.current_drawn_tile

	for option in options:
		for _r in range(option["rotations"]):
			tile.rotate_clockwise()
		var temp_score = _greedy_evaluate_placement(option["cell"], tile)
		if temp_score > high_score:
			high_score = temp_score
			best_option = option
		for _t in range(4 - option["rotations"]):
			tile.rotate_clockwise()

	return best_option


func _greedy_evaluate_placement(cell: Vector2i, tile: Tile) -> float:
	board.placed_tiles[cell] = tile
	var score: float = 0

	for seg in tile.tile_data.internal_connections.keys():
		if seg.begins_with("field_"):
			continue
		var dic = score_system._explore_segment(board, cell, seg)
		if seg.begins_with("city_"):
			score += (dic["tiles"].size() * 2 + dic["shield_count"] * 2) / (dic["open_ports"] + 1)
		else:
			score += dic["tiles"].size() / (dic["open_ports"] + 1)

	board.placed_tiles.erase(cell)
	return score


# --- Greedy meeple ---

func _greedy_evaluate_meeple() -> Variant:
	var last_placed_tile = turn_system.last_placed_tile
	var last_placed_cell = turn_system.last_placed_cell
	var current_player_index = turn_system.current_player_index
	var remaining_meeples = turn_system.remaining_meeples

	var best_key = null
	var best_value: float = -1
	var temp_value: float = -1

	if remaining_meeples[current_player_index] <= 0:
		return null

	for key in last_placed_tile.tile_data.meeple_positions.keys():
		var world_pos = last_placed_tile.to_global(Vector2(key.x, key.y) * 24.0)
		var temp_meeple: Meeple = MEEPLE_SCENE.instantiate() as Meeple
		var info = temp_meeple.get_placement_feature(last_placed_tile, world_pos)
		temp_meeple.free()

		if score_system.is_segment_claimed(board, last_placed_cell, info["feature"]):
			continue
		if info["feature"].begins_with("field_"):
			continue

		if info["feature"] == "monastery":
			var neighbor: int = 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					if board.placed_tiles.has(last_placed_cell + Vector2i(dx, dy)):
						neighbor += 1
			temp_value = neighbor + 1
			if temp_value > best_value and temp_value >= 4:
				best_value = temp_value
				best_key = key
			continue

		var dic = score_system._explore_segment(board, last_placed_cell, info["feature"])
		if info["feature"].begins_with("city_"):
			temp_value = dic["tiles"].size() * 2 + dic["shield_count"] * 2
		else:
			temp_value = dic["tiles"].size()

		if temp_value > best_value:
			best_value = temp_value
			best_key = key

	if best_value >= 1 and best_key != null:
		return last_placed_tile.to_global(Vector2(best_key.x, best_key.y) * 20.0)
	return null

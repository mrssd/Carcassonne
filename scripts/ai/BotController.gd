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

#Main function for bot logic
func take_turn(bot_type: String) -> void:
	var current_drawn_tile = turn_system.current_drawn_tile

	#Finds all valid placements of all 4 rotation
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

	#Rotates tile to the rotation from options
	for _i in range(choice["rotations"]):
		current_drawn_tile.rotate_clockwise()

	# Place the tile
	board.current_tile.visible = true
	board.current_tile.position = board.index_to_coord(choice["cell"])
	turn_system.on_tile_placed()
	Meeple.hide_placement_hints(turn_system.last_placed_tile)

	await get_tree().create_timer(0.5).timeout

	#Places the tile
	if bot_type == "greedy_bot":
		var best_meeple_coords = _greedy_evaluate_meeple()
		if best_meeple_coords == null:
			turn_system.end_meeple_phase()
		else:
			turn_system.place_meeple(best_meeple_coords)
	else:
		turn_system.end_meeple_phase()

#Loops through options (From _bot_place_tiles) and returns the best possible tile from options
func _pick_best_placement(options: Array) -> Dictionary:
	var high_score: float = -1
	var best_option = null
	var tile = turn_system.current_drawn_tile

	for option in options:
		for _r in range(option["rotations"]):
			tile.rotate_clockwise()
		var temp_score = _greedy_evaluate_placement(option["cell"], tile, turn_system.current_player_index)
		if temp_score > high_score:
			high_score = temp_score
			best_option = option
		for _t in range(4 - option["rotations"]):
			tile.rotate_clockwise()

	return best_option


#Calculates a value of the given tile
func _greedy_evaluate_placement(cell: Vector2i, tile: Tile, player_index: int) -> float:
	board.placed_tiles[cell] = tile
	var score: float = 0

	for seg in tile.tile_data.internal_connections.keys():
		if seg.begins_with("field_"):
			continue
		var dic = score_system._explore_segment(board, cell, seg)
		var seg_value: float
		if seg.begins_with("city_"):
			seg_value = (dic["tiles"].size() * 2 + dic["shield_count"] * 2) / (dic["open_ports"] + 1)
		else:
			seg_value = dic["tiles"].size() / (dic["open_ports"] + 1)

		#Discount segment value by amount of open ports
		var tile_open_ports: int = 0
		for edge_index in tile.tile_data.internal_connections[seg]:
			var neighbor_cell = cell + score_system.neighbor_directions[edge_index]
			if not board.placed_tiles.has(neighbor_cell):
				tile_open_ports += 1
		seg_value /= (tile_open_ports + 1)

		#Penalizes helping opponent features
		if _feature_has_opponent_meeple(dic["visited"], player_index):
			score -= seg_value * 0.5  
		else:
			score += seg_value

	board.placed_tiles.erase(cell)
	return score


#Calculates all possible meeple placement and returns the best placement
func _greedy_evaluate_meeple() -> Variant: #Variant which allows both Vector2i and null returned
	var last_placed_tile = turn_system.last_placed_tile
	var last_placed_cell = turn_system.last_placed_cell
	var current_player_index = turn_system.current_player_index
	var remaining_meeples = turn_system.remaining_meeples

	var best_key = null
	var best_value: float = -1
	var temp_value: float = -1

	if remaining_meeples[current_player_index] <= 0:
		return null

	for key in last_placed_tile.tile_data.meeple_positions.keys(): #Loop through all meeple placement of the last_placed_tile
		var world_pos = last_placed_tile.to_global(Vector2(key.x, key.y) * (Board.CELL_SIZE / 4.0))
		var temp_meeple: Meeple = MEEPLE_SCENE.instantiate() as Meeple
		var info = temp_meeple.get_placement_feature(last_placed_tile, world_pos)
		temp_meeple.free()
 
		if score_system.is_segment_claimed(board, last_placed_cell, info["feature"]):  #Ignore claimed feature
			continue

		if info["feature"].begins_with("field_"): #Ignore fields for now
			continue

		if info["feature"] == "monastery": #Monastery scoring
			var neighbor: int = 0
			for dx in [-1, 0, 1]: #Loops -1 to 1, representing neighbour tile coordinates
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

		if info["feature"].begins_with("city_"): #City value calculation
			temp_value = dic["tiles"].size() * 2 + dic["shield_count"] * 2
		else: #Road value calculation
			temp_value = dic["tiles"].size()

		if temp_value > best_value:
			best_value = temp_value
			best_key = key

	if best_value >= 1 and best_key != null:
		return last_placed_tile.to_global(Vector2(best_key.x, best_key.y) * (Board.CELL_SIZE / 4.0))
	return null


#Returns true if any opponent has a meeple on any tile in the visited segment
func _feature_has_opponent_meeple(visited: Array, current_player_index: int) -> bool:
	for entry in visited: #visited example: 1,0|city_0
		var parts = entry.split("|") #split string
		var coords = parts[0].split(",")
		var cell = Vector2i(int(coords[0]), int(coords[1]))
		if not board.placed_tiles.has(cell):
			continue
		var tile = board.placed_tiles[cell]
		for meeple in tile.meeples.values():
			if meeple.owner_index != current_player_index:
				return true
	return false

#Public method that returns the best cell for a given tile
func get_best_placement(tile: Tile) -> Vector2i:
	var options = []
	for p in board.get_all_valid_placement(tile):
		options.append({"cell": p["cell"], "rotations": 0})

	if options.is_empty():
		return Vector2i.MIN

	var best = _pick_best_placement(options)
	return best["cell"]
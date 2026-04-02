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
	elif bot_type == "smart_bot":
		choice = _pick_best_placement_minimax(options)
	elif bot_type == "expert_bot":
		choice = _pick_best_placement_expert(options)
	else:
		choice = _pick_best_placement(options) # Fallback

	#Rotates tile to the rotation from options
	for _i in range(choice["rotations"]):
		current_drawn_tile.rotate_clockwise()

	# Place the tile
	board.current_tile.visible = true
	board.current_tile.position = board.index_to_coord(choice["cell"])
	turn_system.on_tile_placed()
	Meeple.hide_placement_hints(turn_system.last_placed_tile)

	await get_tree().create_timer(0.5).timeout

	#Places the meeple
	if bot_type == "expert_bot":
		var best_meeple_coords = _expert_evaluate_meeple()
		if best_meeple_coords == null:
			turn_system.end_meeple_phase()
		else:
			turn_system.place_meeple(best_meeple_coords, false)
	elif bot_type == "greedy_bot" or bot_type == "smart_bot":
		var best_meeple_coords = _greedy_evaluate_meeple()
		if best_meeple_coords == null:
			turn_system.end_meeple_phase()
		else:
			turn_system.place_meeple(best_meeple_coords, false)
	else:
		turn_system.end_meeple_phase()

#Loops through options (From _bot_place_tiles) and returns the best possible tile from options
func _pick_best_placement(options: Array) -> Dictionary:
	var high_score: float = -INF
	var best_option: Dictionary = options[0]
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


#Calculates a value of the given tile placement
func _greedy_evaluate_placement(cell: Vector2i, tile: Tile, player_index: int) -> float:
	board.placed_tiles[cell] = tile
	var score: float = 0.0
	var seen_features: Array = [] # Deduplicates features that span multiple segments on same tile

	for seg in tile.tile_data.internal_connections.keys():
		#Separate traversal function for field calculation
		if seg.begins_with("field_"):
			var field_dic = score_system._explore_field(board, cell, seg)
			var visited_sorted = field_dic["visited"].duplicate()
			visited_sorted.sort()
			var fkey = "|".join(visited_sorted)
			if seen_features.has(fkey):
				continue
			seen_features.append(fkey)
			var has_mine = _feature_has_my_meeple(field_dic["visited"], player_index)
			var has_opp = _feature_has_opponent_meeple(field_dic["visited"], player_index)
			var cities = score_system._get_adjacent_completed_cities(board, field_dic)
			if has_mine:
				score += cities * 3.0 * 0.25
			elif has_opp:
				score -= cities * 3.0 * 0.1
			continue

		var dic = score_system._explore_segment(board, cell, seg)

		#Skip if already counted this connected feature
		var visited_sorted = dic["visited"].duplicate()
		visited_sorted.sort()
		var fkey = "|".join(visited_sorted)
		if seen_features.has(fkey):
			continue
		seen_features.append(fkey)

		var has_mine = _feature_has_my_meeple(dic["visited"], player_index)
		var has_opp = _feature_has_opponent_meeple(dic["visited"], player_index)
		var is_complete = dic["open_ports"] == 0

		#Raw point value of this feature
		var raw: float
		if seg.begins_with("city_"):
			raw = dic["tiles"].size() * 2.0 + dic["shield_count"] * 2.0
		else:
			raw = dic["tiles"].size() * 1.0

		#Value of completing a feature scores immediately (Heavy weighting compared to raw)
		if is_complete:
			if has_mine:
				score += raw * 2.0 #Extreme value if completing own feature
			elif has_opp:
				score -= raw * 1.0 #Negative value if completing opponent's feature
		
		#Discount by number of open ends remaining since incomplete
		else:
			var discounted = raw / (dic["open_ports"] + 1.0)
			if has_mine:
				score += discounted * 1.2  #Add points for extending own in progress feature
			elif has_opp:
				score -= discounted * 0.6  #Deduct points for extending opponent's feature
			else:
				score += discounted * 0.2  #Neutral

	#Bonus value for placing adjacent to own monastery 
	score += _score_monastery_adjacency(cell, player_index)

	board.placed_tiles.erase(cell)
	return score


#Uses a depth-2 minmax algorithm to pick the best placement
func _pick_best_placement_minimax(options: Array) -> Dictionary:
	var tile = turn_system.current_drawn_tile
	var my_index = turn_system.current_player_index
	var opp_index = (my_index + 1) % turn_system.players.size()

	var best_score: float = -INF
	var best_option: Dictionary = options[0]

	for option in options:
		for _r in range(option["rotations"]):
			tile.rotate_clockwise()

		var cell = option["cell"]
		var my_tile_score = _greedy_evaluate_placement(cell, tile, my_index)

		#Temporarily place my tile so opponent placement search sees the updated board
		board.placed_tiles[cell] = tile
		var opp_best: float = 0.0
		var opp_placements = board.get_all_valid_placement(tile)
		for opp_p in opp_placements:
			var opp_score = _greedy_evaluate_placement(opp_p["cell"], tile, opp_index)
			if opp_score > opp_best:
				opp_best = opp_score
		board.placed_tiles.erase(cell)

		#Penalise opponent opportunity at half weight (uncertainty about their tile)
		var minimax_score = my_tile_score - opp_best * 0.5
		if minimax_score > best_score:
			best_score = minimax_score
			best_option = option

		for _t in range(4 - option["rotations"]):
			tile.rotate_clockwise()

	return best_option


#Minimax depth-2 using the expert evaluation function for expert bot
func _pick_best_placement_expert(options: Array) -> Dictionary:
	var tile = turn_system.current_drawn_tile
	var my_index = turn_system.current_player_index
	var opp_index = (my_index + 1) % turn_system.players.size()

	var best_score: float = -INF
	var best_option: Dictionary = options[0]

	for option in options:
		for _r in range(option["rotations"]):
			tile.rotate_clockwise()

		var cell = option["cell"]
		var my_tile_score = _expert_evaluate_placement(cell, tile, my_index)

		board.placed_tiles[cell] = tile
		var opp_best: float = 0.0
		var opp_placements = board.get_all_valid_placement(tile)
		for opp_p in opp_placements:
			var opp_score = _expert_evaluate_placement(opp_p["cell"], tile, opp_index)
			if opp_score > opp_best:
				opp_best = opp_score
		board.placed_tiles.erase(cell)

		var minimax_score = my_tile_score - opp_best * 0.5
		if minimax_score > best_score:
			best_score = minimax_score
			best_option = option

		for _t in range(4 - option["rotations"]):
			tile.rotate_clockwise()

	return best_option


#Expert evaluation of tile
func _expert_evaluate_placement(cell: Vector2i, tile: Tile, player_index: int) -> float:
	var score = _greedy_evaluate_placement(cell, tile, player_index) #calls greedy to get base score
	var remaining = turn_system.remaining_meeples[player_index]
	var tiles_left = turn_system.tile_deck.get_draw_pile_size()

	board.placed_tiles[cell] = tile
	var seen: Array = []

	for seg in tile.tile_data.internal_connections.keys():
		if seg.begins_with("field_"):
			continue
		var dic = score_system._explore_segment(board, cell, seg)
		
		#Skip if already counted this feature
		var sorted_v = dic["visited"].duplicate()
		sorted_v.sort()
		var fkey = "|".join(sorted_v)
		if seen.has(fkey):
			continue
		seen.append(fkey)

		var has_mine = _feature_has_my_meeple(dic["visited"], player_index)

		# Meeple economy rules
		if remaining <= 2 and dic["open_ports"] == 0 and has_mine: #When <= 2 meeples left completing a feature gets a bonus scaled by remaining meeples
			score += dic["tiles"].size() * float(3 - remaining)

		# Late game rules
		if tiles_left <= 15 and dic["open_ports"] > 2 and has_mine: #When there's less than 15 tiles penalize extending features with 2+ open ports since unlikely to close
			var open_ratio = float(dic["open_ports"]) / float(tiles_left + 1)
			score -= open_ratio * dic["tiles"].size() * 0.5

	board.placed_tiles.erase(cell)
	return score


#Expert evaluation of meeple
func _expert_evaluate_meeple() -> Variant:
	var last_placed_tile = turn_system.last_placed_tile
	var last_placed_cell = turn_system.last_placed_cell
	var current_player_index = turn_system.current_player_index
	var remaining = turn_system.remaining_meeples[current_player_index]
	var tiles_left = turn_system.tile_deck.get_draw_pile_size()

	if remaining <= 0:
		return null

	var best_key = null
	var best_value: float = -1.0

	#Loops through every valid meeple slot
	for key in last_placed_tile.tile_data.meeple_positions.keys():
		var world_pos = last_placed_tile.to_global(Vector2(key.x, key.y) * (Board.CELL_SIZE / 4.0))
		var temp_meeple: Meeple = MEEPLE_SCENE.instantiate() as Meeple
		var info = temp_meeple.get_placement_feature(last_placed_tile, world_pos)
		temp_meeple.free()

		if score_system.is_segment_claimed(board, last_placed_cell, info["feature"]):
			continue

		var temp_value: float = -1.0

		#Field consideration
		if info["feature"].begins_with("field_"):
			if tiles_left > 20: #Only considers placing farmers when less than 20 tiles left
				continue
			#Counts completed cities adjcaent to field
			var field_result = score_system._explore_field(board, last_placed_cell, info["feature"]) 
			var city_count = score_system._get_adjacent_completed_cities(board, field_result)
			#Value calculation scales with tiles_left
			temp_value = city_count * 3.0 * (1.0 - float(tiles_left) / 72.0) 
			if temp_value < 3.0: #Not worth placing a meeple
				continue

		#Monastery consideration
		elif info["feature"] == "monastery":
			var neighbor: int = 0
			#Loops through all 9 surrounding tiles
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					if board.placed_tiles.has(last_placed_cell + Vector2i(dx, dy)):
						neighbor += 1
			temp_value = neighbor + 1
			if temp_value < 4: #Monastery with less than 3 neighbour not worth commiting a meeple
				continue

		#Cities and roads evaluation
		else:
			var dic = score_system._explore_segment(board, last_placed_cell, info["feature"])
			if info["feature"].begins_with("city_"):
				temp_value = dic["tiles"].size() * 2 + dic["shield_count"] * 2
			else:
				temp_value = dic["tiles"].size()

			#Only place on features close to completion if low on meeples (less than 3)
			if remaining <= 2:
				var completion_ratio = 1.0 / (dic["open_ports"] + 1.0)
				temp_value *= completion_ratio * 2.0

		if temp_value > best_value:
			best_value = temp_value
			best_key = key

	#Stricter threshold when low on meeples to avoid wasting them
	var threshold = 2.0 if remaining > 2 else 4.0
	if best_value >= threshold and best_key != null:
		return last_placed_tile.to_global(Vector2(best_key.x, best_key.y) * (Board.CELL_SIZE / 4.0))
	return null


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


#Returns true if the current player has a meeple in the visited segment
func _feature_has_my_meeple(visited: Array, player_index: int) -> bool:
	for entry in visited:
		var parts = entry.split("|")
		var coords = parts[0].split(",")
		var cell = Vector2i(int(coords[0]), int(coords[1]))
		if not board.placed_tiles.has(cell):
			continue
		var tile = board.placed_tiles[cell]
		for meeple in tile.meeples.values():
			if meeple.owner_index == player_index:
				return true
	return false

#Returns bonus score for placing next to own monastery and penalty for opponent's
func _score_monastery_adjacency(cell: Vector2i, player_index: int) -> float:
	var bonus: float = 0.0
	var offsets = [
		Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
		Vector2i(-1, 0),                 Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
	]
	for offset in offsets:
		var neighbor_cell = cell + offset
		if not board.placed_tiles.has(neighbor_cell):
			continue
		var neighbor_tile = board.placed_tiles[neighbor_cell]
		if not neighbor_tile.tile_data.is_monastery:
			continue
		for meeple in neighbor_tile.meeples.values():
			if meeple.owner_index == player_index:
				bonus += 1.0   #Each tile placed adjacent to own monastery +1 
			else:
				bonus -= 0.5  #Deducts points when placing tile on enemy monastery -0.5
	return bonus

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

	var best = _pick_best_placement_expert(options)
	return best["cell"]
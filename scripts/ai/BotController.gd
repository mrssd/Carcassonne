extends Node
class_name BotController

const MEEPLE_SCENE: PackedScene = preload("res://scenes/meeple/Meeple.tscn")

var board: Board
var score_system: Node
var turn_system: TurnSystem
var expert_bot: ExpertBot

func setup(p_turn_system: TurnSystem, p_board: Board, p_score_system: Node) -> void:
	turn_system = p_turn_system
	board = p_board
	score_system = p_score_system
	expert_bot = ExpertBot.new()
	expert_bot.setup(self)

# Generates all valid placement options across all 4 rotations.
# Must run on the main thread (rotates the live tile node).
func generate_options() -> Array:
	var current_drawn_tile = turn_system.current_drawn_tile
	var options: Array = []
	for r in range(4):
		for p in board.get_all_valid_placement(current_drawn_tile):
			options.append({"cell": p["cell"], "rotations": r})
		current_drawn_tile.rotate_clockwise()
	return options


# Pure computation — safe to run on a background thread.
func compute_move(bot_type: String, options: Array) -> Dictionary:
	if bot_type == "expert_bot":
		return expert_bot.pick_best_move(options)
	elif bot_type == "smart_bot":
		return _pick_best_placement_minimax(options)
	else:
		return _pick_best_placement(options)


# Applies a computed move to the board. Must run on the main thread.
func apply_move(choice: Dictionary, bot_type: String) -> void:
	var current_drawn_tile = turn_system.current_drawn_tile
	for _i in range(choice["rotations"]):
		current_drawn_tile.rotate_clockwise()

	board.current_tile.visible = true
	board.current_tile.position = board.index_to_coord(choice["cell"])
	turn_system.on_tile_placed()
	Meeple.hide_placement_hints(turn_system.last_placed_tile)

	#Double checking auto skip if no meeples
	if turn_system.phase != TurnSystem.TurnPhase.PLACE_MEEPLE:
		return

	await get_tree().create_timer(0.5).timeout

	if bot_type == "expert_bot":
		var meeple_pos = choice.get("meeple_pos")
		var placed = false
		if meeple_pos != null and turn_system.remaining_meeples[turn_system.current_player_index] > 0:
			var lt = turn_system.last_placed_tile
			if lt != null:
				var seg = Meeple._resolve_segment(lt.tile_data, meeple_pos, lt.rotation_count)
				if seg != "unknown" and not score_system.is_segment_claimed(board, turn_system.last_placed_cell, seg):
					var world_pos = lt.to_global(Vector2(meeple_pos.x, meeple_pos.y) * (Board.CELL_SIZE / 4.0))
					turn_system.place_meeple(world_pos, false)
					placed = true
		if not placed:
			turn_system.end_meeple_phase()
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
			var has_mine = _count_meeples_on_feature(field_dic["visited"], player_index)
			var has_opp = _max_opponent_meeple_count(field_dic["visited"], player_index)
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

		var mine = _count_meeples_on_feature(dic["visited"], player_index)
		var opp  = _max_opponent_meeple_count(dic["visited"], player_index)
		var is_complete = dic["open_ports"] == 0

		#Raw point value of this feature
		var raw: float
		if seg.begins_with("city_"):
			raw = dic["tiles"].size() * 2.0 + dic["shield_count"] * 2.0
		else:
			raw = dic["tiles"].size() * 1.0

		#Completing a feature scores immediately use majority logic for contested features
		if is_complete:
			if mine > opp:
				score += raw * 2.0    # Win majority: full immediate points
			elif mine == opp and mine > 0:
				score += raw * 1.0    # Tie both score, still good
			elif opp > mine and mine > 0:
				score += raw * 0.5    # Lose majority but still score something
			elif opp > 0:
				score -= raw * 1.0    # Opponent wins, completing it for them

		#Incomplete: discount by open ports, weight by meeple advantage
		else:
			var discounted = raw / (dic["open_ports"] + 1.0)
			if mine > 0 and opp == 0:
				score += discounted * 1.5  # Own uncontested feature — extend aggressively
			elif mine > 0 or opp > 0:
				var total = mine + opp
				var advantage = float(mine - opp) / float(total)
				score += discounted * advantage
			else:
				score += discounted * 0.4  # Unclaimed neutral territory

	#Bonus value for placing adjacent to own monastery 
	score += _score_monastery_adjacency(cell, player_index)

	board.placed_tiles.erase(cell)
	return score



#Builds a FeatureDSU from the current board state
func _build_dsu() -> FeatureDSU:
	var dsu = FeatureDSU.new()
	#Make a node per (cell, ceg) and initial_ports = edge.size() 
	for cell in board.placed_tiles.keys():
		var tile = board.placed_tiles[cell]
		for seg in tile.tile_data.internal_connections.keys():
			if seg.begins_with("field_"):
				continue
			var edges = tile.tile_data.internal_connections[seg]
			dsu.make_node(FeatureDSU.node_key(cell, seg), edges.size(), 1 if tile.tile_data.has_shield else 0)
	#Union right and down borders to avoid double unioning each pair
	for cell in board.placed_tiles.keys():
		var tile = board.placed_tiles[cell]
		for seg in tile.tile_data.internal_connections.keys():
			if seg.begins_with("field_"):
				continue
			var nk = FeatureDSU.node_key(cell, seg)
			for edge in tile.tile_data.internal_connections[seg]:
				if edge != 1 and edge != 2:
					continue  # Only process right and down to avoid double-union
				var ncell = cell + score_system.neighbor_directions[edge]
				if not board.placed_tiles.has(ncell):
					continue
				var ntile = board.placed_tiles[ncell]
				var opp_e = score_system.opposite_index[edge]
				var nseg = score_system._find_segment_for_edge(ntile.tile_data, opp_e)
				if nseg == "":
					continue
				var nnk = FeatureDSU.node_key(ncell, nseg)
				if dsu.has_node(nnk):
					dsu.union(nk, nnk)
	#Register meeples on the board
	for cell in board.placed_tiles.keys():
		var tile = board.placed_tiles[cell]
		for slot_id in tile.meeples.keys():
			var seg = score_system._segment_for_slot(slot_id)
			if seg.begins_with("field_") or seg == "monastery" or seg == "center" or seg == "unknown":
				continue
			var nk = FeatureDSU.node_key(cell, seg)
			if dsu.has_node(nk):
				dsu.add_meeple(nk, tile.meeples[slot_id].owner_index)
	return dsu


# Adds a tile to the DSU after it has been placed in board.placed_tiles.
# Unions with all 4 neighbors — safe since the tile is new and can't double-union.
func _dsu_place_tile(dsu: FeatureDSU, cell: Vector2i, tile: Tile) -> void:
	for seg in tile.tile_data.internal_connections.keys():
		if seg.begins_with("field_"):
			continue
		var edges = tile.tile_data.internal_connections[seg]
		dsu.make_node(FeatureDSU.node_key(cell, seg), edges.size(), 1 if tile.tile_data.has_shield else 0)
	for seg in tile.tile_data.internal_connections.keys():
		if seg.begins_with("field_"):
			continue
		var nk = FeatureDSU.node_key(cell, seg)
		for edge in tile.tile_data.internal_connections[seg]:
			var ncell = cell + score_system.neighbor_directions[edge]
			if not board.placed_tiles.has(ncell):
				continue
			var ntile = board.placed_tiles[ncell]
			var opp_e = score_system.opposite_index[edge]
			var nseg = score_system._find_segment_for_edge(ntile.tile_data, opp_e)
			if nseg == "":
				continue
			var nnk = FeatureDSU.node_key(ncell, nseg)
			if dsu.has_node(nnk):
				dsu.union(nk, nnk)


# Evaluates placing tile at cell for player_index using the DSU 
func _dsu_score(dsu: FeatureDSU, cell: Vector2i, tile: Tile, player_index: int) -> float:
	var score: float = 0.0
	var seen: Dictionary = {}  #Features merging the same external root set
	for seg in tile.tile_data.internal_connections.keys():
		if seg.begins_with("field_"):
			continue
		var edges = tile.tile_data.internal_connections[seg]
		var connected_roots: Dictionary = {}
		var total_tc: int = 1
		var total_op: int = 0
		var total_sc: int = 1 if tile.tile_data.has_shield else 0
		var player_counts: Dictionary = {}
		for edge in edges:
			var ncell = cell + score_system.neighbor_directions[edge]
			if not board.placed_tiles.has(ncell):
				total_op += 1
				continue
			var ntile = board.placed_tiles[ncell]
			var opp_e = score_system.opposite_index[edge]
			var nseg = score_system._find_segment_for_edge(ntile.tile_data, opp_e)
			if nseg == "":
				total_op += 1
				continue
			var nnk = FeatureDSU.node_key(ncell, nseg)
			if not dsu.has_node(nnk):
				total_op += 1
				continue
			var root = dsu.find(nnk)
			if not connected_roots.has(root):
				connected_roots[root] = true
				total_tc += dsu.get_tile_count(nnk)
				total_op += dsu.get_open_ports(nnk) - 1  #Their port facing us closes
				total_sc += dsu.get_shield_count(nnk)
				var mc = dsu.get_meeple_counts(nnk)
				for p in mc:
					player_counts[p] = player_counts.get(p, 0) + mc[p]
			else:
				total_op -= 1  #Same root via another edge one more port closes
		total_op = maxi(0, total_op)
		# Dedup key: sorted list of external roots (or own key if isolated)
		var root_list = connected_roots.keys().duplicate()
		root_list.sort()
		if root_list.is_empty():
			root_list.append(FeatureDSU.node_key(cell, seg))
		var dedup = "|".join(root_list)
		if seen.has(dedup):
			continue
		seen[dedup] = true
		var mine: int = player_counts.get(player_index, 0)
		var opp: int = 0
		for p in player_counts:
			if p != player_index:
				opp = maxi(opp, player_counts[p])
		var is_city = seg.begins_with("city_")
		var raw: float = total_tc * (2.0 if is_city else 1.0) + (total_sc * 2.0 if is_city else 0.0)
		if total_op == 0:
			if mine > opp:                       score += raw * 2.0
			elif mine == opp and mine > 0:        score += raw * 1.0
			elif opp > mine and mine > 0:         score += raw * 0.5
			elif opp > 0:                         score -= raw * 1.0
		else:
			var discounted = raw / (total_op + 1.0)
			if mine > 0 and opp == 0:
				score += discounted * 1.5
			elif mine > 0 or opp > 0:
				score += discounted * float(mine - opp) / float(mine + opp)
			else:
				score += discounted * 0.4
	score += _score_monastery_adjacency(cell, player_index)
	return score


#Expert variant: _dsu_score base + meeple economy and late-game rules.
func _dsu_expert_score(dsu: FeatureDSU, cell: Vector2i, tile: Tile, player_index: int) -> float:
	var score = _dsu_score(dsu, cell, tile, player_index)
	var remaining = turn_system.remaining_meeples[player_index]
	var tiles_left = turn_system.tile_deck.get_draw_pile_size()
	var seen: Dictionary = {}
	for seg in tile.tile_data.internal_connections.keys():
		if seg.begins_with("field_"):
			continue
		var edges = tile.tile_data.internal_connections[seg]
		var connected_roots: Dictionary = {}
		var total_op: int = 0
		var total_tc: int = 1
		var has_mine: bool = false
		for edge in edges:
			var ncell = cell + score_system.neighbor_directions[edge]
			if not board.placed_tiles.has(ncell):
				total_op += 1
				continue
			var ntile = board.placed_tiles[ncell]
			var opp_e = score_system.opposite_index[edge]
			var nseg = score_system._find_segment_for_edge(ntile.tile_data, opp_e)
			if nseg == "" or not dsu.has_node(FeatureDSU.node_key(ncell, nseg)):
				total_op += 1
				continue
			var nnk = FeatureDSU.node_key(ncell, nseg)
			var root = dsu.find(nnk)
			if not connected_roots.has(root):
				connected_roots[root] = true
				total_op += dsu.get_open_ports(nnk) - 1
				total_tc += dsu.get_tile_count(nnk)
				if dsu.get_meeple_counts(nnk).get(player_index, 0) > 0:
					has_mine = true
			else:
				total_op -= 1
		total_op = maxi(0, total_op)
		var root_list = connected_roots.keys().duplicate()
		root_list.sort()
		if root_list.is_empty():
			root_list.append(FeatureDSU.node_key(cell, seg))
		var dedup = "|".join(root_list)
		if seen.has(dedup):
			continue
		seen[dedup] = true
		if not has_mine:
			continue
		if remaining <= 2 and total_op == 0:
			score += total_tc * float(3 - remaining)
		if tiles_left <= 15 and total_op > 2:
			score -= (float(total_op) / float(tiles_left + 1)) * total_tc * 0.5
	return score



# Medium bot: DFS-based depth-2 minimax using _greedy_evaluate_placement.
func _pick_best_placement_minimax(options: Array) -> Dictionary:
	var tile = turn_system.current_drawn_tile
	var my_index = turn_system.current_player_index

	# Pre-score with greedy DFS, keep top 8
	var scored = []
	for option in options:
		for _r in range(option["rotations"]): tile.rotate_clockwise()
		scored.append({"option": option, "score": _greedy_evaluate_placement(option["cell"], tile, my_index)})
		for _t in range(4 - option["rotations"]): tile.rotate_clockwise()
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	var candidates = scored.slice(0, min(8, scored.size()))

	var best_score: float = -INF
	var best_option: Dictionary = candidates[0]["option"]

	for entry in candidates:
		var option = entry["option"]
		var my_score: float = entry["score"]  # Reuse from pre-scoring
		for _r in range(option["rotations"]): tile.rotate_clockwise()
		var cell = option["cell"]

		# Temporarily place tile so opponent sees the new board state
		board.placed_tiles[cell] = tile
		var opp_best: float = 0.0
		for opp_i in range(turn_system.players.size()):
			if opp_i == my_index: continue
			for opp_p in board.get_all_valid_placement(tile):
				var s = _greedy_evaluate_placement(opp_p["cell"], tile, opp_i)
				if s > opp_best: opp_best = s
		board.placed_tiles.erase(cell)

		var minimax_score = my_score - opp_best * 0.5
		if minimax_score > best_score:
			best_score = minimax_score
			best_option = option

		for _t in range(4 - option["rotations"]): tile.rotate_clockwise()

	return best_option


#Minimax depth-2 using the expert evaluation function for expert bot
func _pick_best_placement_expert(options: Array) -> Dictionary:
	var dsu = _build_dsu()
	var tile = turn_system.current_drawn_tile
	var my_index = turn_system.current_player_index

	# Pre-score with DSU and keep top 8
	var scored = []
	for option in options:
		for _r in range(option["rotations"]):
			tile.rotate_clockwise()
		scored.append({"option": option, "score": _dsu_score(dsu, option["cell"], tile, my_index)})
		for _t in range(4 - option["rotations"]):
			tile.rotate_clockwise()
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	var candidates = scored.slice(0, min(8, scored.size()))

	var best_score: float = -INF
	var best_option: Dictionary = candidates[0]["option"]

	for entry in candidates:
		var option = entry["option"]
		for _r in range(option["rotations"]):
			tile.rotate_clockwise()

		var cell = option["cell"]
		var my_score = _dsu_expert_score(dsu, cell, tile, my_index)

		dsu.push_checkpoint()
		board.placed_tiles[cell] = tile
		_dsu_place_tile(dsu, cell, tile)

		var opp_best: float = 0.0
		for opp_i in range(turn_system.players.size()):
			if opp_i == my_index:
				continue
			for opp_p in board.get_all_valid_placement(tile):
				var opp_score = _dsu_expert_score(dsu, opp_p["cell"], tile, opp_i)
				if opp_score > opp_best:
					opp_best = opp_score

		board.placed_tiles.erase(cell)
		dsu.pop_checkpoint()

		var minimax_score = my_score - opp_best * 0.5
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

		var temp_value: float = -1.0

		#Field consideration 
		if info["feature"].begins_with("field_"):
			if score_system.is_segment_claimed(board, last_placed_cell, info["feature"]): #skip claimed fields, can't meaningfully contest
				continue
			if tiles_left > 20: #Only thinks when endgame to prevent wasting meeples
				continue
			var field_result = score_system._explore_field(board, last_placed_cell, info["feature"])
			var city_count = score_system._get_adjacent_completed_cities(board, field_result)
			temp_value = city_count * 3.0 * (1.0 - float(tiles_left) / 72.0)
			if temp_value < 3.0: #Threshold, can be changed
				continue

		#Monastery consideration 
		elif info["feature"] == "monastery":
			if score_system.is_segment_claimed(board, last_placed_cell, info["feature"]): #skip claimed monastery
				continue
			var neighbor: int = 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					if board.placed_tiles.has(last_placed_cell + Vector2i(dx, dy)):
						neighbor += 1
			temp_value = neighbor + 1
			if temp_value < 4: #Threshold again
				continue

		#Cities and roads evaluation
		else:
			if score_system.is_segment_claimed(board, last_placed_cell, info["feature"]):
				continue

			var dic = score_system._explore_segment(board, last_placed_cell, info["feature"])
			var raw: float
			if info["feature"].begins_with("city_"):
				raw = dic["tiles"].size() * 2.0 + dic["shield_count"] * 2.0
			else:
				raw = dic["tiles"].size() * 1.0

			temp_value = raw
			if remaining <= 2:
				temp_value *= (1.0 / (dic["open_ports"] + 1.0)) * 2.0

		if temp_value > best_value:
			best_value = temp_value
			best_key = key

	#Stricter threshold when low on meeples to avoid wasting them
	var threshold = 1.0 if remaining > 2 else 3.0
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

func get_best_placement(tile: Tile) -> Dictionary:
	return expert_bot.pick_best_move([])


#Returns the recommended meeple world position for the last placed tile
func get_meeple_hint() -> Variant:
	return _expert_evaluate_meeple()

#Returns number of meeples on a feature for a specific player
func _count_meeples_on_feature(visited: Array, player_index: int) -> int:
	var count = 0
	for entry in visited:
		var parts = entry.split("|")
		var coords = parts[0].split(",")
		var cell = Vector2i(int(coords[0]), int(coords[1]))
		if not board.placed_tiles.has(cell):
			continue
		for meeple in board.placed_tiles[cell].meeples.values():
			if meeple.owner_index == player_index:
				count += 1
	return count

#Returns the highest meeple count any single opponent has on a feature
func _max_opponent_meeple_count(visited: Array, player_index: int) -> int:
	var max_count = 0
	for i in range(turn_system.players.size()):
		if i == player_index:
			continue
		var c = _count_meeples_on_feature(visited, i)
		if c > max_count:
			max_count = c
	return max_count


	
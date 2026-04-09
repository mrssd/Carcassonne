class_name ExpertBot

const PROBING_FACTOR: int = 7 #How many tiles will be picked for further evaluation from prescore
const MAX_MEEPLE_OPTIONS: int = 3 #Max meeple slots considered per cell+rotation
const MAX_DISTINCT_TILES: int = 8 #Top tile types by probability in chance node

var board: Board
var score_system: Node
var turn_system: TurnSystem
var bot: BotController  

#Monastery meeple tracking for search
var _search_monastery_meeples: Dictionary = {} #node_key → player_index
var _monastery_stack: Array = [] #parallel undo stack to DSU

#Field meeple tracking for search
var _search_field_meeples: Dictionary = {} #node_key → player_index
var _field_meeple_stack: Array = [] #parallel undo stack

#Meeple cost tracking during search
var _search_meeple_delta: Dictionary = {} #player_index → meeples spent in search
var _meeple_placed_stack: Array = [] #player_index or -1 per execute_move


func setup(b: BotController) -> void:
	board = b.board
	score_system = b.score_system
	turn_system = b.turn_system
	bot = b


func _score_manager() -> ScoreManager:
	if turn_system.game_manager != null:
		return turn_system.game_manager.score_manager
	return null


#Distinct tile types remaining in the draw pile, capped at MAX_DISTINCT_TILES by probability.
func _get_distinct_tiles() -> Array:
	var type_map: Dictionary = {}
	for td in turn_system.tile_deck._draw_pile:
		if not type_map.has(td.name):
			type_map[td.name] = {"tile_data": td, "count": 0}
		type_map[td.name]["count"] += 1
	var total = float(turn_system.tile_deck.get_draw_pile_size())
	if total == 0.0:
		return []
	var result: Array = []
	for tname in type_map:
		var e = type_map[tname]
		result.append({"tile_data": e["tile_data"], "prob": float(e["count"]) / total})
	# Keep only the most probable types; renormalize so probabilities sum to 1
	result.sort_custom(func(a, b): return a["prob"] > b["prob"])
	if result.size() > MAX_DISTINCT_TILES:
		result = result.slice(0, MAX_DISTINCT_TILES)
		var prob_sum: float = 0.0
		for e in result: prob_sum += e["prob"]
		for e in result: e["prob"] /= prob_sum
	return result


#Lightweight search tile 
func _make_search_tile(tile_data: CarcassonneTileData) -> Tile:
	var t: Tile = board.tile_scene.instantiate()
	#Deep copies internal_connections arrays so rotations don't corrupt the source tile_data.
	t.tile_data = tile_data.duplicate(true)
	for key in t.tile_data.internal_connections:
		t.tile_data.internal_connections[key] = t.tile_data.internal_connections[key].duplicate()
	t.tile_data.edge = t.tile_data.edge.duplicate()
	return t


# Generate all moves for player_index with the given tile (starting at rotation 0).
# Each move = {cell, rotations, meeple_pos (Vector2i or null), seg (String)}.
# After return the tile is back at rotation 0.
func _generate_moves(tile: Tile, player_index: int) -> Array:
	var moves: Array = []
	var remaining = turn_system.remaining_meeples[player_index]
	for r in range(4):
		for p in board.get_all_valid_placement(tile):
			var cell = p["cell"]
			# No-meeple option
			moves.append({"cell": cell, "rotations": r, "meeple_pos": null, "seg": ""})
			# Meeple options: collect all slots, sort by priority, keep top MAX_MEEPLE_OPTIONS
			if remaining > 0:
				var meeple_opts: Array = []
				for pos in tile.tile_data.meeple_positions.keys():
					var seg = Meeple._resolve_segment(tile.tile_data, pos, tile.rotation_count)
					if seg == "unknown" or seg == "center":
						continue
					var pri: int
					if seg.begins_with("city_"):    pri = 0
					elif seg == "monastery":        pri = 1
					elif seg.begins_with("road_"):  pri = 2
					else:                           pri = 3  # field
					meeple_opts.append({"pos": pos, "seg": seg, "pri": pri})
				meeple_opts.sort_custom(func(a, b): return a["pri"] < b["pri"])
				var added = 0
				for mo in meeple_opts:
					if added >= MAX_MEEPLE_OPTIONS:
						break
					if mo["seg"].begins_with("field_"):
						continue  # fields handled separately below
					moves.append({"cell": cell, "rotations": r, "meeple_pos": mo["pos"], "seg": mo["seg"]})
					added += 1
				# In late game, also consider one field meeple option per cell/rotation
				if turn_system.tile_deck.get_draw_pile_size() <= 20:
					for mo in meeple_opts:
						if mo["seg"].begins_with("field_"):
							moves.append({"cell": cell, "rotations": r, "meeple_pos": mo["pos"], "seg": mo["seg"]})
							break  # one field slot per cell/rotation is enough
		tile.rotate_clockwise()  # 4 total → back to rotation 0
	return moves


#Pre-score a move using DSU and papers move-type priority.
func _move_score(move: Dictionary, tile: Tile, dsu: FeatureDSU, player_index: int) -> float:
	var base = bot._dsu_score(dsu, move["cell"], tile, player_index)
	var seg: String = move.get("seg", "")
	if seg.begins_with("city_"):    
		return base + 100.0
	elif seg == "monastery":       
		return base + 80.0
	elif seg.begins_with("road_"):
		return base + 60.0
	elif move["meeple_pos"] == null: 
		return base #no priority bias
	else:                           
		return base - 50.0   #field meeple is low priority
	return base


#Paper evaluation function from player_index perspective.
func _paper_eval(dsu: FeatureDSU, player_index: int) -> float:
	var n = turn_system.players.size()
	var sm = _score_manager()

	#Real scores + complete features found in DSU
	var projected: Array = []
	for i in range(n):
		projected.append(sm.get_score(i) if sm else 0)

	#Meeple_diff × 10 
	var my_meeples = turn_system.remaining_meeples[player_index] - _search_meeple_delta.get(player_index, 0)
	var opp_meeples = 0
	for i in range(n):
		if i != player_index:
			var opp_m = turn_system.remaining_meeples[i] - _search_meeple_delta.get(i, 0)
			opp_meeples = maxi(opp_meeples, opp_m)

	#Feature values + city bonus for incomplete only
	var feature_result: float = 0.0
	var seen: Dictionary = {}
	for cell in board.placed_tiles.keys():
		var t = board.placed_tiles[cell]

		#Monastery evaluation 
		if t.tile_data.is_monastery:
			var owner: int = -1
			for slot_id in t.meeples:
				if score_system._segment_for_slot(slot_id) == "monastery":
					owner = t.meeples[slot_id].owner_index
					break
			if owner < 0:
				var mk = FeatureDSU.node_key(cell, "monastery")
				if _search_monastery_meeples.has(mk):
					owner = _search_monastery_meeples[mk]
			if owner >= 0:
				var neighbors: int = 0
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						if dx == 0 and dy == 0: continue
						if board.placed_tiles.has(cell + Vector2i(dx, dy)):
							neighbors += 1
				var raw = float(neighbors + 1)
				var ownership: float = 1.0 if owner == player_index else -1.0
				feature_result += raw * ownership * 10.0

		for seg in t.tile_data.internal_connections.keys():
			if seg.begins_with("field_"):
				continue
			var nk = FeatureDSU.node_key(cell, seg)
			if not dsu.has_node(nk):
				continue
			var root = dsu.find(nk)
			if seen.has(root):
				continue
			seen[root] = true
			var op = dsu.get_open_ports(nk)
			var tc = dsu.get_tile_count(nk)
			var sc = dsu.get_shield_count(nk)
			var mc = dsu.get_meeple_counts(nk)
			var mine = mc.get(player_index, 0)
			var opp_max = 0
			for p in mc:
				if p != player_index:
					opp_max = maxi(opp_max, mc[p])
			if mine == 0 and opp_max == 0:
				continue  # Unclaimed 
			var is_city = seg.begins_with("city_")
			var raw = tc * (2.0 if is_city else 1.0) + (sc * 2.0 if is_city else 0.0)
			if op == 0:
				#Complete feature in search add points to projected scores of winners
				var max_c = 0
				for p in mc: max_c = maxi(max_c, mc[p])
				if max_c > 0:
					for p in mc:
						if mc[p] == max_c:
							projected[p] += int(raw)
				continue
			#Incomplete discount by open ports 
			var discounted = raw / (float(op) + 1.0)
			var ownership: float
			if mine > opp_max:       ownership = 1.0
			elif mine == opp_max:    ownership = 0.5
			else:                    ownership = -1.0
			feature_result += discounted * ownership * 10.0
			#City bonus: 1.25 per tile for incomplete cities 
			if is_city and mine >= opp_max and mine > 0:
				feature_result += float(tc) * 1.25

	#Field evaluation: only in late game (≤20 tiles left) to avoid BFS overhead
	var tiles_left = turn_system.tile_deck.get_draw_pile_size()
	if tiles_left <= 20:
		var seen_fields: Dictionary = {}
		for cell in board.placed_tiles.keys():
			var t = board.placed_tiles[cell]
			for seg in t.tile_data.internal_connections.keys():
				if not seg.begins_with("field_"):
					continue
				var fkey = str(cell.x) + "," + str(cell.y) + "|" + seg
				if seen_fields.has(fkey):
					continue
				var field_result = score_system._explore_field(board, cell, seg)
				#Mark all visited (cell|seg) entries so we don't re evaluate this field
				for vk in field_result["visited"]:
					seen_fields[vk] = true
				var owners = score_system._get_meeple_owners(board, field_result)
				#Supplement with search-placed field meeples
				for vk in field_result["visited"]:
					if _search_field_meeples.has(vk):
						var p = _search_field_meeples[vk]
						owners[p] = owners.get(p, 0) + 1
				if owners.is_empty():
					continue
				var cities = score_system._get_adjacent_completed_cities(board, field_result)
				if cities == 0:
					continue
				var raw = float(cities) * 3.0
				var mine = owners.get(player_index, 0)
				var opp_max = 0
				for p in owners:
					if p != player_index:
						opp_max = maxi(opp_max, owners[p])
				var ownership: float
				if mine > opp_max:       ownership = 1.0
				elif mine == opp_max:    ownership = 0.5
				else:                    ownership = -1.0
				feature_result += raw * ownership * 10.0

	#Projected score_diff × 100
	var opp_projected = 0
	for i in range(n):
		if i != player_index:
			opp_projected = maxi(opp_projected, projected[i])
	return float(projected[player_index] - opp_projected) * 100.0 \
		+ float(my_meeples - opp_meeples) * 10.0 \
		+ feature_result


#Execute a move into the DSU and board
func _execute_move(dsu: FeatureDSU, move: Dictionary, tile: Tile, player_index: int) -> void:
	var cell = move["cell"]
	board.placed_tiles[cell] = tile
	bot._dsu_place_tile(dsu, cell, tile)
	var seg: String = move.get("seg", "")
	var monastery_key: String = ""
	var field_key: String = ""
	var meeple_placed: int = -1
	if move.get("meeple_pos") != null and seg != "" and seg != "unknown":
		if seg == "monastery":
			monastery_key = FeatureDSU.node_key(cell, "monastery")
			_search_monastery_meeples[monastery_key] = player_index
			meeple_placed = player_index
		elif seg.begins_with("field_"):
			field_key = FeatureDSU.node_key(cell, seg)
			_search_field_meeples[field_key] = player_index
			meeple_placed = player_index
		else:
			var nk = FeatureDSU.node_key(cell, seg)
			if dsu.has_node(nk):
				dsu.add_meeple(nk, player_index)
				meeple_placed = player_index
	_monastery_stack.append(monastery_key)
	_field_meeple_stack.append(field_key)
	_meeple_placed_stack.append(meeple_placed)
	if meeple_placed >= 0:
		_search_meeple_delta[meeple_placed] = _search_meeple_delta.get(meeple_placed, 0) + 1


#Undo the last executed move
func _undo_move(dsu: FeatureDSU, cell: Vector2i) -> void:
	board.placed_tiles.erase(cell)
	dsu.pop_checkpoint()
	var mk: String = _monastery_stack.pop_back()
	if mk != "":
		_search_monastery_meeples.erase(mk)
	var fk: String = _field_meeple_stack.pop_back()
	if fk != "":
		_search_field_meeples.erase(fk)
	var mp: int = _meeple_placed_stack.pop_back()
	if mp >= 0:
		_search_meeple_delta[mp] -= 1


#Player_index places tile, picks best among top PROBING_FACTOR moves.
func _max_node(dsu: FeatureDSU, depth: int, alpha: float, beta: float,
		player_index: int, moves: Array, tile: Tile) -> float:
	if moves.is_empty():
		return _paper_eval(dsu, player_index)
	var scored: Array = []
	for move in moves:
		for _r in range(move["rotations"]): tile.rotate_clockwise()
		scored.append({"move": move, "score": _move_score(move, tile, dsu, player_index)})
		for _t in range(4 - move["rotations"]): tile.rotate_clockwise()
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	var n = min(PROBING_FACTOR, scored.size())
	var best = -INF
	for i in range(n):
		var move = scored[i]["move"]
		var cell = move["cell"]
		for _r in range(move["rotations"]): tile.rotate_clockwise()
		dsu.push_checkpoint()
		_execute_move(dsu, move, tile, player_index)
		var val: float
		if depth <= 1:
			val = _paper_eval(dsu, player_index)
		else:
			var next_player = (player_index + 1) % turn_system.players.size()
			val = -_chance_node(dsu, depth - 1, -beta, -alpha, next_player)
		_undo_move(dsu, cell)
		for _t in range(4 - move["rotations"]): tile.rotate_clockwise()
		if val > best: best = val
		alpha = maxf(alpha, val)
		if alpha >= beta: break  # Star1 pruning
	return best


#Player_index draws a tile — weighted expected value over distinct types.
func _chance_node(dsu: FeatureDSU, depth: int, alpha: float, beta: float, player_index: int) -> float:
	var distinct = _get_distinct_tiles()
	if distinct.is_empty():
		return _paper_eval(dsu, player_index)
	var expected: float = 0.0
	for entry in distinct:
		var temp = _make_search_tile(entry["tile_data"])
		var moves = _generate_moves(temp, player_index)
		var val: float
		if moves.is_empty():
			val = _paper_eval(dsu, player_index)
		else:
			val = _max_node(dsu, depth, -INF, INF, player_index, moves, temp)
		temp.free()
		expected += entry["prob"] * val
	return expected


#Returns {cell, rotations, meeple_pos, seg} for ref
func pick_best_move(options: Array) -> Dictionary:
	_search_monastery_meeples.clear()
	_monastery_stack.clear()
	_search_field_meeples.clear()
	_field_meeple_stack.clear()
	_search_meeple_delta.clear()
	_meeple_placed_stack.clear()
	var dsu = bot._build_dsu()
	var real_tile = turn_system.current_drawn_tile
	var my_index = turn_system.current_player_index

	#Use a normalized copy at rotation 0 
	var tile = _make_search_tile(real_tile.tile_data)
	var to_zero = (4 - real_tile.rotation_count) % 4
	for _i in range(to_zero):
		tile.tile_data.rotate_clockwise()

	var all_moves = _generate_moves(tile, my_index)
	if all_moves.is_empty():
		if not options.is_empty():
			return {"cell": options[0]["cell"], "rotations": options[0]["rotations"],
					"meeple_pos": null, "seg": ""}
		return {}

	#Pre-score and keep top PROBING_FACTOR
	var scored: Array = []
	for move in all_moves:
		for _r in range(move["rotations"]): tile.rotate_clockwise()
		scored.append({"move": move, "score": _move_score(move, tile, dsu, my_index)})
		for _t in range(4 - move["rotations"]): tile.rotate_clockwise()
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	var n = min(PROBING_FACTOR, scored.size())

	var best_score = -INF
	var best_move = scored[0]["move"]
	var alpha = -INF
	var beta = INF

	for i in range(n):
		var move = scored[i]["move"]
		var cell = move["cell"]
		for _r in range(move["rotations"]): tile.rotate_clockwise()
		dsu.push_checkpoint()
		_execute_move(dsu, move, tile, my_index)
		var opp = (my_index + 1) % turn_system.players.size()
		var val = -_chance_node(dsu, 1, -beta, -alpha, opp)
		_undo_move(dsu, cell)
		for _t in range(4 - move["rotations"]): tile.rotate_clockwise()
		print("[ExpertBot] move %d: cell=%s rot=%d seg='%s' val=%.2f prescore=%.2f" % [i, str(cell), move["rotations"], move.get("seg",""), val, scored[i]["score"]])
		var is_better = val > best_score or (val == best_score and (
			move["cell"].x < best_move["cell"].x or
			(move["cell"].x == best_move["cell"].x and move["cell"].y < best_move["cell"].y)))
		if is_better:
			best_score = val
			best_move = move
		alpha = maxf(alpha, val)
		if alpha >= beta: break

	tile.free()
	print("[ExpertBot] best: cell=%s rot=%d seg='%s' score=%.2f" % [str(best_move["cell"]), best_move["rotations"], best_move.get("seg",""), best_score])
	return best_move

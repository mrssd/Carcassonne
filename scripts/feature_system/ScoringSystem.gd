extends Node
class_name ScoringSystem

# Simple scoring system for completed features (roads, cities, monasteries)
# Works without meeples. When a feature becomes COMPLETE (closed),
# points are added and printed via ScoreManager (if present).

const ROAD_POINTS_PER_TILE: int = 1
const CITY_POINTS_PER_TILE: int = 2
const MONASTERY_COMPLETE_POINTS: int = 9

# neighbor directions corresponding to tile edges: TOP, RIGHT, BOTTOM, LEFT
var neighbor_directions: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var opposite_index := [2, 3, 0, 1]

# fallback scoreboard (only used if no ScoreManager exists in the scene)
var player_scores: Array = []

# if true, prints extra diagnostics
var debug_mode: bool = false

# cached ScoreManager reference
var _score_manager: ScoreManager = null

# IMPORTANT: remembers which completed features have already been scored
# key format: "<prop_type>|<sorted_cells>"
var _scored_features: Dictionary = {}


func _get_score_manager(ctx: Node = null) -> ScoreManager:
	if _score_manager != null:
		return _score_manager

	var scene_root: Node = null
	if ctx != null and ctx.get_tree() != null:
		scene_root = ctx.get_tree().get_current_scene()
	elif get_tree() != null:
		scene_root = get_tree().get_current_scene()

	if scene_root == null:
		push_warning("ScoringSystem._get_score_manager: no current scene available to locate ScoreManager.")
		return null

	var stack: Array = [scene_root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n.name == "ScoreManager":
			_score_manager = n
			return _score_manager
		for child in n.get_children():
			if child is Node:
				stack.append(child)

	return null


func init(player_count: int) -> void:
	# reset scoreboard + scored feature memory for a fresh match
	player_scores = []
	for i in range(player_count):
		player_scores.append(0)
	_scored_features.clear()


func add_score(player_index: int, points: int, feature: String = "", ctx: Node = null) -> void:
	var sm = _get_score_manager(ctx)
	if sm:
		sm.add_score(player_index, points, feature)
		return

	# fallback
	if player_index < 0:
		return
	while player_index >= player_scores.size():
		player_scores.append(0)
	player_scores[player_index] += points

	if feature != "":
		print("Player %d scored %d (total %d) by completing %s" % [player_index + 1, points, player_scores[player_index], feature])
	else:
		print("Player %d scored %d (total %d)" % [player_index + 1, points, player_scores[player_index]])


func get_player_score(player_index: int) -> int:
	var sm = _get_score_manager()
	if sm:
		return sm.get_score(player_index)
	if player_index < 0 or player_index >= player_scores.size():
		return 0
	return player_scores[player_index]


func _make_feature_key(property_type: int, tiles_set: Array) -> String:
	# tiles_set is Array[Vector2i]
	# build a stable sorted key so the same feature always hashes the same way
	var parts: Array = []
	for c in tiles_set:
		parts.append(str(c.x) + "," + str(c.y))
	parts.sort()
	return str(property_type) + "|" + "|".join(parts)


# Main entry: call this AFTER a tile is successfully placed into board.placed_tiles
func score_and_apply(board: Node, placed_cell: Vector2i, player_index: int) -> Dictionary:
	var result: Dictionary = {
		"player_index": player_index,
		"points_awarded": 0,
		"details": []
	}

	if board == null:
		push_error("ScoringSystem: board is null.")
		return result

	if not board.placed_tiles.has(placed_cell):
		return result

	var tile_node: Tile = board.placed_tiles[placed_cell]
	if tile_node == null:
		return result

	# local dedupe for THIS placement only (so we don't score same feature twice from two sides)
	var local_scored_keys: Dictionary = {}

	# 1) Roads and Cities
	var edges: Array = tile_node.get_edges()
	for side in range(4):
		var prop = edges[side]
		if prop != CarcassonneTileData.PropertyType.ROAD and prop != CarcassonneTileData.PropertyType.CITY:
			continue

		var explore_res: Dictionary = _explore_feature(board, placed_cell, prop)
		var tiles_set: Array = explore_res["tiles_set"]
		var open_edges: int = explore_res["open_edges"]

		if tiles_set.is_empty():
			continue

		# only score if COMPLETE (no open edges)
		if open_edges != 0:
			if debug_mode:
				print("ScoringSystem: feature not complete. prop=", prop, "tiles=", tiles_set, "open_edges=", open_edges)
			continue

		var key: String = _make_feature_key(prop, tiles_set)

		# prevent double-score in same placement
		if local_scored_keys.has(key):
			continue
		local_scored_keys[key] = true

		# prevent re-scoring same completed feature later turns
		if _scored_features.has(key):
			continue
		_scored_features[key] = true

		# award points
		if prop == CarcassonneTileData.PropertyType.ROAD:
			var pts: int = tiles_set.size() * ROAD_POINTS_PER_TILE
			add_score(player_index, pts, "road", board)
			result["points_awarded"] += pts
			result["details"].append({"type": "ROAD", "tiles": tiles_set.duplicate(), "points": pts})

		elif prop == CarcassonneTileData.PropertyType.CITY:
			var pts2: int = tiles_set.size() * CITY_POINTS_PER_TILE
			add_score(player_index, pts2, "city", board)
			result["points_awarded"] += pts2
			result["details"].append({"type": "CITY", "tiles": tiles_set.duplicate(), "points": pts2})

	# 2) Monastery (optional — only if your tiles actually mark monastery in edges or name)
	if _is_monastery_tile(tile_node):
		var surrounding_count: int = _count_surrounding_tiles(board, placed_cell)
		if surrounding_count == 8:
			# monastery should also only score once
			var mkey := "MONASTERY|" + str(placed_cell.x) + "," + str(placed_cell.y)
			if not _scored_features.has(mkey):
				_scored_features[mkey] = true
				add_score(player_index, MONASTERY_COMPLETE_POINTS, "monastery", board)
				result["points_awarded"] += MONASTERY_COMPLETE_POINTS
				result["details"].append({"type": "MONASTERY", "cell": placed_cell, "points": MONASTERY_COMPLETE_POINTS})

	return result


# Explore a connected feature (road or city) using adjacency matching.
# Returns { tiles_set: Array[Vector2i], open_edges: int }
func _explore_feature(board: Node, start_cell: Vector2i, property_type: int) -> Dictionary:
	var tiles_set: Array = []
	var visited: Dictionary = {}
	var stack: Array = []

	stack.append(start_cell)
	visited[start_cell] = true

	while stack.size() > 0:
		var cell: Vector2i = stack.pop_back()
		tiles_set.append(cell)

		var tile: Tile = board.placed_tiles[cell]
		if tile == null:
			continue

		var t_edges: Array = tile.get_edges()

		for s in range(4):
			if t_edges[s] != property_type:
				continue

			var neighbor_cell: Vector2i = cell + neighbor_directions[s]

			if board.placed_tiles.has(neighbor_cell):
				var neighbor_tile: Tile = board.placed_tiles[neighbor_cell]
				if neighbor_tile == null:
					continue
				var neighbor_edges: Array = neighbor_tile.get_edges()

				# only connect across this edge if neighbor matches on opposite edge
				if neighbor_edges[opposite_index[s]] == property_type:
					if not visited.has(neighbor_cell):
						visited[neighbor_cell] = true
						stack.append(neighbor_cell)

	# compute open edges for this collected set
	var open_edges: int = 0
	for cell in tiles_set:
		var tile2: Tile = board.placed_tiles[cell]
		if tile2 == null:
			continue
		var e2: Array = tile2.get_edges()

		for s in range(4):
			if e2[s] != property_type:
				continue

			var ncell: Vector2i = cell + neighbor_directions[s]
			if not board.placed_tiles.has(ncell):
				open_edges += 1
			else:
				var ntile: Tile = board.placed_tiles[ncell]
				if ntile == null:
					open_edges += 1
				else:
					var ne: Array = ntile.get_edges()
					if ne[opposite_index[s]] != property_type:
						open_edges += 1

	return {"tiles_set": tiles_set, "open_edges": open_edges}


func _count_surrounding_tiles(board: Node, center_cell: Vector2i) -> int:
	var offsets: Array = [
		Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
		Vector2i(-1,0),                 Vector2i(1,0),
		Vector2i(-1,1),  Vector2i(0,1),  Vector2i(1,1)
	]
	var count: int = 0
	for o in offsets:
		var n = center_cell + o
		if board.placed_tiles.has(n):
			count += 1
	return count


func _is_monastery_tile(tile: Tile) -> bool:
	if tile == null or tile.tile_data == null:
		return false

	# if your data encodes monastery in edges:
	var edges: Array = tile.get_edges()
	for e in edges:
		if e == CarcassonneTileData.PropertyType.MONASTERY:
			return true

	# fallback: name contains monastery
	var nm: String = tile.tile_data.name.to_lower()
	if nm.find("monast") != -1:
		return true

	return false
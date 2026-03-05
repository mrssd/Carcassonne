extends Node
class_name ScoringSystem

const ROAD_POINTS_PER_TILE: int = 1
const CITY_POINTS_PER_TILE: int = 2
const MONASTERY_COMPLETE_POINTS: int = 9

var neighbor_directions: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var opposite_index := [2, 3, 0, 1]

var player_scores: Array = []
var debug_mode: bool = false
var _score_manager: ScoreManager = null

# remembers which completed features already scored (prevents double-score)
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
	player_scores = []
	for i in range(player_count):
		player_scores.append(0)
	_scored_features.clear()
	_score_manager = null


func add_score(player_index: int, points: int, feature: String = "", ctx: Node = null) -> void:
	var sm = _get_score_manager(ctx)
	if sm:
		sm.add_score(player_index, points, feature)
		return

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
	var parts: Array = []
	for c in tiles_set:
		parts.append(str(c.x) + "," + str(c.y))
	parts.sort()
	return str(property_type) + "|" + "|".join(parts)


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

	# local dedupe for this single placement (same feature discovered from multiple sides)
	var local_scored: Dictionary = {}

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

		if open_edges != 0:
			if debug_mode:
				print("ScoringSystem: not complete prop=", prop, "tiles=", tiles_set, "open_edges=", open_edges)
			continue

		var key: String = _make_feature_key(prop, tiles_set)

		if local_scored.has(key):
			continue
		local_scored[key] = true

		if _scored_features.has(key):
			continue
		_scored_features[key] = true

		if prop == CarcassonneTileData.PropertyType.ROAD:
			var pts: int = tiles_set.size() * ROAD_POINTS_PER_TILE
			add_score(player_index, pts, "road", board)
			result["points_awarded"] += pts
			result["details"].append({"type": "ROAD", "tiles": tiles_set.duplicate(), "points": pts})
		else:
			var pts2: int = tiles_set.size() * CITY_POINTS_PER_TILE
			add_score(player_index, pts2, "city", board)
			result["points_awarded"] += pts2
			result["details"].append({"type": "CITY", "tiles": tiles_set.duplicate(), "points": pts2})

	# 2) Monastery (your deck uses "cloister"/"cloisterr" names, not MONASTERY edges)
	if _is_monastery_tile(tile_node):
		var surrounding_count = _count_surrounding_tiles(board, placed_cell)
		if surrounding_count == 8:
			var mkey := "MONASTERY|" + str(placed_cell.x) + "," + str(placed_cell.y)
			if not _scored_features.has(mkey):
				_scored_features[mkey] = true
				add_score(player_index, MONASTERY_COMPLETE_POINTS, "monastery", board)
				result["points_awarded"] += MONASTERY_COMPLETE_POINTS
				result["details"].append({"type": "MONASTERY", "cell": placed_cell, "points": MONASTERY_COMPLETE_POINTS})

	return result


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
				if neighbor_edges[opposite_index[s]] == property_type:
					if not visited.has(neighbor_cell):
						visited[neighbor_cell] = true
						stack.append(neighbor_cell)

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

	# If your data ever uses MONASTERY edges, this supports it:
	var edges: Array = tile.get_edges()
	for e in edges:
		if e == CarcassonneTileData.PropertyType.MONASTERY:
			return true

	# Your current deck uses names like "cloister" / "cloisterr"
	var nm: String = tile.tile_data.name.to_lower()
	if nm.find("cloister") != -1 or nm.find("monast") != -1:
		return true

	return false
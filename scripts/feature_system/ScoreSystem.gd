class_name ScoreSystem extends Node

signal meeple_returned(player_index: int)

@onready var score_manager : ScoreManager = $"../ScoreManager"
@onready var game_manager = $"../GameManager"

# Constant variables for scores
const ROAD_POINTS_PER_TILE : int = 1
const CITY_POINTS_PER_TILE : int = 2
const MONASTERY_COMPLETE_POINTS : int = 9

# Array to point to neighbouring cell, so [0] would be the tile on top
var neighbor_directions : Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# Array to map a tile's edge to another tile's edge
var opposite_index : Array = [2, 3, 0, 1]

# Prevent double scoring from the same features
var _scored_features : Dictionary = {}

#Find which segment that edge belongs to
func _find_segment_for_edge(tile_data : CarcassonneTileData, edge_index : int):
	for segment_key in tile_data.internal_connections:
		if (tile_data.internal_connections[segment_key].has(edge_index)):
				return segment_key
	return ""

#Traces feature from specific segment(feature) or tile
func _explore_segment(board, start_cell, segment_key):
	var stack: Array = [[start_cell, segment_key]] # Each entry is [cell, segment_key], stack for traversal
	var visited: Dictionary = {} #dictionary for visited segments
	var unique_tiles: Dictionary = {} #dictionary for unique tiles
	var open_ports: int = 0 #open ends
	var shield_count: int = 0 #shields

	#depth-first traversal to explore segments 
	while not stack.is_empty():
		var entry = stack.pop_back() #pops the next segment to explore
		var cell = entry[0]
		var seg_key = entry[1]
		var visit_key = str(cell.x) + "," + str(cell.y) + "|" + seg_key #make unique key for segment
		if visited.has(visit_key): #skips if the thing is visited
			continue
		visited[visit_key] = true

		if not unique_tiles.has(cell): #add tile if it hasnt been counted
			unique_tiles[cell] = true
			var tile0 = board.placed_tiles[cell]
			if tile0.tile_data.has_shield: #increment shield if shield
				shield_count += 1


		var tile = board.placed_tiles[cell]
		var edges = tile.tile_data.internal_connections[seg_key]
		for edge_index in edges:
			var neighbor_cell = cell + neighbor_directions[edge_index] #calculate neighbor cell
			if not board.placed_tiles.has(neighbor_cell): #if no neighbour tile add open port
				open_ports += 1 
			else:
				var neighbor_tile = board.placed_tiles[neighbor_cell] 
				var opposite_edge = opposite_index[edge_index]
				var neighbor_seg_key = _find_segment_for_edge(neighbor_tile.tile_data, opposite_edge)
				if neighbor_seg_key == "": 
					open_ports += 1
				else:
					var neighbor_visit_key = str(neighbor_cell.x) + "," + str(neighbor_cell.y) + "|" + neighbor_seg_key
					if not visited.has(neighbor_visit_key):
						stack.append([neighbor_cell, neighbor_seg_key])

	return {
		"tiles": unique_tiles.keys(),
		"open_ports": open_ports,
		"shield_count": shield_count,
		"visited": visited.keys()
	}

# Determines what the segment is
func _get_feature_type(segment_key, _tile_data):
	if segment_key.begins_with("road"):
		return "road"
	elif segment_key.begins_with("city"):
		return "city"
	else:
		return "other"

func score_and_apply(board, placed_cell, player_index):
	var tile = board.placed_tiles[placed_cell]
	if tile == null:
		return

	for segment_key in tile.tile_data.internal_connections.keys():
		var feature_type = _get_feature_type(segment_key, tile.tile_data)
		if feature_type == "other": #skip if not road or city
			continue

		var explore_result = _explore_segment(board, placed_cell, segment_key) #explore segment 
		var visited_keys = explore_result["visited"] #build key for feature
		visited_keys.sort()
		var feature_key = "|".join(visited_keys)

		if _scored_features.has(feature_key):
			continue

		if explore_result["open_ports"] == 0: #if feature is complete (no open end), add points to player
			_scored_features[feature_key] = true
			var points = 0
			if feature_type == "road":
				points = explore_result["tiles"].size() * ROAD_POINTS_PER_TILE
			elif feature_type == "city":
				points = explore_result["tiles"].size() * CITY_POINTS_PER_TILE + explore_result["shield_count"] * 2
			score_manager.add_score(player_index, points)
			_return_meeples(board, explore_result["tiles"])

	_check_monasteries(board, placed_cell, player_index)


func _check_monasteries(board, placed_cell, player_index):
	#define offset for surrrounding cells
	var offsets = [
		Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
		Vector2i(-1,0),                 Vector2i(1,0),
		Vector2i(-1,1),  Vector2i(0,1),  Vector2i(1,1)
	]
	#build an array of lists of tiles to check
	var cells_to_check = [placed_cell]
	for offset in offsets:
		cells_to_check.append(placed_cell + offset)

	#if its a monestary, count surrounding tiles
	for cell in cells_to_check:
		if not board.placed_tiles.has(cell):
			continue
		var tile = board.placed_tiles[cell]
		if tile.tile_data.is_monastery:
			var surrounding_count = 0
			for offset in offsets:
				var neighbor = cell + offset
				if board.placed_tiles.has(neighbor):
					surrounding_count += 1
			if surrounding_count == 8: #if 8 surrounding tiles and not scored, award points and mark as scored
				var mkey = "monastery|" + str(cell.x) + "," + str(cell.y)
				if not _scored_features.has(mkey):
					_scored_features[mkey] = true
					score_manager.add_score(player_index, MONASTERY_COMPLETE_POINTS)
					_return_meeples(board, [cell])


func is_feature_claimed(board, cell: Vector2i) -> bool:
	var tile = board.placed_tiles[cell]
	if tile == null:
		return false

	for segment_key in tile.tile_data.internal_connections.keys():
		var feature_type = _get_feature_type(segment_key, tile.tile_data)
		if feature_type == "other":
			continue
		var explore_result = _explore_segment(board, cell, segment_key)
		for feature_cell in explore_result["tiles"]:
			var feature_tile = board.placed_tiles[feature_cell]
			if feature_tile.meeple != null:
				return true

	if tile.tile_data.is_monestary and tile.meeple != null:
		return true

	return false


func _return_meeples(board, cells: Array) -> void:
	for cell in cells:
		var tile = board.placed_tiles[cell]
		if tile.meeple != null:
			var owner = tile.meeple.owner_index
			tile.meeple.remove()
			tile.meeple = null
			meeple_returned.emit(owner)

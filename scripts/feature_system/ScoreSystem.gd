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

func score_and_apply(board, placed_cell):
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
			var owners = _get_meeple_owners(board, explore_result)
			_award_to_majority(owners, points)
			_return_meeples(board, explore_result)

	_check_monasteries(board, placed_cell)


func _check_monasteries(board, placed_cell):
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
					var monastery_result = {
						"tiles": [cell],
						"visited": [str(cell.x) + "," + str(cell.y) + "|monastery"]
					}
					var owners = _get_meeple_owners(board, monastery_result)
					_award_to_majority(owners, MONASTERY_COMPLETE_POINTS)
					_return_meeples(board, monastery_result)


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
			if not feature_tile.meeples.is_empty():
				return true

	if tile.tile_data.is_monastery and not tile.meeples.is_empty():
		return true

	return false

# Returns which segment key a meeple slot belongs to on a tile,
# by mapping the slot's grid position to the nearest edge.
func _segment_for_slot(tile_data: CarcassonneTileData, slot_id: String) -> String:
	if tile_data.is_monastery:
		return "monastery"
	var parts = slot_id.split("_")
	var x = int(parts[0])
	var y = int(parts[1])
	var edge: int
	if abs(x) >= abs(y):
		edge = 1 if x > 0 else 3
	else:
		edge = 0 if y < 0 else 2
	for seg_key in tile_data.internal_connections:
		if tile_data.internal_connections[seg_key].has(edge):
			return seg_key
	return ""

# Collects meeple counts per player, only counting meeples whose position
# maps to a segment that is part of the feature in explore_result.
func _get_meeple_owners(board, explore_result: Dictionary) -> Dictionary:
	var counts = {}
	# Build map: "cx,cy" -> [segment_keys that belong to this feature]
	var cell_to_segs = {}
	for vkey in explore_result["visited"]:
		var parts = vkey.split("|")
		var cell_str = parts[0]
		var seg_key = parts[1]
		if not cell_to_segs.has(cell_str):
			cell_to_segs[cell_str] = []
		cell_to_segs[cell_str].append(seg_key)
	for cell in explore_result["tiles"]:
		var cell_str = str(cell.x) + "," + str(cell.y)
		var feature_segs = cell_to_segs.get(cell_str, [])
		var tile = board.placed_tiles[cell]
		for slot_id in tile.meeples.keys():
			var seg = _segment_for_slot(tile.tile_data, slot_id)
			if feature_segs.has(seg):
				var owner = tile.meeples[slot_id].owner_index
				counts[owner] = counts.get(owner, 0) + 1
	return counts

#if two players have same meeple, this functions finds the max count and awards full point to all players tied
func _award_to_majority(counts: Dictionary, points: int) -> void:
	if counts.is_empty():
		return
	var max_count = counts.values().max()
	for player in counts:
		if counts[player] == max_count:
			score_manager.add_score(player, points)

func _return_meeples(board, explore_result: Dictionary) -> void:
	var cell_to_segs = {}
	for vkey in explore_result["visited"]:
		var parts = vkey.split("|")
		var cell_str = parts[0]
		var seg_key = parts[1]
		if not cell_to_segs.has(cell_str):
			cell_to_segs[cell_str] = []
		cell_to_segs[cell_str].append(seg_key)
	for cell in explore_result["tiles"]:
		var cell_str = str(cell.x) + "," + str(cell.y)
		var feature_segs = cell_to_segs.get(cell_str, [])
		var tile = board.placed_tiles[cell]
		var to_remove = []
		for slot_id in tile.meeples.keys():
			if feature_segs.has(_segment_for_slot(tile.tile_data, slot_id)):
				to_remove.append(slot_id)
		for slot_id in to_remove:
			var m = tile.meeples[slot_id]
			var owner = m.owner_index
			m.remove()
			tile.meeples.erase(slot_id)
			meeple_returned.emit(owner)

class_name ScoreSystem extends Node

signal meeple_returned(player_index: int)

@onready var score_manager : ScoreManager = $"../ScoreManager"
@onready var game_manager = $"../GameManager"

# Constant variables for scores
const ROAD_POINTS_PER_TILE : int = 1
const CITY_POINTS_PER_TILE : int = 2
const MONASTERY_COMPLETE_POINTS : int = 9

#Array to point to neighbouring cell, so [0] would be the tile on top
var neighbor_directions : Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

#Array to map a tile's edge to another tile's edge
var opposite_index : Array = [2, 3, 0, 1]

# Field numbering reference
#     [0][1]
# [7]       [2]
# [6]       [3]
#     [5][4]

#Lookup table mapping where each half edge connects to which half edge of neighbour
const HALF_EDGE_CONNECTIONS = [
	[0, 5], 
	[0, 4],  
	[1, 7],  
	[1, 6], 
	[2, 1], 
	[2, 0],  
	[3, 3],  
	[3, 2], 
]

#Maps edges to half edges
const EDGE_TO_HALF_EDGES = [[0, 1], [2, 3], [4, 5], [6, 7]]

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
	elif segment_key.begins_with("field"):
		return "field"
	else:
		return "other"

func score_and_apply(board, placed_cell):
	var tile = board.placed_tiles[placed_cell]
	if tile == null:
		return

	for segment_key in tile.tile_data.internal_connections.keys():
		var feature_type = _get_feature_type(segment_key, tile.tile_data)
		if feature_type == "other" or feature_type == "field": #skip if not road or city (fields score at end game only)
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

#end game score function
func score_end_game(board) -> void:
	var end_scored: Dictionary = {} #local dictionary to track features scored to prevent double counting
	var offsets = [
		Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
		Vector2i(-1,0),                  Vector2i(1,0),
		Vector2i(-1,1),  Vector2i(0,1),  Vector2i(1,1)
	]

	for cell in board.placed_tiles.keys(): #loops though every tile on board
		var tile = board.placed_tiles[cell]
		for segment_key in tile.tile_data.internal_connections.keys(): #loops through every feature on that tile
			var feature_type = _get_feature_type(segment_key, tile.tile_data)
			if feature_type == "other" or feature_type == "field":
				continue

			var explore_result = _explore_segment(board, cell, segment_key) #explore connected feature from this tile/segment
			var visited_keys = explore_result["visited"]
			visited_keys.sort()
			var feature_key = "|".join(visited_keys) #make the current feature a key
			if _scored_features.has(feature_key) or end_scored.has(feature_key): #skips the process if it was already scored midgame
				continue
			end_scored[feature_key] = true

			var owners = _get_meeple_owners(board, explore_result) #find which owner owns the feature
			if owners.is_empty(): #nobody owns feature then skip
				continue

			var points = 0
			if feature_type == "road": #if its a road same 1pt as midgame
				points = explore_result["tiles"].size() * ROAD_POINTS_PER_TILE
			elif feature_type == "city": #if its a city the score should be halfed
				points = explore_result["tiles"].size() + explore_result["shield_count"]
			_award_to_majority(owners, points) #award point
			_return_meeples(board, explore_result) #return meeple (for no reason tbh)

		if tile.tile_data.is_monastery: #monestary doesnt use internal connections so separate if statement to deal with it
			var mkey = "monastery|" + str(cell.x) + "," + str(cell.y) 
			if not _scored_features.has(mkey): #if that monestary is not scored
				var surrounding_count = 0 #var to count surrounding tiles
				for offset in offsets: 
					if board.placed_tiles.has(cell + offset): 
						surrounding_count += 1
				var monastery_result = {
					"tiles": [cell],
					"visited": [str(cell.x) + "," + str(cell.y) + "|monastery"]
				}
				var owners = _get_meeple_owners(board, monastery_result)
				if not owners.is_empty(): #if theres a owner
					_award_to_majority(owners, 1 + surrounding_count) #award the score
					_return_meeples(board, monastery_result)

	score_end_game_farmers(board)

#Awards 3*completed adjacent cities points to the player with most farmers on the tile
func score_end_game_farmers(board) -> void:
	var scored_fields: Dictionary = {} #Dictionary to prevent double scoring
	for cell in board.placed_tiles.keys(): #Loops through all placed tiles
		var tile = board.placed_tiles[cell]
		for seg_key in tile.tile_data.internal_connections.keys():
			if not seg_key.begins_with("field_"):
				continue
			var field_result = _explore_field(board, cell, seg_key)
			var visited_keys = field_result["visited"].duplicate()
			visited_keys.sort()
			var field_key = "|".join(visited_keys)
			if scored_fields.has(field_key):
				continue
			scored_fields[field_key] = true
			var owners = _get_meeple_owners(board, field_result)
			var city_count = _get_adjacent_completed_cities(board, field_result)
			print("[FARMER] Field: %d tile(s), cities: %d, owners: %s" % [field_result["tiles"].size(), city_count, owners])
			if owners.is_empty():
				continue
			_award_to_majority(owners, city_count * 3)
			print("[FARMER] Awarded %d pts to majority of %s" % [city_count * 3, owners])
			_return_meeples(board, field_result)

#Finds the field segment key that contains a given half-edge index on a tile
func _find_field_segment_for_half_edge(tile_data: CarcassonneTileData, half_edge: int) -> String:
	for seg_key in tile_data.internal_connections:
		if seg_key.begins_with("field_") and tile_data.internal_connections[seg_key].has(half_edge):
			return seg_key
	return ""

#Traverses tiles using the half edge connection table, almost the same as _explore_segment
func _explore_field(board, start_cell: Vector2i, segment_key: String) -> Dictionary:
	var stack: Array = [[start_cell, segment_key]]
	var visited: Dictionary = {}
	var unique_tiles: Dictionary = {}
	#DFS traversal through tiles
	while not stack.is_empty():
		var entry = stack.pop_back()
		var cell = entry[0]
		var seg_key = entry[1]
		var visit_key = str(cell.x) + "," + str(cell.y) + "|" + seg_key
		if visited.has(visit_key):
			continue
		visited[visit_key] = true
		if not unique_tiles.has(cell):
			unique_tiles[cell] = true
		var tile = board.placed_tiles[cell]
		var half_edges = tile.tile_data.internal_connections[seg_key]
		for half_edge in half_edges:
			var conn = HALF_EDGE_CONNECTIONS[half_edge]
			var edge_idx = conn[0]
			# Fields never cross city edges
			if tile.tile_data.edge[edge_idx] == CarcassonneTileData.PropertyType.CITY:
				continue
			var neighbor_cell = cell + neighbor_directions[edge_idx]
			if not board.placed_tiles.has(neighbor_cell):
				continue
			var neighbor_tile = board.placed_tiles[neighbor_cell]
			var neighbor_seg_key = _find_field_segment_for_half_edge(neighbor_tile.tile_data, conn[1])
			if neighbor_seg_key == "":
				continue
			var neighbor_visit_key = str(neighbor_cell.x) + "," + str(neighbor_cell.y) + "|" + neighbor_seg_key
			if not visited.has(neighbor_visit_key):
				stack.append([neighbor_cell, neighbor_seg_key])
	return {"tiles": unique_tiles.keys(), "visited": visited.keys()} #Returns tiles and visited, same format as _explore_segment

#Checks if a field half edge overlaps with a city edge indicies
#For example, city is on edge [0], field has half edge [0, 1, 4, 5, 6, 7], city edge 0 -> checks half edge 0 -> returns true
#City on edge[1] (right side), field has same half edge, city edge 1 -> checks half edge 2 and 3 from lookup table HALF_EDGE_CONNECTIONS)-> no 2 and 3 -> return false
func _field_adjacent_to_city(field_half_edges: Array, city_edge_indices: Array) -> bool:
	for city_edge in city_edge_indices: #For each edge the city occupies
		for h in EDGE_TO_HALF_EDGES[city_edge]: #For half edges
			if field_half_edges.has(h): #If the half edge contains a city
				return true
	return false

#Counts unique cities touching it
func _get_adjacent_completed_cities(board, field_result: Dictionary) -> int:
	var found_cities: Dictionary = {}
	var cell_to_segs: Dictionary = {} #example {"0, 0: [field_0]"}
	#Loops through visited field and build a cell_to_segs
	for vkey in field_result["visited"]:
		var parts = vkey.split("|")
		var cell_str = parts[0]
		var seg_key = parts[1]
		if not cell_to_segs.has(cell_str):
			cell_to_segs[cell_str] = []
		cell_to_segs[cell_str].append(seg_key)
	#Loops through each tile in the field
	for cell in field_result["tiles"]:
		var cell_str = str(cell.x) + "," + str(cell.y)
		var tile_data = board.placed_tiles[cell].tile_data
		for field_seg in cell_to_segs.get(cell_str, []):
			var field_half_edges = tile_data.internal_connections[field_seg] #Grabs half edge for a city
			for seg_key in tile_data.internal_connections:
				if not seg_key.begins_with("city_"):
					continue
				if not _field_adjacent_to_city(field_half_edges, tile_data.internal_connections[seg_key]):
					continue
				var city_result = _explore_segment(board, cell, seg_key)
				if city_result["open_ports"] > 0: #Incomplete cities
					continue  
				var city_visited = city_result["visited"].duplicate()
				city_visited.sort()
				found_cities["|".join(city_visited)] = true #If the next tile finds the same city again, it joins the visited key in one string and deduplicated automatically in found_cities dictionary
	return found_cities.size()


#Checks if the segment or field is claimed 
func is_segment_claimed(board, cell: Vector2i, segment_key: String) -> bool:
	if segment_key == "center" or segment_key == "unknown":
		return false
	if segment_key == "monastery":
		return not board.placed_tiles[cell].meeples.is_empty()
	if segment_key.begins_with("field_"):
		var field_result = _explore_field(board, cell, segment_key)
		return not _get_meeple_owners(board, field_result).is_empty()
	var explore_result = _explore_segment(board, cell, segment_key)
	return not _get_meeple_owners(board, explore_result).is_empty()

# Returns which segment key a meeple slot belongs to on a tile, by mapping the slot's grid position to the nearest edge.
func _segment_for_slot(slot_id: String) -> String:
	# slot_id format: "x_y_segment_key" e.g. "0_-1_road_0"
	# split into at most 3 parts on the first two underscores
	return slot_id.split("_", true, 2)[2]

# Collects meeple counts per player, only counting meeples whose position maps to a segment that is part of the feature in explore_result.
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
			var seg = _segment_for_slot(slot_id)
			if feature_segs.has(seg):
				var owner = tile.meeples[slot_id].owner_index
				counts[owner] = counts.get(owner, 0) + 1
	return counts

#If two players have same meeple, this functions finds the max count and awards full point to all players tied
func _award_to_majority(counts: Dictionary, points: int) -> void:
	if counts.is_empty():
		return
	var max_count = counts.values().max()
	for player in counts:
		if counts[player] == max_count:
			score_manager.add_score(player, points)

#Returns meeple if a feature is completed
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
			if feature_segs.has(_segment_for_slot(slot_id)):
				to_remove.append(slot_id)
		for slot_id in to_remove:
			var m = tile.meeples[slot_id]
			var owner = m.owner_index
			m.remove()
			tile.meeples.erase(slot_id)
			meeple_returned.emit(owner)

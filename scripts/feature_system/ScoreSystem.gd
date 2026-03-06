class_name ScoreSystem extends Node

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


func _find_segment_for_edge(tile_data : CarcassonneTileData, edge_index : int):
    for i in tile_data.internal_connections:
        if (tile_data.internal_connections[i].has(edge_index)):
                return i
    return ""

#Traces feature from specific segment(feature) or tile
func _explore_segment(board, start_cell, segment_key):
    var stack: Array = [[start_cell, segment_key]] # Each entry is [cell, segment_key]
    var visited: Dictionary = {}
    var unique_tiles: Dictionary = {}
    var open_ports: int = 0
    var shield_count: int = 0

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
            if tile.tile_data.has_shield:
                shield_count += 1

        var tile = board.placed_tiles[cell]
        var edges = tile.tile_data.internal_connections[seg_key]
        for edge_index in edges:
            var neighbor_cell = cell + neighbor_directions[edge_index]
            if not board.placed_tiles.has(neighbor_cell):
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

# Get which feature from internal_connections
func _get_feature_type(segment_key, tile_data):
    # Option 1: Use segment key prefix
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
        if feature_type == "other":
            continue

        var explore_result = _explore_segment(board, placed_cell, segment_key)
        var visited_keys = explore_result["visited"]
        visited_keys.sort()
        var feature_key = "|".join(visited_keys)

        if _scored_features.has(feature_key):
            continue

        if explore_result["open_ports"] == 0:
            _scored_features[feature_key] = true
            var points = 0
            if feature_type == "road":
                points = explore_result["tiles"].size() * ROAD_POINTS_PER_TILE
            elif feature_type == "city":
                points = explore_result["tiles"].size() * CITY_POINTS_PER_TILE + explore_result["shield_count"] * 2
            print("ScoreSystem: awarding", points, "to player", player_index)
            score_manager.add_score(player_index, points)

    _check_monasteries(board, placed_cell, player_index)


func _check_monasteries(board, placed_cell, player_index):
    # Offsets for 8 surrounding cells
    var offsets = [
        Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
        Vector2i(-1,0),                 Vector2i(1,0),
        Vector2i(-1,1),  Vector2i(0,1),  Vector2i(1,1)
    ]
    # Build list: placed_cell + all 8 neighbors
    var cells_to_check = [placed_cell]
    for offset in offsets:
        cells_to_check.append(placed_cell + offset)

    for cell in cells_to_check:
        if not board.placed_tiles.has(cell):
            continue
        var tile = board.placed_tiles[cell]
        if tile.tile_data.is_monestary:
            # Count surrounding tiles
            var surrounding_count = 0
            for offset in offsets:
                var neighbor = cell + offset
                if board.placed_tiles.has(neighbor):
                    surrounding_count += 1
            if surrounding_count == 8:
                var mkey = "monastery|" + str(cell.x) + "," + str(cell.y)
                if not _scored_features.has(mkey):
                    _scored_features[mkey] = true
                    score_manager.add_score(player_index, MONASTERY_COMPLETE_POINTS)
                    print("Player %d scored %d for monastery at %s" % [player_index + 1, MONASTERY_COMPLETE_POINTS, str(cell)])



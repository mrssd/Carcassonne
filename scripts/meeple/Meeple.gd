extends Node2D

class_name Meeple

var owner_index: int = -1 # Player index
var player_colors: Array = [Color.BLUE, Color.RED, Color.GREEN, Color.YELLOW, Color.ORANGE] # Matched with UI player colors
var placed: bool = false
var feature_name: String = "" # Feature where meeple is placed

func _ready() -> void:
	_update_color()

func _update_color() -> void:
	var sprite = $Sprite2D
	if sprite and owner_index >= 0 and owner_index < player_colors.size():
		sprite.modulate = player_colors[owner_index]

func set_player(player_idx: int):
	owner_index = player_idx
	_update_color()

func is_placed() -> bool:
	return placed

func place_on_tile(tile: Node2D, feature_position: Vector2, feature: String, animate: bool = true):
	placed = true
	feature_name = feature
	tile.add_child(self)
	position = feature_position
	rotation = -tile.rotation
	z_index = 100
	z_as_relative = false
	if has_node("Sprite2D"):
		$Sprite2D.z_index = 100
	if animate:
		MeeplePlaceAnimation.play(self)

func remove():
	placed = false
	feature_name = ""
	queue_free()

func get_placement_feature(tile: Tile, world_click: Vector2) -> Dictionary:
	var best_dist := 1e9
	var best_feature := "center"
	var best_local := Vector2.ZERO
	var best_slot_id := "0_0_center"

	var unit_scale := Board.CELL_SIZE / 4.0

	if tile.tile_data.meeple_positions.size() > 0:
		for base_key in tile.tile_data.meeple_positions.keys():
			var base_rel := Vector2(base_key.x, base_key.y)
			var local_offset := base_rel * unit_scale
			var world_candidate := tile.to_global(local_offset)
			var dist := world_click.distance_to(world_candidate)

			if dist < best_dist:
				best_dist = dist
				best_local = local_offset
				best_feature = _resolve_segment(tile.tile_data, base_key, tile.rotation_count)
				best_slot_id = "%d_%d_%s" % [base_key.x, base_key.y, best_feature]
	else:
		best_local = Vector2.ZERO
		best_feature = "center"
		best_slot_id = "0_0_center"

	return {
		"offset": best_local, #Local position on the tile
		"feature": best_feature, #e.g. "city_0", "road_1", "field_2", "monastery"
		"slot_id": best_slot_id #unique ID for that slot
	}

static func _resolve_segment(tile_data: CarcassonneTileData, pos: Vector2i, rotation_count: int = 0) -> String:
	if tile_data.is_monastery and tile_data.meeple_positions.get(pos, CarcassonneTileData.PropertyType.NONE) == CarcassonneTileData.PropertyType.MONASTERY:
		return "monastery"
	# Un-rotate pos into tile-local space to match rotated internal_connections
	var r = ((rotation_count % 4) + 4) % 4
	var rp = pos
	for _i in range(r):
		rp = Vector2i(-rp.y, rp.x)
	# Fields using half edge lookup
	if tile_data.meeple_positions.get(pos, CarcassonneTileData.PropertyType.NONE) == CarcassonneTileData.PropertyType.FIELD:
		for he in _half_edges_for_pos(rp):
			for seg_key in tile_data.internal_connections:
				if seg_key.begins_with("field_") and tile_data.internal_connections[seg_key].has(he):
					return seg_key
		return "unknown"
	#Road and city using edge lookup
	var ax = abs(rp.x)
	var ay = abs(rp.y)
	var candidate_edges: Array
	if ax == 0 and ay == 0:
		candidate_edges = [0, 1, 2, 3]
	elif ax > ay:
		candidate_edges = [1 if rp.x > 0 else 3]
	elif ay > ax:
		candidate_edges = [0 if rp.y < 0 else 2]
	else:
		candidate_edges = [1 if rp.x > 0 else 3, 0 if rp.y < 0 else 2]
	for edge in candidate_edges:
		for seg_key in tile_data.internal_connections:
			# exclude field segments: their half-edge indices 0-7 overlap with edge indices 0-3
			if not seg_key.begins_with("field_") and tile_data.internal_connections[seg_key].has(edge):
				return seg_key
	return "unknown"

static func _half_edges_for_pos(pos: Vector2i) -> Array:
	#   [0][1]
	# [7]   [2]
	# [6]   [3]
	#   [5][4]
	if pos.y < 0 and pos.x < 0:   return [0, 7] 
	elif pos.y < 0 and pos.x > 0: return [1, 2] 
	elif pos.y > 0 and pos.x > 0: return [3, 4] 
	elif pos.y > 0 and pos.x < 0: return [5, 6]  
	elif pos.y < 0:                return [0, 1]  
	elif pos.y > 0:                return [4, 5] 
	elif pos.x > 0:                return [2, 3]  
	elif pos.x < 0:                return [6, 7]  
	return [0, 1, 2, 3, 4, 5, 6, 7]

static func try_place_on_board(allowed_tile: Tile, world_click: Vector2, player_index: int, remaining_meeples: Array, meeple_scene: PackedScene, animate: bool = true) -> bool:
	if allowed_tile == null:
		print("No tile to place meeple on.")
		return false

	if remaining_meeples[player_index] <= 0:
		print("No meeples remaining for Player %d" % [player_index])
		return false

	var temp_meeple: Meeple = meeple_scene.instantiate() as Meeple
	if temp_meeple == null:
		print("Failed to instantiate meeple.")
		return false

	var info = temp_meeple.get_placement_feature(allowed_tile, world_click)
	var slot_id = info["slot_id"]
	var feature = info["feature"]

	temp_meeple.set_player(player_index)
	temp_meeple.place_on_tile(allowed_tile, info["offset"], feature, animate)
	allowed_tile.add_meeple(slot_id, temp_meeple)

	remaining_meeples[player_index] -= 1
	print("Meeple placed for Player %d, remaining: %d" % [player_index, remaining_meeples[player_index]])
	return true


#White circle 
class MeepleHints:
	extends Node2D

	var positions: Array[Vector2] = []
	var radius: float = 6.0

	func _ready() -> void:
		z_as_relative = false
		z_index = 1000
		queue_redraw()

	func _draw() -> void:
		for p in positions:
			# white filled circle + thin dark outline
			draw_circle(p, radius, Color.WHITE)
			draw_arc(p, radius, 0.0, TAU, 24, Color(0, 0, 0, 0.75), 1.0, true)

static func show_placement_hints(tile: Tile, unit_scale: float = Board.CELL_SIZE / 4.0, score_system = null, board = null, cell: Vector2i = Vector2i.ZERO) -> void:
	if tile == null:
		return

	# Remove existing hints (if any)
	if tile.has_node("MeepleHints"):
		tile.get_node("MeepleHints").queue_free()

	var hints := MeepleHints.new()
	hints.name = "MeepleHints"

	# Build positions using the SAME logic as get_placement_feature()
	var positions: Array[Vector2] = []
	if tile.tile_data and tile.tile_data.meeple_positions.size() > 0:
		for base_key in tile.tile_data.meeple_positions.keys():
			if score_system != null and board != null:
				var feature = _resolve_segment(tile.tile_data, base_key, tile.rotation_count)
				if score_system.is_segment_claimed(board, cell, feature):
					continue
			var base_rel := Vector2(base_key.x, base_key.y)
			var local_offset := base_rel * unit_scale
			positions.append(local_offset)
	else:
		positions.append(Vector2.ZERO)

	hints.positions = positions
	tile.add_child(hints)
	hints.queue_redraw()

static func hide_placement_hints(tile: Tile) -> void:
	if tile and tile.has_node("MeepleHints"):
		tile.get_node("MeepleHints").queue_free()

#Returns true if there is at least one unclaimed meeple position on the tile and the player has meeples remaining
static func has_valid_placements(tile: Tile, score_system, board, cell: Vector2i, player_meeples: int) -> bool:
	if player_meeples <= 0:
		return false
	if tile == null or tile.tile_data == null:
		return false
	if tile.tile_data.meeple_positions.is_empty():
		return true  # fallback centre position is always available
	for base_key in tile.tile_data.meeple_positions.keys():
		var feature := _resolve_segment(tile.tile_data, base_key, tile.rotation_count)
		if not score_system.is_segment_claimed(board, cell, feature):
			return true
	return false

#Meeple hint highlight class
class MeepleHintHighlight:
	extends Node2D
	var hint_pos: Vector2 = Vector2.ZERO
	var _time: float = 0.0
	func _ready() -> void:
		z_as_relative = false
		z_index = 1001
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		var pulse := (sin(_time * 4.0) + 1.0) / 2.0
		var r := lerpf(7.0, 9.0, pulse)
		draw_circle(hint_pos, r, Color(1.0, 0.85, 0.0, lerpf(0.7, 1.0, pulse)))
		draw_arc(hint_pos, r, 0.0, TAU, 32, Color(1.0, 0.5, 0.0, 1.0), 2.0, true)


static func show_meeple_hint(tile: Tile, world_pos: Vector2) -> void:
	hide_meeple_hint(tile)
	var hint := MeepleHintHighlight.new()
	hint.name = "MeepleHintHighlight"
	hint.hint_pos = tile.to_local(world_pos)
	tile.add_child(hint)


static func hide_meeple_hint(tile: Tile) -> void:
	if tile and tile.has_node("MeepleHintHighlight"):
		tile.get_node("MeepleHintHighlight").queue_free()

extends Node2D

class_name Meeple

var owner_index: int = -1 # Player index
var player_colors: Array = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
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

func place_on_tile(tile: Node2D, feature_position: Vector2, feature: String):
	placed = true
	feature_name = feature
	tile.add_child(self)
	position = feature_position
	rotation = -tile.rotation
	z_index = 100
	z_as_relative = false
	if has_node("Sprite2D"):
		$Sprite2D.z_index = 100

func remove():
	placed = false
	feature_name = ""
	queue_free()

func get_placement_feature(tile: Tile, world_click: Vector2) -> Dictionary:
	var best_dist := 1e9
	var best_feature := "center"
	var best_local := Vector2.ZERO
	var best_slot_id := "center_0_0"

	# Each grid unit corresponds to 24 pixels on the tile
	var unit_scale := 24.0

	if tile.tile_data.meeple_positions.size() > 0:
		for base_key in tile.tile_data.meeple_positions.keys():
			var base_rel := Vector2(base_key.x, base_key.y)
			var local_offset := base_rel * unit_scale
			var world_candidate := tile.to_global(local_offset)
			var dist := world_click.distance_to(world_candidate)

			if dist < best_dist:
				best_dist = dist
				best_local = local_offset
				best_feature = str(tile.tile_data.meeple_positions[base_key])
				best_slot_id = "%d_%d_%s" % [base_key.x, base_key.y, best_feature]
	else:
		best_local = Vector2.ZERO
		best_feature = "center"
		best_slot_id = "center_0_0"

	return {
		"offset": best_local,
		"feature": best_feature,
		"slot_id": best_slot_id
	}

static func try_place_on_board(board: Node,allowed_tile: Tile, world_click: Vector2, player_index: int, remaining_meeples: Array, meeple_scene: PackedScene) -> bool:
	var clicked_cell: Vector2i = board.coord_to_index(world_click)
	if not board.placed_tiles.has(clicked_cell):
		print("Meeple must be placed on the tile just placed this turn.")
		return false

	var target_tile: Tile = board.placed_tiles[clicked_cell]

	# Enforce: only place on the tile just placed
	if allowed_tile == null or target_tile != allowed_tile:
		print("You can only place a meeple on the tile you just placed.")
		return false

	var temp_meeple: Meeple = meeple_scene.instantiate() as Meeple
	if temp_meeple == null:
		print("Failed to instantiate meeple.")
		return false

	var info = temp_meeple.get_placement_feature(target_tile, world_click)
	var slot_id = info["slot_id"]
	var feature = info["feature"]

	# No per-tile occupancy check (your rule guarantees at most one placement this phase)
	if remaining_meeples[player_index] <= 0:
		print("No meeples remaining for Player %d" % [player_index])
		return false

	temp_meeple.set_player(player_index)
	temp_meeple.place_on_tile(target_tile, info["offset"], feature)
	target_tile.add_meeple(slot_id, temp_meeple)

	remaining_meeples[player_index] -= 1
	print("Meeple placed for Player %d, remaining: %d" % [player_index, remaining_meeples[player_index]])
	return true


# -------------------------------------------------------------------
# Visual hints for meeple placements (white circles on allowed tile)
# -------------------------------------------------------------------

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

static func show_placement_hints(tile: Tile, unit_scale: float = 24.0) -> void:
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







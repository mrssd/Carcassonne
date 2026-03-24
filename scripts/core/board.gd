extends Node2D
class_name Board

const CELL_SIZE: int = 96
@export var tile_scene: PackedScene

var placed_tiles := {}
var current_tile: Tile # NEED TO MATCH IN TILE SCRIPT
# Hover/transparency config
@export var hover_placed_alpha: float = 1.0 # placed tile value
@export var hover_current_alpha: float = 0.40 # tile in hand value
var _hover_cell = null

func coord_to_index(world_coord: Vector2) -> Vector2i:
	return Vector2i(round(world_coord.x / CELL_SIZE), round(world_coord.y / CELL_SIZE))

func index_to_coord(cell_index: Vector2i) -> Vector2:
	return Vector2(cell_index.x * CELL_SIZE, cell_index.y * CELL_SIZE)

func snap_to_grid(world_coord: Vector2) -> Vector2:
	var cell: Vector2i = coord_to_index(world_coord)
	return index_to_coord(cell)

func _process(_dt):
	if not current_tile:
		return
	current_tile.position = snap_to_grid(get_global_mouse_position())

	# Determine if we're hovering over an already placed tile cell
	var cell: Vector2i = coord_to_index(current_tile.position)
	if placed_tiles.has(cell):
		_set_hover_transparency(cell)
	else:
		_clear_hover_transparency()

func place_tile(cell: Vector2i, tile: Tile): # NEED TO MATCH IN TILE SCRIPT
	tile.position = index_to_coord(cell)
	tile.visible = true
	# ensure tile placed has full opacity
	tile.modulate = Color(1, 1, 1, 1)
	placed_tiles[cell] = tile
	# clear hover state when placing
	_clear_hover_transparency()


func _set_hover_transparency(cell: Vector2i) -> void:
	# If already hovering same cell, noop
	if _hover_cell == cell:
		return
	# Clear previous hover first
	_clear_hover_transparency()
	if not placed_tiles.has(cell):
		return
	var placed_tile: Tile = placed_tiles[cell]
	if placed_tile != null:
		placed_tile.modulate = Color(1, 1, 1, hover_placed_alpha)
	if current_tile != null:	
		current_tile.modulate = Color(1, 0.35, 0.35, hover_current_alpha) # RGB value for tile in hand
	_hover_cell = cell


func _clear_hover_transparency() -> void:
	if _hover_cell != null and placed_tiles.has(_hover_cell):
		var prev_tile: Tile = placed_tiles[_hover_cell]
		if prev_tile != null:
			prev_tile.modulate = Color(1, 1, 1, 1)
	_hover_cell = null
	if current_tile != null:
		current_tile.modulate = Color(1, 1, 1, 1)

func can_place(cell: Vector2i, tile: Tile) -> bool:
	if placed_tiles.size() == 0:
		return true
	if placed_tiles.has(cell):
		return false
	
	var has_neighbor: bool = false
	var edges: Array = tile.get_edges() # NEED THIS FUNCTION TO COME FROM TILE SCRIPT
	# FOLLOWING VARS ASSUME A 4 ELEMENT ARRAY BEING PASSED FOR EDGES
	var neighbor_directions: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var opposite_index := [2, 3, 0, 1]
	
	for i in range(4):
		var neighbor_cell: Vector2i = cell + neighbor_directions[i]
		if placed_tiles.has(neighbor_cell):
			has_neighbor = true
			var neighbor: Tile = placed_tiles[neighbor_cell]
			var neighbor_edges: Array = neighbor.get_edges()
			if edges[i] != neighbor_edges[opposite_index[i]]:
				return false
	
	return has_neighbor

#Function i get akk valid placement for current tile
func get_all_valid_placement(tile: Tile) -> Array:
	if tile == null:
		push_error("Tile is null in get_all_valid_placement!")
		return []
	var valid = []
	var neighbor_directions: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var checked = {}

	#loop through all placed tiles
	for cell in placed_tiles.keys():
		#4 direction
		for direction in neighbor_directions:
			var empty_cell = cell + direction
			if placed_tiles.has(empty_cell) or checked.has(empty_cell):
				continue
			checked[empty_cell] = true
			if can_place(empty_cell, tile):
				valid.append({ "cell": empty_cell })

	return valid

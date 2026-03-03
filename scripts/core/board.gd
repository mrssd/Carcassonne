extends Node2D
class_name Board

const CELL_SIZE : int = 96
@export var tile_scene : PackedScene

var placed_tiles := {}
var current_tile : Tile #NEED TO MATCH IN TILE SCRIPT

func coord_to_index(world_coord : Vector2) -> Vector2i:
	return Vector2i(round(world_coord.x / CELL_SIZE), round(world_coord.y / CELL_SIZE))

func index_to_coord(cell_index : Vector2i) -> Vector2:
	return Vector2(cell_index.x * CELL_SIZE, cell_index.y * CELL_SIZE)

func snap_to_grid(world_coord : Vector2) -> Vector2:
	var cell : Vector2i = coord_to_index(world_coord)
	return index_to_coord(cell)

func _process(_dt):
	if not current_tile:
		return
	current_tile.position = snap_to_grid(get_global_mouse_position())

func place_tile(cell : Vector2i, tile : Tile): #NEED TO MATCH IN TILE SCRIPT
	tile.position = index_to_coord(cell)
	placed_tiles[cell] = tile

func can_place(cell : Vector2i, tile : Tile) -> bool:
	if placed_tiles.size() == 0:
		return true
	if placed_tiles.has(cell):
		return false
	
	var has_neighbor : bool = false
	var edges : Array = tile.get_edges() #NEED THIS FUNCTION TO COME FROM TILE SCRIPT
	# FOLLOWING VARS ASSUME A 4 ELEMENT ARRAY BEING PASSED FOR EDGES
	var neighbor_directions : Array = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	var opposite_index := [2,3,0,1]
	
	for i in range(4):
		var neighbor_cell : Vector2i = cell + neighbor_directions[i]
		if placed_tiles.has(neighbor_cell):
			has_neighbor = true
			var neighbor : Tile = placed_tiles[neighbor_cell]
			var neighbor_edges : Variant = neighbor.get_edges()
			if edges[i] != neighbor_edges[opposite_index[i]]:
				return false
	
	return has_neighbor

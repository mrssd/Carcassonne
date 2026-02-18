extends Node2D
class_name Board

@export var cell_size : int = 96
@export var tile_scene : PackedScene

var placed_tiles := {}
var current_tile : Tile #NEED TO MATCH IN TILE SCRIPT

func coord_to_index(world_coord : Vector2) -> Vector2i:
    return Vector2i(round(world_coord.x / cell_size), round(world_coord.y / cell_size))

func index_to_coord(cell_index : Vector2i) -> Vector2:
    return Vector2(cell_coord.x * cell_size, cell_coord.y * cell_size)

func snap_to_grid(world_coord : Vector2) -> Vector2i:
    var cell : Vector2 = coord_to_index(world_coord)
    return index_to_coord(cell)

func _process(_dt):
    if not current_tile:
        return
    current_tile.position = snap_to_grid(get_global_mouse_position())

func place_tile(cell : Vector2i, tile : Tile):
    tile.position = index_to_coord(cell)
    placed_tiles[cell] = tile










class_name Tile extends Node2D

@export var tile_data: CarcassonneTileData
@onready var sprite: Sprite2D = $Sprite2D # reference to child sprite
@onready var label: Label = $Label

## Grid position on the board (in tile coordinates)
var board_position: Vector2i = Vector2i.ZERO

## Number of clockwise rotations applied (0-3)
var rotation_count: int = 0


func _ready() -> void:
	update_visual()


## Rotate tile 90 degrees clockwise
func rotate_clockwise() -> void:
	tile_data.rotate_clockwise()
	rotation_degrees += 90
	rotation_count = (rotation_count + 1) % 4
	update_visual()


## Rotate tile 90 degrees counter-clockwise
func rotate_counter_clockwise() -> void:
	tile_data.rotate_counter_clockwise()
	rotation_degrees -= 90
	rotation_count = (rotation_count - 1) % 4
	update_visual()


## Returns the edge type at a given orientation (use TileData.Orientation values)
func get_edge(orientation: int) -> int:
	return tile_data.edge[orientation]


## Check if this tile can be placed adjacent to another tile on a given side.
## 'my_side' is the side of this tile facing the neighbour (use TileData.Orientation values).
func can_connect(other: Tile, my_side: int) -> bool:
	var opposite: int = (my_side + 2) % 4
	return get_edge(my_side) == other.get_edge(opposite)


## Called whenever tile data changes — update sprites/colors here.
func update_visual() -> void:
	if tile_data == null:
		return
	if sprite and tile_data.tile_texture:
		sprite.texture = tile_data.tile_texture # ← set the image
	if label:
		label.text = tile_data.name # ← show name for debug

## Get edges of a tile
func get_edges() -> Array:
	return tile_data.edge.duplicate()

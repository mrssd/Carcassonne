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

func place_on_tile(tile: Node2D, feature_position: Vector2, feature: String):
	placed = true
	feature_name = feature
	position = feature_position
	tile.add_child(self)

func remove():
	placed = false
	feature_name = ""
	queue_free()

func set_player(player_idx: int):
	owner_index = player_idx
	_update_color()

func is_placed() -> bool:
	return placed

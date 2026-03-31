extends Node2D

const CELL_SIZE := 96

func _ready():
	z_as_relative = false
	z_index = 10
	queue_redraw()

func _draw():
	var color = Color(1, 1, 1, 0.8)
	var thickness = 3
	draw_rect(Rect2(Vector2(-CELL_SIZE / 2, -CELL_SIZE / 2), Vector2(CELL_SIZE, CELL_SIZE)), color, false, thickness)

extends Node2D

func _ready():
	z_as_relative = false
	z_index = 10
	queue_redraw()

func _draw():
	var half := Board.CELL_SIZE / 2.0
	var thickness := 3.0
	var inset := thickness / 2.0
	draw_rect(
		Rect2(Vector2(-half + inset, -half + inset), Vector2(Board.CELL_SIZE - inset * 2, Board.CELL_SIZE - inset * 2)),
		Color(1, 1, 0, 0.8),
		false,
		thickness
	)

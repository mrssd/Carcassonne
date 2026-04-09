extends Node2D

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var half := Board.CELL_SIZE / 2.0
	var pulse := (sin(_time * 4.0) + 1.0) / 2.0
	var thickness: float = lerp(3.0, 5.0, pulse)
	var inset := thickness / 2.0
	var fill_rect := Rect2(Vector2(-half, -half), Vector2(Board.CELL_SIZE, Board.CELL_SIZE))
	var border_rect := Rect2(Vector2(-half + inset, -half + inset), Vector2(Board.CELL_SIZE - inset * 2, Board.CELL_SIZE - inset * 2))
	draw_rect(fill_rect, Color(0.2, 1.0, 0.3, lerp(0.08, 0.18, pulse)), true)
	draw_rect(border_rect, Color(0.2, 1.0, 0.3, lerp(0.7, 1.0, pulse)), false, thickness)

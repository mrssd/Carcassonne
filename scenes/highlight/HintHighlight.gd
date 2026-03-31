extends Node2D

const CELL_SIZE := 96

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse = (sin(_time * 4.0) + 1.0) / 2.0  # 0..1

	var fill_alpha = lerp(0.08, 0.18, pulse)
	draw_rect(
		Rect2(Vector2(-CELL_SIZE / 2, -CELL_SIZE / 2), Vector2(CELL_SIZE, CELL_SIZE)),
		Color(0.2, 1.0, 0.3, fill_alpha),
		true
	)

	var border_alpha = lerp(0.7, 1.0, pulse)
	var thickness = lerp(3.0, 5.0, pulse)
	draw_rect(
		Rect2(Vector2(-CELL_SIZE / 2, -CELL_SIZE / 2), Vector2(CELL_SIZE, CELL_SIZE)),
		Color(0.2, 1.0, 0.3, border_alpha),
		false,
		thickness
	)

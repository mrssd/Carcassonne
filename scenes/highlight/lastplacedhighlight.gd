extends Node2D

const DEFAULT_PLAYER_COLORS: Array[Color] = [Color.BLUE, Color.RED, Color.GREEN, Color.YELLOW, Color.ORANGE]
const FALLBACK_COLOR := Color(1, 1, 1, 0.8)
const CORNER_LEN := 14.0

var player_colors: Array[Color] = DEFAULT_PLAYER_COLORS.duplicate()
var highlight_color: Color = FALLBACK_COLOR
func _ready() -> void:
	z_as_relative = false
	z_index = 20
	queue_redraw()

func set_player_colors(colors: Array) -> void:
	var next_colors: Array[Color] = []
	for color in colors:
		if color is Color:
			next_colors.append(color)
	if next_colors.size() > 0:
		player_colors = next_colors

func set_last_tile_highlight(player_index: int) -> void:
	var c := player_colors[player_index % player_colors.size()] if player_colors.size() > 0 else FALLBACK_COLOR
	highlight_color = Color(c.r, c.g, c.b, 1.0)
	queue_redraw()

func _draw() -> void:
	var half := Board.CELL_SIZE / 2.0
	var thickness := 4.0
	var inset := thickness / 2.0
	var color := Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.9)

	draw_rect(
		Rect2(Vector2(-half, -half), Vector2(Board.CELL_SIZE, Board.CELL_SIZE)),
		Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.08),
		true
	)

	var corners: Array[Vector2] = [Vector2(-half + inset, -half + inset), Vector2(half - inset, -half + inset), Vector2(half - inset, half - inset), Vector2(-half + inset, half - inset)]
	var x_dirs: Array[int] = [1, -1, -1,  1]
	var y_dirs: Array[int] = [1,  1, -1, -1]
	for i in range(4):
		var corner: Vector2 = corners[i]
		draw_line(corner, corner + Vector2(x_dirs[i] * CORNER_LEN, 0), color, thickness, true)
		draw_line(corner, corner + Vector2(0, y_dirs[i] * CORNER_LEN), color, thickness, true)

extends Node2D

const CELL_SIZE := 96
const DEFAULT_PLAYER_COLORS: Array[Color] = [Color.BLUE, Color.RED, Color.GREEN, Color.YELLOW, Color.ORANGE]
const FALLBACK_COLOR := Color(1, 1, 1, 0.8)

var player_colors: Array[Color] = DEFAULT_PLAYER_COLORS.duplicate()
var highlight_color: Color = FALLBACK_COLOR
var border_thickness: float = 3
var fill_color: Color = Color(1, 1, 1, 0.1)

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
	var player_color := player_colors[player_index % player_colors.size()] if player_colors.size() > 0 else FALLBACK_COLOR
	highlight_color = Color(player_color.r, player_color.g, player_color.b, 1.0)
	fill_color = Color(player_color.r, player_color.g, player_color.b, 0)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(-CELL_SIZE / 2, -CELL_SIZE / 2), Vector2(CELL_SIZE, CELL_SIZE))
	if fill_color.a > 0.0:
		draw_rect(rect, fill_color, true)
	draw_rect(rect, highlight_color, false, border_thickness)

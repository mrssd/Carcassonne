extends PanelContainer
class_name PlayerCardUI

@onready var player_name_label: Label = %player_name
@onready var meeples_label: Label = %meepls
@onready var score_label: Label = %player_score
@onready var avatar_texture: TextureRect = %player_avatar

var player_index: int = 0
var is_current_turn: bool = false

# Called when the node enters the scene tree
func _ready() -> void:
	# Allow mouse events to pass through to parent for hover detection
	mouse_filter = Control.MOUSE_FILTER_PASS

# Update player information on the card
func update_player_info(player_name: String, avatar: Texture2D, meeples: int, score: int) -> void:
	player_name_label.text = player_name
	if avatar:
		avatar_texture.texture = avatar
	meeples_label.text = str(meeples)
	score_label.text = str(score)

# Set whether this card is for the current turn player
func set_current_turn(active: bool) -> void:
	is_current_turn = active
	# Only change position/z-index, not size
	if is_current_turn:
		z_index = 10 # Bring current player card to front
	else:
		z_index = 0

# Set card x position for stack flow effect
func set_stack_position(stack_index: int) -> void:
	# Each card shifts more to the right - creates flowing effect
	position.x = stack_index * 20

# Get the player index
func get_player_index() -> int:
	return player_index

# Set player index
func set_player_index(index: int) -> void:
	player_index = index

# Set border color based on player color
func set_border_color(color: Color) -> void:
	var style_box = get_theme_stylebox("panel") as StyleBoxFlat
	if style_box:
		style_box = style_box.duplicate()
		style_box.border_color = color
		style_box.border_width_left = 2
		style_box.border_width_top = 2
		style_box.border_width_right = 2
		style_box.border_width_bottom = 2
		add_theme_stylebox_override("panel", style_box)

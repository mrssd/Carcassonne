extends Control
class_name UIManager

@onready var turn_system: TurnSystem = $"../../TurnSystem"
@onready var game_manager = $"../../GameManager"
@onready var score_manager = $"../../ScoreManager"
@onready var score_label: Label = $VBoxContainer/Scoreboard/VBoxContainer/ScoreLabel
@onready var turn_label: Label = $VBoxContainer/CurrentAction/VBoxContainer/TurnLabel
@onready var deck_label: Label = $VBoxContainer/Information/VBoxContainer/DeckLabel
@onready var game_over_label: Label = $VBoxContainer/Information/VBoxContainer/GameOverLabel

# Color for each player (supports up to 5)
var player_colors = [
	Color.BLUE,
	Color.RED,
	Color.GREEN,
	Color.YELLOW,
	Color.ORANGE,
]

const PHASE_HINTS = {
	1: "Place the tile on a highlighted cell.\nRight-click or Q / E to rotate.",
	2: "Click a dot to place a meeple on a feature.\nPress S to skip.",
}

var hint_label: Label

func _ready() -> void:
	_create_hint_panel()
	
	# Use call_deferred to ensure GameManager has initialized its deck
	call_deferred("_setup_connections")

func _setup_connections() -> void:
	if turn_system:
		turn_system.turn_changed.connect(_on_turn_changed)
		turn_system.phase_changed.connect(_on_phase_changed)
		# Set initial turn display
		turn_label.text = "Turn: %s" % turn_system.get_current_player()
		_update_turn_color(turn_system.current_player_index)
	
	if game_manager:
		if game_manager.tile_deck:
			game_manager.tile_deck.deck_changed.connect(_on_deck_changed)
			# Set initial deck display
			_update_deck_display()
		game_manager.game_ended.connect(_on_game_ended)

	if score_label and score_manager:
		score_manager.score_updated.connect(_on_score_changed)
		# Set initial score display
		_on_score_changed()

func _on_turn_changed(player_name: String, player_index: int) -> void:
	turn_label.text = "Turn: %s" % player_name
	_update_turn_color(player_index)
	_on_score_changed()

func _update_turn_color(player_index: int) -> void:
	if player_index < player_colors.size():
		turn_label.add_theme_color_override("font_color", player_colors[player_index])

func _on_deck_changed() -> void:
	_update_deck_display()

func _update_deck_display() -> void:
	if game_manager and game_manager.tile_deck:
		var remaining = game_manager.tile_deck.get_draw_pile_size()
		deck_label.text = "Tiles: %d" % remaining

func _on_game_ended(message: String) -> void:
	game_over_label.text = message
	game_over_label.visible = true

func _on_score_changed(player_index := -1, new_score := -1) -> void:
	if score_manager:
		score_label.text = score_manager.get_all_scores_text()

func _create_hint_panel() -> void:
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -90
	panel.offset_bottom = -10
	panel.offset_left = 200
	panel.offset_right = -200

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.75)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color.WHITE)
	hint_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(hint_label)
	add_child(panel)
	panel.hide()
	hint_label.set_meta("panel", panel)

func _on_phase_changed(phase: int) -> void:
	var panel = hint_label.get_meta("panel")
	if PHASE_HINTS.has(phase):
		hint_label.text = PHASE_HINTS[phase]
		panel.show()
	else:
		panel.hide()

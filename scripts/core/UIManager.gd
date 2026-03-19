extends Control
class_name UIManager

@onready var turn_system: TurnSystem = $"../../TurnSystem"
@onready var game_manager = $"../../GameManager"
@onready var score_manager = $"../../ScoreManager"
@onready var score_label: Label = $VBoxContainer/Scoreboard/MarginContainer/VBoxContainer/ScoreLabel
@onready var turn_label: Label = $VBoxContainer/CurrentAction/MarginContainer/VBoxContainer/TurnLabel
@onready var deck_label: Label = $VBoxContainer/Information/MarginContainer/VBoxContainer/DeckLabel
@onready var game_over_label: Label = $VBoxContainer/Information/MarginContainer/VBoxContainer/GameOverLabel
@onready var hint_label: Label = $VBoxContainer2/Hint/VBoxContainer/HintLabel
@onready var hint_panel: Panel = $VBoxContainer2/Hint

# Color for each player (supports up to 5)
var player_colors = [
	Color.BLUE,
	Color.RED,
	Color.GREEN,
	Color.YELLOW,
	Color.ORANGE,
]

func _ready() -> void:
	# Use call_deferred to ensure GameManager has initialized its deck
	call_deferred("_setup_connections")

func _setup_connections() -> void:
	if turn_system:
		turn_system.turn_changed.connect(_on_turn_changed)
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

func show_hint(message: String) -> void:
	hint_label.text = message
	hint_panel.show()

func hide_hint() -> void:
	hint_panel.hide()

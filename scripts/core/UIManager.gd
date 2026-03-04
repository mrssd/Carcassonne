extends Control
class_name UIManager

@onready var turn_system: TurnSystem = $"../../TurnSystem"
@onready var game_manager = $"../../GameManager"
@onready var turn_label: Label = $TurnLabel
@onready var deck_label: Label = $DeckLabel
@onready var game_over_label: Label = $GameOverLabel

# Color for each player
var player_colors = [
	Color.BLUE, # Player 1
	Color.RED # Player 2
]

func _ready() -> void:
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

func _on_turn_changed(player_name: String, player_index: int) -> void:
	turn_label.text = "Turn: %s" % player_name
	_update_turn_color(player_index)
	print("UI Updated: %s" % player_name)

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
	print("Game Over UI Updated: %s" % message)

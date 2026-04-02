extends Node

var bot_count: int = 1
var total_players: int = 2
var bot_difficulty: String = "random_bot"
var bot_players_label: Label
var bots_difficulty_button: OptionButton
var back_button: Button

func _ready() -> void:
	# Get references to UI elements
	bot_players_label = %bot_players
	bots_difficulty_button = %bots_difficulty
	back_button = %back_menu
	
	# Connect buttons
	%add_bot_player.pressed.connect(_on_add_bot_pressed)
	%remove_bot_player.pressed.connect(_on_remove_bot_pressed)
	%strat_game.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	bots_difficulty_button.item_selected.connect(_on_difficulty_selected)
	
	print("Back button connected: ", back_button)
	print("Back button disabled: ", back_button.disabled)
	print("Back button mouse filter: ", back_button.mouse_filter)
	
	# Initialize display
	_update_bot_display()

func _on_add_bot_pressed() -> void:
	if total_players < 5:
		bot_count += 1
		total_players += 1
		_update_bot_display()

func _on_remove_bot_pressed() -> void:
	if bot_count > 1:
		bot_count -= 1
		total_players -= 1
		_update_bot_display()

func _on_difficulty_selected(index: int) -> void:
	if index == 0:
		bot_difficulty = "random_bot"
	elif index == 1:
		bot_difficulty = "greedy_bot"

func _on_start_pressed() -> void:
	GameManager.player_count = total_players
	GameManager.player_types.clear()
	
	# Add human player
	GameManager.player_types.append("human")
	
	# Add bot players
	for i in range(bot_count):
		GameManager.player_types.append(bot_difficulty)
	
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_back_pressed() -> void:
	print("Back button pressed")
	call_deferred("_go_back")

func _update_bot_display() -> void:
	bot_players_label.text = str(bot_count)

func _go_back() -> void:
	print("Going back to main menu")
	get_tree().change_scene_to_file("res://scenes/menu/mainMenu.tscn")

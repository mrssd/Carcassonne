extends Node

func _ready() -> void:
	MusicManager.play_menu_music()
	%back_menu.move_to_front()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/mainMenu.tscn")

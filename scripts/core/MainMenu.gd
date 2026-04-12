extends Node

func _ready() -> void:
	MusicManager.play_menu_music()

func _on_singleplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/SPYMenu.tscn")

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/LANMenu.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

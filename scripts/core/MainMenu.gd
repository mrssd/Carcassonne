extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn") # change to the game scene when start is pressed

func _on_options_pressed() -> void:
	pass


func _on_exit_pressed() -> void:
	get_tree().quit() # quit the game when exit is pressed

extends Node

var player_count: int = 2
var count_label: Label

func _ready() -> void:
	var vbox = $VBoxContainer

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var title = Label.new()
	title.text = "Players: "
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 30)
	row.add_child(title)

	var minus_btn = Button.new()
	minus_btn.text = " - "
	minus_btn.add_theme_font_size_override("font_size", 30)
	minus_btn.pressed.connect(_on_minus_pressed)
	row.add_child(minus_btn)

	count_label = Label.new()
	count_label.text = str(player_count)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_font_size_override("font_size", 30)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(count_label)

	var plus_btn = Button.new()
	plus_btn.text = " + "
	plus_btn.add_theme_font_size_override("font_size", 30)
	plus_btn.pressed.connect(_on_plus_pressed)
	row.add_child(plus_btn)

	vbox.add_child(row)
	vbox.move_child(row, 0)

func _on_minus_pressed() -> void:
	player_count = max(2, player_count - 1)
	count_label.text = str(player_count)

func _on_plus_pressed() -> void:
	player_count = min(5, player_count + 1)
	count_label.text = str(player_count)

func _on_start_pressed() -> void:
	GameManager.player_count = player_count
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_options_pressed() -> void:
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

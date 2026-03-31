extends Node

var player_count: int = 2
var cpu_count: int = 0
var cpu_difficulty: String = "random_bot"
var count_label: Label
var cpu_label: Label
var difficulty_label: Label

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

	var cpu_row = HBoxContainer.new()
	cpu_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var cpu_title = Label.new()
	cpu_title.text = "CPU Players: "
	cpu_title.add_theme_color_override("font_color", Color.WHITE)
	cpu_title.add_theme_font_size_override("font_size", 30)
	cpu_row.add_child(cpu_title)

	var cpu_minus = Button.new()
	cpu_minus.text = " - "
	cpu_minus.add_theme_font_size_override("font_size", 30)
	cpu_minus.pressed.connect(_on_cpu_minus_pressed)
	cpu_row.add_child(cpu_minus)

	cpu_label = Label.new()
	cpu_label.text = str(cpu_count)
	cpu_label.add_theme_color_override("font_color", Color.WHITE)
	cpu_label.add_theme_font_size_override("font_size", 30)
	cpu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cpu_label.custom_minimum_size = Vector2(40, 0)
	cpu_row.add_child(cpu_label)

	var cpu_plus = Button.new()
	cpu_plus.text = " + "
	cpu_plus.add_theme_font_size_override("font_size", 30)
	cpu_plus.pressed.connect(_on_cpu_plus_pressed)
	cpu_row.add_child(cpu_plus)

	vbox.add_child(cpu_row)
	vbox.move_child(cpu_row, 1)

	var diff_row = HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var diff_title = Label.new()
	diff_title.text = "CPU Difficulty: "
	diff_title.add_theme_color_override("font_color", Color.WHITE)
	diff_title.add_theme_font_size_override("font_size", 30)
	diff_row.add_child(diff_title)

	var diff_btn = Button.new()
	diff_btn.text = " < "
	diff_btn.add_theme_font_size_override("font_size", 30)
	diff_btn.pressed.connect(_on_difficulty_pressed)
	diff_row.add_child(diff_btn)

	difficulty_label = Label.new()
	difficulty_label.text = "Random"
	difficulty_label.add_theme_color_override("font_color", Color.WHITE)
	difficulty_label.add_theme_font_size_override("font_size", 30)
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_label.custom_minimum_size = Vector2(120, 0)
	diff_row.add_child(difficulty_label)

	var diff_btn2 = Button.new()
	diff_btn2.text = " > "
	diff_btn2.add_theme_font_size_override("font_size", 30)
	diff_btn2.pressed.connect(_on_difficulty_pressed)
	diff_row.add_child(diff_btn2)

	vbox.add_child(diff_row)
	vbox.move_child(diff_row, 2)

func _on_minus_pressed() -> void:
	player_count = max(2, player_count - 1)
	count_label.text = str(player_count)
	cpu_count = min(cpu_count, player_count - 1)
	cpu_label.text = str(cpu_count)

func _on_plus_pressed() -> void:
	player_count = min(5, player_count + 1)
	count_label.text = str(player_count)

func _on_cpu_minus_pressed() -> void:
	cpu_count = max(0, cpu_count - 1)
	cpu_label.text = str(cpu_count)

func _on_cpu_plus_pressed() -> void:
	cpu_count = min(player_count - 1, cpu_count + 1)
	cpu_label.text = str(cpu_count)

func _on_difficulty_pressed() -> void:
	if cpu_difficulty == "random_bot":
		cpu_difficulty = "greedy_bot"
		difficulty_label.text = "Greedy"
	else:
		cpu_difficulty = "random_bot"
		difficulty_label.text = "Random"

func _on_start_pressed() -> void:
	GameManager.player_count = player_count
	GameManager.player_types.clear()
	for i in range(player_count):
		if i >= player_count - cpu_count:
			GameManager.player_types.append(cpu_difficulty)
		else:
			GameManager.player_types.append("human")
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_options_pressed() -> void:
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

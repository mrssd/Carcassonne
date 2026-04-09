class_name EndGameOverlay
extends Control

func setup(players: Array, scores: Array, colors: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	#Dark backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.75)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	#CenterContainer
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.06, 0.08, 1.0)
	card_style.corner_radius_top_left = 16
	card_style.corner_radius_top_right = 16
	card_style.corner_radius_bottom_right = 16
	card_style.corner_radius_bottom_left = 16
	card_style.content_margin_left = 40.0
	card_style.content_margin_right = 40.0
	card_style.content_margin_top = 32.0
	card_style.content_margin_bottom = 32.0
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(400.0, 0.0)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	#Title
	var title := Label.new()
	title.text = "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	#Column headers sit above the separator
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var swatch_spacer := Control.new()
	swatch_spacer.custom_minimum_size = Vector2(16.0, 0.0)
	header.add_child(swatch_spacer)

	var player_hdr := Label.new()
	player_hdr.text = "Player"
	player_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hdr.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	header.add_child(player_hdr)

	var score_hdr := Label.new()
	score_hdr.text = "Score"
	score_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_hdr.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	header.add_child(score_hdr)

	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	# Sort players by score descending
	var entries: Array = []
	for i in range(players.size()):
		entries.append({"index": i, "name": players[i], "score": scores[i]})
	entries.sort_custom(func(a, b): return a["score"] > b["score"])
	var top_score: int = entries[0]["score"]

	# Rows use a tighter inner container so the separator gaps stay wider
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 6)
	vbox.add_child(rows_box)

	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var swatch := ColorRect.new()
		swatch.color = colors[entry["index"]]
		swatch.custom_minimum_size = Vector2(16.0, 16.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)

		var name_lbl := Label.new()
		name_lbl.text = entry["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry["score"] == top_score:
			name_lbl.add_theme_color_override("font_color", Color.GOLD)
		row.add_child(name_lbl)

		var score_lbl := Label.new()
		score_lbl.text = str(entry["score"])
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if entry["score"] == top_score:
			score_lbl.add_theme_color_override("font_color", Color.GOLD)
		row.add_child(score_lbl)

		rows_box.add_child(row)

	vbox.add_child(HSeparator.new())

	#Winner announcement
	var winner_lbl := Label.new()
	winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_lbl.add_theme_font_size_override("font_size", 20)
	winner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var winners: Array = entries.filter(func(e): return e["score"] == top_score)
	if winners.size() == 1:
		winner_lbl.text = "%s wins!" % winners[0]["name"]
		winner_lbl.add_theme_color_override("font_color", Color.GOLD)
	else:
		var names: String = ""
		for i in range(winners.size()):
			if i > 0: names += ", "
			names += winners[i]["name"]
		winner_lbl.text = "Tie: %s" % names
	vbox.add_child(winner_lbl)

	#Main Menu button
	var btn := Button.new()
	btn.text = "Main Menu"
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/mainMenu.tscn"))
	vbox.add_child(btn)

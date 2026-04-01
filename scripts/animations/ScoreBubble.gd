extends Node
class_name ScoreBubble

func play(board: Board, world_pos: Vector2, score: int) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 100
	panel.z_as_relative = false

	var label := Label.new()
	label.text = "+%d" % score
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	panel.add_child(label)
	board.add_child(panel)

	panel.position = world_pos - Vector2(20, 40)
	panel.modulate.a = 0.0

	var drop_tween = create_tween().set_parallel(true)
	drop_tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	drop_tween.tween_property(panel, "position:y", panel.position.y + 10.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await drop_tween.finished

	await get_tree().create_timer(0.5).timeout

	var fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_property(panel, "modulate:a", 0.0, 0.8)
	fade_tween.tween_property(panel, "position:y", panel.position.y - 20.0, 0.8) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await fade_tween.finished

	panel.queue_free()

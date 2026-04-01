extends Node
class_name ScoreBubble

func play(board: Board, meeple: Node2D, score: int) -> void:
	var world_pos := meeple.global_position

	#Score bubble panel
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

	#Label properties
	var label := Label.new()
	label.text = "+%d" % score
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	panel.add_child(label)
	board.add_child(panel)
	panel.position = world_pos - Vector2(20, 60) #ADJUST this vector if want to change panel position (higher lower etc)
	panel.modulate.a = 0.0

	#Drop the bubble onto the scene
	var drop_tween = create_tween().set_parallel(true)#Makes animaton happen simulatenously
	drop_tween.tween_property(panel, "modulate:a", 1.0, 0.15) #Uses cubic curve to give feeling of dropping and stopping, modulate:a modifies alpha in modulate color from 0 to 1 over 0.15 seconds
	drop_tween.tween_property(panel, "position:y", panel.position.y + 10.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC) #position:y modifies y inside position vector, basically over 0.15 seconds animate from current value to currenty + 10
	await drop_tween.finished 

	await get_tree().create_timer(0.8).timeout

	#Fade out bubble and meeple together
	var fade_tween = create_tween().set_parallel(true) #Makes animation happen simulatenously
	fade_tween.tween_property(panel, "modulate:a", 0.0, 0.5) #Same as above
	fade_tween.tween_property(panel, "position:y", panel.position.y - 30.0, 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	if is_instance_valid(meeple):
		fade_tween.tween_property(meeple, "modulate:a", 0.0, 0.5)
	await fade_tween.finished

	panel.queue_free()
	if is_instance_valid(meeple):
		meeple.remove()

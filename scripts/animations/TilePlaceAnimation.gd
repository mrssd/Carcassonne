class_name TilePlaceAnimation

static func play(tile: Node2D, final_pos: Vector2) -> void:
	tile.position = final_pos + Vector2(0, -40)
	tile.modulate = Color(1, 1, 1, 0)

	var tween := tile.create_tween().set_parallel(true)
	tween.tween_property(tile, "position:y", final_pos.y, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(tile, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

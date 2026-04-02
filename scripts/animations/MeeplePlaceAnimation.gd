class_name MeeplePlaceAnimation

static func play(meeple: Node2D) -> void:
	var final_global_y := meeple.global_position.y
	meeple.global_position.y = final_global_y - 30
	meeple.modulate.a = 0.0

	var tween := meeple.create_tween().set_parallel(true)
	tween.tween_property(meeple, "global_position:y", final_global_y, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(meeple, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

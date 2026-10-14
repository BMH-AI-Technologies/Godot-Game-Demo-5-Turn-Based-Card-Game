extends Label

func show_value(value: String, tint: Color, reduced: bool, speed: float) -> void:
	text = value
	modulate = tint
	var tween := create_tween().set_parallel()
	if not reduced:
		tween.tween_property(self, "position:y", position.y - 65, 0.7 / speed)
	tween.tween_property(self, "modulate:a", 0.0, 0.8 / speed)
	tween.chain().tween_callback(queue_free)

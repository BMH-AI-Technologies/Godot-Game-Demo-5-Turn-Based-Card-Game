class_name ManaBar
extends ProgressBar
## Fixed scene width; one segment per mana. Redrawn only when values/layout change.
@export var fill_color: Color = Color("#599ec8")
@export var segment_color: Color = Color.WHITE

func _ready() -> void:
	var fill: StyleBoxFlat = get_theme_stylebox("fill").duplicate()
	fill.bg_color = fill_color
	add_theme_stylebox_override("fill", fill)
	resized.connect(queue_redraw)

func set_mana(current: int, maximum: int = 10) -> void:
	max_value = maxi(1, maximum)
	value = current
	%Value.text = str(current)
	%Value.anchor_right = 1.0 / max_value
	queue_redraw()

func _draw() -> void:
	for point in range(1, int(max_value)):
		var x: float = size.x * point / max_value
		draw_line(Vector2(x, 2), Vector2(x, size.y - 2), segment_color, 1.0)

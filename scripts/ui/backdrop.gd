class_name ForestBackdrop
extends Control
## Lightweight original scenery. Only cosmetic time; never consumes combat RNG.

var elapsed: float = 0.0
var reduced_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not reduced_motion:
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 720))
	draw_rect(Rect2(0, 0, 1280, 720), Color("#142529"))
	for i in range(12):
		draw_circle(Vector2(900, 153), 140 - i * 8, Color(0.65, 0.70, 0.52, 0.008 + i * 0.001))
	draw_circle(Vector2(900, 153), 51, Color("#babf92"))
	draw_circle(Vector2(923, 134), 46, Color("#263b39"))
	for layer in range(3):
		var tint: Color = [Color("#1c3634"), Color("#203d35"), Color("#122c29")][layer]
		for i in range(12):
			var x: float = float(i * 125 - 55 + layer * 49)
			var ground: float = 385.0 + layer * 38
			var top: float = float(80 + (i * 71 + layer * 29) % 135)
			draw_rect(Rect2(x + 24, top, 12 + layer * 3, ground - top), tint)
			for tier in range(4):
				var y: float = top + tier * 36
				var w: float = 35.0 + tier * 13
				draw_colored_polygon(PackedVector2Array([Vector2(x + 30, y - 50), Vector2(x + 30 - w, y + 45), Vector2(x + 30 + w, y + 45)]), tint)
	# Old gateway and broken stonework frame the clearing.
	for x in [75, 1135]:
		draw_rect(Rect2(x, 236, 62, 243), Color("#344740"))
		draw_rect(Rect2(x - 7, 226, 76, 16), Color("#516050"))
		draw_rect(Rect2(x - 12, 459, 86, 24), Color("#52624e"))
		for y in range(252, 460, 25):
			draw_line(Vector2(x, y), Vector2(x + 61, y), Color("#20332f"), 3)
			draw_line(Vector2(x + (25 if y % 2 else 39), y), Vector2(x + (25 if y % 2 else 39), y + 24), Color("#20332f"), 2)
	draw_rect(Rect2(0, 477, 1280, 243), Color("#202f2a"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 530), Vector2(354, 469), Vector2(980, 479), Vector2(1280, 532), Vector2(1280, 720), Vector2(0, 720)]), Color("#354038"))
	for i in range(45):
		var x: float = float((i * 193 + 21) % 1280)
		var y: float = float(480 + (i * 79) % 235)
		draw_rect(Rect2(x, y, 12 + i % 6 * 6, 3), Color("#475044"))
	for i in range(24):
		var x: float = float((i * 157 + 57) % 1240)
		var y: float = 240 + float(i * 91 % 225) + sin(elapsed * 0.5 + i) * 9
		draw_circle(Vector2(x, y), 1.5, Color(0.87, 0.81, 0.48, 0.35 + sin(elapsed + i) * 0.2))
	draw_rect(Rect2(0, 0, 1280, 90), Color(0.025, 0.05, 0.05, 0.45))

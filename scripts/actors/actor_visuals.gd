@tool
class_name ActorVisuals
extends Control
## Art has its own bounded area; it never contributes to the actor HUD's layout.
@export_range(0.1, 5.0, 0.1) var size_multiplier: float = 1.0:
	set(value):
		size_multiplier = value
		if is_node_ready():
			fit_sprite()
## Optional stance whose feet define the floor; lower animation pixels are clipped.
## Empty keeps the bounds of all poses as the ground reference.
@export var grounding_animation: StringName = &"":
	set(value):
		grounding_animation = value
		if is_node_ready():
			rebuild_bounds()

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var mount: Node2D = $Art
var frame_bounds: Rect2
var authored_position: Vector2
var frames: SpriteFrames

func _ready() -> void:
	authored_position = sprite.position
	resized.connect(fit_sprite)
	sprite.sprite_frames_changed.connect(rebuild_bounds)
	rebuild_bounds()

func rebuild_bounds() -> void:
	if frames != null and frames.changed.is_connected(rebuild_bounds):
		frames.changed.disconnect(rebuild_bounds)
	frames = sprite.sprite_frames
	frame_bounds = Rect2()
	if frames == null:
		return
	frames.changed.connect(rebuild_bounds)
	var ground_bounds := Rect2()
	# Cache the visible bounds of every pose so attacks cannot shift the feet.
	for animation in frames.get_animation_names():
		for index in range(frames.get_frame_count(animation)):
			var texture := frames.get_frame_texture(animation, index)
			if texture == null:
				continue
			var frame_rect := Rect2(Vector2.ZERO, texture.get_size())
			var pixels := texture.get_image()
			if pixels != null and not pixels.is_empty():
				frame_rect = Rect2(pixels.get_used_rect())
			if not frame_rect.has_area():
				continue
			if sprite.centered:
				frame_rect.position -= texture.get_size() * 0.5
			frame_bounds = frame_bounds.merge(frame_rect) if frame_bounds.has_area() else frame_rect
			if animation == grounding_animation:
				ground_bounds = ground_bounds.merge(frame_rect) if ground_bounds.has_area() else frame_rect
	if ground_bounds.has_area():
		frame_bounds.size.y = ground_bounds.end.y - frame_bounds.position.y
	fit_sprite()

func fit_sprite() -> void:
	if not is_node_ready() or not frame_bounds.has_area() or size.y <= 0:
		return
	var local_bounds := frame_bounds
	local_bounds.position += sprite.offset
	var authored_transform := sprite.transform
	authored_transform.origin = authored_position
	var bounds: Rect2 = authored_transform * local_bounds
	if bounds.size.y <= 0:
		return
	var fitted_scale: float = minf(size_multiplier, size.y / bounds.size.y)
	mount.scale = Vector2.ONE * fitted_scale
	mount.position = Vector2(size.x * 0.5 - bounds.get_center().x * fitted_scale, size.y - bounds.end.y * fitted_scale)

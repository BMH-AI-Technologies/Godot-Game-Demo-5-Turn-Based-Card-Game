extends Control
## The root follows the pointer; its only child is centered at the origin.
@export var card_scale: float = 0.65
@export var opacity: float = 0.78
var definition: CardDefinition
var artwork: Texture2D

func configure(data: CardDefinition, art: Texture2D, _source: Control) -> void:
	definition = data
	artwork = art

func _ready() -> void:
	%Card.definition = definition
	%Card.artwork = artwork
	%Card.drag_enabled = false
	%Card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Card.focus_mode = Control.FOCUS_NONE
	%Card.scale = Vector2.ONE * card_scale
	%Card.modulate.a = opacity
	%Card.resized.connect(center_card)
	%Card.minimum_size_changed.connect(fit_card.call_deferred)
	fit_card.call_deferred()

func fit_card() -> void:
	%Card.reset_size()
	center_card()

func center_card() -> void:
	%Card.position = -%Card.size * card_scale * 0.5

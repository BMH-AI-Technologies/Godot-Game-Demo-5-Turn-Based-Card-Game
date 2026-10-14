extends PanelContainer
signal card_dropped(card_id: String)
@export_enum("library", "deck", "both") var accepted_source: String = "library"
var accepts: Callable

func _ready() -> void:
	# Include panel headings, name fields and empty space as drop destinations.
	for control in find_children("*", "Control", true, false):
		forward_from(control)

func forward_from(control: Control) -> void:
	control.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("deck_card") or data.get("source", "") not in ["library", "deck"]:
		return false
	return (accepted_source == "both" or data.source == accepted_source) and accepts.is_valid() and accepts.call(str(data.deck_card))

func _drop_data(at: Vector2, data: Variant) -> void:
	if _can_drop_data(at, data):
		card_dropped.emit(str(data.deck_card))

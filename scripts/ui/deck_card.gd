@tool
class_name DeckCard
extends CardView
signal count_changed(card_id: String, delta: int)
var source: String = "library"
var copies: int = 0
var body_pressed: bool = false

func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		%Action.pressed.connect(func(): count_changed.emit(definition.id, 1 if source == "library" else -1))

func configure(data: CardDefinition, count: int, location: String, can_add: bool, reduced: bool) -> void:
	source = location
	copies = count
	reduced_motion = reduced
	definition = data
	playable = true
	drag_enabled = location == "deck" or can_add
	%Action.text = "+" if location == "library" else "−"
	%Action.tooltip_text = I18n.t("ADD_CARD" if location == "library" else "REMOVE_CARD")
	%Action.disabled = location == "library" and not can_add
	update_frame()
	reset_size.call_deferred()

func update_frame() -> void:
	super.update_frame()
	if is_node_ready() and definition != null:
		%Footer.text = I18n.t("IN_DECK", [copies]) if source == "library" else I18n.t("COPY_COUNT", [copies])

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		super._gui_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			body_pressed = true
		elif body_pressed:
			body_pressed = false
			count_changed.emit(definition.id, 1)
		accept_event()
	if event.is_action_pressed("ui_accept"):
		count_changed.emit(definition.id, 1)
		accept_event()

func _get_drag_data(_at: Vector2) -> Variant:
	body_pressed = false
	if not drag_enabled:
		return null
	begin_drag()
	return {"deck_card": definition.id, "source": source}

@tool
class_name CardView
extends PanelContainer

signal chosen(instance_id: int)
signal inspected(instance_id: int)
signal dragged(instance_id: int)
signal inspection_requested(card: CardDefinition, art: Texture2D)

@export var definition: CardDefinition:
	set(value):
		definition = value
		if is_node_ready():
			refresh_text()
@export_group("Appearance")
## Optional scene override; otherwise use CardDefinition.artwork.
@export var artwork: Texture2D:
	set(value):
		artwork = value
		if is_node_ready():
			refresh_text()

var instance_id: int = 0
var playable: bool = true
var show_playability: bool = false
var selected: bool = false
var replace_marked: bool = false
var drag_enabled: bool = true
var reduced_motion: bool = false
var hovering: bool = false
var opening_selection: bool = false
var display_scale: float = 1.0
var drag_in_progress: bool = false
var drawing: bool = false
var tween: Tween

func _ready() -> void:
	refresh_text()
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(hover.bind(true))
	mouse_exited.connect(hover.bind(false))
	focus_entered.connect(hover.bind(true))
	focus_exited.connect(hover.bind(false))

func setup(data: CardDefinition, id: int, can_play: bool = true) -> void:
	instance_id = id
	playable = can_play
	definition = data
	refresh_text()

func refresh_text() -> void:
	if definition == null:
		return
	%Cost.text = str(definition.cost)
	%Title.text = I18n.t(definition.title)
	%Artwork.texture = artwork if artwork != null else definition.artwork
	%Category.text = I18n.t(definition.kind).to_upper()
	%Rules.text = I18n.t(definition.rules)
	var payment_hint := "CARD_NORMAL" if definition.kind == "Attack" else "CARD_RESERVE"
	tooltip_text = I18n.t("CARD_TOOLTIP", [definition.title, definition.cost, definition.kind, definition.rules, payment_hint])
	for effect in definition.effects:
		if effect.operation == "weak":
			tooltip_text += "\n" + I18n.t("WEAK_HELP")
		elif effect.operation == "strength":
			tooltip_text += "\n" + I18n.t("STRENGTH_HELP")
	update_frame()

func update_frame() -> void:
	if not is_node_ready() or definition == null:
		return
	z_index = 5 if hovering or selected else 0
	%Footer.text = I18n.t("CARD_REPLACE") if replace_marked else ""
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	style.bg_color = Color("#132326") if playable else Color("#252c2b")
	var accent: Color = {"Attack": Color("#c99767"), "Skill": Color("#78bba6"), "Block": Color("#78bba6"), "Special": Color("#9e99d2")}.get(definition.kind, GameUI.GOLD)
	style.border_color = GameUI.RED if replace_marked else (GameUI.GOLD if selected else accent)
	if opening_selection:
		%Footer.text = I18n.t("CARD_REPLACE" if replace_marked else "CARD_KEEP")
		self_modulate.a = 0.55 if replace_marked else 1.0
	style.set_border_width_all(3 if selected or replace_marked else 2)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_offset = Vector2(0, 4)
	if show_playability:
		style.border_color = (GameUI.GOLD if selected else Color("#8af5cb")) if playable else Color("#495855")
		style.set_border_width_all(3 if playable else 1)
		style.shadow_size = 12 if playable else 2
		style.shadow_offset = Vector2.ZERO
		style.shadow_color = Color(0.3, 1.0, 0.7, 0.38) if playable else Color(0, 0, 0, 0.3)
	add_theme_stylebox_override("panel", style)

func hover(active: bool) -> void:
	if drag_in_progress or drawing:
		return
	hovering = active
	if active:
		inspected.emit(instance_id)
	z_index = 5 if active or selected else 0
	if tween:
		tween.kill()
	pivot_offset = size * 0.5
	if not reduced_motion:
		tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ONE * display_scale * (1.035 if active else 1.0), 0.1)
	else:
		scale = Vector2.ONE * display_scale

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or drawing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		inspection_requested.emit(definition, artwork)
		accept_event()
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
		chosen.emit(instance_id)
		accept_event()

func make_drag_preview() -> Control:
	var preview = load("res://scenes/components/card_drag_preview.tscn").instantiate()
	preview.configure(definition, artwork, self)
	return preview

func begin_drag() -> void:
	drag_in_progress = true
	if tween:
		tween.kill()
	scale = Vector2.ONE * display_scale
	modulate.a = 0.35
	set_drag_preview(make_drag_preview())

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and drag_in_progress:
		drag_in_progress = false
		modulate.a = 1.0
		hover(false)

func _get_drag_data(_at: Vector2) -> Variant:
	if not drag_enabled or drawing or Engine.is_editor_hint():
		return null
	dragged.emit(instance_id)
	begin_drag()
	return {"card": instance_id}

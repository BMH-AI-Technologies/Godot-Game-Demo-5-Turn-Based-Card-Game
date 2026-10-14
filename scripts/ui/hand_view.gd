class_name HandView
extends Control
## Repeated cards use a PackedScene; the only calculated UI layout is the hand.
signal chosen(card_id: int)
signal inspected(card_id: int)
signal dragged(card_id: int)
signal inspection_requested(card: CardDefinition, art: Texture2D)
signal card_dealt(card_id: int)
@export var card_scene: PackedScene = preload("res://scenes/components/card.tscn")
@export var maximum_spacing: float = 258.0
@export var card_scale: float = 1.0
@export var center_vertically: bool = false
@export_range(0.0, 3.0, 0.05) var deal_start_delay: float = 0.0
var dealing: bool = false
var cards: Dictionary = {}
var order: Array[int] = []

func _ready() -> void:
	resized.connect(arrange)

func render(combat: Combat, selected: int, replacements: Array, busy: bool, settings: GameProfile, pending_draws: Array[int] = []) -> void:
	if dealing:
		return
	order.clear()
	for instance in combat.hand:
		order.append(instance.id)
	for id in cards.keys():
		if id not in order:
			remove_child(cards[id])
			cards[id].queue_free()
			cards.erase(id)
	for instance in combat.hand:
		var fresh: bool = not cards.has(instance.id)
		var view: CardView
		if fresh:
			view = card_scene.instantiate()
			add_child(view)
			cards[instance.id] = view
			view.minimum_size_changed.connect(arrange.call_deferred)
			view.chosen.connect(func(id): chosen.emit(id))
			view.inspected.connect(func(id): inspected.emit(id))
			view.dragged.connect(func(id): dragged.emit(id))
			view.inspection_requested.connect(func(data, art): inspection_requested.emit(data, art))
		else:
			view = cards[instance.id]
		view.setup(instance.definition, instance.id, combat.phase == Combat.Phase.OPENING or combat.card_error(instance).is_empty())
		view.opening_selection = combat.phase == Combat.Phase.OPENING
		view.show_playability = combat.phase == Combat.Phase.PLAYER and not busy
		view.display_scale = card_scale
		view.scale = Vector2.ONE * card_scale
		view.selected = not replacements.has(instance.id) if view.opening_selection else selected == instance.id
		view.replace_marked = replacements.has(instance.id)
		view.reduced_motion = settings.reduced_motion
		view.drag_enabled = combat.phase == Combat.Phase.PLAYER and not busy
		view.update_frame()
		if instance.id in pending_draws:
			view.modulate.a = 0
	arrange.call_deferred()

func arrange() -> void:
	if order.is_empty() or dealing:
		return
	# Wrapped labels may briefly grow during first layout or locale changes.
	# Reset once their minimum changes so cards can shrink back to scene size.
	for id in order:
		cards[id].reset_size()
	var width: float = cards[order[0]].size.x * card_scale
	var spacing: float = minf(maximum_spacing, (size.x - width - 32) / maxi(1, order.size() - 1))
	var total: float = width + spacing * (order.size() - 1)
	for i in range(order.size()):
		var view: CardView = cards[order[i]]
		view.pivot_offset = view.size * 0.5
		var y: float = (size.y - view.size.y * card_scale) * 0.5 if center_vertically else 0.0
		view.position = Vector2((size.x - total) * 0.5 + i * spacing, y) + view.size * (card_scale - 1.0) * 0.5

func clear_cards() -> void:
	for view in cards.values():
		view.queue_free()
	cards.clear()
	order.clear()

func deal(settings: GameProfile, source: Control, ids: Array[int], start_delay: float = 0.0) -> void:
	var incoming: Array[int] = []
	for id in ids:
		if cards.has(id) and id not in incoming:
			incoming.append(id)
	if incoming.is_empty():
		return
	for id in incoming:
		var view: CardView = cards[id]
		view.drawing = true
		view.hovering = false
		if view.tween:
			view.tween.kill()
		view.modulate.a = 0.0
	await get_tree().process_frame
	arrange()
	dealing = true
	var origin := get_global_transform().affine_inverse() * source.get_global_rect().get_center()
	var sequence := create_tween().set_parallel()
	for i in range(incoming.size()):
		var view: CardView = cards[incoming[i]]
		var destination := view.position
		var delay: float = (start_delay + i * 0.14) / settings.animation_speed
		var duration: float = 0.5 / settings.animation_speed
		view.z_index = 20 + i
		if not settings.reduced_motion:
			view.position = origin - view.size * 0.5
			view.scale = Vector2.ONE * source.size.x / view.size.x
			sequence.tween_property(view, "position", destination, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			sequence.tween_property(view, "scale", Vector2.ONE * card_scale, duration).set_delay(delay)
		sequence.tween_property(view, "modulate:a", 1.0, 0.12 / settings.animation_speed).set_delay(delay)
		sequence.tween_callback(card_dealt.emit.bind(incoming[i])).set_delay(delay)
	await sequence.finished
	for id in incoming:
		var view: CardView = cards[id]
		view.drawing = false
		view.update_frame()
	dealing = false
	arrange()

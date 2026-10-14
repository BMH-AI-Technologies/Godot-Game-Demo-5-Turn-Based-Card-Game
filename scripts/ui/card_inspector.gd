class_name CardInspector
extends GamePopup
## Read-only carousel: linked resources share the same card UI and remain unmodified.
@export var card_scene: PackedScene = preload("res://scenes/components/inspection_card.tscn")
var subject: Resource
var artwork: Texture2D
var source: ActorState
var combat: Combat
var entries: Array[Resource] = []
var views: Array[CardView] = []
var selected_index: int = 0
var motion: Tween
var reduced_motion: bool = false
var animation_speed: float = 1.0
var card_view: CardView:
	get: return views[selected_index] if not views.is_empty() else null

func _ready() -> void:
	super._ready()
	visibility_changed.connect(func(): set_process_input(is_visible_in_tree()))
	set_process_input(is_visible_in_tree())
	%Shade.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			# Consume the closing click before revealing the controls underneath.
			get_viewport().set_input_as_handled()
			closed.emit())
	%Previous.pressed.connect(func(): focus_card(selected_index - 1))
	%Next.pressed.connect(func(): focus_card(selected_index + 1))
	%Carousel.resized.connect(func(): arrange(false))

func configure(data: Resource, art: Texture2D = null, actor: ActorState = null, model: Combat = null) -> void:
	clear_inspection()
	subject = data
	artwork = art
	source = actor
	combat = model
	entries = [data]
	if data is ActorDefinition:
		for ability in data.abilities:
			if ability is EnemySkill and not ability.hidden and ability.kind in ["Special", "Ultimate"]:
				entries.append(ability)
	# Follow references once per resource; cycles cannot create an endless carousel.
	var cursor: int = 0
	while cursor < entries.size():
		if entries[cursor] is CardDefinition:
			for linked in entries[cursor].referenced_cards():
				if not entries.has(linked):
					entries.append(linked)
		cursor += 1
	for index in range(entries.size()):
		var view: CardView = card_scene.instantiate()
		%Carousel.add_child(view)
		view.instance_id = index
		view.drag_enabled = false
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		view.focus_mode = Control.FOCUS_NONE
		view.reduced_motion = true
		view.chosen.connect(focus_card)
		views.append(view)
	refresh_text()
	arrange.call_deferred(false)

func clear_inspection() -> void:
	if motion:
		motion.kill()
		motion = null
	for view in views:
		%Carousel.remove_child(view)
		view.queue_free()
	views.clear()
	entries.clear()
	selected_index = 0
	subject = null
	artwork = null
	source = null
	combat = null

func refresh_text() -> void:
	for index in range(entries.size()):
		var entry: Resource = entries[index]
		var view: CardView = views[index]
		if entry is ActorDefinition:
			var display := CardDefinition.new()
			display.title = entry.title
			display.kind = "Boss" if entry.is_boss else "Enemy"
			display.artwork = artwork
			display.rules = I18n.t("ENEMY_CARD_STATS", [source.hp, entry.max_hp, entry.base_attack, entry.base_block]) + "\n\n" + I18n.t(entry.description)
			view.definition = display
			view.get_node("%Cost").get_parent().hide()
		elif entry is EnemySkill:
			var display := CardDefinition.new()
			display.title = entry.title
			display.cost = entry.cost
			display.kind = entry.kind
			display.artwork = entry.icon
			display.rules = entry.description_text(combat, source)
			view.definition = display
		else:
			view.artwork = artwork if index == 0 else null
			view.definition = entry
		view.tooltip_text = ""
	%Source.text = I18n.t(source.definition.title) if source != null else I18n.t("CARD_INSPECT")
	arrange.call_deferred(false)

func focus_card(index: int) -> void:
	if index < 0 or index >= views.size() or index == selected_index:
		return
	selected_index = index
	arrange(not reduced_motion)

func arrange(animate: bool) -> void:
	if not is_node_ready() or views.is_empty():
		return
	if motion:
		motion.kill()
	if animate:
		motion = create_tween().set_parallel()
	var spacing: float = minf(470.0, %Carousel.size.x * 0.27)
	for index in range(views.size()):
		var view := views[index]
		var distance: int = index - selected_index
		view.reset_size()
		view.pivot_offset = view.size * 0.5
		view.visible = absi(distance) <= 1
		view.display_scale = 1.0 if distance == 0 else 0.72
		view.z_index = 6 if distance == 0 else 1
		var destination: Vector2 = %Carousel.size * 0.5 + Vector2(distance * spacing, 0) - view.size * 0.5
		var target_scale: Vector2 = Vector2.ONE * view.display_scale
		# Keep card faces opaque so the dimmed battlefield cannot bleed through.
		var tint := Color.WHITE if distance == 0 else Color(0.78, 0.78, 0.78, 1.0)
		if animate:
			motion.tween_property(view, "position", destination, 0.25 / animation_speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			motion.tween_property(view, "scale", target_scale, 0.25 / animation_speed)
			motion.tween_property(view, "modulate", tint, 0.25 / animation_speed)
		else:
			view.position = destination
			view.scale = target_scale
			view.modulate = tint
	%Previous.visible = views.size() > 1
	%Next.visible = views.size() > 1
	%Previous.disabled = selected_index == 0
	%Next.disabled = selected_index == views.size() - 1
	%Position.visible = views.size() > 1
	%Position.text = "%d / %d" % [selected_index + 1, views.size()]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ui_left"):
		focus_card(selected_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		focus_card(selected_index + 1)
		get_viewport().set_input_as_handled()

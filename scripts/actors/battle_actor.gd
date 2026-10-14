@tool
class_name BattleActor
extends Control
## A scene-authored actor: stats here, visual nodes below, combat state in model.

signal targeted(actor_id: int)
signal card_dropped(card_id: int, actor_id: int)
signal inspection_requested(skill: EnemySkill, actor_id: int)
signal actor_inspection_requested(actor_id: int)

@export_group("Identity")
@export var actor_key: String = ""
## Name and description are plain text, translated only for the game UI.
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_group("Stats")
@export_range(1, 9999) var max_health: int = 30
@export_range(0, 999) var attack: int = 4
@export_range(0, 999) var defense: int = 4
@export_range(120, 500) var health_bar_width: float = 310.0

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var intent_view: EnemyIntentView = %IntentView
@onready var mana_label: Label = %EnemyMana
@onready var mana_bar: ManaBar = %ManaBar
@onready var health_label: Label = %HealthText
@onready var status_label: Label = %Status
@onready var bar: ProgressBar = %HealthBar
@onready var target_button: Button = %TargetButton
var actor_id: int = 0
var state: ActorState
var model: Combat
var reduced_motion: bool = false
var motion: Tween
var origin: Vector2

func _ready() -> void:
	origin = sprite.position
	%ActorName.text = display_name
	bar.max_value = max_health
	bar.value = max_health
	%HealthDisplay.custom_minimum_size.x = health_bar_width
	health_label.text = "%d / %d" % [max_health, max_health]
	if Engine.is_editor_hint():
		return
	target_button.pressed.connect(func(): targeted.emit(actor_id))
	target_button.gui_input.connect(_inspect_input)
	intent_view.pressed.connect(func(): targeted.emit(actor_id))
	intent_view.inspection_requested.connect(func(skill): inspection_requested.emit(skill, actor_id))
	target_button.set_drag_forwarding(Callable(), can_receive_card, receive_card)
	sprite.animation_finished.connect(_animation_finished)
	play_animation("idle")

func build_definition() -> ActorDefinition:
	var data := ActorDefinition.new()
	data.id = actor_key
	data.title = display_name
	data.description = description
	data.max_hp = max_health
	data.base_attack = attack
	data.base_block = defense
	return data

func bind_actor(actor_state: ActorState, combat: Combat, reduced: bool) -> void:
	state = actor_state
	model = combat
	actor_id = state.id
	set_reduced_motion(reduced)
	refresh()

func refresh() -> void:
	if state == null:
		return
	%ActorName.text = I18n.t(state.definition.title)
	bar.max_value = state.definition.max_hp
	bar.value = state.hp
	health_label.text = I18n.t("HP_VALUE", [state.hp, state.definition.max_hp])
	status_label.text = I18n.t("BLOCK_VALUE", [state.block])
	if state.weak > 0:
		status_label.text += " · " + I18n.t("WEAK_VALUE", [state.weak])
	if state.strength > 0:
		status_label.text += " · " + I18n.t("STRENGTH_VALUE", [state.strength])
	target_button.tooltip_text = ""
	for ability in state.definition.abilities:
		if ability.kind == "Ultimate" and not (ability is EnemySkill and ability.hidden):
			target_button.tooltip_text += I18n.t("ULTIMATE_INSPECT", [ability.title, ability.cost, ability.cooldown])
	target_button.disabled = state.hp <= 0
	if actor_id == 0:
		%Intent.hide()
		mana_bar.hide()
		mana_label.text = ""
	else:
		%Intent.show()
		mana_bar.show()
		mana_bar.set_mana(state.mana)
		intent_view.configure(model, state)
		mana_label.text = ""
		if state.hp > 0 and state.intent != null:
			if state.intent.kind in ["Special", "Ultimate"] and not state.intent_canceled:
				mana_label.text = I18n.t("SKILL_INTENT_META", [state.intent.cost, state.intent.cooldown])

func _inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if actor_id > 0 and state != null and state.hp > 0:
			actor_inspection_requested.emit(actor_id)
			accept_event()

func can_receive_card(_at: Vector2, data: Variant) -> bool:
	return state != null and state.hp > 0 and data is Dictionary and data.has("card")

func receive_card(_at: Vector2, data: Variant) -> void:
	card_dropped.emit(int(data.card), actor_id)

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		sprite.pause()
	elif state == null or state.hp > 0:
		play_animation("idle")

func play_animation(cue: String, speed: float = 1.0) -> void:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(cue):
		sprite.play(cue, speed)
	if reduced_motion:
		sprite.pause()

func act(direction: float, duration: float, cue: String) -> void:
	# Fit the whole clip into the windup + impact presentation interval.
	var clip_duration: float = 0.4
	if sprite.sprite_frames.has_animation(cue):
		clip_duration = 0.0
		for frame in range(sprite.sprite_frames.get_frame_count(cue)):
			clip_duration += sprite.sprite_frames.get_frame_duration(cue, frame) / sprite.sprite_frames.get_animation_speed(cue)
	play_animation(cue, clip_duration / maxf(duration, 0.01))
	if reduced_motion:
		return
	if motion:
		motion.kill()
	sprite.position = origin
	motion = create_tween()
	motion.tween_property(sprite, "position:x", origin.x + direction * 48, duration * 0.35)
	motion.tween_property(sprite, "position:x", origin.x, duration * 0.65)

func flash(tint: Color, duration: float) -> void:
	play_animation("hurt")
	sprite.modulate = tint
	create_tween().tween_property(sprite, "modulate", Color.WHITE, duration)

func die(duration: float) -> void:
	play_animation("death")
	target_button.disabled = true
	create_tween().tween_property(self, "modulate:a", 0.3, duration)

func _animation_finished() -> void:
	if sprite.animation != &"death":
		play_animation("idle")

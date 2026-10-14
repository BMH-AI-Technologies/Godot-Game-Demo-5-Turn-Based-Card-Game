class_name EnemyIntentView
extends Button
signal inspection_requested(skill: EnemySkill)
var skill: EnemySkill
@onready var icon_view: TextureRect = %Icon
@onready var value_label: Label = %Value

func configure(combat: Combat, actor: ActorState) -> void:
	skill = actor.intent as EnemySkill
	icon_view.texture = skill.icon if skill != null else null
	icon_view.visible = actor.hp > 0 and skill != null and not skill.hidden
	disabled = actor.hp <= 0 or skill == null or skill.hidden
	tooltip_text = combat.intent_text(actor) if not disabled else ""
	value_label.add_theme_font_size_override("font_size", 28)
	modulate.a = 0.5 if actor.intent_canceled else 1.0
	if actor.hp <= 0:
		value_label.text = I18n.t("DEFEATED")
	elif actor.intent_canceled or skill == null or skill.hidden:
		value_label.text = I18n.t("NO_ACTION")
		value_label.add_theme_font_size_override("font_size", 20)
	elif skill.kind == "Attack":
		var damage := skill.get_effects(actor)[0]
		value_label.text = str(combat.damage_amount(actor, combat.player, damage.base_amount(actor)))
		if damage.hits > 1:
			value_label.text += " × %d" % damage.hits
	elif skill.kind == "Block":
		value_label.text = str(skill.get_effects(actor)[0].amount)
	else:
		value_label.text = I18n.t(skill.title)
		value_label.add_theme_font_size_override("font_size", 20)
	custom_minimum_size.x = maxf(112.0, value_label.get_minimum_size().x + 84.0)
	var style: StyleBoxFlat = get_theme_stylebox("normal").duplicate()
	style.border_color = GameUI.GOLD if skill != null and skill.kind == "Ultimate" else Color("#6d9e94")
	add_theme_stylebox_override("normal", style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not disabled:
		inspection_requested.emit(skill)
		accept_event()

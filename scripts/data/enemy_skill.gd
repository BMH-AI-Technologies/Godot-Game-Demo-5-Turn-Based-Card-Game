class_name EnemySkill
extends AbilityDefinition
## Immutable, reusable enemy card. Cooldowns/mana belong to ActorState.
@export_group("Card Appearance")
@export var icon: Texture2D
## Plain-text ability rules, translated when displayed on the inspection card.
@export_multiline var description: String = ""
@export var hidden: bool = false
## Optional AnimatedSprite2D animation; empty uses the actor's normal attack/cast.
@export var animation: StringName = &""

func description_text(combat, source) -> String:
	var details: Array[String] = []
	for effect in get_effects(source):
		var detail: String = effect.describe(combat, source, combat.player)
		if not detail.is_empty():
			details.append(detail)
	return I18n.t("SKILL_COOLDOWN", [cooldown]) + "\n\n" + I18n.t(description) + ("\n\n" + "\n".join(details) if not details.is_empty() else "")

## Unique reaction subclasses resolve after player payment, before effects.
func intercept_card(_combat, _source, _card, _context: Dictionary) -> bool:
	return false

class_name CardDefinition
extends Resource

## Stable save identifier. Keep this when renaming the resource or card.
@export var id: String = ""
## Printed name in plain English; localization/text.csv supplies Vietnamese.
@export var title: String = ""
@export var cost: int = 1
@export_enum("Attack", "Skill") var kind: String = "Attack"
@export_enum("Shared", "Knight", "Wizard", "Rogue") var hero_class: String = "Shared"
@export_enum("enemy", "self", "all_enemies") var target: String = "enemy"
@export var artwork: Texture2D
## Printed rules in plain English. Effect resources define the actual behavior.
@export_multiline var rules: String = ""
@export var effects: Array[CombatEffect] = []
@export_group("Availability")
@export var in_library: bool = true
@export var in_rewards: bool = true

func referenced_cards() -> Array:
	var result: Array = []
	for effect in effects:
		for card in effect.referenced_cards():
			if card != null and not result.has(card):
				result.append(card)
	return result

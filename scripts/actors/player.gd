@tool
class_name PlayerActor
extends BattleActor

@export_group("Hero")
@export var attack_bonus: int = 5
@export var mana_offset: int = 0
@export var natural_draw: int = 1

func build_definition() -> ActorDefinition:
	var data := super.build_definition()
	data.attack_bonus = attack_bonus
	data.mana_offset = mana_offset
	data.natural_draw = natural_draw
	return data

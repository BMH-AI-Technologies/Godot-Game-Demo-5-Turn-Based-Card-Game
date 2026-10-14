class_name EnemyEmptyPocketsSkill
extends EnemyBlockSkill
## Keep this unusual effect local; inherit ordinary scalable block afterward.
@export_group("Recovery")
@export var recovery_draw: int = 3

func get_effects(source) -> Array[CombatEffect]:
	var discard_hand := preload("res://scripts/effects/empty_pockets.gd").new()
	discard_hand.recovery_draw = recovery_draw
	var result: Array[CombatEffect] = [discard_hand]
	result.append_array(super.get_effects(source))
	return result

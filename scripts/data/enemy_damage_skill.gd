class_name EnemyDamageSkill
extends EnemySkill
## Shared by normal attacks, extra-damage attacks and multi-hit specials.
@export_group("Damage")
@export_range(0.0, 10.0, 0.05) var attack_multiplier: float = 1.0
@export var flat_damage: int = 0
@export_range(1, 10) var hits: int = 1

func get_effects(source) -> Array[CombatEffect]:
	var damage := CombatEffect.new()
	damage.attack_multiplier = attack_multiplier
	damage.amount = flat_damage
	damage.hits = hits
	var result: Array[CombatEffect] = [damage]
	result.append_array(super.get_effects(source))
	return result

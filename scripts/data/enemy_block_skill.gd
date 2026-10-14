class_name EnemyBlockSkill
extends EnemySkill
## Scale block from the actor's exported Defense; optional effects follow it.
@export_group("Block")
@export_range(0.0, 10.0, 0.05) var block_multiplier: float = 1.0
@export var flat_block: int = 0

func get_effects(source) -> Array[CombatEffect]:
	var block := CombatEffect.new()
	block.operation = "block"
	block.recipient = "source"
	block.amount = flat_block + floori(source.definition.base_block * block_multiplier)
	var result: Array[CombatEffect] = [block]
	result.append_array(super.get_effects(source))
	return result

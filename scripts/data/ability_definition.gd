class_name AbilityDefinition
extends Resource

## Stable identifier used by each actor's cooldown state.
@export var id: String = ""
## Printed skill name; use actual text with a matching translation entry.
@export var title: String = ""
@export_enum("Attack", "Block", "Special", "Ultimate", "Reaction") var kind: String = "Attack"
@export_group("Mana and Timing")
@export var cost: int = 0
## An action used at round r becomes eligible at r + cooldown.
@export var cooldown: int = 0
@export_enum("opponent", "self") var target: String = "opponent"
@export var effects: Array[CombatEffect] = []

func get_effects(_source) -> Array[CombatEffect]:
	return effects

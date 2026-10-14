class_name CardInstance
extends RefCounted

var id: int
var definition: CardDefinition
var cost_delta: int = 0

func _init(instance_id: int, data: CardDefinition) -> void:
	id = instance_id
	definition = data

func cost() -> int:
	return maxi(0, definition.cost + cost_delta)

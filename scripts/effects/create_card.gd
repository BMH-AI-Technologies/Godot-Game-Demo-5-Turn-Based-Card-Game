class_name CreateCardEffect
extends CombatEffect
@export var card: CardDefinition
@export_range(1, 10) var copies: int = 1

func apply(combat, _source, _targets: Array, _context: Dictionary) -> void:
	if card != null:
		for copy in range(copies):
			combat.create_card(card)

func referenced_cards() -> Array:
	return [card] if card != null else []

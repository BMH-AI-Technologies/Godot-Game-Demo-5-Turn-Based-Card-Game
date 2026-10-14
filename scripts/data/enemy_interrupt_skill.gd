class_name EnemyInterruptSkill
extends EnemySkill
## Off-turn cancellation uses the same mana pool without consuming normal intent.
@export_group("Interrupt Trigger")
@export var minimum_card_cost: int = 5

func intercept_card(combat, source, card, context: Dictionary) -> bool:
	if card.definition.kind != "Skill" or int(context.cost) < minimum_card_cost:
		return false
	if not combat.ability_ready(source, self):
		return false
	source.mana -= cost
	source.ready_round[id] = combat.round_number + cooldown
	return true

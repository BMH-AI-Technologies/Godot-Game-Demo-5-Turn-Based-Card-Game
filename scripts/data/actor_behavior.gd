class_name ActorBehavior
extends Resource
## Optional, stateless hooks for unique enemies/bosses. Store mutable values in
## actor.memory, never on this shared Resource. Normal enemies need no behavior.

func round_started(_combat, _actor) -> void:
	pass

func choose_intent(_combat, _actor) -> AbilityDefinition:
	return null

## Called after payment, before ANY card effect. true cancels the card.
func intercept_card(_combat, _actor, _card, _context: Dictionary) -> bool:
	return false

func card_finished(_combat, _actor, _card, _outcome: String) -> void:
	pass

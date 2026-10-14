extends CombatEffect
## A unique boss effect, composed with an ordinary self-block effect.
@export var recovery_draw: int = 3

func apply(combat, _source, _targets: Array, _context: Dictionary) -> void:
	var count: int = combat.hand.size()
	combat.discard.append_array(combat.hand)
	combat.hand.clear()
	combat.player.memory["recovery_draw"] = int(combat.player.memory.get("recovery_draw", 0)) + recovery_draw
	combat.record("hand_discarded", {"amount": count})
	combat.record("status", {"target": 0, "text": "RECOVERY_DRAW", "args": [recovery_draw]})

func describe(_combat, _source, _target) -> String:
	return I18n.t("EMPTY_POCKETS_INTENT", [recovery_draw])

extends ActorBehavior
## The phase belongs to the actor. Its interrupt is a separate EnemySkill.
@export var phase_strength: int = 1

func round_started(combat, actor) -> void:
	if actor.hp * 2 <= actor.definition.max_hp and not actor.memory.get("awakened", false):
		actor.memory["awakened"] = true
		actor.strength += phase_strength
		combat.record("status", {"target": actor.id, "text": "STRENGTH_GAIN", "args": [phase_strength]})

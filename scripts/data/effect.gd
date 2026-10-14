class_name CombatEffect
extends Resource
## Override apply() in a small Resource script for a genuinely unique effect.
## Effects run only in the model; animations consume the resulting events.

@export_enum("damage", "block", "draw", "mana", "heal", "weak", "strength", "interrupt") var operation: String = "damage"
## Mixed actions can affect the caster as well as their selected target.
@export_enum("targets", "source") var recipient: String = "targets"
@export var amount: int = 0
@export var hits: int = 1
## Enemy actions can scale directly with the enemy node's exported Attack.
@export var attack_multiplier: float = 0.0

func base_amount(source) -> int:
	return amount + floori(source.definition.base_attack * attack_multiplier)

## Used by the card inspector to show generated/referenced cards beside a card.
func referenced_cards() -> Array:
	return []

func apply(combat, source, targets: Array, context: Dictionary) -> void:
	if recipient == "source":
		targets = [source]
	match operation:
		"damage":
			var hit_targets: Dictionary = context.get("hit_targets", {})
			for hit in range(hits):
				# Snapshot a whole AoE wave before applying any of its hits.
				var wave: Array = []
				for target in targets:
					if target.hp > 0:
						wave.append([target, combat.damage_amount(source, target, base_amount(source), context.get("attack", false), not hit_targets.has(target.id))])
						hit_targets[target.id] = true
				for entry in wave:
					combat.deal_damage(source, entry[0], entry[1])
		"block":
			for target in targets:
				combat.gain_block(target, amount)
		"heal":
			for target in targets:
				combat.heal(target, amount)
		"weak":
			for target in targets:
				if target.hp > 0:
					target.weak = mini(3, target.weak + amount)
					combat.record("status", {"target": target.id, "text": "WEAK_GAIN", "args": [amount]})
		"draw":
			combat.draw_cards(amount)
		"strength":
			for target in targets:
				if target.hp > 0:
					target.strength += amount
					combat.record("status", {"target": target.id, "text": "STRENGTH_GAIN", "args": [amount]})
		"mana":
			# Normal mana caps at ten; excess never becomes reserve mana.
			var gained := mini(amount, maxi(0, 10 - combat.mana))
			combat.mana += gained
			if gained > 0:
				combat.record("mana", {"target": source.id, "amount": gained})
		"interrupt":
			for target in targets:
				combat.cancel_intent(target)

## Custom effects describe only their visible intent, never hidden reactions.
func describe(combat, source, target) -> String:
	match operation:
		"damage":
			return I18n.t("INTENT_DAMAGE", [combat.damage_amount(source, target, base_amount(source)), " × %d" % hits if hits > 1 else ""])
		"block": return I18n.t("INTENT_BLOCK", [amount])
		"weak": return I18n.t("WEAK_VALUE", [amount])
		"strength": return I18n.t("STRENGTH_GAIN", [amount])
	return ""

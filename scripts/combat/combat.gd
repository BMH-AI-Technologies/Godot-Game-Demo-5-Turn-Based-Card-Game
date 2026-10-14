class_name Combat
extends RefCounted
signal action_ended(action: String)
## Pure synchronous combat model. Commands validate before mutating and emit
## ordered presentation events. No Nodes, timers, animation or file access.

enum Phase { OPENING, PLAYER, ENEMY, WON, LOST }
var phase: Phase = Phase.OPENING
var revision: int = 0
var round_number: int = 1
var mana: int = 1
var max_mana: int = 1
var reserve: int = 0
var player: ActorState
var enemies: Array[ActorState] = []
var draw_pile: Array = []
var hand: Array = []
var discard: Array = []
var resolving: CardInstance
var next_card_id: int = 1
var events: Array[Dictionary] = []
var deck_rng := RandomNumberGenerator.new()
var ai_rng := RandomNumberGenerator.new()

func setup(content: GameContent, preset: Array, encounter: int, combat_seed: int, hero: ActorDefinition = null, foes: Array[ActorDefinition] = [], run_deck: bool = false) -> String:
	if not content.configuration_error().is_empty():
		return content.configuration_error()
	if content.encounter(encounter) == null:
		return I18n.t("Choose a valid encounter.")
	var error := content.validate_deck(preset, not run_deck)
	if not error.is_empty():
		return error
	deck_rng.seed = combat_seed
	ai_rng.seed = combat_seed ^ 0x5F3759DF
	player = ActorState.new(0, content.knight if hero == null else hero)
	if foes.is_empty():
		for id in content.encounter_enemies(encounter):
			foes.append(content.enemies[id])
	for i in range(foes.size()):
		enemies.append(ActorState.new(i + 1, foes[i]))
	for i in range(preset.size()):
		draw_pile.append(CardInstance.new(i + 1, content.cards[preset[i]]))
	next_card_id = preset.size() + 1
	hand = OpeningHand.sample(draw_pile, deck_rng)
	for card in hand:
		draw_pile.erase(card)
	OpeningHand.shuffle(draw_pile, deck_rng)
	start_round(false)
	phase = Phase.OPENING
	events.clear()
	return ""

func record(kind: String, values: Dictionary = {}) -> void:
	var event := values.duplicate(true)
	event["kind"] = kind
	event["round"] = round_number
	events.append(event)

func mulligan(ids: Array) -> String:
	if phase != Phase.OPENING:
		return I18n.t("The opening replacement is already complete.")
	var rejected: Array = []
	for id in ids:
		var card := find_card(id)
		if card == null or rejected.has(card):
			return I18n.t("Choose each opening card at most once.")
		rejected.append(card)
	events.clear()
	for card in rejected:
		hand.erase(card)
	# Rejected physical copies stay out of the pool until every replacement.
	for i in range(rejected.size()):
		var card: CardInstance = draw_pile.pop_back()
		hand.append(card)
		record("draw", {"card": card.id})
	draw_pile.append_array(rejected)
	OpeningHand.shuffle(draw_pile, deck_rng)
	phase = Phase.PLAYER
	revision += 1
	record("round", {"amount": round_number})
	action_ended.emit("mulligan")
	return ""

func find_card(id: int) -> CardInstance:
	for card in hand:
		if card.id == id:
			return card
	return null

func actor(id: int) -> ActorState:
	if id == 0:
		return player
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return null

func payment(card: CardInstance) -> Dictionary:
	var from_reserve: int = 0 if card.definition.kind == "Attack" else mini(reserve, card.cost())
	return {"normal": card.cost() - from_reserve, "reserve": from_reserve}

func card_error(card: CardInstance) -> String:
	if phase != Phase.PLAYER:
		return I18n.t("Wait for your turn.")
	if card == null or not hand.has(card):
		return I18n.t("That card is no longer in your hand.")
	if payment(card).normal > mana:
		if card.definition.kind == "Attack":
			return I18n.t("Attacks need %d normal mana. Reserve cannot pay for attacks.") % card.cost()
		return I18n.t("You need %d mana across your normal and reserve pools.") % card.cost()
	return ""

func has_playable_card() -> bool:
	if phase != Phase.PLAYER:
		return false
	for card in hand:
		if not card_error(card).is_empty():
			continue
		if card.definition.target == "self":
			return player.hp > 0
		for enemy in enemies:
			if enemy.hp > 0:
				return true
	return false

func play_card(id: int, target_id: int, expected_revision: int = -1) -> String:
	if expected_revision >= 0 and expected_revision != revision:
		return I18n.t("Combat changed; choose the card again.")
	var card := find_card(id)
	var error := card_error(card)
	if not error.is_empty():
		return error
	var targets: Array = []
	match card.definition.target:
		"enemy":
			var target := actor(target_id)
			if target == null or target == player or target.hp <= 0:
				return I18n.t("Choose a living enemy.")
			targets.append(target)
		"self":
			if target_id != 0:
				return I18n.t("Play this card on yourself or in the play zone.")
			targets.append(player)
		"all_enemies":
			for enemy in enemies:
				if enemy.hp > 0:
					targets.append(enemy)
			if targets.is_empty():
				return I18n.t("There are no living targets.")
	events.clear()
	var paid := payment(card)
	reserve -= paid.reserve
	mana -= paid.normal
	hand.erase(card)
	resolving = card
	revision += 1
	var context := {"attack": card.definition.kind == "Attack", "cost": card.cost(), "payment": paid, "hit_targets": {}}
	record("card", {"source": 0, "card": card.id, "title": card.definition.title, "type": card.definition.kind, "target": target_id})
	var interrupted: bool = false
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		for ability in enemy.definition.abilities:
			if ability is EnemySkill and ability.kind == "Reaction" and ability.intercept_card(self, enemy, card, context):
				interrupted = true
				break
		if not interrupted and enemy.definition.behavior != null:
			interrupted = enemy.definition.behavior.intercept_card(self, enemy, card, context)
		refresh_intent_affordability(enemy)
		if interrupted:
			record("interrupted", {"target": 0, "text": "INTERRUPTED"})
			break
	if not interrupted:
		for effect in card.definition.effects:
			effect.apply(self, player, targets, context)
	discard.append(card)
	resolving = null
	var outcome := "interrupted" if interrupted else "resolved"
	for enemy in enemies:
		if enemy.hp > 0 and enemy.definition.behavior != null:
			enemy.definition.behavior.card_finished(self, enemy, card, outcome)
	check_outcome()
	action_ended.emit("card")
	return ""

func draw_cards(count: int) -> int:
	var drawn: int = 0
	for i in range(count):
		if draw_pile.is_empty() and not discard.is_empty():
			draw_pile.append_array(discard)
			discard.clear()
			OpeningHand.shuffle(draw_pile, deck_rng)
			record("shuffle")
		if draw_pile.is_empty():
			break
		var card: CardInstance = draw_pile.pop_back()
		if hand.size() >= 10:
			discard.append(card)
			record("overflow", {"title": card.definition.title})
		else:
			hand.append(card)
			drawn += 1
			record("draw", {"card": card.id})
	return drawn

func end_turn() -> String:
	if phase != Phase.PLAYER:
		return I18n.t("It is not your turn.")
	events.clear()
	phase = Phase.ENEMY
	revision += 1
	reserve = mini(3, reserve + mana)
	mana = 0
	player.weak = maxi(0, player.weak - 1)
	player.vulnerable = maxi(0, player.vulnerable - 1)
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		enemy.block = 0
		var action := enemy.intent
		if action != null and not enemy.intent_canceled:
			if not enemy.intent_paid:
				enemy.mana -= action.cost
				enemy.ready_round[action.id] = round_number + action.cooldown
			enemy.last_action = action.kind
			record("action", {"source": enemy.id, "target": 0 if action.target == "opponent" else enemy.id, "title": action.title, "type": action.kind, "animation": action.animation if action is EnemySkill else &""})
			var targets: Array = [player] if action.target == "opponent" else [enemy]
			for effect in action.get_effects(enemy):
				effect.apply(self, enemy, targets, {})
		else:
			record("no_action", {"source": enemy.id})
		enemy.weak = maxi(0, enemy.weak - 1)
		enemy.vulnerable = maxi(0, enemy.vulnerable - 1)
		check_outcome()
		if phase == Phase.LOST or phase == Phase.WON:
			action_ended.emit("end_turn")
			return ""
	round_number += 1
	start_round(true)
	action_ended.emit("end_turn")
	return ""

## Generated cards stay in hand between turns, just like other unplayed cards.
func create_card(definition: CardDefinition) -> void:
	var card := CardInstance.new(next_card_id, definition)
	next_card_id += 1
	if hand.size() >= 10:
		discard.append(card)
		record("overflow", {"title": definition.title})
	else:
		hand.append(card)
		record("created", {"card": card.id, "title": definition.title})

func start_round(natural_draw: bool) -> void:
	player.block = 0
	max_mana = mini(10, round_number + player.definition.mana_offset)
	mana = max_mana
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		enemy.mana = mini(10, round_number)
		enemy.intent_canceled = false
		enemy.intent_paid = false
		if enemy.definition.behavior != null:
			enemy.definition.behavior.round_started(self, enemy)
		enemy.intent = plan_intent(enemy)
	if natural_draw:
		var recovery: int = int(player.memory.get("recovery_draw", 0))
		player.memory.erase("recovery_draw")
		if recovery > 0:
			draw_cards(recovery)
		draw_cards(player.definition.natural_draw)
	phase = Phase.PLAYER
	record("round", {"amount": round_number})

func plan_intent(enemy: ActorState) -> AbilityDefinition:
	if enemy.definition.behavior != null:
		var custom := enemy.definition.behavior.choose_intent(self, enemy)
		if custom != null and custom.kind != "Reaction" and ability_ready(enemy, custom):
			return custom
	var candidates: Array[AbilityDefinition] = []
	var weights: Array[int] = []
	var total_weight: int = 0
	for ability in enemy.definition.abilities:
		if ability.kind == "Reaction" or not ability_ready(enemy, ability):
			continue
		if ability.kind == "Block" and enemy.last_action == "Block":
			continue
		# Paid skills compete individually: more mana means greater likelihood.
		var weight: int = 15 * (maxi(0, ability.cost) + 1)
		match ability.kind:
			"Attack": weight = 35
			"Block": weight = 10
		candidates.append(ability)
		weights.append(weight)
		total_weight += weight
	if candidates.is_empty():
		return null
	var roll: int = ai_rng.randi_range(1, total_weight)
	for i in range(candidates.size()):
		roll -= weights[i]
		if roll <= 0:
			return candidates[i]
	return null

func ability_ready(enemy: ActorState, ability: AbilityDefinition) -> bool:
	return enemy.mana >= ability.cost and round_number >= int(enemy.ready_round.get(ability.id, 0))

## A reaction can consume normal mana, but never restores a canceled action.
func refresh_intent_affordability(enemy: ActorState) -> void:
	if enemy.intent == null or enemy.intent_canceled or enemy.mana >= enemy.intent.cost:
		return
	for ability in enemy.definition.abilities:
		if ability.kind == "Attack" and ability.cost <= enemy.mana:
			enemy.intent = ability
			record("intent_changed", {"source": enemy.id, "title": ability.title})
			return

## Paid cancellation leaves the enemy with no action and no replacement.
func cancel_intent(enemy: ActorState) -> bool:
	if enemy.hp <= 0 or enemy.intent == null or enemy.intent_canceled or enemy.intent.kind not in ["Special", "Ultimate"]:
		return false
	if enemy.mana < enemy.intent.cost:
		return false
	enemy.mana -= enemy.intent.cost
	enemy.ready_round[enemy.intent.id] = round_number + enemy.intent.cooldown
	enemy.intent_paid = true
	enemy.intent_canceled = true
	record("interrupted", {"target": enemy.id, "text": "INTERRUPTED_NO_ACTION"})
	return true

func damage_amount(source: ActorState, target: ActorState, base: int, attack_card: bool = false, first_hit: bool = true) -> int:
	var damage: float = float(base + source.strength)
	if attack_card and first_hit:
		damage += source.definition.attack_bonus
	if source.weak > 0:
		damage *= 0.75
	if target.vulnerable > 0:
		damage *= 1.25
	return maxi(0, int(floor(damage)))

func deal_damage(source: ActorState, target: ActorState, amount: int) -> void:
	if target.hp <= 0:
		return
	var blocked: int = mini(target.block, amount)
	target.block -= blocked
	var loss: int = mini(target.hp, amount - blocked)
	target.hp -= loss
	record("damage", {"source": source.id, "target": target.id, "amount": amount, "loss": loss, "blocked": blocked, "hp": target.hp, "block": target.block})
	if target.hp == 0:
		record("death", {"target": target.id})

func gain_block(target: ActorState, amount: int) -> void:
	if target.hp > 0:
		target.block += amount
		record("block", {"target": target.id, "amount": amount, "block": target.block})

func heal(target: ActorState, amount: int) -> void:
	if target.hp > 0:
		var gained: int = mini(amount, target.definition.max_hp - target.hp)
		target.hp += gained
		record("heal", {"target": target.id, "amount": gained, "hp": target.hp})

func check_outcome() -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	if player.hp <= 0:
		phase = Phase.LOST
	else:
		var living: int = 0
		for enemy in enemies:
			living += int(enemy.hp > 0)
		if living == 0:
			phase = Phase.WON
	if phase == Phase.WON or phase == Phase.LOST:
		record("outcome", {"won": phase == Phase.WON})

func intent_text(enemy: ActorState) -> String:
	if enemy.hp <= 0:
		return I18n.t("DEFEATED")
	if enemy.intent_canceled:
		return I18n.t("INTERRUPTED_NO_ACTION")
	if enemy.intent == null:
		return I18n.t("NO_ACTION")
	var parts: Array[String] = []
	for effect in enemy.intent.get_effects(enemy):
		var description: String = effect.describe(self, enemy, player)
		if not description.is_empty():
			parts.append(description)
	return I18n.t("%s\n%s") % [I18n.t(enemy.intent.title), " · ".join(parts)]

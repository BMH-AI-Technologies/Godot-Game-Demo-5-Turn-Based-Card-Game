class_name DemoRun
extends RefCounted
## Runtime state for an authored campaign; never mutates shared resources.
enum Phase { MAP, COMBAT, REWARD, COMPLETE, DEFEAT }
var campaign: CampaignDefinition
var phase: Phase = Phase.MAP
var stage: int = 0
var hp: int
var max_hp: int
var deck: Array[String] = []
var starting_deck: Array[String] = []
var offers: Array[String] = []
var healed: int = 0
var seed_value: int
var reward_rng := RandomNumberGenerator.new()

func _init(preset: Array[String], hero: ActorDefinition, run_seed: int, route: CampaignDefinition) -> void:
	campaign = route
	starting_deck = preset.duplicate()
	deck = preset.duplicate()
	max_hp = hero.max_hp
	hp = max_hp
	seed_value = run_seed
	reward_rng.seed = run_seed ^ 0x524557

func enter_battle(index: int) -> bool:
	if phase != Phase.MAP or index != stage or index < 0 or index >= campaign.encounters.size() or hp <= 0:
		return false
	phase = Phase.COMBAT
	return true

func finish_battle(combat: Combat, content: GameContent) -> bool:
	if phase != Phase.COMBAT or combat.phase not in [Combat.Phase.WON, Combat.Phase.LOST]:
		return false
	hp = clampi(combat.player.hp, 0, max_hp)
	if combat.phase == Combat.Phase.LOST:
		phase = Phase.DEFEAT
	elif stage == campaign.encounters.size() - 1:
		phase = Phase.COMPLETE
	else:
		var battle := campaign.encounters[stage]
		healed = mini(max_hp - hp, ceili(max_hp * clampf(battle.heal_percent, 0.0, 100.0) / 100.0))
		hp += healed
		var pool: Array = []
		for id in content.reward_cards(battle):
			if deck.count(id) < GameContent.COPY_LIMIT:
				pool.append(id)
		OpeningHand.shuffle(pool, reward_rng)
		offers.assign(pool.slice(0, mini(clampi(battle.reward_choices, 0, 3), pool.size())))
		if offers.is_empty():
			advance()
		else:
			phase = Phase.REWARD
	return true

func choose_reward(id: String) -> bool:
	if phase != Phase.REWARD or id not in offers:
		return false
	deck.append(id)
	advance()
	return true

func advance() -> void:
	offers.clear()
	stage += 1
	phase = Phase.MAP

class_name GameContent
extends RefCounted
## Loads Inspector-authored catalogs/campaigns; IDs remain stable for saved decks.

const DECK_SIZE: int = 20
const COPY_LIMIT: int = 5
const DEFAULT_CATALOG = preload("res://data/card_catalog.tres")
var catalog: CardCatalog
var campaign: CampaignDefinition
var card_ids: Array[String] = []
var cards: Dictionary = {}
var knight: ActorDefinition
var enemies: Dictionary = {}
var player_scene: PackedScene
var enemy_scenes: Dictionary = {}
var scene_ids: Dictionary = {}
var errors: Array[String] = []

func _init(card_catalog: CardCatalog = DEFAULT_CATALOG, route: CampaignDefinition = null) -> void:
	catalog = card_catalog
	# Load scenes after scripts compile: actor scripts also reference Combat/GameContent.
	campaign = route if route != null else load("res://data/campaigns/demo.tres")
	player_scene = load("res://scenes/actors/hero/knight.tscn")
	knight = snapshot(player_scene)
	if catalog == null or campaign == null:
		errors.append(I18n.t("Assign a card catalog and campaign in game.tscn."))
		return
	for definition in catalog.cards:
		if definition == null or definition.id.is_empty() or cards.has(definition.id):
			errors.append(I18n.t("Catalog cards need non-empty, unique IDs and no empty entries."))
			continue
		cards[definition.id] = definition
		card_ids.append(definition.id)
	for definition in catalog.starting_deck:
		if definition == null or cards.get(definition.id) != definition:
			errors.append(I18n.t("Every starting card must reference a card in the catalog."))
	if campaign.encounters.is_empty():
		errors.append(I18n.t("A campaign needs at least one encounter."))
	for battle in campaign.encounters:
		if battle == null or battle.enemies.is_empty():
			errors.append(I18n.t("Each encounter needs at least one enemy scene."))
			continue
		for scene in battle.enemies:
			_register_enemy(scene)
		for card in battle.reward_pool:
			if card == null or cards.get(card.id) != card:
				errors.append(I18n.t("Every reward card must reference a card in the catalog."))

func _register_enemy(scene: PackedScene) -> void:
	if scene == null:
		errors.append(I18n.t("Each encounter needs valid EnemyActor scenes."))
		return
	if scene_ids.has(scene):
		return
	var node := scene.instantiate()
	if not node is EnemyActor:
		errors.append(I18n.t("Each encounter needs valid EnemyActor scenes."))
		node.free()
		return
	var definition: ActorDefinition = node.build_definition()
	node.free()
	if definition.id.is_empty() or enemies.has(definition.id):
		errors.append(I18n.t("Different enemy scenes need non-empty, unique actor keys."))
		return
	scene_ids[scene] = definition.id
	enemy_scenes[definition.id] = scene
	enemies[definition.id] = definition

func configuration_error() -> String:
	return "\n".join(errors)

func encounter(index: int) -> EncounterDefinition:
	if campaign == null or index < 0 or index >= campaign.encounters.size():
		return null
	return campaign.encounters[index]

func encounter_enemies(index: int) -> Array:
	var result: Array = []
	var battle := encounter(index)
	if battle != null:
		for scene in battle.enemies:
			if scene_ids.has(scene):
				result.append(scene_ids[scene])
	return result

func is_library_card(id: String) -> bool:
	return cards.has(id) and cards[id].in_library and cards[id].hero_class in ["Shared", "Knight"]

func reward_cards(battle: EncounterDefinition) -> Array[String]:
	var result: Array[String] = []
	var pool: Array[CardDefinition] = catalog.cards if battle.reward_pool.is_empty() else battle.reward_pool
	for card in pool:
		if card != null and cards.get(card.id) == card and card.in_rewards and card.hero_class in ["Shared", "Knight"] and card.id not in result:
			result.append(card.id)
	return result

func snapshot(scene: PackedScene) -> ActorDefinition:
	# Headless model tests use the same scene-authored stats as live actors.
	var actor = scene.instantiate()
	var data: ActorDefinition = actor.build_definition()
	actor.free()
	return data

func default_deck() -> Array[String]:
	var result: Array[String] = []
	if catalog != null:
		for card in catalog.starting_deck:
			if card != null and cards.get(card.id) == card:
				result.append(card.id)
	return result

func deck_limit_error(deck: Array, starting: bool = true) -> String:
	if starting and deck.size() > DECK_SIZE:
		return I18n.t("DECK_FULL")
	var counts: Dictionary = {}
	for id in deck:
		if not cards.has(id):
			return I18n.t("This deck contains an unavailable card.")
		if starting and not is_library_card(id):
			return I18n.t("This deck contains an unavailable card.")
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] > COPY_LIMIT:
			return I18n.t("COPY_LIMIT", [cards[id].title, COPY_LIMIT])
	return ""

func validate_deck(deck: Array, starting: bool = true) -> String:
	var limit_error := deck_limit_error(deck, starting)
	if not limit_error.is_empty():
		return limit_error
	if (starting and deck.size() != DECK_SIZE) or deck.size() < 5:
		return I18n.t("A starting deck needs exactly 20 cards (%d / 20).") % deck.size()
	var ones: int = 0
	var low: int = 0
	for id in deck:
		if not cards.has(id):
			return I18n.t("This deck contains an unavailable card.")
		var card: CardDefinition = cards[id]
		if card.hero_class not in ["Shared", "Knight"]:
			return I18n.t("Only Shared cards and cards for your hero belong in this deck.")
		ones += int(card.cost == 1)
		low += int(card.cost <= 3)
	if ones < 1 or low < 2:
		return I18n.t("Include a cost-1 card and another card costing 3 or less.")
	return ""

class_name GameProfile
extends RefCounted
## Five independent named deck slots per hero, separate from live combat.
const SLOT_COUNT: int = 5
const KNIGHT: String = "H01"
var path: String = "user://profile.cfg"
var hero_decks: Dictionary = {}
var active_slots: Dictionary = {}
var deck: Array[String]:
	get: return get_deck(KNIGHT, active_slot(KNIGHT))
	set(value): hero_decks[KNIGHT][active_slot(KNIGHT)].cards = value.duplicate()
var music_volume: float = 0.35
var effects_volume: float = 0.65
var animation_speed: float = 1.0
var reduced_motion: bool = false
var fullscreen: bool = true
var language: String = "vi"
var warning: String = ""

func _init(content: GameContent, override_path: String = "") -> void:
	if not override_path.is_empty():
		path = override_path
	ensure_hero(KNIGHT, content.default_deck())
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return
	var version: int = int(config.get_value("profile", "version", 0))
	if error != OK or version not in [1, 2, 3]:
		warning = "Your preferences could not be read. Using the default deck and settings."
		return
	if version < 3:
		hero_decks[KNIGHT][0].cards = clean_deck(config.get_value("profile", "deck", content.default_deck()), content)
	else:
		var saved = config.get_value("profile", "hero_decks", {})
		if saved is Dictionary:
			for hero in saved:
				if not hero is String or not saved[hero] is Array:
					continue
				ensure_hero(hero)
				for slot in range(mini(SLOT_COUNT, saved[hero].size())):
					var entry = saved[hero][slot]
					if entry is Dictionary:
						hero_decks[hero][slot] = {
							"name": str(entry.get("name", "")).strip_edges().left(32),
							"cards": clean_deck(entry.get("cards", []), content)
						}
		var selected = config.get_value("profile", "active_slots", {})
		if selected is Dictionary:
			for hero in hero_decks:
				active_slots[hero] = clampi(int(selected.get(hero, 0)), 0, SLOT_COUNT - 1)
	music_volume = clampf(float(config.get_value("settings", "music", 0.35)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value("settings", "effects", 0.65)), 0.0, 1.0)
	animation_speed = clampf(float(config.get_value("settings", "speed", 1.0)), 0.5, 3.0)
	reduced_motion = bool(config.get_value("settings", "reduced_motion", false))
	fullscreen = bool(config.get_value("settings", "fullscreen", true)) if version >= 2 else true
	language = str(config.get_value("settings", "language", "vi"))
	if language not in ["vi", "en"]:
		language = "vi"

func ensure_hero(hero: String, starter: Array[String] = []) -> void:
	if hero_decks.has(hero):
		return
	hero_decks[hero] = []
	for slot in range(SLOT_COUNT):
		hero_decks[hero].append({"name": "", "cards": starter.duplicate() if slot == 0 else []})
	active_slots[hero] = 0

func active_slot(hero: String) -> int:
	return int(active_slots.get(hero, 0))

func get_deck(hero: String, slot: int) -> Array[String]:
	var result: Array[String] = []
	result.assign(hero_decks[hero][slot].cards)
	return result

func deck_name(hero: String, slot: int) -> String:
	var custom_name: String = hero_decks[hero][slot].name
	return custom_name if not custom_name.is_empty() else I18n.t("DECK_SLOT", [slot + 1])

func store_deck(hero: String, slot: int, title: String, cards: Array[String], content: GameContent) -> Error:
	if slot < 0 or slot >= SLOT_COUNT or not content.deck_limit_error(cards).is_empty():
		return ERR_INVALID_DATA
	ensure_hero(hero)
	hero_decks[hero][slot] = {"name": title.strip_edges().left(32), "cards": cards.duplicate()}
	active_slots[hero] = slot
	return save()

func clean_deck(value: Variant, content: GameContent) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		warning = "DECK_MIGRATED"
		return content.default_deck()
	for id in value:
		if id is String and content.is_library_card(id) and result.size() < GameContent.DECK_SIZE and result.count(id) < GameContent.COPY_LIMIT:
			result.append(id)
		else:
			warning = "DECK_MIGRATED"
	return result

func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("profile", "version", 3)
	config.set_value("profile", "hero_decks", hero_decks)
	config.set_value("profile", "active_slots", active_slots)
	config.set_value("settings", "music", music_volume)
	config.set_value("settings", "effects", effects_volume)
	config.set_value("settings", "speed", animation_speed)
	config.set_value("settings", "reduced_motion", reduced_motion)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "language", language)
	var error := config.save(path + ".tmp")
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)

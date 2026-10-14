extends Control
## Entry point: routing/preferences. Screens and actors are authored PackedScenes.
const MENU = preload("res://scenes/screens/menu.tscn")
const DECK = preload("res://scenes/screens/deck_editor.tscn")
const SELECT = preload("res://scenes/screens/character_select.tscn")
const FIGHT = preload("res://scenes/screens/combat.tscn")
const SETTINGS = preload("res://scenes/screens/settings.tscn")
const TEXT_PANEL = preload("res://scenes/screens/text_panel.tscn")
const BATTLE_POPUP = preload("res://scenes/screens/battle_popup.tscn")
const DEMO_MAP = preload("res://scenes/screens/demo_map.tscn")
const CARD_REWARD = preload("res://scenes/screens/card_reward.tscn")
const DEMO_END = preload("res://scenes/screens/demo_end.tscn")
@export_group("Content")
@export var card_catalog: CardCatalog = preload("res://data/card_catalog.tres")
@export var campaign: CampaignDefinition = preload("res://data/campaigns/demo.tres")
var demo_run: DemoRun
var content: GameContent
var profile: GameProfile
var screen: Control
var modal: Control
var preset_choice: int = 0
var encounter_choice: int = 0
var selected_deck: Array[String] = []
var selected_seed: int = 0
@onready var background: ForestBackdrop = %Background
@onready var audio: GameAudio = %Audio
@onready var screen_host: Control = %Screens
@onready var popup_host: Control = %Popups
@onready var inspector: CardInspector = %CardInspector

func _ready() -> void:
	inspector.closed.connect(close_modal)
	content = GameContent.new(card_catalog, campaign)
	profile = GameProfile.new(content)
	audio.setup(profile)
	TranslationServer.set_locale(profile.language)
	apply_settings()
	show_menu()

func change_screen(scene: PackedScene) -> void:
	close_modal()
	if is_instance_valid(screen):
		screen_host.remove_child(screen)
		screen.queue_free()
	screen = scene.instantiate()
	screen_host.add_child(screen)
	screen.setup(self)

func show_menu() -> void:
	demo_run = null
	change_screen(MENU)
	if not profile.warning.is_empty():
		show_text("SETTINGS", profile.warning)
		profile.warning = ""

func show_deck() -> void:
	change_screen(DECK)

func show_setup() -> void:
	demo_run = null
	change_screen(SELECT)

func start_combat() -> void:
	demo_run = null
	change_screen(FIGHT)

func start_demo() -> void:
	if not content.configuration_error().is_empty():
		show_text("DECK", content.configuration_error(), true)
		return
	if not content.validate_deck(selected_deck).is_empty():
		return
	demo_run = DemoRun.new(selected_deck, content.knight, selected_seed, content.campaign)
	change_screen(DEMO_MAP)

func start_demo_battle(index: int) -> void:
	if demo_run == null or not demo_run.enter_battle(index):
		return
	encounter_choice = index
	selected_deck = demo_run.deck.duplicate()
	selected_seed = demo_run.seed_value + index * 7919
	change_screen(FIGHT)

func finish_demo_battle(combat: Combat) -> void:
	if demo_run == null or not demo_run.finish_battle(combat, content):
		return
	match demo_run.phase:
		DemoRun.Phase.REWARD: change_screen(CARD_REWARD)
		DemoRun.Phase.MAP: change_screen(DEMO_MAP)
		_: change_screen(DEMO_END)

func choose_demo_reward(id: String) -> void:
	if demo_run != null and demo_run.choose_reward(id):
		change_screen(DEMO_MAP)

func replay_demo() -> void:
	if demo_run == null:
		return
	selected_deck = demo_run.starting_deck.duplicate()
	selected_seed = int(Time.get_unix_time_from_system() * 1000) % 2147483647
	start_demo()

func show_popup(scene: PackedScene) -> Control:
	close_modal()
	modal = scene.instantiate()
	popup_host.add_child(modal)
	modal.closed.connect(close_modal)
	get_tree().paused = true
	return modal

func close_modal() -> void:
	if is_instance_valid(modal):
		if modal == inspector:
			inspector.hide()
			inspector.clear_inspection()
		else:
			popup_host.remove_child(modal)
			modal.queue_free()
	modal = null
	get_tree().paused = false
	if is_instance_valid(screen) and screen.has_method("apply_preferences"):
		screen.apply_preferences()

func show_settings() -> void:
	var panel = show_popup(SETTINGS)
	panel.setup(self)

func show_text(title: String, body: String, translated_body: bool = false) -> void:
	var panel = show_popup(TEXT_PANEL)
	panel.configure(title, body, translated_body)

func show_credits() -> void:
	show_text("CREDITS", "CREDITS_BODY")

func show_battle_popup(combat: Combat, result: bool = false) -> void:
	var panel = show_popup(BATTLE_POPUP)
	panel.setup(self, combat, result)

func show_card_inspector(data: Resource, art: Texture2D = null, actor: ActorState = null, model: Combat = null) -> void:
	if is_instance_valid(modal) or get_viewport().gui_is_dragging():
		return
	if data is EnemySkill and (data.hidden or actor == null or model == null):
		return
	if data is ActorDefinition and (actor == null or model == null):
		return
	if not data is EnemySkill and not data is CardDefinition and not data is ActorDefinition:
		return
	modal = inspector
	inspector.reduced_motion = profile.reduced_motion
	inspector.animation_speed = profile.animation_speed
	inspector.configure(data, art, actor, model)
	inspector.show()
	get_tree().paused = true

func set_language(locale: String) -> void:
	profile.language = locale
	TranslationServer.set_locale(locale)
	DisplayServer.window_set_title(I18n.t("GAME_WINDOW_TITLE"))
	screen.refresh_text()
	if is_instance_valid(modal) and modal.has_method("refresh_text"):
		modal.refresh_text()

func apply_settings() -> void:
	background.reduced_motion = profile.reduced_motion
	audio.apply_settings()
	DisplayServer.window_set_title(I18n.t("GAME_WINDOW_TITLE"))
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if profile.fullscreen:
		window.size = DisplayServer.screen_get_size(window.current_screen)
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		var available := DisplayServer.screen_get_usable_rect(window.current_screen).size
		window.size = Vector2i(mini(1600, available.x), mini(900, available.y))
		window.move_to_center()

func _input(event: InputEvent) -> void:
	var cancel_drag: bool = event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)
	if cancel_drag and get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
		if screen is CombatScreen:
			screen.cancel_selection()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal):
			close_modal()
		elif screen is CombatScreen:
			if screen.selected_id != 0:
				screen.cancel_selection()
			else:
				screen.show_pause()
		elif screen is DeckScreen:
			screen.request_back()
		else:
			show_menu()
		get_viewport().set_input_as_handled()

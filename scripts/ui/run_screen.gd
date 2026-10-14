class_name RunScreen
extends GameScreen

func _ready() -> void:
	%Menu.pressed.connect(func(): app.show_menu())
	%Settings.pressed.connect(func(): app.show_settings())

func refresh_text() -> void:
	if app == null or app.demo_run == null:
		return
	%Health.text = I18n.t("RUN_HEALTH", [app.demo_run.hp, app.demo_run.max_hp])
	%DeckCount.text = I18n.t("RUN_DECK_COUNT", [app.demo_run.deck.size()])

extends GameScreen

func _ready() -> void:
	%Back.pressed.connect(func(): app.show_menu())
	%EditDeck.pressed.connect(func(): app.show_deck())
	%Start.pressed.connect(start_battle)
	%DeckChoice.item_selected.connect(func(index): app.preset_choice = index; validate())

func refresh_text() -> void:
	if app == null:
		return
	%DeckChoice.clear()
	%DeckChoice.add_item(I18n.t("STARTER_DECK"))
	for slot in range(GameProfile.SLOT_COUNT):
		%DeckChoice.add_item("%s · %d/20" % [app.profile.deck_name(GameProfile.KNIGHT, slot), app.profile.get_deck(GameProfile.KNIGHT, slot).size()])
	%DeckChoice.select(app.preset_choice)
	var names: Array[String] = []
	if app.content.campaign != null:
		%RouteHeading.text = I18n.t(app.content.campaign.title)
		for battle in app.content.campaign.encounters:
			if battle != null:
				names.append(I18n.t(battle.title))
	%Route.text = " → ".join(names)
	validate()
	apply_preferences()

func apply_preferences() -> void:
	var sprite: AnimatedSprite2D = $Margin/Layout/Body/Hero/Portrait/AnimatedSprite2D
	if app.profile.reduced_motion:
		sprite.pause()
	else:
		sprite.play("idle")

func validate() -> void:
	var deck: Array = app.content.default_deck() if app.preset_choice == 0 else app.profile.get_deck(GameProfile.KNIGHT, app.preset_choice - 1)
	%Validation.text = app.content.configuration_error()
	if %Validation.text.is_empty():
		%Validation.text = app.content.validate_deck(deck)
	%Start.disabled = not %Validation.text.is_empty()

func start_battle() -> void:
	app.selected_deck = app.content.default_deck() if app.preset_choice == 0 else app.profile.get_deck(GameProfile.KNIGHT, app.preset_choice - 1)
	app.selected_seed = int(Time.get_unix_time_from_system() * 1000) % 2147483647
	app.start_demo()

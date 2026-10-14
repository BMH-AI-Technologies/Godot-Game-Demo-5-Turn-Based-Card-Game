extends GamePopup
var app
var combat: Combat
var showing_result: bool = false

func _ready() -> void:
	super._ready()
	%Resume.pressed.connect(func(): closed.emit())
	%Settings.pressed.connect(func(): app.show_settings())
	%Retry.pressed.connect(func(): app.start_combat())
	%NewBattle.pressed.connect(func(): app.show_setup())
	%Menu.pressed.connect(func(): app.show_menu())

func setup(game, model: Combat, result: bool) -> void:
	app = game
	combat = model
	showing_result = result
	%Resume.visible = not result
	%Settings.visible = not result
	for control in [%Close, %Outcome, %Stats, %Body, %Retry, %NewBattle]:
		control.visible = result
	%Panel.custom_minimum_size = Vector2(1040, 800) if result else Vector2(520, 360)
	%Heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if result else HORIZONTAL_ALIGNMENT_CENTER
	refresh_text()

func refresh_text() -> void:
	if showing_result:
		var won := combat.phase == Combat.Phase.WON
		%Heading.text = I18n.t("WON_TITLE" if won else "LOST_TITLE")
		%Outcome.text = I18n.t("VICTORY" if won else "DEFEAT")
		%Stats.text = I18n.t("RESULT_STATS", [combat.round_number, combat.player.hp, combat.player.definition.max_hp])
		%Body.text = I18n.t("WON_BODY" if won else "LOST_BODY")
	else:
		%Heading.text = I18n.t("PAUSED")
		%Stats.text = ""
		%Body.text = ""

class_name CardRewardScreen
extends RunScreen
const REWARD_CARD = preload("res://scenes/components/reward_card.tscn")
var choices: Array[CardView] = []
var selected: String = ""

func _ready() -> void:
	super._ready()
	%Confirm.pressed.connect(func(): app.choose_demo_reward(selected))

func setup(game) -> void:
	app = game
	for index in range(app.demo_run.offers.size()):
		var id: String = app.demo_run.offers[index]
		var card: CardView = REWARD_CARD.instantiate()
		%Cards.add_child(card)
		choices.append(card)
		card.setup(app.content.cards[id], index)
		card.drag_enabled = false
		card.chosen.connect(func(_instance): choose(id))
		card.inspection_requested.connect(func(data, art): app.show_card_inspector(data, art))
	refresh_text()

func choose(id: String) -> void:
	selected = id
	%Confirm.disabled = false
	for card in choices:
		card.selected = card.definition.id == id
		card.update_frame()

func refresh_text() -> void:
	super.refresh_text()
	if app == null:
		return
	%Recovery.text = I18n.t("RUN_HEALED", [app.demo_run.healed])
	for card in choices:
		card.reduced_motion = app.profile.reduced_motion
		card.refresh_text()

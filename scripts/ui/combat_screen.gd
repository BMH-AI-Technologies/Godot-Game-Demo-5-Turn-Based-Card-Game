class_name CombatScreen
extends GameScreen
## Owns battle input. Authored actor/card scenes own visuals; Combat owns rules.

## Show the enemies before opening-card selection, scaled by animation speed.
@export_range(0.1, 5.0, 0.05) var enemy_reveal_duration: float = 1.25
## Hold the completed battle before rewards/results, in seconds.
@export_range(0.0, 5.0, 0.05) var victory_delay: float = 1.0

var combat := Combat.new()
var actors: Dictionary = {}
var selected_id: int = 0
var target_id: int = 1
var replacements: Array = []
var busy: bool = false
var auto_end_pending: bool = false
var result_shown: bool = false
var revealing_enemies: bool = true
@onready var hand_root: HandView = %OpeningHand
@onready var presenter: CombatPresenter = %Presenter
var cards: Dictionary:
	get: return hand_root.cards

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	%EndTurn.pressed.connect(submit_end)
	%PlayCard.pressed.connect(submit_selected)
	%Pause.pressed.connect(show_pause)
	%ConfirmOpening.pressed.connect(submit_end)
	%OpeningPause.pressed.connect(show_pause)
	%CardDropSurface.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
	for hand in [%Hand, %OpeningHand]:
		hand.chosen.connect(select_card)
		hand.dragged.connect(select_card)
		hand.inspection_requested.connect(inspect_card)
		hand.card_dealt.connect(func(_id): app.audio.play("draw"))
	presenter.announced.connect(func(text): %Message.text = text)
	presenter.enemy_phase.connect(func(): %Round.text = I18n.t("ENEMY_TURN"))

func setup(game) -> void:
	app = game
	presenter.audio = app.audio
	var foes: Array[ActorDefinition] = []
	actors[0] = %Player
	var enemy_ids: Array = app.content.encounter_enemies(app.encounter_choice)
	for i in range(enemy_ids.size()):
		var scene: PackedScene = app.content.enemy_scenes[enemy_ids[i]]
		var enemy: EnemyActor = scene.instantiate()
		%EnemyRow.add_child(enemy)
		actors[i + 1] = enemy
		foes.append(enemy.build_definition())
	var error := combat.setup(app.content, app.selected_deck, app.encounter_choice, app.selected_seed, %Player.build_definition(), foes, app.demo_run != null)
	if not error.is_empty():
		app.show_text("DECK", error, true)
		return
	if app.demo_run != null:
		combat.player.hp = app.demo_run.hp
	for id in actors:
		var actor: BattleActor = actors[id]
		actor.bind_actor(combat.actor(id), combat, app.profile.reduced_motion)
		actor.targeted.connect(choose_target)
		actor.card_dropped.connect(drop_card)
		actor.inspection_requested.connect(inspect_enemy_skill)
		actor.actor_inspection_requested.connect(inspect_enemy)
	combat.action_ended.connect(_on_action_ended)
	busy = true
	refresh()
	# A node-bound tween pauses with combat and stops if the screen is freed.
	var reveal := create_tween()
	reveal.tween_interval(enemy_reveal_duration / app.profile.animation_speed)
	await reveal.finished
	revealing_enemies = false
	refresh()
	await hand_root.deal(app.profile, %DrawDeck, hand_root.order.duplicate(), hand_root.deal_start_delay)
	busy = false
	refresh()

func refresh_text() -> void:
	if app != null and combat.player != null:
		refresh()

func refresh() -> void:
	var opening: bool = combat.phase == Combat.Phase.OPENING
	var show_opening: bool = opening and not revealing_enemies
	%OpeningLayer.visible = show_opening
	%Pause.visible = not show_opening
	%Pause.disabled = busy and combat.phase in [Combat.Phase.WON, Combat.Phase.LOST]
	if not opening and hand_root == %OpeningHand:
		%OpeningHand.clear_cards()
		hand_root = %Hand
	%ConfirmOpening.disabled = busy
	%OpeningCount.text = I18n.t("OPENING_KEEP_COUNT", [combat.hand.size() - replacements.size(), replacements.size()])
	%Encounter.text = I18n.t(app.content.encounter(app.encounter_choice).title)
	%Round.text = I18n.t("ROUND", [combat.round_number, "OPENING" if combat.phase == Combat.Phase.OPENING else "PLAYER_TURN"])
	%Mana.set_mana(combat.mana)
	%Reserve.set_mana(combat.reserve, 3)
	for actor in actors.values():
		actor.refresh()
	if combat.actor(target_id) == null or combat.actor(target_id).hp <= 0:
		for enemy in combat.enemies:
			if enemy.hp > 0:
				target_id = enemy.id
				break
	if not revealing_enemies:
		hand_root.render(combat, selected_id, replacements, busy, app.profile)
	%EndTurn.disabled = busy or combat.phase not in [Combat.Phase.OPENING, Combat.Phase.PLAYER]
	%EndTurn.text = I18n.t("END_TURN")
	if opening:
		%ConfirmOpening.text = I18n.t("CONFIRM_KEEP", [combat.hand.size() - replacements.size()])
	%PlayCard.visible = combat.phase == Combat.Phase.PLAYER
	%PlayCard.disabled = selected_id == 0 or busy
	if combat.phase in [Combat.Phase.WON, Combat.Phase.LOST]:
		%Round.text = I18n.t("VICTORY" if combat.phase == Combat.Phase.WON else "DEFEAT")

func apply_preferences() -> void:
	if app == null:
		return
	for actor in actors.values():
		actor.set_reduced_motion(app.profile.reduced_motion)
	for view in cards.values():
		view.reduced_motion = app.profile.reduced_motion
	resume_actions()

func select_card(id: int) -> void:
	if busy or is_instance_valid(app.modal):
		return
	app.audio.play("click")
	if combat.phase == Combat.Phase.OPENING:
		if replacements.has(id):
			replacements.erase(id)
		else:
			replacements.append(id)
		refresh.call_deferred()
		return
	if combat.phase != Combat.Phase.PLAYER:
		return
	selected_id = id
	for key in cards:
		cards[key].selected = key == id
		cards[key].update_frame()
	%PlayCard.disabled = false

func inspect_card(data: CardDefinition, art: Texture2D) -> void:
	if not busy:
		app.show_card_inspector(data, art)

func inspect_enemy_skill(skill: EnemySkill, actor_id: int) -> void:
	if not busy:
		app.show_card_inspector(skill, null, combat.actor(actor_id), combat)

func inspect_enemy(actor_id: int) -> void:
	if busy:
		return
	var actor_view: EnemyActor = actors[actor_id]
	app.show_card_inspector(actor_view.state.definition, actor_view.artwork, actor_view.state, combat)

func choose_target(id: int) -> void:
	if busy:
		return
	if id > 0:
		target_id = id
	if selected_id != 0:
		drop_card(selected_id, id)

func submit_selected() -> void:
	var card := combat.find_card(selected_id)
	if card != null:
		submit(selected_id, target_id if card.definition.target == "enemy" else 0)

func drop_card(id: int, actor_id: int) -> void:
	var card := combat.find_card(id)
	if card != null:
		submit(id, actor_id if card.definition.target == "enemy" else 0)

func submit(id: int, actor_id: int) -> void:
	if busy or is_instance_valid(app.modal):
		return
	var error := combat.play_card(id, actor_id, combat.revision)
	if not error.is_empty():
		notify(error)

func submit_end() -> void:
	if busy or is_instance_valid(app.modal):
		return
	var error: String
	if combat.phase == Combat.Phase.OPENING:
		error = combat.mulligan(replacements)
		replacements.clear()
	else:
		error = combat.end_turn()
	if not error.is_empty():
		notify(error)

func _on_action_ended(action: String) -> void:
	busy = true
	selected_id = 0
	if action == "mulligan":
		# Keep selected cards in hand; only the replacement events are dealt again.
		refresh()
	%EndTurn.disabled = true
	%ConfirmOpening.disabled = true
	%PlayCard.disabled = true
	for view in cards.values():
		view.drag_enabled = false
		view.show_playability = false
		view.update_frame()
	await presenter.play(combat.events.duplicate(true), actors, hand_root, combat, app.profile, %DrawDeck)
	%Message.text = ""
	if combat.phase in [Combat.Phase.WON, Combat.Phase.LOST]:
		show_result()
		return
	busy = false
	refresh()
	# Once per completed action, including opening and enemy-phase completion.
	# Deferring avoids recursive turns and gives pause/input an event boundary.
	auto_end_pending = combat.phase == Combat.Phase.PLAYER and not combat.has_playable_card()
	resume_actions()

func resume_actions() -> void:
	if auto_end_pending and not busy and not is_instance_valid(app.modal):
		_auto_end_turn.call_deferred(combat.revision)

func _auto_end_turn(expected_revision: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or busy or is_instance_valid(app.modal) or not auto_end_pending:
		return
	if combat.revision != expected_revision:
		return
	auto_end_pending = false
	if combat.phase == Combat.Phase.PLAYER and not combat.has_playable_card():
		combat.end_turn()

func cancel_selection() -> void:
	selected_id = 0
	for view in cards.values():
		view.selected = false
		view.update_frame()
	%PlayCard.disabled = true
	%Message.text = ""

func notify(message: String) -> void:
	%Message.text = message
	app.audio.play("error")

func show_result() -> void:
	if result_shown:
		return
	result_shown = true
	busy = true
	refresh()
	app.audio.play("win" if combat.phase == Combat.Phase.WON else "loss")
	if combat.phase == Combat.Phase.WON:
		var hold := create_tween()
		hold.tween_interval(victory_delay)
		await hold.finished
	busy = false
	refresh()
	if app.demo_run != null:
		app.finish_demo_battle(combat)
		return
	app.show_battle_popup(combat, true)

func show_pause() -> void:
	if busy and combat.phase in [Combat.Phase.WON, Combat.Phase.LOST]:
		return
	app.show_battle_popup(combat, combat.phase in [Combat.Phase.WON, Combat.Phase.LOST])

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if busy or app == null or is_instance_valid(app.modal) or combat.phase != Combat.Phase.PLAYER or not data is Dictionary or not data.has("card"):
		return false
	# The entire bottom hand band is a cancel zone, including gaps and the deck.
	# Returning here cancels even if the card previously left the hand.
	if not Rect2(Vector2.ZERO, size).has_point(at) or global_position.y + at.y >= %Hand.global_position.y:
		return false
	var card := combat.find_card(int(data.card))
	if not combat.card_error(card).is_empty():
		return false
	return card.definition.target != "enemy" or enemy_at(at) > 0

func _drop_data(at: Vector2, data: Variant) -> void:
	if _can_drop_data(at, data):
		drop_card(int(data.card), enemy_at(at))

func enemy_at(at: Vector2) -> int:
	for enemy in combat.enemies:
		if enemy.hp > 0 and actors[enemy.id].get_global_rect().has_point(global_position + at):
			return enemy.id
	return 0

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		# A temporary full-screen surface catches drops even over HUD buttons/cards.
		%CardDropSurface.visible = not busy and combat.phase == Combat.Phase.PLAYER and data is Dictionary and data.has("card")
	elif what == NOTIFICATION_DRAG_END:
		if %CardDropSurface.visible and not get_viewport().gui_is_drag_successful():
			cancel_selection()
		%CardDropSurface.hide()

func _input(event: InputEvent) -> void:
	if app == null or is_instance_valid(app.modal):
		return
	var play_pressed := event.is_action_pressed("play_card")
	var end_pressed := event.is_action_pressed("end_turn")
	if busy or get_viewport().gui_is_dragging():
		if play_pressed or end_pressed:
			get_viewport().set_input_as_handled()
		return
	if end_pressed:
		submit_end()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		if combat.hand.is_empty():
			return
		var current: int = -1
		for i in range(combat.hand.size()):
			if combat.hand[i].id == selected_id:
				current = i
		var move_right := event.is_action_pressed("ui_right")
		var index: int = posmod(current + (1 if move_right else -1), combat.hand.size())
		if current < 0:
			index = 0 if move_right else combat.hand.size() - 1
		if combat.phase == Combat.Phase.OPENING:
			selected_id = combat.hand[index].id
			cards[selected_id].grab_focus()
		else:
			select_card(combat.hand[index].id)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var live: Array[int] = []
		for enemy in combat.enemies:
			if enemy.hp > 0:
				live.append(enemy.id)
		if not live.is_empty():
			target_id = live[posmod(live.find(target_id) + 1, live.size())]
			actors[target_id].target_button.grab_focus()
	elif play_pressed and combat.phase == Combat.Phase.PLAYER:
		# Consume this action even with no selection so focused buttons cannot fire.
		submit_selected()
	else:
		return
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Card/intent GUI gets right-click first; empty battlefield still cancels.
	if app != null and not is_instance_valid(app.modal) and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_selection()
		get_viewport().set_input_as_handled()

class_name DeckScreen
extends GameScreen
const CARD = preload("res://scenes/components/deck_card.tscn")
const STACK = preload("res://scenes/components/deck_stack.tscn")
const TYPES: Array[String] = ["ALL_TYPES", "Attack", "Skill"]
const COSTS: Array[int] = [-1, 0, 1, 2, 3, 5]
const HERO: String = GameProfile.KNIGHT
var draft: Array[String] = []
var slot: int = 0
var feedback_key: String = ""
var feedback_args: Array = []
var library_cards: Dictionary = {}
var stacks: Dictionary = {}

func _ready() -> void:
	%TypeFilter.item_selected.connect(func(_index): refresh())
	%CostFilter.item_selected.connect(func(_index): refresh())
	%SlotChoice.item_selected.connect(select_slot)
	%DeckName.text_changed.connect(func(_value): feedback_key = "UNSAVED"; show_feedback())
	%DeckName.text_submitted.connect(func(_value): save_deck())
	%Save.pressed.connect(save_deck)
	%Back.pressed.connect(request_back)
	%Reset.pressed.connect(func(): draft = app.content.default_deck(); mark_changed())
	%Clear.pressed.connect(func(): draft.clear(); mark_changed())
	%LibraryPanel.accepts = func(id): return draft.has(id)
	%DeckPanel.accepts = can_add
	%LibraryPanel.card_dropped.connect(func(id): change_count(id, -1))
	%DeckPanel.card_dropped.connect(func(id): change_count(id, 1))
	for node in [%LibraryScroll, %LibraryGrid]:
		%LibraryPanel.forward_from(node)
	for node in [%DeckScroll, %DeckGrid, %EmptyDeck]:
		%DeckPanel.forward_from(node)
	%LibraryScroll.resized.connect(arrange_columns)
	%DeckScroll.resized.connect(arrange_columns)

func setup(game) -> void:
	app = game
	slot = app.profile.active_slot(HERO)
	load_slot()
	refresh_text()

func load_slot() -> void:
	draft = app.profile.get_deck(HERO, slot)
	%DeckName.text = app.profile.hero_decks[HERO][slot].name
	feedback_key = ""
	feedback_args = []

func refresh_text() -> void:
	var selected_type: int = maxi(0, %TypeFilter.selected)
	var selected_cost: int = maxi(0, %CostFilter.selected)
	%TypeFilter.clear()
	for key in TYPES:
		%TypeFilter.add_item(I18n.t(key))
	%TypeFilter.select(selected_type)
	%CostFilter.clear()
	for cost in COSTS:
		%CostFilter.add_item(I18n.t("ALL_COSTS") if cost < 0 else str(cost))
	%CostFilter.select(selected_cost)
	update_slots()
	refresh()

func update_slots() -> void:
	%SlotChoice.clear()
	for index in range(GameProfile.SLOT_COUNT):
		%SlotChoice.add_item("%02d  ·  %s" % [index + 1, app.profile.deck_name(HERO, index)])
	%SlotChoice.select(slot)
	%DeckName.placeholder_text = I18n.t("DECK_SLOT", [slot + 1])

func select_slot(index: int) -> void:
	if index == slot:
		return
	if not save_deck():
		%SlotChoice.select(slot)
		return
	slot = index
	app.profile.active_slots[HERO] = slot
	load_slot()
	update_slots()
	refresh()

func clear_grid(grid: Control) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

func refresh() -> void:
	clear_grid(%LibraryGrid)
	clear_grid(%DeckGrid)
	library_cards.clear()
	stacks.clear()
	for id in app.content.card_ids:
		var data: CardDefinition = app.content.cards[id]
		var copies: int = draft.count(id)
		if app.content.is_library_card(id) and (%TypeFilter.selected == 0 or data.kind == TYPES[%TypeFilter.selected]) and (%CostFilter.selected == 0 or data.cost == COSTS[%CostFilter.selected]):
			var card: DeckCard = CARD.instantiate()
			%LibraryGrid.add_child(card)
			card.configure(data, copies, "library", can_add(id), app.profile.reduced_motion)
			card.count_changed.connect(change_count)
			card.inspection_requested.connect(app.show_card_inspector)
			%LibraryPanel.forward_from(card)
			%LibraryPanel.forward_from(card.get_node("%Action"))
			library_cards[id] = card
		if copies > 0:
			var stack = STACK.instantiate()
			%DeckGrid.add_child(stack)
			stack.configure(data, copies, app.profile.reduced_motion)
			stack.count_changed.connect(change_count)
			stack.card.inspection_requested.connect(app.show_card_inspector)
			%DeckPanel.forward_from(stack)
			%DeckPanel.forward_from(stack.card)
			%DeckPanel.forward_from(stack.card.get_node("%Action"))
			stacks[id] = stack
	%DeckCount.text = "%d / %d" % [draft.size(), GameContent.DECK_SIZE]
	%EmptyDeck.visible = draft.is_empty()
	%Validation.text = app.content.validate_deck(draft)
	if %Validation.text.is_empty():
		%Validation.text = I18n.t("DECK_READY")
	show_feedback()
	arrange_columns.call_deferred()

func arrange_columns() -> void:
	for grid: GridContainer in [%LibraryGrid, %DeckGrid]:
		var padding: MarginContainer = grid.get_parent()
		var scroll: ScrollContainer = padding.get_parent()
		# Reserve scrollbar space so filtering cannot make columns jump back and forth.
		var available := scroll.size.x - scroll.get_v_scroll_bar().get_combined_minimum_size().x
		available -= padding.get_theme_constant("margin_left") + padding.get_theme_constant("margin_right")
		var gap := grid.get_theme_constant("h_separation")
		var card_width: float = 208.0 if grid == %LibraryGrid else 224.0
		grid.columns = clampi(int((available + gap) / (card_width + gap)), 1, 4 if grid == %LibraryGrid else 3)

func can_add(id: String) -> bool:
	return app != null and app.content.is_library_card(id) and draft.size() < GameContent.DECK_SIZE and draft.count(id) < GameContent.COPY_LIMIT

func change_count(id: String, delta: int) -> void:
	if delta > 0:
		if not can_add(id):
			feedback_key = "DECK_FULL" if draft.size() >= GameContent.DECK_SIZE else "COPY_LIMIT"
			feedback_args = [] if draft.size() >= GameContent.DECK_SIZE else [app.content.cards[id].title, GameContent.COPY_LIMIT]
			show_feedback()
			return
		draft.append(id)
	elif draft.has(id):
		draft.erase(id)
	else:
		return
	app.audio.play("click")
	mark_changed()

func mark_changed() -> void:
	feedback_key = "UNSAVED"
	feedback_args = []
	# Do not destroy a drag source inside Godot's drop callback.
	refresh.call_deferred()

func show_feedback() -> void:
	%Feedback.text = I18n.t(feedback_key, feedback_args)

func save_deck() -> bool:
	var error: Error = app.profile.store_deck(HERO, slot, %DeckName.text, draft, app.content)
	feedback_key = "SAVED" if error == OK else "SAVE_FAILED"
	feedback_args = [] if error == OK else [error]
	if error == OK:
		app.preset_choice = slot + 1
		update_slots()
	show_feedback()
	return error == OK

func request_back() -> void:
	if save_deck():
		app.show_menu()

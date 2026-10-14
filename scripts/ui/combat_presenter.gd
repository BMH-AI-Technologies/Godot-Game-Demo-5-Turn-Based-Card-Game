class_name CombatPresenter
extends Node
## Translates model events into scene animations. Never changes combat state.
signal announced(text: String)
signal enemy_phase
@export var action_duration: float = 0.32
@export var impact_duration: float = 0.22
@export var floating_scene: PackedScene = preload("res://scenes/effects/floating_text.tscn")
var audio: GameAudio

func play(events: Array[Dictionary], actors: Dictionary, hand: HandView, model: Combat, settings: GameProfile, draw_source: Control) -> void:
	var speed: float = settings.animation_speed
	var pending_draws: Array[int] = []
	for event in events:
		if event.kind in ["draw", "created"]:
			pending_draws.append(event.card)
	var event_index: int = 0
	while event_index < events.size():
		var event := events[event_index]
		event_index += 1
		match event.kind:
			"card", "action":
				announced.emit(I18n.t(event.title))
				if event.kind == "card" and event.type == "Attack":
					# One swing cue per card, rather than overlapping it for every AoE target.
					audio.play("slash")
				if event.kind == "card" and hand.cards.has(event.card):
					var view: CardView = hand.cards[event.card]
					var depart := create_tween().set_parallel()
					if not settings.reduced_motion:
						depart.tween_property(view, "position:y", -150.0, action_duration / speed)
					depart.tween_property(view, "modulate:a", 0.0, action_duration / speed)
				if event.kind == "action":
					enemy_phase.emit()
				var actor: BattleActor = actors.get(event.source)
				if actor != null:
					var cue := "attack" if event.type in ["Attack", "Special", "Ultimate"] else "cast"
					if not str(event.get("animation", "")).is_empty():
						cue = str(event.animation)
					var impacts: int = 0
					for index in range(event_index, events.size()):
						if events[index].kind != "damage":
							break
						impacts += 1
					actor.act(1.0 if event.source == 0 else -1.0, (action_duration + impact_duration * impacts) / speed, cue)
				await wait(action_duration / speed)
			"damage":
				var view: BattleActor = actors.get(event.target)
				if view != null:
					view.bar.value = event.hp
					view.health_label.text = I18n.t("HP_VALUE", [event.hp, model.actor(event.target).definition.max_hp])
					view.status_label.text = I18n.t("BLOCK_VALUE", [event.block])
					view.flash(Color("#f5a08a"), impact_duration / speed)
					floating(view, I18n.t("HP_LOSS", [event.loss]) if event.loss > 0 else I18n.t("BLOCKED"), GameUI.RED if event.loss > 0 else GameUI.TEAL, settings)
				audio.play("hit" if event.loss > 0 else "block")
				await wait(impact_duration / speed)
			"block", "heal", "mana", "status", "interrupted":
				var key: String = event.get("text", {"block": "BLOCK_GAIN", "heal": "HEAL_GAIN", "mana": "MANA_GAIN"}.get(event.kind, "INTERRUPTED"))
				var args: Array = event.get("args", [event.amount] if event.has("amount") else [])
				var target: BattleActor = actors.get(event.target)
				if target != null:
					floating(target, I18n.t(key, args), GameUI.TEAL, settings)
				var sound: String = {"block": "block", "heal": "heal", "mana": "mana", "interrupted": "interrupt"}.get(event.kind, "debuff" if key == "WEAK_GAIN" else "buff")
				audio.play(sound)
				await wait(0.18 / speed)
			"death":
				var view: BattleActor = actors.get(event.target)
				if view != null:
					view.die(0.45 / speed)
				await wait(0.45 / speed)
			"draw", "created":
				# Consecutive draws share one staggered deal, including cards created
				# by effects. Hide later arrivals until their event is presented.
				var incoming: Array[int] = [int(event.card)]
				while event_index < events.size() and events[event_index].kind in ["draw", "created"]:
					incoming.append(events[event_index].card)
					event_index += 1
				hand.render(model, 0, [], true, settings, pending_draws)
				await hand.deal(settings, draw_source, incoming)
				for id in incoming:
					pending_draws.erase(id)
			"hand_discarded":
				for view in hand.cards.values():
					create_tween().tween_property(view, "modulate:a", 0.0, action_duration / speed)
				await wait(action_duration / speed)
			"shuffle":
				announced.emit(I18n.t("SHUFFLED"))
			"overflow":
				announced.emit(I18n.t("OVERFLOW", [event.title]))

func wait(duration: float) -> void:
	await get_tree().create_timer(duration, false).timeout

func floating(actor: BattleActor, text: String, tint: Color, settings: GameProfile) -> void:
	var cue = floating_scene.instantiate()
	get_parent().add_child(cue)
	cue.global_position = actor.sprite.global_position + Vector2(-90, -140)
	cue.show_value(text, tint, settings.reduced_motion, settings.animation_speed)

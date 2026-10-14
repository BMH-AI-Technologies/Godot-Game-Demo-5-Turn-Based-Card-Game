extends GamePopup
var app

func _ready() -> void:
	super._ready()
	%Music.value_changed.connect(func(value): app.profile.music_volume = value; update_audio())
	%Effects.value_changed.connect(func(value): app.profile.effects_volume = value; update_audio())
	%Speed.value_changed.connect(func(value): app.profile.animation_speed = value; update_values())
	%Reduced.toggled.connect(func(value): app.profile.reduced_motion = value; app.apply_settings())
	%Fullscreen.toggled.connect(func(value): app.profile.fullscreen = value; app.apply_settings())
	%Language.item_selected.connect(func(index): app.set_language("vi" if index == 0 else "en"))
	%Save.pressed.connect(save_settings)

func setup(game) -> void:
	app = game
	%Music.set_value_no_signal(app.profile.music_volume)
	%Effects.set_value_no_signal(app.profile.effects_volume)
	%Speed.set_value_no_signal(app.profile.animation_speed)
	%Reduced.set_pressed_no_signal(app.profile.reduced_motion)
	%Fullscreen.set_pressed_no_signal(app.profile.fullscreen)
	%Language.add_item("Tiếng Việt")
	%Language.add_item("English")
	refresh_text()

func refresh_text() -> void:
	%Heading.text = I18n.t("SETTINGS")
	%Language.select(0 if app.profile.language == "vi" else 1)
	update_values()

func update_values() -> void:
	%MusicValue.text = "%d%%" % int(app.profile.music_volume * 100)
	%EffectsValue.text = "%d%%" % int(app.profile.effects_volume * 100)
	%SpeedValue.text = "%.2f×" % app.profile.animation_speed

func update_audio() -> void:
	app.audio.apply_settings()
	update_values()

func save_settings() -> void:
	var error: Error = app.profile.save()
	if error == OK:
		closed.emit()
	else:
		%Feedback.text = I18n.t("SAVE_FAILED", [error])

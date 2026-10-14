extends GameScreen

func _ready() -> void:
	%Play.pressed.connect(func(): app.show_setup())
	%Deck.pressed.connect(func(): app.show_deck())
	%Settings.pressed.connect(func(): app.show_settings())
	%Credits.pressed.connect(func(): app.show_credits())
	%Quit.pressed.connect(func(): get_tree().quit())

func setup(game) -> void:
	super.setup(game)
	apply_preferences()

func apply_preferences() -> void:
	var sprite: AnimatedSprite2D = $Margin/Layout/Body/Hero/Portrait/AnimatedSprite2D
	if app.profile.reduced_motion:
		sprite.pause()
	else:
		sprite.play("idle")

class_name GameScreen
extends Control
## Shared context only; each PackedScene owns its controls and screen logic.

var app

func setup(game) -> void:
	app = game
	refresh_text()

func refresh_text() -> void:
	pass

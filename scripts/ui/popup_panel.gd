class_name GamePopup
extends Control
signal closed

func _ready() -> void:
	%Close.pressed.connect(func(): closed.emit())

extends Control
## One live card view and one visible back for every extra copy.
signal count_changed(card_id: String, delta: int)
@onready var card: DeckCard = %Card

func _ready() -> void:
	card.count_changed.connect(func(id, delta): count_changed.emit(id, delta))

func configure(data: CardDefinition, count: int, reduced: bool) -> void:
	card.configure(data, count, "deck", false, reduced)
	for i in range(1, 5):
		get_node("Back%d" % i).visible = i < count

class_name CardCatalog
extends Resource
## Explicit references also keep all registered cards in exported builds.
@export var cards: Array[CardDefinition] = []
## Repeat a card reference to add copies to the default starting deck.
@export var starting_deck: Array[CardDefinition] = []

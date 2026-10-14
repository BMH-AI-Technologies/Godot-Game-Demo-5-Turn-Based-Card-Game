class_name EncounterDefinition
extends Resource
## One battle in a linear campaign. Enemy scenes may appear more than once.
@export var title: String = ""
@export var enemies: Array[PackedScene] = []
@export_group("Victory Rewards")
## Percentage of maximum HP; rounded up, capped at maximum HP.
@export_range(0.0, 100.0, 1.0) var heal_percent: float = 10.0
## Choose one card from this many offers. Zero skips card rewards.
@export_range(0, 3) var reward_choices: int = 3
## Empty uses all eligible reward cards in the catalog.
@export var reward_pool: Array[CardDefinition] = []

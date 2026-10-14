class_name ActorDefinition
extends Resource

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var max_hp: int = 30
@export var base_attack: int = 0
@export var base_block: int = 0
@export var attack_bonus: int = 0
@export var mana_offset: int = 0
@export var natural_draw: int = 1
@export var is_boss: bool = false
@export var abilities: Array[AbilityDefinition] = []
@export var behavior: ActorBehavior

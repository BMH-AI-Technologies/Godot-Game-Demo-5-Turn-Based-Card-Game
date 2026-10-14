@tool
class_name EnemyActor
extends BattleActor
## Inherit enemy.tscn. Change exported stats, SpriteFrames and special actions.

@export_group("Artwork")
## Texture for the enemy inspection card, independent of its battle animations.
@export var artwork: Texture2D

@export_group("Abilities")
@export var basic_attack: EnemySkill = preload("res://data/enemies skill/basic_attack.tres")
@export var basic_block: EnemySkill = preload("res://data/enemies skill/basic_block.tres")
@export var special_actions: Array[EnemySkill] = []
@export var behavior: ActorBehavior
@export var is_boss: bool = false

func build_definition() -> ActorDefinition:
	var data := super.build_definition()
	data.is_boss = is_boss
	data.behavior = behavior
	data.abilities = [basic_attack, basic_block]
	data.abilities.append_array(special_actions)
	return data

class_name ActorState
extends RefCounted

var id: int
var definition: ActorDefinition
var hp: int
var block: int = 0
var mana: int = 0
var weak: int = 0
var vulnerable: int = 0
var strength: int = 0
var intent: AbilityDefinition
var intent_canceled: bool = false
var intent_paid: bool = false
var ready_round: Dictionary = {}
var last_action: String = ""
var memory: Dictionary = {}

func _init(actor_id: int, data: ActorDefinition) -> void:
	id = actor_id
	definition = data
	hp = data.max_hp

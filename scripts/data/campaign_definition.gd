class_name CampaignDefinition
extends Resource
@export var title: String = ""
## Array order is the route order; winning the last encounter ends the campaign.
@export var encounters: Array[EncounterDefinition] = []
@export_multiline var completion_text: String = "You completed every battle in this campaign."

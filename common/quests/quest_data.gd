extends Resource
class_name QuestData

enum QuestCategory { STORY_EVENT, MUNICIPAL, GUILD, AMBIENT_LEAD }

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var category: QuestCategory = QuestCategory.AMBIENT_LEAD
@export var quest_level: int = 1
@export var giver_npc_id: String = ""
@export var region: String = ""
@export var target_item: Resource = null # Resolved to ItemData at runtime
@export var target_amount: int = 0
@export var next_quest_id: String = ""
@export var next_quest: QuestData = null # Stitched relation pointer
@export var is_hidden_lead: bool = false
@export var gates_profession_promotion: String = "None"
@export var gates_title_promotion: String = "None"
@export var is_one_time: bool = false
@export var target_gold: int = 0
@export var unlocks_province_license: String = ""


@export var gold_reward: int = 0
@export var xp_reward: int = 0
@export var influence_reward: int = 0

func get_gold_reward() -> int:
	return gold_reward if gold_reward > 0 else quest_level * 200

func get_xp_reward() -> int:
	return xp_reward if xp_reward > 0 else quest_level * 100

func get_influence_reward() -> int:
	return influence_reward if influence_reward > 0 else quest_level * 10

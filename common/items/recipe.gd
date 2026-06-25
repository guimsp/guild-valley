class_name Recipe
extends Resource

@export var is_breakthrough_only: bool = false
@export var is_service: bool = false
@export_enum("Basic", "Mandatory Input", "Dynamic Boost") var service_type: int = 0
@export var booster_item: ItemData = null

# Display name of the recipe (e.g. "Bake Bread", "Smelt Iron")
@export var recipe_name: String = ""

# Job career category ("patreon", "craftsman", "tailor", "scholar", "woodworker", "herbalist")
@export_enum("patreon", "craftsman", "tailor", "scholar", "woodworker", "herbalist", "rogue", "showman") var required_career: String = "patreon"

# Minimum level required in that job to craft this item
@export var required_level: int = 1

# Input ingredients required: Map of ItemData -> quantity
@export var inputs: Dictionary[ItemData, int] = {}

# Output item produced
@export var output_item: ItemData

# Output quantity produced
@export var output_amount: int = 1

# XP rewarded to the corresponding career when crafted
@export var xp_reward: int = 15

func get_base_craft_time() -> float:
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var econ = main_loop.root.get_node_or_null("EconomyManager")
		if econ and econ.has_method("get_algorithmic_craft_time"):
			return econ.get_algorithmic_craft_time(self)
			
	if not output_item:
		return float(required_level * 5.0)
		
	var level = output_item.item_level
	var category = output_item.get_item_category()
	
	if category == ItemData.ItemCategory.SEMI_ELABORATE:
		return 14.0 + (level - 1) * 4.0
	elif category in [ItemData.ItemCategory.FINISHED_PRODUCT, ItemData.ItemCategory.EQUIPABLE, ItemData.ItemCategory.CONSUMABLE]:
		return 24.0 + (level - 1) * 6.0
	else:
		return 10.0 + (level - 1) * 4.0

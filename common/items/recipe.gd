class_name Recipe
extends Resource

@export var is_breakthrough_only: bool = false
@export var is_service: bool = false

# Display name of the recipe (e.g. "Bake Bread", "Smelt Iron")
@export var recipe_name: String = ""

# Job career category ("patreon", "craftsman", "tailor", "scholar")
@export_enum("patreon", "craftsman", "tailor", "scholar") var required_career: String = "patreon"

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

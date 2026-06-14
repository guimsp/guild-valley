class_name Recipe
extends Resource

# Display name of the recipe (e.g. "Bake Bread", "Smelt Iron")
@export var recipe_name: String = ""

# Job career category ("farmer", "craftsman", "tailor")
@export_enum("farmer", "craftsman", "tailor") var required_career: String = "farmer"

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

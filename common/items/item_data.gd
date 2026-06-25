class_name ItemData
extends Resource

enum ItemCategory {
	RAW_MATERIAL,
	SEMI_ELABORATE,
	FINISHED_PRODUCT,
	EQUIPABLE,
	CONSUMABLE
}

enum RarityTier {
	COMMON,
	LUXURY,
	RARE
}

@export var item_category_override: int = -1
@export var rarity_override: int = -1
@export var target_stock_override: int = -1
@export var price_elasticity_override: float = -1.0
@export var price_override: int = -1
@export var is_liquid: bool = false

# Unique identifier for the item (e.g. "wheat", "iron_ore")
@export var id: String = ""

# Item advancement level/tier (used for dynamic crafting time calculations)
@export var item_level: int = 1

# User-facing display name (e.g. "Wheat")
@export var name: String = ""

# Visual texture icon for UI inventory slots
@export var icon: Texture2D

# Base market value before supply and demand adjustments
@export var base_value: int = 10:
	get:
		if price_override > 0:
			return price_override
		var main_loop = Engine.get_main_loop()
		if main_loop and main_loop.root:
			var econ = main_loop.root.get_node_or_null("EconomyManager")
			if econ and econ.has_method("get_algorithmic_base_value"):
				return econ.get_algorithmic_base_value(self)
		return base_value

# Minimum price bounds for pricing controls
@export var min_price: int = 1:
	get:
		if min_price == 1:
			return max(1, int(round(base_value * 0.5)))
		return min_price

# Maximum price bounds for pricing controls
@export var max_price: int = 999:
	get:
		if max_price == 999:
			return max(base_value + 1, int(round(base_value * 1.8)))
		return max_price

# Weight per unit (useful for inventory limits)
@export var weight: float = 0.5

# Item category
@export_enum("Resource", "Material", "Product", "Food") var category: String = "Resource"

# Marketplace category for grouping and navigation
@export_enum("Raw Materials", "Semi-Elaborate", "Finished Goods", "Consumables", "Equipment", "Skill Items") var market_category: String = "Raw Materials"

# General item type
@export_enum("Raw Material", "Consumable", "Equipment", "Quest") var item_type: String = "Raw Material"

# Slot type if the item is equipable
@export_enum("None", "Head", "Body", "Gloves", "Weapon", "Tool", "Bag", "Necklace", "Ring", "Transportation") var equipment_slot: String = "None"

# Equipment Stats
@export var armor_stat: int = 0
@export var attack_stat: int = 0
@export var speed_bonus: float = 0.0
@export var capacity_bonus: int = 0
@export var gathering_multiplier_bonus: float = 0.0
@export var durability: int = 100
@export var max_durability: int = 100
@export var is_tool: bool = false

# Flag indicating if the item can be traded in markets
@export var is_tradable: bool = true

# Flag indicating if the item can stack in inventory slots
@export var is_stackable: bool = true

# Maximum quantity per stack (if stackable)
@export var max_stack: int = 20

# Flag indicating if the item is a luxury product
@export var is_luxury_product: bool = false

# Flag indicating if the item is a baseline raw material
@export var is_raw_material: bool = false:
	get:
		if market_category == "Raw Materials" or id == "standard_timber":
			return true
		return is_raw_material

# User-facing description
@export_multiline var description: String = ""

func get_item_category() -> int:
	if item_category_override != -1:
		return item_category_override
	match market_category:
		"Raw Materials":
			return ItemCategory.RAW_MATERIAL
		"Semi-Elaborate":
			return ItemCategory.SEMI_ELABORATE
		"Finished Goods":
			return ItemCategory.FINISHED_PRODUCT
		"Consumables":
			return ItemCategory.CONSUMABLE
		"Equipment":
			return ItemCategory.EQUIPABLE
		"Skill Items":
			return ItemCategory.EQUIPABLE
		_:
			return ItemCategory.RAW_MATERIAL

func get_rarity_tier() -> int:
	if rarity_override != -1:
		return rarity_override
	if is_luxury_product:
		return RarityTier.LUXURY
	if market_category == "Skill Items":
		return RarityTier.RARE
	return RarityTier.COMMON

func get_target_stock() -> int:
	if target_stock_override != -1:
		return target_stock_override
	match get_rarity_tier():
		RarityTier.COMMON:
			return 80
		RarityTier.LUXURY:
			return 35
		RarityTier.RARE:
			return 10
		_:
			return 80

func get_price_elasticity() -> float:
	if price_elasticity_override >= 0.0:
		return price_elasticity_override
	match get_rarity_tier():
		RarityTier.COMMON:
			return 1.0
		RarityTier.LUXURY:
			return 1.5
		RarityTier.RARE:
			return 3.0
		_:
			return 1.0


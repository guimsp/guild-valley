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

# Unique identifier for the item (e.g. "wheat", "iron_ore")
@export var id: String = ""

# User-facing display name (e.g. "Wheat")
@export var name: String = ""

# Visual texture icon for UI inventory slots
@export var icon: Texture2D

# Base market value before supply and demand adjustments
@export var base_value: int = 10

# Minimum price bounds for pricing controls
@export var min_price: int = 1

# Maximum price bounds for pricing controls
@export var max_price: int = 999

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
		if market_category == "Raw Materials":
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
			return 0.5
		RarityTier.LUXURY:
			return 1.2
		RarityTier.RARE:
			return 3.0
		_:
			return 1.0


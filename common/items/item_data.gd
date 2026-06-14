class_name ItemData
extends Resource

# Unique identifier for the item (e.g. "wheat", "iron_ore")
@export var id: String = ""

# User-facing display name (e.g. "Wheat")
@export var name: String = ""

# Visual texture icon for UI inventory slots
@export var icon: Texture2D

# Base market value before supply and demand adjustments
@export var base_value: int = 10

# Weight per unit (useful for inventory limits)
@export var weight: float = 0.5

# Item category
@export_enum("Resource", "Material", "Product", "Food") var category: String = "Resource"

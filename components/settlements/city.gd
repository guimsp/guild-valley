class_name City
extends Node2D

@export var city_name: String = "Capital City"
@export var radius_of_influence: float = 800.0
@export var prosperity: int = 50
@export var growth_points: int = 0
@export var growth_milestones: int = 100
@export var is_growing: bool = true
@export var market_node_path: NodePath
@export var security_level: float = 0.8
@export var ownership_province: String = ""

func _ready() -> void:
	add_to_group("Cities")

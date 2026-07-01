class_name CraftingBench
extends StaticBody2D

@export var building_data: BuildingData = null
@export var bench_name: String = "Crafting Bench"

@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Public"
@export var owner_id: String = ""
@export var buy_cost: int = 150
@export var rent_cost: int = 40
@export var rent_days_remaining: int = 0
@export var max_rent_days: int = 5
@export var is_buyable: bool = false
@export var is_rentable: bool = false

# List of recipes available at this bench
@export var recipes: Array[Recipe] = []

@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	if not building_data:
		building_data = GameState.get_building_data_for_node(self)
	add_to_group("CraftingBenches")
	add_to_group("nav_carve_obstacles")
	GameState.add_text_tag(self, "Bench")
	# Load default recipes if none are assigned
	if recipes.is_empty():
		var grind_wheat = load("res://common/items/recipes/grind_wheat.tres")
		var bake_bread = load("res://common/items/recipes/bake_bread.tres")
		if grind_wheat:
			recipes.append(grind_wheat)
		if bake_bread:
			recipes.append(bake_bread)

	# Connect interaction signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

# Prompt text displayed on HUD
func get_interaction_text() -> String:
	return "Craft"

func interact(_player: CharacterBody2D) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
		
	if hud:
		var parent_b = get_parent().get("parent_building")
		if parent_b and parent_b.ownership_type == "Player" and hud.has_method("open_building_ui"):
			hud.open_building_ui(parent_b)
		else:
			hud.open_crafting(self)

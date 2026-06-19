extends StaticBody2D

@export var building_data: BuildingData = null

@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Player"
@export var owner_id: String = "Player"
@export var buy_cost: int = 400
@export var custom_name: String = "Warehouse"

# Minimum retained stock: item_id (String) -> int (retained amount)
var min_retained_stock: Dictionary = {}
var is_warehouse: bool = true

@onready var front_area: Area2D = get_node_or_null("FrontInteractionArea")

var nearest_settlement: Node2D = null
var inventory: Node = null

func _ready() -> void:
	if not building_data:
		building_data = GameState.get_building_data_for_node(self)
	add_to_group("Warehouses")
	add_to_group("production_buildings") # Added to production_buildings so logistics/routes see it
	add_to_group("nav_carve_obstacles")
	GameState.add_text_tag(self, custom_name)
	
	var footprint = get_node_or_null("CollisionShape2D")
	if footprint:
		footprint.disabled = true
		
	if front_area:
		front_area.body_entered.connect(_on_front_body_entered)
		front_area.body_exited.connect(_on_front_body_exited)
		
	_setup_inventory()
	
	await get_tree().process_frame
	_find_nearest_settlement()

func _find_nearest_settlement() -> void:
	var min_dist: float = INF
	var closest: Node2D = null
	for city in get_tree().get_nodes_in_group("Cities"):
		var dist = global_position.distance_to(city.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = city
	for town in get_tree().get_nodes_in_group("Towns"):
		var dist = global_position.distance_to(town.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = town
	nearest_settlement = closest

func _on_front_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_front_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

func get_interaction_text() -> String:
	return "Manage Warehouse"

func interact(player: CharacterBody2D) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("open_building_ui"):
		hud.open_building_ui(self)

func _setup_inventory() -> void:
	var inv_script = load("res://components/inventory/inventory_component.gd")
	inventory = inv_script.new()
	inventory.name = "BuildingInventory"
	inventory.max_slots = 48
	inventory.max_stack = 50 # Higher stacks for warehousing
	inventory.max_weight = 1000.0
	add_child(inventory)

# Logistics courier compatibility method: checks how much is available above the lock threshold
func get_available_item_amount(item_id: String) -> int:
	var total = inventory.get_item_amount(item_id) if inventory else 0
	var min_stock = min_retained_stock.get(item_id, 0)
	var available = max(0, total - min_stock)
	return available

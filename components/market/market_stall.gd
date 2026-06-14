class_name MarketStall
extends StaticBody2D

@export var market_name: String = "Town Market"

@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Public"
@export var owner_id: String = ""
@export var buy_cost: int = 250
@export var rent_cost: int = 60
@export var rent_days_remaining: int = 0
@export var max_rent_days: int = 5
@export var is_buyable: bool = true
@export var is_rentable: bool = false

# Sensitivity of price shifts (higher = steeper price changes)
@export var sensitivity: float = 0.5

# Map of ItemData -> Target stock count (the ideal amount the market wants)
var target_stock: Dictionary = {}

@onready var inventory: InventoryComponent = $InventoryComponent
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	add_to_group("MarketStall")
	GameState.add_text_tag(self, "Stall")
	# Populate default goods for testing
	_populate_default_stock()
	
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
	return "Trade"

# Called when player interacts (presses E)
func interact(player: CharacterBody2D) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud:
		hud.open_market(self)


func _populate_default_stock() -> void:
	# Load item resources
	var wheat: ItemData = load("res://common/items/instances/wheat.tres")
	var flour: ItemData = load("res://common/items/instances/flour.tres")
	var bread: ItemData = load("res://common/items/instances/bread.tres")
	var cotton: ItemData = load("res://common/items/instances/cotton.tres")
	var cloth: ItemData = load("res://common/items/instances/cloth.tres")
	var ore: ItemData = load("res://common/items/instances/iron_ore.tres")
	var ingot: ItemData = load("res://common/items/instances/iron_ingot.tres")
	
	# Set market goals (target stocks)
	target_stock[wheat] = 40
	target_stock[flour] = 20
	target_stock[bread] = 10
	target_stock[cotton] = 30
	target_stock[cloth] = 15
	target_stock[ore] = 25
	target_stock[ingot] = 10
	
	# Initialize stock (start at 50% target stock)
	if inventory:
		inventory.add_item(wheat, 20)
		inventory.add_item(flour, 10)
		inventory.add_item(bread, 5)
		inventory.add_item(cotton, 15)
		inventory.add_item(cloth, 7)
		inventory.add_item(ore, 12)
		inventory.add_item(ingot, 5)

# Calculate buy price (what player pays to buy 1 unit)
func get_buy_price(item: ItemData) -> int:
	var base_val: int = item.base_value
	var current_stock: int = inventory.get_item_amount(item.id)
	var target: int = target_stock.get(item, 10)
	
	if target <= 0:
		target = 10
		
	var multiplier: float = 1.0 + (float(target - current_stock) / target) * sensitivity
	multiplier = clamp(multiplier, 0.2, 3.0)
	
	# Buy price is slightly higher than value (10% trade spread)
	return int(base_val * multiplier * 1.1)

# Calculate sell price (what player receives when selling 1 unit)
func get_sell_price(item: ItemData) -> int:
	var base_val: int = item.base_value
	var current_stock: int = inventory.get_item_amount(item.id)
	var target: int = target_stock.get(item, 10)
	
	if target <= 0:
		target = 10
		
	var multiplier: float = 1.0 + (float(target - current_stock) / target) * sensitivity
	multiplier = clamp(multiplier, 0.2, 3.0)
	
	# Sell price is slightly lower than value (10% trade spread)
	return int(base_val * multiplier * 0.9)

# Executes buying items from the market (player inventory gets items, pays gold)
func buy_item(item: ItemData, amount: int) -> bool:
	var current_stock: int = inventory.get_item_amount(item.id)
	if current_stock < amount:
		print("[MarketStall] Not enough stock in market!")
		return false
		
	# Calculate price incrementally (marginal price changes per unit purchased)
	var total_price: int = 0
	var temp_stock: int = current_stock
	for i in range(amount):
		var target: int = target_stock.get(item, 10)
		var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
		multiplier = clamp(multiplier, 0.2, 3.0)
		total_price += int(item.base_value * multiplier * 1.1)
		temp_stock -= 1
		
	if GameState.gold < total_price:
		print("[MarketStall] Player cannot afford purchase! Cost: %d, Gold: %d" % [total_price, GameState.gold])
		return false
		
	# Attempt to add to player inventory
	var remainder: int = GameState.player_inventory.add_item(item, amount)
	if remainder > 0:
		var accepted: int = amount - remainder
		if accepted <= 0:
			print("[MarketStall] Player inventory is full!")
			return false
			
		# Recalculate price for accepted portion
		total_price = 0
		temp_stock = current_stock
		for i in range(accepted):
			var target: int = target_stock.get(item, 10)
			var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
			multiplier = clamp(multiplier, 0.2, 3.0)
			total_price += int(item.base_value * multiplier * 1.1)
			temp_stock -= 1
			
		GameState.gold -= total_price
		inventory.remove_item(item.id, accepted)
	else:
		GameState.gold -= total_price
		inventory.remove_item(item.id, amount)
		
	print("[MarketStall] Transaction successful. Bought %d %s for %d Gold." % [amount - remainder, item.name, total_price])
	return true

# Executes selling items to the market (player sells items, receives gold)
func sell_item(item: ItemData, amount: int) -> bool:
	var player_stock: int = GameState.player_inventory.get_item_amount(item.id)
	if player_stock < amount:
		print("[MarketStall] Player doesn't have enough items to sell!")
		return false
		
	# Calculate revenue incrementally
	var current_stock: int = inventory.get_item_amount(item.id)
	var total_revenue: int = 0
	var temp_stock: int = current_stock
	for i in range(amount):
		var target: int = target_stock.get(item, 10)
		var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
		multiplier = clamp(multiplier, 0.2, 3.0)
		total_revenue += int(item.base_value * multiplier * 0.9)
		temp_stock += 1
		
	# Try to add items to market inventory
	var remainder: int = inventory.add_item(item, amount)
	if remainder > 0:
		var accepted: int = amount - remainder
		if accepted <= 0:
			print("[MarketStall] Market inventory is full!")
			return false
			
		# Recalculate revenue for accepted portion
		total_revenue = 0
		temp_stock = current_stock
		for i in range(accepted):
			var target: int = target_stock.get(item, 10)
			var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
			multiplier = clamp(multiplier, 0.2, 3.0)
			total_revenue += int(item.base_value * multiplier * 0.9)
			temp_stock += 1
			
		GameState.gold += total_revenue
		GameState.player_inventory.remove_item(item.id, accepted)
	else:
		GameState.gold += total_revenue
		GameState.player_inventory.remove_item(item.id, amount)
		
	print("[MarketStall] Transaction successful. Sold %d %s for %d Gold." % [amount - remainder, item.name, total_revenue])
	return true

func simulate_overnight_tick() -> void:
	# Load item resources
	var wheat: ItemData = load("res://common/items/instances/wheat.tres")
	var flour: ItemData = load("res://common/items/instances/flour.tres")
	var bread: ItemData = load("res://common/items/instances/bread.tres")
	
	if not inventory:
		return
		
	# Farmers deliver Wheat
	inventory.add_item(wheat, 5)
	
	# Millers consume Wheat to make Flour (e.g. consume 3 Wheat, add 1 Flour)
	if inventory.has_item(wheat.id, 3):
		inventory.remove_item(wheat.id, 3)
		inventory.add_item(flour, 1)
		
	# Bakers consume Flour to make Bread (e.g. consume 2 Flour, add 1 Bread)
	if inventory.has_item(flour.id, 2):
		inventory.remove_item(flour.id, 2)
		inventory.add_item(bread, 1)
		
	# Townspeople eat Bread (consume 2 Bread)
	inventory.remove_item(bread.id, 2)
	
	print("[MarketStall] Overnight tick completed: Wheat, Flour, and Bread stocks adjusted.")


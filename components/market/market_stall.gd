class_name MarketStall
extends StaticBody2D

@export var building_data: BuildingData = null
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

@export var attractiveness: int = 10:
	set(val):
		attractiveness = clamp(val, 10, 100)

var temp_attractiveness_modifier: int = 0

func get_shop_attractiveness() -> int:
	if ownership_type == "Public":
		return 35
		
	var base_attr = attractiveness
	if parent_building and "attractiveness" in parent_building:
		base_attr = parent_building.attractiveness
		
	var parent_temp = 0
	if parent_building and "temp_attractiveness_modifier" in parent_building:
		parent_temp = parent_building.temp_attractiveness_modifier
		
	var has_event_hall = false
	for hall in get_tree().get_nodes_in_group("EventHalls"):
		if is_instance_valid(hall) and hall.ownership_type == "Player":
			has_event_hall = true
			break
	if has_event_hall:
		base_attr = int(base_attr * 1.05)
		
	# Apply local tax delinquency penalty (-20% attractiveness)
	var pm = get_node_or_null("/root/PoliticsManager")
	var prov = GameState.get_province_of_node(self) if GameState else ""
	if pm and prov != "":
		var faction = ""
		if ownership_type == "Player" or (ownership_type == "Rented" and owner_id == "Player"):
			faction = "Player"
		elif ownership_type == "NPC" and owner_id == "Rival":
			faction = "Rival"
			
		if faction != "" and pm.is_faction_delinquent(faction, prov):
			base_attr = int(base_attr * 0.80)
		
	return clamp(base_attr + temp_attractiveness_modifier + parent_temp, 10, 100)

func recalculate_attractiveness() -> void:
	for ui in get_tree().get_nodes_in_group("MarketUIs"):
		if ui.visible and ui.get("_stall") == self:
			if ui.has_method("refresh"):
				ui.call_deferred("refresh")

func upgrade_attractiveness(amount: int) -> void:
	if parent_building and parent_building.has_method("upgrade_attractiveness"):
		parent_building.upgrade_attractiveness(amount)
	else:
		attractiveness += amount

func apply_temp_attractiveness_modifier(amount: int) -> void:
	if parent_building and parent_building.has_method("apply_temp_attractiveness_modifier"):
		parent_building.apply_temp_attractiveness_modifier(amount)
	else:
		temp_attractiveness_modifier += amount

var parent_building: Node2D = null
var custom_prices: Dictionary = {}

# Map of ItemData -> Target stock count (the ideal amount the market wants)
var target_stock: Dictionary = {}

@onready var inventory: InventoryComponent = $InventoryComponent
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	GameState.ensure_strongbox(self)
	if not building_data:
		building_data = GameState.get_building_data_for_node(self)
	if building_data and "attractiveness" in building_data:
		attractiveness = building_data.attractiveness
	add_to_group("MarketStall")
	add_to_group("nav_carve_obstacles")
	GameState.add_text_tag(self, "Stall")
	# Populate default goods for testing
	_populate_default_stock()
	
	# Connect interaction signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
		# Set dynamic customized interaction shape to prevent overlap
		var col = interaction_area.get_node_or_null("CollisionShape2D")
		if col:
			var shape = CircleShape2D.new()
			shape.radius = 32.0
			col.shape = shape
			col.position = Vector2(0, 24)

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

# Prompt text displayed on HUD
func get_interaction_text() -> String:
	return "Trade"

func get_custom_price(item: ItemData) -> int:
	if custom_prices.has(item.id):
		return custom_prices[item.id]
	return item.base_value


# Called when player interacts (presses E)
func interact(player: CharacterBody2D) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud:
		hud.open_market(self)


func _populate_default_stock() -> void:
	# Load item resources
	var wheat: ItemData = load("res://common/items/instances/Raw Materials/wheat.tres")
	var flour: ItemData = load("res://common/items/instances/Semi-Elaborate/flour.tres")
	var bread: ItemData = load("res://common/items/instances/Finished Goods/bread.tres")
	var cotton: ItemData = load("res://common/items/instances/Raw Materials/cotton.tres")
	var cloth: ItemData = load("res://common/items/instances/Semi-Elaborate/cloth.tres")
	var ore: ItemData = load("res://common/items/instances/Raw Materials/iron_ore.tres")
	var ingot: ItemData = load("res://common/items/instances/Semi-Elaborate/iron_ingot.tres")
	var ale: ItemData = load("res://common/items/instances/Finished Goods/ale.tres")
	
	# Load guide books
	var book_p: ItemData = load("res://common/items/instances/Skill Items/book_patreon.tres")
	var book_c: ItemData = load("res://common/items/instances/Skill Items/book_craftsman.tres")
	var book_t: ItemData = load("res://common/items/instances/Skill Items/book_tailor.tres")
	var book_s: ItemData = load("res://common/items/instances/Skill Items/book_scholar.tres")
	
	# Set market goals (target stocks)
	target_stock[wheat] = 40
	target_stock[flour] = 20
	target_stock[bread] = 10
	target_stock[cotton] = 30
	target_stock[cloth] = 15
	target_stock[ore] = 25
	target_stock[ingot] = 10
	target_stock[ale] = 30
	target_stock[book_p] = 1
	target_stock[book_c] = 1
	target_stock[book_t] = 1
	target_stock[book_s] = 1
	
	# Initialize stock (start at 50% target stock)
	if inventory:
		inventory.add_item(wheat, 20)
		inventory.add_item(flour, 10)
		if ownership_type != "Public":
			inventory.add_item(bread, 20)
		else:
			inventory.add_item(bread, 5)
		inventory.add_item(cotton, 15)
		inventory.add_item(cloth, 7)
		inventory.add_item(ore, 12)
		inventory.add_item(ingot, 5)
		inventory.add_item(ale, 15)
		inventory.add_item(book_p, 1)
		inventory.add_item(book_c, 1)
		inventory.add_item(book_t, 1)
		inventory.add_item(book_s, 1)

func get_single_buy_price(item: ItemData, temp_stock: int) -> int:
	var base_val: int = item.base_value
	var target: int = target_stock.get(item, 10)
	if target <= 0: target = 10
	var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
	multiplier = clamp(multiplier, 0.2, 3.0)
	
	var price = 0.0
	if ownership_type == "Public":
		price = base_val * multiplier
	else:
		price = base_val * multiplier * 1.1
		
	# Apply Infrastructure Tariff Import Buy Markup
	var pm = get_node_or_null("/root/PoliticsManager")
	var prov = GameState.get_province_of_node(self) if GameState else ""
	if pm and prov != "" and ownership_type == "Public":
		if pm.is_law_active("infrastructure_tariff_inc", prov):
			price *= 1.50
		elif pm.is_law_active("infrastructure_tariff_dec", prov):
			price *= 0.50
			
	return int(price)

# Calculate buy price (what player pays to buy 1 unit)
func get_buy_price(item: ItemData) -> int:
	if custom_prices.has(item.id):
		return custom_prices[item.id]
	var current_stock: int = inventory.get_item_amount(item.id)
	return get_single_buy_price(item, current_stock)

# Calculate sell price (what player receives when selling 1 unit)
func get_sell_price(item: ItemData) -> int:
	if custom_prices.has(item.id):
		return int(custom_prices[item.id] * 0.8)
		
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
		
	if ownership_type == "Player" or (ownership_type == "Rented" and owner_id == "Player"):
		# Withdraw item from stall (0 gold cost)
		var remainder: int = GameState.player_inventory.add_item(item, amount)
		if remainder > 0:
			var accepted: int = amount - remainder
			if accepted <= 0:
				print("[MarketStall] Player inventory is full!")
				return false
			inventory.remove_item(item.id, accepted)
		else:
			inventory.remove_item(item.id, amount)
		print("[MarketStall] Withdrew %d %s from storefront." % [amount, item.name])
		return true
		
	# Calculate price incrementally (marginal price changes per unit purchased)
	var total_price: int = 0
	var temp_stock: int = current_stock
	for i in range(amount):
		total_price += get_single_buy_price(item, temp_stock)
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
			total_price += get_single_buy_price(item, temp_stock)
			temp_stock -= 1
			
		GameState.gold -= total_price
		inventory.remove_item(item.id, accepted)
	else:
		GameState.gold -= total_price
		inventory.remove_item(item.id, amount)
		
	# Payout competitor owner if NPC owned
	if ownership_type == "NPC" and owner_id == "Rival":
		var rivals = get_tree().get_nodes_in_group("Rivals")
		if rivals.size() > 0:
			rivals[0].gold += total_price
		
	print("[MarketStall] Transaction successful. Bought %d %s for %d Gold." % [amount - remainder, item.name, total_price])
	return true

# Executes selling items to the market (player sells items, receives gold)
func sell_item(item: ItemData, amount: int) -> bool:
	var player_stock: int = GameState.player_inventory.get_item_amount(item.id)
	if player_stock < amount:
		print("[MarketStall] Player doesn't have enough items to sell!")
		return false
		
	if ownership_type == "Player" or (ownership_type == "Rented" and owner_id == "Player"):
		# Deposit item into stall (0 gold revenue)
		var remainder: int = inventory.add_item(item, amount)
		if remainder > 0:
			var accepted: int = amount - remainder
			if accepted <= 0:
				print("[MarketStall] Market inventory is full!")
				return false
			GameState.player_inventory.remove_item(item.id, accepted)
		else:
			GameState.player_inventory.remove_item(item.id, amount)
		print("[MarketStall] Deposited %d %s to storefront." % [amount, item.name])
		return true
		
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
			
		# Deduct from rival if NPC owned
		if ownership_type == "NPC" and owner_id == "Rival":
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				if rivals[0].gold < total_revenue:
					# Rollback inventory add
					inventory.remove_item(item.id, accepted)
					print("[MarketStall] Rival cannot afford to buy your items!")
					return false
				rivals[0].gold -= total_revenue
			
		GameState.gold += total_revenue
		GameState.player_inventory.remove_item(item.id, accepted)
	else:
		# Deduct from rival if NPC owned
		if ownership_type == "NPC" and owner_id == "Rival":
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				if rivals[0].gold < total_revenue:
					# Rollback inventory add
					inventory.remove_item(item.id, amount)
					print("[MarketStall] Rival cannot afford to buy your items!")
					return false
				rivals[0].gold -= total_revenue
				
		GameState.gold += total_revenue
		GameState.player_inventory.remove_item(item.id, amount)
		
	print("[MarketStall] Transaction successful. Sold %d %s for %d Gold." % [amount - remainder, item.name, total_revenue])
	return true

func get_interaction_position() -> Vector2:
	var marker = get_node_or_null("EntranceMarker")
	if marker:
		return marker.global_position
		
	if parent_building and is_instance_valid(parent_building):
		var b_marker = parent_building.get_node_or_null("EntranceMarker")
		if b_marker:
			return b_marker.global_position
			
	return global_position + Vector2(0, 52)

func simulate_overnight_tick() -> void:
	# Load item resources
	var wheat: ItemData = load("res://common/items/instances/Raw Materials/wheat.tres")
	var flour: ItemData = load("res://common/items/instances/Semi-Elaborate/flour.tres")
	var bread: ItemData = load("res://common/items/instances/Finished Goods/bread.tres")
	
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


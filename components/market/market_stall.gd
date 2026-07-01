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
@export var is_under_audit: bool = false

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

var province_name: String = ""

@onready var inventory: InventoryComponent = $InventoryComponent
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	GameState.ensure_strongbox(self)
	province_name = GameState.get_province_of_node(self) if GameState else "Unknown Province"
	if not building_data:
		building_data = GameState.get_building_data_for_node(self)
	if building_data and "attractiveness" in building_data:
		attractiveness = building_data.attractiveness
	add_to_group("MarketStall")
	add_to_group("nav_carve_obstacles")
	GameState.add_text_tag(self, "Stall")
	# Populate default goods for testing
	_populate_default_stock()
	
	if ownership_type == "Public":
		var econ = get_node_or_null("/root/EconomyManager")
		if econ and econ.has_method("register_public_stall"):
			econ.register_public_stall(self)
	
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
	if is_under_audit or (parent_building != null and parent_building.get("is_under_audit") == true):
		if GameState:
			GameState.spawn_ui_floating_text("Stall is under audit!")
		return
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud:
		hud.open_market(self)


func _populate_default_stock() -> void:
	if name.contains("StorageChest"):
		return
	if ownership_type == "Player" or ownership_type == "Rented" or owner_id == "Rival" or owner_id == "Player":
		return
		
	if ownership_type == "Public":
		if inventory:
			inventory.max_slots = 500
		var econ = get_node_or_null("/root/EconomyManager")
		if econ:
			for item in econ.item_database.values():
				if not item.is_tradable:
					continue
				var cat = item.get_item_category()
				if cat in [0, 1, 2, 3, 4] and item.market_category != "Skill Items":
					target_stock[item] = item.get_target_stock()
					
		# Also add skill books to public markets so players can buy them
		var book_f: ItemData = load("res://common/items/instances/Skill Items/book_fleet_footed.tres")
		var book_i: ItemData = load("res://common/items/instances/Skill Items/book_industrious.tres")
		var book_st: ItemData = load("res://common/items/instances/Skill Items/book_sturdy.tres")
		if book_f: target_stock[book_f] = 1
		if book_i: target_stock[book_i] = 1
		if book_st: target_stock[book_st] = 1
	else:
		# Original default stock logic for non-public/competitor/rented/player stalls
		var wheat: ItemData = load("res://common/items/instances/Raw Materials/wheat.tres")
		var flour: ItemData = load("res://common/items/instances/Semi-Elaborate/flour.tres")
		var bread: ItemData = load("res://common/items/instances/Finished Goods/bread.tres")
		var cotton: ItemData = load("res://common/items/instances/Raw Materials/cotton.tres")
		var cloth: ItemData = load("res://common/items/instances/Semi-Elaborate/cloth.tres")
		var ore: ItemData = load("res://common/items/instances/Raw Materials/iron_ore.tres")
		var ingot: ItemData = load("res://common/items/instances/Semi-Elaborate/iron_ingot.tres")
		var ale: ItemData = load("res://common/items/instances/Finished Goods/ale.tres")
		
		if wheat: target_stock[wheat] = 40
		if flour: target_stock[flour] = 20
		if bread: target_stock[bread] = 10
		if cotton: target_stock[cotton] = 30
		if cloth: target_stock[cloth] = 15
		if ore: target_stock[ore] = 25
		if ingot: target_stock[ingot] = 10
		if ale: target_stock[ale] = 30

	if GameState and SaveLoadManager.is_loading_game:
		print("[MarketStall] Populate default stock aborted (max slots expanded and targets set) for ", name, " because game is loading")
		return
		
	if not is_inside_tree():
		await ready
	await get_tree().physics_frame
	
	if not is_inside_tree() or is_queued_for_deletion():
		return
		
	if ownership_type == "Public" and inventory:
		inventory.max_slots = 9999
		inventory.max_weight = 999999.0

	if ownership_type == "Player" or ownership_type == "Rented" or owner_id == "Rival" or owner_id == "Player":
		return
		
	if ownership_type == "Public":
		var econ = get_node_or_null("/root/EconomyManager")
		if econ:
			for item in econ.item_database.values():
				if not item.is_tradable:
					continue
				var cat = item.get_item_category()
				if cat in [0, 1, 2, 3, 4] and item.market_category != "Skill Items":
					var mid_stock = get_target_mid_stock_for(item)
					var average_amt = int(mid_stock * 0.5)
					# Introduce 35% random variance so starting stock is organic
					var variance = int(average_amt * randf_range(-0.35, 0.35))
					var start_amt = max(1, average_amt + variance)
					if inventory:
						inventory.add_item(item, start_amt)
						
		# Also add skill books to public markets so players can buy them
		var book_f: ItemData = load("res://common/items/instances/Skill Items/book_fleet_footed.tres")
		var book_i: ItemData = load("res://common/items/instances/Skill Items/book_industrious.tres")
		var book_st: ItemData = load("res://common/items/instances/Skill Items/book_sturdy.tres")
		if inventory:
			if book_f: inventory.add_item(book_f, 1)
			if book_i: inventory.add_item(book_i, 1)
			if book_st: inventory.add_item(book_st, 1)
	else:
		var wheat: ItemData = load("res://common/items/instances/Raw Materials/wheat.tres")
		var flour: ItemData = load("res://common/items/instances/Semi-Elaborate/flour.tres")
		var bread: ItemData = load("res://common/items/instances/Finished Goods/bread.tres")
		var cotton: ItemData = load("res://common/items/instances/Raw Materials/cotton.tres")
		var cloth: ItemData = load("res://common/items/instances/Semi-Elaborate/cloth.tres")
		var ore: ItemData = load("res://common/items/instances/Raw Materials/iron_ore.tres")
		var ingot: ItemData = load("res://common/items/instances/Semi-Elaborate/iron_ingot.tres")
		var ale: ItemData = load("res://common/items/instances/Finished Goods/ale.tres")
		
		if inventory:
			if wheat: inventory.add_item(wheat, max(1, 20 + randi_range(-6, 6)))
			if flour: inventory.add_item(flour, max(1, 10 + randi_range(-3, 3)))
			if bread: inventory.add_item(bread, max(1, 20 + randi_range(-6, 6)))
			if cotton: inventory.add_item(cotton, max(1, 15 + randi_range(-4, 4)))
			if cloth: inventory.add_item(cloth, max(1, 7 + randi_range(-2, 2)))
			if ore: inventory.add_item(ore, max(1, 12 + randi_range(-3, 3)))
			if ingot: inventory.add_item(ingot, max(1, 5 + randi_range(-1, 1)))
			if ale: inventory.add_item(ale, max(1, 15 + randi_range(-4, 4)))

func get_target_mid_stock_for(item: ItemData) -> int:
	if not item:
		return 10
	var main_loop = Engine.get_main_loop()
	if not main_loop or not main_loop.root:
		return 10
	var econ = main_loop.root.get_node_or_null("EconomyManager")
	if not econ:
		return 10
		
	var career = econ.get_item_career(item.id)
	var prof = econ.CAREER_TO_PROFESSION.get(career, econ.ProfessionType.PATREON)
	var profile = econ.PROFESSION_PROFILES[prof]
	
	var province_scale = 100.0
	# Only cities' markets scale with prosperity levels
	var nearest_sett = GameState.get_nearest_settlement(self) if GameState else null
	if nearest_sett and nearest_sett.is_in_group("Cities"):
		var prov = GameState.get_province_of_node(self) if GameState else ""
		if ProsperityManager and prov != "":
			province_scale = ProsperityManager.province_prosperity.get(prov, 100.0)
		
	var L = max(1, item.item_level)
	var target_mid = int(ceil(profile.base_stock / pow(L, 1.2))) * (province_scale / 100.0)
	return int(max(1, target_mid))

func get_calculated_price(item: ItemData, current_stock: int) -> float:
	var target_mid = get_target_mid_stock_for(item)
	var mid_price = item.base_value
	
	var min_val = mid_price * 0.5
	var max_val = mid_price * 1.8
	
	var elasticity = item.get_price_elasticity()
	var alpha = elasticity * (sensitivity / 0.5)
	var price = float(mid_price)
	
	if current_stock <= 0:
		price = max_val
	elif current_stock < target_mid:
		var deficit_ratio = 1.0 - (float(current_stock) / target_mid)
		price = mid_price + (max_val - mid_price) * pow(deficit_ratio, alpha)
	elif current_stock <= 2.0 * target_mid:
		var excess_ratio = 2.0 - (float(current_stock) / target_mid)
		price = min_val + (mid_price - min_val) * pow(excess_ratio, alpha)
	else:
		price = min_val
		
	return clamp(price, min_val, max_val)

func get_single_buy_price(item: ItemData, temp_stock: int, ignore_tariffs: bool = false) -> int:
	var base_price = get_calculated_price(item, temp_stock)
	
	var price = 0.0
	if ownership_type == "Public":
		price = base_price
	else:
		price = base_price * 1.1
		
	# Apply Infrastructure Tariff Toll Buy Markup
	if not ignore_tariffs:
		var pm = get_node_or_null("/root/PoliticsManager")
		var prov = GameState.get_province_of_node(self) if GameState else ""
		if pm and prov != "" and ownership_type == "Public":
			if pm.is_law_active("infrastructure_tariff_inc", prov):
				price *= 1.15
			elif pm.is_law_active("infrastructure_tariff_dec", prov):
				price *= 0.85
			
	return int(price)

# Calculate buy price (what player pays to buy 1 unit)
func get_buy_price(item: ItemData, ignore_tariffs: bool = false) -> int:
	if parent_building and "custom_prices" in parent_building and parent_building.custom_prices.has(item.id):
		return parent_building.custom_prices[item.id]
	if custom_prices.has(item.id):
		return custom_prices[item.id]
	var current_stock: int = inventory.get_item_amount(item.id)
	return get_single_buy_price(item, current_stock, ignore_tariffs)

# Calculate sell price (what player receives when selling 1 unit)
func get_sell_price(item: ItemData) -> int:
	if parent_building and "custom_prices" in parent_building and parent_building.custom_prices.has(item.id):
		return int(parent_building.custom_prices[item.id] * 0.8)
	if custom_prices.has(item.id):
		return int(custom_prices[item.id] * 0.8)
		
	var current_stock: int = inventory.get_item_amount(item.id)
	var base_price = get_calculated_price(item, current_stock)
	
	# Sell price is slightly lower than value (10% trade spread)
	return int(base_price * 0.9)

# Calculate single sell price dynamically based on temporary stock level
func get_single_sell_price(item: ItemData, temp_stock: int) -> int:
	if parent_building and "custom_prices" in parent_building and parent_building.custom_prices.has(item.id):
		return int(parent_building.custom_prices[item.id] * 0.8)
	if custom_prices.has(item.id):
		return int(custom_prices[item.id] * 0.8)
		
	var base_price = get_calculated_price(item, temp_stock)
	return int(base_price * 0.9)

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
		var econ = get_node_or_null("/root/EconomyManager")
		if econ and econ.has_method("register_trade_activity"):
			econ.register_trade_activity(String(get_path()), item.id)
		return true
		
	var unit_price: int = get_buy_price(item)
	var total_price: int = unit_price * amount
		
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
			
		total_price = unit_price * accepted
		
		# Set change attribution
		GameState.next_change_reason = "Market Purchase"
		GameState.next_change_detail = item.name
		GameState.gold -= total_price
		inventory.remove_item(item.id, accepted)
	else:
		# Set change attribution
		GameState.next_change_reason = "Market Purchase"
		GameState.next_change_detail = item.name
		GameState.gold -= total_price
		inventory.remove_item(item.id, amount)
		
	# Payout competitor owner if NPC owned
	if ownership_type == "NPC" and owner_id == "Rival":
		var rivals = get_tree().get_nodes_in_group("Rivals")
		if rivals.size() > 0:
			rivals[0].gold += total_price
		
	print("[MarketStall] Transaction successful. Bought %d %s for %d Gold." % [amount - remainder, item.name, total_price])
	var econ = get_node_or_null("/root/EconomyManager")
	if econ and econ.has_method("register_trade_activity"):
		econ.register_trade_activity(String(get_path()), item.id)
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
		var econ = get_node_or_null("/root/EconomyManager")
		if econ and econ.has_method("register_trade_activity"):
			econ.register_trade_activity(String(get_path()), item.id)
		return true
		
	var unit_price: int = get_sell_price(item)
	var total_revenue: int = unit_price * amount
		
	# Try to add items to market inventory
	var remainder: int = inventory.add_item(item, amount)
	if remainder > 0:
		var accepted: int = amount - remainder
		if accepted <= 0:
			print("[MarketStall] Market inventory is full!")
			return false
			
		total_revenue = unit_price * accepted
			
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
			
		# Set change attribution
		GameState.next_change_reason = "Market Sales"
		GameState.next_change_detail = item.name
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
				
		# Set change attribution
		GameState.next_change_reason = "Market Sales"
		GameState.next_change_detail = item.name
		GameState.gold += total_revenue
		GameState.player_inventory.remove_item(item.id, amount)
		
	print("[MarketStall] Transaction successful. Sold %d %s for %d Gold." % [amount - remainder, item.name, total_revenue])
	var econ = get_node_or_null("/root/EconomyManager")
	if econ and econ.has_method("register_trade_activity"):
		econ.register_trade_activity(String(get_path()), item.id)
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


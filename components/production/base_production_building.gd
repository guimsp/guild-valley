class_name BaseProductionBuilding
extends StaticBody2D

@export var building_data: BuildingData = null

@onready var fade_trigger: Area2D = get_node_or_null("FadeTrigger")
@onready var exterior: Control = get_node_or_null("Exterior")

@export var buy_cost: int = 250
@export var is_buyable: bool = true
@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Player":
	set(val):
		ownership_type = val
		if is_node_ready():
			_update_door_state()
			if has_method("update_storefront_stall_state"):
				update_storefront_stall_state()
@export var owner_id: String = "Player"

@export var custom_name: String = ""
@export var is_under_audit: bool = false
var audit_timer: float = 0.0

@export var attractiveness: int = 10:
	set(val):
		attractiveness = clamp(val, 10, 100)

var temp_attractiveness_modifier: int = 0

func upgrade_attractiveness(amount: int) -> void:
	attractiveness += amount

func apply_temp_attractiveness_modifier(amount: int) -> void:
	temp_attractiveness_modifier += amount

var col_door: CollisionShape2D = null
var storefront_stall: Node = self
var inventory: Node = null
var building_storage: Node = null
var entry_door: Area2D = null
var interior_position: Vector2 = Vector2.ZERO
var instanced_interior: Node = null

# --- Storefront / Merchant Interface ---
@export var market_name: String = ""
@export var sensitivity: float = 0.5
var custom_prices: Dictionary = {}
var target_stock: Dictionary = {}

# Component variables
var upgrade_component: Node = null
var staff_component: Node = null

# HR / Candidates
@export var base_max_employees: int = 1
var max_employees: int:
	get:
		var bonus = improvements.get("bunkhouse", 0) if typeof(improvements) == TYPE_DICTIONARY else 0
		return base_max_employees + bonus
	set(val):
		base_max_employees = val

var current_level: int:
	get: return building_level
	set(val):
		building_level = val
		if building_data:
			building_data.building_level = val

@export var building_level: int = 1:
	get:
		return upgrade_component.building_level if upgrade_component else building_level
	set(val):
		if upgrade_component:
			upgrade_component.building_level = val
		else:
			building_level = val

var is_upgrading: bool = false:
	get:
		return upgrade_component.is_upgrading if upgrade_component else is_upgrading
	set(val):
		if upgrade_component:
			upgrade_component.is_upgrading = val
		else:
			is_upgrading = val

var upgrade_timer: float = 0.0:
	get:
		return upgrade_component.upgrade_timer if upgrade_component else upgrade_timer
	set(val):
		if upgrade_component:
			upgrade_component.upgrade_timer = val
		else:
			upgrade_timer = val

var improvements: Dictionary = {
	"storage_vault": 0,      # Max level 3
	"deep_shelving": 0,      # Max level 3
	"extra_workbench": 0,    # Max level 2
	"bunkhouse": 0,          # Max level 2
	"iron_reinforcements": 0,# Max level 3
	"ornate_facade": 0,      # Max level 3
	"strongbox_vault": 0,    # Max level 3
	"auto_gathering": 0,     # Max level 1
	"storefront": 0          # Max level 1
}:
	get:
		return upgrade_component.improvements if upgrade_component else improvements
	set(val):
		if upgrade_component:
			upgrade_component.improvements = val
		else:
			improvements = val

# Level upgrade requirements database
# Key: Next Level -> { "gold_cost": int, "time": float, "profession_level": int }
const UPGRADE_REQUIREMENTS: Dictionary = {
	2: { "gold_cost": 300, "time": 15.0, "profession_level": 3 },
	3: { "gold_cost": 600, "time": 30.0, "profession_level": 5 },
	4: { "gold_cost": 1200, "time": 45.0, "profession_level": 8 }
}

const IMPROVEMENT_DEFINITIONS: Dictionary = {
	"storage_vault": { "max_level": 3, "cost": 150, "name": "Storage Vault", "description": "Increases warehouse storage by +4 slots per level." },
	"deep_shelving": { "max_level": 3, "cost": 100, "name": "Deep Shelving", "description": "Increases item stack limits by +5 per level." },
	"extra_workbench": { "max_level": 2, "cost": 100, "name": "Extra Workbench", "description": "Allows +1 concurrent crafting worker per level." },
	"bunkhouse": { "max_level": 2, "cost": 100, "name": "Bunkhouse", "description": "Increases max hired worker cap by +1 slot per level." },
	"iron_reinforcements": { "max_level": 3, "cost": 300, "name": "Iron Reinforcements", "description": "Adds rogue/sabotage protection (+15% success penalty)." },
	"ornate_facade": { "max_level": 3, "cost": 150, "name": "Ornate Facade", "description": "Boosts building attractiveness by +5 rating per level." },
	"strongbox_vault": { "max_level": 3, "cost": 150, "name": "Strongbox Vault", "description": "Increases strongbox gold capacity by +1000 per level." },
	"auto_gathering": { "max_level": 1, "cost": 200, "name": "Auto Gathering", "description": "Employees gather raw materials from mega nodes when recipe inputs are missing." },
	"storefront": { "max_level": 1, "cost": 150, "name": "Stall Storefront", "description": "Unlocks the overworld retail storefront to sell goods directly to shoppers." }
}

var rogue_sabotage_penalty: float = 0.0

var hired_employees: Array = []:
	get:
		return staff_component.hired_employees if staff_component else hired_employees
	set(val):
		if staff_component:
			staff_component.hired_employees = val
		else:
			hired_employees = val

var hireable_candidates: Array = []:
	get:
		return staff_component.hireable_candidates if staff_component else hireable_candidates
	set(val):
		if staff_component:
			staff_component.hireable_candidates = val
		else:
			hireable_candidates = val

# Player manual crafting variables
@export var max_concurrent_slots: int = 3
var is_player_working_here: bool = false
var player_crafting_recipe_path: String = ""
var player_craft_timer: float = 0.0
var player_craft_total_time: float = 0.0
var player_service_slots: Array[float] = []

func is_recipe_permitted(recipe: Recipe) -> bool:
	if building_level > 1:
		return true
	if not recipe:
		return true
	if recipe.required_level == 1:
		for input_item in recipe.inputs:
			if not input_item.is_raw_material:
				return false
	var econ = get_node_or_null("/root/EconomyManager")
	if econ:
		for input_item in recipe.inputs:
			if not input_item.is_raw_material:
				var input_career = econ.get_item_career(input_item.id)
				if input_career != recipe.required_career:
					return false
	return true


# Core production stats (abandoned get/set metadata)
var daily_production: Dictionary = {}
var lifetime_production: Dictionary = {}

func clear_daily_stats() -> void:
	daily_production.clear()

func get_interaction_text(player: CharacterBody2D = null) -> String:
	var active_player = player
	if not active_player:
		active_player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
		
	if ownership_type == "Player":
		return "Manage Building"
		
	if ownership_type == "NPC":
		if active_player:
			var local_pos = to_local(active_player.global_position)
			if local_pos.x < -16.0:
				return "Buy Business"
			elif local_pos.x >= 16.0:
				return "Trade"
		return "Locked. Opponent property."
		
	if ownership_type == "Public":
		if active_player:
			var local_pos = to_local(active_player.global_position)
			if local_pos.x < -16.0:
				return "Buy Business"
			elif local_pos.x >= 16.0:
				return "Trade"
		return "Trade"
		
	return "Locked"

func interact(player: CharacterBody2D) -> void:
	var local_pos = to_local(player.global_position)
	
	if ownership_type == "Player":
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if not hud:
			hud = get_tree().get_first_node_in_group("game_hud")
		if hud and hud.has_method("open_building_ui"):
			hud.open_building_ui(self)
		return
		
	if ownership_type == "NPC" or ownership_type == "Public":
		if local_pos.x < -16.0:
			player.try_buy_workstation()
		elif local_pos.x >= 16.0:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = get_tree().get_first_node_in_group("game_hud")
			if hud and hud.has_method("open_market"):
				hud.open_market(self)

func _populate_npc_stall_stock() -> void:
	if ownership_type != "NPC" or owner_id == "Rival":
		return
		
	var bench = get_node_or_null("CraftingBench")
	if not bench and is_instance_valid(instanced_interior):
		bench = instanced_interior.get_node_or_null("CraftingBench")
	if bench and "recipes" in bench:
		for recipe in bench.recipes:
			if recipe and recipe.output_item and inventory:
				inventory.add_item(recipe.output_item, 20)

func get_shop_attractiveness() -> int:
	if ownership_type == "Public":
		return 35
	var facade_bonus = improvements.get("ornate_facade", 0) * 5 if typeof(improvements) == TYPE_DICTIONARY else 0
	var base = attractiveness + facade_bonus
	var has_event_hall = false
	for hall in get_tree().get_nodes_in_group("EventHalls"):
		if is_instance_valid(hall) and hall.ownership_type == "Player":
			has_event_hall = true
			break
	if has_event_hall:
		base = int(base * 1.05)
		
	# Apply local tax delinquency penalty (-20% attractiveness)
	var pm = get_node_or_null("/root/PoliticsManager")
	var prov = GameState.get_province_of_node(self) if GameState else ""
	if pm and prov != "":
		var faction = "Player" if ownership_type == "Player" else ("Rival" if ownership_type == "NPC" and owner_id == "Rival" else "")
		if faction != "" and pm.is_faction_delinquent(faction, prov):
			base = int(base * 0.80)
			
	return clamp(base + temp_attractiveness_modifier, 10, 100)

func recalculate_attractiveness() -> void:
	for ui in get_tree().get_nodes_in_group("BuildingUIs"):
		if ui.visible and ui.get("_building") == self:
			if ui.has_method("refresh"):
				ui.call_deferred("refresh")

func _on_law_changed(prov: String, law_id: String, is_active: bool) -> void:
	if not is_active:
		return
	var b_prov = GameState.get_province_of_node(self) if GameState else ""
	if b_prov != prov:
		return
		
	for emp in hired_employees:
		var node_path = str(emp.get("active_gathering_node_path", ""))
		if node_path != "":
			var node = get_node_or_null(node_path)
			if is_instance_valid(node):
				if law_id == "crown_forestry_protection" and node.resource_type_id == "standard_timber":
					if staff_component: staff_component.cancel_employee_gathering(emp, "Forestry Protection Act")
				elif law_id == "noble_game_preservation" and node.resource_type_id == "venison":
					if staff_component: staff_component.cancel_employee_gathering(emp, "Game Preservation Act")
					
	if law_id == "metallurgical_monopoly" and is_in_group("Smelters"):
		var sett = GameState.get_nearest_settlement(self)
		if sett and not sett.is_in_group("Cities"):
			if staff_component: staff_component.cancel_all_smelting_recipes("Metallurgical Monopoly")

func get_single_buy_price(item: ItemData, temp_stock: int) -> int:
	var base_val: int = item.base_value
	var target: float = target_stock.get(item, 10)
	
	# Scale target stock based on settlement prosperity level
	var settlement = GameState.get_nearest_settlement(self) if GameState else null
	if settlement and "prosperity_level" in settlement:
		var p_lvl = settlement.prosperity_level
		target *= (1.0 + (p_lvl - 1) * 0.5)
		
	if target <= 0.0: target = 10.0
	var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
	multiplier = clamp(multiplier, 0.2, 3.0)
	
	var price = 0.0
	if ownership_type == "Public":
		price = base_val * multiplier
	else:
		price = base_val * multiplier * 1.1
		
	# Apply Hospitality Excise Tax (+40% surcharge)
	var pm = get_node_or_null("/root/PoliticsManager")
	var prov = GameState.get_province_of_node(self) if GameState else ""
	if pm and prov != "":
		if pm.is_law_active("hospitality_excise_tax", prov):
			if is_in_group("Inns") or is_in_group("Taverns"):
				price *= 1.40
				
	return int(price)

func get_buy_price(item: ItemData, ignore_tariffs: bool = false) -> int:
	if custom_prices.has(item.id):
		return custom_prices[item.id]
	var current_stock: int = inventory.get_item_amount(item.id)
	return get_single_buy_price(item, current_stock)

func get_sell_price(item: ItemData) -> int:
	if custom_prices.has(item.id):
		return int(custom_prices[item.id] * 0.8)
		
	var base_val: int = item.base_value
	var current_stock: int = inventory.get_item_amount(item.id)
	var target: float = target_stock.get(item, 10)
	
	# Scale target stock based on settlement prosperity level
	var settlement = GameState.get_nearest_settlement(self) if GameState else null
	if settlement and "prosperity_level" in settlement:
		var p_lvl = settlement.prosperity_level
		target *= (1.0 + (p_lvl - 1) * 0.5)
		
	if target <= 0.0:
		target = 10.0
		
	var multiplier: float = 1.0 + (float(target - current_stock) / target) * sensitivity
	multiplier = clamp(multiplier, 0.2, 3.0)
	
	return int(base_val * multiplier * 0.9)

func get_single_sell_price(item: ItemData, temp_stock: int) -> int:
	if custom_prices.has(item.id):
		return int(custom_prices[item.id] * 0.8)
		
	var base_val: int = item.base_value
	var target: float = target_stock.get(item, 10)
	
	# Scale target stock based on settlement prosperity level
	var settlement = GameState.get_nearest_settlement(self) if GameState else null
	if settlement and "prosperity_level" in settlement:
		var p_lvl = settlement.prosperity_level
		target *= (1.0 + (p_lvl - 1) * 0.5)
		
	if target <= 0.0:
		target = 10.0
		
	var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
	multiplier = clamp(multiplier, 0.2, 3.0)
	
	return int(base_val * multiplier * 0.9)

func buy_item(item: ItemData, amount: int) -> bool:
	var current_stock: int = inventory.get_item_amount(item.id)
	if current_stock < amount:
		return false
		
	if ownership_type == "Player":
		var remainder: int = GameState.player_inventory.add_item(item, amount)
		if remainder > 0:
			var accepted: int = amount - remainder
			if accepted <= 0:
				return false
			inventory.remove_item(item.id, accepted)
		else:
			inventory.remove_item(item.id, amount)
		return true
		
	var unit_price: int = get_buy_price(item)
	var total_price: int = unit_price * amount
		
	if GameState.gold < total_price:
		return false
		
	var remainder: int = GameState.player_inventory.add_item(item, amount)
	if remainder > 0:
		var accepted: int = amount - remainder
		if accepted <= 0:
			return false
			
		total_price = unit_price * accepted
		
		# Set change attribution
		GameState.next_change_reason = "Shop Purchase"
		GameState.next_change_detail = item.name
		GameState.gold -= total_price
		inventory.remove_item(item.id, accepted)
	else:
		# Set change attribution
		GameState.next_change_reason = "Shop Purchase"
		GameState.next_change_detail = item.name
		GameState.gold -= total_price
		inventory.remove_item(item.id, amount)
		
	if ownership_type == "NPC" and owner_id == "Rival":
		var rivals = get_tree().get_nodes_in_group("Rivals")
		if rivals.size() > 0:
			rivals[0].gold += total_price
		
	return true

func sell_item(item: ItemData, amount: int) -> bool:
	var player_stock: int = GameState.player_inventory.get_item_amount(item.id)
	if player_stock < amount:
		return false
		
	if ownership_type == "Player":
		var remainder: int = inventory.add_item(item, amount)
		if remainder > 0:
			var accepted: int = amount - remainder
			if accepted <= 0:
				return false
			GameState.player_inventory.remove_item(item.id, accepted)
		else:
			GameState.player_inventory.remove_item(item.id, amount)
		return true
		
	var unit_price: int = get_sell_price(item)
	var total_revenue: int = unit_price * amount
		
	var remainder: int = inventory.add_item(item, amount)
	if remainder > 0:
		var accepted: int = amount - remainder
		if accepted <= 0:
			return false
			
		total_revenue = unit_price * accepted
			
		if ownership_type == "NPC" and owner_id == "Rival":
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				if rivals[0].gold < total_revenue:
					inventory.remove_item(item.id, accepted)
					return false
				rivals[0].gold -= total_revenue
			
		# Set change attribution
		GameState.next_change_reason = "Shop Sales"
		GameState.next_change_detail = item.name
		GameState.gold += total_revenue
		GameState.player_inventory.remove_item(item.id, accepted)
	else:
		if ownership_type == "NPC" and owner_id == "Rival":
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				if rivals[0].gold < total_revenue:
					inventory.remove_item(item.id, amount)
					return false
				rivals[0].gold -= total_revenue
				
		# Set change attribution
		GameState.next_change_reason = "Shop Sales"
		GameState.next_change_detail = item.name
		GameState.gold += total_revenue
		GameState.player_inventory.remove_item(item.id, amount)
		
	return true

func get_interaction_position() -> Vector2:
	var marker = get_node_or_null("EntranceMarker")
	if marker:
		return marker.global_position
	return global_position + Vector2(8, 52)

func _setup_shared_inventory() -> void:
	var inv_script = load("res://components/inventory/inventory_component.gd")
	# Stall Storage: max 4 slots
	inventory = inv_script.new()
	inventory.name = "StallInventory"
	inventory.max_slots = 4
	inventory.max_stack = 20
	inventory.max_weight = 100.0
	add_child(inventory)

	# Building Storage: max 8 slots
	building_storage = inv_script.new()
	building_storage.name = "BuildingStorage"
	building_storage.max_slots = 8
	building_storage.max_stack = 20
	building_storage.max_weight = 100.0
	add_child(building_storage)

func _create_dynamic_door() -> void:
	col_door = CollisionShape2D.new()
	col_door.name = "ColDoor"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 16)
	col_door.shape = shape
	if has_meta("blueprint_door_pos"):
		col_door.global_position = get_meta("blueprint_door_pos")
	else:
		col_door.position = Vector2(0, 32)
	add_child(col_door)

func _create_entry_door() -> void:
	entry_door = Area2D.new()
	entry_door.name = "EntryDoorTrigger"
	entry_door.set_script(load("res://components/teleport/teleport_trigger.gd"))
	if has_meta("blueprint_door_pos"):
		entry_door.global_position = get_meta("blueprint_door_pos")
	else:
		entry_door.position = Vector2(0, 32)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 16)
	col.shape = shape
	entry_door.add_child(col)
	
	add_child(entry_door)
	
	entry_door.is_local_teleport = true
	entry_door.ownership_type = ownership_type
	entry_door.owner_id = owner_id
	entry_door.is_buyable = false
	
	if instanced_interior:
		entry_door.target_room_node = instanced_interior
		entry_door.target_spawn_position = interior_position + Vector2(128, 200)
	else:
		entry_door.target_spawn_position = interior_position + Vector2(128, 200)

func _update_door_state() -> void:
	if col_door:
		var should_lock = false
		if ownership_type == "NPC":
			should_lock = true
		col_door.disabled = not should_lock
	if entry_door:
		entry_door.ownership_type = ownership_type
		entry_door.owner_id = owner_id
		if entry_door.has_method("_update_door_state"):
			entry_door._update_door_state()
	if instanced_interior and instanced_interior.exit_door:
		instanced_interior.exit_door.ownership_type = ownership_type
		instanced_interior.exit_door.owner_id = owner_id
		if instanced_interior.exit_door.has_method("_update_door_state"):
			instanced_interior.exit_door._update_door_state()

func _ready_base() -> void:
	var init_lvl = building_level
	var init_employees = hired_employees
	var init_candidates = hireable_candidates
	var init_improvements = improvements
	var init_upgrading = is_upgrading
	var init_timer = upgrade_timer

	# Instantiate components
	var upgrade_comp_script = load("res://components/production/BuildingUpgradeComponent.gd")
	if upgrade_comp_script:
		upgrade_component = upgrade_comp_script.new()
		upgrade_component.name = "BuildingUpgradeComponent"
		add_child(upgrade_component)
		upgrade_component.setup(self)

	var staff_comp_script = load("res://components/production/BuildingStaffComponent.gd")
	if staff_comp_script:
		staff_component = staff_comp_script.new()
		staff_component.name = "BuildingStaffComponent"
		add_child(staff_component)
		staff_component.setup(self)

	# Push initial values to components
	building_level = init_lvl
	hired_employees = init_employees
	hireable_candidates = init_candidates
	improvements = init_improvements
	is_upgrading = init_upgrading
	upgrade_timer = init_timer

	GameState.ensure_strongbox(self)
	if not building_data:
		building_data = GameState.get_building_data_for_node(self)
	if building_data:
		if "attractiveness" in building_data:
			attractiveness = building_data.attractiveness
		if "building_level" in building_data:
			building_level = building_data.building_level
		
	# Register to the master production buildings group
	add_to_group("production_buildings")
	
	var pm = get_node_or_null("/root/PoliticsManager")
	if pm:
		pm.law_changed.connect(_on_law_changed)
	
	call_deferred("_populate_npc_stall_stock")
	
	var footprint = get_node_or_null("CollisionShape2D")
	if footprint:
		footprint.disabled = true
		
	if has_meta("is_teleport_only") and get_meta("is_teleport_only") == true:
		if fade_trigger:
			fade_trigger.queue_free()
			fade_trigger = null
		
	if fade_trigger:
		if not fade_trigger.body_entered.is_connected(_on_fade_body_entered):
			fade_trigger.body_entered.connect(_on_fade_body_entered)
		if not fade_trigger.body_exited.is_connected(_on_fade_body_exited):
			fade_trigger.body_exited.connect(_on_fade_body_exited)
		
	_setup_shared_inventory()
	
	var building_id = "bld_%s_%d_%d" % [name.to_lower(), int(global_position.x), int(global_position.y)]
	interior_position = GameState.allocate_interior_space(building_id)
	
	var template_node = null
	if building_data and building_data.career == "patreon":
		var scene_root = get_tree().current_scene if get_tree().current_scene else get_tree().root
		template_node = scene_root.find_child("Tmp_Flour_Mill_lvl1", true, false)
		if not template_node:
			template_node = get_tree().root.find_child("Tmp_Flour_Mill_lvl1", true, false)
			
	if template_node:
		instanced_interior = template_node.duplicate()
		instanced_interior.name = "Interior_" + name + "_" + str(int(global_position.x))
		instanced_interior.set_script(load("res://components/buildings/interior_template.gd"))
		instanced_interior.global_position = interior_position
		var parent_scene = get_tree().current_scene if get_tree().current_scene else get_tree().root
		parent_scene.call_deferred("add_child", instanced_interior)
		
		var exit_spawn_pos = global_position + Vector2(0, 64)
		instanced_interior.call_deferred("setup_interior", self, exit_spawn_pos)
	else:
		var interior_scene = load("res://components/buildings/interior_template.tscn")
		if interior_scene:
			instanced_interior = interior_scene.instantiate() as Node
			instanced_interior.name = "Interior_" + name + "_" + str(int(global_position.x))
			instanced_interior.global_position = interior_position
			var parent_scene = get_tree().current_scene if get_tree().current_scene else get_tree().root
			parent_scene.call_deferred("add_child", instanced_interior)
			
			var exit_spawn_pos = global_position + Vector2(0, 64)
			instanced_interior.call_deferred("setup_interior", self, exit_spawn_pos)

	_create_dynamic_door()
	_create_entry_door()
	_update_door_state()
	if upgrade_component:
		if not upgrade_component.improvement_purchased.is_connected(_on_improvement_purchased):
			upgrade_component.improvement_purchased.connect(_on_improvement_purchased)
	update_storefront_stall_state()
	recalculate_building_parameters()

func _on_fade_body_entered(body: Node2D) -> void:
	if (body.is_in_group("Player") or body.is_in_group("Rivals")) and exterior:
		create_tween().tween_property(exterior, "modulate:a", 0.0, 0.25)

func _on_fade_body_exited(body: Node2D) -> void:
	if (body.is_in_group("Player") or body.is_in_group("Rivals")):
		if fade_trigger:
			for b in fade_trigger.get_overlapping_bodies():
				if b.is_in_group("Player") or b.is_in_group("Rivals"):
					return
		if exterior:
			create_tween().tween_property(exterior, "modulate:a", 1.0, 0.25)

func _on_front_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_front_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

func get_employee_craft_time(emp: Dictionary, recipe: Resource) -> float:
	if staff_component:
		return staff_component.get_employee_craft_time(emp, recipe)
	return recipe.get_base_craft_time()

func start_player_crafting(recipe_path: String) -> void:
	if is_under_audit:
		if GameState:
			GameState.spawn_ui_floating_text("Cannot craft: Building is under audit!")
		return
		
	var recipe = load(recipe_path)
	if not recipe:
		return
		
	if not recipe.is_service and not is_recipe_permitted(recipe):
		if GameState:
			GameState.spawn_ui_floating_text("Cross-class/refinement requires building level 2!")
		return
		
	if recipe.get("is_service") == true:
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			var bench_pos = global_position # Fallback
			if is_instance_valid(instanced_interior) and is_instance_valid(instanced_interior.crafting_bench):
				bench_pos = instanced_interior.crafting_bench.global_position
			TransitionScreen.transition_teleport(bench_pos)
			player.freeze()
			if player.has_method("spawn_floating_text"):
				player.spawn_floating_text("Offering Service")
				
		is_player_working_here = true
		player_crafting_recipe_path = recipe_path
		player_craft_timer = 0.0
		player_craft_total_time = 0.0
		player_service_slots.clear()
		
		# Close the UI!
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if not hud:
			hud = get_tree().get_first_node_in_group("game_hud")
		if hud and hud.has_method("close_building_ui"):
			hud.close_building_ui()
		return
		
	# Check Metallurgical Monopoly (smelting outside city walls)
	var pm = get_node_or_null("/root/PoliticsManager")
	var b_prov = GameState.get_province_of_node(self) if GameState else ""
	if pm and b_prov != "":
		if pm.is_law_active("metallurgical_monopoly", b_prov) and is_in_group("Smelters"):
			var sett = GameState.get_nearest_settlement(self)
			if sett and not sett.is_in_group("Cities"):
				if GameState:
					GameState.spawn_ui_floating_text("Illegal! Smelting outside city walls is banned in this province.")
				return
		
	# Check concurrent crafting workbench limit
	var active_crafters = 0
	for emp in hired_employees:
		if emp.get("active_recipe_path", "") != "":
			active_crafters += 1
	var limit = 1 + (improvements.get("extra_workbench", 0) if typeof(improvements) == TYPE_DICTIONARY else 0)
	if active_crafters >= limit:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if not hud:
			hud = get_tree().get_first_node_in_group("game_hud")
		if hud:
			hud._spawn_floating_text("All crafting benches are occupied!", global_position)
		return
		
	var target_b_storage = building_storage if building_storage else inventory
	if not target_b_storage:
		return
		
	# Verify inputs first
	var inputs_ok = true
	for item in recipe.inputs:
		var qty = recipe.inputs[item]
		if target_b_storage.get_item_amount(item.id) < qty:
			inputs_ok = false
			break
			
	if not inputs_ok:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if not hud:
			hud = get_tree().get_first_node_in_group("game_hud")
		if hud:
			hud._spawn_floating_text("Not enough inputs in building storage!", global_position)
		return
		
	# Consume ingredients
	for item in recipe.inputs:
		var qty = recipe.inputs[item]
		target_b_storage.remove_item(item.id, qty)
		
	# Teleport player to the bench and freeze them
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var bench_pos = global_position # Fallback
		if is_instance_valid(instanced_interior) and is_instance_valid(instanced_interior.crafting_bench):
			bench_pos = instanced_interior.crafting_bench.global_position
		TransitionScreen.transition_teleport(bench_pos)
		player.freeze()
		if player.has_method("spawn_floating_text"):
			player.spawn_floating_text("Started Crafting")
			
	# Calculate craft time based on player productivity level
	var level = GameState.career_levels.get(recipe.required_career, 1) if GameState else 1
	var craft_time = recipe.get_base_craft_time()
	var prod = player.get("productivity") if player else 1.0
	if prod > 0.0:
		craft_time /= prod
		
	# Level 8 Trait: Artisan's Efficiency
	if level >= 8 and recipe.output_item and recipe.output_item.get("is_luxury_product") == true:
		craft_time *= 0.85
		
	# Apply local law and delinquency modifiers to player
	if pm and b_prov != "":
		if pm.is_faction_delinquent("Player", b_prov):
			craft_time *= 1.25
		if pm.is_law_active("labor_welfare_mandate", b_prov):
			craft_time *= 1.176
			
	if GameState:
		craft_time = GameState.apply_macro_modifier(self, "crafting_time", craft_time)
			
	is_player_working_here = true
	player_crafting_recipe_path = recipe_path
	player_craft_timer = craft_time
	player_craft_total_time = craft_time
	
	# Close the UI!
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud and hud.has_method("close_building_ui"):
		hud.close_building_ui()

func stop_player_crafting() -> void:
	is_player_working_here = false
	player_crafting_recipe_path = ""
	player_craft_timer = 0.0
	player_craft_total_time = 0.0
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.unfreeze()
		if player.has_method("spawn_floating_text"):
			player.spawn_floating_text("Stopped Crafting")
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if not hud:
			hud = get_tree().get_first_node_in_group("game_hud")
		if hud and hud.has_method("update_interaction_prompt"):
			hud.update_interaction_prompt()

func recalculate_building_parameters() -> void:
	if building_storage:
		building_storage.max_slots = 8 + (improvements.get("storage_vault", 0) * 4)
		building_storage.max_stack = 20 + (improvements.get("deep_shelving", 0) * 5)
	var sbox = get_node_or_null("StrongboxComponent")
	if sbox:
		sbox.set("max_slots", 10 + (improvements.get("storage_vault", 0) * 4))
		if "max_gold_capacity" in sbox:
			sbox.max_gold_capacity = 1500 + (improvements.get("strongbox_vault", 0) * 1000)
	rogue_sabotage_penalty = improvements.get("iron_reinforcements", 0) * 0.15

func reset_all_workers() -> void:
	if is_player_working_here:
		stop_player_crafting()
	for emp in hired_employees:
		emp["active_recipe_path"] = ""
		emp["active_gathering_node_path"] = ""
		emp["shift_status"] = "idle"
		emp["craft_timer"] = 0.0
		emp["craft_total_time"] = 0.0
		var worker = emp.get("shift_worker_ref")
		if is_instance_valid(worker):
			if worker.get("is_gathering"):
				worker.set("is_gathering", false)
				if is_instance_valid(worker.get("target_mega_node")):
					worker.target_mega_node._on_body_exited(worker)
			worker.set("worker_state", "idle_at_workshop")
			var target_pos = get_interaction_position()
			if worker.has_method("_generate_path"):
				worker.call("_generate_path", target_pos)
			emp["shift_worker_ref"] = null
		var npc = emp.get("npc_ref")
		if is_instance_valid(npc):
			npc.set("worker_state", "idle_at_workshop")
			var target_pos = get_interaction_position()
			if npc.has_method("_generate_path"):
				npc.call("_generate_path", target_pos)

func get_nearest_mega_node_for_resource(resource_id: String) -> Area2D:
	var nodes = get_tree().get_nodes_in_group("MegaNodes")
	var nearest_node: Area2D = null
	var min_dist = INF
	for node in nodes:
		if is_instance_valid(node) and node.resource_type_id == resource_id:
			var dist = global_position.distance_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_node = node
	return nearest_node

func initiate_level_upgrade() -> void:
	if upgrade_component:
		upgrade_component.initiate_level_upgrade()

func purchase_improvement(improvement_id: String) -> void:
	if upgrade_component:
		upgrade_component.purchase_improvement(improvement_id)

func _tick_employees(delta: float) -> void:
	if is_under_audit:
		if is_player_working_here:
			stop_player_crafting()
		return
		
	if ownership_type != "Player" and ownership_type != "NPC" and ownership_type != "Rented":
		return
		
	if upgrade_component:
		upgrade_component.tick_upgrade(delta)
		
	_tick_player_crafting(delta)
	
	if staff_component:
		staff_component.tick_employees(delta)

func _tick_player_crafting(delta: float) -> void:
	# Process player manual crafting if active
	if is_player_working_here and player_crafting_recipe_path != "":
		var recipe = load(player_crafting_recipe_path)
		if recipe and recipe.get("is_service") == true:
			player_craft_timer += delta # Track elapsed time for service
			var new_slots: Array[float] = []
			for cooldown in player_service_slots:
				var next_cd = cooldown - delta
				if next_cd > 0.0:
					new_slots.append(next_cd)
			player_service_slots = new_slots
			
			# Prevent immediate propagation cancel on the starting frame
			if player_craft_timer > 0.1 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel")):
				stop_player_crafting()
			return
			
		# Prevent immediate propagation cancel on the starting frame
		var elapsed = player_craft_total_time - player_craft_timer
		if elapsed > 0.1 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel")):
			recipe = load(player_crafting_recipe_path)
			if recipe:
				var target_b_storage = building_storage if building_storage else inventory
				if target_b_storage:
					for item in recipe.inputs:
						target_b_storage.add_item(item, recipe.inputs[item])
			stop_player_crafting()
			return
			
		player_craft_timer -= delta
		if player_craft_timer <= 0.0:
			if recipe:
				if recipe.is_event:
					_resolve_completed_event(recipe)
					GameState.add_xp(recipe.required_career, recipe.xp_reward)
					stop_player_crafting()
					return
				var out_item = recipe.output_item
				var out_qty = recipe.output_amount
				var target_b_storage = building_storage if building_storage else inventory
				var level = GameState.career_levels.get(recipe.required_career, 1)
				var double_harvest_triggered = false
				if level >= 8:
					if randf() <= 0.35:
						out_qty *= 2
						double_harvest_triggered = true
				elif level >= 5:
					if randf() <= 0.20:
						out_qty *= 2
						double_harvest_triggered = true
						
				var player = get_tree().get_first_node_in_group("Player")
				var miracle_artisan_triggered = false
				if player and "character_resource" in player and player.character_resource != null:
					var ma_lvl = 0
					for trait_id in player.character_resource.active_mods:
						if trait_id.begins_with("Miracle Artisan_Lvl"):
							ma_lvl = int(trait_id.replace("Miracle Artisan_Lvl", ""))
							break
					if ma_lvl > 0:
						var ma_chance = 0.0
						if ma_lvl == 1: ma_chance = 0.03
						elif ma_lvl == 2: ma_chance = 0.07
						elif ma_lvl == 3: ma_chance = 0.15
						
						if randf() <= ma_chance:
							out_qty *= 2
							miracle_artisan_triggered = true
							
				var artisan_efficiency_triggered = level >= 8 and out_item.get("is_luxury_product") == true
					
				if target_b_storage and target_b_storage.get_free_space_for_item(out_item) >= out_qty:
					target_b_storage.add_item(out_item, out_qty)
					
					var hud = get_tree().get_first_node_in_group("PlayerHUD")
					if not hud:
						hud = get_tree().get_first_node_in_group("game_hud")
					if hud and hud.has_method("_spawn_floating_text"):
						if double_harvest_triggered:
							hud._spawn_floating_text("Double Harvest!", global_position)
						if miracle_artisan_triggered:
							hud._spawn_floating_text("Miracle Artisan!", global_position)
						if artisan_efficiency_triggered:
							hud._spawn_floating_text("Masterwork Efficiency!", global_position)
							
					lifetime_production[out_item.id] = lifetime_production.get(out_item.id, 0) + out_qty
					daily_production[out_item.id] = daily_production.get(out_item.id, 0) + out_qty
					
					var b_prov = GameState.get_province_of_node(self) if GameState else ""
					var gc = get_node_or_null("/root/GuildController")
					if gc and b_prov != "":
						var holder = gc.call("get_office_holder", b_prov, "Materials Steward")
						if holder != "" and holder == "Player" and randf() < 0.10:
							for item in recipe.inputs:
								if item.get_item_category() == 0 or item.get_item_category() == 1:
									target_b_storage.add_item(item, recipe.inputs[item])
							if GameState:
								GameState.spawn_ui_floating_text("Materials Refunded! (Materials Steward)")
									
					if recipe.get("is_breakthrough_only") == true:
						var fee = recipe.get_meta("gold_fee")
						if fee == null: fee = 100
						GameState.gold = max(0, GameState.gold - fee)
						var is_p = recipe.get_meta("is_player")
						var char_n = recipe.get_meta("character_name")
						var car = recipe.get_meta("career")
						var locked_lvl = recipe.get_meta("level") or 3
						
						if is_p:
							GameState.career_levels[car] = locked_lvl + 1
							GameState._on_career_leveled_up(car, locked_lvl + 1)
						else:
							for building in get_tree().get_nodes_in_group("production_buildings"):
								if building.ownership_type == "Player":
									for emp in building.hired_employees:
										var npc = emp.get("npc_ref")
										if is_instance_valid(npc) and npc.npc_name == char_n:
											npc.skills_data[car]["level"] = locked_lvl + 1
											break
											
						GameState.active_trial_recipes.erase(player_crafting_recipe_path)
						var dir = DirAccess.open(player_crafting_recipe_path.get_base_dir())
						if dir:
							dir.remove(player_crafting_recipe_path.get_file())
							
						GameState.spawn_ui_floating_text("Breakthrough Successful! Level up to %d!" % (locked_lvl + 1))
						stop_player_crafting()
						return
						
					GameState.add_xp(recipe.required_career, recipe.xp_reward)
					
					var inputs_ok = true
					for item in recipe.inputs:
						if target_b_storage.get_item_amount(item.id) < recipe.inputs[item]:
							inputs_ok = false
							break
							
					var next_has_space = target_b_storage.get_free_space_for_item(out_item) >= out_qty
					
					if inputs_ok and next_has_space:
						for item in recipe.inputs:
							target_b_storage.remove_item(item.id, recipe.inputs[item])
						player = get_tree().get_first_node_in_group("Player")
						var craft_time = recipe.get_base_craft_time()
						var prod = player.get("productivity") if player else 1.0
						if prod > 0.0:
							craft_time /= prod
						if level >= 8 and recipe.output_item and recipe.output_item.get("is_luxury_product") == true:
							craft_time *= 0.85
							
						var pm = get_node_or_null("/root/PoliticsManager")
						if pm and b_prov != "":
							if pm.is_faction_delinquent("Player", b_prov):
								craft_time *= 1.25
							if pm.is_law_active("labor_welfare_mandate", b_prov):
								craft_time *= 1.176
								
						if GameState:
							craft_time = GameState.apply_macro_modifier(self, "crafting_time", craft_time)
								
						player_craft_timer = craft_time
						player_craft_total_time = craft_time
					else:
						stop_player_crafting()
						if not inputs_ok:
							GameState.spawn_ui_floating_text("Crafting halted: Insufficient materials!")
						else:
							GameState.spawn_ui_floating_text("Crafting halted: Storage full!")
				else:
					stop_player_crafting()
					GameState.spawn_ui_floating_text("Crafting halted: Storage full!")

func _populate_candidates() -> void:
	if staff_component:
		staff_component.populate_candidates()

func ensure_spouse_candidate() -> void:
	if staff_component:
		staff_component.ensure_spouse_candidate()

func produces_using_only_raw_materials() -> bool:
	var bench = get_node_or_null("CraftingBench")
	if not bench and is_instance_valid(instanced_interior):
		bench = instanced_interior.get_node_or_null("CraftingBench")
	if not bench or not ("recipes" in bench) or bench.recipes.is_empty():
		return false
	for recipe in bench.recipes:
		if not recipe:
			continue
		for input in recipe.inputs:
			if not input.is_raw_material:
				return false
	return true

func get_active_service_provider(service_recipe_path: String) -> Dictionary:
	if is_player_working_here and player_crafting_recipe_path == service_recipe_path:
		var required_career = ""
		var recipe = load(service_recipe_path)
		if recipe:
			required_career = recipe.required_career
		var level = GameState.career_levels.get(required_career, 1) if required_career != "" else 1
		return {"offered": true, "level": level, "is_player": true}
		
	for emp in hired_employees:
		if emp.get("active_recipe_path", "") == service_recipe_path:
			var level = 1
			var npc = emp.get("npc_ref")
			if is_instance_valid(npc) and npc.get("skills_data"):
				var recipe = load(service_recipe_path)
				var car = recipe.required_career if recipe else "patreon"
				if npc.skills_data.has(car):
					level = npc.skills_data[car].get("level", 1)
			return {"offered": true, "level": level, "is_player": false, "employee": emp}
			
	return {"offered": false, "level": 1, "is_player": false}

func get_any_active_service_provider() -> Dictionary:
	var bench = get_node_or_null("CraftingBench")
	if not bench and is_instance_valid(instanced_interior):
		bench = instanced_interior.get_node_or_null("CraftingBench")
	if bench and "recipes" in bench:
		for recipe in bench.recipes:
			if recipe and recipe.get("is_service") == true:
				var provider = get_active_service_provider(recipe.resource_path)
				if provider["offered"]:
					var slots = player_service_slots if provider["is_player"] else provider["employee"].get("service_slots", [])
					if slots.size() < max_concurrent_slots:
						provider["recipe"] = recipe
						return provider
	return {"offered": false, "level": 1, "is_player": false, "recipe": null}

func get_service_price(recipe: Recipe) -> int:
	if not recipe:
		return 20
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var econ = main_loop.root.get_node_or_null("EconomyManager")
		if econ and econ.has_method("get_algorithmic_craft_time"):
			var duration = econ.get_algorithmic_craft_time(recipe)
			var career = recipe.required_career
			var type = econ.CAREER_TO_PROFESSION.get(career, econ.ProfessionType.PATREON)
			var profile = econ.PROFESSION_PROFILES[type]
			var base_service_fee = (duration * profile.labor_base) * profile.scalar * 1.5
			return int(round(base_service_fee))
	return 20

func update_storefront_stall_state() -> void:
	var spawn_pos = Vector2.ZERO
	if has_meta("stall_spawn_pos"):
		spawn_pos = get_meta("stall_spawn_pos") as Vector2
	else:
		var anchor = get_node_or_null("Stall_Anchor")
		if anchor:
			spawn_pos = anchor.global_position
		else:
			spawn_pos = global_position + Vector2(32, 16)
			
	var should_have_stall = false
	if ownership_type == "Player" or ownership_type == "NPC":
		should_have_stall = improvements.get("storefront", 0) > 0
	else:
		should_have_stall = true
		
	var current_stall_exists = is_instance_valid(storefront_stall) and storefront_stall != self
	
	if should_have_stall:
		if not current_stall_exists:
			var stall_scene = load("res://components/market/market_stall.tscn")
			if stall_scene:
				var stall = stall_scene.instantiate() as MarketStall
				get_parent().add_child(stall)
				stall.global_position = spawn_pos
				if stall.has_node("CollisionShape2D"):
					var col = stall.get_node("CollisionShape2D") as CollisionShape2D
					if col:
						col.disabled = true
				stall.collision_layer = 0
				stall.collision_mask = 0
				stall.ownership_type = ownership_type
				stall.owner_id = owner_id
				stall.inventory = inventory
				stall.parent_building = self
				storefront_stall = stall
				print("[Building] Instantiated storefront stall at ", spawn_pos, " for ", name)
	else:
		if current_stall_exists:
			print("[Building] Removing storefront stall for ", name)
			storefront_stall.queue_free()
			storefront_stall = self

func _on_improvement_purchased(improvement_id: String, _new_level: int) -> void:
	if improvement_id == "storefront":
		update_storefront_stall_state()

func _resolve_completed_event(recipe: Resource) -> void:
	if not recipe or not recipe.is_event:
		return
		
	var consumed_items: Array = []
	for input in recipe.inputs:
		var qty = recipe.inputs[input]
		for j in range(qty):
			consumed_items.append(input)
			
	var econ = get_node_or_null("/root/EconomyManager")
	if not econ:
		return
		
	var sbox = get_node_or_null("StrongboxComponent")
	if not sbox:
		return
		
	var base_influence: int = 15
	var base_prestige: int = 30
	
	var r_name = recipe.resource_path.get_file().replace(".tres", "")
	match r_name:
		"contract_bridge_reconstruction":
			base_influence = 30
			base_prestige = 60
		"contract_palace_remodeling":
			base_influence = 50
			base_prestige = 100
		"contract_crop_blight":
			base_influence = 50
			base_prestige = 100
		"contract_treat_archduke":
			base_influence = 75
			base_prestige = 150
		"contract_ballista_fleet":
			base_influence = 25
			base_prestige = 50
		"contract_honor_guard":
			base_influence = 40
			base_prestige = 80
		"noble_event":
			base_influence = 15
			base_prestige = 30
		"royal_event":
			base_influence = 30
			base_prestige = 60
		_:
			base_influence = recipe.required_level * 5
			base_prestige = recipe.required_level * 10
			
	var contract_data: Dictionary = {
		"influence": base_influence,
		"prestige": base_prestige
	}
	
	var resolution: Dictionary = econ.resolve_grand_event(consumed_items, contract_data)
	var payout: int = resolution.get("payout", 0)
	var outcome_tier: int = resolution.get("outcome_tier", 1)
	var p_mult: float = resolution.get("prestige_multiplier", 1.0)
	
	var total_influence = int(round(float(base_influence) * p_mult))
	var total_prestige = int(round(float(base_prestige) * p_mult))
	
	sbox.strongbox_gold += payout
	
	var client_type = "Guests"
	if r_name == "royal_event": client_type = "Nobles"
	elif r_name in ["contract_bridge_reconstruction", "contract_palace_remodeling"]: client_type = "Town Council"
	elif r_name in ["contract_crop_blight", "contract_treat_archduke"]: client_type = "Sanitarium Board"
	elif r_name in ["contract_ballista_fleet", "contract_honor_guard"]: client_type = "Military Guard"
	elif r_name == "engrave_central_banking_charter": client_type = "Bank Board"
	elif r_name in ["forge_extortion_mandate", "forge_regional_trade_passport"]: client_type = "Underworld Contacts"
	
	var outcome_str: String = "Regular"
	match outcome_tier:
		0: outcome_str = "Bad"
		1: outcome_str = "Regular"
		2: outcome_str = "Good"
		3: outcome_str = "Excellent"
		4: outcome_str = "Pristine"
		
	if ownership_type == "Player" or owner_id == "Player":
		GameState.influence += total_influence
		GameState.permanent_influence += total_prestige
		
	var tx_name = "%s (%s)" % [recipe.recipe_name, outcome_str]
	sbox.add_transaction(tx_name, 1, payout, TimeManager.get_time_string() if has_node("/root/TimeManager") else "", client_type)
	
	if ownership_type == "Player" or owner_id == "Player":
		GameState.spawn_ui_floating_text("+%d Gold, +%d Influence (%s: %s)" % [payout, total_influence, recipe.recipe_name, outcome_str])
	
	if outcome_tier == 0:
		var msg = "A hosted %s suffered a mishap, resulting in poor reviews and reduced payouts." % recipe.recipe_name
		AlertManager.add_alert("Grand Event Mishap!", msg, "warning", self)

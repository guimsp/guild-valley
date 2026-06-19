class_name BaseProductionBuilding
extends StaticBody2D

@export var building_data: BuildingData = null

@onready var fade_trigger: Area2D = get_node_or_null("FadeTrigger")
@onready var exterior: Control = get_node_or_null("Exterior")

@export var buy_cost: int = 250
@export var is_buyable: bool = true
@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Player"
@export var owner_id: String = "Player"

@export var custom_name: String = ""
@export var building_level: int = 1

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
var instanced_interior: Node2D = null

# --- Storefront / Merchant Interface ---
@export var market_name: String = ""
@export var sensitivity: float = 0.5
var custom_prices: Dictionary = {}
var target_stock: Dictionary = {}

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

var is_upgrading: bool = false
var upgrade_timer: float = 0.0

var improvements: Dictionary = {
	"storage_vault": 0,      # Max level 3
	"deep_shelving": 0,      # Max level 3
	"extra_workbench": 0,    # Max level 2
	"bunkhouse": 0,          # Max level 2
	"iron_reinforcements": 0,# Max level 3
	"ornate_facade": 0,      # Max level 3
	"strongbox_vault": 0,    # Max level 3
	"auto_gathering": 0      # Max level 1
}

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
	"auto_gathering": { "max_level": 1, "cost": 200, "name": "Auto Gathering", "description": "Employees gather raw materials from mega nodes when recipe inputs are missing." }
}

var rogue_sabotage_penalty: float = 0.0

var hired_employees: Array = []
var hireable_candidates: Array = []

# Player manual crafting variables
var is_player_working_here: bool = false
var player_crafting_recipe_path: String = ""
var player_craft_timer: float = 0.0
var player_craft_total_time: float = 0.0


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
	if ownership_type != "NPC":
		return
		
	var bench = get_node_or_null("CraftingBench")
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
					_cancel_employee_gathering(emp, "Forestry Protection Act")
				elif law_id == "noble_game_preservation" and node.resource_type_id == "venison":
					_cancel_employee_gathering(emp, "Game Preservation Act")
					
	if law_id == "metallurgical_monopoly" and is_in_group("Smelters"):
		var sett = GameState.get_nearest_settlement(self)
		if sett and not sett.is_in_group("Cities"):
			_cancel_all_smelting_recipes("Metallurgical Monopoly")

func _cancel_employee_gathering(emp: Dictionary, law_reason: String) -> void:
	emp["active_gathering_node_path"] = ""
	emp["shift_status"] = "idle"
	emp["is_paused"] = true
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
			
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text("%s: On Strike! (%s)" % [emp.get("name", "Worker"), law_reason], global_position)

func _cancel_all_smelting_recipes(law_reason: String) -> void:
	for emp in hired_employees:
		var recipe_path = emp.get("active_recipe_path", "")
		if recipe_path != "":
			emp["active_recipe_path"] = ""
			emp["craft_timer"] = 0.0
			emp["craft_total_time"] = 0.0
			emp["is_paused"] = true
			var worker = emp.get("npc_ref")
			if is_instance_valid(worker):
				worker.set("worker_state", "idle_at_workshop")
				var target_pos = get_interaction_position()
				if worker.has_method("_generate_path"):
					worker.call("_generate_path", target_pos)
					
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = get_tree().get_first_node_in_group("game_hud")
			if hud and hud.has_method("_spawn_floating_text"):
				hud._spawn_floating_text("%s: Smelting Banned! (%s)" % [emp.get("name", "Worker"), law_reason], global_position)

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
		
	# Apply Hospitality Excise Tax (+40% surcharge)
	var pm = get_node_or_null("/root/PoliticsManager")
	var prov = GameState.get_province_of_node(self) if GameState else ""
	if pm and prov != "":
		if pm.is_law_active("hospitality_excise_tax", prov):
			if is_in_group("Inns") or is_in_group("Taverns"):
				price *= 1.40
				
	return int(price)

func get_buy_price(item: ItemData) -> int:
	if custom_prices.has(item.id):
		return custom_prices[item.id]
	var current_stock: int = inventory.get_item_amount(item.id)
	return get_single_buy_price(item, current_stock)

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
		
	var total_price: int = 0
	var temp_stock: int = current_stock
	for i in range(amount):
		total_price += get_single_buy_price(item, temp_stock)
		temp_stock -= 1
		
	if GameState.gold < total_price:
		return false
		
	var remainder: int = GameState.player_inventory.add_item(item, amount)
	if remainder > 0:
		var accepted: int = amount - remainder
		if accepted <= 0:
			return false
			
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
		
	var current_stock: int = inventory.get_item_amount(item.id)
	var total_revenue: int = 0
	var temp_stock: int = current_stock
	for i in range(amount):
		var target: int = target_stock.get(item, 10)
		var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
		multiplier = clamp(multiplier, 0.2, 3.0)
		total_revenue += int(item.base_value * multiplier * 0.9)
		temp_stock += 1
		
	var remainder: int = inventory.add_item(item, amount)
	if remainder > 0:
		var accepted: int = amount - remainder
		if accepted <= 0:
			return false
			
		total_revenue = 0
		temp_stock = current_stock
		for i in range(accepted):
			var target: int = target_stock.get(item, 10)
			var multiplier: float = 1.0 + (float(target - temp_stock) / target) * sensitivity
			multiplier = clamp(multiplier, 0.2, 3.0)
			total_revenue += int(item.base_value * multiplier * 0.9)
			temp_stock += 1
			
		if ownership_type == "NPC" and owner_id == "Rival":
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				if rivals[0].gold < total_revenue:
					inventory.remove_item(item.id, accepted)
					return false
				rivals[0].gold -= total_revenue
			
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
	col_door.position = Vector2(0, 32)
	add_child(col_door)

func _create_entry_door() -> void:
	entry_door = Area2D.new()
	entry_door.name = "EntryDoorTrigger"
	entry_door.set_script(load("res://components/teleport/teleport_trigger.gd"))
	entry_door.position = Vector2(0, 32)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 16)
	col.shape = shape
	entry_door.add_child(col)
	
	add_child(entry_door)
	
	entry_door.is_local_teleport = true
	entry_door.target_spawn_position = interior_position + Vector2(0, 60)
	entry_door.ownership_type = ownership_type
	entry_door.owner_id = owner_id
	entry_door.is_buyable = false

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
		
	if fade_trigger:
		if not fade_trigger.body_entered.is_connected(_on_fade_body_entered):
			fade_trigger.body_entered.connect(_on_fade_body_entered)
		if not fade_trigger.body_exited.is_connected(_on_fade_body_exited):
			fade_trigger.body_exited.connect(_on_fade_body_exited)
		
	_setup_shared_inventory()
	
	var building_id = "bld_%s_%d_%d" % [name.to_lower(), int(global_position.x), int(global_position.y)]
	interior_position = GameState.allocate_interior_space(building_id)
	
	var interior_scene = load("res://components/buildings/interior_template.tscn")
	if interior_scene:
		instanced_interior = interior_scene.instantiate() as Node2D
		instanced_interior.name = "Interior_" + name + "_" + str(int(global_position.x))
		instanced_interior.global_position = interior_position
		get_tree().current_scene.call_deferred("add_child", instanced_interior)
		
		var exit_spawn_pos = global_position + Vector2(0, 64)
		instanced_interior.call_deferred("setup_interior", self, exit_spawn_pos)

	_create_dynamic_door()
	_create_entry_door()
	_update_door_state()
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
	var craft_time = float(recipe.required_level * 5.0)
	var worker = emp.get("npc_ref")
	var prod = worker.get("productivity") if is_instance_valid(worker) else 1.0
	if prod > 0.0:
		craft_time /= prod
		
	# Trait Level 8: Artisan's Efficiency
	var level = 1
	if is_instance_valid(worker):
		if "skills_data" in worker and worker.skills_data.has(recipe.required_career):
			level = worker.skills_data[recipe.required_career].get("level", 1)
		elif recipe.required_career + "_level" in worker:
			level = worker.get(recipe.required_career + "_level")
	else:
		level = emp.get("levels", {}).get(recipe.required_career, 1)
		
	if level >= 8 and recipe.output_item.get("is_luxury_product") == true:
		craft_time *= 0.85
		
	# Apply local law and delinquency modifiers
	var pm = get_node_or_null("/root/PoliticsManager")
	var prov = GameState.get_province_of_node(self) if GameState else ""
	if pm and prov != "":
		var faction = "Player" if ownership_type == "Player" else ("Rival" if ownership_type == "NPC" and owner_id == "Rival" else "")
		if faction != "" and pm.is_faction_delinquent(faction, prov):
			craft_time *= 1.25
		if pm.is_law_active("labor_welfare_mandate", prov):
			craft_time *= 1.176
			
	return craft_time

func start_player_crafting(recipe_path: String) -> void:
	var recipe = load(recipe_path)
	if not recipe:
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
	var craft_time = float(recipe.required_level * 5.0)
	var prod = player.get("productivity") if player else 1.0
	if prod > 0.0:
		craft_time /= prod
		
	# Level 8 Trait: Artisan's Efficiency
	if level >= 8 and recipe.output_item.get("is_luxury_product") == true:
		craft_time *= 0.85
		
	# Apply local law and delinquency modifiers to player
	if pm and b_prov != "":
		if pm.is_faction_delinquent("Player", b_prov):
			craft_time *= 1.25
		if pm.is_law_active("labor_welfare_mandate", b_prov):
			craft_time *= 1.176
			
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
	var next_lvl = building_level + 1
	if not UPGRADE_REQUIREMENTS.has(next_lvl):
		GameState.spawn_ui_floating_text("Building is already at maximum level!")
		return
	var req = UPGRADE_REQUIREMENTS[next_lvl]
	var career_id = "craftsman"
	if building_data and building_data.career != "":
		career_id = building_data.career
	var player_career_level = GameState.career_levels.get(career_id, 1)
	if player_career_level < req.profession_level:
		GameState.spawn_ui_floating_text("Requires %s Level %d!" % [career_id.capitalize(), req.profession_level])
		return
	if GameState.gold < req.gold_cost:
		GameState.spawn_ui_floating_text("Requires %d Gold!" % req.gold_cost)
		return
	GameState.gold -= req.gold_cost
	is_upgrading = true
	upgrade_timer = req.time
	reset_all_workers()
	GameState.spawn_ui_floating_text("Renovation started: %d seconds!" % int(req.time))

func purchase_improvement(improvement_id: String) -> void:
	if not IMPROVEMENT_DEFINITIONS.has(improvement_id):
		return
	var def = IMPROVEMENT_DEFINITIONS[improvement_id]
	var current_lvl = improvements.get(improvement_id, 0)
	if current_lvl >= def.max_level:
		GameState.spawn_ui_floating_text("Improvement already at maximum level!")
		return
	var cost = def.cost
	if GameState.gold < cost:
		GameState.spawn_ui_floating_text("Not enough gold!")
		return
	GameState.gold -= cost
	improvements[improvement_id] = current_lvl + 1
	recalculate_building_parameters()
	GameState.spawn_ui_floating_text("%s Purchased!" % def.name)

func _tick_employees(delta: float) -> void:
	if ownership_type != "Player" and ownership_type != "NPC":
		return
		
	if is_upgrading:
		upgrade_timer -= delta
		if upgrade_timer <= 0.0:
			is_upgrading = false
			building_level += 1
			recalculate_building_parameters()
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = get_tree().get_first_node_in_group("game_hud")
			if hud:
				hud._spawn_floating_text("%s upgraded to Level %d!" % [name.replace("Interior_", ""), building_level], global_position)
			GameState.spawn_ui_floating_text("%s upgraded to Level %d!" % [name.replace("Interior_", ""), building_level])
			for ui in get_tree().get_nodes_in_group("BuildingUIs"):
				if ui.visible and ui.get("_building") == self:
					ui.call_deferred("refresh")
		return
		
	# Process player manual crafting if active
	if is_player_working_here and player_crafting_recipe_path != "":
		# Cancel inputs
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
			var recipe = load(player_crafting_recipe_path)
			if recipe:
				var target_b_storage = building_storage if building_storage else inventory
				if target_b_storage:
					for item in recipe.inputs:
						target_b_storage.add_item(item, recipe.inputs[item])
			stop_player_crafting()
			return
			
		player_craft_timer -= delta
		if player_craft_timer <= 0.0:
			var recipe = load(player_crafting_recipe_path)
			if recipe:
				var out_item = recipe.output_item
				var out_qty = recipe.output_amount
				var target_b_storage = building_storage if building_storage else inventory
				
				# Get player career level
				var level = GameState.career_levels.get(recipe.required_career, 1)
				
				# Level 5/8 Trait: Bountiful Harvest
				var double_harvest_triggered = false
				if level >= 8:
					if randf() <= 0.35:
						out_qty *= 2
						double_harvest_triggered = true
				elif level >= 5:
					if randf() <= 0.20:
						out_qty *= 2
						double_harvest_triggered = true
						
				var artisan_efficiency_triggered = false
				if level >= 8 and out_item.get("is_luxury_product") == true:
					artisan_efficiency_triggered = true
					
				if target_b_storage and target_b_storage.get_free_space_for_item(out_item) >= out_qty:
					target_b_storage.add_item(out_item, out_qty)
					
					var hud = get_tree().get_first_node_in_group("PlayerHUD")
					if not hud:
						hud = get_tree().get_first_node_in_group("game_hud")
					if hud and hud.has_method("_spawn_floating_text"):
						if double_harvest_triggered:
							hud._spawn_floating_text("Double Harvest!", global_position)
						if artisan_efficiency_triggered:
							hud._spawn_floating_text("Masterwork Efficiency!", global_position)
							
					lifetime_production[out_item.id] = lifetime_production.get(out_item.id, 0) + out_qty
					daily_production[out_item.id] = daily_production.get(out_item.id, 0) + out_qty
					
					# Player earns career XP
					GameState.add_xp(recipe.required_career, int(recipe.xp_reward * 0.5))
					
					# Start next continuous craft
					var inputs_ok = true
					for item in recipe.inputs:
						var qty = recipe.inputs[item]
						if target_b_storage.get_item_amount(item.id) < qty:
							inputs_ok = false
							break
							
					var next_has_space = target_b_storage.get_free_space_for_item(out_item) >= out_qty
					
					if inputs_ok and next_has_space:
						for item in recipe.inputs:
							var qty = recipe.inputs[item]
							target_b_storage.remove_item(item.id, qty)
						# Recalculate craft time based on level
						var player = get_tree().get_first_node_in_group("Player")
						var craft_time = float(recipe.required_level * 5.0)
						var prod = player.get("productivity") if player else 1.0
						if prod > 0.0:
							craft_time /= prod
						if level >= 8 and recipe.output_item.get("is_luxury_product") == true:
							craft_time *= 0.85
							
						# Apply local law and delinquency modifiers to player
						var pm = get_node_or_null("/root/PoliticsManager")
						var b_prov = GameState.get_province_of_node(self) if GameState else ""
						if pm and b_prov != "":
							if pm.is_faction_delinquent("Player", b_prov):
								craft_time *= 1.25
							if pm.is_law_active("labor_welfare_mandate", b_prov):
								craft_time *= 1.176
								
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
		
	# Clean up and replenish candidates
	var valid_candidates = []
	for cand in hireable_candidates:
		if is_instance_valid(cand) and not cand.get("is_hired"):
			valid_candidates.append(cand)
	hireable_candidates = valid_candidates
	
	if hireable_candidates.size() < 3:
		_populate_candidates()
		
	for emp in hired_employees:
		# 1. Process active recipe (crafting)
		var recipe_path = emp.get("active_recipe_path", "")
		if recipe_path != "":
			var worker = emp.get("npc_ref")
			if emp.get("is_paused", false):
				if str(emp.get("active_gathering_node_path", "")) == "":
					var recipe = load(recipe_path)
					var inputs_ok = true
					if recipe and building_storage:
						for item in recipe.inputs:
							var qty = recipe.inputs[item]
							if building_storage.get_item_amount(item.id) < qty:
								inputs_ok = false
								break
					
					if inputs_ok:
						if recipe and building_storage:
							for item in recipe.inputs:
								var qty = recipe.inputs[item]
								building_storage.remove_item(item.id, qty)
						emp["is_paused"] = false
						var craft_time = get_employee_craft_time(emp, recipe)
						emp["craft_timer"] = craft_time
						emp["craft_total_time"] = craft_time
						if is_instance_valid(worker):
							worker.set("worker_state", "traveling_to_workbench")
							if is_instance_valid(instanced_interior) and is_instance_valid(instanced_interior.crafting_bench):
								var target_pos = instanced_interior.crafting_bench.global_position
								worker.call("_generate_path", target_pos)
					else:
						var missing_raw_material = null
						if recipe and (improvements.get("auto_gathering", 0) > 0):
							for item in recipe.inputs:
								var qty = recipe.inputs[item]
								if building_storage.get_item_amount(item.id) < qty:
									if item.is_raw_material:
										missing_raw_material = item
										break
						
						if missing_raw_material:
							var is_illegal = false
							var pm_g = get_node_or_null("/root/PoliticsManager")
							var b_prov = GameState.get_province_of_node(self) if GameState else ""
							if pm_g and b_prov != "":
								if pm_g.is_law_active("crown_forestry_protection", b_prov) and missing_raw_material.id == "standard_timber":
									is_illegal = true
								elif pm_g.is_law_active("noble_game_preservation", b_prov) and missing_raw_material.id == "venison":
									is_illegal = true
									
							if is_illegal:
								emp["active_recipe_path"] = recipe_path
								emp["craft_timer"] = 0.0
								emp["craft_total_time"] = 0.0
								emp["is_paused"] = true
								if is_instance_valid(worker):
									worker.set("worker_state", "traveling_to_workbench")
								continue

							var nearest = get_nearest_mega_node_for_resource(missing_raw_material.id)
							if nearest:
								emp["is_paused"] = true
								emp["craft_timer"] = 0.0
								emp["craft_total_time"] = 0.0
								if is_instance_valid(worker):
									worker.start_gathering_shift(nearest)
									emp["active_gathering_node_path"] = nearest.get_path()
						else:
							emp["active_recipe_path"] = recipe_path
							emp["craft_timer"] = 0.0
							emp["craft_total_time"] = 0.0
							emp["is_paused"] = true
							if is_instance_valid(worker):
								worker.set("worker_state", "traveling_to_workbench")
								var target_pos = get_interaction_position()
								if worker.global_position.y >= 9000.0:
									if is_instance_valid(instanced_interior) and is_instance_valid(instanced_interior.crafting_bench):
										target_pos = instanced_interior.crafting_bench.global_position
								worker.call("_generate_path", target_pos)
							
							# Send alert if not already sent
							if not emp.get("shortage_alert_sent", false):
								emp["shortage_alert_sent"] = true
								if GameState.has_method("add_alert"):
									var b_name = name.replace("Interior_", "")
									var msg = "%s cannot produce %s at %s: Insufficient inputs in storage." % [emp.get("name", "Employee"), recipe.recipe_name, b_name]
									GameState.add_alert("Production Blocked", msg, "warning", self)
				continue
				
			var worker_at_bench = false
			if is_instance_valid(worker):
				var w_state = worker.get("worker_state")
				if w_state == "producing_goods":
					worker_at_bench = true
				elif w_state != "traveling_to_workbench" and w_state != "traveling_to_node" and w_state != "gathering_at_node" and w_state != "returning_to_workshop":
					worker.set("worker_state", "traveling_to_workbench")
					if is_instance_valid(instanced_interior) and is_instance_valid(instanced_interior.crafting_bench):
						var target_pos = instanced_interior.crafting_bench.global_position
						worker.call("_generate_path", target_pos)
						
			if worker_at_bench:
				var timer = emp.get("craft_timer", 0.0)
				if timer > 0.0:
					timer -= delta
					emp["craft_timer"] = max(0.0, timer)
					
				if emp["craft_timer"] <= 0.0:
					var recipe = load(recipe_path)
					if recipe and building_storage:
						var out_item = recipe.output_item
						var out_qty = recipe.output_amount
						
						# Determine worker's level for traits
						var level = 1
						if is_instance_valid(worker):
							if "skills_data" in worker and worker.skills_data.has(recipe.required_career):
								level = worker.skills_data[recipe.required_career].get("level", 1)
							elif recipe.required_career + "_level" in worker:
								level = worker.get(recipe.required_career + "_level")
						else:
							level = emp.get("levels", {}).get(recipe.required_career, 1)
							
						# Level 5/8 Trait: Bountiful Harvest (output doubling)
						var double_harvest_triggered = false
						if level >= 8:
							if randf() <= 0.35:
								out_qty *= 2
								double_harvest_triggered = true
						elif level >= 5:
							if randf() <= 0.20:
								out_qty *= 2
								double_harvest_triggered = true
								
						# Level 8 Trait: Artisan's Efficiency feedback
						var artisan_efficiency_triggered = false
						if level >= 8 and out_item.get("is_luxury_product") == true:
							artisan_efficiency_triggered = true
						
						if building_storage.get_free_space_for_item(out_item) >= out_qty:
							building_storage.add_item(out_item, out_qty)
							
							# Floating Text feedback
							var hud = get_tree().get_first_node_in_group("PlayerHUD")
							if hud and hud.has_method("_spawn_floating_text"):
								if double_harvest_triggered:
									hud._spawn_floating_text("Double Harvest!", global_position)
								if artisan_efficiency_triggered:
									hud._spawn_floating_text("Masterwork Efficiency!", global_position)
							
							# Log daily/lifetime stats
							lifetime_production[out_item.id] = lifetime_production.get(out_item.id, 0) + out_qty
							daily_production[out_item.id] = daily_production.get(out_item.id, 0) + out_qty
							
							if ownership_type == "Player":
								GameState.add_xp(recipe.required_career, int(recipe.xp_reward * 0.5))
							elif ownership_type == "NPC":
								var rivals = get_tree().get_nodes_in_group("Rivals")
								if rivals.size() > 0:
									var rival = rivals[0]
									if rival.has_method("add_xp"):
										rival.add_xp(int(recipe.xp_reward * 0.5))
										
							# Hired employee gains profession XP
							if is_instance_valid(worker) and worker.has_method("gain_profession_xp"):
								worker.gain_profession_xp(recipe.required_career, int(recipe.xp_reward * 0.5))
							
							var should_repeat = false
							if emp.get("is_repeating", true):
								should_repeat = true
							else:
								var limit = emp.get("production_amount_limit", 0)
								if limit > 1:
									emp["production_amount_limit"] = limit - 1
									should_repeat = true
								else:
									emp["production_amount_limit"] = 0
									
							if should_repeat:
								var inputs_ok = true
								for item in recipe.inputs:
									var qty = recipe.inputs[item]
									if building_storage.get_item_amount(item.id) < qty:
										inputs_ok = false
										break
								
								var next_has_space = building_storage.get_free_space_for_item(out_item) >= out_qty
								
								if inputs_ok and next_has_space:
									for item in recipe.inputs:
										var qty = recipe.inputs[item]
										building_storage.remove_item(item.id, qty)
									var craft_time = get_employee_craft_time(emp, recipe)
									emp["craft_timer"] = craft_time
									emp["craft_total_time"] = craft_time
								else:
									if not inputs_ok and (improvements.get("auto_gathering", 0) > 0):
										var missing_raw_material = null
										for item in recipe.inputs:
											var qty = recipe.inputs[item]
											if building_storage.get_item_amount(item.id) < qty:
												if item.is_raw_material:
													missing_raw_material = item
													break
										
										if missing_raw_material:
											var is_illegal = false
											var pm_rep = get_node_or_null("/root/PoliticsManager")
											var b_prov = GameState.get_province_of_node(self) if GameState else ""
											if pm_rep and b_prov != "":
												if pm_rep.is_law_active("crown_forestry_protection", b_prov) and missing_raw_material.id == "standard_timber":
													is_illegal = true
												elif pm_rep.is_law_active("noble_game_preservation", b_prov) and missing_raw_material.id == "venison":
													is_illegal = true
													
											if is_illegal:
												emp["active_recipe_path"] = recipe_path
												emp["craft_timer"] = 0.0
												emp["craft_total_time"] = 0.0
												emp["is_paused"] = true
												if is_instance_valid(worker):
													worker.set("worker_state", "producing_goods")
												continue

											var nearest = get_nearest_mega_node_for_resource(missing_raw_material.id)
											if nearest:
												emp["is_paused"] = true
												emp["craft_timer"] = 0.0
												emp["craft_total_time"] = 0.0
												if is_instance_valid(worker):
													worker.start_gathering_shift(nearest)
													emp["active_gathering_node_path"] = nearest.get_path()
												continue
												
									if not inputs_ok:
										emp["active_recipe_path"] = recipe_path
										emp["craft_timer"] = 0.0
										emp["craft_total_time"] = 0.0
										emp["is_paused"] = true
										if is_instance_valid(worker):
											worker.set("worker_state", "producing_goods")
										
										# Send alert if not already sent
										if not emp.get("shortage_alert_sent", false):
											emp["shortage_alert_sent"] = true
											if GameState.has_method("add_alert"):
												var b_name = name.replace("Interior_", "")
												var msg = "%s has stopped producing %s at %s: Insufficient inputs in storage." % [emp.get("name", "Employee"), recipe.recipe_name, b_name]
												GameState.add_alert("Production Stalled", msg, "warning", self)
									else:
										# Storage full - keep standard halt
										emp["active_recipe_path"] = ""
										emp["craft_timer"] = 0.0
										emp["craft_total_time"] = 0.0
										emp["is_paused"] = false
										if is_instance_valid(worker):
											worker.set("worker_state", "producing_goods")
										if GameState.has_method("add_alert"):
											var b_name = name.replace("Interior_", "")
											var msg = "%s has stopped producing %s at %s: Building storage is full." % [emp.get("name", "Employee"), recipe.recipe_name, b_name]
											GameState.add_alert("Storage Full", msg, "warning", self)
							else:
								emp["active_recipe_path"] = ""
								emp["craft_timer"] = 0.0
								emp["craft_total_time"] = 0.0
								if is_instance_valid(worker):
									worker.set("worker_state", "producing_goods") # keep idle at workbench
						else:
							# Storage full
							emp["active_recipe_path"] = ""
							emp["craft_timer"] = 0.0
							emp["craft_total_time"] = 0.0
							if is_instance_valid(worker):
								worker.set("worker_state", "producing_goods")
							if GameState.has_method("add_alert"):
								var b_name = name.replace("Interior_", "")
								var msg = "%s has stopped producing %s at %s: Building storage is full." % [emp.get("name", "Employee"), recipe.recipe_name, b_name]
								GameState.add_alert("Storage Full", msg, "warning", self)
							
		# 2. Process active gathering task (shifts)
		var node_path = str(emp.get("active_gathering_node_path", ""))
		if node_path != "":
			var worker = emp.get("shift_worker_ref")
			if not is_instance_valid(worker) and emp.get("is_paused", false):
				worker = emp.get("npc_ref")
			var node = get_node_or_null(node_path)
			if is_instance_valid(worker):
				var w_state = worker.get("worker_state")
				if w_state == "returning_to_workshop":
					emp["shift_status"] = "returning"
				elif w_state == "gathering_at_node":
					emp["shift_status"] = "gathering"
				elif w_state == "traveling_to_node":
					emp["shift_status"] = "traveling"
				elif w_state == "idle_at_workshop":
					# Finished returning and depositing
					emp["shift_status"] = "idle"
					if emp.get("is_paused", false):
						emp["active_gathering_node_path"] = ""
					else:
						emp["shift_worker_ref"] = null
					
					# Handle repeating
					if emp.get("is_repeating", true) and node:
						var res_id = node.resource_type_id
						var is_illegal = false
						var pm_rep = get_node_or_null("/root/PoliticsManager")
						var b_prov = GameState.get_province_of_node(self) if GameState else ""
						if pm_rep and b_prov != "":
							if pm_rep.is_law_active("crown_forestry_protection", b_prov) and res_id == "standard_timber":
								is_illegal = true
							elif pm_rep.is_law_active("noble_game_preservation", b_prov) and res_id == "venison":
								is_illegal = true
								
						if is_illegal:
							emp["active_gathering_node_path"] = ""
							emp["shift_status"] = "idle"
							emp["shift_worker_ref"] = null
							continue

						var econ_mgr = get_node_or_null("/root/EconomyManager")
						var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
						if item_res and building_storage:
							var free_space = building_storage.get_free_space_for_item(item_res)
							var fee = node.get_entry_fee()
							
							var player_has_gold = true
							if ownership_type == "Player":
								player_has_gold = GameState.gold >= fee
							else:
								var rivals = get_tree().get_nodes_in_group("Rivals")
								player_has_gold = rivals.size() > 0 and rivals[0].gold >= fee
								
							if free_space >= 20 and player_has_gold:
								if ownership_type == "Player":
									GameState.gold -= fee
									GameState.spawn_ui_floating_text("Paid Permit: -%d Gold!" % fee)
								else:
									var rivals = get_tree().get_nodes_in_group("Rivals")
									if rivals.size() > 0:
										rivals[0].gold -= fee
								
								worker.start_gathering_shift(node)
								emp["shift_worker_ref"] = worker
								emp["shift_status"] = "traveling"
							else:
								emp["active_gathering_node_path"] = ""
								emp["shift_status"] = "idle"
								emp["shift_worker_ref"] = null
					else:
						# Not repeating, clear task
						emp["active_gathering_node_path"] = ""
						emp["shift_status"] = "idle"
						emp["shift_worker_ref"] = null
				elif emp.get("shift_status") in ["traveling", "gathering"]:
					# Failsafe reset
					emp["shift_status"] = "idle"
					emp["shift_worker_ref"] = null

func _spawn_shift_worker(emp: Dictionary, node: Area2D) -> void:
	var worker = emp.get("npc_ref")
	if is_instance_valid(worker):
		worker.start_gathering_shift(node)
		emp["shift_worker_ref"] = worker
		emp["shift_status"] = "traveling"

func _populate_candidates() -> void:
	hireable_candidates.clear()
	var province_name = GameState.get_province_of_node(self)
	var all_npcs = get_tree().get_nodes_in_group("NPCs")
	var local_unemployed = []
	for npc in all_npcs:
		if is_instance_valid(npc) and not npc.get("is_hired") and npc.get("province") == province_name:
			if npc.get("is_quest_npc") == true or npc.get("roams_interior_only") == true or npc.get("quest_npc_id") != "":
				continue
			local_unemployed.append(npc)
			
	# Replenish dynamic NPCs if count drops below 3
	while local_unemployed.size() < 3:
		var new_npc = spawn_dynamic_npc_in_province(province_name)
		if is_instance_valid(new_npc):
			local_unemployed.append(new_npc)
			
	for npc in local_unemployed:
		hireable_candidates.append(npc)
		
	ensure_spouse_candidate()

func ensure_spouse_candidate() -> void:
	var spouse_id = ""
	if owner_id == "Player" or ownership_type == "Player":
		if GameState and GameState.is_married:
			spouse_id = GameState.spouse_npc_id
	elif owner_id == "Rival":
		var rivals = get_tree().get_nodes_in_group("Rivals")
		for r in rivals:
			if is_instance_valid(r) and r.get("spouse_npc_id") != "":
				spouse_id = r.spouse_npc_id
				break
				
	if spouse_id != "":
		var spouse_node = null
		for npc in get_tree().get_nodes_in_group("NPCs"):
			if is_instance_valid(npc) and npc.get("quest_npc_id") == spouse_id:
				spouse_node = npc
				break
		if spouse_node and not spouse_node.get("is_hired"):
			if not hireable_candidates.has(spouse_node):
				hireable_candidates.append(spouse_node)

func spawn_dynamic_npc_in_province(prov_name: String) -> CharacterBody2D:
	var npc_scene = load("res://entities/npc/npc.tscn")
	if not npc_scene:
		return null
		
	var target_settlement = null
	for city in get_tree().get_nodes_in_group("Cities"):
		if (city.city_name + " Province") == prov_name:
			target_settlement = city
			break
	if not target_settlement:
		for town in get_tree().get_nodes_in_group("Towns"):
			if town.ownership_province == prov_name:
				target_settlement = town
				break
				
	var spawn_pos = global_position
	if target_settlement:
		spawn_pos = target_settlement.global_position
		
	var npc = npc_scene.instantiate() as CharacterBody2D
	npc.global_position = spawn_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	get_parent().add_child(npc)
	npc.province = prov_name
	
	print("[Building] Spawned dynamic NPC in province %s at position %s" % [prov_name, npc.global_position])
	return npc

func produces_using_only_raw_materials() -> bool:
	var bench = get_node_or_null("CraftingBench")
	if not bench or not ("recipes" in bench) or bench.recipes.is_empty():
		return false
	for recipe in bench.recipes:
		if not recipe:
			continue
		for input in recipe.inputs:
			if not input.is_raw_material:
				return false
	return true

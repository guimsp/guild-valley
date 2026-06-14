extends Node

# Signals
signal time_changed(hours: int, minutes: int, days: int)

# Player global finances
var gold: int = 1000
var bank_balance: int = 0

# Player global inventory (untyped to avoid circular autoload load reference order issues)
var player_inventory: Node

# Time cycle variables
var time_minutes: float = 0.0 # 0.0 to 60.0
var time_hours: int = 6 # Starts at 6 AM
var time_days: int = 1
var TIME_SPEED: float = 1.0 # 1 in-game minute = 1 real second
var _last_emitted_minute: int = -1

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	
	_last_emitted_minute = 0
	
	var inventory_script = load("res://components/inventory/inventory_component.gd")
	player_inventory = inventory_script.new()
	player_inventory.name = "PlayerInventory"
	# Set a default capacity for the player (4 slots, max stack 20)
	player_inventory.max_slots = 4
	player_inventory.max_stack = 20
	player_inventory.max_weight = 60.0
	add_child(player_inventory)
	
	# Give starting items for testing
	var wheat_res = load("res://common/items/instances/wheat.tres")
	if wheat_res:
		player_inventory.add_item(wheat_res, 10)

func _process(delta: float) -> void:
	time_minutes += delta * TIME_SPEED
	if time_minutes >= 60.0:
		time_minutes -= 60.0
		time_hours += 1
		if time_hours >= 24:
			time_hours = 0
			time_days += 1
			
	var current_min = int(time_minutes)
	if current_min != _last_emitted_minute:
		_last_emitted_minute = current_min
		time_changed.emit(time_hours, current_min, time_days)

func advance_day() -> void:
	time_days += 1
	time_hours = 6
	time_minutes = 0.0
	_last_emitted_minute = 0
	
	# Emit immediate update
	time_changed.emit(time_hours, 0, time_days)
	
	# overnight economy simulation
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	for stall in stalls:
		if stall.has_method("simulate_overnight_tick"):
			stall.simulate_overnight_tick()
			
	# overnight crop/resource regrowth
	var fields = get_tree().get_nodes_in_group("WheatFields")
	for field in fields:
		if field.has_method("simulate_overnight_tick"):
			field.simulate_overnight_tick()
			
	var cotton = get_tree().get_nodes_in_group("CottonPlants")
	for plant in cotton:
		if plant.has_method("simulate_overnight_tick"):
			plant.simulate_overnight_tick()
			
	var mines = get_tree().get_nodes_in_group("OreMines")
	for mine in mines:
		if mine.has_method("simulate_overnight_tick"):
			mine.simulate_overnight_tick()
			
	# overnight Bank interest (5% if player owns at least one Bank)
	var banks = get_tree().get_nodes_in_group("Banks")
	if banks.size() > 0 and bank_balance > 0:
		var interest = int(bank_balance * 0.05)
		if interest > 0:
			bank_balance += interest
			spawn_ui_floating_text("Bank Interest Earned: +%d Gold!" % interest)
			
	# overnight Inn traveler revenue
	var inns = get_tree().get_nodes_in_group("Inns")
	for inn in inns:
		if is_instance_valid(inn) and inn.ownership_type == "Player":
			var prosperity = 20
			if inn.get("nearest_settlement"):
				prosperity = inn.nearest_settlement.prosperity if "prosperity" in inn.nearest_settlement else 20
			var rev = inn.base_revenue + int(prosperity * 0.5)
			gold += rev
			spawn_ui_floating_text("Inn Revenue: +%d Gold!" % rev)
		elif is_instance_valid(inn) and inn.ownership_type == "NPC" and inn.owner_id == "Rival":
			var prosperity = 20
			if inn.get("nearest_settlement"):
				prosperity = inn.nearest_settlement.prosperity if "prosperity" in inn.nearest_settlement else 20
			var rev = inn.base_revenue + int(prosperity * 0.5)
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				rivals[0].gold += rev
				
	# overnight Rental House tenant simulation
	var houses = get_tree().get_nodes_in_group("Houses")
	for house in houses:
		if is_instance_valid(house) and house.get("is_rental"):
			if house.is_occupied:
				# Add rent income to owner
				var rent_earned = house.rent_cost
				if house.ownership_type == "Player":
					gold += rent_earned
					spawn_ui_floating_text("Received %d Gold in Rent!" % rent_earned)
				elif house.ownership_type == "NPC" and house.owner_id == "Rival":
					var rivals = get_tree().get_nodes_in_group("Rivals")
					if rivals.size() > 0:
						rivals[0].gold += rent_earned
				
				# Decrement tenant rent days
				house.rent_days_remaining -= 1
				if house.rent_days_remaining <= 0:
					house.is_occupied = false
					house.rent_days_remaining = 0
					house._update_door_state()
					if house.ownership_type == "Player":
						spawn_ui_floating_text("Tenant moved out!")
			else:
				# Roll for new tenant
				var prosperity = 20
				var dist_to_market = 800.0
				
				if house.get("nearest_settlement"):
					prosperity = house.nearest_settlement.prosperity if "prosperity" in house.nearest_settlement else 20
					var market_node = null
					if "market_node_path" in house.nearest_settlement and house.nearest_settlement.market_node_path:
						market_node = house.nearest_settlement.get_node_or_null(house.nearest_settlement.market_node_path)
					if market_node:
						dist_to_market = house.global_position.distance_to(market_node.global_position)
					else:
						dist_to_market = house.global_position.distance_to(house.nearest_settlement.global_position)
				
				var base_chance = 0.20
				var prosperity_bonus = prosperity * 0.005
				var market_bonus = max(0.0, 1.0 - dist_to_market / 800.0) * 0.20
				var total_chance = base_chance + prosperity_bonus + market_bonus
				
				if randf() < total_chance:
					house.is_occupied = true
					house.rent_days_remaining = randi_range(3, 8)
					var base_rent = 25
					house.rent_cost = base_rent + int(prosperity_bonus * 50) + int(market_bonus * 50)
					house._update_door_state()
					if house.ownership_type == "Player":
						spawn_ui_floating_text("New Tenant moved in! (Rent: %d G)" % house.rent_cost)
						
	# Decay rent days overnight
	var groups_to_decay = ["MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "TeleportTriggers", "WheatFields", "CottonPlants"]
	for grp in groups_to_decay:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and "ownership_type" in node:
				if (grp == "WheatFields" or grp == "CottonPlants") and _get_grid_for_crop(node) != null:
					continue
					
				if node.ownership_type == "Rented":
					node.rent_days_remaining -= 1
					if node.rent_days_remaining <= 0:
						node.ownership_type = "Public"
						node.owner_id = ""
						node.rent_days_remaining = 0
						
					# Propagate to child plots if grid
					if "crop_nodes" in node:
						for plot in node.crop_nodes:
							if is_instance_valid(plot):
								plot.ownership_type = node.ownership_type
								plot.owner_id = node.owner_id
								plot.rent_days_remaining = node.rent_days_remaining

func _get_grid_for_crop(crop_plot: Node2D) -> Node2D:
	if not is_instance_valid(crop_plot):
		return null
	for grid in get_tree().get_nodes_in_group("WheatFieldGrids"):
		if "crop_nodes" in grid and crop_plot in grid.crop_nodes:
			return grid
	for grid in get_tree().get_nodes_in_group("CottonPatchGrids"):
		if "crop_nodes" in grid and crop_plot in grid.crop_nodes:
			return grid
	return null



func _ensure_input_actions() -> void:
	var actions: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_ENTER],
		"toggle_inventory": [KEY_I],
		"toggle_build_menu": [KEY_B],
		"buy_workstation": [KEY_R],
		"rent_workstation": [KEY_T]
	}
	
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var event: InputEventKey = InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)


# Player career levels and experience
var career_levels: Dictionary = {
	"farmer": 1,
	"craftsman": 1,
	"tailor": 1,
	"banker": 1,
	"innkeeper": 1
}

var career_xp: Dictionary = {
	"farmer": 0,
	"craftsman": 0,
	"tailor": 0,
	"banker": 0,
	"innkeeper": 0
}

# Add experience and check for level ups
func add_xp(career: String, amount: int) -> void:
	if not career_levels.has(career):
		return
		
	career_xp[career] += amount
	var xp_to_next: int = get_xp_for_level(career_levels[career])
	
	while career_xp[career] >= xp_to_next:
		career_xp[career] -= xp_to_next
		career_levels[career] += 1
		print("[GameState] Leveled up %s to level %d!" % [career.capitalize(), career_levels[career]])
		xp_to_next = get_xp_for_level(career_levels[career])

# Calculate total XP required to level up (simple growth curve)
func get_xp_for_level(current_level: int) -> int:
	return int(100 * pow(1.5, current_level - 1))

# Check if player has the required level and ingredients to craft a recipe
# Use Resource type to avoid compile order conflicts with the Recipe class name
func can_craft_recipe(recipe: Resource) -> bool:
	var level = career_levels.get(recipe.required_career, 0)
	if level < recipe.required_level:
		return false
		
	# Check ingredients
	for item in recipe.inputs:
		var amount = recipe.inputs[item]
		if not player_inventory.has_item(item.id, amount):
			return false
			
	return true

# Crafts the recipe. Returns true if successful.
# Use Resource type to avoid compile order conflicts with the Recipe class name
func craft_recipe(recipe: Resource) -> bool:
	if not can_craft_recipe(recipe):
		return false
		
	# Consume ingredients
	for item in recipe.inputs:
		var amount = recipe.inputs[item]
		player_inventory.remove_item(item.id, amount)
		
	# Add output item
	player_inventory.add_item(recipe.output_item, recipe.output_amount)
	
	# Reward XP
	add_xp(recipe.required_career, recipe.xp_reward)
	return true

# Dynamically spawns a text label on top of an element (like Mill, Bed, etc.)
func add_text_tag(parent: Node2D, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	label.custom_minimum_size = Vector2(120, 20)
	# Center position relative to pivot (0,0)
	label.position = Vector2(-60, -10)
	label.z_index = 10
	
	# For walk-in buildings, add to the Exterior control so it fades out with the roof
	var ext = parent.get_node_or_null("Exterior")
	if ext:
		ext.add_child(label)
	else:
		parent.add_child(label)


func get_scene_path_for_node(node: Node) -> String:
	if node.is_in_group("Beds"):
		return "res://components/sleep/bed.tscn"
	elif node.is_in_group("MarketStall"):
		return "res://components/market/market_stall.tscn"
	elif node.is_in_group("CraftingBenches"):
		return "res://components/crafting/crafting_bench.tscn"
	elif node.is_in_group("WheatFieldGrids"):
		return "res://components/gathering/wheat_field_grid.tscn"
	elif node.is_in_group("CottonPatchGrids"):
		return "res://components/gathering/cotton_patch_grid.tscn"
	elif node.is_in_group("OreMines"):
		return "res://components/gathering/ore_mine.tscn"
	elif node.is_in_group("Mills"):
		return "res://components/production/mill.tscn"
	elif node.is_in_group("Smelters"):
		return "res://components/production/smelter.tscn"
	elif node.is_in_group("Looms"):
		return "res://components/production/loom.tscn"
	elif node.is_in_group("WheatFields"):
		return "res://components/gathering/wheat_field.tscn"
	elif node.is_in_group("CottonPlants"):
		return "res://components/gathering/cotton_plant.tscn"
	elif node.is_in_group("Houses"):
		return "res://components/buildings/house.tscn"
	elif node.is_in_group("Banks"):
		return "res://components/production/bank.tscn"
	elif node.is_in_group("Inns"):
		return "res://components/production/inn.tscn"
	return ""


func spawn_ui_floating_text(txt: String) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("_spawn_floating_text"):
		var players = get_tree().get_nodes_in_group("Player")
		var pos = players[0].global_position if players.size() > 0 else Vector2.ZERO
		hud._spawn_floating_text(txt, pos)


func save_game() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	var player_pos = player.global_position if player else Vector2(500.0, 300.0)
	
	var player_inv = []
	if player_inventory:
		for slot in player_inventory.slots:
			if slot.get("item") and slot["item"] is Resource:
				player_inv.append({
					"item_path": slot["item"].resource_path,
					"amount": slot["amount"]
				})
				
	var grid_spawned = {}
	for grid in get_tree().get_nodes_in_group("WheatFieldGrids"):
		if "crop_nodes" in grid:
			for crop in grid.crop_nodes:
				if is_instance_valid(crop):
					grid_spawned[crop] = true
	for grid in get_tree().get_nodes_in_group("CottonPatchGrids"):
		if "crop_nodes" in grid:
			for crop in grid.crop_nodes:
				if is_instance_valid(crop):
					grid_spawned[crop] = true
					
	var buildings_data = []
	var groups = ["Beds", "MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "Mills", "Smelters", "Looms", "WheatFields", "CottonPlants", "Houses", "Banks", "Inns"]
	
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node):
				continue
			if (group_name == "WheatFields" or group_name == "CottonPlants") and grid_spawned.has(node):
				continue
				
			var path = get_scene_path_for_node(node)
			if path == "":
				continue
				
			var parent_node = node.get_parent()
			var parent_path = ""
			if parent_node:
				parent_path = String(get_tree().root.get_path_to(parent_node))
				
			var data = {
				"scene_path": path,
				"position": [node.global_position.x, node.global_position.y],
				"parent_path": parent_path
			}
			
			if "ownership_type" in node:
				data["ownership_type"] = node.ownership_type
				data["owner_id"] = node.owner_id
				data["rent_days_remaining"] = node.rent_days_remaining
				
			if "is_rental" in node:
				data["is_rental"] = node.is_rental
				data["is_occupied"] = node.is_occupied
				data["rent_cost"] = node.rent_cost
			
			if group_name == "MarketStall":
				var market_inv = []
				if "inventory" in node and node.inventory:
					for slot in node.inventory.slots:
						if slot.get("item"):
							market_inv.append({
								"item_path": slot["item"].resource_path,
								"amount": slot["amount"]
							})
				data["inventory"] = market_inv
				
			buildings_data.append(data)
			
	var doors_data = []
	for node in get_tree().get_nodes_in_group("TeleportTriggers"):
		if is_instance_valid(node):
			doors_data.append({
				"path": String(get_tree().root.get_path_to(node)),
				"ownership_type": node.ownership_type,
				"owner_id": node.owner_id,
				"rent_days_remaining": node.rent_days_remaining
			})
			
	var construction_data = []
	for node in get_tree().get_nodes_in_group("ConstructionSites"):
		if not is_instance_valid(node):
			continue
		var parent_node = node.get_parent()
		var parent_path = ""
		if parent_node:
			parent_path = String(get_tree().root.get_path_to(parent_node))
		construction_data.append({
			"position": [node.global_position.x, node.global_position.y],
			"parent_path": parent_path,
			"target_scene_path": node.target_scene_path,
			"build_time": node.build_time,
			"building_name": node.building_name,
			"elapsed_time": node._elapsed_time if "_elapsed_time" in node else 0.0,
			"is_rental": node.is_rental if "is_rental" in node else false
		})
		
	var save_dict = {
		"player": {
			"gold": gold,
			"bank_balance": bank_balance,
			"position": [player_pos.x, player_pos.y],
			"careers": career_levels,
			"xp": career_xp,
			"inventory": player_inv
		},
		"time": {
			"minutes": time_minutes,
			"hours": time_hours,
			"days": time_days
		},
		"buildings": buildings_data,
		"doors": doors_data,
		"construction_sites": construction_data
	}
	
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "  "))
		file.close()
		print("[GameState] Game Saved to user://savegame.json")
		spawn_ui_floating_text("Game Saved!")


func load_game() -> void:
	if not FileAccess.file_exists("user://savegame.json"):
		print("[GameState] Save file user://savegame.json does not exist!")
		spawn_ui_floating_text("No Save File!")
		return
		
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	if not file:
		return
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("[GameState] JSON parse error: ", json.get_error_message())
		return
		
	var save_dict = json.data
	
	get_tree().paused = false
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud:
		if hud.has_method("exit_placement_mode_external"):
			hud.exit_placement_mode_external()
		if "pause_menu" in hud and hud.pause_menu and hud.pause_menu.visible:
			hud.toggle_pause_menu()
		
	var p_data = save_dict.get("player", {})
	gold = p_data.get("gold", 1000)
	bank_balance = p_data.get("bank_balance", 0)
	career_levels = p_data.get("careers", career_levels)
	career_xp = p_data.get("xp", career_xp)
	
	var t_data = save_dict.get("time", {})
	time_minutes = t_data.get("minutes", 0.0)
	time_hours = t_data.get("hours", 6)
	time_days = t_data.get("days", 1)
	_last_emitted_minute = int(time_minutes)
	time_changed.emit(time_hours, _last_emitted_minute, time_days)
	
	if player_inventory:
		player_inventory.clear()
		for slot in p_data.get("inventory", []):
			var path = slot.get("item_path", "")
			var amount = slot.get("amount", 0)
			if path != "" and amount > 0:
				var item = load(path)
				if item:
					player_inventory.add_item(item, amount)
					
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var pos_arr = p_data.get("position", [500.0, 300.0])
		player.global_position = Vector2(pos_arr[0], pos_arr[1])
		if "interactables_in_range" in player:
			player.interactables_in_range.clear()
			player.interactables_changed.emit()
		
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			camera.reset_smoothing()
			
	var groups_to_clear = ["Beds", "MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "Mills", "Smelters", "Looms", "WheatFields", "CottonPlants", "ConstructionSites", "Houses", "Banks", "Inns"]
	for group_name in groups_to_clear:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()
				
	var buildings_list = save_dict.get("buildings", [])
	for b_data in buildings_list:
		var path = b_data.get("scene_path", "")
		var pos_arr = b_data.get("position", [0.0, 0.0])
		var parent_path = b_data.get("parent_path", "")
		
		if path == "":
			continue
			
		var scene = load(path)
		if not scene:
			continue
			
		var node = scene.instantiate() as Node2D
		node.global_position = Vector2(pos_arr[0], pos_arr[1])
		
		if "ownership_type" in node:
			node.ownership_type = b_data.get("ownership_type", "Public")
			node.owner_id = b_data.get("owner_id", "")
			node.rent_days_remaining = int(b_data.get("rent_days_remaining", 0))
			
		if "is_rental" in node:
			node.is_rental = b_data.get("is_rental", false)
			node.is_occupied = b_data.get("is_occupied", false)
			node.rent_cost = int(b_data.get("rent_cost", 30))
			if node.has_method("_update_door_state"):
				node._update_door_state()
		
		var parent_node = null
		if parent_path != "":
			parent_node = get_tree().root.get_node_or_null(parent_path)
		if not parent_node and player:
			parent_node = player.get_parent()
			
		if parent_node:
			parent_node.add_child(node)
		else:
			get_tree().root.add_child(node)
			
		if path == "res://components/market/market_stall.tscn":
			var inv_data = b_data.get("inventory", [])
			if "inventory" in node and node.inventory:
				node.inventory.clear()
				for slot in inv_data:
					var item_path = slot.get("item_path", "")
					var amount = slot.get("amount", 0)
					if item_path != "" and amount > 0:
						var item = load(item_path)
						if item:
							node.inventory.add_item(item, amount)
							
	var doors_list = save_dict.get("doors", [])
	for d_data in doors_list:
		var path = d_data.get("path", "")
		if path != "":
			var node = get_tree().root.get_node_or_null(path)
			if is_instance_valid(node) and "ownership_type" in node:
				node.ownership_type = d_data.get("ownership_type", "Public")
				node.owner_id = d_data.get("owner_id", "")
				node.rent_days_remaining = int(d_data.get("rent_days_remaining", 0))
							
	var construction_list = save_dict.get("construction_sites", [])
	for c_data in construction_list:
		var pos_arr = c_data.get("position", [0.0, 0.0])
		var parent_path = c_data.get("parent_path", "")
		var target_path = c_data.get("target_scene_path", "")
		var build_time = c_data.get("build_time", 3.0)
		var building_name = c_data.get("building_name", "")
		var elapsed_time = c_data.get("elapsed_time", 0.0)
		
		var scene = load("res://components/placement/construction_site.tscn")
		if not scene:
			continue
			
		var node = scene.instantiate() as Node2D
		node.global_position = Vector2(pos_arr[0], pos_arr[1])
		node.target_scene_path = target_path
		node.build_time = build_time
		node.building_name = building_name
		node._elapsed_time = elapsed_time
		if "is_rental" in node:
			node.is_rental = c_data.get("is_rental", false)
		
		var parent_node = null
		if parent_path != "":
			parent_node = get_tree().root.get_node_or_null(parent_path)
		if not parent_node and player:
			parent_node = player.get_parent()
			
		if parent_node:
			parent_node.add_child(node)
		else:
			get_tree().root.add_child(node)
			
	if hud:
		if hud.has_method("update_hud_values"):
			hud.update_hud_values()
		if hud.has_method("update_inventory_panel"):
			hud.update_inventory_panel()
			
	print("[GameState] Game Loaded from user://savegame.json")
	spawn_ui_floating_text("Game Loaded!")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			save_game()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			load_game()
			get_viewport().set_input_as_handled()

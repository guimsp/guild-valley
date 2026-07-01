extends Node

signal rival_ai_active_changed(active: bool)
signal gold_changed(new_gold: int)
signal wealth_ledger_changed

# Player global finances
var gold: int = 1000:
	set(val):
		var diff = val - gold
		gold = val
		gold_changed.emit(val)
		
		var is_loading = false
		var slm = get_node_or_null("/root/SaveLoadManager")
		if slm and slm.get("is_loading_game") == true:
			is_loading = true
			
		if diff != 0 and not is_loading:
			_log_wealth_transaction(diff)

var wealth_ledger: Array = []
const MAX_WEALTH_LEDGER_ENTRIES: int = 50
var next_change_reason: String = ""
var next_change_detail: String = ""

var current_province: String = "Valley Province"
var current_region_name: String = "Valley City"

func _log_wealth_transaction(diff: int) -> void:
	var reason = next_change_reason
	var detail = next_change_detail
	
	if reason == "":
		var stack = get_stack()
		var found_frame = null
		for i in range(stack.size()):
			var f = stack[i]
			if "game_state.gd" not in f.source:
				found_frame = f
				break
		if found_frame:
			var src = found_frame.source.get_file()
			var func_name = found_frame.function
			reason = "%s -> %s" % [src, func_name]
			detail = "System Triggered"
		else:
			if not stack.is_empty():
				var frame = stack[stack.size() - 1]
				reason = "%s -> %s" % [frame.source.get_file(), frame.function]
				detail = "System Triggered"
			else:
				reason = "System"
				detail = "Direct write"
				
	var time_str = "Day 1 - 06:00 AM"
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("get_time_string"):
		time_str = tm.get_time_string()
		
	var entry = {
		"amount": diff,
		"reason": reason,
		"detail": detail,
		"timestamp": time_str,
		"new_total": gold
	}
	wealth_ledger.append(entry)
	while wealth_ledger.size() > MAX_WEALTH_LEDGER_ENTRIES:
		wealth_ledger.pop_front()
		
	next_change_reason = ""
	next_change_detail = ""
	wealth_ledger_changed.emit()

var bank_balance: int = 0
var influence: int = 150
var permanent_influence: int = 300
var title_level: int = 1
# Player global stats
var player_hp: float = 100.0
var player_max_hp: float = 100.0
var player_stamina: float = 100.0
var player_max_stamina: float = 100.0
var player_speed: float = 210.0

var player_name: String = "Player"
var selected_spawn_town: String = "Mineville"
var balance_config: Dictionary = {}
var rival_ai_active: bool = true:
	set(val):
		if rival_ai_active != val:
			rival_ai_active = val
			rival_ai_active_changed.emit(val)

# Player global inventory (untyped to avoid circular autoload load reference order issues)
var player_inventory: Node

# Dynastic Relationship System Globals
var is_married: bool = false
var spouse_npc_id: String = ""
var relationship_db: Dictionary = {}
var completed_relation_quests: Array = []

func ensure_strongbox(node: Node) -> Node:
	if not is_instance_valid(node):
		return null
	var strongbox = node.get_node_or_null("StrongboxComponent")
	if not strongbox:
		var strongbox_script = load("res://common/components/strongbox_component.gd")
		if strongbox_script:
			strongbox = strongbox_script.new()
			strongbox.name = "StrongboxComponent"
			node.add_child(strongbox)
	return strongbox

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_load_build_database()
	
	# Load balance constants configuration if available
	var file = FileAccess.open("res://common/singletons/game_balance_config.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			if json.data is Dictionary:
				balance_config = json.data
			else:
				print("[GameState] JSON balance data is not a Dictionary, using default dictionary.")
		else:
			print("[GameState] Failed to parse game_balance_config.json: ", json.get_error_message())
	else:
		print("[GameState] game_balance_config.json not found, using empty config.")
	
	var inventory_script = load("res://components/inventory/inventory_component.gd")
	player_inventory = inventory_script.new()
	player_inventory.name = "PlayerInventory"
	# Set a default capacity for the player (4 slots, max stack 20)
	player_inventory.max_slots = 4
	player_inventory.max_stack = 20
	player_inventory.max_weight = 60.0
	add_child(player_inventory)
	
	# Initialize starting inventory with test equipment items
	var starter_items = [
		"res://common/items/instances/Equipment/iron_helmet.tres",
		"res://common/items/instances/Equipment/iron_chestplate.tres",
		"res://common/items/instances/Equipment/leather_gloves.tres",
		"res://common/items/instances/Equipment/iron_sword.tres",
		"res://common/items/instances/Equipment/bronze_pickaxe.tres",
		"res://common/items/instances/Equipment/bronze_sickle.tres",
		"res://common/items/instances/Equipment/bronze_scythe.tres",
		"res://common/items/instances/Equipment/iron_pickaxe.tres",
		"res://common/items/instances/Equipment/iron_sickle.tres",
		"res://common/items/instances/Equipment/iron_scythe.tres",
		"res://common/items/instances/Equipment/steel_pickaxe.tres",
		"res://common/items/instances/Equipment/steel_sickle.tres",
		"res://common/items/instances/Equipment/steel_scythe.tres",
		"res://common/items/instances/Equipment/leather_backpack.tres",
		"res://common/items/instances/Equipment/silver_necklace.tres",
		"res://common/items/instances/Equipment/gold_ring.tres",
		"res://common/items/instances/Equipment/horse.tres",
		"res://common/items/instances/Equipment/cart.tres"
	]
	for path in starter_items:
		if ResourceLoader.exists(path):
			var item = load(path)
			if item:
				player_inventory.add_item(item, 1)
				
	recalculate_career_stats()
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _on_node_added(node: Node) -> void:
	if node.name == "Floor" and node is CanvasItem:
		node.z_index = -10

func _on_focus_changed(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var p = control.get_parent()
	while p:
		if p is ScrollContainer:
			p.ensure_control_visible(control)
			break
		p = p.get_parent()



func _ensure_input_actions() -> void:
	var actions: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_F, KEY_ENTER],
		"toggle_inventory": [KEY_I],
		"toggle_build_menu": [KEY_B],
		"buy_workstation": [KEY_R],
		"rent_workstation": [KEY_T]
	}
	
	for action in actions:
		if InputMap.has_action(action):
			if action == "interact":
				InputMap.action_erase_events(action)
			else:
				continue
		else:
			InputMap.add_action(action)
			
		for key in actions[action]:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

	# Ensure WASD is mapped to ui_left, ui_right, ui_up, ui_down for menu navigation
	var ui_mappings = {
		"ui_left": [KEY_A],
		"ui_right": [KEY_D],
		"ui_up": [KEY_W],
		"ui_down": [KEY_S]
	}
	
	for action in ui_mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		
		# Check existing mapped keys to avoid adding duplicates
		var existing_keys = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				existing_keys.append(event.physical_keycode)
				
		for key in ui_mappings[action]:
			if not (key in existing_keys):
				var event = InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)


var active_trial_recipes: Array = []

var max_profession_slots: int = 1

# Player career levels and experience
var career_levels: Dictionary = {
	"patreon": 1,
	"craftsman": 0,
	"tailor": 0,
	"scholar": 0,
	"woodworker": 0,
	"herbalist": 0,
	"rogue": 0,
	"showman": 0
}

func get_active_careers_count() -> int:
	var count = 0
	for key in career_levels:
		if career_levels[key] > 0:
			count += 1
	return count

func unlock_secondary_profession_slot() -> void:
	max_profession_slots = 2

var allocated_interiors: Dictionary = {}
var next_interior_index: int = 0

func allocate_interior_space(building_id: String) -> Vector2:
	if allocated_interiors.has(building_id):
		var pos_arr = allocated_interiors[building_id]
		return Vector2(pos_arr[0], pos_arr[1])
		
	# Space interiors apart by 1200 pixels along Y = 10000
	var pos = Vector2(next_interior_index * 1200.0, 10000.0)
	allocated_interiors[building_id] = [pos.x, pos.y]
	next_interior_index += 1
	return pos

var career_xp: Dictionary = {
	"patreon": 0,
	"craftsman": 0,
	"tailor": 0,
	"scholar": 0,
	"woodworker": 0,
	"herbalist": 0,
	"rogue": 0,
	"showman": 0
}

# Player Title / Status System
func get_title_name(lvl: int) -> String:
	match lvl:
		1: return "Apprentice"
		2: return "Journeyman"
		3: return "Guildmaster"
		4: return "Patrician"
		5: return "Guild Baron"
		_: return "Unknown Title"

func get_title_upgrade_cost(target_level: int) -> Dictionary:
	return {
		"gold": 1000 * int(pow(2, target_level - 2)),
		"influence": 500 * (target_level - 1)
	}

func can_upgrade_title() -> bool:
	if title_level >= 5:
		return false
	var cost = get_title_upgrade_cost(title_level + 1)
	
	# Check if the title promotion is locked by a bottleneck quest
	var next_title_name = get_title_name(title_level + 1)
	if QuestManager.is_title_promotion_locked(next_title_name):
		return false
		
	return gold >= cost["gold"] and permanent_influence >= cost["influence"]

func upgrade_title() -> bool:
	if not can_upgrade_title():
		return false
	var cost = get_title_upgrade_cost(title_level + 1)
	gold -= cost["gold"]
	title_level += 1
	spawn_ui_floating_text("Title Upgraded to: %s!" % get_title_name(title_level))
	return true

# Add experience and check for level ups
func add_xp(career: String, amount: int) -> void:
	if not career_levels.has(career):
		return
		
	var lvl = career_levels[career]
	# If next level is locked by a quest bottleneck, freeze advancement
	if QuestManager.is_profession_promotion_locked(career, lvl + 1):
		career_xp[career] = 0
		return
		
	career_xp[career] += amount
	var xp_to_next: int = get_xp_for_level(lvl)
	
	while career_xp[career] >= xp_to_next:
		# Check promotion lock for the transition to the next level
		if QuestManager.is_profession_promotion_locked(career, lvl + 1):
			career_xp[career] = 0
			break
			
		career_xp[career] -= xp_to_next
		save_dict_on_level_up(career) # save the level up
		career_levels[career] += 1
		print("[GameState] Leveled up %s to level %d!" % [career.capitalize(), career_levels[career]])
		_on_career_leveled_up(career, career_levels[career])
		
		lvl = career_levels[career]
		xp_to_next = get_xp_for_level(lvl)


func save_dict_on_level_up(_career: String) -> void:
	pass # helper placeholder if needed

func gain_profession_xp(career_id: String, amount: int) -> void:
	add_xp(career_id, amount)

# Recalculate career passive stats
func recalculate_career_stats() -> void:
	# Reset player stats to default base values
	player_speed = 210.0
	player_max_stamina = 100.0
	player_max_hp = 100.0
	
	var patreon_lvl = career_levels.get("patreon", 1)
	
	# Patreon Level 9: +20% Player Movement Speed and +25 Max Stamina
	if patreon_lvl >= 9:
		player_speed = 252.0
		player_max_stamina = 125.0
		
	# Patreon Level 10: +25 Max HP
	if patreon_lvl >= 10:
		player_max_hp = 125.0
		
	# Clamp current stats to their new max values
	player_stamina = min(player_stamina, player_max_stamina)
	player_hp = min(player_hp, player_max_hp)

func _on_career_leveled_up(career: String, new_level: int) -> void:
	recalculate_career_stats()
	if career == "patreon":
		if new_level == 9:
			spawn_ui_floating_text("Patreon Level 9: Speed +20%, Max Stamina +25!")
		elif new_level == 10:
			spawn_ui_floating_text("Patreon Level 10: Civic Landlord Unlocked & Max HP +25!")

# Calculate total XP required to level up (500 XP per level progression, capped at level 10)
func get_xp_for_level(current_level: int) -> int:
	if current_level >= 10:
		return 999999999 # Cap at level 10
	return current_level * 500

# Check if player has the required ingredients to craft a recipe
# Use Resource type to avoid compile order conflicts with the Recipe class name
func can_craft_recipe(recipe: Resource) -> bool:
	# Check ingredients (career level check removed for item crafting)
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
	elif node.is_in_group("PaperMakers"):
		return "res://components/production/paper_maker.tscn"
	elif node.is_in_group("PrintingPresses"):
		return "res://components/production/printing_press.tscn"
	elif node.is_in_group("Bakeries"):
		return "res://components/production/bakery.tscn"
	elif node.is_in_group("Taverns"):
		return "res://components/production/tavern.tscn"
	elif node.is_in_group("Farmsteads"):
		return "res://components/production/farmstead.tscn"
	elif node.is_in_group("Distilleries"):
		return "res://components/production/distillery.tscn"
	elif node.is_in_group("EventHalls"):
		return "res://components/production/event_hall.tscn"
	elif node.is_in_group("Warehouses"):
		return "res://components/buildings/warehouse.tscn"
	elif node.is_in_group("MarketStall"):
		return "res://components/market/market_stall.tscn"
	return ""


func spawn_ui_floating_text(txt: String) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("_spawn_floating_text"):
		var players = get_tree().get_nodes_in_group("Player")
		var pos = players[0].global_position if players.size() > 0 else Vector2.ZERO
		hud._spawn_floating_text(txt, pos)


func show_npc_dialogue(npc: Node2D, npc_name: String, messages: Array, on_complete: Callable = Callable()) -> void:
	var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
	var bubble = bubble_scene.instantiate()
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud:
		var parent_node = hud.get_node_or_null("Control")
		if parent_node:
			parent_node.add_child(bubble)
		else:
			hud.add_child(bubble)
		bubble.start_dialogue(npc, npc_name, messages, on_complete)


func get_nearest_settlement(node: Node) -> Node2D:
	if not is_instance_valid(node):
		return null
		
	var settlement = node.get("nearest_settlement")
	if not settlement:
		var pos = node.global_position if "global_position" in node else Vector2.ZERO
		var min_dist: float = INF
		var closest: Node2D = null
		
		var tree = Engine.get_main_loop() as SceneTree
		if not tree:
			return null
			
		for city in tree.get_nodes_in_group("Cities"):
			var dist = pos.distance_to(city.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = city
		for town in tree.get_nodes_in_group("Towns"):
			var dist = pos.distance_to(town.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = town
		settlement = closest
	return settlement

func get_province_of_node(node: Node) -> String:
	if not is_instance_valid(node):
		return "Unknown Province"
		
	var pos = node.global_position if "global_position" in node else Vector2.ZERO
	
	# Check if the node is inside any drawn Province ColorRect in the editor blueprint
	var bp = get_node_or_null("/root/World/world_map_blueprint")
	if bp:
		var prov_folder = bp.get_node_or_null("Provinces")
		if prov_folder:
			for prov_node in prov_folder.get_children():
				if is_instance_valid(prov_node):
					for child in prov_node.get_children():
						if child is ColorRect:
							var rect = child.get_global_rect()
							if rect.has_point(pos):
								var prov_name = prov_node.name.replace("_", " ")
								return prov_name
								
	var settlement = get_nearest_settlement(node)
	if not settlement:
		return "Unknown Province"
		
	if "ownership_province" in settlement and settlement.ownership_province != "":
		return settlement.ownership_province
		
	if settlement.is_in_group("Cities") or "city_name" in settlement:
		var name_val = settlement.get("city_name")
		if name_val == null or str(name_val) == "":
			name_val = settlement.name
		return str(name_val) + " Province"
		
	return "Unknown Province"

func get_provinces() -> Array[String]:
	var list: Array[String] = []
	var bp = get_node_or_null("/root/World/world_map_blueprint")
	if bp:
		var prov_folder = bp.get_node_or_null("Provinces")
		if prov_folder:
			for child in prov_folder.get_children():
				list.append(child.name.replace("_", " "))
	if list.is_empty():
		return ["Valley Province", "Oakhaven Province", "Highland Province"]
	return list

func has_private_house_in_province(owner_type: String, province: String) -> bool:
	var houses = get_tree().get_nodes_in_group("Houses")
	for house in houses:
		if is_instance_valid(house) and not house.is_rental:
			if house.ownership_type == owner_type:
				if get_province_of_node(house) == province:
					return true
	return false

# Central database array of BuildingData resources
var build_database: Array[BuildingData] = []

func _load_build_database() -> void:
	build_database.clear()
	var dir_path = "res://common/buildings/resources/"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name
				if clean_name.ends_with(".remap"):
					clean_name = clean_name.replace(".remap", "")
				if clean_name.ends_with(".tres"):
					var res = load(dir_path + clean_name)
					if res and res is BuildingData:
						build_database.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()
		print("Central Database: Loaded %d building resources." % build_database.size())
	else:
		push_error("Failed to open buildings resources folder: " + dir_path)


func get_building_data_for_node(node: Node2D) -> BuildingData:
	var target_name = node.get("custom_name") if node.get("custom_name") != null and node.get("custom_name") != "" else node.name
	if node.get("market_name") != null and target_name == node.name:
		target_name = node.get("market_name")
	var at_index = target_name.find("@")
	if at_index != -1:
		target_name = target_name.substr(0, at_index)
	target_name = target_name.strip_edges()
	
	for db_item in build_database:
		if db_item.name == target_name:
			return db_item
			
	for db_item in build_database:
		if db_item.scene_path == node.scene_file_path:
			return db_item
			
	return null

func apply_macro_modifier(node: Node, modifier_key: String, base_value: float) -> float:
	var bonus_mult = 0.0 # for speed/productivity/yield
	var time_mult = 0.0  # for time/duration modifiers
	
	# 1. Settlement Scope
	var settlement = get_nearest_settlement(node)
	if is_instance_valid(settlement):
		var dist = 0.0
		if "global_position" in node and "global_position" in settlement:
			dist = node.global_position.distance_to(settlement.global_position)
		var radius = settlement.get("radius_of_influence")
		if radius == null:
			radius = 800.0
		if dist <= radius:
			if "modifiers" in settlement and settlement.modifiers.has(modifier_key):
				var mod_val = settlement.modifiers[modifier_key]
				if modifier_key.ends_with("_time") or modifier_key.ends_with("_duration"):
					time_mult += mod_val
				else:
					bonus_mult += mod_val
					
	# 2. Province Scope
	var province_name = get_province_of_node(node)
	if province_name != "Unknown Province" and province_name != "":
		var pmd = get_node_or_null("/root/ProvinceMasterData") if is_inside_tree() else null
		if pmd:
			var mod_val = pmd.get_modifier(province_name, modifier_key)
			if modifier_key.ends_with("_time") or modifier_key.ends_with("_duration"):
				time_mult += mod_val
			else:
				bonus_mult += mod_val
				
	# 3. Map Scope (Global)
	var gp = get_node_or_null("/root/GlobalProfile") if is_inside_tree() else null
	if gp:
		var mod_val = gp.get_modifier(modifier_key)
		if modifier_key.ends_with("_time") or modifier_key.ends_with("_duration"):
			time_mult += mod_val
		else:
			bonus_mult += mod_val
			
	var result = base_value
	# Apply multipliers
	if modifier_key.ends_with("_time") or modifier_key.ends_with("_duration"):
		result *= (1.0 + time_mult)
	else:
		result *= (1.0 + bonus_mult)
		
	return result

func get_required_tool_type_for_resource(resource_id: String) -> String:
	match resource_id:
		"wheat", "sunflower", "barley_and_hops", "grapes", "apple":
			return "scythe"
		"cotton", "berries", "honey", "venison", "wild_animal_hides", "raw_wild_herbs", "overworld_root", "underground_fungi", "wild_flax", "river_reeds":
			return "sickle"
		"iron_ore", "coal_nugget", "copper_ore", "zinc_ore", "raw_stone", "marble_block", "clay_mud", "scraped_metal", "wild_animal_bones":
			return "pickaxe"
	return ""

func is_tool_sufficient(tool_id: String, required_type: String, item_level: int) -> bool:
	if required_type == "":
		return true
		
	var id_lower = tool_id.to_lower()
	
	var tool_type = ""
	var tool_tier = ""
	
	if id_lower.contains("scythe"):
		tool_type = "scythe"
	elif id_lower.contains("sickle"):
		tool_type = "sickle"
	elif id_lower.contains("pickaxe"):
		tool_type = "pickaxe"
		
	if tool_type != required_type:
		return false
		
	if id_lower.begins_with("steel_"):
		tool_tier = "steel"
	elif id_lower.begins_with("iron_"):
		tool_tier = "iron"
	elif id_lower.begins_with("bronze_") or id_lower.begins_with("copper_"):
		tool_tier = "copper"
		
	if item_level >= 4:
		return tool_tier == "iron" or tool_tier == "steel"
		
	return tool_tier == "copper" or tool_tier == "iron" or tool_tier == "steel"

func find_sufficient_tool(inventory_or_storage: Node, required_type: String, item_level: int) -> String:
	if required_type == "":
		return ""
		
	var tools_to_check = []
	if required_type == "scythe":
		tools_to_check = ["steel_scythe", "iron_scythe", "bronze_scythe"]
	elif required_type == "sickle":
		tools_to_check = ["steel_sickle", "iron_sickle", "bronze_sickle"]
	elif required_type == "pickaxe":
		tools_to_check = ["steel_pickaxe", "iron_pickaxe", "bronze_pickaxe"]
		
	for tool_id in tools_to_check:
		if is_tool_sufficient(tool_id, required_type, item_level):
			if inventory_or_storage and inventory_or_storage.get_item_amount(tool_id) > 0:
				return tool_id
	return ""

# Centralized Window Stack Management
# Array of Dictionaries: { "window": Control, "close_callable": Callable, "cached_focus": Control }
var window_stack: Array = []

func register_window(window: Control, close_callable: Callable) -> void:
	if not window:
		return
	# Avoid duplicate registration
	for entry in window_stack:
		if entry["window"] == window:
			return
			
	var prev_focus = get_viewport().gui_get_focus_owner()
	window_stack.append({
		"window": window,
		"close_callable": close_callable,
		"cached_focus": prev_focus
	})
	print("[WindowManager] Registered window: ", window.name, ", Stack size: ", window_stack.size())

func unregister_window(window: Control) -> void:
	if not window:
		return
	var found_idx = -1
	for i in range(window_stack.size()):
		if window_stack[i]["window"] == window:
			found_idx = i
			break
			
	if found_idx != -1:
		var entry = window_stack[found_idx]
		window_stack.remove_at(found_idx)
		print("[WindowManager] Unregistered window: ", window.name, ", Stack size: ", window_stack.size())
		
		# Restore focus
		var cached = entry["cached_focus"]
		if is_instance_valid(cached) and cached.is_inside_tree() and cached.visible:
			cached.grab_focus()

func pop_and_close_top_window() -> bool:
	if window_stack.is_empty():
		return false
		
	var entry = window_stack.pop_back()
	var window = entry["window"]
	var close_callable = entry["close_callable"]
	var cached = entry["cached_focus"]
	
	print("[WindowManager] Popping and closing top window: ", window.name if is_instance_valid(window) else "Invalid")
	if close_callable.is_valid():
		close_callable.call()
		
	# Restore focus
	if is_instance_valid(cached) and cached.is_inside_tree() and cached.visible:
		cached.grab_focus()
		
	return true

extends Node

signal rival_ai_active_changed(active: bool)
signal gold_changed(new_gold: int)

# Player global finances
var gold: int = 1000:
	set(val):
		gold = val
		gold_changed.emit(val)
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

func _on_node_added(node: Node) -> void:
	if node.name == "Floor" and node is CanvasItem:
		node.z_index = -10



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

# Player career levels and experience
var career_levels: Dictionary = {
	"patreon": 1,
	"craftsman": 0,
	"tailor": 0,
	"scholar": 0
}

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
	"scholar": 0
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
		"gold": 100,
		"influence": 10 * (target_level - 1)
	}

func can_upgrade_title() -> bool:
	if title_level >= 5:
		return false
	var cost = get_title_upgrade_cost(title_level + 1)
	return gold >= cost["gold"] and influence >= cost["influence"]

func upgrade_title() -> bool:
	if not can_upgrade_title():
		return false
	var cost = get_title_upgrade_cost(title_level + 1)
	gold -= cost["gold"]
	influence -= cost["influence"]
	title_level += 1
	spawn_ui_floating_text("Title Upgraded to: %s!" % get_title_name(title_level))
	return true

# Add experience and check for level ups
func add_xp(career: String, amount: int) -> void:
	if not career_levels.has(career):
		return
		
	var lvl = career_levels[career]
	if lvl in [3, 6, 9]:
		career_xp[career] = 0
		return
		
	career_xp[career] += amount
	var xp_to_next: int = get_xp_for_level(lvl)
	
	while career_xp[career] >= xp_to_next:
		career_xp[career] -= xp_to_next
		save_dict_on_level_up(career) # save the level up
		career_levels[career] += 1
		print("[GameState] Leveled up %s to level %d!" % [career.capitalize(), career_levels[career]])
		_on_career_leveled_up(career, career_levels[career])
		
		lvl = career_levels[career]
		if lvl in [3, 6, 9]:
			career_xp[career] = 0
			break
			
		xp_to_next = get_xp_for_level(lvl)


func save_dict_on_level_up(career: String) -> void:
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
		for city in get_tree().get_nodes_in_group("Cities"):
			var dist = pos.distance_to(city.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = city
		for town in get_tree().get_nodes_in_group("Towns"):
			var dist = pos.distance_to(town.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = town
		settlement = closest
	return settlement

func get_province_of_node(node: Node) -> String:
	var settlement = get_nearest_settlement(node)
	if not settlement:
		return "Unknown Province"
		
	if "ownership_province" in settlement and settlement.ownership_province != "":
		return settlement.ownership_province
		
	if settlement.is_in_group("Cities") or "city_name" in settlement:
		return settlement.city_name + " Province"
		
	return "Unknown Province"


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

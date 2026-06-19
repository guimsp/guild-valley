extends Node

# Signals
signal time_changed(hours: int, minutes: int, days: int)
signal rival_ai_active_changed(active: bool)

# Player global finances
var gold: int = 1000
var bank_balance: int = 0
var influence: int = 150
var permanent_influence: int = 300
var title_level: int = 1
# Player global stats
var player_hp: float = 100.0
var player_max_hp: float = 100.0
var player_stamina: float = 100.0
var player_max_stamina: float = 100.0
var player_speed: float = 150.0

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

# Time cycle variables
var time_minutes: float = 0.0 # 0.0 to 60.0
var time_hours: int = 6 # Starts at 6 AM
var time_days: int = 1
var TIME_SPEED: float = 1.0 # 1 in-game minute = 1 real second
var _last_emitted_minute: int = -1
var last_salary_payout_day: int = -1

func get_time_string() -> String:
	var ampm = "AM" if time_hours < 12 else "PM"
	var display_hours = time_hours % 12
	if display_hours == 0:
		display_hours = 12
	return "Day %d - %02d:%02d %s" % [time_days, display_hours, int(time_minutes), ampm]

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
	
	_last_emitted_minute = 0
	
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

func _process(delta: float) -> void:
	time_minutes += delta * TIME_SPEED
	if time_minutes >= 60.0:
		time_minutes -= 60.0
		time_hours += 1
		if time_hours >= 24:
			time_hours = 0
			time_days += 1
			_clear_daily_production_stats()
			_deduct_salaries()
			if time_days % 4 == 0:
				if has_node("/root/PoliticsManager"):
					get_node("/root/PoliticsManager").process_seasonal_taxes()
			
	var current_min = int(time_minutes)
	if current_min != _last_emitted_minute:
		_last_emitted_minute = current_min
		time_changed.emit(time_hours, current_min, time_days)
		_check_politics_cycle_ticks()

func _clear_daily_production_stats() -> void:
	for node in get_tree().get_nodes_in_group("production_buildings"):
		if node.has_method("clear_daily_stats"):
			node.clear_daily_stats()

var _last_checked_politics_key: int = -1

func _check_politics_cycle_ticks() -> void:
	if not has_node("/root/PoliticsManager"):
		return
	
	var pm = get_node("/root/PoliticsManager")
	var key = time_days * 100 + time_hours
	if _last_checked_politics_key == key:
		return
	_last_checked_politics_key = key
	
	if time_days % 4 == 0:
		for province in ["Valley Province", "Oakhaven Province"]:
			if time_hours == 6:
				pm.set_phase(province, pm.Phase.PHASE_SPONSORSHIP)
				spawn_ui_floating_text("%s: Lawhouse is open for Sponsorship!" % province)
			elif time_hours == 12:
				pm.assemble_ballot(province)
				pm.set_phase(province, pm.Phase.PHASE_BALLOT_ASSEMBLY)
				spawn_ui_floating_text("%s: Ballot Assembly Phase begun!" % province)
			elif time_hours == 18:
				pm.set_phase(province, pm.Phase.PHASE_VOTING)
				spawn_ui_floating_text("%s: Council Voting Phase begun!" % province)
			elif time_hours == 0:
				var state = pm.province_states[province]
				if state["current_phase"] == pm.Phase.PHASE_VOTING:
					var results = pm.resolve_voting_session(province, {}, {})
					var passed = []
					for lid in results:
						if results[lid]["passed"]:
							passed.append(results[lid]["law_name"])
					if passed.size() > 0:
						spawn_ui_floating_text("%s passed: %s" % [province, ", ".join(passed)])
					else:
						spawn_ui_floating_text("%s: No laws passed." % province)

func advance_day() -> void:
	if time_days % 4 == 0:
		if has_node("/root/PoliticsManager"):
			var pm = get_node("/root/PoliticsManager")
			for province in ["Valley Province", "Oakhaven Province"]:
				if pm.province_states[province]["current_phase"] == pm.Phase.PHASE_VOTING:
					pm.resolve_voting_session(province, {}, {})
					
	time_days += 1
	time_hours = 6
	time_minutes = 0.0
	_last_emitted_minute = 0
	_clear_daily_production_stats()
	
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
		var usury_blocked = false
		if has_node("/root/PoliticsManager"):
			var pm = get_node("/root/PoliticsManager")
			var bank_prov = get_province_of_node(banks[0])
			if pm.is_law_active("usury_prohibition", bank_prov):
				usury_blocked = true
				
		if usury_blocked:
			spawn_ui_floating_text("Bank Interest Blocked by Usury Prohibition!")
		else:
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
			var base_rev = inn.base_revenue if "base_revenue" in inn else 50
			if inn.get("building_level") != null and inn.building_level >= 2:
				base_rev = 120 # Premium luxury hotel lodging
			var rev = base_rev + int(prosperity * 0.5)
			
			var sbox = inn.get_node_or_null("StrongboxComponent")
			if sbox:
				sbox.strongbox_gold += rev
				sbox.add_transaction("Lodging Rent", 1, rev, "Overnight", "Guests")
			else:
				gold += rev
			spawn_ui_floating_text("Inn Revenue: +%d Gold!" % rev)
		elif is_instance_valid(inn) and inn.ownership_type == "NPC" and inn.owner_id == "Rival":
			var prosperity = 20
			if inn.get("nearest_settlement"):
				prosperity = inn.nearest_settlement.prosperity if "prosperity" in inn.nearest_settlement else 20
			var base_rev = inn.base_revenue if "base_revenue" in inn else 50
			if inn.get("building_level") != null and inn.building_level >= 2:
				base_rev = 120
			var rev = base_rev + int(prosperity * 0.5)
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				rivals[0].gold += rev
				
	# overnight Employee salary deduction
	_deduct_salaries()
				
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
				
				var is_patreon_l10 = career_levels.get("patreon", 1) >= 10
				if is_patreon_l10 and house.ownership_type == "Player":
					total_chance *= 1.5 # +50% tenant fill rate
				
				if randf() < total_chance:
					house.is_occupied = true
					house.rent_days_remaining = randi_range(3, 8)
					var base_rent = 25
					var rent_cost = base_rent + int(prosperity_bonus * 50) + int(market_bonus * 50)
					if is_patreon_l10 and house.ownership_type == "Player":
						rent_cost = int(rent_cost * 1.15) # +15% higher rent limit
					house.rent_cost = rent_cost
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

	# overnight Employee salary deduction
	_deduct_salaries()

func _deduct_salaries() -> void:
	if last_salary_payout_day == time_days:
		return
	last_salary_payout_day = time_days
	
	var employee_salary_cost = 0
	var rival_salary_cost = 0
	var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	for grp in production_groups:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and "hired_employees" in node:
				if node.ownership_type == "Player":
					for emp in node.hired_employees:
						employee_salary_cost += int(emp.get("salary", 15))
				elif node.ownership_type == "NPC" and node.owner_id == "Rival":
					for emp in node.hired_employees:
						rival_salary_cost += int(emp.get("salary", 15))
	if employee_salary_cost > 0:
		gold -= employee_salary_cost
		spawn_ui_floating_text("Paid Employee Salaries: -%d Gold!" % employee_salary_cost)
	if rival_salary_cost > 0:
		var rivals = get_tree().get_nodes_in_group("Rivals")
		if rivals.size() > 0:
			rivals[0].gold -= rival_salary_cost

func _get_grid_for_crop(crop_plot: Node2D) -> Node2D:
	return null



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
		
	career_xp[career] += amount
	var xp_to_next: int = get_xp_for_level(career_levels[career])
	
	while career_xp[career] >= xp_to_next:
		career_xp[career] -= xp_to_next
		save_dict_on_level_up(career) # save the level up
		career_levels[career] += 1
		print("[GameState] Leveled up %s to level %d!" % [career.capitalize(), career_levels[career]])
		_on_career_leveled_up(career, career_levels[career])
		xp_to_next = get_xp_for_level(career_levels[career])

func save_dict_on_level_up(career: String) -> void:
	pass # helper placeholder if needed

func gain_profession_xp(career_id: String, amount: int) -> void:
	add_xp(career_id, amount)

# Recalculate career passive stats
func recalculate_career_stats() -> void:
	# Reset player stats to default base values
	player_speed = 150.0
	player_max_stamina = 100.0
	player_max_hp = 100.0
	
	var patreon_lvl = career_levels.get("patreon", 1)
	
	# Patreon Level 9: +20% Player Movement Speed and +25 Max Stamina
	if patreon_lvl >= 9:
		player_speed = 180.0
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

# Calculate total XP required to level up (simple growth curve)
func get_xp_for_level(current_level: int) -> int:
	return int(round(100 * pow(1.5, current_level - 1)))

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
					
	var saved_nodes = {}
	var buildings_data = []
	var groups = ["Beds", "MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "Mills", "Smelters", "Looms", "WheatFields", "CottonPlants", "Houses", "Banks", "Inns", "PaperMakers", "PrintingPresses", "Bakeries", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node):
				continue
			if node in saved_nodes:
				continue
			saved_nodes[node] = true
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
				
			if "hired_employees" in node:
				var serialized_emps = []
				for emp in node.hired_employees:
					var emp_copy = emp.duplicate(true)
					var npc = emp.get("npc_ref")
					if is_instance_valid(npc):
						emp_copy["npc_name"] = npc.npc_name
						emp_copy["skills_data"] = npc.skills_data
						emp_copy["salary"] = npc.salary
						emp_copy["speed"] = npc.speed
						emp_copy["productivity"] = npc.get("productivity")
						emp_copy["province"] = npc.province
						emp_copy["worker_state"] = npc.worker_state
						emp_copy["commercial_route_current_waypoint_index"] = npc.commercial_route_current_waypoint_index
						emp_copy["commercial_route_cargo_item_id"] = npc.commercial_route_cargo_item_id
						emp_copy["commercial_route_cargo_amount"] = npc.commercial_route_cargo_amount
						emp_copy["commercial_route_gold_carried"] = npc.commercial_route_gold_carried
						emp_copy["current_stop_index"] = npc.current_stop_index
						
						# Serialize cargo_inventory
						if npc.cargo_inventory:
							var cargo_inv_data = []
							for slot in npc.cargo_inventory.slots:
								if slot.get("item"):
									cargo_inv_data.append({
										"item_path": slot["item"].resource_path,
										"amount": slot["amount"]
									})
							emp_copy["cargo_inventory"] = cargo_inv_data
							
					if emp_copy.has("npc_ref"):
						emp_copy.erase("npc_ref")
					if emp_copy.has("shift_worker_ref"):
						emp_copy.erase("shift_worker_ref")
						
					# Serialize active trade route if present
					var active_route = emp.get("active_commercial_route")
					if active_route != null:
						if active_route.get("route_stops") != null:
							var stops_data = []
							for stop in active_route.route_stops:
								if is_instance_valid(stop):
									stops_data.append({
										"target_building_path": String(get_tree().root.get_path_to(stop.target_building)) if is_instance_valid(stop.target_building) else "",
										"action_type": stop.action_type,
										"item_id": stop.item_id,
										"target_quantity": stop.target_quantity
									})
							var serialized_route = {
								"is_global_logistics": true,
								"route_name": active_route.route_name,
								"route_stops": stops_data
							}
							emp_copy["active_commercial_route"] = serialized_route
						else:
							var serialized_route = {
								"route_name": active_route.route_name,
								"source_building_path": String(get_tree().root.get_path_to(active_route.source_building_ref)) if is_instance_valid(active_route.source_building_ref) else "",
								"target_item_id": active_route.target_item_id,
								"target_amount": active_route.target_amount,
								"minimum_sell_price": active_route.minimum_sell_price,
								"market_waypoints_paths": []
							}
							for wp in active_route.market_waypoints:
								if is_instance_valid(wp):
									serialized_route["market_waypoints_paths"].append(String(get_tree().root.get_path_to(wp)))
							emp_copy["active_commercial_route"] = serialized_route
					serialized_emps.append(emp_copy)
				data["hired_employees"] = serialized_emps
			if "hireable_candidates" in node:
				var serialized_cands = []
				for cand in node.hireable_candidates:
					if is_instance_valid(cand):
						serialized_cands.append(cand.npc_name)
				data["hireable_candidates"] = serialized_cands
				
			var sbox = node.get_node_or_null("StrongboxComponent")
			if sbox:
				data["strongbox_gold"] = sbox.strongbox_gold
				data["transaction_ledger"] = sbox.transaction_ledger
			
			if "inventory" in node and node.inventory:
				var market_inv = []
				for slot in node.inventory.slots:
					if slot.get("item"):
						market_inv.append({
							"item_path": slot["item"].resource_path,
							"amount": slot["amount"]
						})
				data["inventory"] = market_inv
				
			if "building_storage" in node and node.building_storage:
				var storage_inv = []
				for slot in node.building_storage.slots:
					if slot.get("item"):
						storage_inv.append({
							"item_path": slot["item"].resource_path,
							"amount": slot["amount"]
						})
				data["building_storage"] = storage_inv

			if "daily_production" in node:
				data["daily_production"] = node.daily_production
			if "lifetime_production" in node:
				data["lifetime_production"] = node.lifetime_production
				
			if "custom_prices" in node:
				data["custom_prices"] = node.custom_prices
				
			if "building_level" in node:
				data["building_level"] = node.building_level
			if "is_upgrading" in node:
				data["is_upgrading"] = node.is_upgrading
				data["upgrade_timer"] = node.upgrade_timer
			if "improvements" in node:
				data["improvements"] = node.improvements
				
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
		
	var npcs_data = []
	for npc in get_tree().get_nodes_in_group("NPCs"):
		if is_instance_valid(npc) and npc is NPCAIController:
			if npc.get("roams_interior_only") or npc.get("is_quest_npc"):
				continue
			var npc_dict = {
				"npc_name": npc.npc_name,
				"position": [npc.global_position.x, npc.global_position.y],
				"province": npc.province,
				"career": npc.career,
				"skills_data": npc.skills_data,
				"salary": npc.salary,
				"speed": npc.speed,
				"productivity": npc.productivity,
				"is_hired": npc.is_hired,
				"worker_state": npc.worker_state,
				"npc_type": npc.npc_type,
				"quest_npc_id": npc.quest_npc_id,
			}
			if npc.has_node("EquipmentComponent"):
				npc_dict["equipment"] = npc.get_node("EquipmentComponent").serialize()
			if npc.is_hired and is_instance_valid(npc.hired_by_building):
				npc_dict["hired_by_building_path"] = String(get_tree().root.get_path_to(npc.hired_by_building))
			npcs_data.append(npc_dict)
		
	# Update relationship_db from active NPCs in the scene tree
	for npc in get_tree().get_nodes_in_group("RelationNPCs"):
		if is_instance_valid(npc) and npc.has_node("RelationshipComponent"):
			var rel = npc.get_node("RelationshipComponent")
			relationship_db[npc.quest_npc_id] = rel.get_save_data()

	var save_dict = {
		"player": {
			"player_name": player_name,
			"rival_ai_active": rival_ai_active,
			"gold": gold,
			"bank_balance": bank_balance,
			"influence": influence,
			"permanent_influence": permanent_influence,
			"title_level": title_level,
			"position": [player_pos.x, player_pos.y],
			"careers": career_levels,
			"xp": career_xp,
			"inventory": player_inv,
			"equipment": player.get_node("EquipmentComponent").serialize() if player and player.has_node("EquipmentComponent") else {}
		},
		"time": {
			"minutes": time_minutes,
			"hours": time_hours,
			"days": time_days
		},
		"buildings": buildings_data,
		"doors": doors_data,
		"construction_sites": construction_data,
		"npcs": npcs_data,
		"interiors": {
			"allocated": allocated_interiors,
			"next_index": next_interior_index
		},
		"quests": QuestManager.get_save_data(),
		"relationships": relationship_db,
		"is_married": is_married,
		"spouse_npc_id": spouse_npc_id,
		"completed_relation_quests": completed_relation_quests
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
	player_name = p_data.get("player_name", "Player")
	rival_ai_active = p_data.get("rival_ai_active", true)
	gold = p_data.get("gold", 1000)
	bank_balance = p_data.get("bank_balance", 0)
	influence = p_data.get("influence", 150)
	permanent_influence = p_data.get("permanent_influence", 300)
	title_level = p_data.get("title_level", 1)
	career_levels = p_data.get("careers", career_levels)
	career_xp = p_data.get("xp", career_xp)
	
	var int_data = save_dict.get("interiors", {})
	allocated_interiors = int_data.get("allocated", {})
	next_interior_index = int_data.get("next_index", 0)
	
	var t_data = save_dict.get("time", {})
	time_minutes = t_data.get("minutes", 0.0)
	time_hours = t_data.get("hours", 6)
	time_days = t_data.get("days", 1)
	_last_emitted_minute = int(time_minutes)
	time_changed.emit(time_hours, _last_emitted_minute, time_days)
	
	QuestManager.load_save_data(save_dict.get("quests", {}))
	relationship_db = save_dict.get("relationships", {})
	is_married = save_dict.get("is_married", false)
	spouse_npc_id = save_dict.get("spouse_npc_id", "")
	completed_relation_quests = save_dict.get("completed_relation_quests", [])
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var pos_arr = p_data.get("position", [500.0, 300.0])
		player.global_position = Vector2(pos_arr[0], pos_arr[1])
		if player.has_node("EquipmentComponent") and p_data.has("equipment"):
			player.get_node("EquipmentComponent").deserialize(p_data["equipment"])
			player.recalculate_equipment_stats()
		if "interactables_in_range" in player:
			player.interactables_in_range.clear()
			player.interactables_changed.emit()
		
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			camera.reset_smoothing()
			
	if player_inventory:
		player_inventory.clear()
		for slot in p_data.get("inventory", []):
			var path = slot.get("item_path", "")
			var amount = slot.get("amount", 0)
			if path != "" and amount > 0:
				var item = load(path)
				if item:
					player_inventory.add_item(item, amount)

	# Clear all physical NPC instances to avoid duplicates before restoring them
	for npc in get_tree().get_nodes_in_group("NPCs"):
		if is_instance_valid(npc):
			npc.queue_free()
			
	var groups_to_clear = ["Beds", "MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "Mills", "Smelters", "Looms", "WheatFields", "CottonPlants", "ConstructionSites", "Houses", "Banks", "Inns", "PaperMakers", "PrintingPresses", "Bakeries", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
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
			
		var parent_node = null
		if parent_path != "":
			parent_node = get_tree().root.get_node_or_null(parent_path)
		if not parent_node and player:
			parent_node = player.get_parent()
			
		var node = null
		var is_new = false
		if path == "res://components/market/market_stall.tscn" and parent_node:
			if parent_node.has_node("StorefrontStall"):
				node = parent_node.get_node("StorefrontStall")
			elif parent_node.has_node("StorageChest"):
				node = parent_node.get_node("StorageChest")
			else:
				var scene = load(path)
				if not scene:
					continue
				node = scene.instantiate() as Node2D
				is_new = true
		elif path == "res://components/crafting/crafting_bench.tscn" and parent_node:
			if parent_node.has_node("CraftingBench"):
				node = parent_node.get_node("CraftingBench")
			else:
				var scene = load(path)
				if not scene:
					continue
				node = scene.instantiate() as Node2D
				is_new = true
		else:
			var scene = load(path)
			if not scene:
				continue
			node = scene.instantiate() as Node2D
			is_new = true
			
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
				
		if "hired_employees" in node and b_data.has("hired_employees"):
			var emps = b_data["hired_employees"]
			for emp in emps:
				if emp.has("active_commercial_route") and emp["active_commercial_route"] != null:
					var route_dict = emp["active_commercial_route"]
					if route_dict.get("is_global_logistics", false) == true:
						var route = load("res://components/production/global_logistics_route.gd").new()
						route.route_name = route_dict.get("route_name", "Route")
						var stops: Array[Resource] = []
						for stop_data in route_dict.get("route_stops", []):
							var stop = load("res://components/production/trade_route_stop.gd").new()
							var b_path = stop_data.get("target_building_path", "")
							if b_path != "":
								stop.target_building = get_tree().root.get_node_or_null(b_path)
							stop.action_type = stop_data.get("action_type", "LOAD")
							stop.item_id = stop_data.get("item_id", "")
							stop.target_quantity = int(stop_data.get("target_quantity", 20))
							stops.append(stop)
						route.route_stops = stops
						emp["active_commercial_route"] = route
					else:
						# Skip legacy route deserialization
						print("[GameState] Skipping legacy commercial route deserialization (deleted file).")
			node.hired_employees = emps
		if "hireable_candidates" in node and b_data.has("hireable_candidates"):
			node.hireable_candidates = b_data["hireable_candidates"]
			
		var sbox = ensure_strongbox(node)
		if sbox:
			sbox.strongbox_gold = int(b_data.get("strongbox_gold", 0))
			sbox.transaction_ledger = b_data.get("transaction_ledger", [])
		
		if is_new:
			if parent_node:
				parent_node.add_child(node)
			else:
				get_tree().root.add_child(node)
			
		if "inventory" in node and node.inventory:
			var inv_data = b_data.get("inventory", [])
			node.inventory.clear()
			for slot in inv_data:
				var item_path = slot.get("item_path", "")
				var amount = slot.get("amount", 0)
				if item_path != "" and amount > 0:
					var item = load(item_path)
					if item:
						node.inventory.add_item(item, amount)
		if "building_storage" in node and node.building_storage:
			var storage_data = b_data.get("building_storage", [])
			node.building_storage.clear()
			for slot in storage_data:
				var item_path = slot.get("item_path", "")
				var amount = slot.get("amount", 0)
				if item_path != "" and amount > 0:
					var item = load(item_path)
					if item:
						node.building_storage.add_item(item, amount)
		if "daily_production" in node and b_data.has("daily_production"):
			node.daily_production = b_data["daily_production"]
		if "lifetime_production" in node and b_data.has("lifetime_production"):
			node.lifetime_production = b_data["lifetime_production"]
		if "custom_prices" in node:
			node.custom_prices = b_data.get("custom_prices", {})
			
		if "building_level" in node:
			node.building_level = int(b_data.get("building_level", 1))
		if "is_upgrading" in node:
			node.is_upgrading = b_data.get("is_upgrading", false)
			node.upgrade_timer = float(b_data.get("upgrade_timer", 0.0))
		if "improvements" in node:
			node.improvements = b_data.get("improvements", {
				"storage_vault": 0,
				"deep_shelving": 0,
				"extra_workbench": 0,
				"bunkhouse": 0,
				"iron_reinforcements": 0,
				"ornate_facade": 0
			})
			if node.has_method("recalculate_building_parameters"):
				node.recalculate_building_parameters()
							
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
			
	# Restore all persistent NPCs
	var npc_scene = load("res://entities/npc/npc.tscn")
	var npcs_list = save_dict.get("npcs", [])
	
	# Keep a lookup table of spawned NPCs by name
	var spawned_npcs = {}
	
	for n_data in npcs_list:
		if not npc_scene:
			continue
		var npc = npc_scene.instantiate() as CharacterBody2D
		# Set is_loaded flag to prevent ready randomization
		npc.set("is_loaded", true)
		
		# Set basic properties
		npc.npc_name = n_data.get("npc_name", "")
		var pos_arr = n_data.get("position", [0.0, 0.0])
		npc.global_position = Vector2(pos_arr[0], pos_arr[1])
		npc.province = n_data.get("province", "Unknown Province")
		npc.career = n_data.get("career", "patreon")
		npc.skills_data = n_data.get("skills_data", {})
		npc.salary = int(n_data.get("salary", 15))
		npc.speed = float(n_data.get("speed", 50.0))
		npc.is_hired = n_data.get("is_hired", false)
		npc.worker_state = n_data.get("worker_state", "idle_at_workshop")
		npc.npc_type = int(n_data.get("npc_type", 0))
		npc.quest_npc_id = n_data.get("quest_npc_id", "")
		# Add child to current world scene parent (which is parent of player)
		if player:
			player.get_parent().add_child(npc)
		else:
			get_tree().root.add_child(npc)
			
		if npc.has_node("EquipmentComponent") and n_data.has("equipment"):
			npc.get_node("EquipmentComponent").deserialize(n_data["equipment"])
			npc.recalculate_equipment_stats()
			
		spawned_npcs[npc.npc_name] = npc
		
		# If hired, wire up back-references
		if npc.is_hired and n_data.has("hired_by_building_path"):
			var b_path = n_data["hired_by_building_path"]
			var building = get_tree().root.get_node_or_null(b_path)
			if is_instance_valid(building):
				npc.hired_by_building = building
				
				# Link this physical NPC reference inside the building's hired_employees dictionary
				if "hired_employees" in building:
					for emp in building.hired_employees:
						if emp.get("name") == npc.npc_name:
							emp["npc_ref"] = npc
							if emp.get("active_commercial_route") != null:
								var route = emp["active_commercial_route"]
								npc.active_commercial_route = route
								
								if route.get("route_stops") != null:
									npc.current_stop_index = int(emp.get("current_stop_index", 0))
									if npc.cargo_inventory:
										npc.cargo_inventory.clear()
										if emp.has("cargo_inventory"):
											for slot_data in emp["cargo_inventory"]:
												var res = load(slot_data["item_path"])
												if res:
													npc.cargo_inventory.add_item(res, int(slot_data["amount"]))
									
									if npc.worker_state == "internal_route_transit":
										var idx = npc.current_stop_index
										if idx < route.route_stops.size():
											var stop = route.route_stops[idx]
											if stop and is_instance_valid(stop.target_building):
												var target_pos = stop.target_building.get_interaction_position() if stop.target_building.has_method("get_interaction_position") else stop.target_building.global_position
												if npc.nav_motor and is_instance_valid(npc.nav_motor.nav_agent):
													npc.nav_motor.nav_agent.target_position = target_pos
												else:
													npc.call("_generate_path", target_pos)
								else:
									npc.commercial_route_current_waypoint_index = int(emp.get("commercial_route_current_waypoint_index", 0))
									npc.commercial_route_cargo_item_id = emp.get("commercial_route_cargo_item_id", "")
									npc.commercial_route_cargo_amount = int(emp.get("commercial_route_cargo_amount", 0))
									npc.commercial_route_gold_carried = int(emp.get("commercial_route_gold_carried", 0))
									
									if npc.worker_state == "commercial_route_transit":
										var idx = npc.commercial_route_current_waypoint_index
										if npc.active_commercial_route and idx < npc.active_commercial_route.market_waypoints.size():
											var wp = npc.active_commercial_route.market_waypoints[idx]
											if is_instance_valid(wp):
												var target_pos = wp.global_position
												if wp.has_method("get_interaction_position"):
													target_pos = wp.get_interaction_position()
												
												if npc.nav_motor and is_instance_valid(npc.nav_motor.nav_agent):
													npc.nav_motor.nav_agent.target_position = target_pos
												else:
													npc.call("_generate_path", target_pos)
									elif npc.worker_state in ["commercial_route_returning", "commercial_route_loading"]:
										if is_instance_valid(npc.hired_by_building):
											var target_pos = npc.hired_by_building.get_interaction_position()
											if npc.nav_motor and is_instance_valid(npc.nav_motor.nav_agent):
												npc.nav_motor.nav_agent.target_position = target_pos
											else:
												npc.call("_generate_path", target_pos)
							break

	# Restore candidates reference for all buildings
	for group_name in groups_to_clear:
		for building in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(building) and "hireable_candidates" in building:
				var restored_cands = []
				for cand_item in building.hireable_candidates:
					if cand_item is String:
						if spawned_npcs.has(cand_item):
							restored_cands.append(spawned_npcs[cand_item])
					elif is_instance_valid(cand_item):
						restored_cands.append(cand_item)
				building.hireable_candidates = restored_cands

	recalculate_career_stats()
	print("[GameState] Game Loaded from user://savegame.json")
	spawn_ui_floating_text("Game Loaded!")




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

# --- Road Navigation Network ---
var road_astar: AStar2D = AStar2D.new()
var road_points_map: Dictionary = {}
var is_baking: bool = false
var _bake_queued: bool = false

func rebuild_road_network() -> void:
	road_astar.clear()
	road_points_map.clear()
	
	var step_size = 64.0
	var points_to_connect = []
	
	# Gather road segments
	var roads = get_tree().get_nodes_in_group("Roads")
	for road in roads:
		var size = road.size if "size" in road else Vector2(64, 64)
		var half_size = size / 2.0
		var pos = road.global_position
		
		# Subdivide road segment into 64x64 grids
		var start_x = -half_size.x + step_size / 2.0
		var end_x = half_size.x
		var start_y = -half_size.y + step_size / 2.0
		var end_y = half_size.y
		
		var x = start_x
		while x < end_x:
			var y = start_y
			while y < end_y:
				var grid_pos = pos + Vector2(x, y)
				var snapped_pos = Vector2(
					round(grid_pos.x / 16.0) * 16.0,
					round(grid_pos.y / 16.0) * 16.0
				)
				if not snapped_pos in points_to_connect:
					points_to_connect.append(snapped_pos)
				y += step_size
			x += step_size
			
	# Gather plazas
	var plazas = get_tree().get_nodes_in_group("Plazas")
	for plaza in plazas:
		var size = plaza.size if "size" in plaza else Vector2(128, 128)
		var half_size = size / 2.0
		var pos = plaza.global_position
		
		var start_x = -half_size.x + step_size / 2.0
		var end_x = half_size.x
		var start_y = -half_size.y + step_size / 2.0
		var end_y = half_size.y
		
		var x = start_x
		while x < end_x:
			var y = start_y
			while y < end_y:
				var grid_pos = pos + Vector2(x, y)
				var snapped_pos = Vector2(
					round(grid_pos.x / 16.0) * 16.0,
					round(grid_pos.y / 16.0) * 16.0
				)
				if not snapped_pos in points_to_connect:
					points_to_connect.append(snapped_pos)
				y += step_size
			x += step_size
			
	# Gather market stalls to integrate them into the road network so NPCs can navigate to them
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	var stall_positions = []
	for stall in stalls:
		if is_instance_valid(stall):
			var pos = stall.global_position
			var snapped_pos = Vector2(
				round(pos.x / 16.0) * 16.0,
				round(pos.y / 16.0) * 16.0
			)
			if not snapped_pos in points_to_connect:
				points_to_connect.append(snapped_pos)
			if not snapped_pos in stall_positions:
				stall_positions.append(snapped_pos)

	# Add points to AStar
	var point_id = 0
	for pos in points_to_connect:
		road_astar.add_point(point_id, pos)
		road_points_map[pos] = point_id
		point_id += 1
		
	# Connect adjacent points within 92.0 pixels
	for i in range(points_to_connect.size()):
		var pos_a = points_to_connect[i]
		var id_a = road_points_map[pos_a]
		for j in range(i + 1, points_to_connect.size()):
			var pos_b = points_to_connect[j]
			var id_b = road_points_map[pos_b]
			if pos_a.distance_to(pos_b) <= 92.0:
				road_astar.connect_points(id_a, id_b)

	# Ensure every stall is connected to the nearest road/plaza point to prevent navigation isolation
	for stall_pos in stall_positions:
		var stall_id = road_points_map[stall_pos]
		var connections = road_astar.get_point_connections(stall_id)
		if connections.is_empty():
			var closest_dist = INF
			var closest_id = -1
			for pos in points_to_connect:
				if pos == stall_pos or pos in stall_positions:
					continue
				var dist = stall_pos.distance_to(pos)
				if dist < closest_dist:
					closest_dist = dist
					closest_id = road_points_map[pos]
			if closest_id != -1:
				road_astar.connect_points(stall_id, closest_id)

	print("[RoadNavigation] Rebuilt network with %d points." % road_astar.get_point_count())

func get_road_path(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	if road_astar.get_point_count() == 0:
		return [to_pos]
		
	var from_id = road_astar.get_closest_point(from_pos)
	var to_id = road_astar.get_closest_point(to_pos)
	
	var path_points = road_astar.get_point_path(from_id, to_id)
	var final_path: Array[Vector2] = []
	
	for p in path_points:
		final_path.append(p)
		
	return final_path


func rebake_all_navigation_regions() -> void:
	if is_baking:
		_bake_queued = true
		return
		
	is_baking = true
	_bake_queued = false
	
	# Await a physics frame to ensure all colliders are registered in the physics server
	await get_tree().physics_frame
	
	# Dynamically gather all building/obstacle nodes and add them to the carving group
	var obstacle_groups = ["MarketStall", "Houses", "Bakeries", "Smelters", "Inns", "PrintingPresses", "PaperMakers", "Looms", "Mills", "Banks", "CraftingBenches", "OreMines", "WheatFields", "CottonPlants", "ConstructionSites"]
	for grp in obstacle_groups:
		for node in get_tree().get_nodes_in_group(grp):
			if node is Node2D and not node.is_in_group("nav_carve_obstacles"):
				node.add_to_group("nav_carve_obstacles")
	
	# Rebake global ground region (async background thread)
	var global_navs = get_tree().get_nodes_in_group("GlobalNavRegion")
	for region in global_navs:
		if region is NavigationRegion2D:
			region.bake_navigation_polygon(true)
			
	# Rebake road regions (async background thread)
	var roads = get_tree().get_nodes_in_group("Roads")
	for road in roads:
		var region = road.get_node_or_null("RoadNavRegion")
		if region is NavigationRegion2D:
			region.bake_navigation_polygon(true)
			
	# Rebake plaza regions (async background thread)
	var plazas = get_tree().get_nodes_in_group("Plazas")
	for plaza in plazas:
		var region = plaza.get_node_or_null("PlazaNavRegion")
		if region is NavigationRegion2D:
			region.bake_navigation_polygon(true)
			
	# Give the server a moment to finish the thread before dropping the lock
	await get_tree().physics_frame
	is_baking = false
	print("[RoadNavigation] Rebaked all navigation regions (ground, roads, plazas) async using nav_carve_obstacles group.")
	
	if _bake_queued:
		rebake_all_navigation_regions()


# Alerts System
signal alert_added(alert_data: Dictionary)
signal alert_removed(alert_id: String)

var active_alerts: Array = []
var past_alerts: Array = []

func add_alert(title: String, description: String, alert_type: String, building_ref: Node2D = null) -> void:
	# Avoid duplicate active alerts for the same building and title
	for active in active_alerts:
		if active.title == title and active.description == description:
			return
			
	var time_str = ""
	# Find TimeCycleModulate node in the scene tree
	var time_cycle = get_tree().get_first_node_in_group("TimeCycle")
	if not time_cycle:
		# Check by class/type or name
		for node in get_tree().get_nodes_in_group("TimeCycleModulate"):
			time_cycle = node
			break
	if not time_cycle:
		time_cycle = get_tree().current_scene.find_child("TimeCycleModulate", true, false)
		
	if time_cycle and "current_day" in time_cycle:
		time_str = "Day %d - %02d:%02d" % [time_cycle.current_day, time_cycle.current_hour, time_cycle.current_minute]
	else:
		var dt = Time.get_time_dict_from_system()
		time_str = "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]
		
	var alert_id = "alert_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var alert_data = {
		"id": alert_id,
		"title": title,
		"description": description,
		"type": alert_type, # "warning", "info", "danger"
		"time": time_str,
		"building": building_ref
	}
	
	active_alerts.append(alert_data)
	past_alerts.insert(0, alert_data)
	
	alert_added.emit(alert_data)

func remove_alert(alert_id: String) -> void:
	for i in range(active_alerts.size()):
		if active_alerts[i].id == alert_id:
			active_alerts.remove_at(i)
			alert_removed.emit(alert_id)
			break



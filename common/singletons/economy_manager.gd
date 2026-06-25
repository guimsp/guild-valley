extends Node

enum ProfessionType { PATREON, CRAFTSMAN, WOODWORKER, TAILOR, HERBALIST, SCHOLAR, ROGUE, SHOWMAN }
enum ServiceType { BASIC, MANDATORY_INPUT, DYNAMIC_BOOST }

const PROFESSION_PROFILES: Dictionary = {
	ProfessionType.PATREON: { "labor_base": 0.2, "time_mult": 2.0, "floor_mult": 8.0, "base_stock": 100, "scalar": 1.15 },
	ProfessionType.CRAFTSMAN: { "labor_base": 0.6, "time_mult": 6.0, "floor_mult": 15.0, "base_stock": 40, "scalar": 1.40 },
	ProfessionType.WOODWORKER: { "labor_base": 0.4, "time_mult": 4.0, "floor_mult": 12.0, "base_stock": 60, "scalar": 1.25 },
	ProfessionType.TAILOR: { "labor_base": 0.3, "time_mult": 3.0, "floor_mult": 10.0, "base_stock": 80, "scalar": 1.20 },
	ProfessionType.HERBALIST: { "labor_base": 0.5, "time_mult": 3.5, "floor_mult": 11.0, "base_stock": 50, "scalar": 1.35 },
	ProfessionType.SCHOLAR: { "labor_base": 1.0, "time_mult": 8.0, "floor_mult": 25.0, "base_stock": 30, "scalar": 1.75 },
	ProfessionType.ROGUE: { "labor_base": 0.8, "time_mult": 5.0, "floor_mult": 18.0, "base_stock": 45, "scalar": 1.50 },
	ProfessionType.SHOWMAN: { "labor_base": 0.8, "time_mult": 4.0, "floor_mult": 20.0, "base_stock": 30, "scalar": 1.60 }
}

const CAREER_TO_PROFESSION: Dictionary = {
	"patreon": ProfessionType.PATREON,
	"craftsman": ProfessionType.CRAFTSMAN,
	"woodworker": ProfessionType.WOODWORKER,
	"tailor": ProfessionType.TAILOR,
	"herbalist": ProfessionType.HERBALIST,
	"scholar": ProfessionType.SCHOLAR,
	"rogue": ProfessionType.ROGUE,
	"showman": ProfessionType.SHOWMAN
}

# Dictionary of item_id (String) -> ItemData
var item_database: Dictionary = {}
var item_career_map: Dictionary = {}
var recipes_database: Dictionary = {} # output_item.id -> Recipe

var trade_activity: Dictionary = {}
var guild_stabilization_timer: float = 0.0
const GUILD_STABILIZATION_INTERVAL: float = 120.0

var _visiting_items: Dictionary = {}

# Queue of pending search query requests:
# Each entry is a Dictionary: { "npc": CharacterBody2D, "item_id": String, "callback": Callable }
var query_queue: Array[Dictionary] = []

# Global toggle to show floating debug emotes above NPCs (for testing purposes)
var show_debug_emotes: bool = true

func _ready() -> void:
	# Load all items on launch
	_load_item_database()
	if GameState:
		if not TimeManager.time_changed.is_connected(_on_time_changed):
			TimeManager.time_changed.connect(_on_time_changed)

func _physics_process(delta: float) -> void:
	guild_stabilization_timer += delta
	if guild_stabilization_timer >= GUILD_STABILIZATION_INTERVAL:
		guild_stabilization_timer = 0.0
		_run_guild_stabilization()
		
	# Stagger shop queries: process a maximum of 5 requests per frame
	var processed_count = 0
	while processed_count < 5 and not query_queue.is_empty():
		var request = query_queue.pop_front()
		if is_instance_valid(request.npc):
			_resolve_shop_query(request.npc, request.item_id, request.callback)
		processed_count += 1

# Queue a search check
func request_shop_search(npc: CharacterBody2D, item_id: String, callback: Callable) -> void:
	# Avoid duplicate queuing for the same NPC and item ID
	for request in query_queue:
		if request.npc == npc and request.item_id == item_id:
			return
	
	query_queue.append({
		"npc": npc,
		"item_id": item_id,
		"callback": callback
	})

# Load all ItemData resources recursively
func _load_item_database() -> void:
	item_database.clear()
	var base_path = "res://common/items/instances/"
	_scan_item_dir_recursive(base_path)
	_build_item_career_map()
	print("[EconomyManager] Successfully initialized item database with %d items." % item_database.size())

func _scan_item_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_scan_item_dir_recursive(path + file_name + "/")
			else:
				var clean_name = file_name
				if clean_name.ends_with(".remap"):
					clean_name = clean_name.replace(".remap", "")
				if clean_name.ends_with(".tres"):
					var res = load(path + clean_name)
					if res and res is ItemData:
						item_database[res.id] = res
			file_name = dir.get_next()
		dir.list_dir_end()

func _build_item_career_map() -> void:
	item_career_map.clear()
	recipes_database.clear()
	var dir_path = "res://common/items/recipes/"
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
					if res and res is Recipe:
						if res.output_item:
							item_career_map[res.output_item.id] = res.required_career
							recipes_database[res.output_item.id] = res
			file_name = dir.get_next()
		dir.list_dir_end()
		print("[EconomyManager] Built recipe-to-career registry with %d items and %d recipes." % [item_career_map.size(), recipes_database.size()])

func get_item_career(item_id: String) -> String:
	if item_career_map.has(item_id):
		return item_career_map[item_id]
		
	# Fallback for raw materials/gatherable resources
	var raw_material_careers = {
		"wheat": "patreon",
		"barley_and_hops": "patreon",
		"grapes": "patreon",
		"apple": "patreon",
		"sugar": "patreon",
		"egg": "patreon",
		"milk": "patreon",
		"honey": "patreon",
		"water": "patreon",
		"berries": "patreon",
		"venison": "patreon",
		"cotton": "tailor",
		"iron_ore": "craftsman",
		"standard_timber": "craftsman"
	}
	return raw_material_careers.get(item_id, "patreon")

func _resolve_shop_query(npc: CharacterBody2D, item_id: String, callback: Callable) -> void:
	# Check if item exists in database
	if not item_database.has(item_id):
		push_warning("[EconomyManager] Item ID '%s' not found in database!" % item_id)
		callback.call(null)
		return
		
	var item_data: ItemData = item_database[item_id]
	var npc_settlement = GameState.get_nearest_settlement(npc)
	if not npc_settlement:
		callback.call(null)
		return
		
	# 1. Filter candidates: stocking requested Item ID, active, same town/city
	var candidates: Array[CollisionObject2D] = []
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	
	for stall in stalls:
		if not is_instance_valid(stall) or not stall.inventory:
			continue
			
		# Check settlement match
		var stall_settlement = GameState.get_nearest_settlement(stall)
		if stall_settlement != npc_settlement:
			continue
			
		# Exclude Warehouses from ambient retail shopping queries
		if stall.is_in_group("Warehouses") or (stall.get("parent_building") != null and stall.parent_building.is_in_group("Warehouses")):
			continue
			
		# Exclude audited stalls
		if stall.get("is_under_audit") == true or (stall.get("parent_building") != null and stall.parent_building.get("is_under_audit") == true):
			continue
			
		# Check if shop stocks the exact item ID (personal/private shops and workshops must have real stock)
		var is_public_market_stall = (stall is MarketStall) and (stall.ownership_type == "Public")
		if not is_public_market_stall:
			if stall.inventory.get_item_amount(item_id) <= 0:
				continue
			
		candidates.append(stall)
		
	if candidates.is_empty():
		# Save empty decision breakdown for debug purposes
		_save_empty_decision(npc, item_id)
		callback.call(null)
		return
		
	# 2. Gather candidates' price and distance to normalize them
	var min_price = INF
	var max_price = -INF
	var min_dist = INF
	var max_dist = -INF
	
	var candidates_raw_data = []
	for stall in candidates:
		var price = stall.get_buy_price(item_data)
		var dist = npc.global_position.distance_to(stall.global_position)
		
		min_price = min(min_price, price)
		max_price = max(max_price, price)
		min_dist = min(min_dist, dist)
		max_dist = max(max_dist, dist)
		
		candidates_raw_data.append({
			"stall": stall,
			"price": price,
			"dist": dist
		})
		
	# 3. Retrieve social class weights
	var weights = npc.profile.get_decision_weights()
	var w_price = weights.get("price", 0.50)
	var w_attractiveness = weights.get("attractiveness", 0.30)
	var w_employee_skill = weights.get("employee_skill", 0.10)
	var w_randomness = weights.get("randomness", 0.10)
	
	var best_stall: CollisionObject2D = null
	var best_utility = -INF
	
	# Prepare decision breakdown log
	var decision_breakdown = {
		"item_id": item_id,
		"timestamp_hours": TimeManager.time_hours,
		"timestamp_minutes": int(TimeManager.time_minutes),
		"timestamp_days": TimeManager.time_days,
		"candidates": []
	}
	
	# 4. Evaluate normalized utility scores
	for data in candidates_raw_data:
		var stall: CollisionObject2D = data.stall
		var price: int = data.price
		var dist: float = data.dist
		
		# Normalize price: lower is better (cheapest shop gets 1.0, most expensive gets 0.0 or close)
		# Using inverse price ratio relative to min_price
		var price_score = 1.0
		if price > 0:
			price_score = min_price / float(price)
			
		# Proximity score (closer distance yields higher score)
		var proximity_score = 1.0
		# Proximity decay curve: 1.0 at distance 0, decaying down to 0 at 1000 pixels
		proximity_score = clamp(1.0 - dist / 1000.0, 0.0, 1.0)
		
		# Shop attractiveness (starts at 10, max 100)
		var attractiveness_val = stall.get_shop_attractiveness()
		# Normalize to 0.0 - 1.0 range
		var shop_attractiveness_score = clamp(float(attractiveness_val - 10) / 90.0, 0.0, 1.0)
		
		# Total Attractiveness score (80% shop-specific, 20% proximity)
		var attractiveness_score = 0.8 * shop_attractiveness_score + 0.2 * proximity_score
		
		# Employee skill rating (0.0 to 1.0, defaults to 0.2 if no employees / standalone stall)
		var employee_skill_score = 0.2
		var emp_source = stall
		if stall.get("parent_building") != null:
			emp_source = stall.parent_building
		if "hired_employees" in emp_source:
			var employees: Array = emp_source.hired_employees
			if not employees.is_empty():
				var skill_sum = 0.0
				for emp in employees:
					skill_sum += emp.get("skill", 0.5)
				employee_skill_score = skill_sum / employees.size()
				
		# Random noise
		var random_noise = randf()
		
		# Weighted Utility Score
		var utility = (w_price * price_score) + (w_attractiveness * attractiveness_score) + (w_employee_skill * employee_skill_score) + (w_randomness * random_noise)
		
		# Log parameters for debugging
		var shop_name = ""
		if stall.get("parent_building") != null:
			var parent = stall.parent_building
			shop_name = parent.custom_name if parent.get("custom_name") != "" else parent.name
		elif stall.get("custom_name") != null and stall.get("custom_name") != "":
			shop_name = stall.custom_name
		elif stall.get("market_name") != null and stall.get("market_name") != "":
			shop_name = stall.market_name
		else:
			shop_name = stall.name
			
		var breakdown_entry = {
			"shop_name": shop_name,
			"price": price,
			"distance": dist,
			"price_score": price_score,
			"proximity_score": proximity_score,
			"attractiveness_score": attractiveness_score,
			"employee_skill": employee_skill_score,
			"random_noise": random_noise,
			"utility": utility,
			"is_winner": false
		}
		decision_breakdown["candidates"].append(breakdown_entry)
		
		if utility > best_utility:
			best_utility = utility
			best_stall = stall
			
	# Highlight the winner in log
	if best_stall:
		var best_name = ""
		if best_stall.get("parent_building") != null:
			var parent = best_stall.parent_building
			best_name = parent.custom_name if parent.get("custom_name") != "" else parent.name
		elif best_stall.get("custom_name") != null and best_stall.get("custom_name") != "":
			best_name = best_stall.custom_name
		elif best_stall.get("market_name") != null and best_stall.get("market_name") != "":
			best_name = best_stall.market_name
		else:
			best_name = best_stall.name
			
		for entry in decision_breakdown["candidates"]:
			if entry["shop_name"] == best_name:
				entry["is_winner"] = true
				break
				
	# Save breakdown log on the NPC node for live UI inspection
	if "last_decision_breakdown" in npc:
		npc.last_decision_breakdown = decision_breakdown
	if "decision_history" in npc:
		npc.decision_history.push_front(decision_breakdown.duplicate(true))
		if npc.decision_history.size() > 2:
			npc.decision_history.resize(2)
		
	callback.call(best_stall)

func _save_empty_decision(npc: CharacterBody2D, item_id: String) -> void:
	var decision_breakdown = {
		"item_id": item_id,
		"timestamp_hours": TimeManager.time_hours,
		"timestamp_minutes": int(TimeManager.time_minutes),
		"timestamp_days": TimeManager.time_days,
		"candidates": []
	}
	if "last_decision_breakdown" in npc:
		npc.last_decision_breakdown = decision_breakdown
	if "decision_history" in npc:
		npc.decision_history.push_front(decision_breakdown.duplicate(true))
		if npc.decision_history.size() > 2:
			npc.decision_history.resize(2)

var shortage_days: Dictionary = {} # key: String -> int

func _on_time_changed(hours: int, minutes: int, days: int) -> void:
	if hours == 0 and minutes == 0:
		# Consolidated nightly balancing cycle
		# Phase A: Simulated Background Guild Consumption
		_process_background_guild_consumption()
		# Phase B: Merchant Caravan Safety-Valve (Disabled in favor of real-time passive restock)
		# _process_merchant_caravan_balancing()

func _process_background_guild_consumption() -> void:
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	for stall in stalls:
		if not is_instance_valid(stall) or stall.ownership_type != "Public" or not stall.inventory:
			continue
		for item_id in item_database:
			var item = item_database[item_id]
			# Category: 0 = RAW_MATERIAL, 1 = SEMI_ELABORATE
			if item.get_item_category() == 0 or item.get_item_category() == 1:
				var current_amount = stall.inventory.get_item_amount(item_id)
				if current_amount > 1:
					var pct = randf_range(0.10, 0.25)
					var deduction = int(current_amount * pct)
					if deduction >= current_amount:
						deduction = current_amount - 1
					if deduction > 0:
						stall.inventory.remove_item(item_id, deduction)

func register_trade_activity(stall_path: String, item_id: String) -> void:
	var key = stall_path + ":" + item_id
	trade_activity[key] = true

func _run_guild_stabilization() -> void:
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	var public_stalls: Array = []
	for stall in stalls:
		if is_instance_valid(stall) and stall.ownership_type == "Public" and stall.inventory:
			public_stalls.append(stall)
			
	if public_stalls.is_empty():
		return
		
	for stall in public_stalls:
		var stall_key = String(stall.get_path())
		for item_id in item_database:
			var item = item_database[item_id]
			if not item.is_tradable:
				continue
				
			var act_key = stall_key + ":" + item_id
			if trade_activity.has(act_key):
				trade_activity.erase(act_key)
				continue
				
			var target_mid = stall.target_stock.get(item, item.get_target_stock())
			if stall.has_method("get_target_mid_stock_for"):
				target_mid = stall.call("get_target_mid_stock_for", item)
				
			var min_stock = int(target_mid * 0.25)
			var max_stock = int(target_mid * 2.0)
			var current_stock = stall.inventory.get_item_amount(item_id)
			
			if current_stock < min_stock:
				var target_range_min = int(target_mid * 0.8)
				var target_range_max = int(target_mid * 1.2)
				var nudge_target = randi_range(target_range_min, target_range_max)
				var needed = nudge_target - current_stock
				var small_batch = int(clamp(needed * randf_range(0.15, 0.35), 1.0, needed))
				if small_batch > 0:
					stall.inventory.add_item(item, small_batch)
					print("[EconomyManager] Guild stabilization: added %d %s to %s" % [small_batch, item_id, stall.name])
			elif current_stock > max_stock:
				var target_range_min = int(target_mid * 0.8)
				var target_range_max = int(target_mid * 1.2)
				var nudge_target = randi_range(target_range_min, target_range_max)
				var excess = current_stock - nudge_target
				var small_batch = int(clamp(excess * randf_range(0.15, 0.35), 1.0, excess))
				if small_batch > 0:
					stall.inventory.remove_item(item_id, small_batch)
					print("[EconomyManager] Guild stabilization: removed %d %s from %s" % [small_batch, item_id, stall.name])

func get_algorithmic_craft_time(recipe: Recipe) -> float:
	if not recipe:
		return 5.0
	var L = recipe.required_level
	if recipe.output_item:
		L = recipe.output_item.item_level
	var N = recipe.inputs.size()
	var career = recipe.required_career
	var type = CAREER_TO_PROFESSION.get(career, ProfessionType.PATREON)
	var profile = PROFESSION_PROFILES[type]
	return 5.0 + (L * profile.time_mult) + (N * 4.0)

func get_algorithmic_gathering_time(item_level: int) -> float:
	return 5.0 + (item_level * 3.0)

func evaluate_modifiers(base_val: float, modifiers: Array) -> float:
	var current_val = base_val
	# Apply FLAT modifiers first
	for mod in modifiers:
		if mod and mod.get("type") == StatModifier.ModificationType.FLAT:
			current_val += mod.value
	# Apply MULTIPLIER modifiers second
	for mod in modifiers:
		if mod and mod.get("type") == StatModifier.ModificationType.MULTIPLIER:
			current_val *= mod.value
	return current_val

func is_operation_pristine(recipe: Recipe) -> bool:
	if not recipe:
		return false
	if recipe.output_item and recipe.output_item.item_level >= 6:
		return true
	for input_item in recipe.inputs:
		if input_item and input_item.item_level >= 6:
			return true
	return false

func register_public_stall(stall: MarketStall) -> void:
	pass

func resolve_grand_event(consumed_items: Array, contract_data: Dictionary = {}) -> Dictionary:
	var total_input_value: float = 0.0
	var min_item_level: int = 999
	var max_item_level: int = -999

	for item in consumed_items:
		if item is ItemData:
			total_input_value += float(item.base_value)
			var level: int = item.item_level
			if level < min_item_level:
				min_item_level = level
			if level > max_item_level:
				max_item_level = level

	# Guard against empty arrays
	if min_item_level == 999:
		min_item_level = 1
	if max_item_level == -999:
		max_item_level = 1

	var bad_chance: float = 0.0
	var reg_chance: float = 0.0
	var good_chance: float = 0.0
	var exc_chance: float = 0.0
	var pri_chance: float = 0.0

	if min_item_level >= 5:
		# Profile D
		bad_chance = 0.0
		reg_chance = 0.02
		good_chance = 0.06
		exc_chance = 0.12
		pri_chance = 0.80
	elif min_item_level >= 4:
		# Profile C
		bad_chance = 0.0
		reg_chance = 0.10
		good_chance = 0.15
		exc_chance = 0.25
		pri_chance = 0.50
	elif max_item_level >= 4:
		# Profile B
		bad_chance = 0.20
		reg_chance = 0.40
		good_chance = 0.30
		exc_chance = 0.10
		pri_chance = 0.0
	else:
		# Profile A
		bad_chance = 0.35
		reg_chance = 0.45
		good_chance = 0.20
		exc_chance = 0.0
		pri_chance = 0.0

	var roll: float = randf()
	var outcome_tier: int = 1 # 0=BAD, 1=REGULAR, 2=GOOD, 3=EXCELLENT, 4=PRISTINE

	var cum_bad: float = bad_chance
	var cum_reg: float = cum_bad + reg_chance
	var cum_good: float = cum_reg + good_chance
	var cum_exc: float = cum_good + exc_chance

	if roll < cum_bad:
		outcome_tier = 0
	elif roll < cum_reg:
		outcome_tier = 1
	elif roll < cum_good:
		outcome_tier = 2
	elif roll < cum_exc:
		outcome_tier = 3
	else:
		outcome_tier = 4

	var multiplier: float = 1.00
	var prestige_multiplier: float = 1.00
	
	match outcome_tier:
		0:
			multiplier = 0.50
			prestige_multiplier = 1.00
		1:
			multiplier = 1.00
			prestige_multiplier = 1.00
		2:
			multiplier = 1.30
			prestige_multiplier = 1.00
		3:
			multiplier = 1.75
			prestige_multiplier = 1.50
		4:
			multiplier = 2.50
			prestige_multiplier = 2.50

	var base_reward: float = total_input_value * 1.5
	var final_payout: int = int(round(base_reward * multiplier))

	return {
		"outcome_tier": outcome_tier,
		"payout": final_payout,
		"prestige_multiplier": prestige_multiplier,
		"total_input_value": total_input_value,
		"min_item_level": min_item_level,
		"max_item_level": max_item_level
	}



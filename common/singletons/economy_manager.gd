extends Node

# Dictionary of item_id (String) -> ItemData
var item_database: Dictionary = {}
var item_career_map: Dictionary = {}

# Queue of pending search query requests:
# Each entry is a Dictionary: { "npc": CharacterBody2D, "item_id": String, "callback": Callable }
var query_queue: Array[Dictionary] = []

# Global toggle to show floating debug emotes above NPCs (for testing purposes)
var show_debug_emotes: bool = true

var empty_items_timers: Dictionary = {}

func _ready() -> void:
	# Load all items on launch
	_load_item_database()
	if GameState:
		if not TimeManager.time_changed.is_connected(_on_time_changed):
			TimeManager.time_changed.connect(_on_time_changed)

func _physics_process(delta: float) -> void:
	_process_restock_timers(delta)
	
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
					if res and "output_item" in res and res.output_item and "required_career" in res:
						item_career_map[res.output_item.id] = res.required_career
			file_name = dir.get_next()
		dir.list_dir_end()
		print("[EconomyManager] Built recipe-to-career registry with %d items." % item_career_map.size())

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

func _process_merchant_caravan_balancing() -> void:
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	var public_stalls = []
	for stall in stalls:
		if is_instance_valid(stall) and stall.ownership_type == "Public" and stall.inventory:
			public_stalls.append(stall)
			
	if public_stalls.is_empty():
		return
		
	# Process shortage and glut for each public stall
	for stall in public_stalls:
		var stall_key = String(stall.get_path())
		for item_id in item_database:
			var item = item_database[item_id]
			if not item.is_tradable:
				continue
				
			var target = stall.target_stock.get(item, item.get_target_stock())
			var current_stock = stall.inventory.get_item_amount(item_id)
			
			# 1. Shortage Intervention
			if current_stock < target * 0.25:
				var key = stall_key + ":" + item_id
				var consecutive = shortage_days.get(key, 0) + 1
				shortage_days[key] = consecutive
				if consecutive >= 2:
					var mid_amount = int(target * 0.5)
					var needed = mid_amount - current_stock
					if needed > 0:
						stall.inventory.add_item(item, needed)
						print("[EconomyManager] Caravan shortage intervention: added %d %s to %s" % [needed, item_id, stall.name])
					shortage_days[key] = 0
			else:
				var key = stall_key + ":" + item_id
				shortage_days[key] = 0
				
			# 2. Glut Intervention
			if current_stock > target * 1.5:
				var excess = current_stock - target
				var to_remove = int(excess * 0.5)
				if to_remove > 0:
					stall.inventory.remove_item(item_id, to_remove)
					print("[EconomyManager] Caravan glut intervention: removed %d %s from %s" % [to_remove, item_id, stall.name])
					
	# 3. Market Disruption (Random Oversupply)
	if randf() < 0.20:
		var commodities = []
		for item_id in item_database:
			var item = item_database[item_id]
			var cat = item.get_item_category()
			if cat == 0 or cat == 1:
				commodities.append(item)
		if not commodities.is_empty():
			commodities.shuffle()
			var dump_count = randi_range(1, min(3, commodities.size()))
			for i in range(dump_count):
				var item = commodities[i]
				var target = public_stalls[0].target_stock.get(item, item.get_target_stock())
				var dump_amount = randi_range(int(target * 0.5), int(target * 1.0))
				if dump_amount > 0:
					for stall in public_stalls:
						stall.inventory.add_item(item, dump_amount)
					print("[EconomyManager] Caravan Market Disruption: dumped %d units of %s into public markets!" % [dump_amount, item.id])
					if GameState and GameState.has_method("spawn_ui_floating_text"):
						GameState.spawn_ui_floating_text("Caravan Disruption: Oversupply of %s!" % item.name)

func register_public_stall(stall: MarketStall) -> void:
	if is_instance_valid(stall) and stall.inventory:
		if not stall.inventory.inventory_changed.is_connected(_on_public_stall_inventory_changed.bind(stall)):
			stall.inventory.inventory_changed.connect(_on_public_stall_inventory_changed.bind(stall))
		_check_stall_stock_level(stall)

func _on_public_stall_inventory_changed(stall: MarketStall) -> void:
	_check_stall_stock_level(stall)

func _check_stall_stock_level(stall: MarketStall) -> void:
	if not is_instance_valid(stall) or not stall.inventory:
		return
	if stall.ownership_type != "Public":
		return
	var stall_key = String(stall.get_path())
	for item in stall.target_stock:
		var item_id = item.id
		var key = stall_key + ":" + item_id
		var current_stock = stall.inventory.get_item_amount(item_id)
		
		# If it hits 0 and is not already tracked, start a 1-3 min timer
		if current_stock == 0:
			if not empty_items_timers.has(key):
				var wait_time = randf_range(60.0, 180.0) # 1 to 3 real-time minutes
				empty_items_timers[key] = {
					"stall": stall,
					"item": item,
					"time_left": wait_time
				}
				print("[EconomyManager] Stall %s: item %s is out of stock. Restock scheduled in %.1f seconds." % [stall.name, item_id, wait_time])
		else:
			# If it has a timer and is no longer at 0, check if we should remove it (e.g. player/rival restocked it)
			if empty_items_timers.has(key):
				var target = stall.target_stock.get(item, item.get_target_stock())
				var mid_stock = target * 0.5
				# If stock is now above 20% of mid stock, we can safely clear the replenishment timer
				if current_stock >= max(1, int(mid_stock * 0.20)):
					empty_items_timers.erase(key)
					print("[EconomyManager] Stall %s: item %s restocked externally to %d. Cleared timer." % [stall.name, item_id, current_stock])

func _process_restock_timers(delta: float) -> void:
	var to_erase = []
	for key in empty_items_timers:
		var data = empty_items_timers[key]
		data["time_left"] -= delta
		if data["time_left"] <= 0.0:
			to_erase.append(key)
			_restock_item(data["stall"], data["item"])
			
	for key in to_erase:
		empty_items_timers.erase(key)

func _restock_item(stall: MarketStall, item: ItemData) -> void:
	if not is_instance_valid(stall) or not stall.inventory:
		return
		
	var target = stall.target_stock.get(item, item.get_target_stock())
	var mid_stock = target * 0.5
	var restock_pct = randf_range(0.20, 0.40)
	var restock_amount = max(1, int(mid_stock * restock_pct))
	
	var current_stock = stall.inventory.get_item_amount(item.id)
	if current_stock < restock_amount:
		var needed = restock_amount - current_stock
		stall.inventory.add_item(item, needed)
		print("[EconomyManager] Centrally restocked %d units of %s to %s (current: %d, mid-stock: %f, restock target: %d)." % [needed, item.id, stall.name, current_stock, mid_stock, restock_amount])


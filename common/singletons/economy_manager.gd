extends Node

# Dictionary of item_id (String) -> ItemData
var item_database: Dictionary = {}

# Queue of pending search query requests:
# Each entry is a Dictionary: { "npc": CharacterBody2D, "item_id": String, "callback": Callable }
var query_queue: Array[Dictionary] = []

# Global toggle to show floating debug emotes above NPCs (for testing purposes)
var show_debug_emotes: bool = true

func _ready() -> void:
	# Load all items on launch
	_load_item_database()

func _physics_process(_delta: float) -> void:
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
			
		# Check if shop stocks the exact item ID (personal/private shops must have real stock)
		if stall.ownership_type != "Public":
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
		"timestamp_hours": GameState.time_hours,
		"timestamp_minutes": int(GameState.time_minutes),
		"timestamp_days": GameState.time_days,
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
		"timestamp_hours": GameState.time_hours,
		"timestamp_minutes": int(GameState.time_minutes),
		"timestamp_days": GameState.time_days,
		"candidates": []
	}
	if "last_decision_breakdown" in npc:
		npc.last_decision_breakdown = decision_breakdown
	if "decision_history" in npc:
		npc.decision_history.push_front(decision_breakdown.duplicate(true))
		if npc.decision_history.size() > 2:
			npc.decision_history.resize(2)

class_name NPCProfile
extends Resource

enum SocialClass { PEASANT, CITIZEN, NOBLE }

@export var social_class: SocialClass = SocialClass.PEASANT
@export var shopping_queue: Array[String] = []
@export var shopping_list: Array[String] = []

# Keep demand_profiles dictionary for inspector panel compatibility
@export var demand_profiles: Dictionary = {}

# Active clock elapsed time
@export var current_game_time: float = 0.0

# Dynamic need timestamp tracker: { item_id (String) : target_timestamp (float) }
@export var demand_timers: Dictionary = {}

# Active accumulation tracker: { item_id (String) : count (int) }
@export var demand_accumulation: Dictionary = {}

func get_accumulation(item_id: String) -> int:
	return demand_accumulation.get(item_id, 1)

func set_accumulation(item_id: String, amount: int) -> void:
	demand_accumulation[item_id] = amount
	if demand_profiles.has(item_id):
		demand_profiles[item_id]["accumulation"] = amount

func increment_accumulation(item_id: String) -> void:
	var amt = min(2, demand_accumulation.get(item_id, 1) + 1)
	set_accumulation(item_id, amt)

func reset_accumulation(item_id: String) -> void:
	set_accumulation(item_id, 1)

func set_retry_timer(item_id: String) -> void:
	var duration = randf_range(90.0, 180.0)
	demand_timers[item_id] = current_game_time + duration
	if demand_profiles.has(item_id):
		demand_profiles[item_id]["timer"] = duration

func reset_demand_cooldown(item_id: String) -> void:
	var item = null
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var econ = main_loop.root.get_node_or_null("EconomyManager")
		if econ and econ.item_database.has(item_id):
			item = econ.item_database[item_id]
			
	var cooldown = 1200.0 # Default fallback
	var cooldown_min = 960.0
	var cooldown_max = 1440.0
	if item:
		cooldown = item.base_demand_cooldown
		if cooldown <= 0.0:
			var cat = item.get_item_category()
			if item.is_luxury_product:
				cooldown = 2400.0
			elif item.is_tool:
				cooldown = 1200.0
			elif cat == ItemData.ItemCategory.CONSUMABLE or item.market_category == "Consumables":
				cooldown = 540.0
			else:
				cooldown = 1200.0
		cooldown_min = cooldown * 0.8
		cooldown_max = cooldown * 1.2
		
	var duration = randf_range(cooldown_min, cooldown_max)
	demand_timers[item_id] = current_game_time + duration
	
	if demand_profiles.has(item_id):
		demand_profiles[item_id]["timer"] = duration
		demand_profiles[item_id]["cooldown_min"] = cooldown_min
		demand_profiles[item_id]["cooldown_max"] = cooldown_max
		demand_profiles[item_id]["cooldown_total"] = duration

func trigger_shopping_queue_push(item_id: String) -> void:
	if not (item_id in shopping_queue):
		shopping_queue.append(item_id)

func trigger_shopping_list_push(item_id: String) -> void:
	if not (item_id in shopping_list):
		shopping_list.append(item_id)

func initialize_demands() -> void:
	demand_timers.clear()
	demand_accumulation.clear()
	demand_profiles.clear()
	
	var econ = null
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		econ = main_loop.root.get_node_or_null("EconomyManager")
		
	if not econ or not econ.item_database:
		return
		
	for item_id in econ.item_database:
		var item = econ.item_database[item_id]
		var item_lvl = item.item_level
		var is_eligible = false
		match social_class:
			SocialClass.PEASANT:
				is_eligible = (item_lvl >= 0 and item_lvl <= 2 and item.is_tradable)
			SocialClass.CITIZEN:
				is_eligible = (item_lvl >= 3 and item_lvl <= 5 and item.is_tradable)
			SocialClass.NOBLE:
				is_eligible = (item_lvl >= 6 and item.is_tradable)
				
		if is_eligible:
			demand_accumulation[item_id] = 1
			
			var cooldown = item.base_demand_cooldown
			if cooldown <= 0.0:
				var cat = item.get_item_category()
				if item.is_luxury_product:
					cooldown = 1200.0
				elif item.is_tool:
					cooldown = 600.0
				elif cat == ItemData.ItemCategory.CONSUMABLE or item.market_category == "Consumables":
					cooldown = 180.0
				else:
					cooldown = 600.0
					
			var cooldown_min = cooldown * 0.8
			var cooldown_max = cooldown * 1.2
			
			# Stagger initial timers to distribute demand rushes organically
			var duration = randf_range(0.0, cooldown_max)
			demand_timers[item_id] = current_game_time + duration
			
			demand_profiles[item_id] = {
				"cooldown_min": cooldown_min,
				"cooldown_max": cooldown_max,
				"timer": duration,
				"cooldown_total": cooldown,
				"accumulation": 1
			}

func get_decision_weights() -> Dictionary:
	match social_class:
		SocialClass.PEASANT:
			return {
				"price": 0.45,
				"proximity": 0.35,
				"attractiveness": 0.05,
				"employee_skill": 0.05,
				"randomness": 0.10
			}
		SocialClass.CITIZEN:
			return {
				"price": 0.30,
				"proximity": 0.25,
				"attractiveness": 0.25,
				"employee_skill": 0.10,
				"randomness": 0.10
			}
		SocialClass.NOBLE:
			return {
				"price": 0.15,
				"proximity": 0.20,
				"attractiveness": 0.40,
				"employee_skill": 0.15,
				"randomness": 0.10
			}
	return {
		"price": 0.30,
		"proximity": 0.25,
		"attractiveness": 0.25,
		"employee_skill": 0.10,
		"randomness": 0.10
	}

func tick_demands(delta: float) -> Array[String]:
	current_game_time += delta
	var triggered: Array[String] = []
	for item_id in demand_timers:
		var target_time = demand_timers[item_id]
		var timer_left = max(0.0, target_time - current_game_time)
		
		# Sync timer for UI rendering
		if demand_profiles.has(item_id):
			demand_profiles[item_id]["timer"] = timer_left
			
		if current_game_time >= target_time:
			trigger_shopping_list_push(item_id)
			triggered.append(item_id)
			reset_demand_cooldown(item_id)
	return triggered

func get_class_string() -> String:
	match social_class:
		SocialClass.PEASANT:
			return "Peasant"
		SocialClass.CITIZEN:
			return "Citizen"
		SocialClass.NOBLE:
			return "Noble"
	return "Peasant"

const PROFESSION_TIERS = ["NOVICE", "JOURNEYMAN", "EXPERT", "MASTER"]

static func get_profession_tier(level: int) -> String:
	if level <= 3:
		return "NOVICE"
	elif level <= 6:
		return "JOURNEYMAN"
	elif level <= 9:
		return "EXPERT"
	else:
		return "MASTER"


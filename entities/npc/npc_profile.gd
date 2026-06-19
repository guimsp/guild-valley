class_name NPCProfile
extends Resource

enum SocialClass { PEASANT, CITIZEN, NOBLE }

@export var social_class: SocialClass = SocialClass.PEASANT
@export var shopping_queue: Array[String] = []

# Dictionary of item_id (String) -> Dictionary of cooldown configuration:
# {
#   "cooldown_min": float,
#   "cooldown_max": float,
#   "timer": float,
#   "cooldown_total": float # track total time for UI progress calculations
# }
@export var demand_profiles: Dictionary = {}

func get_decision_weights() -> Dictionary:
	match social_class:
		SocialClass.PEASANT:
			return {
				"price": 0.70,
				"attractiveness": 0.15,
				"employee_skill": 0.05,
				"randomness": 0.10
			}
		SocialClass.CITIZEN:
			return {
				"price": 0.50,
				"attractiveness": 0.30,
				"employee_skill": 0.10,
				"randomness": 0.10
			}
		SocialClass.NOBLE:
			return {
				"price": 0.15,
				"attractiveness": 0.50,
				"employee_skill": 0.25,
				"randomness": 0.10
			}
	return {
		"price": 0.50,
		"attractiveness": 0.30,
		"employee_skill": 0.10,
		"randomness": 0.10
	}

func tick_demands(delta: float) -> Array[String]:
	var triggered: Array[String] = []
	for item_id in demand_profiles:
		var profile = demand_profiles[item_id]
		if not profile.has("timer"):
			var min_c = profile.get("cooldown_min", 30.0)
			var max_c = profile.get("cooldown_max", 60.0)
			var start_c = randf_range(min_c, max_c)
			profile["timer"] = start_c
			profile["cooldown_total"] = start_c
			
		if not profile.has("accumulation"):
			profile["accumulation"] = 1
			
		profile["timer"] -= delta
		if profile["timer"] <= 0.0:
			var min_c = profile.get("cooldown_min", 30.0)
			var max_c = profile.get("cooldown_max", 60.0)
			var next_c = randf_range(min_c, max_c)
			profile["timer"] = next_c
			profile["cooldown_total"] = next_c
			
			if not (item_id in shopping_queue):
				shopping_queue.append(item_id)
				triggered.append(item_id)
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

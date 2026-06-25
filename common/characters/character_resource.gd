class_name CharacterResource
extends Resource

# Base Stats
@export var life_points: int = 100
@export var armor_points: int = 0
@export var base_damage: int = 10
@export var walking_speed: float = 4.0
@export var productivity: float = 1.0
@export var gathering_speed: float = 1.0

# Progression & ID Wrappers
@export var character_id: String = ""
@export var profession_level: int = 1
@export var assigned_workshop_id: String = ""
@export var active_mods: Array[String] = []
@export var daily_wage: int = 0

func get_sum_of_all_base_stats() -> float:
	return float(life_points + armor_points + base_damage) + walking_speed + productivity + gathering_speed

func update_daily_wage(npc_node: Node = null) -> void:
	var base_wage = 8.0
	
	# Scale wage based on career level: +3.5 gold per level
	base_wage += (profession_level - 1) * 3.5
	
	# Default average stats if no NPC node is passed
	var speed_val = 70.0
	var prod_val = 1.0 + (profession_level * 0.02)
	
	if npc_node:
		if "speed" in npc_node:
			speed_val = npc_node.speed
		if "productivity" in npc_node:
			prod_val = npc_node.productivity
			
	var speed_factor = speed_val / 70.0
	var salary_subtotal = base_wage * speed_factor * prod_val
	
	var mods_weight = 0
	# Lookup NPCManager autoload for active mod weights
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var npc_mgr = main_loop.root.get_node_or_null("NPCManager")
		if npc_mgr:
			for trait_id in active_mods:
				var trait_level = 1
				if "_Lvl2" in trait_id:
					trait_level = 2
				elif "_Lvl3" in trait_id:
					trait_level = 3
					
				if "Miracle Artisan" in trait_id:
					mods_weight += trait_level * 8
				elif "Diligent Master" in trait_id or "Fleet-Footed" in trait_id:
					mods_weight += trait_level * 5
				else:
					mods_weight += trait_level * 5
					
	daily_wage = clamp(int(round(salary_subtotal + mods_weight)), 10, 80)

func to_dictionary() -> Dictionary:
	return {
		"id": character_id,
		"level": profession_level,
		"workshop": assigned_workshop_id,
		"traits": active_mods,
		"wage": daily_wage
	}

func from_dictionary(data: Dictionary) -> void:
	character_id = data.get("id", "")
	profession_level = data.get("level", 1)
	assigned_workshop_id = data.get("workshop", "")
	
	var raw_traits = data.get("traits", [])
	active_mods.clear()
	for t in raw_traits:
		active_mods.append(str(t))
		
	daily_wage = data.get("wage", 15)

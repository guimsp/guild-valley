extends Node

const TRAIT_POOL: Array[String] = [
	"Fleet-Footed",
	"Diligent Master",
	"Scythe-Wielder",
	"Miracle Artisan",
	"Scavenger's Eye"
]

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func get_trait_weight(trait_id: String) -> int:
	if "_Lvl3" in trait_id:
		return 90
	elif "_Lvl2" in trait_id:
		return 40
	elif "_Lvl1" in trait_id:
		return 15
	return 0

func generate_character_resource(province_name: String, level: int = 1) -> CharacterResource:
	var char_res = CharacterResource.new()
	char_res.character_id = "char_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 100000)
	char_res.profession_level = level
	
	var p_level: int = 1
	var pm = get_node_or_null("/root/ProsperityManager")
	if pm:
		p_level = pm.get_level_for_prosperity(pm.province_prosperity.get(province_name, 100.0))
		
	var roll: float = randf()
	var trait_count: int = 0
	
	if p_level <= 2:
		if roll <= 0.70:
			trait_count = 0
		elif roll <= 0.95:
			trait_count = 1
		else:
			trait_count = 2
	elif p_level <= 4:
		if roll <= 0.40:
			trait_count = 0
		elif roll <= 0.85:
			trait_count = 1
		else:
			trait_count = 2
	else:
		if roll <= 0.15:
			trait_count = 0
		elif roll <= 0.65:
			trait_count = 1
		else:
			trait_count = 2
			
	var traits: Array[String] = []
	while traits.size() < trait_count:
		var trait_name = TRAIT_POOL.pick_random()
		
		var power_roll = randf()
		var power_lvl = 1
		if power_roll <= 0.70:
			power_lvl = 1
		elif power_roll <= 0.95:
			power_lvl = 2
		else:
			power_lvl = 3
			
		var trait_id = "%s_Lvl%d" % [trait_name, power_lvl]
		if not traits.has(trait_id):
			traits.append(trait_id)
			
	char_res.active_mods = traits
	char_res.update_daily_wage()
	
	return char_res

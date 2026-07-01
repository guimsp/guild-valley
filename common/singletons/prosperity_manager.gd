extends Node

signal prosperity_updated(province: String, value: float)

# Shared Province Prosperity starting values
var province_prosperity: Dictionary = {}

func initialize_prosperity_states(provinces: Array[String]) -> void:
	province_prosperity.clear()
	for prov in provinces:
		province_prosperity[prov] = 100.0

var prosperity_thresholds: Array = [250.0, 500.0, 750.0, 1000.0]

func _ready() -> void:
	initialize_prosperity_states(["Valley Province", "Oakhaven Province", "Highland Province"])
	# Load thresholds from JSON if available
	var file = FileAccess.open("res://common/singletons/prosperity_config.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			if json.data is Dictionary and json.data.has("thresholds") and json.data["thresholds"] is Array:
				prosperity_thresholds = json.data["thresholds"]
			else:
				print("[ProsperityManager] JSON format invalid, using defaults.")
		else:
			print("[ProsperityManager] Failed to parse prosperity_config.json: ", json.get_error_message())
	else:
		print("[ProsperityManager] prosperity_config.json not found, using default thresholds.")

func add_prosperity(province: String, amount: float) -> void:
	if not province_prosperity.has(province):
		province_prosperity[province] = 100.0
	province_prosperity[province] = max(0.0, province_prosperity[province] + amount)
	prosperity_updated.emit(province, province_prosperity[province])
	print("[ProsperityManager] Added %.1f Prosperity to %s. Total: %.1f" % [amount, province, province_prosperity[province]])
	sync_settlements()

func get_level_for_prosperity(val: float) -> int:
	if val < prosperity_thresholds[0]:
		return 1
	elif val < prosperity_thresholds[1]:
		return 2
	elif val < prosperity_thresholds[2]:
		return 3
	elif val < prosperity_thresholds[3]:
		return 4
	else:
		return 5

func sync_settlements() -> void:
	for province in province_prosperity:
		var val = province_prosperity[province]
		var level = get_level_for_prosperity(val)
		var sec_rating = 100.0 + (level - 1) * 20.0
		
		for city in get_tree().get_nodes_in_group("Cities"):
			if city.get("ownership_province") == province:
				city.prosperity = int(val)
				var old_level = city.get("prosperity_level")
				# If already initialized and upgrading, trigger expansion
				if old_level != null and old_level > 0 and level > old_level:
					city.set("prosperity_level", level)
					_trigger_prosperity_expansion(city, level - old_level)
				else:
					city.set("prosperity_level", level)
				city.set("security_rating", sec_rating)
				
		for town in get_tree().get_nodes_in_group("Towns"):
			if town.get("ownership_province") == province:
				town.prosperity = int(val)
				var old_level = town.get("prosperity_level")
				if old_level != null and old_level > 0 and level > old_level:
					town.set("prosperity_level", level)
					_trigger_prosperity_expansion(town, level - old_level)
				else:
					town.set("prosperity_level", level)
				town.set("security_rating", sec_rating)

func _trigger_prosperity_expansion(settlement: Node2D, delta_levels: int) -> void:
	var world_node = get_tree().current_scene
	if not world_node:
		return
		
	# Find the World NPC Spawner component inside the active World scene
	var npc_spawner_inst = null
	for child in world_node.get_children():
		if child.get_script() and child.get_script().resource_path.contains("world_npc_spawner"):
			npc_spawner_inst = child
			break
			
	if npc_spawner_inst and npc_spawner_inst.has_method("spawn_prosperity_npcs"):
		npc_spawner_inst.call("spawn_prosperity_npcs", settlement, delta_levels)

func pave_province_roads(province: String) -> void:
	for road in get_tree().get_nodes_in_group("Roads"):
		if is_instance_valid(road):
			var settlement = GameState.get_nearest_settlement(road)
			if settlement and settlement.get("ownership_province") == province:
				road.set("is_paved", true)



extends Node

# Dictionary of province_name -> Array[Dictionary]
# Each dict has: { "key": String, "value": float, "source": String }
var province_modifiers: Dictionary = {}

var purchased_province_licenses: Array[String] = []

func has_province_license(prov: String) -> bool:
	var starting_prov = get_player_starting_province()
	if prov == starting_prov or prov == "Unknown Province" or prov == "":
		return true
	return purchased_province_licenses.has(prov)

func get_player_starting_province() -> String:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return "Valley Province"
	var spawn_town = GameState.selected_spawn_town
	var town_node = null
	for grp in ["Cities", "Towns"]:
		for node in tree.get_nodes_in_group(grp):
			if node.name == spawn_town or (node.has_method("get_settlement_name") and node.get_settlement_name() == spawn_town) or node.get("city_name") == spawn_town:
				town_node = node
				break
		if town_node:
			break
	if town_node:
		return GameState.get_province_of_node(town_node)
	return "Valley Province"

func grant_province_license(prov: String) -> void:
	if not purchased_province_licenses.has(prov):
		purchased_province_licenses.append(prov)
		if GameState.has_method("spawn_ui_floating_text"):
			GameState.spawn_ui_floating_text("Operating License Granted: %s!" % prov)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func add_modifier(province_name: String, key: String, value: float, source: String = "") -> void:
	if not province_modifiers.has(province_name):
		province_modifiers[province_name] = []
	remove_modifier(province_name, key, source)
	province_modifiers[province_name].append({
		"key": key,
		"value": value,
		"source": source
	})

func get_modifier(province_name: String, key: String) -> float:
	if not province_modifiers.has(province_name):
		return 0.0
	var total = 0.0
	for mod in province_modifiers[province_name]:
		if mod.get("key") == key:
			total += mod.get("value", 0.0)
	return total

func remove_modifier(province_name: String, key: String, source: String = "") -> void:
	if not province_modifiers.has(province_name):
		return
	var i = province_modifiers[province_name].size() - 1
	while i >= 0:
		var mod = province_modifiers[province_name][i]
		if mod.get("key") == key and (source == "" or mod.get("source") == source):
			province_modifiers[province_name].remove_at(i)
		i -= 1

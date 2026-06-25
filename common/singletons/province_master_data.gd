extends Node

# Dictionary of province_name -> Array[Dictionary]
# Each dict has: { "key": String, "value": float, "source": String }
var province_modifiers: Dictionary = {}

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

extends Node

# Array of active global modifier profiles: Array[Dictionary]
# Each dict has: { "key": String, "value": float, "source": String }
var global_modifiers: Array[Dictionary] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func add_modifier(key: String, value: float, source: String = "") -> void:
	remove_modifier(key, source)
	global_modifiers.append({
		"key": key,
		"value": value,
		"source": source
	})

func get_modifier(key: String) -> float:
	var total = 0.0
	for mod in global_modifiers:
		if mod.get("key") == key:
			total += mod.get("value", 0.0)
	return total

func remove_modifier(key: String, source: String = "") -> void:
	var i = global_modifiers.size() - 1
	while i >= 0:
		var mod = global_modifiers[i]
		if mod.get("key") == key and (source == "" or mod.get("source") == source):
			global_modifiers.remove_at(i)
		i -= 1

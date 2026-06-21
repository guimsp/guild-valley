extends Node

signal prosperity_updated(province: String, value: float)

# Shared Province Prosperity starting values
var province_prosperity: Dictionary = {
	"Valley Province": 100.0,
	"Oakhaven Province": 100.0
}

func add_prosperity(province: String, amount: float) -> void:
	if not province_prosperity.has(province):
		province_prosperity[province] = 100.0
	province_prosperity[province] = max(0.0, province_prosperity[province] + amount)
	prosperity_updated.emit(province, province_prosperity[province])
	print("[ProsperityManager] Added %.1f Prosperity to %s. Total: %.1f" % [amount, province, province_prosperity[province]])
	
	# Sync prosperity with all City and Town nodes in the province
	for city in get_tree().get_nodes_in_group("Cities"):
		if city.get("ownership_province") == province:
			city.prosperity = int(max(0, city.prosperity + amount))
	for town in get_tree().get_nodes_in_group("Towns"):
		if town.get("ownership_province") == province:
			town.prosperity = int(max(0, town.prosperity + amount))

extends Node2D

func _ready() -> void:
	var econ = get_node_or_null("/root/EconomyManager")
	if not econ:
		print("EconomyManager not found")
		get_tree().quit()
		return
		
	print("--- LIST OF ALL ITEMS IN DATABASE ---")
	for item_id in econ.item_database:
		var item = econ.item_database[item_id]
		print("ID: ", item.id, " | Name: ", item.name, " | Category: ", item.market_category, " | Path: ", item.resource_path)
		
	get_tree().quit()

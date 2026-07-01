extends SceneTree

func _init() -> void:
	print("DUMP NPCS START")
	var world_scene = load("res://entities/world/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	# Wait several frames for everything to spawn and initialize
	for i in range(10):
		await process_frame
	
	var out = []
	out.append("World children:")
	for child in world.get_children():
		out.append("  %s (%s)" % [child.name, child.get_class()])
		
	out.append("\nCities in group:")
	var cities = root.get_tree().get_nodes_in_group("Cities")
	for c in cities:
		out.append("  %s - Province: %s - Pos: %s" % [c.name, str(c.get("ownership_province")), str(c.global_position)])
		
	out.append("\nTowns in group:")
	var towns = root.get_tree().get_nodes_in_group("Towns")
	for t in towns:
		out.append("  %s - Province: %s - Pos: %s" % [t.name, str(t.get("ownership_province")), str(t.global_position)])
		
	out.append("\nNPCs in group:")
	var npcs = root.get_tree().get_nodes_in_group("NPCs")
	for n in npcs:
		var sett = n.get("spawn_settlement")
		var sett_name = sett.name if sett else "None"
		out.append("  %s (%s) - Pos: %s - Type: %d - Settlement: %s" % [n.name, n.npc_name, str(n.global_position), n.npc_type, sett_name])
		
	# Let's also print all nodes containing 'NPC' or similar in their name from the whole tree
	out.append("\nAll nodes in scene tree:")
	_dump_tree(root, "", out)
	
	var out_text = "\n".join(out)
	var f = FileAccess.open("res://world_dump.txt", FileAccess.WRITE)
	if f:
		f.store_string(out_text)
		f.close()
	print("Dump saved successfully!")
	quit()

func _dump_tree(node: Node, indent: String, out: Array) -> void:
	out.append(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_dump_tree(child, indent + "  ", out)

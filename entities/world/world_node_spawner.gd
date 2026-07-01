extends Node

const MEGA_SCRIPT_PATH = "res://components/gathering/mega_node.gd"

func spawn_all_nodes(parent: Node2D) -> void:
	# 1. Clear old nodes
	for node in parent.get_tree().get_nodes_in_group("MegaNodes"):
		if is_instance_valid(node):
			node.queue_free()
			
	await parent.get_tree().physics_frame
	await parent.get_tree().physics_frame

	# 2. Parse resource nodes from blueprint
	var blueprint = parent.get_node_or_null("world_map_blueprint")
	if not blueprint:
		push_warning("[WorldNodeSpawner] No world_map_blueprint found, falling back to procedural spawning.")
		_spawn_procedural_nodes(parent)
		return
		
	var res_nodes = blueprint.get_node_or_null("ResourceNodes")
	if not res_nodes:
		push_warning("[WorldNodeSpawner] No ResourceNodes node found in blueprint, falling back to procedural spawning.")
		_spawn_procedural_nodes(parent)
		return
		
	for child in res_nodes.get_children():
		if child is ColorRect:
			var pos = child.global_position + child.size / 2.0
			
			# If there's a specific interactive Interact or Door marker, use that as center
			var door_node = child.get_node_or_null("Interact")
			if not door_node:
				door_node = child.get_node_or_null("Door")
				
			var size = Vector2.ZERO
			if door_node and door_node is Control:
				pos = child.global_position + door_node.position + door_node.size / 2.0
				size = door_node.size
				
			var display_name = child.name.replace("_", " ")
			var resource_id = "raw_log"
			var lower_name = child.name.to_lower()
			
			if "iron" in lower_name:
				resource_id = "iron_ore"
				display_name = "Iron Ore Vein"
			elif "timber" in lower_name:
				resource_id = "raw_log"
				display_name = "Timber Grove"
			elif "farmstead" in lower_name:
				resource_id = "wheat"
				display_name = "Wheat Farmstead"
				
			_spawn_node(parent, display_name, resource_id, pos, size)

func _spawn_procedural_nodes(parent: Node2D) -> void:
	_spawn_province_nodes(parent, 1000, 1)
	_spawn_province_nodes(parent, 7000, 2)
	_spawn_province_nodes(parent, 13000, 3)

func _spawn_province_nodes(parent: Node2D, x_center: float, province_num: int) -> void:
	# Level 1 Nodes (Clustered tightly at Y: 200 - 560)
	_spawn_node(parent, "Forest", "raw_log", Vector2(x_center - 150, 200))
	_spawn_node(parent, "Wheat Field", "wheat", Vector2(x_center - 50, 200))
	_spawn_node(parent, "Coal Vein", "coal_nugget", Vector2(x_center + 50, 200))
	_spawn_node(parent, "Herb Slopes", "raw_wild_herbs", Vector2(x_center + 150, 200))
	
	_spawn_node(parent, "Root Grove", "overworld_root", Vector2(x_center - 150, 320))
	_spawn_node(parent, "Flax Field", "wild_flax", Vector2(x_center - 50, 320))
	_spawn_node(parent, "Reed Banks", "river_reeds", Vector2(x_center + 50, 320))
	_spawn_node(parent, "Scrap Pile", "scraped_metal", Vector2(x_center + 150, 320))
	
	_spawn_node(parent, "Bone Pit", "wild_animal_bones", Vector2(x_center - 100, 440))
	_spawn_node(parent, "Twig Patch", "deadwood_twigs", Vector2(x_center, 440))
	_spawn_node(parent, "Clay Bank", "clay_mud", Vector2(x_center + 100, 440))
	_spawn_node(parent, "Stone Quarry", "raw_stone", Vector2(x_center, 560))

	# Level 3 Nodes
	_spawn_node(parent, "Hunting Grounds", "venison", Vector2(x_center - 150, 680))
	_spawn_node(parent, "Copper Ridge", "copper_ore", Vector2(x_center - 50, 680))
	_spawn_node(parent, "Zinc Hollows", "zinc_ore", Vector2(x_center + 50, 680))
	_spawn_node(parent, "Hardwood Grove", "raw_hardwood_log", Vector2(x_center + 150, 680))

	# Level 4 Nodes (Exactly 1 of each in the world, distributed separately)
	if province_num == 1:
		_spawn_node(parent, "Fungi Cave", "underground_fungi", Vector2(x_center, 800))
	elif province_num == 2:
		_spawn_node(parent, "Marble Deposit", "marble_block", Vector2(x_center, 800))
	elif province_num == 3:
		_spawn_node(parent, "Hops Field", "barley_and_hops", Vector2(x_center - 50, 800))
		_spawn_node(parent, "Pelt Woods", "wild_animal_hides", Vector2(x_center + 50, 800))

func _spawn_node(parent: Node2D, display_name: String, resource_id: String, pos: Vector2, size: Vector2 = Vector2.ZERO) -> void:
	var mega_script = load(MEGA_SCRIPT_PATH)
	var node = Area2D.new()
	node.name = display_name.replace(" ", "") + "_" + str(int(pos.x))
	node.set_script(mega_script)
	node.node_name = display_name
	node.resource_type_id = resource_id
	node.base_fee = 50
	node.global_position = pos
	
	var col = CollisionShape2D.new()
	if size != Vector2.ZERO:
		var shape = RectangleShape2D.new()
		shape.size = size
		col.shape = shape
	else:
		var shape = CircleShape2D.new()
		shape.radius = 96.0
		col.shape = shape
	col.name = "CollisionShape2D"
	node.add_child(col)
	
	parent.add_child(node)
	print("[WorldNodeSpawner] Spawned node: ", display_name, " (", resource_id, ") at ", pos, " with size: ", size)

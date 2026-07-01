extends Node

const MEGA_SCRIPT_PATH = "res://components/gathering/mega_node.gd"

var all_registered_nodes: Array = []
var world_parent: Node2D = null

func spawn_all_nodes(parent: Node2D) -> void:
	world_parent = parent
	
	# 1. Clear old nodes
	for node in parent.get_tree().get_nodes_in_group("MegaNodes"):
		if is_instance_valid(node):
			node.queue_free()
			
	await parent.get_tree().physics_frame
	await parent.get_tree().physics_frame

	all_registered_nodes.clear()

	# Connect prosperity changes to dynamically spawn higher level nodes
	if not ProsperityManager.prosperity_updated.is_connected(_on_prosperity_updated):
		ProsperityManager.prosperity_updated.connect(_on_prosperity_updated)

	# 2. Parse resource nodes from blueprint
	var blueprint = parent.get_node_or_null("world_map_blueprint")
	if not blueprint:
		push_warning("[WorldNodeSpawner] No world_map_blueprint found, falling back to procedural spawning.")
		_register_procedural_nodes()
		update_spawned_nodes()
		return
		
	var res_nodes = blueprint.get_node_or_null("ResourceNodes")
	if not res_nodes:
		push_warning("[WorldNodeSpawner] No ResourceNodes node found in blueprint, falling back to procedural spawning.")
		_register_procedural_nodes()
		update_spawned_nodes()
		return
		
	for child in res_nodes.get_children():
		if child is ColorRect:
			var pos = child.global_position + child.size / 2.0
			
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
			elif "coal" in lower_name:
				resource_id = "coal_nugget"
				display_name = "Coal Vein"
			elif "herb" in lower_name:
				resource_id = "raw_wild_herbs"
				display_name = "Herb Slopes"
			elif "root" in lower_name:
				resource_id = "overworld_root"
				display_name = "Root Grove"
			elif "flax" in lower_name:
				resource_id = "wild_flax"
				display_name = "Flax Field"
			elif "reed" in lower_name:
				resource_id = "river_reeds"
				display_name = "Reed Banks"
			elif "scrap" in lower_name:
				resource_id = "scraped_metal"
				display_name = "Scrap Pile"
			elif "bone" in lower_name:
				resource_id = "wild_animal_bones"
				display_name = "Bone Pit"
			elif "twig" in lower_name:
				resource_id = "deadwood_twigs"
				display_name = "Twig Patch"
			elif "clay" in lower_name:
				resource_id = "clay_mud"
				display_name = "Clay Bank"
			elif "stone" in lower_name:
				resource_id = "raw_stone"
				display_name = "Stone Quarry"
			elif "hunting" in lower_name or "venison" in lower_name:
				resource_id = "venison"
				display_name = "Hunting Grounds"
			elif "copper" in lower_name:
				resource_id = "copper_ore"
				display_name = "Copper Ridge"
			elif "zinc" in lower_name:
				resource_id = "zinc_ore"
				display_name = "Zinc Hollows"
			elif "hardwood" in lower_name:
				resource_id = "raw_hardwood_log"
				display_name = "Hardwood Grove"
			elif "fungi" in lower_name:
				resource_id = "underground_fungi"
				display_name = "Fungi Cave"
			elif "marble" in lower_name:
				resource_id = "marble_block"
				display_name = "Marble Deposit"
			elif "hops" in lower_name or "barley" in lower_name:
				resource_id = "barley_and_hops"
				display_name = "Hops Field"
			elif "pelt" in lower_name or "hides" in lower_name:
				resource_id = "wild_animal_hides"
				display_name = "Pelt Woods"
				
			var province = GameState.get_province_of_node(child) if GameState else "Valley Province"
			var req_prosperity = _get_required_prosperity_for_resource(resource_id)
			
			all_registered_nodes.append({
				"display_name": display_name,
				"resource_id": resource_id,
				"pos": pos,
				"size": size,
				"province": province,
				"required_prosperity": req_prosperity
			})
			
	update_spawned_nodes()

func _register_procedural_nodes() -> void:
	_register_province_nodes(1000, 1)
	_register_province_nodes(7000, 2)
	_register_province_nodes(13000, 3)

func _register_province_nodes(x_center: float, province_num: int) -> void:
	var province = "Valley Province"
	if province_num == 2: province = "Oakhaven Province"
	elif province_num == 3: province = "Highland Province"
	
	var register = func(display_name: String, resource_id: String, pos: Vector2):
		var req = _get_required_prosperity_for_resource(resource_id)
		all_registered_nodes.append({
			"display_name": display_name,
			"resource_id": resource_id,
			"pos": pos,
			"size": Vector2.ZERO,
			"province": province,
			"required_prosperity": req
		})

	# Level 1 Nodes
	register.call("Forest", "raw_log", Vector2(x_center - 150, 200))
	register.call("Wheat Field", "wheat", Vector2(x_center - 50, 200))
	register.call("Coal Vein", "coal_nugget", Vector2(x_center + 50, 200))
	register.call("Herb Slopes", "raw_wild_herbs", Vector2(x_center + 150, 200))
	
	register.call("Root Grove", "overworld_root", Vector2(x_center - 150, 320))
	register.call("Flax Field", "wild_flax", Vector2(x_center - 50, 320))
	register.call("Reed Banks", "river_reeds", Vector2(x_center + 50, 320))
	register.call("Scrap Pile", "scraped_metal", Vector2(x_center + 150, 320))
	
	register.call("Bone Pit", "wild_animal_bones", Vector2(x_center - 100, 440))
	register.call("Twig Patch", "deadwood_twigs", Vector2(x_center, 440))
	register.call("Clay Bank", "clay_mud", Vector2(x_center + 100, 440))
	register.call("Stone Quarry", "raw_stone", Vector2(x_center, 560))

	# Level 3 Nodes
	register.call("Hunting Grounds", "venison", Vector2(x_center - 150, 680))
	register.call("Copper Ridge", "copper_ore", Vector2(x_center - 50, 680))
	register.call("Zinc Hollows", "zinc_ore", Vector2(x_center + 50, 680))
	register.call("Hardwood Grove", "raw_hardwood_log", Vector2(x_center + 150, 680))

	# Level 4 Nodes
	if province_num == 1:
		register.call("Fungi Cave", "underground_fungi", Vector2(x_center, 800))
	elif province_num == 2:
		register.call("Marble Deposit", "marble_block", Vector2(x_center, 800))
	elif province_num == 3:
		register.call("Hops Field", "barley_and_hops", Vector2(x_center - 50, 800))
		register.call("Pelt Woods", "wild_animal_hides", Vector2(x_center + 50, 800))

func _get_required_prosperity_for_resource(resource_id: String) -> int:
	var item_level = 1
	var econ = get_node_or_null("/root/EconomyManager")
	if econ and econ.item_database.has(resource_id):
		item_level = econ.item_database[resource_id].item_level
		
	match item_level:
		3: return 3
		4: return 4
		_: return 1

func update_spawned_nodes() -> void:
	if not is_instance_valid(world_parent):
		return
		
	var spawned_positions = []
	for node in world_parent.get_tree().get_nodes_in_group("MegaNodes"):
		if is_instance_valid(node):
			spawned_positions.append(node.global_position)
			
	for info in all_registered_nodes:
		var already_spawned = false
		for pos in spawned_positions:
			if pos.distance_to(info.pos) < 5.0:
				already_spawned = true
				break
		if already_spawned:
			continue
			
		var prov_prosperity = ProsperityManager.province_prosperity.get(info.province, 100.0)
		var current_prov_level = ProsperityManager.get_level_for_prosperity(prov_prosperity)
		
		if current_prov_level >= info.required_prosperity:
			_spawn_node_instance(world_parent, info.display_name, info.resource_id, info.pos, info.size)

func _spawn_node_instance(parent: Node2D, display_name: String, resource_id: String, pos: Vector2, size: Vector2 = Vector2.ZERO) -> void:
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

func _on_prosperity_updated(_province: String, _value: float) -> void:
	update_spawned_nodes()

extends Node

const HOUSE_SCENE_PATH = "res://components/buildings/house.tscn"
const QUEST_BOARD_SCENE_PATH = "res://components/buildings/quest_board.tscn"
const STALL_SCENE_PATH = "res://components/market/market_stall.tscn"
const FOUNTAIN_SCENE_PATH = "res://entities/fountain/fountain.tscn"

var parent_node: Node2D

func rebuild_world(parent: Node2D) -> void:
	parent_node = parent
	
	# Free the second set of houses and doors as they are redundant now
	var p_house2 = parent.get_node_or_null("PlayerHouse2")
	if p_house2: p_house2.queue_free()
	var h_door2 = parent.get_node_or_null("HouseDoor2")
	if h_door2: h_door2.queue_free()
	var r_house2 = parent.get_node_or_null("RivalHouse2")
	if r_house2: r_house2.queue_free()
	var rh_door2 = parent.get_node_or_null("RivalHouseDoor2")
	if rh_door2: rh_door2.queue_free()
	
	# Load and instance the visual blueprint map
	var blueprint_scene = load("res://entities/world/world_map_blueprint.tscn")
	var blueprint = null
	if blueprint_scene:
		blueprint = blueprint_scene.instantiate()
		blueprint.name = "world_map_blueprint"
		blueprint.z_index = -10
		blueprint.z_as_relative = false
		parent.add_child(blueprint)
		parent.move_child(blueprint, 0)
		
		# Phased migration: hide overworld blueprint layers so they do not overlap
		var provinces_node = blueprint.get_node_or_null("Provinces")
		if provinces_node and provinces_node is CanvasItem:
			provinces_node.hide()
		var settlements_node = blueprint.get_node_or_null("Settlements")
		if settlements_node and settlements_node is CanvasItem:
			settlements_node.hide()
		var static_blds_node = blueprint.get_node_or_null("StaticBuildings")
		if static_blds_node and static_blds_node is CanvasItem:
			static_blds_node.hide()
		# Do not hide HighwaysAndPlazas and TerrainObstacles so they remain visible
		var resource_nodes = blueprint.get_node_or_null("ResourceNodes")
		if resource_nodes and resource_nodes is CanvasItem:
			resource_nodes.show()

	# 1. Clear old structures
	for node in parent.get_tree().get_nodes_in_group("Roads"):
		if is_instance_valid(node):
			node.queue_free()
	for node in parent.get_tree().get_nodes_in_group("Plazas"):
		if is_instance_valid(node):
			node.queue_free()
	for node in parent.get_tree().get_nodes_in_group("BuildingLots"):
		if is_instance_valid(node):
			node.queue_free()
			
	for city in parent.get_tree().get_nodes_in_group("Cities"):
		for child in city.get_children():
			child.queue_free()
	for town in parent.get_tree().get_nodes_in_group("Towns"):
		for child in town.get_children():
			child.queue_free()
			
	var mine_outpost = parent.get_node_or_null("MineOutpost")
	if mine_outpost: mine_outpost.queue_free()
	var wood_outpost = parent.get_node_or_null("WoodOutpost")
	if wood_outpost: wood_outpost.queue_free()
	
	# Wait for nodes to be freed
	await parent.get_tree().physics_frame
	await parent.get_tree().physics_frame

	# 2. Setup settlements Node2D instances in the scene
	var city_script = load("res://components/settlements/city.gd")
	var town_script = load("res://components/settlements/town.gd")
	
	# Valley Province
	var valley_city = parent.get_node_or_null("ValleyCity")
	if not valley_city:
		valley_city = Node2D.new()
		valley_city.name = "ValleyCity"
		valley_city.set_script(city_script)
		parent.add_child(valley_city)
	valley_city.city_name = "Valley City"
	valley_city.radius_of_influence = 800.0
	valley_city.prosperity = 80
	valley_city.ownership_province = "Valley Province"
	valley_city.global_position = Vector2(2591.4, -1823.7)
	
	var mineville = parent.get_node_or_null("Mineville")
	if not mineville:
		mineville = Node2D.new()
		mineville.name = "Mineville"
		mineville.set_script(town_script)
		parent.add_child(mineville)
	mineville.town_name = "Mineville"
	mineville.prosperity = 30
	mineville.ownership_province = "Valley Province"
	mineville.global_position = Vector2(792.0, -3216.0)
	
	var riverton = parent.get_node_or_null("Riverton")
	if not riverton:
		riverton = Node2D.new()
		riverton.name = "Riverton"
		riverton.set_script(town_script)
		parent.add_child(riverton)
	riverton.town_name = "Riverton"
	riverton.prosperity = 30
	riverton.ownership_province = "Valley Province"
	riverton.global_position = Vector2(1800, 1000)

	# Oakhaven Province
	var oakhaven_city = parent.get_node_or_null("OakhavenCity")
	if not oakhaven_city:
		oakhaven_city = Node2D.new()
		oakhaven_city.name = "OakhavenCity"
		oakhaven_city.set_script(city_script)
		parent.add_child(oakhaven_city)
	oakhaven_city.city_name = "Oakhaven City"
	oakhaven_city.radius_of_influence = 800.0
	oakhaven_city.prosperity = 80
	oakhaven_city.ownership_province = "Oakhaven Province"
	oakhaven_city.global_position = Vector2(7000, 1000)

	var oakville = parent.get_node_or_null("Oakville")
	if not oakville:
		oakville = Node2D.new()
		oakville.name = "Oakville"
		oakville.set_script(town_script)
		parent.add_child(oakville)
	oakville.town_name = "Oakville"
	oakville.prosperity = 30
	oakville.ownership_province = "Oakhaven Province"
	oakville.global_position = Vector2(5307.3, -1062.1)

	var pinewood = parent.get_node_or_null("Pinewood")
	if not pinewood:
		pinewood = Node2D.new()
		pinewood.name = "Pinewood"
		pinewood.set_script(town_script)
		parent.add_child(pinewood)
	pinewood.town_name = "Pinewood"
	pinewood.prosperity = 30
	pinewood.ownership_province = "Oakhaven Province"
	pinewood.global_position = Vector2(7800, 1000)

	# Highland Province
	var highland_city = parent.get_node_or_null("HighlandCity")
	if not highland_city:
		highland_city = Node2D.new()
		highland_city.name = "HighlandCity"
		highland_city.set_script(city_script)
		parent.add_child(highland_city)
	highland_city.city_name = "Highland City"
	highland_city.radius_of_influence = 800.0
	highland_city.prosperity = 80
	highland_city.ownership_province = "Highland Province"
	highland_city.global_position = Vector2(13000, 1000)
	
	var stonebridge = parent.get_node_or_null("Stonebridge")
	if not stonebridge:
		stonebridge = Node2D.new()
		stonebridge.name = "Stonebridge"
		stonebridge.set_script(town_script)
		parent.add_child(stonebridge)
	stonebridge.town_name = "Stonebridge"
	stonebridge.prosperity = 30
	stonebridge.ownership_province = "Highland Province"
	stonebridge.global_position = Vector2(12200, 1000)
	
	var clayton = parent.get_node_or_null("Clayton")
	if not clayton:
		clayton = Node2D.new()
		clayton.name = "Clayton"
		clayton.set_script(town_script)
		parent.add_child(clayton)
	clayton.town_name = "Clayton"
	clayton.prosperity = 30
	clayton.ownership_province = "Highland Province"
	clayton.global_position = Vector2(13800, 1000)

	# 3. Position Player and Rival at spawners
	var player = parent.get_node_or_null("Player")
	var rival = parent.get_node_or_null("AIRival")
	var spawn_assigned = false
	if blueprint:
		var spawners_node = blueprint.get_node_or_null("Spawners")
		if spawners_node:
			var player_folder_name = "Town_A_1_Spawns" # Mineville
			var rival_folder_name = "Town_A_2_Spawns"  # Oakville
			
			if GameState and GameState.selected_spawn_town == "Oakville":
				player_folder_name = "Town_A_2_Spawns"
				rival_folder_name = "Town_A_1_Spawns"
				
			var p_folder = spawners_node.get_node_or_null(player_folder_name)
			var r_folder = spawners_node.get_node_or_null(rival_folder_name)
			
			if p_folder:
				var p_anchor = p_folder.get_node_or_null("Player_Spawn_Anchor")
				if p_anchor and player:
					player.global_position = p_anchor.global_position
					spawn_assigned = true
					var camera = player.get_node_or_null("Camera2D")
					if camera and camera is Camera2D:
						camera.reset_smoothing()
			if r_folder:
				var r_anchor = r_folder.get_node_or_null("Rival1_Spawn_Anchor")
				if r_anchor and rival:
					rival.global_position = r_anchor.global_position
	if not spawn_assigned:
		if player: player.global_position = Vector2(1000, 1000)
		if rival: rival.global_position = Vector2(1050, 1000)

	# 4. Parse static buildings from blueprint
	if blueprint:
		var static_blds_node = blueprint.get_node_or_null("StaticBuildings")
		if static_blds_node:
			for category in static_blds_node.get_children():
				for bld_node in category.get_children():
					if bld_node is ColorRect:
						var rect = bld_node.get_global_rect()
						var bld_pos = rect.position + rect.size / 2.0
						
						var specs = _get_static_building_specs(bld_node.name)
						var bld_scene_path = specs["path"]
						var properties = specs["props"]
						
						# Find matching interior name
						var parent_folder_name = category.name
						var prefix = parent_folder_name.replace("_Buildings", "")
						var interior_name = "Int_" + prefix + "_" + bld_node.name
						
						if "Town_Hall" in bld_node.name or "TownHall" in bld_node.name:
							var scene_root = parent.get_tree().current_scene if parent.is_inside_tree() else null
							var name_with_underscore = "Int_" + prefix + "_Town_Hall"
							var name_no_underscore = "Int_" + prefix + "_TownHall"
							
							if scene_root:
								if scene_root.find_child(name_no_underscore, true, false):
									interior_name = name_no_underscore
								else:
									interior_name = name_with_underscore
							else:
								if "City" in prefix:
									interior_name = name_no_underscore
								else:
									interior_name = name_with_underscore
								
						var door_node = bld_node.get_node_or_null("Door")
						var door_pos = bld_pos + Vector2(0, 32)
						if door_node and door_node is Control:
							var door_rect = door_node.get_global_rect()
							door_pos = door_rect.position + door_rect.size / 2.0
							
						# Spawn the building
						var bld_scene = load(bld_scene_path)
						if bld_scene:
							var bld = bld_scene.instantiate() as Node2D
							bld.name = bld_node.name
							bld.global_position = bld_pos
							bld.set_meta("blueprint_interior_name", interior_name)
							bld.set_meta("blueprint_door_pos", door_pos)
							
							for prop in properties:
								bld.set(prop, properties[prop])
								
							if bld.has_method("set_building_size"):
								bld.set_building_size(rect.size)
								
							parent.add_child(bld)
							
							# Create building lot
							var lot_scene = load("res://components/placement/building_lot.tscn")
							var lot = lot_scene.instantiate() as BuildingLot
							lot.global_position = bld_pos
							lot.lot_size = rect.size
							parent.add_child(lot)
							lot.occupied_node = bld
							lot.is_occupied = true
							
							# Check for Stall_Anchor child
							var stall_anchor = bld_node.get_node_or_null("Stall_Anchor")
							if stall_anchor:
								bld.set_meta("stall_spawn_pos", stall_anchor.global_position)
								if bld.ownership_type == "NPC":
									bld.improvements["storefront"] = 1
								if bld.has_method("update_storefront_stall_state"):
									bld.update_storefront_stall_state()
								
	# 5. Parse slot grids under Settlements
	var settlements_node = blueprint.get_node_or_null("Settlements") if blueprint else null
	var all_slots = []
	if settlements_node:
		_find_all_slots(settlements_node, all_slots)
		
	var slots_by_settlement = {}
	for slot in all_slots:
		var sett = _get_settlement_for_slot(slot, parent)
		if sett:
			if not slots_by_settlement.has(sett):
				slots_by_settlement[sett] = []
			slots_by_settlement[sett].append(slot)
			
	for sett in slots_by_settlement:
		# Sort slots numerically by name
		slots_by_settlement[sett].sort_custom(func(a, b):
			var get_num = func(s: String):
				var num_str = ""
				for char in s:
					if char in "0123456789":
						num_str += char
				return int(num_str) if num_str != "" else 1
			return get_num.call(a.name) < get_num.call(b.name)
		)
		
		var is_city = sett.is_in_group("Cities")
		var rent_limit = 6 if is_city else 4
		
		var is_player_start = (GameState and sett.name == GameState.selected_spawn_town)
		var rival_start_town = "Oakville" if (not GameState or GameState.selected_spawn_town == "Mineville") else "Mineville"
		var is_rival_start = (sett.name == rival_start_town)

		for i in range(slots_by_settlement[sett].size()):
			var slot = slots_by_settlement[sett][i]
			var rect = slot.get_global_rect()
			var global_pos = rect.position + rect.size / 2.0
			var local_pos = global_pos - sett.global_position
			
			var signpost_node = slot.get_node_or_null("Signpost")
			var door_pos = global_pos + Vector2(0, 32)
			if signpost_node and signpost_node is Control:
				var door_rect = signpost_node.get_global_rect()
				door_pos = door_rect.position + door_rect.size / 2.0
				
			if i == 0 and is_player_start:
				var p_house = parent.get_node_or_null("PlayerHouse")
				if p_house:
					p_house.global_position = global_pos
					p_house.set_meta("blueprint_door_pos", door_pos)
				var h_door = parent.get_node_or_null("HouseDoor")
				if h_door:
					h_door.global_position = door_pos
					h_door.target_spawn_position = Vector2(3250, 3260) if sett.name == "Mineville" else Vector2(8250, 3260)
				print("[WorldLayoutSpawner] Repositioned PlayerHouse and HouseDoor to starting slot in ", sett.name, " at ", global_pos)
				continue
				
			elif i == 0 and is_rival_start:
				var r_house = parent.get_node_or_null("RivalHouse")
				if r_house:
					r_house.global_position = global_pos
					r_house.set_meta("blueprint_door_pos", door_pos)
				var rh_door = parent.get_node_or_null("RivalHouseDoor")
				if rh_door:
					rh_door.global_position = door_pos
					rh_door.target_spawn_position = Vector2(8250, 3260) if sett.name == "Oakville" else Vector2(3250, 3260)
				print("[WorldLayoutSpawner] Repositioned RivalHouse and RivalHouseDoor to starting slot in ", sett.name, " at ", global_pos)
				continue

			if i < rent_limit:
				# Spawn Rental House
				var lot = _create_lot_with_building(sett, local_pos, HOUSE_SCENE_PATH, {
					"custom_name": "Rental House", 
					"is_rental": true, 
					"ownership_type": "NPC", 
					"owner_id": ""
				})
				if lot.occupied_node:
					lot.occupied_node.set_meta("blueprint_door_pos", door_pos)
					if lot.occupied_node.has_method("set_building_size"):
						lot.occupied_node.set_building_size(rect.size)
			else:
				# Spawn empty BuildingLot
				var lot_scene = load("res://components/placement/building_lot.tscn")
				var lot = lot_scene.instantiate() as BuildingLot
				lot.position = local_pos
				lot.lot_size = rect.size
				sett.add_child(lot)
				lot.set_meta("blueprint_door_pos", door_pos)

	# 6. Parse Highways and Plazas
	if blueprint:
		var hp_node = blueprint.get_node_or_null("HighwaysAndPlazas")
		if hp_node:
			_parse_highways_and_plazas(parent, hp_node)
			
	# Dynamic exit doors linking:
	var door1 = parent.get_node_or_null("HouseInterior/DoorTrigger")
	var door2 = parent.get_node_or_null("HouseInterior2/DoorTrigger")
	
	var h_door = parent.get_node_or_null("HouseDoor")
	var rh_door = parent.get_node_or_null("RivalHouseDoor")
	
	if h_door and rh_door:
		# Check where they teleport to
		if h_door.target_spawn_position.x < 5000:
			# h_door teleports to HouseInterior (3250, 3260)
			if door1: door1.target_spawn_position = h_door.global_position + Vector2(0, 40)
			if door2: door2.target_spawn_position = rh_door.global_position + Vector2(0, 40)
		else:
			# h_door teleports to HouseInterior2 (8250, 3260)
			if door2: door2.target_spawn_position = h_door.global_position + Vector2(0, 40)
			if door1: door1.target_spawn_position = rh_door.global_position + Vector2(0, 40)
			
	# Wait a frame to sync
	await parent.get_tree().process_frame

func _get_static_building_specs(node_name: String) -> Dictionary:
	var lower = node_name.to_lower()
	var path = HOUSE_SCENE_PATH
	var props = {}
	
	if "town_hall" in lower or "townhall" in lower:
		props = {"custom_name": "Town Hall", "ownership_type": "Public", "is_buyable": false}
	elif "law_house" in lower or "lawhouse" in lower or "city_council" in lower:
		props = {"custom_name": "City Council", "ownership_type": "Public", "is_buyable": false, "is_city_council": true}
	elif "chappel" in lower or "chapel" in lower:
		props = {"custom_name": "Small Chapel", "ownership_type": "Public", "is_buyable": false}
	elif "guardhouse" in lower:
		props = {"custom_name": "Town Guardhouse", "ownership_type": "Public", "is_buyable": false}
	elif "quest" in lower or "board" in lower:
		path = QUEST_BOARD_SCENE_PATH
	elif "guild" in lower:
		var clean_name = node_name.replace("_", " ")
		if "woodmaker" in lower:
			clean_name = "Woodworker Guild"
		else:
			clean_name = clean_name.capitalize()
		props = {"custom_name": clean_name, "ownership_type": "Public", "owner_id": "Guild", "is_buyable": false, "is_guild": true}
	elif "royal_house" in lower:
		props = {"custom_name": "Royal House", "ownership_type": "Public", "is_buyable": false}
	else:
		props = {"custom_name": node_name.replace("_", " ").capitalize(), "ownership_type": "NPC", "is_rental": true}
		
	return {"path": path, "props": props}

func _spawn_interactable_stall(parent: Node2D, pos: Vector2, building: Node2D) -> void:
	var stall_scene = load(STALL_SCENE_PATH)
	if stall_scene:
		var stall = stall_scene.instantiate() as MarketStall
		stall.global_position = pos
		if stall.has_node("CollisionShape2D"):
			var col = stall.get_node("CollisionShape2D") as CollisionShape2D
			if col:
				col.disabled = true
		stall.collision_layer = 0
		stall.collision_mask = 0
		stall.ownership_type = building.ownership_type
		stall.owner_id = building.owner_id
		stall.inventory = building.inventory
		stall.parent_building = building
		parent.add_child(stall)
		print("[WorldLayout] Spawned interactable stall at ", pos, " linked to building ", building.name)

func _find_all_slots(node: Node, slots_list: Array) -> void:
	if node.name.begins_with("Slot") and node is ColorRect:
		slots_list.append(node)
	for child in node.get_children():
		_find_all_slots(child, slots_list)

func _get_settlement_for_slot(slot: Node, parent: Node2D) -> Node2D:
	var path = slot.get_path()
	var path_str = str(path)
	if "City A" in path_str or "City_A" in path_str:
		return parent.get_node_or_null("ValleyCity")
	elif "Town A 2" in path_str or "Town_A_2" in path_str:
		return parent.get_node_or_null("Oakville")
	elif "Town A 1" in path_str or "Town_A_1" in path_str:
		return parent.get_node_or_null("Mineville")
	elif "City B" in path_str or "City_B" in path_str:
		return parent.get_node_or_null("OakhavenCity")
	elif "Town B 1" in path_str or "Town_B_1" in path_str:
		return parent.get_node_or_null("Riverton")
	elif "Town B 2" in path_str or "Town_B_2" in path_str:
		return parent.get_node_or_null("Pinewood")
	elif "City C" in path_str or "City_C" in path_str:
		return parent.get_node_or_null("HighlandCity")
	elif "Town C 1" in path_str or "Town_C_1" in path_str:
		return parent.get_node_or_null("Stonebridge")
	elif "Town C 2" in path_str or "Town_C_2" in path_str:
		return parent.get_node_or_null("Clayton")
	return null

func _create_lot_with_building(settlement: Node2D, relative_pos: Vector2, building_scene_path: String, properties: Dictionary = {}) -> BuildingLot:
	var lot_scene = load("res://components/placement/building_lot.tscn")
	var lot = lot_scene.instantiate() as BuildingLot
	lot.position = relative_pos
	settlement.add_child(lot)
	
	if building_scene_path != "":
		var bld_scene = load(building_scene_path)
		var bld = bld_scene.instantiate() as Node2D
		bld.position = relative_pos
		for prop in properties:
			bld.set(prop, properties[prop])
		settlement.add_child(bld)
		lot.occupied_node = bld
		lot.is_occupied = true
		
	return lot

func convert_lot_to_rental_house(lot: BuildingLot) -> Node2D:
	if not is_instance_valid(lot) or lot.is_occupied:
		return null
		
	var bld_scene = load("res://components/buildings/house.tscn")
	if not bld_scene:
		return null
		
	var bld = bld_scene.instantiate() as Node2D
	bld.position = lot.position
	bld.set("custom_name", "Rental House")
	bld.set("is_rental", true)
	bld.set("ownership_type", "NPC")
	bld.set("owner_id", "")
	
	var door_pos = lot.get_meta("blueprint_door_pos") if lot.has_meta("blueprint_door_pos") else lot.global_position + Vector2(0, 32)
	bld.set_meta("blueprint_door_pos", door_pos)
	
	lot.get_parent().add_child(bld)
	lot.occupied_node = bld
	lot.is_occupied = true
	
	if bld.has_method("set_building_size"):
		bld.set_building_size(lot.lot_size)
		
	print("[WorldLayoutSpawner] Converted vacant lot at ", lot.global_position, " to Rental House.")
	return bld

func _parse_highways_and_plazas(parent: Node2D, hp_node: Node) -> void:
	_traverse_highways_and_plazas(parent, hp_node)

func _traverse_highways_and_plazas(parent: Node2D, node: Node) -> void:
	if node is Line2D:
		var points = node.points
		if points.size() > 0:
			var min_x = INF
			var max_x = -INF
			var min_y = INF
			var max_y = -INF
			for p in points:
				var gp = node.global_position + p
				if gp.x < min_x: min_x = gp.x
				if gp.x > max_x: max_x = gp.x
				if gp.y < min_y: min_y = gp.y
				if gp.y > max_y: max_y = gp.y
				
			var size_val = Vector2(max_x - min_x, max_y - min_y)
			var line_width = node.width
			if size_val.x < line_width: size_val.x = line_width
			if size_val.y < line_width: size_val.y = line_width
			
			var center = Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
			
			var road_script = load("res://components/roads/road_segment.gd")
			var road = Area2D.new()
			road.name = "RoadSegment_" + node.name
			road.set_script(road_script)
			road.size = size_val
			road.global_position = center
			parent.add_child(road)
			
	elif node is ColorRect and "plaza" in node.name.to_lower():
		var rect = node.get_global_rect()
		var center = rect.position + rect.size / 2.0
		
		var plaza_script = load("res://components/roads/plaza.gd")
		var plaza = Area2D.new()
		plaza.name = node.name
		plaza.set_script(plaza_script)
		plaza.size = rect.size
		plaza.global_position = center
		parent.add_child(plaza)
		
		var sett = _get_settlement_for_slot(node, parent)
		if sett:
			var market = ColorRect.new()
			market.name = sett.name + "Market"
			# Set to fully transparent so it doesn't overlap/obscure the blueprint plaza
			market.color = Color(0, 0, 0, 0)
			market.offset_left = rect.position.x - sett.global_position.x
			market.offset_right = rect.end.x - sett.global_position.x
			market.offset_top = rect.position.y - sett.global_position.y
			market.offset_bottom = rect.end.y - sett.global_position.y
			sett.add_child(market)
			sett.market_node_path = sett.get_path_to(market)
			
			var stall_scene = load(STALL_SCENE_PATH)
			var stall = stall_scene.instantiate() as MarketStall
			stall.name = sett.name + "MarketStall"
			stall.market_name = (sett.get("city_name") if sett.get("city_name") else sett.get("town_name")) + " Market"
			stall.ownership_type = "Public"
			
			var stall_pos = rect.size / 2.0
			var stall_anchor = node.get_node_or_null("Stall_Anchor")
			if stall_anchor:
				stall_pos = stall_anchor.global_position - rect.position
			stall.position = stall_pos
			market.add_child(stall)
			
			var fountain_scene = load(FOUNTAIN_SCENE_PATH)
			if fountain_scene:
				var fountain = fountain_scene.instantiate()
				fountain.name = "Fountain_" + sett.name
				var fountain_pos = center + Vector2(-80, 0)
				var fountain_anchor = node.get_node_or_null("Fountain_Anchor")
				if fountain_anchor:
					fountain_pos = fountain_anchor.global_position
				fountain.global_position = fountain_pos
				parent.add_child(fountain)
				
	for child in node.get_children():
		_traverse_highways_and_plazas(parent, child)

func reconnect_lots_to_buildings() -> void:
	# Run after a delay to ensure all deserialized buildings are positioned
	await parent_node.get_tree().process_frame
	await parent_node.get_tree().process_frame
	
	var lots = parent_node.get_tree().get_nodes_in_group("BuildingLots")
	var buildings = parent_node.get_tree().get_nodes_in_group("production_buildings")
	var houses = parent_node.get_tree().get_nodes_in_group("Houses")
	
	var all_blds = []
	all_blds.append_array(buildings)
	all_blds.append_array(houses)
	
	for lot in lots:
		if not is_instance_valid(lot):
			continue
		# Find if any building is centered exactly (or close to) this lot
		var occupied_by = null
		for bld in all_blds:
			if is_instance_valid(bld) and bld.global_position.distance_to(lot.global_position) < 10.0:
				occupied_by = bld
				break
		if occupied_by:
			lot.is_occupied = true
			lot.occupied_node = occupied_by
			lot.call("_update_barrier_state")
			lot.queue_redraw()
		else:
			if lot.is_occupied and not is_instance_valid(lot.occupied_node):
				lot.is_occupied = false
				lot.occupied_node = null
				lot.call("_update_barrier_state")
				lot.queue_redraw()

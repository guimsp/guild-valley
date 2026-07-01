extends Node

const NPC_SCENE_PATH = "res://entities/npc/npc.tscn"

var npcs_data: Array = []

func _ready() -> void:
	var file = FileAccess.open("res://common/npc/npcs.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			npcs_data = json.data

func spawn_initial_npcs(parent: Node2D) -> void:
	# 1. Clear old NPCs
	for npc in parent.get_tree().get_nodes_in_group("NPCs"):
		if is_instance_valid(npc) and not npc.is_hired:
			npc.queue_free()
			
	await parent.get_tree().physics_frame
	await parent.get_tree().physics_frame
	
	# Try to find the blueprint
	var blueprint = parent.get_node_or_null("world_map_blueprint")
	
	# Helper to find anchor positions with fallback
	# Helper to find anchor positions with fallback (using immutable ID to decouple display names)
	var get_story_npc_spawn_pos = func(npc_id: String, default_pos: Vector2) -> Vector2:
		if not blueprint:
			return default_pos
		var story_npcs_node = blueprint.get_node_or_null("Spawners/Story_NPCs")
		if not story_npcs_node:
			return default_pos
		
		var id_clean = npc_id.replace(" ", "").to_lower()
		for child in story_npcs_node.get_children():
			var child_name = child.name.to_lower()
			if child_name == id_clean or child_name == "spawn_" + id_clean:
				return child.global_position
			for sub_child in child.get_children():
				var sub_child_name = sub_child.name.to_lower()
				if sub_child_name == id_clean or sub_child_name == "spawn_" + id_clean:
					return sub_child.global_position
		return default_pos
	
	# Find ValleyCity to determine fallback positions
	var valley_city = parent.get_node_or_null("ValleyCity")
	var city_pos = valley_city.global_position if valley_city else Vector2(2591.4, -1823.7)

	var npc_scene = load(NPC_SCENE_PATH)
	
	# 2. Spawn unique NPCs from the database
	for spec in npcs_data:
		if not spec.get("is_unique", false):
			continue
			
		var npc = npc_scene.instantiate()
		npc.name = spec["name"]
		npc.npc_name = spec["name"]
		npc.quest_npc_id = spec["id"]
		npc.set_meta("quest_ids", spec.get("quests", []))
		
		# Convert class string to enum
		var class_enum = NPCProfile.SocialClass.PEASANT
		match spec.get("social_class", "Peasant"):
			"Citizen": class_enum = NPCProfile.SocialClass.CITIZEN
			"Noble": class_enum = NPCProfile.SocialClass.NOBLE
			
		# Set NPC Type enum
		var type_enum = NPCAIController.NPCType.TYPE_EMPLOYEE
		match spec.get("npc_type", "EMPLOYEE"):
			"RELATION_TARGET": type_enum = NPCAIController.NPCType.TYPE_RELATION_TARGET
			"CONSUMER": type_enum = NPCAIController.NPCType.TYPE_CONSUMER
			"STATIC": type_enum = NPCAIController.NPCType.TYPE_STATIC
			
		npc.npc_type = type_enum
		
		# Resolve spawn settlement node dynamically
		var sett_name = spec.get("spawn_settlement", "")
		var target_sett = parent.find_child(sett_name, true, false) if sett_name != "" else null
		if not target_sett and sett_name != "":
			target_sett = parent.get_node_or_null(sett_name)
		if not target_sett:
			target_sett = valley_city
			
		npc.set("spawn_settlement", target_sett)
		if target_sett:
			npc.province = target_sett.ownership_province
			
		# Find spawn position
		var spawn_pos = target_sett.global_position if target_sett else city_pos
		var is_interior = false
		if spec.get("interior_name", "") != "":
			# Scope find_child to target_sett so we find the correct city-scoped interior!
			var room = null
			if target_sett:
				room = target_sett.find_child(spec["interior_name"], true, false)
			if not room:
				# Fallback: search globally if not found under settlement
				var parent_scene = parent.get_tree().current_scene if parent.get_tree().current_scene else parent.get_tree().root
				room = parent_scene.find_child(spec["interior_name"], true, false)
			if room:
				spawn_pos = room.global_position + Vector2(128, 200)
				is_interior = true
				
		# Always try to find story npc spawn position marker if available (for both interior and overworld)
		var marker_pos = get_story_npc_spawn_pos.call(spec["id"], Vector2.ZERO)
		if marker_pos != Vector2.ZERO:
			spawn_pos = marker_pos
		elif not is_interior:
			spawn_pos = spawn_pos + Vector2(randf_range(-150, 150), randf_range(-150, 150))
			
		# Assign home house first
		var home_building_id = spec.get("home_building_id", "")
		if home_building_id != "":
			for house in parent.get_tree().get_nodes_in_group("Houses"):
				if house.name == home_building_id or house.name.to_lower().contains(spec["id"]):
					npc.home_house = house
					if not house.has_meta("occupants"):
						house.set_meta("occupants", [])
					house.get_meta("occupants").append(npc)
					break
					
		if npc.home_house == null and npc.npc_type != NPCAIController.NPCType.TYPE_STATIC:
			register_npc_with_expansion(npc, target_sett)

		# Override spawn position for overworld unique NPCs to their home doorstep (if no custom marker was set)
		if not is_interior and is_instance_valid(npc.home_house) and marker_pos == Vector2.ZERO:
			if npc.home_house.has_meta("blueprint_door_pos"):
				spawn_pos = npc.home_house.get_meta("blueprint_door_pos") + Vector2(randf_range(-40, 40), 32.0 + randf_range(-8, 8))
			else:
				spawn_pos = npc.home_house.global_position + Vector2(randf_range(-40, 40), 48.0 + randf_range(-8, 8))

		npc.global_position = spawn_pos
		npc.roams_interior_only = is_interior
		npc.is_quest_npc = spec.get("is_quest_npc", false)
		
		# Set hometown from target settlement
		var s_name = ""
		if target_sett:
			s_name = target_sett.get("city_name") if "city_name" in target_sett else target_sett.get("town_name")
		npc.hometown = s_name
		
		# Assign strongly-typed fields
		npc.npc_rank = spec.get("rank", "")
		if spec.has("color_modulate"):
			var c_arr = spec["color_modulate"]
			if c_arr is Array and c_arr.size() >= 3:
				var a = c_arr[3] if c_arr.size() > 3 else 1.0
				npc.rank_color = Color(c_arr[0], c_arr[1], c_arr[2], a)
		
		# Set metadata fields from spec (excluding rank/color modulates)
		for meta_key in ["is_guild_master", "is_guild_office_npc", "guild_profession", "office_name"]:
			if spec.has(meta_key):
				npc.set_meta(meta_key, spec[meta_key])
		
		# Initialize profile
		var profile = NPCProfile.new()
		profile.social_class = class_enum
		profile.initialize_demands()
		npc.profile = profile
		
		parent.add_child(npc)
		
		# Initialize dynamic runtime state after node enters tree
		if npc.npc_runtime_state:
			npc.npc_runtime_state.initialize_state(spec)
		
		# Hook relationship component
		var rel_comp = npc.get_node_or_null("RelationshipComponent")
		if rel_comp and spec.get("is_romanceable", false):
			rel_comp.hidden_preferences = spec.get("likes", [])
			rel_comp.disliked_preferences = spec.get("dislikes", [])
			rel_comp.profession_type = spec["id"]
			rel_comp.profession_level = 5 if spec["name"] == "Valeria" else 3
			if GameState.relationship_db.has(spec["id"]):
				rel_comp.load_save_data(GameState.relationship_db[spec["id"]])
				
		print("[WorldNPCSpawner] Spawned Unique NPC ", spec["name"], " at ", spawn_pos)
		
	# 3. Trigger initial ambient populations setup
	update_ambient_population(parent)

func update_ambient_population(parent: Node2D) -> void:
	var npc_scene = load(NPC_SCENE_PATH)
	if not npc_scene:
		return
		
	var settlements = []
	settlements.append_array(parent.get_tree().get_nodes_in_group("Cities"))
	settlements.append_array(parent.get_tree().get_nodes_in_group("Towns"))
	
	for sett in settlements:
		var province_name = sett.ownership_province
		if province_name == "":
			continue
			
		var is_city = sett.is_in_group("Cities")
		
		# Find all active consumer NPCs belonging to this settlement
		var sett_npcs = []
		for npc in parent.get_tree().get_nodes_in_group("NPCs"):
			if is_instance_valid(npc) and npc.npc_type == NPCAIController.NPCType.TYPE_CONSUMER:
				if npc.get("spawn_settlement") == sett and not npc.is_hired:
					sett_npcs.append(npc)
					
		# Base count & scaling
		var base_count = 20 if is_city else 10
		var level_bonus = 5 if is_city else 3
		var target_count = base_count + (sett.prosperity_level - 1) * level_bonus
		
		# Spawn if below target
		if sett_npcs.size() < target_count:
			var spawn_centers = _get_spawn_positions_for_settlement(sett)
			var needed = target_count - sett_npcs.size()
			for i in range(needed):
				var npc = npc_scene.instantiate()
				npc.province = province_name
				npc.set("spawn_settlement", sett)
				_initialize_npc_profile(npc, is_city, sett.prosperity_level)
				
				# Register home house FIRST before adding to tree
				register_npc_with_expansion(npc, sett)
				
				var center_pos = spawn_centers.pick_random()
				var spawn_pos = center_pos
				if is_instance_valid(npc.home_house):
					if npc.home_house.has_meta("blueprint_door_pos"):
						spawn_pos = npc.home_house.get_meta("blueprint_door_pos") + Vector2(0, 32)
					else:
						spawn_pos = npc.home_house.global_position + Vector2(0, 48)
						
				var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
				npc.global_position = spawn_pos + offset
				parent.add_child(npc)
				sett_npcs.append(npc)
				
		# Despawn if above target
		while sett_npcs.size() > target_count:
			var extra_npc = sett_npcs.pop_back()
			if is_instance_valid(extra_npc.home_house):
				if extra_npc.home_house.has_meta("occupants"):
					extra_npc.home_house.get_meta("occupants").erase(extra_npc)
			extra_npc.queue_free()
			
	print("[WorldNPCSpawner] Ambient populations verified and scaled.")

func spawn_prosperity_npcs(settlement: Node2D, delta_levels: int) -> void:
	var npc_scene = load(NPC_SCENE_PATH)
	if not npc_scene:
		return
		
	var is_city = settlement.is_in_group("Cities")
	var count = (5 if is_city else 3) * delta_levels
	var spawn_centers = _get_spawn_positions_for_settlement(settlement)
	var parent = settlement.get_parent()
	
	for i in range(count):
		var npc = npc_scene.instantiate()
		npc.province = settlement.ownership_province
		npc.set("spawn_settlement", settlement)
		_initialize_npc_profile(npc, is_city, settlement.prosperity_level)
		
		# Register home house FIRST before adding to tree
		register_npc_with_expansion(npc, settlement)
		
		var center_pos = spawn_centers.pick_random()
		var spawn_pos = center_pos
		if is_instance_valid(npc.home_house):
			if npc.home_house.has_meta("blueprint_door_pos"):
				spawn_pos = npc.home_house.get_meta("blueprint_door_pos") + Vector2(0, 32)
			else:
				spawn_pos = npc.home_house.global_position + Vector2(0, 48)
				
		var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		npc.global_position = spawn_pos + offset
		parent.add_child(npc)
		
	print("[WorldNPCSpawner] Spawned %d new NPCs for prosperity level-up in %s" % [count, settlement.name])

func _get_spawn_positions_for_settlement(settlement: Node2D) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child in settlement.get_children():
		if child.name.contains("Market"):
			for grandchild in child.get_children():
				if grandchild.is_in_group("MarketStall") or grandchild.name.contains("Stall"):
					positions.append(grandchild.global_position)
		if child.is_in_group("MarketStall") or child.name.contains("Stall"):
			positions.append(child.global_position)
		if child.name.contains("PublicHall") or child.name.contains("CityCouncil") or child.name.contains("QuestBoard") or child.name.contains("Guild"):
			positions.append(child.global_position)
			
	if positions.is_empty():
		positions.append(settlement.global_position)
	return positions

func _initialize_npc_profile(npc: CharacterBody2D, is_city: bool, prosperity_level: int) -> void:
	var profile = NPCProfile.new()
	var roll = randf()
	
	# Class distribution mapping
	if is_city:
		if roll <= 0.40:
			profile.social_class = NPCProfile.SocialClass.PEASANT
		elif roll <= 0.80:
			profile.social_class = NPCProfile.SocialClass.CITIZEN
		else:
			profile.social_class = NPCProfile.SocialClass.NOBLE
	else:
		if roll <= 0.70:
			profile.social_class = NPCProfile.SocialClass.PEASANT
		elif roll <= 0.95:
			profile.social_class = NPCProfile.SocialClass.CITIZEN
		else:
			profile.social_class = NPCProfile.SocialClass.NOBLE
			
	profile.initialize_demands()
	npc.profile = profile
	npc.npc_type = NPCAIController.NPCType.TYPE_CONSUMER

static func register_npc_to_house(npc: CharacterBody2D, settlement: Node2D) -> bool:
	var houses = settlement.get_tree().get_nodes_in_group("Houses")
	for house in houses:
		if is_instance_valid(house) and house.is_rental:
			if house.nearest_settlement == settlement:
				if not house.has_meta("occupants"):
					house.set_meta("occupants", [])
				var occupants = house.get_meta("occupants")
				if occupants.size() < 3:
					occupants.append(npc)
					house.set_meta("occupants", occupants)
					npc.home_house = house
					return true
	return false

static func register_npc_with_expansion(npc: CharacterBody2D, settlement: Node2D) -> void:
	if register_npc_to_house(npc, settlement):
		return
		
	# No vacant house found, convert an empty lot
	var lots = settlement.get_tree().get_nodes_in_group("BuildingLots")
	var target_lot = null
	for lot in lots:
		if is_instance_valid(lot) and not lot.is_occupied:
			if lot.nearest_settlement == settlement:
				target_lot = lot
				break
				
	if target_lot:
		var root = settlement.get_tree().current_scene
		var spawner = root.find_child("WorldLayoutSpawner", true, false)
		if not spawner:
			spawner = root.get_node_or_null("WorldLayoutSpawner")
		if not spawner:
			for child in root.get_children():
				if child.name == "WorldLayoutSpawner" or (child.get_script() and child.get_script().resource_path.contains("world_layout_spawner")):
					spawner = child
					break
		if spawner and spawner.has_method("convert_lot_to_rental_house"):
			var house = spawner.convert_lot_to_rental_house(target_lot)
			if house:
				if not house.has_meta("occupants"):
					house.set_meta("occupants", [])
				var occupants = house.get_meta("occupants")
				occupants.append(npc)
				house.set_meta("occupants", occupants)
				npc.home_house = house
				print("[NPCSpawner] Converted BuildingLot to RentalHouse for NPC ", npc.npc_name)
				return
				
	# FALLBACK: If no lot is available, crowd the NPC into the least occupied rental house in the settlement
	var houses = settlement.get_tree().get_nodes_in_group("Houses")
	var best_house = null
	var min_occupants = 9999
	for house in houses:
		if is_instance_valid(house) and house.is_rental and house.nearest_settlement == settlement:
			if not house.has_meta("occupants"):
				house.set_meta("occupants", [])
			var count = house.get_meta("occupants").size()
			if count < min_occupants:
				min_occupants = count
				best_house = house
				
	if best_house:
		var occupants = best_house.get_meta("occupants")
		occupants.append(npc)
		best_house.set_meta("occupants", occupants)
		npc.home_house = best_house
		print("[NPCSpawner] WARNING: Overcrowded NPC %s into existing house %s (Occupants: %d)" % [npc.npc_name, best_house.name, occupants.size()])
		return
				
	print("[NPCSpawner] WARNING: No house or building lot available for NPC ", npc.npc_name)

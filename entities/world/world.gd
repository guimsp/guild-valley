extends Node2D

func _ready() -> void:
	# Wait a couple of frames to ensure all child nodes (roads, settlements) are fully instantiated and ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Configure navigation map connection margin to stitch adjacent road segments directly
	var map_rid = get_world_2d().get_navigation_map()
	NavigationServer2D.map_set_edge_connection_margin(map_rid, 36.0)
	
	# Spawn global ground NavigationRegion2D for the background (travel_cost = 4.0)
	_setup_global_ground_navigation()
	
	# Build the road navigation network
	if GameState.has_method("rebuild_road_network"):
		GameState.rebuild_road_network()
		
	# Spawn NPCs for each settlement
	_spawn_npcs()
	
	# Spawn Influence Broker near Player's start location
	var broker_scene = load("res://entities/npc/influence_broker.tscn")
	if broker_scene:
		var broker = broker_scene.instantiate()
		broker.global_position = Vector2(1650, 480)
		add_child(broker)
		print("[World] Spawned Influence Broker at: ", broker.global_position)
	
	# Configure collision exceptions between player, rivals, and NPCs
	_setup_collision_exceptions()
	
	# Add player and rival house static colliders to carving group
	var p_house = get_node_or_null("PlayerHouse")
	if p_house: p_house.add_to_group("nav_carve_obstacles")
	var r_house = get_node_or_null("RivalHouse")
	if r_house: r_house.add_to_group("nav_carve_obstacles")
	var p_house2 = get_node_or_null("PlayerHouse2")
	if p_house2: p_house2.add_to_group("nav_carve_obstacles")
	var r_house2 = get_node_or_null("RivalHouse2")
	if r_house2: r_house2.add_to_group("nav_carve_obstacles")
	
	# Spawn Delivery Targets
	var church_archive = load("res://components/quests/delivery_target.gd").new()
	church_archive.name = "ChurchArchive"
	church_archive.target_id = "church_archive"
	church_archive.target_name = "Church Archive"
	church_archive.quest_item_id = "ancient_manuscript"
	church_archive.global_position = Vector2(1700, 320)
	add_child(church_archive)
	
	var rival_mailbox = load("res://components/quests/delivery_target.gd").new()
	rival_mailbox.name = "RivalMailbox"
	rival_mailbox.target_id = "rival_mailbox"
	rival_mailbox.target_name = "Rival Mailbox"
	rival_mailbox.quest_item_id = "confidential_documents"
	rival_mailbox.global_position = Vector2(1850, 480)
	add_child(rival_mailbox)

	# Setup Forest nodes yields
	var gf = get_node_or_null("GreatForest")
	if gf: gf.resource_type_id = "standard_timber"
	var of = get_node_or_null("OakhavenForest")
	if of: of.resource_type_id = "standard_timber"

	# Spawn Hunting Grounds programmatically
	_spawn_hunting_ground("Imperial Hunting Grounds", Vector2(2500, 2200))
	_spawn_hunting_ground("Oakhaven Hunting Grounds", Vector2(7500, 2200))

	# Spawn Guard Patrols programmatically
	_spawn_guard("Guard Captain Roger", Vector2(1600, 600), false)
	_spawn_guard("Guard Walter", Vector2(2500, 1500), true)
	_spawn_guard("Guard Captain Peter", Vector2(5500, 600), false)
	_spawn_guard("Guard Edmund", Vector2(7000, 1500), true)

	# Ensure all navigation regions are rebaked and completely synced with the final world state
	if GameState.has_method("rebake_all_navigation_regions"):
		GameState.rebake_all_navigation_regions()

func _setup_collision_exceptions() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	var rivals = get_tree().get_nodes_in_group("Rivals")
	var npcs = get_tree().get_nodes_in_group("NPCs")
	
	var all_characters = []
	all_characters.append_array(players)
	all_characters.append_array(rivals)
	all_characters.append_array(npcs)
	
	for i in range(all_characters.size()):
		var char_a = all_characters[i]
		if not is_instance_valid(char_a) or not char_a is CollisionObject2D:
			continue
		for j in range(i + 1, all_characters.size()):
			var char_b = all_characters[j]
			if not is_instance_valid(char_b) or not char_b is CollisionObject2D:
				continue
			char_a.add_collision_exception_with(char_b)
			char_b.add_collision_exception_with(char_a)
			
	print("[World] Configured collision exceptions between %d characters." % all_characters.size())


func _spawn_npcs() -> void:
	var npc_scene = load("res://entities/npc/npc.tscn")
	if not npc_scene:
		push_error("Failed to load NPC scene")
		return
		
	# Spawn in Cities
	for city in get_tree().get_nodes_in_group("Cities"):
		# Spawn 3 NPCs per city
		for i in range(3):
			var npc = npc_scene.instantiate()
			# Spawn offset to avoid overlap
			var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
			npc.global_position = city.global_position + offset
			_initialize_npc_profile(npc, true)
			add_child(npc)
			print("[World] Spawned NPC at City %s: %s" % [city.city_name if "city_name" in city else city.name, npc.global_position])
			
	# Spawn in Towns
	for town in get_tree().get_nodes_in_group("Towns"):
		# Spawn 2 NPCs per town
		for i in range(2):
			var npc = npc_scene.instantiate()
			var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
			npc.global_position = town.global_position + offset
			_initialize_npc_profile(npc, false)
			add_child(npc)
			print("[World] Spawned NPC at Town %s: %s" % [town.town_name if "town_name" in town else town.name, npc.global_position])

	# Spawn 4 Relation NPCs near Valley City start area
	var relation_specs = [
		{
			"name": "Elena",
			"quest_npc_id": "elena",
			"career": "tailor",
			"social_class": NPCProfile.SocialClass.PEASANT,
			"pos": Vector2(1600.0, 380.0),
			"likes": ["spool_thread", "red_dye", "blue_dye"]
		},
		{
			"name": "Aldous",
			"quest_npc_id": "aldous",
			"career": "scholar",
			"social_class": NPCProfile.SocialClass.CITIZEN,
			"pos": Vector2(1650.0, 300.0),
			"likes": ["ancient_manuscript", "ink", "paper"]
		},
		{
			"name": "Valeria",
			"quest_npc_id": "valeria",
			"career": "scholar",
			"social_class": NPCProfile.SocialClass.NOBLE,
			"pos": Vector2(1720.0, 380.0),
			"likes": ["confidential_documents", "gold_ring", "silver_necklace"]
		},
		{
			"name": "Gideon",
			"quest_npc_id": "gideon",
			"career": "craftsman",
			"social_class": NPCProfile.SocialClass.CITIZEN,
			"pos": Vector2(1550.0, 440.0),
			"likes": ["standard_timber", "iron_ingot", "iron_ore"]
		}
	]
	
	for spec in relation_specs:
		var npc = npc_scene.instantiate()
		npc.name = spec["name"]
		npc.npc_name = spec["name"]
		npc.quest_npc_id = spec["quest_npc_id"]
		npc.career = spec["career"]
		npc.global_position = spec["pos"]
		
		# Set up custom profile
		var profile = NPCProfile.new()
		profile.social_class = spec["social_class"]
		profile.demand_profiles["bread"] = {
			"cooldown_min": 40.0,
			"cooldown_max": 80.0,
			"timer": randf_range(10.0, 30.0)
		}
		npc.profile = profile
		npc.npc_type = NPCAIController.NPCType.TYPE_RELATION_TARGET
		npc.roams_interior_only = false
		
		add_child(npc)
		
		# Configure relationship component parameters
		var rel_comp = npc.get_node_or_null("RelationshipComponent")
		if rel_comp:
			rel_comp.hidden_preferences = spec["likes"]
			if spec["career"] == "craftsman":
				rel_comp.profession_type = "woodworker"
			else:
				rel_comp.profession_type = spec["career"]
			
			if spec["name"] == "Valeria":
				rel_comp.profession_level = 5
			else:
				rel_comp.profession_level = 3
				
			if GameState.relationship_db.has(spec["quest_npc_id"]):
				rel_comp.load_save_data(GameState.relationship_db[spec["quest_npc_id"]])
			
		print("[World] Spawned Relation NPC %s at %s" % [spec["name"], spec["pos"]])

func _initialize_npc_profile(npc: CharacterBody2D, is_city: bool) -> void:
	var profile = NPCProfile.new()
	
	# Class distribution matching user requirements:
	# Valley City (City): 40% Peasants, 40% Citizens, 20% Nobles
	# Mineville (Town): 70% Peasants, 25% Citizens, 5% Nobles
	var roll = randf()
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
			
	# Give item demand timers (shorter timers for quick testing)
	# Bread: all classes, requests bread every 30 to 60 seconds
	profile.demand_profiles["bread"] = {
		"cooldown_min": 30.0,
		"cooldown_max": 60.0,
		"timer": randf_range(5.0, 25.0)
	}
	# Ale: all classes, requests ale every 45 to 90 seconds
	profile.demand_profiles["ale"] = {
		"cooldown_min": 45.0,
		"cooldown_max": 90.0,
		"timer": randf_range(10.0, 40.0)
	}
	
	# Nobles and Citizens want premium items like cloth
	if profile.social_class != NPCProfile.SocialClass.PEASANT:
		profile.demand_profiles["cloth"] = {
			"cooldown_min": 60.0,
			"cooldown_max": 120.0,
			"timer": randf_range(15.0, 55.0)
		}
	else:
		# Peasants want wheat for raw food
		profile.demand_profiles["wheat"] = {
			"cooldown_min": 50.0,
			"cooldown_max": 100.0,
			"timer": randf_range(10.0, 50.0)
		}
		
	npc.profile = profile


func _setup_global_ground_navigation() -> void:
	var region = NavigationRegion2D.new()
	region.name = "GlobalGroundNavRegion"
	region.add_to_group("GlobalNavRegion")
	add_child(region)
	
	var poly = NavigationPolygon.new()
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	poly.source_geometry_group_name = "nav_carve_obstacles"
	poly.agent_radius = 16.0
	
	var vertices_p1 = PackedVector2Array([
		Vector2(-2000, -1000),
		Vector2(3200, -1000),
		Vector2(3200, 3000),
		Vector2(-2000, 3000)
	])
	var vertices_p2 = PackedVector2Array([
		Vector2(3800, -1000),
		Vector2(9500, -1000),
		Vector2(9500, 3000),
		Vector2(3800, 3000)
	])
	poly.add_outline(vertices_p1)
	poly.add_outline(vertices_p2)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	region.enabled = true
	
	NavigationServer2D.region_set_enter_cost(region.get_rid(), 4.0)
	NavigationServer2D.region_set_travel_cost(region.get_rid(), 4.0)
	
	region.bake_navigation_polygon(false)
	
	print("[World] Spawned global ground NavigationRegion2D with static collider parsing.")

func _spawn_hunting_ground(node_name: String, pos: Vector2) -> void:
	var mega_script = load("res://components/gathering/mega_node.gd")
	var node = Area2D.new()
	node.name = node_name.replace(" ", "")
	node.set_script(mega_script)
	node.node_name = node_name
	node.resource_type_id = "venison"
	node.base_fee = 50
	node.global_position = pos
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 96.0
	col.shape = shape
	node.add_child(col)
	
	add_child(node)
	print("[World] Programmatically spawned hunting ground: ", node_name, " at ", pos)

func _spawn_guard(guard_name: String, start_pos: Vector2, is_roaming: bool) -> void:
	var npc_scene = load("res://entities/npc/npc.tscn")
	if not npc_scene:
		return
	var guard = npc_scene.instantiate()
	var guard_script = load("res://entities/npc/guard_patrol.gd")
	guard.set_script(guard_script)
	guard.npc_name = guard_name
	guard.is_roaming_guard = is_roaming
	guard.global_position = start_pos
	add_child(guard)
	print("[World] Spawned Guard: ", guard_name, " at ", start_pos, " (roaming: ", is_roaming, ")")

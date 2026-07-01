extends Node2D

var layout_spawner = preload("res://entities/world/world_layout_spawner.gd")
var node_spawner = preload("res://entities/world/world_node_spawner.gd")
var npc_spawner = preload("res://entities/world/world_npc_spawner.gd")

var _layout_inst = null
var _node_inst = null
var _npc_inst = null

func _ready() -> void:
	# Initialize dynamic provinces on all singletons from visual blueprint
	var provinces: Array[String] = []
	var bp_ref = get_node_or_null("world_map_blueprint")
	if bp_ref:
		var prov_folder = bp_ref.get_node_or_null("Provinces")
		if prov_folder:
			for child in prov_folder.get_children():
				provinces.append(child.name.replace("_", " "))
				
	if not provinces.is_empty():
		if has_node("/root/PoliticsManager"):
			get_node("/root/PoliticsManager").initialize_politics_states(provinces)
		if has_node("/root/ProsperityManager"):
			get_node("/root/ProsperityManager").initialize_prosperity_states(provinces)
		if has_node("/root/GuildController"):
			get_node("/root/GuildController").initialize_guild_states(provinces)
		if has_node("/root/QuestManager"):
			get_node("/root/QuestManager").initialize_quest_states(provinces)

	# Instantiate our delegated components
	_layout_inst = layout_spawner.new()
	_node_inst = node_spawner.new()
	_npc_inst = npc_spawner.new()
	
	add_child(_layout_inst)
	add_child(_node_inst)
	add_child(_npc_inst)
	
	# Wait process frames to ensure parent/children ready states align
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Configure navigation map connection margin to stitch adjacent road segments directly
	var map_rid = get_world_2d().get_navigation_map()
	NavigationServer2D.map_set_edge_connection_margin(map_rid, 36.0)
	
	# 1. Rebuild world layout (settlements, roads, slots, portals, starting buildings)
	await _layout_inst.rebuild_world(self)
	
	# 2. Spawn gathering nodes (clustered L1, separated L4)
	await _node_inst.spawn_all_nodes(self)
	
	# 3. Setup regional boundaries and terrain obstacles from the blueprint
	_setup_regional_boundaries()
	_setup_terrain_obstacles()
	
	# 4. Setup global navigation polygons (3 separate regions for the 3 provinces)
	_setup_global_ground_navigation()
	
	# 5. Build the road navigation network
	if NavigationManager:
		NavigationManager.rebuild_road_network()
		
	# 6. Spawn NPCs
	await _npc_inst.spawn_initial_npcs(self)
	
	# Try to find the blueprint
	var blueprint = get_node_or_null("world_map_blueprint")
	
	# Helper to find anchor positions with fallback
	var get_story_npc_spawn_pos = func(npc_name: String, default_pos: Vector2) -> Vector2:
		if not blueprint:
			return default_pos
		var story_npcs_node = blueprint.get_node_or_null("Spawners/Story_NPCs")
		if not story_npcs_node:
			return default_pos
		
		var name_clean = npc_name.replace(" ", "").to_lower()
		for child in story_npcs_node.get_children():
			var child_name = child.name.to_lower()
			if child_name == name_clean or child_name == "spawn_" + name_clean:
				return child.global_position
			for sub_child in child.get_children():
				var sub_child_name = sub_child.name.to_lower()
				if sub_child_name == name_clean or sub_child_name == "spawn_" + name_clean:
					return sub_child.global_position
		return default_pos

	# 7. Influence Broker spawning removed (manually placed in map)
	
	# 8. Configure collision exceptions between character nodes
	_setup_collision_exceptions()
	
	# 9. Configure houses dynamically and add to carving group
	var p_house = get_node_or_null("PlayerHouse")
	if p_house:
		var house_script = GDScript.new()
		house_script.source_code = "extends StaticBody2D\nvar ownership_type: String = \"Player\"\nvar is_rental: bool = false\nvar owner_id: String = \"Player\"\n"
		house_script.reload()
		p_house.set_script(house_script)
		p_house.add_to_group("nav_carve_obstacles")
		p_house.add_to_group("Houses")
		
	var r_house = get_node_or_null("RivalHouse")
	if r_house:
		var house_script = GDScript.new()
		house_script.source_code = "extends StaticBody2D\nvar ownership_type: String = \"NPC\"\nvar is_rental: bool = false\nvar owner_id: String = \"Rival\"\n"
		house_script.reload()
		r_house.set_script(house_script)
		r_house.add_to_group("nav_carve_obstacles")
		r_house.add_to_group("Houses")
	
	# 10. Quest Delivery Targets spawning removed (manually placed in map)
	
	# 11. Connect signals for prosperity changes and daily population updates
	ProsperityManager.prosperity_updated.connect(func(_prov, _val): update_ambient_population())
	var last_day = TimeManager.time_days
	TimeManager.time_changed.connect(func(_hrs, _mins, days):
		if days != last_day:
			last_day = days
			update_ambient_population()
	)
	
	# Ensure all navigation regions are rebaked and completely synced
	if NavigationManager:
		NavigationManager.rebake_all_navigation_regions()
		
	if SaveLoadManager and SaveLoadManager.is_loading_game:
		SaveLoadManager.load_game()


func update_ambient_population() -> void:
	if _npc_inst:
		_npc_inst.update_ambient_population(self)

func reconnect_lots_to_buildings() -> void:
	if _layout_inst:
		_layout_inst.reconnect_lots_to_buildings()

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
		Vector2(-1000, -5000),
		Vector2(4500, -5000),
		Vector2(4500, 5000),
		Vector2(-1000, 5000)
	])
	var vertices_p2 = PackedVector2Array([
		Vector2(4500, -5000),
		Vector2(11000, -5000),
		Vector2(11000, 5000),
		Vector2(4500, 5000)
	])
	var vertices_p3 = PackedVector2Array([
		Vector2(11000, -5000),
		Vector2(16500, -5000),
		Vector2(16500, 5000),
		Vector2(11000, 5000)
	])
	poly.add_outline(vertices_p1)
	poly.add_outline(vertices_p2)
	poly.add_outline(vertices_p3)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	region.enabled = true
	
	NavigationServer2D.region_set_enter_cost(region.get_rid(), 8.0)
	NavigationServer2D.region_set_travel_cost(region.get_rid(), 8.0)
	
	region.bake_navigation_polygon(false)
	print("[World] Spawned global ground NavigationRegion2D with static collider parsing.")

func _setup_regional_boundaries() -> void:
	var blueprint = get_node_or_null("world_map_blueprint")
	if not blueprint:
		return
	var regions_folder = blueprint.get_node_or_null("Regions")
	if not regions_folder:
		return
		
	# Hide all regions visually
	regions_folder.visible = false
	
	var rect_nodes = []
	for child in regions_folder.get_children():
		if child is ColorRect:
			rect_nodes.append(child)
		else:
			for sub in child.get_children():
				if sub is ColorRect:
					rect_nodes.append(sub)
					
	for rect_node in rect_nodes:
		var global_rect = rect_node.get_global_rect()
		
		var area = Area2D.new()
		area.name = "Area_" + rect_node.name
		add_child(area)
		
		var collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = global_rect.size
		collision_shape.shape = rect_shape
		area.global_position = global_rect.position + global_rect.size / 2.0
		area.add_child(collision_shape)
		area.set_meta("region_rect", global_rect)
		area.set_meta("rect_node", rect_node)
		
		# Connect signals
		area.body_entered.connect(func(body):
			if body.is_in_group("Player"):
				_on_player_entered_region(rect_node)
		)
		area.body_exited.connect(func(body):
			if body.is_in_group("Player"):
				_on_player_exited_region(rect_node)
		)
		
		print("[World] Created dynamic region trigger for ", rect_node.name, " at rect ", global_rect)

func _on_player_entered_region(rect_node: ColorRect) -> void:
	if not is_instance_valid(rect_node):
		return
	var prov_name = rect_node.get_parent().name.replace("_", " ")
	var region_name = rect_node.name.replace("Region_", "").replace("_", " ")
	GameState.current_province = prov_name
	GameState.current_region_name = region_name
	print("[World] Player entered region: ", region_name, " in province: ", prov_name)

func _on_player_exited_region(_rect_node: ColorRect) -> void:
	pass

func _setup_terrain_obstacles() -> void:
	var blueprint = get_node_or_null("world_map_blueprint")
	if not blueprint:
		return
	var obstacles_node = blueprint.get_node_or_null("TerrainObstacles")
	if not obstacles_node:
		return
		
	# Generate physical StaticBody2D colliders for terrain obstacles (walls, rivers, lakes, clutter)
	# This ensures the player collides with them, and navigation region baking detects them
	_generate_physics_colliders(obstacles_node)

func _generate_physics_colliders(node: Node) -> void:
	if node is ColorRect:
		if not node.name.begins_with("Label") and not "Anchor" in node.name and not "Gate" in node.name:
			var rect = node.get_global_rect()
			var center = rect.position + rect.size / 2.0
			
			var static_body = StaticBody2D.new()
			static_body.name = "Collider_" + node.name
			static_body.global_position = center
			
			var col = CollisionShape2D.new()
			col.name = "CollisionShape2D"
			var shape = RectangleShape2D.new()
			shape.size = rect.size
			col.shape = shape
			static_body.add_child(col)
			
			static_body.add_to_group("nav_carve_obstacles")
			add_child(static_body)
			
	elif node is Line2D:
		var points = node.points
		if points.size() > 1:
			var static_body = StaticBody2D.new()
			static_body.name = "Collider_" + node.name
			static_body.add_to_group("nav_carve_obstacles")
			add_child(static_body)
			
			var line_width = node.width
			var global_transform = node.global_transform
			
			for i in range(points.size() - 1):
				var p1 = global_transform * points[i]
				var p2 = global_transform * points[i+1]
				
				var segment_length = p1.distance_to(p2)
				var center = (p1 + p2) / 2.0
				var angle = (p2 - p1).angle()
				
				var col = CollisionShape2D.new()
				col.name = "ColSegment_%d" % i
				var shape = RectangleShape2D.new()
				shape.size = Vector2(segment_length, line_width)
				col.shape = shape
				col.global_position = center
				col.rotation = angle
				static_body.add_child(col)
				
	for child in node.get_children():
		_generate_physics_colliders(child)

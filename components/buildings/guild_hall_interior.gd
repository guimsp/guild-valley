extends Control

@onready var exit_door: TeleportTrigger = get_node_or_null("ExitDoor")

var parent_building: Node2D = null

func _ready() -> void:
	add_to_group("Interiors")

func setup_interior(parent_b: Node2D, exit_pos: Vector2) -> void:
	parent_building = parent_b
	_generate_wall_collisions()
	_setup_interior_navigation()
	
	# Resolve blueprint exit door visual and build a real trigger Area2D on it
	var door_visual = get_node_or_null("ColorRect")
	if door_visual:
		var door_trigger = Area2D.new()
		door_trigger.name = "ExitDoorTrigger"
		door_trigger.set_script(load("res://components/teleport/teleport_trigger.gd"))
		door_trigger.position = door_visual.position + door_visual.size / 2.0
		
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = door_visual.size
		col.shape = shape
		door_trigger.add_child(col)
		
		add_child(door_trigger)
		exit_door = door_trigger
		
	if exit_door:
		exit_door.is_local_teleport = true
		exit_door.is_exit_door = true
		exit_door.target_spawn_position = exit_pos
		exit_door.ownership_type = parent_building.ownership_type
		exit_door.owner_id = parent_building.owner_id
		if exit_door.has_method("_update_door_state"):
			exit_door._update_door_state()
			
	# Check if this interior has any unique NPCs defined in npcs.json
	var has_fixed_npcs = false
	var file = FileAccess.open("res://common/npc/npcs.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			for spec in json.data:
				if spec.get("is_unique", false) and spec.get("interior_name", "") == name:
					has_fixed_npcs = true
					break

	if not has_fixed_npcs:
		if parent_building and parent_building.get("is_city_council") == true:
			_spawn_councilor_and_guards()
		else:
			_spawn_guild_master()
			_spawn_office_nodes()
	else:
		print("[GuildHallInterior] Skipping programmatic NPC spawn for ", name, " as it has fixed unique NPCs.")

func _get_guild_profession() -> String:
	if parent_building and "custom_name" in parent_building:
		var cn = parent_building.custom_name.to_lower()
		if "craftsman" in cn:
			return "craftsman"
		elif "scholar" in cn:
			return "scholar"
		elif "tailor" in cn:
			return "tailor"
		elif "patreon" in cn:
			return "patreon"
	return "General"

func _spawn_office_nodes() -> void:
	var center = Vector2(128, 128)
	var offices = [
		{ "name": "Grand Chairman", "office": "Grand Chairman", "pos": center + Vector2(-70, 40), "color": Color(1.0, 0.85, 0.5) },
		{ "name": "Donations Overseer", "office": "Logistics Overseer", "pos": center + Vector2(0, 40), "color": Color(0.6, 0.9, 0.7) },
		{ "name": "Materials Steward", "office": "Materials Steward", "pos": center + Vector2(70, 40), "color": Color(0.9, 0.6, 0.6) }
	]
	
	var npc_scene = load("res://entities/npc/npc.tscn")
	var prof = _get_guild_profession()
	for off in offices:
		if npc_scene:
			var npc = npc_scene.instantiate() as CharacterBody2D
			npc.name = off.name.replace(" ", "")
			npc.npc_name = off.name
			npc.position = off.pos
			npc.npc_type = NPCAIController.NPCType.TYPE_STATIC
			npc.roams_interior_only = true
			npc.is_quest_npc = false
			npc.set_meta("is_guild_office_npc", true)
			npc.set_meta("office_name", off.office)
			npc.set_meta("guild_profession", prof)
			
			npc.rank_color = off.color
				
			add_child(npc)
			if GameState and GameState.has_method("add_text_tag"):
				GameState.add_text_tag(npc, off.name)
			print("[GuildHallInterior] Spawned office NPC: ", off.name, " at ", npc.global_position)

func _spawn_guild_master() -> void:
	var npc_scene = load("res://entities/npc/npc.tscn")
	if npc_scene:
		var gm = npc_scene.instantiate() as CharacterBody2D
		gm.name = "GuildMaster"
		
		var prof = _get_guild_profession()
		gm.npc_name = prof.capitalize() + " Guild Master" if prof != "General" else "Guild Master"
		gm.position = Vector2(128, 58) # Top center of 256x256 room
		gm.npc_type = NPCAIController.NPCType.TYPE_STATIC
		gm.roams_interior_only = true
		gm.is_quest_npc = false
		gm.set_meta("is_guild_master", true)
		gm.set_meta("guild_profession", prof)
		
		gm.rank_color = Color(0.8, 0.9, 1.0)
			
		add_child(gm)
		print("[GuildHallInterior] Spawned Guild Master NPC: ", gm.npc_name, " at ", gm.global_position)


func _setup_interior_navigation() -> void:
	var local_group = "nav_carve_obstacles_interior_" + str(get_instance_id())
	if has_node("Walls"):
		for wall in get_node("Walls").get_children():
			wall.add_to_group(local_group)
			
	var region = NavigationRegion2D.new()
	region.name = "InteriorNavRegion"
	add_child(region)
	
	var poly = NavigationPolygon.new()
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	poly.source_geometry_group_name = local_group
	poly.agent_radius = 16.0
	
	# Bounded for 256x256 area with a 16px buffer offset
	var vertices = PackedVector2Array([
		Vector2(16, 16),
		Vector2(240, 16),
		Vector2(240, 240),
		Vector2(16, 240)
	])
	poly.add_outline(vertices)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	region.enabled = true
	region.bake_navigation_polygon(false)

func _generate_wall_collisions() -> void:
	var walls_node = get_node_or_null("Walls")
	if walls_node:
		for wall in walls_node.get_children():
			if wall is Line2D:
				var static_body = StaticBody2D.new()
				static_body.name = "WallsStaticBody_" + wall.name
				add_child(static_body)
				
				var col_poly = CollisionPolygon2D.new()
				col_poly.name = "WallsCollisionPolygon_" + wall.name
				col_poly.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
				col_poly.polygon = wall.points
				static_body.position = wall.position
				static_body.add_child(col_poly)
				static_body.add_to_group("nav_carve_obstacles")
				print("[GuildHallInterior] Generated StaticBody2D walls for ", wall.name)

func _spawn_councilor_and_guards() -> void:
	# Spawn Councilor Elena or Marcus
	var npc_scene = load("res://entities/npc/npc.tscn")
	if npc_scene:
		var npc = npc_scene.instantiate() as CharacterBody2D
		npc.is_loaded = true
		npc.roams_interior_only = true
		npc.anchor_position = global_position
		npc.is_quest_npc = true
		
		var province = GameState.get_province_of_node(parent_building) if GameState else "Valley Province"
		if province == "Oakhaven Province" or "Oakhaven" in parent_building.name:
			npc.npc_name = "Councilor Elena"
			npc.quest_npc_id = "councilor_elena"
		else:
			npc.npc_name = "Councilor Marcus"
			npc.quest_npc_id = "councilor_marcus"
			
		npc.rank_color = Color(1.0, 0.9, 0.5) # Gold modulate for councilors
			
		npc.position = Vector2(128, 68) # Standing at the center-north near desk
		add_child(npc)
		print("[GuildHallInterior] Spawned Councilor %s at %s" % [npc.npc_name, str(npc.position)])
		
		# Spawn Guards on either side of the room
		var guard_script = load("res://entities/npc/guard_patrol.gd")
		var is_oakhaven = province == "Oakhaven Province" or "Oakhaven" in parent_building.name
		
		var g1 = npc_scene.instantiate() as CharacterBody2D
		g1.set_script(guard_script)
		g1.is_loaded = true
		g1.roams_interior_only = true
		g1.is_roaming_guard = false
		g1.npc_name = "Guard Captain Peter" if is_oakhaven else "Guard Captain Roger"
		g1.position = Vector2(48, 128)
		add_child(g1)
		
		var g2 = npc_scene.instantiate() as CharacterBody2D
		g2.set_script(guard_script)
		g2.is_loaded = true
		g2.roams_interior_only = true
		g2.is_roaming_guard = false
		g2.npc_name = "Guard Edmund" if is_oakhaven else "Guard Walter"
		g2.position = Vector2(208, 128)
		add_child(g2)
		print("[GuildHallInterior] Spawned guards: %s and %s" % [g1.npc_name, g2.npc_name])

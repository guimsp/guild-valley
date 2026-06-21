extends Node2D

@onready var exit_door: TeleportTrigger = get_node_or_null("ExitDoor")

var parent_building: Node2D = null

func _ready() -> void:
	add_to_group("Interiors")

func setup_interior(parent_b: Node2D, exit_pos: Vector2) -> void:
	parent_building = parent_b
	_setup_interior_navigation()
	
	if exit_door:
		exit_door.is_local_teleport = true
		exit_door.target_spawn_position = exit_pos
		exit_door.ownership_type = parent_building.ownership_type
		exit_door.owner_id = parent_building.owner_id
		if exit_door.has_method("_update_door_state"):
			exit_door._update_door_state()
			
	_spawn_guild_master()
	_spawn_office_nodes()

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
	var offices = [
		{ "name": "Grand Chairman", "office": "Grand Chairman", "pos": Vector2(-200, 40), "color": Color(1.0, 0.85, 0.5) },
		{ "name": "Donations Overseer", "office": "Logistics Overseer", "pos": Vector2(0, 40), "color": Color(0.6, 0.9, 0.7) },
		{ "name": "Materials Steward", "office": "Materials Steward", "pos": Vector2(200, 40), "color": Color(0.9, 0.6, 0.6) }
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
			
			var sprite = npc.get_node_or_null("AnimatedSprite2D")
			if sprite:
				sprite.modulate = off.color
				
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
		gm.position = Vector2(0, -100)
		gm.npc_type = NPCAIController.NPCType.TYPE_STATIC
		gm.roams_interior_only = true
		gm.is_quest_npc = false
		gm.set_meta("is_guild_master", true)
		gm.set_meta("guild_profession", prof)
		
		var sprite = gm.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.modulate = Color(0.8, 0.9, 1.0)
			
		add_child(gm)
		print("[GuildHallInterior] Spawned Guild Master NPC: ", gm.npc_name, " at ", gm.global_position)


func _setup_interior_navigation() -> void:
	if has_node("Walls"):
		for wall in get_node("Walls").get_children():
			wall.add_to_group("nav_carve_obstacles")
			
	var region = NavigationRegion2D.new()
	region.name = "InteriorNavRegion"
	add_child(region)
	
	var poly = NavigationPolygon.new()
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	poly.source_geometry_group_name = "nav_carve_obstacles"
	poly.agent_radius = 16.0
	
	var vertices = PackedVector2Array([
		Vector2(-450, -300),
		Vector2(450, -300),
		Vector2(450, 300),
		Vector2(-450, 300)
	])
	poly.add_outline(vertices)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	region.enabled = true
	region.bake_navigation_polygon(false)

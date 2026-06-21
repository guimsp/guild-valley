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
			
	# Spawn Counselor Elena or Marcus
	var npc_scene = load("res://entities/npc/npc.tscn")
	if npc_scene:
		var npc = npc_scene.instantiate()
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
			
		var animated_sprite = npc.get_node_or_null("AnimatedSprite2D")
		if animated_sprite:
			animated_sprite.modulate = Color(1.0, 0.9, 0.5) # Gold modulate for councilors
			
		npc.position = Vector2(0, -60) # Standing at the center-north near desk
		add_child(npc)
		print("[LawhouseInterior] Spawned %s at %s" % [npc.npc_name, str(npc.position)])
		
		# Spawn Guards on either side of the room
		var guard_script = load("res://entities/npc/guard_patrol.gd")
		var is_oakhaven = province == "Oakhaven Province" or "Oakhaven" in parent_building.name
		
		var g1 = npc_scene.instantiate()
		g1.set_script(guard_script)
		g1.is_loaded = true
		g1.roams_interior_only = true
		g1.is_roaming_guard = false
		g1.npc_name = "Guard Captain Peter" if is_oakhaven else "Guard Captain Roger"
		g1.position = Vector2(-160, -60)
		add_child(g1)
		
		var g2 = npc_scene.instantiate()
		g2.set_script(guard_script)
		g2.is_loaded = true
		g2.roams_interior_only = true
		g2.is_roaming_guard = false
		g2.npc_name = "Guard Edmund" if is_oakhaven else "Guard Walter"
		g2.position = Vector2(160, -60)
		add_child(g2)
		print("[LawhouseInterior] Spawned guards: %s and %s" % [g1.npc_name, g2.npc_name])

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
		Vector2(-250, -200),
		Vector2(250, -200),
		Vector2(250, 200),
		Vector2(-250, 200)
	])
	poly.add_outline(vertices)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	region.enabled = true
	region.bake_navigation_polygon(false)

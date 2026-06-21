extends Node2D

@onready var exit_door: TeleportTrigger = get_node_or_null("ExitDoor")
@onready var crafting_bench: CraftingBench = get_node_or_null("CraftingBench")
@onready var storage_chest: MarketStall = get_node_or_null("StorageChest")

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
			
	if parent_building and parent_building.is_in_group("Houses"):
		if crafting_bench:
			crafting_bench.queue_free()
			crafting_bench = null

	if crafting_bench:
		crafting_bench.ownership_type = parent_building.ownership_type
		crafting_bench.owner_id = parent_building.owner_id
		crafting_bench.bench_name = parent_building.name + " Bench"
		# Set recipes from parent building if applicable
		var parent_bench = parent_building.get_node_or_null("CraftingBench")
		if parent_bench:
			crafting_bench.recipes = parent_bench.recipes
			
	if storage_chest:
		storage_chest.ownership_type = parent_building.ownership_type
		storage_chest.owner_id = parent_building.owner_id
		storage_chest.market_name = parent_building.name + " Chest"
		storage_chest.parent_building = parent_building
		if parent_building and "inventory" in parent_building and parent_building.inventory:
			storage_chest.inventory = parent_building.inventory
		elif storage_chest.inventory:
			storage_chest.inventory.max_slots = 8
			
	# If parent building is NPC owned, lock exit door for others (or disable interaction)
	if parent_building.ownership_type == "NPC":
		if exit_door:
			exit_door.ownership_type = "NPC"
			if exit_door.has_method("_update_door_state"):
				exit_door._update_door_state()

	# Spawn bank teller desk/trigger if parent building is a Bank
	if parent_building and parent_building.is_in_group("Banks"):
		var teller_trigger = Area2D.new()
		teller_trigger.name = "TellerTrigger"
		teller_trigger.position = Vector2(0, -60)
		teller_trigger.set_script(load("res://components/buildings/bank_teller_trigger.gd"))
		teller_trigger.parent_building = parent_building
		
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 24.0
		col.shape = shape
		teller_trigger.add_child(col)
		
		# Visual counter desk
		var desk_visual = ColorRect.new()
		desk_visual.name = "VisualDesk"
		desk_visual.size = Vector2(48, 20)
		desk_visual.position = Vector2(-24, -10)
		desk_visual.color = Color(0.45, 0.35, 0.2, 1) # Wood brown color
		teller_trigger.add_child(desk_visual)
		
		add_child(teller_trigger)

	# Spawn management ledger if parent building is NOT a private house/rental
	if parent_building and not parent_building.is_in_group("Houses"):
		var ledger = Area2D.new()
		ledger.name = "BuildingLedger"
		ledger.position = Vector2(0, -30)
		ledger.set_script(load("res://components/buildings/building_ledger.gd"))
		ledger.parent_building = parent_building
		
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 24.0
		col.shape = shape
		ledger.add_child(col)
		
		# Visual ledger desk/book
		var ledger_visual = ColorRect.new()
		ledger_visual.name = "VisualBook"
		ledger_visual.size = Vector2(32, 16)
		ledger_visual.position = Vector2(-16, -8)
		ledger_visual.color = Color(0.18, 0.45, 0.25, 1) # Green leather ledger book
		ledger.add_child(ledger_visual)
		
		add_child(ledger)

	# Spawn Commercial Routes Console if parent building is a private Player House
	if parent_building and parent_building.is_in_group("Houses") and parent_building.ownership_type == "Player" and not parent_building.is_rental:
		var console_scene = load("res://components/buildings/commercial_routes_console.tscn")
		if console_scene:
			var console = console_scene.instantiate()
			console.name = "CommercialRoutesConsole"
			console.position = Vector2(-80, -30)
			add_child(console)

	# Spawn Counselor NPC if parent building is the City Council
	if parent_building and parent_building.get("is_city_council") == true:
		if storage_chest:
			storage_chest.queue_free()
			storage_chest = null
			
		var npc_scene = load("res://entities/npc/npc.tscn")
		if npc_scene:
			var npc = npc_scene.instantiate()
			# Set is_loaded = true to prevent ready-based name randomization
			npc.is_loaded = true
			npc.roams_interior_only = true
			npc.anchor_position = global_position
			npc.is_quest_npc = true
			
			var province = GameState.get_province_of_node(parent_building)
			if province == "Oakhaven Province" or "Oakhaven" in parent_building.name:
				npc.npc_name = "Councilor Elena"
				npc.quest_npc_id = "councilor_elena"
			else:
				npc.npc_name = "Councilor Marcus"
				npc.quest_npc_id = "councilor_marcus"
				
			var animated_sprite = npc.get_node_or_null("AnimatedSprite2D")
			if animated_sprite:
				# Gold modulate for councilors
				animated_sprite.modulate = Color(1.0, 0.9, 0.5)
				
			npc.position = Vector2.ZERO # Center of the room
			add_child(npc)


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
		Vector2(-150, -100),
		Vector2(150, -100),
		Vector2(150, 100),
		Vector2(-150, 100)
	])
	poly.add_outline(vertices)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	region.enabled = true
	region.bake_navigation_polygon(false)

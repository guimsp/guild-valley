extends Control

@onready var exit_door: TeleportTrigger = get_node_or_null("ExitDoor")
@onready var crafting_bench: CraftingBench = get_node_or_null("CraftingBench")
@onready var storage_chest: MarketStall = get_node_or_null("StorageChest")

var parent_building: Node2D = null

func _ready() -> void:
	add_to_group("Interiors")

func setup_interior(parent_b: Node2D, exit_pos: Vector2) -> void:
	parent_building = parent_b
	_generate_wall_collisions()
	_setup_interior_navigation()

	# Resolve blueprint exit door visual and build a real trigger Area2D on it
	var door_visual = get_node_or_null("Exit_Anchor")
	if not door_visual:
		door_visual = get_node_or_null("ColorRect")
	if not door_visual:
		door_visual = get_node_or_null("ColorExit_AnchorRect")
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
			
	_update_workbenches()

	# Listen to workbench upgrades
	if parent_building and parent_building.get("upgrade_component"):
		parent_building.upgrade_component.improvement_purchased.connect(func(imp_id, _new_lvl):
			if imp_id == "extra_workbench":
				_update_workbenches()
		)

	if not storage_chest and parent_building:
		# Dynamically spawn storage chest if not present statically
		var slot_chest = get_node_or_null("StorageChest_Slot")
		var chest_pos = slot_chest.position if slot_chest else Vector2(196, 128)
		var chest_scene = load("res://components/market/market_stall.tscn")
		if chest_scene:
			var chest = chest_scene.instantiate()
			chest.name = "StorageChest"
			chest.position = chest_pos
			add_child(chest)
			storage_chest = chest
			
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
		teller_trigger.position = Vector2(128, 68) # Centered
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
		ledger.position = Vector2(128, 90) # Centered
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
			console.position = Vector2(50, 90)
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
				
			npc.position = Vector2(128, 128) # Center of the room
			add_child(npc)


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

var workbenches: Array = []

func get_free_workbench(npc: CharacterBody2D) -> Node2D:
	var employees = get_tree().get_nodes_in_group("NPCs")
	var busy_benches = []
	for emp in employees:
		if emp != npc and emp.is_in_group("NPCs") and emp.has_meta("assigned_bench"):
			var b = emp.get_meta("assigned_bench")
			if is_instance_valid(b):
				busy_benches.append(b)
				
	for bench in workbenches:
		if not busy_benches.has(bench):
			return bench
			
	return crafting_bench

func _update_workbenches() -> void:
	if not parent_building:
		return
	if parent_building.is_in_group("Houses"):
		if crafting_bench:
			crafting_bench.queue_free()
			crafting_bench = null
		workbenches.clear()
		return
		
	var workbench_level = parent_building.improvements.get("extra_workbench", 0)
	
	# Clean up any workbenches that are no longer valid (re-creating them is safer to sync)
	for b in workbenches:
		if is_instance_valid(b) and b != crafting_bench:
			b.queue_free()
	workbenches.clear()
	
	# 1. Bench 1 (always present if not a house)
	if not crafting_bench:
		var slot_bench = get_node_or_null("Bench_Slot_1")
		var bench_pos = slot_bench.position if slot_bench else Vector2(60, 128)
		var bench_scene = load("res://components/crafting/crafting_bench.tscn")
		if bench_scene:
			var bench = bench_scene.instantiate()
			bench.name = "CraftingBench"
			bench.position = bench_pos
			add_child(bench)
			crafting_bench = bench
			
	if crafting_bench:
		_setup_bench_properties(crafting_bench)
		workbenches.append(crafting_bench)
		
	# 2. Bench 2 (extra_workbench >= 1)
	if workbench_level >= 1:
		var slot_bench = get_node_or_null("Bench_Slot_2")
		if slot_bench:
			var bench = _spawn_additional_bench(slot_bench.position, "CraftingBench_2")
			if bench:
				workbenches.append(bench)
				
	# 3. Bench 3 (extra_workbench >= 2)
	if workbench_level >= 2:
		var slot_bench = get_node_or_null("Bench_Slot_3")
		if slot_bench:
			var bench = _spawn_additional_bench(slot_bench.position, "CraftingBench_3")
			if bench:
				workbenches.append(bench)

func _spawn_additional_bench(pos: Vector2, bench_name: String) -> Node2D:
	var bench_scene = load("res://components/crafting/crafting_bench.tscn")
	if bench_scene:
		var bench = bench_scene.instantiate() as Node2D
		bench.name = bench_name
		bench.position = pos
		add_child(bench)
		_setup_bench_properties(bench)
		return bench
	return null

func _setup_bench_properties(bench: Node2D) -> void:
	bench.ownership_type = parent_building.ownership_type
	bench.owner_id = parent_building.owner_id
	bench.bench_name = parent_building.name + " Bench"
	var parent_bench = parent_building.get_node_or_null("CraftingBench")
	if parent_bench:
		bench.recipes = parent_bench.recipes

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
				print("[InteriorTemplate] Generated StaticBody2D walls for ", wall.name)

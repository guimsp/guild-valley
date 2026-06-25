class_name City
extends Node2D

@export var city_name: String = "Capital City"
@export var radius_of_influence: float = 800.0
@export var prosperity: int = 50
@export var growth_points: int = 0
@export var growth_milestones: int = 100
@export var is_growing: bool = true
@export var market_node_path: NodePath
@export var security_level: float = 0.8
@export var wealth_level: float = 0.5
@export var criminal_heat: float = 0.0
@export var ownership_province: String = ""
@export var modifiers: Dictionary = {}

# Dynamic expansion and attributes
@export var prosperity_level: int = 1
@export var security_rating: float = 100.0
@export var unlocked_expansion_zones: Array = []
@export var wall_tier: int = 1

func _ready() -> void:
	add_to_group("Cities")
	# Re-create walls and landmarks on startup
	call_deferred("restore_expansion_zones")

func check_and_execute_expansion() -> void:
	var pm = get_node_or_null("/root/ProsperityManager")
	if not pm:
		return
		
	var prov_prop = pm.province_prosperity.get(ownership_province, 100.0)
	var target_level = pm.get_level_for_prosperity(prov_prop)
	
	# Execute expansion step-by-step
	var expanded = false
	while 1 + unlocked_expansion_zones.size() < target_level:
		var available = ["North", "South", "East", "West"]
		for zone in unlocked_expansion_zones:
			available.erase(zone)
			
		if available.is_empty():
			break
			
		var next_zone = available.pick_random()
		unlocked_expansion_zones.append(next_zone)
		_spawn_lots_for_zone(next_zone)
		expanded = true
		
	if expanded:
		wall_tier = clamp(1 + unlocked_expansion_zones.size(), 1, 3)
		rebuild_walls()
		apply_landmark_upgrades()
		
		# If level 3 is reached, trigger road network paved cobblestone overhaul
		if target_level >= 3:
			if pm.has_method("pave_province_roads"):
				pm.pave_province_roads(ownership_province)
				
		# Rebake navigation
		var nav_mgr = get_node_or_null("/root/NavigationManager")
		if nav_mgr:
			nav_mgr.rebuild_road_network()
			nav_mgr.rebake_all_navigation_regions()

func restore_expansion_zones() -> void:
	# Clear dynamically spawned lots first to prevent duplicates
	for child in get_children():
		if child.is_in_group("DynamicLots"):
			child.queue_free()
			
	# Wait for queue free to complete
	await get_tree().physics_frame
	
	# Respawn
	for zone in unlocked_expansion_zones:
		_spawn_lots_for_zone(zone)
		
	rebuild_walls()
	apply_landmark_upgrades()

func _spawn_lots_for_zone(zone: String) -> void:
	var lot_scene = load("res://components/placement/building_lot.tscn")
	if not lot_scene:
		push_error("Failed to load building lot scene!")
		return
		
	# Space out 6 lots in a 3x2 grid relative to city position
	# Lot footprint is 96x80. Use 120x100 spacing
	var offsets = []
	match zone:
		"North":
			for x in [-120, 120]:
				for y in [-450, -350, -250]:
					offsets.append(Vector2(x, y))
		"South":
			for x in [-120, 120]:
				for y in [250, 350, 450]:
					offsets.append(Vector2(x, y))
		"East":
			for x in [300, 420, 540]:
				for y in [-50, 50]:
					offsets.append(Vector2(x, y))
		"West":
			for x in [-540, -420, -300]:
				for y in [-50, 50]:
					offsets.append(Vector2(x, y))
					
	for i in range(offsets.size()):
		var lot = lot_scene.instantiate() as Area2D
		lot.name = ("Lot_Dynamic_%s_%d" % [zone, i]).validate_node_name()
		lot.add_to_group("DynamicLots")
		lot.add_to_group("BuildingLots")
		lot.position = offsets[i]
		add_child(lot)

func rebuild_walls() -> void:
	# Clear old walls
	for child in get_children():
		if child.is_in_group("CityWalls"):
			child.queue_free()
			
	# Calculate current bounding box based on unlocked zones
	var min_x = -320.0
	var max_x = 320.0
	var min_y = -180.0
	var max_y = 520.0
	
	if "West" in unlocked_expansion_zones: min_x = -620.0
	if "East" in unlocked_expansion_zones: max_x = 620.0
	if "North" in unlocked_expansion_zones: min_y = -520.0
	if "South" in unlocked_expansion_zones: max_y = 620.0
	
	# Draw line walls
	var line = Line2D.new()
	line.name = "WallLine"
	line.add_to_group("CityWalls")
	line.closed = true
	line.points = PackedVector2Array([
		Vector2(min_x, min_y),
		Vector2(max_x, min_y),
		Vector2(max_x, max_y),
		Vector2(min_x, max_y)
	])
	
	# Aesthetics based on wall_tier
	match wall_tier:
		1: # Palisade
			line.default_color = Color(0.48, 0.38, 0.28)
			line.width = 8.0
		2: # Refined wood walls
			line.default_color = Color(0.35, 0.2, 0.1)
			line.width = 14.0
		3: # Massive Stone Walls
			line.default_color = Color(0.5, 0.5, 0.52)
			line.width = 22.0
			
			# Add stone accent inner line
			var inner_line = Line2D.new()
			inner_line.name = "StoneAccent"
			inner_line.add_to_group("CityWalls")
			inner_line.closed = true
			inner_line.points = line.points
			inner_line.default_color = Color(0.35, 0.35, 0.37)
			inner_line.width = 6.0
			add_child(inner_line)
			
	add_child(line)
	
	# Add StaticBody2D collisions so NPCs and rivals cannot cross city boundaries
	var static_body = StaticBody2D.new()
	static_body.name = "WallCollisions"
	static_body.add_to_group("CityWalls")
	static_body.add_to_group("nav_carve_obstacles") # Carve navigation regions
	static_body.collision_layer = 4 # NPC Barrier layer
	static_body.collision_mask = 0
	
	# Add 4 collision shapes (North, South, East, West segment boundaries)
	var shapes = [
		[Vector2(min_x, min_y), Vector2(max_x, min_y)], # North
		[Vector2(min_x, max_y), Vector2(max_x, max_y)], # South
		[Vector2(min_x, min_y), Vector2(min_x, max_y)], # West
		[Vector2(max_x, min_y), Vector2(max_x, max_y)]  # East
	]
	
	for segment in shapes:
		var col = CollisionShape2D.new()
		var shape = SegmentShape2D.new()
		shape.a = segment[0]
		shape.b = segment[1]
		col.shape = shape
		static_body.add_child(col)
		
	add_child(static_body)

func apply_landmark_upgrades() -> void:
	for child in get_children():
		if child.is_in_group("Houses") or child.name.contains("Guild") or child.name.contains("Council") or child.name.contains("Hall"):
			var roof = child.get_node_or_null("Exterior/Roof") as ColorRect
			if roof:
				# Apply tier colors to Roof
				match wall_tier:
					1:
						roof.color = Color(0.18, 0.24, 0.35) # standard blueish
						var frame = roof.get_node_or_null("GoldFrame")
						if frame: frame.visible = false
					2:
						roof.color = Color(0.5, 0.28, 0.18) # warm wood cedar
						var frame = roof.get_node_or_null("GoldFrame")
						if frame: frame.visible = false
					3:
						roof.color = Color(0.12, 0.28, 0.45) # grand royal slate
						
						# Create or show gold frame accent
						var frame = roof.get_node_or_null("GoldFrame") as ColorRect
						if not frame:
							frame = ColorRect.new()
							frame.name = "GoldFrame"
							frame.anchors_preset = Control.PRESET_FULL_RECT
							frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
							frame.grow_vertical = Control.GROW_DIRECTION_BOTH
							frame.offset_left = 2
							frame.offset_right = -2
							frame.offset_top = 2
							frame.offset_bottom = -2
							frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
							frame.color = Color(0.85, 0.72, 0.2, 0.3) # gold semi transparent frame
							roof.add_child(frame)
						frame.visible = true

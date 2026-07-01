extends Node

# --- Road Navigation Network ---
var road_astar: AStar2D = AStar2D.new()
var road_points_map: Dictionary = {}
var is_baking: bool = false
var _bake_queued: bool = false

func rebuild_road_network() -> void:
	road_astar.clear()
	road_points_map.clear()
	
	var step_size = 64.0
	var points_to_connect = []
	
	# Gather road segments
	var roads = get_tree().get_nodes_in_group("Roads")
	for road in roads:
		var size = road.size if "size" in road else Vector2(64, 64)
		var half_size = size / 2.0
		var pos = road.global_position
		
		# Subdivide road segment into 64x64 grids
		var start_x = -half_size.x + step_size / 2.0
		var end_x = half_size.x
		var start_y = -half_size.y + step_size / 2.0
		var end_y = half_size.y
		
		var x = start_x
		while x < end_x:
			var y = start_y
			while y < end_y:
				var grid_pos = pos + Vector2(x, y)
				var snapped_pos = Vector2(
					round(grid_pos.x / 16.0) * 16.0,
					round(grid_pos.y / 16.0) * 16.0
				)
				if not snapped_pos in points_to_connect:
					points_to_connect.append(snapped_pos)
				y += step_size
			x += step_size
			
	# Gather plazas
	var plazas = get_tree().get_nodes_in_group("Plazas")
	for plaza in plazas:
		var size = plaza.size if "size" in plaza else Vector2(128, 128)
		var half_size = size / 2.0
		var pos = plaza.global_position
		
		var start_x = -half_size.x + step_size / 2.0
		var end_x = half_size.x
		var start_y = -half_size.y + step_size / 2.0
		var end_y = half_size.y
		
		var x = start_x
		while x < end_x:
			var y = start_y
			while y < end_y:
				var grid_pos = pos + Vector2(x, y)
				var snapped_pos = Vector2(
					round(grid_pos.x / 16.0) * 16.0,
					round(grid_pos.y / 16.0) * 16.0
				)
				if not snapped_pos in points_to_connect:
					points_to_connect.append(snapped_pos)
				y += step_size
			x += step_size
			
	# Gather market stalls to integrate them into the road network so NPCs can navigate to them
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	var stall_positions = []
	for stall in stalls:
		if is_instance_valid(stall):
			var pos = stall.global_position
			var snapped_pos = Vector2(
				round(pos.x / 16.0) * 16.0,
				round(pos.y / 16.0) * 16.0
			)
			if not snapped_pos in points_to_connect:
				points_to_connect.append(snapped_pos)
			if not snapped_pos in stall_positions:
				stall_positions.append(snapped_pos)

	# Add points to AStar
	var point_id = 0
	for pos in points_to_connect:
		road_astar.add_point(point_id, pos)
		road_points_map[pos] = point_id
		point_id += 1
		
	# Connect adjacent points within 92.0 pixels
	for i in range(points_to_connect.size()):
		var pos_a = points_to_connect[i]
		var id_a = road_points_map[pos_a]
		for j in range(i + 1, points_to_connect.size()):
			var pos_b = points_to_connect[j]
			var id_b = road_points_map[pos_b]
			if pos_a.distance_to(pos_b) <= 92.0:
				road_astar.connect_points(id_a, id_b)

	# Ensure every stall is connected to the nearest road/plaza point to prevent navigation isolation
	for stall_pos in stall_positions:
		var stall_id = road_points_map[stall_pos]
		var connections = road_astar.get_point_connections(stall_id)
		if connections.is_empty():
			var closest_dist = INF
			var closest_id = -1
			for pos in points_to_connect:
				if pos == stall_pos or pos in stall_positions:
					continue
				var dist = stall_pos.distance_to(pos)
				if dist < closest_dist:
					closest_dist = dist
					closest_id = road_points_map[pos]
			if closest_id != -1:
				road_astar.connect_points(stall_id, closest_id)

	print("[RoadNavigation] Rebuilt network with %d points." % road_astar.get_point_count())

func get_road_path(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	if road_astar.get_point_count() == 0:
		return [to_pos]
		
	var from_id = road_astar.get_closest_point(from_pos)
	var to_id = road_astar.get_closest_point(to_pos)
	
	var path_points = road_astar.get_point_path(from_id, to_id)
	var final_path: Array[Vector2] = []
	
	for p in path_points:
		final_path.append(p)
		
	return final_path

func rebake_all_navigation_regions() -> void:
	_bake_queued = true
	_trigger_debounced_bake()

func _trigger_debounced_bake() -> void:
	if is_baking:
		return
		
	# Debounce wait of 0.3s to allow rapid sequential spawns/loads to settle
	await get_tree().create_timer(0.3).timeout
	
	if not _bake_queued:
		return
	if is_baking:
		return
		
	_bake_queued = false
	is_baking = true
	
	# Await a physics frame to ensure all colliders are registered in the physics server
	await get_tree().physics_frame
	
	# Dynamically gather all building/obstacle nodes and add them to the carving group
	var obstacle_groups = ["MarketStall", "Houses", "Bakeries", "Smelters", "Inns", "PrintingPresses", "PaperMakers", "Looms", "Mills", "Banks", "CraftingBenches", "OreMines", "WheatFields", "CottonPlants", "ConstructionSites"]
	for grp in obstacle_groups:
		for node in get_tree().get_nodes_in_group(grp):
			if node is Node2D and not node.is_in_group("nav_carve_obstacles"):
				node.add_to_group("nav_carve_obstacles")
	
	# Gather all regions to bake sequentially
	var pending_regions = []
	
	var global_navs = get_tree().get_nodes_in_group("GlobalNavRegion")
	for region in global_navs:
		if region is NavigationRegion2D:
			pending_regions.append(region)
			
	var roads = get_tree().get_nodes_in_group("Roads")
	for road in roads:
		var region = road.get_node_or_null("RoadNavRegion")
		if region is NavigationRegion2D:
			pending_regions.append(region)
			
	var plazas = get_tree().get_nodes_in_group("Plazas")
	for plaza in plazas:
		var region = plaza.get_node_or_null("PlazaNavRegion")
		if region is NavigationRegion2D:
			pending_regions.append(region)
			
	# Bake them sequentially to prevent thread overlapping and warnings
	for region in pending_regions:
		if is_instance_valid(region):
			region.bake_navigation_polygon(true)
			await region.bake_finished
			
	is_baking = false
	print("[RoadNavigation] Rebaked all navigation regions (ground, roads, plazas) sequentially using nav_carve_obstacles group.")
	
	# If a new request was queued during the bake, trigger it now
	if _bake_queued:
		_trigger_debounced_bake()

extends Control

var view_range: float = 800.0
var center: Vector2 = Vector2(60, 60)
var radius: float = 55.0
var scale_factor: float = 55.0 / 800.0
var cached_lines: Array = []

@onready var location_lbl: Label = null

func _ready() -> void:
	# Keep redrawing every frame for real-time tracking
	set_process(true)
	
	# Cache location label if it exists as a sibling in VBoxContainer
	var parent_vbox = get_parent().get_parent()
	if parent_vbox and parent_vbox is VBoxContainer:
		location_lbl = parent_vbox.get_node_or_null("LocationLabel")
		
	# Cache blueprint lines for highly accurate, rotated road/river/wall drawing on radar
	call_deferred("_cache_blueprint_lines")

func _cache_blueprint_lines() -> void:
	cached_lines.clear()
	var bp = get_node_or_null("/root/World/world_map_blueprint")
	if not bp:
		return
		
	var bp_queue = [bp]
	while not bp_queue.is_empty():
		var curr = bp_queue.pop_back()
		if not is_instance_valid(curr):
			continue
			
		if curr is Line2D:
			var points = curr.points
			if points.size() > 1:
				var path_lower = str(curr.get_path()).to_lower()
				var line_color = Color(0.25, 0.25, 0.28, 0.8) # Road gray
				var line_width = 2.5
				
				if "river" in path_lower:
					line_color = Color(0.14, 0.3, 0.75, 0.9) # River blue
					line_width = 3.5
				elif "wall" in path_lower:
					line_color = Color(0.55, 0.45, 0.35, 0.8) # Wall brown
					line_width = 2.0
				elif "maplimit" in path_lower:
					line_color = Color(0.1, 0.1, 0.1, 0.9)
					line_width = 1.5
					
				# Store global points
				var g_points = []
				for pt in points:
					g_points.append(curr.to_global(pt))
				cached_lines.append({
					"points": g_points,
					"color": line_color,
					"width": line_width
				})
				
		for child in curr.get_children():
			bp_queue.append(child)

func _process(_delta: float) -> void:
	queue_redraw()
	_update_location_label()

func _update_location_label() -> void:
	if not location_lbl or not is_instance_valid(location_lbl):
		return
		
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not is_instance_valid(player):
		location_lbl.text = ""
		return
		
	var pos = player.global_position
	
	# Resolve overworld position if player is inside an interior
	if pos.y > 8000.0:
		var closest_interior: Node = null
		var min_interior_dist = INF
		for interior in get_tree().get_nodes_in_group("Interiors"):
			if is_instance_valid(interior):
				var dist = pos.distance_to(interior.global_position)
				if dist < min_interior_dist:
					min_interior_dist = dist
					closest_interior = interior
		if closest_interior and is_instance_valid(closest_interior.get("parent_building")):
			pos = closest_interior.parent_building.global_position
			
	var province = GameState.current_province
	
	var prosperity_val = 100
	var pm = get_node_or_null("/root/ProsperityManager")
	if pm:
		prosperity_val = int(pm.province_prosperity.get(province, 100.0))
		
	var closest_settlement: Node2D = null
	var min_dist: float = INF
	var is_city: bool = false
	
	# Find closest City
	for city in get_tree().get_nodes_in_group("Cities"):
		if is_instance_valid(city):
			var dist = pos.distance_to(city.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_settlement = city
				is_city = true
				
	# Find closest Town
	for town in get_tree().get_nodes_in_group("Towns"):
		if is_instance_valid(town):
			var dist = pos.distance_to(town.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_settlement = town
				is_city = false
				
	var location_name = "No Man's Land"
	if closest_settlement:
		var influence_radius = 800.0 if is_city else 600.0
		if not is_city and "radius_of_influence" in closest_settlement:
			influence_radius = closest_settlement.radius_of_influence
			
		if min_dist <= influence_radius:
			location_name = closest_settlement.city_name if is_city else closest_settlement.town_name
			
	location_lbl.text = "%s (%d) - %s" % [province, prosperity_val, location_name]

func _draw() -> void:
	# 1. Background Grid & Radar Area
	draw_circle(center, radius, Color(0.04, 0.05, 0.07, 0.85))
	
	# Concentric rings
	draw_arc(center, radius, 0.0, TAU, 32, Color(0.24, 0.6, 0.86, 0.35), 1.0)
	draw_arc(center, radius * 0.66, 0.0, TAU, 32, Color(0.24, 0.6, 0.86, 0.18), 1.0)
	draw_arc(center, radius * 0.33, 0.0, TAU, 32, Color(0.24, 0.6, 0.86, 0.1), 1.0)
	
	# Crosshairs
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.24, 0.6, 0.86, 0.08))
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.24, 0.6, 0.86, 0.08))
	
	# 2. Get Player Node
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not is_instance_valid(player):
		return
		
	var player_pos = player.global_position
	var font = get_theme_font("font")
	
	# Helper lambda to project absolute world position onto radar control position
	var to_radar = func(world_pos: Vector2) -> Vector2:
		var rel = world_pos - player_pos
		return center + rel * scale_factor

	# 3. Draw Roads & blueprint paths
	for line_data in cached_lines:
		var g_pts = line_data.points
		var line_color = line_data.color
		var line_width = line_data.width
		
		for i in range(g_pts.size() - 1):
			var p1 = g_pts[i]
			var p2 = g_pts[i + 1]
			
			if p1.distance_to(player_pos) < view_range + 200.0 or p2.distance_to(player_pos) < view_range + 200.0:
				var c_start = to_radar.call(p1)
				var c_end = to_radar.call(p2)
				
				if (c_start - center).length() <= radius or (c_end - center).length() <= radius:
					var line_start = center + (c_start - center).limit_length(radius)
					var line_end = center + (c_end - center).limit_length(radius)
					draw_line(line_start, line_end, line_color, line_width)

	# 4. Draw Plazas
	for plaza in get_tree().get_nodes_in_group("Plazas"):
		if is_instance_valid(plaza):
			var rel = plaza.global_position - player_pos
			if rel.length() < view_range:
				var c_pos = to_radar.call(plaza.global_position)
				var plaza_sz = plaza.size * scale_factor
				var rect = Rect2(c_pos - plaza_sz / 2.0, plaza_sz)
				# Draw translucent filled rect
				draw_rect(rect, Color(0.28, 0.28, 0.32, 0.35))
				draw_rect(rect, Color(0.35, 0.35, 0.4, 0.5), false, 1.0)

	# 5. Draw Buildings (Workstations/Houses)
	var building_groups = ["Houses", "Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	for grp in building_groups:
		for b in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(b):
				var rel = b.global_position - player_pos
				if rel.length() <= view_range:
					var c_pos = to_radar.call(b.global_position)
					if (c_pos - center).length() <= radius:
						var color = Color(0.24, 0.6, 0.86, 0.9) # Player owned (blue)
						if b.ownership_type == "Rival" or b.get("owner_id") == "Rival":
							color = Color(0.86, 0.24, 0.24, 0.9) # Rival (red)
						elif b.ownership_type == "Public" or b.ownership_type == "NPC":
							color = Color(0.6, 0.6, 0.6, 0.8) # Public/NPC (grey)
						
						draw_rect(Rect2(c_pos - Vector2(2, 2), Vector2(4, 4)), color)

	# 6. Draw MegaNodes
	for mn in get_tree().get_nodes_in_group("MegaNodes"):
		if is_instance_valid(mn):
			var rel = mn.global_position - player_pos
			if rel.length() <= view_range + 100.0:
				var c_pos = to_radar.call(mn.global_position)
				if (c_pos - center).length() <= radius:
					var color = Color(0.85, 0.75, 0.24, 0.7) # Yellow (wheat)
					if mn.resource_type_id == "iron_ore":
						color = Color(0.7, 0.7, 0.75, 0.7) # Grey (iron)
					elif mn.resource_type_id == "cotton":
						color = Color(0.85, 0.85, 0.9, 0.7) # Cotton (light blue/white)
					
					draw_circle(c_pos, 4.0, color)
					draw_arc(c_pos, 4.0, 0.0, TAU, 16, Color.BLACK, 1.0)

	# 7. Draw Settlements (Cities/Towns)
	var settlements = []
	settlements.append_array(get_tree().get_nodes_in_group("Cities"))
	settlements.append_array(get_tree().get_nodes_in_group("Towns"))
	for s in settlements:
		if is_instance_valid(s):
			var rel = s.global_position - player_pos
			if rel.length() <= view_range + 100.0:
				var c_pos = to_radar.call(s.global_position)
				if (c_pos - center).length() <= radius:
					var is_c = s.is_in_group("Cities")
					var label_char = "C" if is_c else "T"
					var color = Color.GOLD if is_c else Color.SILVER
					
					draw_circle(c_pos, 5.0, Color(0.08, 0.08, 0.1, 0.9))
					draw_arc(c_pos, 5.0, 0.0, TAU, 16, color, 1.0)
					if font:
						draw_string(font, c_pos + Vector2(-3, 3), label_char, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, color)

	# 8. Draw Other Characters (NPCs, Rivals, Workers)
	# A. NPCs
	for npc in get_tree().get_nodes_in_group("NPCs"):
		if is_instance_valid(npc) and npc != player:
			var rel = npc.global_position - player_pos
			if rel.length() <= view_range:
				var c_pos = to_radar.call(npc.global_position)
				if (c_pos - center).length() <= radius:
					draw_circle(c_pos, 2.0, Color(0.3, 0.8, 0.6)) # Teal/Greenish
					
	# D. Influence Broker
	for broker in get_tree().get_nodes_in_group("InfluenceBroker"):
		if is_instance_valid(broker):
			var c_pos = to_radar.call(broker.global_position)
			var dist = (c_pos - center).length()
			if dist <= radius:
				draw_circle(c_pos, 4.0, Color(1.0, 0.85, 0.0)) # Bright Gold
				draw_arc(c_pos, 4.0, 0.0, TAU, 12, Color.WHITE, 1.0)
			else:
				var border_pos = center + (c_pos - center).normalized() * (radius - 4.0)
				draw_circle(border_pos, 4.0, Color(1.0, 0.85, 0.0)) # Gold direction indicator on border
				draw_arc(border_pos, 4.0, 0.0, TAU, 12, Color.WHITE, 1.2)
					
	# B. Hired Workers
	for worker in get_tree().get_nodes_in_group("GatheringWorkers"):
		if is_instance_valid(worker):
			var rel = worker.global_position - player_pos
			if rel.length() <= view_range:
				var c_pos = to_radar.call(worker.global_position)
				if (c_pos - center).length() <= radius:
					draw_circle(c_pos, 2.0, Color(0.24, 0.7, 0.9)) # Electric cyan

	# C. Rivals
	for rival in get_tree().get_nodes_in_group("Rivals"):
		if is_instance_valid(rival):
			var rel = rival.global_position - player_pos
			if rel.length() <= view_range:
				var c_pos = to_radar.call(rival.global_position)
				if (c_pos - center).length() <= radius:
					draw_circle(c_pos, 2.5, Color(0.9, 0.2, 0.2)) # Bright red

	# 9. Draw Player Arrow at Center
	var facing = player.get("_last_direction") if "_last_direction" in player else "south"
	var dir_vec = Vector2(0, 1)
	match facing:
		"north": dir_vec = Vector2(0, -1)
		"south": dir_vec = Vector2(0, 1)
		"east": dir_vec = Vector2(1, 0)
		"west": dir_vec = Vector2(-1, 0)
		
	var angle = dir_vec.angle()
	var points = PackedVector2Array([
		center + Vector2(6, 0).rotated(angle),
		center + Vector2(-4, -4).rotated(angle),
		center + Vector2(-2, 0).rotated(angle), # indented center back
		center + Vector2(-4, 4).rotated(angle)
	])
	draw_polygon(points, PackedColorArray([Color(0.24, 0.85, 0.44)]))
	draw_polyline(points, Color.BLACK, 1.0)

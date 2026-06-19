extends Control

var view_range: float = 800.0
var center: Vector2 = Vector2(60, 60)
var radius: float = 55.0
var scale_factor: float = 55.0 / 800.0

@onready var location_lbl: Label = null

func _ready() -> void:
	# Keep redrawing every frame for real-time tracking
	set_process(true)
	
	# Cache location label if it exists as a sibling in VBoxContainer
	var parent_vbox = get_parent().get_parent()
	if parent_vbox and parent_vbox is VBoxContainer:
		location_lbl = parent_vbox.get_node_or_null("LocationLabel")

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
	var province = "Valley Province" if pos.x < 3500 else "Oakhaven Province"
	
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
			
	location_lbl.text = "%s - %s" % [province, location_name]

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

	# 3. Draw Roads
	for road in get_tree().get_nodes_in_group("Roads"):
		if is_instance_valid(road):
			var rel = road.global_position - player_pos
			if rel.length() < view_range + 200.0:
				var half_w = road.size.x / 2.0
				var half_h = road.size.y / 2.0
				var p_start = road.global_position - (Vector2(half_w, 0) if road.size.x > road.size.y else Vector2(0, half_h))
				var p_end = road.global_position + (Vector2(half_w, 0) if road.size.x > road.size.y else Vector2(0, half_h))
				
				var c_start = to_radar.call(p_start)
				var c_end = to_radar.call(p_end)
				
				# Simple clip logic: draw line if it's within the radar circle bounds
				if (c_start - center).length() <= radius or (c_end - center).length() <= radius:
					var line_start = center + (c_start - center).limit_length(radius)
					var line_end = center + (c_end - center).limit_length(radius)
					draw_line(line_start, line_end, Color(0.25, 0.25, 0.28, 0.8), 2.5)

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

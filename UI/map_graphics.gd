extends Control

var is_zoomed_in: bool = false
var current_bounds: Rect2
var current_scale_factor: float = 1.0
var current_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	clip_contents = true

func toggle_zoom() -> void:
	is_zoomed_in = not is_zoomed_in
	queue_redraw()

func _draw() -> void:
	var player_pos = Vector2(1650, 480)
	var players = get_tree().get_nodes_in_group("Player")
	if not players.is_empty() and is_instance_valid(players[0]):
		player_pos = players[0].global_position
		
	var world_bounds = get_world_bounds()
	var bounds: Rect2
	if is_zoomed_in and world_bounds.size.x > 2000 and world_bounds.size.y > 1500:
		var zoom_size = Vector2(2000, 1500)
		var center_pos = player_pos
		center_pos.x = clamp(center_pos.x, world_bounds.position.x + zoom_size.x / 2.0, world_bounds.end.x - zoom_size.x / 2.0)
		center_pos.y = clamp(center_pos.y, world_bounds.position.y + zoom_size.y / 2.0, world_bounds.end.y - zoom_size.y / 2.0)
		bounds = Rect2(center_pos - zoom_size / 2.0, zoom_size)
	else:
		bounds = world_bounds
		
	var size_map = size
	
	# Maintain aspect ratio
	var scale_factor = min(size_map.x / bounds.size.x, size_map.y / bounds.size.y)
	# Center map within control container
	var offset = (size_map - bounds.size * scale_factor) / 2.0
	
	current_bounds = bounds
	current_scale_factor = scale_factor
	current_offset = offset
	
	var to_map = func(world_pos: Vector2) -> Vector2:
		return offset + (world_pos - bounds.position) * scale_factor
		
	# 1. Draw plazas
	var plazas = get_tree().get_nodes_in_group("Plazas")
	for plaza in plazas:
		if is_instance_valid(plaza) and "size" in plaza:
			var center = to_map.call(plaza.global_position)
			var p_size = plaza.size * scale_factor
			draw_rect(Rect2(center - p_size / 2.0, p_size), Color(0.26, 0.26, 0.29, 0.8))
			draw_rect(Rect2(center - p_size / 2.0, p_size), Color(0.42, 0.42, 0.46, 0.6), false, 1.5)
			
	# 2. Draw blueprint Line2D paths (Roads, Rivers, Walls, MapLimits) and ColorRect visual assets (Lakes/Water)
	var bp = get_node_or_null("/root/World/world_map_blueprint")
	if bp:
		var bp_queue = [bp]
		while not bp_queue.is_empty():
			var curr = bp_queue.pop_back()
			if not is_instance_valid(curr):
				continue
				
			if curr is Line2D:
				var points = curr.points
				if points.size() > 1:
					var path_lower = str(curr.get_path()).to_lower()
					var line_color = Color(0.24, 0.24, 0.27, 0.8) # Road gray
					var line_width = max(1.5, curr.width * scale_factor)
					
					if "river" in path_lower:
						line_color = Color(0.14, 0.3, 0.75, 0.9) # River blue
						line_width = max(3.0, curr.width * scale_factor)
					elif "wall" in path_lower:
						line_color = Color(0.55, 0.45, 0.35, 0.8) # Wall brown
						line_width = max(1.5, curr.width * scale_factor)
					elif "maplimit" in path_lower:
						line_color = Color(0.1, 0.1, 0.1, 0.9) # Border
						line_width = max(1.0, 2.0 * scale_factor)
						
					for i in range(points.size() - 1):
						var p1 = to_map.call(curr.to_global(points[i]))
						var p2 = to_map.call(curr.to_global(points[i + 1]))
						draw_line(p1, p2, line_color, line_width)
						
			elif curr is ColorRect:
				var path_lower = str(curr.get_path()).to_lower()
				if "lake" in path_lower or "water" in path_lower or "sea" in path_lower or "river" in path_lower:
					var rect = curr.get_global_rect()
					var center = to_map.call(rect.position + rect.size / 2.0)
					var size_val = rect.size * scale_factor
					var color = Color(0.14, 0.3, 0.75, 0.9) # Deep blue lake/water
					draw_rect(Rect2(center - size_val / 2.0, size_val), color)
						
			for child in curr.get_children():
				bp_queue.append(child)
			
	# 3. Draw building lots
	var lots = get_tree().get_nodes_in_group("BuildingLots")
	for lot in lots:
		if is_instance_valid(lot):
			var center = to_map.call(lot.global_position)
			var l_size = Vector2(96, 96) * scale_factor
			# Sleek semi-transparent cyan area for lot placements
			draw_rect(Rect2(center - l_size / 2.0, l_size), Color(0.15, 0.45, 0.65, 0.2))
			draw_rect(Rect2(center - l_size / 2.0, l_size), Color(0.2, 0.6, 0.8, 0.45), false, 1.0)
			
	# 4. Draw buildings
	var groups = {
		"Mills": "Mill",
		"Smelters": "Smelter",
		"Looms": "Loom",
		"Bakeries": "Bakery",
		"PaperMakers": "PaperMaker",
		"PrintingPresses": "Press",
		"Banks": "Bank",
		"Inns": "Inn",
		"Houses": "House"
	}
	
	for g in groups:
		for b in get_tree().get_nodes_in_group(g):
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				var center = to_map.call(b.global_position)
				var b_size = Vector2(64, 64) * scale_factor
				
				# Base color depending on ownership
				var color = Color(0.42, 0.35, 0.26) # Default wood brown
				if "ownership_type" in b:
					if b.ownership_type == "Player":
						color = Color(0.2, 0.62, 0.36) # Teal green for Player
					elif b.ownership_type == "NPC":
						color = Color(0.8, 0.35, 0.35) # Red for rivals
						
				draw_rect(Rect2(center - b_size / 2.0, b_size), color)
				draw_rect(Rect2(center - b_size / 2.0, b_size), color.lightened(0.2), false, 1.0)
				
	# 5. Draw Rivals
	var rivals = get_tree().get_nodes_in_group("Rivals")
	for rival in rivals:
		if is_instance_valid(rival):
			var center = to_map.call(rival.global_position)
			draw_circle(center, 5.0, Color(0.9, 0.3, 0.3)) # Red dot
			draw_circle(center, 5.0, Color(1, 1, 1), false, 1.0)
			
	# 6. Draw Player
	for player in players:
		if is_instance_valid(player):
			var center = to_map.call(player.global_position)
			# Cyan circle with pulse ring
			draw_circle(center, 6.0, Color(0.24, 0.6, 0.86))
			draw_circle(center, 6.0, Color(1, 1, 1), false, 1.0)
			draw_arc(center, 10.0, 0.0, TAU, 16, Color(0.24, 0.6, 0.86, 0.6), 1.5)
			
	# 6b. Draw Influence Broker
	var brokers = get_tree().get_nodes_in_group("InfluenceBroker")
	for broker in brokers:
		if is_instance_valid(broker):
			var center = to_map.call(broker.global_position)
			draw_circle(center, 6.0, Color(1.0, 0.85, 0.0))
			draw_circle(center, 6.0, Color(1, 1, 1), false, 1.0)
			draw_arc(center, 10.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.0, 0.6), 1.5)
			
	# 7. Draw MegaNodes
	var mega_nodes = get_tree().get_nodes_in_group("MegaNodes")
	for mn in mega_nodes:
		if is_instance_valid(mn):
			var center = to_map.call(mn.global_position)
			var mn_radius = 96.0
			for child in mn.get_children():
				if child is CollisionShape2D and child.shape is CircleShape2D:
					mn_radius = child.shape.radius
					break
			var map_radius = mn_radius * scale_factor
			
			var color = Color(0.24, 0.52, 0.85, 0.1)
			var border_color = Color(0.24, 0.52, 0.85, 0.4)
			if mn.resource_type_id == "wheat":
				color = Color(0.85, 0.75, 0.24, 0.1)
				border_color = Color(0.85, 0.75, 0.24, 0.4)
			elif mn.resource_type_id == "iron_ore":
				color = Color(0.7, 0.7, 0.75, 0.1)
				border_color = Color(0.7, 0.7, 0.75, 0.4)
			elif mn.resource_type_id == "cotton":
				color = Color(0.85, 0.85, 0.9, 0.1)
				border_color = Color(0.85, 0.85, 0.9, 0.4)
				
			draw_circle(center, map_radius, color)
			draw_arc(center, map_radius, 0.0, TAU, 32, border_color, 1.5)
			
	# 8. Draw Labels
	var font = get_theme_font("font")
	
	# A. Province Headers
	var bp_l = get_node_or_null("/root/World/world_map_blueprint")
	if bp_l:
		var prov_folder = bp_l.get_node_or_null("Provinces")
		if prov_folder:
			for prov_node in prov_folder.get_children():
				if is_instance_valid(prov_node):
					var label_anchor = prov_node.get_node_or_null("Label_Anchor")
					var label_pos = label_anchor.global_position if label_anchor else prov_node.global_position
					var prov_name = prov_node.name.replace("_", " ")
					var pos = to_map.call(label_pos)
					var draw_pos = pos - Vector2(150, 0)
					draw_string_outline(font, draw_pos, prov_name, HORIZONTAL_ALIGNMENT_CENTER, 300, 16, 4, Color.BLACK)
					draw_string(font, draw_pos, prov_name, HORIZONTAL_ALIGNMENT_CENTER, 300, 16, Color(0.88, 0.73, 0.23, 1))
		
	# B. Cities & Towns Labels
	var settlements = []
	settlements.append_array(get_tree().get_nodes_in_group("Cities"))
	settlements.append_array(get_tree().get_nodes_in_group("Towns"))
	for s in settlements:
		if is_instance_valid(s):
			var pos = to_map.call(s.global_position) + Vector2(0, -12)
			var text = s.city_name if s.is_in_group("Cities") else s.town_name
			var font_size = 11 if s.is_in_group("Cities") else 10
			var font_color = Color(1.0, 0.9, 0.6) if s.is_in_group("Cities") else Color(0.95, 0.95, 0.95)
			
			var draw_pos = pos - Vector2(100, 0)
			draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, 200, font_size, 3, Color.BLACK)
			draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, 200, font_size, font_color)
			
			if get_tree().get_nodes_in_group("InformantLookouts").size() > 0:
				var w = s.get("wealth_level") if "wealth_level" in s else 0.5
				var sec = s.get("security_level") if "security_level" in s else 0.8
				var h = s.get("criminal_heat") if "criminal_heat" in s else 0.0
				var attr_text = "W: %.1f | S: %.1f | H: %.1f" % [w, sec, h]
				var attr_pos = pos + Vector2(-100, 12)
				draw_string_outline(font, attr_pos, attr_text, HORIZONTAL_ALIGNMENT_CENTER, 200, font_size - 2, 2, Color.BLACK)
				draw_string(font, attr_pos, attr_text, HORIZONTAL_ALIGNMENT_CENTER, 200, font_size - 2, Color(0.7, 0.9, 0.7))
			
	# C. MegaNode Labels
	for mn in mega_nodes:
		if is_instance_valid(mn):
			var pos = to_map.call(mn.global_position) + Vector2(0, 18)
			var text = mn.node_name
			var draw_pos = pos - Vector2(100, 0)
			draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, 200, 9, 3, Color.BLACK)
			draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, 200, 9, Color(0.8, 0.8, 0.8))
			
	# D. Influence Broker Labels
	for broker in get_tree().get_nodes_in_group("InfluenceBroker"):
		if is_instance_valid(broker):
			var pos = to_map.call(broker.global_position) + Vector2(0, -14)
			var text = "Influence Broker"
			var draw_pos = pos - Vector2(100, 0)
			draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, 200, 10, 3, Color.BLACK)
			draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, 200, 10, Color(1.0, 0.85, 0.0))

func get_world_bounds() -> Rect2:
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	
	# Find starting nodes
	var search_queue = []
	for node in get_tree().get_nodes_in_group("MapLimits"):
		search_queue.append(node)
		
	if search_queue.is_empty():
		var bp = get_node_or_null("/root/World/world_map_blueprint")
		var target = null
		if bp:
			target = bp.get_node_or_null("MapLimits")
		if not target:
			target = get_node_or_null("/root/World/MapLimits")
		if target:
			search_queue.append(target)
			
	# Process queue iteratively (avoids GDScript lambda capture and recursion errors)
	while not search_queue.is_empty():
		var current = search_queue.pop_back()
		if not is_instance_valid(current):
			continue
			
		if current is Line2D:
			for pt in current.points:
				var gpt = current.to_global(pt)
				if gpt.x < min_x: min_x = gpt.x
				if gpt.y < min_y: min_y = gpt.y
				if gpt.x > max_x: max_x = gpt.x
				if gpt.y > max_y: max_y = gpt.y
				
		for child in current.get_children():
			search_queue.append(child)
			
	# If we found any valid bounds from Line2D nodes, return them!
	if min_x != INF:
		return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

	var nodes = []
	nodes.append_array(get_tree().get_nodes_in_group("Roads"))
	nodes.append_array(get_tree().get_nodes_in_group("Plazas"))
	
	var groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Houses", "BuildingLots", "Player", "InfluenceBroker", "MegaNodes"]
	for g in groups:
		nodes.append_array(get_tree().get_nodes_in_group(g))
		
	if nodes.is_empty():
		return Rect2(0, 0, 4000, 3000)
		
	min_x = INF
	min_y = INF
	max_x = -INF
	max_y = -INF
	
	for n in nodes:
		if is_instance_valid(n) and "global_position" in n:
			var pos = n.global_position
			if pos.x < min_x: min_x = pos.x
			if pos.y < min_y: min_y = pos.y
			if pos.x > max_x: max_x = pos.x
			if pos.y > max_y: max_y = pos.y
			
	min_x -= 150
	min_y -= 150
	max_x += 150
	max_y += 150
	
	if min_x == INF:
		return Rect2(0, 0, 4000, 3000)
		
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cutpurse_apartments = get_tree().get_nodes_in_group("CutpurseApartments")
		if cutpurse_apartments.is_empty():
			return
			
		var click_pos = event.position
		var world_pos = (click_pos - current_offset) / current_scale_factor + current_bounds.position
		
		var settlements = []
		settlements.append_array(get_tree().get_nodes_in_group("Cities"))
		settlements.append_array(get_tree().get_nodes_in_group("Towns"))
		
		var clicked_settlement = null
		var min_dist = 150.0
		for s in settlements:
			if is_instance_valid(s):
				var dist = world_pos.distance_to(s.global_position)
				if dist < min_dist:
					min_dist = dist
					clicked_settlement = s
					
		if clicked_settlement:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = get_tree().get_first_node_in_group("game_hud")
			if hud and hud.has_method("open_rogue_mission_popup"):
				hud.open_rogue_mission_popup(clicked_settlement)
				accept_event()

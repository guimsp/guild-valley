extends VBoxContainer

signal route_save_committed(emp_data: Dictionary, stops_data: Array, is_new: bool)
signal close_requested()

@onready var clear_route_button: Button = %ClearRouteButton
@onready var start_route_button: Button = %StartRouteButton
@onready var distance_label: Label = %DistanceLabel
@onready var time_label: Label = %TimeLabel
@onready var waypoints_list: VBoxContainer = %WaypointsList
@onready var stalls_list: VBoxContainer = %StallsList

var selected_source_building: Node2D = null
var selected_employee_dict: Dictionary = {}
var selected_waypoints: Array = [] # Array of Stop dictionaries
var modifying_emp_data: Dictionary = {}
var is_modifying: bool = false

var _warning_label: Label = null
var is_commerce_route: bool = true # Unified mode: always show player owned & markets
var popup: PanelContainer = null
var popup_step: int = 0
var selected_action: String = "LOAD"
var selected_item_id: String = ""
var _current_configuring_building: Node2D = null
var current_view_province: String = "Valley Province"
var _prev_view_province: String = "Valley Province"

var route_map_control: Control = null
var map_buttons: Dictionary = {}
var employee_popup: PanelContainer = null
var create_new_route_btn: Button = null

func _ready() -> void:
	_warning_label = Label.new()
	_warning_label.add_theme_font_size_override("font_size", 11)
	_warning_label.add_theme_color_override("font_color", Color.YELLOW)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.visible = false
	add_child(_warning_label)
	move_child(_warning_label, get_child_count() - 2) # Place right above footer
	
	clear_route_button.pressed.connect(clear_waypoints)
	start_route_button.pressed.connect(_on_start_or_save_pressed)
	
	# Instantiate "Create new route" button at the top of the LeftColumn
	var left_col = get_node_or_null("Columns/LeftColumn")
	if left_col:
		create_new_route_btn = Button.new()
		create_new_route_btn.name = "CreateNewRouteButton"
		create_new_route_btn.text = "Create new route"
		create_new_route_btn.custom_minimum_size = Vector2(160, 32)
		create_new_route_btn.add_theme_font_size_override("font_size", 12)
		create_new_route_btn.focus_mode = Control.FOCUS_ALL
		_setup_button_effects(create_new_route_btn)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.24, 0.35, 0.95)
		style.border_color = Color(0.88, 0.73, 0.23, 1.0)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		create_new_route_btn.add_theme_stylebox_override("normal", style)
		create_new_route_btn.add_theme_stylebox_override("hover", style)
		create_new_route_btn.add_theme_stylebox_override("focus", style)
		create_new_route_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		
		left_col.add_child(create_new_route_btn)
		left_col.move_child(create_new_route_btn, 0)
		
		create_new_route_btn.pressed.connect(func():
			clear_waypoints()
			_focus_first_map_node()
		)
		
	if stalls_list:
		var right_col = stalls_list.get_parent().get_parent() as VBoxContainer
		if right_col:
			_setup_route_map(right_col)
			
	setup_new()

func setup_new() -> void:
	is_modifying = false
	modifying_emp_data = {}
	selected_waypoints.clear()
	selected_source_building = null
	selected_employee_dict = {}
	start_route_button.text = "Start Route"
	_refresh_waypoints_list()
	_validate_route_stops()
	_update_metrics()
	if route_map_control:
		_recreate_map_buttons()
		route_map_control.queue_redraw()
	if create_new_route_btn:
		create_new_route_btn.call_deferred("grab_focus")

func setup_edit(emp_data: Dictionary, route_copy: Resource) -> void:
	is_modifying = true
	modifying_emp_data = emp_data
	selected_source_building = emp_data["workshop"]
	selected_employee_dict = emp_data["emp"]
	
	selected_waypoints.clear()
	for stop in route_copy.route_stops:
		if is_instance_valid(stop):
			selected_waypoints.append({
				"building": stop.target_building,
				"action": stop.action_type,
				"item_id": stop.item_id,
				"quantity": stop.target_quantity,
				"minimum_sell_price": stop.minimum_sell_price
			})
			
	start_route_button.text = "Save Route"
	_refresh_waypoints_list()
	_validate_route_stops()
	_update_metrics()
	
	if is_instance_valid(selected_source_building):
		var new_prov = GameState.get_province_of_node(selected_source_building)
		if new_prov != "":
			current_view_province = new_prov
			_prev_view_province = new_prov
			
	if route_map_control:
		_recreate_map_buttons()
		route_map_control.queue_redraw()

func _on_start_or_save_pressed() -> void:
	if selected_waypoints.is_empty():
		GameState.spawn_ui_floating_text("Select at least one stop!")
		return
		
	if not _validate_route_stops():
		return
		
	if is_modifying:
		route_save_committed.emit(modifying_emp_data, selected_waypoints, false)
	else:
		_show_employee_selection_popup()

func add_waypoint(building: Node2D) -> void:
	var default_item_id = ""
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	if econ_mgr and not econ_mgr.item_database.is_empty():
		default_item_id = econ_mgr.item_database.keys()[0]
		
	selected_waypoints.append({
		"building": building,
		"action": "LOAD",
		"item_id": default_item_id,
		"quantity": 20,
		"minimum_sell_price": 0
	})
	_refresh_waypoints_list()
	_validate_route_stops()
	_update_metrics()
	if route_map_control:
		route_map_control.queue_redraw()

func remove_waypoint(index: int) -> void:
	if index >= 0 and index < selected_waypoints.size():
		selected_waypoints.remove_at(index)
		_refresh_waypoints_list()
		_validate_route_stops()
		_update_metrics()
		if route_map_control:
			route_map_control.queue_redraw()

func clear_waypoints() -> void:
	selected_waypoints.clear()
	_refresh_waypoints_list()
	_validate_route_stops()
	_update_metrics()
	if route_map_control:
		route_map_control.queue_redraw()

func _refresh_waypoints_list() -> void:
	for child in waypoints_list.get_children():
		child.queue_free()
		
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	var items = econ_mgr.item_database if econ_mgr else {}
	
	for i in range(selected_waypoints.size()):
		var stop_data = selected_waypoints[i]
		var building = stop_data.building
		if not is_instance_valid(building):
			continue
			
		var b_name = building.custom_name if (building.get("custom_name") != "" and "custom_name" in building) else building.name
		b_name = b_name.replace("Interior_", "")
		
		var h = HBoxContainer.new()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_theme_constant_override("separation", 12)
		
		var item_name = "Unknown"
		if items.has(stop_data.item_id):
			item_name = items[stop_data.item_id].name
			
		var is_market = building.is_in_group("MarketStall") and not building.is_in_group("production_buildings")
		var act_label = stop_data.action
		if is_market:
			if stop_data.action == "UNLOAD":
				act_label = "SELL"
			elif stop_data.action == "LOAD":
				act_label = "BUY"
		
		var min_price_str = ""
		if (stop_data.action == "UNLOAD" or stop_data.action == "SELL") and stop_data.get("minimum_sell_price", 0) > 0:
			min_price_str = " (min $%d)" % stop_data["minimum_sell_price"]
			
		var desc_lbl = Label.new()
		desc_lbl.text = "%d. %s (%s: %d %s)%s" % [(i + 1), b_name, act_label, stop_data.quantity, item_name, min_price_str]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		h.add_child(desc_lbl)
		
		var del_btn = Button.new()
		del_btn.text = "X"
		del_btn.add_theme_font_size_override("font_size", 10)
		del_btn.custom_minimum_size = Vector2(24, 24)
		del_btn.focus_mode = Control.FOCUS_ALL
		_setup_button_effects(del_btn)
		del_btn.pressed.connect(func():
			remove_waypoint(i)
		)
		h.add_child(del_btn)
		
		waypoints_list.add_child(h)

func _validate_route_stops() -> bool:
	var error_msg = ""
	var is_valid = true
	
	for i in range(selected_waypoints.size()):
		var stop_data = selected_waypoints[i]
		var building = stop_data.building
		var action = stop_data.action
		var item_id = stop_data.item_id
		
		if action == "UNLOAD" and is_instance_valid(building):
			if building.is_in_group("MarketStall"):
				var econ_mgr = get_node_or_null("/root/EconomyManager")
				var item = econ_mgr.item_database.get(item_id) if econ_mgr else null
				if item and (not item.is_tradable or item.item_type == "Quest"):
					is_valid = false
					var b_name = building.custom_name if (building.get("custom_name") != "" and "custom_name" in building) else building.name
					error_msg = "Error: Stop %d (%s) cannot buy untradable/quest items." % [i + 1, b_name.replace("Interior_", "")]
					break
			else:
				var consumed_ingredients = {}
				var bench = building.get_node_or_null("CraftingBench")
				if not bench and is_instance_valid(building.get("instanced_interior")):
					bench = building.instanced_interior.get_node_or_null("CraftingBench")
				if bench and "recipes" in bench:
					for r in bench.recipes:
						if r and r.inputs:
							for input_item in r.inputs:
								consumed_ingredients[input_item.id] = true
								
				if not consumed_ingredients.has(item_id):
					is_valid = false
					var b_name = building.custom_name if (building.get("custom_name") != "" and "custom_name" in building) else building.name
					error_msg = "Error: Stop %d (%s) does not consume this item." % [i + 1, b_name.replace("Interior_", "")]
					break
					
	if not is_valid:
		start_route_button.disabled = true
		_warning_label.text = error_msg
		_warning_label.add_theme_color_override("font_color", Color.RED)
		_warning_label.visible = true
	else:
		start_route_button.disabled = false
		
		# Validation warning: loaded but never unloaded
		var loaded_items = {}
		var unloaded_items = {}
		for wp in selected_waypoints:
			if wp.action == "LOAD":
				loaded_items[wp.item_id] = true
			elif wp.action == "UNLOAD" or wp.action == "SELL":
				unloaded_items[wp.item_id] = true
				
		var missing_unloads = []
		for id in loaded_items:
			if not unloaded_items.has(id):
				missing_unloads.append(id)
				
		if not missing_unloads.is_empty():
			var econ_mgr = get_node_or_null("/root/EconomyManager")
			var names = []
			for id in missing_unloads:
				var item = econ_mgr.item_database.get(id) if econ_mgr else null
				names.append(item.name if item else id)
			_warning_label.text = "Warning: Items (%s) are LOADED but never UNLOADED or SOLD." % ", ".join(names)
			_warning_label.add_theme_color_override("font_color", Color.YELLOW)
			_warning_label.visible = true
		else:
			_warning_label.visible = false
			
	return is_valid

func _update_metrics() -> void:
	var total_distance = 0.0
	var last_pos = Vector2.ZERO
	
	if is_instance_valid(selected_source_building):
		last_pos = selected_source_building.global_position
		
	for wp_data in selected_waypoints:
		var wp = wp_data.building
		if is_instance_valid(wp) and last_pos != Vector2.ZERO:
			total_distance += _calculate_path_distance(last_pos, wp.global_position)
			last_pos = wp.global_position
			
	if is_instance_valid(selected_source_building) and last_pos != Vector2.ZERO and last_pos != selected_source_building.global_position:
		total_distance += _calculate_path_distance(last_pos, selected_source_building.global_position)
		
	var speed = 70.0
	if selected_employee_dict and selected_employee_dict.get("npc_ref"):
		var npc = selected_employee_dict["npc_ref"]
		if is_instance_valid(npc):
			speed = npc.speed
	elif selected_employee_dict:
		speed = selected_employee_dict.get("speed", 70.0)
		
	var route_time = total_distance / speed
	
	distance_label.text = "Total Route Distance: %d pixels" % int(total_distance)
	time_label.text = "Est. Round-Trip Travel Time: %d seconds" % int(route_time)

func _calculate_path_distance(start: Vector2, end: Vector2) -> float:
	var map = get_viewport().get_world_2d().navigation_map
	var path = NavigationServer2D.map_get_path(map, start, end, true)
	var dist = 0.0
	if path.size() > 1:
		for i in range(path.size() - 1):
			dist += path[i].distance_to(path[i + 1])
	else:
		dist = start.distance_to(end)
	return dist

# --- Visual Route Planning Map ---

func _setup_route_map(container: VBoxContainer) -> void:
	if stalls_list and stalls_list.get_parent():
		stalls_list.get_parent().visible = false
		
	var title = container.get_node_or_null("StallsLabel")
	if title:
		title.text = "Select Route Waypoints on Map:"
		
	var map_panel = PanelContainer.new()
	map_panel.custom_minimum_size = Vector2(500, 360)
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.45, 0.28, 1.0) # Grass green background
	style.set_border_width_all(2)
	style.border_color = Color(0.75, 0.55, 0.2, 0.8) # Antique gold border
	style.set_corner_radius_all(8)
	map_panel.add_theme_stylebox_override("panel", style)
	
	route_map_control = Control.new()
	route_map_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_map_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_map_control.clip_contents = true
	map_panel.add_child(route_map_control)
	
	container.add_child(map_panel)
	
	route_map_control.draw.connect(_on_map_draw)
	route_map_control.resized.connect(_on_map_resized)
	
	_recreate_map_buttons()

func _get_valid_targets() -> Array:
	var targets = []
	for b in get_tree().get_nodes_in_group("production_buildings"):
		if is_instance_valid(b) and b.ownership_type == "Player":
			if not targets.has(b):
				targets.append(b)
	for h in get_tree().get_nodes_in_group("Houses"):
		if is_instance_valid(h) and h.ownership_type == "Player" and not h.is_rental:
			if not targets.has(h):
				targets.append(h)
	for stall in get_tree().get_nodes_in_group("MarketStall"):
		if is_instance_valid(stall) and not targets.has(stall):
			targets.append(stall)
				
	if current_view_province != "":
		var filtered = []
		for t in targets:
			if GameState.get_province_of_node(t) == current_view_province:
				filtered.append(t)
		return filtered
		
	return targets

func _recreate_map_buttons() -> void:
	for btn in map_buttons.values():
		if is_instance_valid(btn):
			btn.queue_free()
	map_buttons.clear()
	
	if current_view_province == "":
		var provinces = ["Valley Province", "Oakhaven Province"]
		for p in provinces:
			var btn = Button.new()
			btn.text = p
			btn.tooltip_text = "Zoom into " + p
			btn.custom_minimum_size = Vector2(145, 50)
			btn.focus_mode = Control.FOCUS_ALL
			
			var btn_style_normal = StyleBoxFlat.new()
			btn_style_normal.bg_color = Color(0.18, 0.24, 0.35, 0.85)
			btn_style_normal.set_border_width_all(2)
			btn_style_normal.border_color = Color(0.88, 0.73, 0.23, 0.5)
			btn_style_normal.set_corner_radius_all(10)
			
			var btn_style_hover = btn_style_normal.duplicate() as StyleBoxFlat
			btn_style_hover.bg_color = Color(0.24, 0.32, 0.45, 0.95)
			btn_style_hover.border_color = Color(0.88, 0.73, 0.23, 1.0)
			btn_style_hover.set_border_width_all(3)
			
			btn.add_theme_stylebox_override("normal", btn_style_normal)
			btn.add_theme_stylebox_override("hover", btn_style_hover)
			btn.add_theme_stylebox_override("focus", btn_style_hover)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_font_size_override("font_size", 12)
			
			btn.pressed.connect(func():
				_zoom_into_province(p)
			)
			
			route_map_control.add_child(btn)
			map_buttons[p] = btn
			_setup_button_effects(btn)
			
		_reposition_map_buttons()
		return

	var targets = _get_valid_targets()
	for b in targets:
		var btn = Button.new()
		var b_name = b.custom_name if (b.get("custom_name") != "" and "custom_name" in b) else b.name
		b_name = b_name.replace("Interior_", "")
		
		var abbr = b_name.substr(0, 3).to_upper()
		btn.text = abbr
		btn.tooltip_text = b_name
		btn.custom_minimum_size = Vector2(32, 32)
		btn.focus_mode = Control.FOCUS_ALL
		
		var btn_style_normal = StyleBoxFlat.new()
		var is_stall = b.is_in_group("MarketStall")
		if is_stall:
			var ownership = b.ownership_type if "ownership_type" in b else "Public"
			if ownership == "Player" or (ownership == "Rented" and b.get("owner_id") == "Player"):
				btn_style_normal.bg_color = Color(0.2, 0.62, 0.36, 0.8)
			elif ownership == "NPC":
				btn_style_normal.bg_color = Color(0.7, 0.3, 0.2, 0.8)
			else:
				btn_style_normal.bg_color = Color(0.2, 0.5, 0.7, 0.8)
		else:
			btn_style_normal.bg_color = Color(0.2, 0.62, 0.36, 0.8)
			
		btn_style_normal.set_border_width_all(1)
		btn_style_normal.border_color = Color(1.0, 1.0, 1.0, 0.4)
		btn_style_normal.set_corner_radius_all(6)
		
		var btn_style_hover = btn_style_normal.duplicate() as StyleBoxFlat
		btn_style_hover.bg_color = Color(0.25, 0.75, 0.45, 1.0) if not is_stall else (btn_style_normal.bg_color + Color(0.1, 0.1, 0.1))
		btn_style_hover.border_color = Color(0.9, 0.77, 0.31, 1.0)
		btn_style_hover.set_border_width_all(2)
		
		btn.add_theme_stylebox_override("normal", btn_style_normal)
		btn.add_theme_stylebox_override("hover", btn_style_hover)
		btn.add_theme_stylebox_override("focus", btn_style_hover)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 10)
		
		var lbl = Label.new()
		lbl.text = b_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.position = Vector2(-24, 32)
		lbl.custom_minimum_size = Vector2(80, 12)
		btn.add_child(lbl)
		
		btn.pressed.connect(func(): _show_waypoint_config_popup(b))
		route_map_control.add_child(btn)
		map_buttons[b] = btn
		_setup_button_effects(btn)
		
	_reposition_map_buttons()

func _reposition_map_buttons() -> void:
	if not is_instance_valid(route_map_control) or route_map_control.size == Vector2.ZERO:
		return
		
	var bounds = get_world_bounds()
	var size_map = route_map_control.size
	
	var scale_factor = min(size_map.x / bounds.size.x, size_map.y / bounds.size.y)
	var offset = (size_map - bounds.size * scale_factor) / 2.0
	
	for b in map_buttons:
		var btn = map_buttons[b]
		if is_instance_valid(btn):
			var target_pos: Vector2
			if b is String:
				if b == "Valley Province":
					target_pos = Vector2(1500, 950)
				else:
					target_pos = Vector2(6500, 950)
			else:
				target_pos = b.global_position
			var center = offset + (target_pos - bounds.position) * scale_factor
			btn.position = center - btn.custom_minimum_size / 2.0

func _on_map_resized() -> void:
	_reposition_map_buttons()
	if is_instance_valid(route_map_control):
		route_map_control.queue_redraw()
	if popup and is_instance_valid(_current_configuring_building):
		_position_popup_next_to_node(_current_configuring_building)

func _on_map_draw() -> void:
	if not is_instance_valid(route_map_control):
		return
		
	var bounds = get_world_bounds()
	var size_map = route_map_control.size
	
	var scale_factor = min(size_map.x / bounds.size.x, size_map.y / bounds.size.y)
	var offset = (size_map - bounds.size * scale_factor) / 2.0
	
	var to_map = func(world_pos: Vector2) -> Vector2:
		return offset + (world_pos - bounds.position) * scale_factor
		
	# Draw plazas
	for plaza in get_tree().get_nodes_in_group("Plazas"):
		if is_instance_valid(plaza) and "size" in plaza:
			if current_view_province != "" and GameState.get_province_of_node(plaza) != current_view_province:
				continue
			var center = to_map.call(plaza.global_position)
			var p_size = plaza.size * scale_factor
			route_map_control.draw_rect(Rect2(center - p_size / 2.0, p_size), Color(0.5, 0.46, 0.42, 1.0))
			route_map_control.draw_rect(Rect2(center - p_size / 2.0, p_size), Color(0.4, 0.36, 0.32, 0.5), false, 1.0)
			
	# Draw markets
	for city in get_tree().get_nodes_in_group("Cities") + get_tree().get_nodes_in_group("Towns"):
		if current_view_province != "" and GameState.get_province_of_node(city) != current_view_province:
			continue
		var m_path = city.get("market_node_path")
		if m_path:
			var market = city.get_node_or_null(m_path)
			if is_instance_valid(market) and market is ColorRect:
				var center = to_map.call(market.global_position + market.size / 2.0)
				var m_size = market.size * scale_factor
				route_map_control.draw_rect(Rect2(center - m_size / 2.0, m_size), Color(0.5, 0.46, 0.42, 1.0))
				route_map_control.draw_rect(Rect2(center - m_size / 2.0, m_size), Color(0.4, 0.36, 0.32, 0.5), false, 1.0)
			
	# Draw roads
	for road in get_tree().get_nodes_in_group("Roads"):
		if is_instance_valid(road) and "size" in road:
			if current_view_province != "" and GameState.get_province_of_node(road) != current_view_province:
				continue
			var center = to_map.call(road.global_position)
			var r_size = road.size * scale_factor
			route_map_control.draw_rect(Rect2(center - r_size / 2.0, r_size), Color(0.4, 0.4, 0.42, 1.0))
			
	# Draw connection lines
	var route_points = []
	if is_instance_valid(selected_source_building):
		route_points.append(selected_source_building)
	for wp_data in selected_waypoints:
		var wp = wp_data.building
		if is_instance_valid(wp):
			route_points.append(wp)
	if is_instance_valid(selected_source_building) and route_points.size() > 1:
		route_points.append(selected_source_building)
		
	if route_points.size() > 1:
		for idx in range(route_points.size() - 1):
			var b1 = route_points[idx]
			var b2 = route_points[idx + 1]
			if is_instance_valid(b1) and is_instance_valid(b2):
				if current_view_province != "" and GameState.get_province_of_node(b1) != current_view_province:
					continue
				var p1 = to_map.call(b1.global_position)
				var p2 = to_map.call(b2.global_position)
				route_map_control.draw_line(p1, p2, Color(0.88, 0.73, 0.23, 0.6), 2.5)
				var mid = (p1 + p2) / 2.0
				route_map_control.draw_circle(mid, 4.0, Color(0.88, 0.73, 0.23, 0.9))

func get_world_bounds() -> Rect2:
	var raw_nodes = []
	raw_nodes.append_array(get_tree().get_nodes_in_group("Roads"))
	raw_nodes.append_array(get_tree().get_nodes_in_group("Plazas"))
	
	var groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Houses", "MarketStall"]
	for g in groups:
		raw_nodes.append_array(get_tree().get_nodes_in_group(g))
		
	var nodes = []
	if current_view_province != "":
		for n in raw_nodes:
			if is_instance_valid(n) and GameState.get_province_of_node(n) == current_view_province:
				nodes.append(n)
	else:
		nodes = raw_nodes
		
	if nodes.is_empty():
		return Rect2(450, 650, 3000, 2000)
		
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	
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
		return Rect2(450, 650, 3000, 2000)
		
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _zoom_into_province(prov_name: String) -> void:
	current_view_province = prov_name
	_prev_view_province = prov_name
	_recreate_map_buttons()
	if route_map_control:
		route_map_control.queue_redraw()

func _zoom_out_to_selection() -> void:
	if current_view_province != "":
		_prev_view_province = current_view_province
	current_view_province = ""
	_recreate_map_buttons()
	if route_map_control:
		route_map_control.queue_redraw()

# --- Waypoint Configurations ---

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		if popup:
			_close_popup(null)
			get_viewport().set_input_as_handled()
			return
		elif employee_popup:
			_close_employee_popup()
			get_viewport().set_input_as_handled()
			return
			
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not popup and not employee_popup:
				_on_start_or_save_pressed()
				get_viewport().set_input_as_handled()
				return
				
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner in map_buttons.values():
			var dir = Vector2.ZERO
			if event.keycode == KEY_W or event.keycode == KEY_UP:
				dir = Vector2.UP
			elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
				dir = Vector2.DOWN
			elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
				dir = Vector2.LEFT
			elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
				dir = Vector2.RIGHT
				
			if dir != Vector2.ZERO:
				var best_candidate: Button = null
				var best_score = INF
				var current_pos = focus_owner.global_position + focus_owner.size / 2.0
				
				for b in map_buttons:
					var other_btn = map_buttons[b]
					if other_btn == focus_owner or not is_instance_valid(other_btn) or not other_btn.is_visible_in_tree():
						continue
						
					var other_pos = other_btn.global_position + other_btn.size / 2.0
					var diff = other_pos - current_pos
					var dist = diff.length()
					if dist < 1.0:
						continue
						
					var dot = diff.normalized().dot(dir)
					if dot > 0.5:
						var score = dist / dot
						if score < best_score:
							best_score = score
							best_candidate = other_btn
							
				if best_candidate:
					best_candidate.grab_focus()
				
				# Always consume directional inputs when a map button is focused to lock focus to the map nodes
				get_viewport().set_input_as_handled()

func _position_popup_next_to_node(building: Node2D) -> void:
	if not popup or not is_instance_valid(route_map_control) or not is_instance_valid(building) or not map_buttons.has(building):
		return
		
	var btn = map_buttons[building]
	if not is_instance_valid(btn):
		return
		
	var popup_size = popup.custom_minimum_size
	var size_to_use = popup_size
	
	var map_size = route_map_control.size
	if map_size == Vector2.ZERO:
		map_size = Vector2(500, 360)
		
	var btn_center = btn.position + btn.size / 2.0
	
	var pos = Vector2.ZERO
	if btn_center.x < map_size.x / 2.0:
		pos.x = btn.position.x + btn.size.x + 10
	else:
		pos.x = btn.position.x - size_to_use.x - 10
		
	pos.y = btn_center.y - size_to_use.y / 2.0
	
	# Clamp to map bounds
	pos.x = clamp(pos.x, 5.0, map_size.x - size_to_use.x - 5.0)
	pos.y = clamp(pos.y, 5.0, map_size.y - size_to_use.y - 5.0)
	
	popup.position = pos

func _focus_first_map_node() -> void:
	if map_buttons.is_empty():
		return
		
	var best_btn: Button = null
	for key in map_buttons:
		var btn = map_buttons[key]
		if is_instance_valid(btn) and btn.is_visible_in_tree():
			best_btn = btn
			break
			
	if best_btn:
		best_btn.grab_focus()

func _show_waypoint_config_popup(building: Node2D) -> void:
	if is_instance_valid(selected_source_building) and is_instance_valid(building):
		var src_prov = GameState.get_province_of_node(selected_source_building)
		var dest_prov = GameState.get_province_of_node(building)
		if src_prov != dest_prov:
			GameState.spawn_ui_floating_text("Cannot add stop in a different province!")
			return

	if popup:
		popup.queue_free()
		
	_current_configuring_building = building
	popup = PanelContainer.new()
	popup.name = "WaypointConfigPopup"
	popup.custom_minimum_size = Vector2(280, 260)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	style.border_color = Color(0.88, 0.73, 0.23, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	popup.add_theme_stylebox_override("panel", style)
	
	if route_map_control:
		route_map_control.add_child(popup)
		_position_popup_next_to_node(building)
	else:
		add_child(popup)
		popup.set_as_top_level(true)
		popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	popup_step = 0
	_render_popup_step(building)

func _render_popup_step(building: Node2D) -> void:
	for child in popup.get_children():
		child.queue_free()
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "Configure Waypoint"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31, 1))
	vbox.add_child(title_lbl)
	
	var b_name = building.custom_name if (building.get("custom_name") != "" and "custom_name" in building) else building.name
	b_name = b_name.replace("Interior_", "")
	
	var subtitle = Label.new()
	subtitle.text = b_name
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(subtitle)
	
	var content_area = VBoxContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_area)
	
	var is_stall = building.is_in_group("MarketStall") and not building.is_in_group("production_buildings")
	
	if popup_step == 0:
		var prompt = Label.new()
		prompt.text = "Select Stop Action:"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.add_theme_font_size_override("font_size", 12)
		content_area.add_child(prompt)
		
		var action_hbox = HBoxContainer.new()
		action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		action_hbox.add_theme_constant_override("separation", 24)
		content_area.add_child(action_hbox)
		
		var load_btn = Button.new()
		load_btn.text = "BUY" if is_stall else "LOAD"
		load_btn.custom_minimum_size = Vector2(100, 40)
		load_btn.focus_mode = Control.FOCUS_ALL
		action_hbox.add_child(load_btn)
		
		var unload_btn = Button.new()
		unload_btn.text = "SELL" if is_stall else "UNLOAD"
		unload_btn.custom_minimum_size = Vector2(100, 40)
		unload_btn.focus_mode = Control.FOCUS_ALL
		action_hbox.add_child(unload_btn)
		
		_setup_button_effects(load_btn)
		_setup_button_effects(unload_btn)
		
		load_btn.focus_neighbor_right = unload_btn.get_path()
		unload_btn.focus_neighbor_left = load_btn.get_path()
		
		load_btn.pressed.connect(func():
			selected_action = "LOAD"
			popup_step = 1
			_render_popup_step(building)
		)
		unload_btn.pressed.connect(func():
			selected_action = "UNLOAD"
			popup_step = 1
			_render_popup_step(building)
		)
		load_btn.call_deferred("grab_focus")
		
	elif popup_step == 1:
		var display_action = selected_action
		if is_stall:
			if selected_action == "LOAD":
				display_action = "BUY"
			elif selected_action == "UNLOAD":
				display_action = "SELL"
		var prompt = Label.new()
		prompt.text = "Select Item to %s:" % display_action
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.add_theme_font_size_override("font_size", 12)
		content_area.add_child(prompt)
		
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 130)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_area.add_child(scroll)
		
		var items_grid = GridContainer.new()
		items_grid.columns = 4
		items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_grid.add_theme_constant_override("h_separation", 6)
		items_grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(items_grid)
		
		var possible_items = []
		var econ_mgr = get_node_or_null("/root/EconomyManager")
		var db_items = econ_mgr.item_database if econ_mgr else {}
		
		if building.is_in_group("production_buildings"):
			var bench = building.get_node_or_null("CraftingBench")
			if not bench and is_instance_valid(building.get("instanced_interior")):
				bench = building.instanced_interior.get_node_or_null("CraftingBench")
			if bench and "recipes" in bench:
				for r in bench.recipes:
					if r:
						if selected_action == "LOAD":
							if r.output_item and not possible_items.has(r.output_item):
								possible_items.append(r.output_item)
						else:
							if r.inputs:
								for input_item in r.inputs:
									if not possible_items.has(input_item):
										possible_items.append(input_item)
										
		if possible_items.is_empty():
			for item_id in db_items:
				possible_items.append(db_items[item_id])
				
		var loaded_item_ids = []
		for wp in selected_waypoints:
			if wp.action == "LOAD":
				if not loaded_item_ids.has(wp.item_id):
					loaded_item_ids.append(wp.item_id)
					
		# Prioritize items loaded previously if doing UNLOAD or SELL
		if selected_action == "UNLOAD" or selected_action == "SELL":
			possible_items.sort_custom(func(a, b):
				var a_loaded = loaded_item_ids.has(a.id)
				var b_loaded = loaded_item_ids.has(b.id)
				if a_loaded and not b_loaded:
					return true
				elif not a_loaded and b_loaded:
					return false
				return a.name < b.name
			)
			
		var item_buttons = []
		for item in possible_items:
			var card_btn = Button.new()
			card_btn.custom_minimum_size = Vector2(48, 54)
			card_btn.focus_mode = Control.FOCUS_ALL
			_setup_button_effects(card_btn)
			
			var card_style_normal = StyleBoxFlat.new()
			card_style_normal.bg_color = Color(0.14, 0.16, 0.20, 0.8)
			card_style_normal.border_color = Color(0.3, 0.35, 0.4, 0.6)
			card_style_normal.set_border_width_all(1)
			card_style_normal.set_corner_radius_all(4)
			
			var is_recommended = (selected_action == "UNLOAD" or selected_action == "SELL") and loaded_item_ids.has(item.id)
			if is_recommended:
				# Premium glowing golden styling for recommended items
				card_style_normal.bg_color = Color(0.22, 0.2, 0.12, 0.9)
				card_style_normal.border_color = Color(0.88, 0.73, 0.23, 0.9)
				card_style_normal.set_border_width_all(2)
				
			var card_style_hover = card_style_normal.duplicate() as StyleBoxFlat
			card_style_hover.bg_color = Color(0.2, 0.24, 0.3, 0.9)
			card_style_hover.border_color = Color(0.88, 0.73, 0.23, 1.0)
			
			card_btn.add_theme_stylebox_override("normal", card_style_normal)
			card_btn.add_theme_stylebox_override("hover", card_style_hover)
			card_btn.add_theme_stylebox_override("focus", card_style_hover)
			
			var card_vbox = VBoxContainer.new()
			card_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			card_vbox.add_theme_constant_override("separation", 2)
			card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_btn.add_child(card_vbox)
			
			var art_placeholder = Panel.new()
			art_placeholder.custom_minimum_size = Vector2(24, 24)
			art_placeholder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			art_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var art_style = StyleBoxFlat.new()
			art_style.bg_color = Color(0.08, 0.09, 0.12, 0.9)
			art_style.border_color = Color(0.4, 0.45, 0.5, 0.3)
			art_style.set_border_width_all(1)
			art_style.set_corner_radius_all(3)
			art_placeholder.add_theme_stylebox_override("panel", art_style)
			
			var art_lbl = Label.new()
			art_lbl.text = "★" if is_recommended else "[Art]"
			art_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			art_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			art_lbl.add_theme_font_size_override("font_size", 8)
			art_lbl.modulate = Color(0.9, 0.77, 0.2) if is_recommended else Color(0.5, 0.5, 0.5)
			art_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art_placeholder.add_child(art_lbl)
			
			card_vbox.add_child(art_placeholder)
			
			var name_lbl = Label.new()
			name_lbl.text = item.name
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			name_lbl.add_theme_font_size_override("font_size", 7)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_vbox.add_child(name_lbl)
			
			card_btn.set_meta("item_id", item.id)
			items_grid.add_child(card_btn)
			item_buttons.append(card_btn)
			
			card_btn.pressed.connect(func():
				selected_item_id = item.id
				popup_step = 2
				_render_popup_step(building)
			)
			
		if item_buttons.size() > 0:
			item_buttons[0].call_deferred("grab_focus")
			
	elif popup_step == 2:
		var prompt = Label.new()
		prompt.text = "Select Quantity with A/D:"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.add_theme_font_size_override("font_size", 12)
		content_area.add_child(prompt)
		
		var econ_mgr = get_node_or_null("/root/EconomyManager")
		var item_name = selected_item_id.capitalize()
		if econ_mgr and econ_mgr.item_database.has(selected_item_id):
			item_name = econ_mgr.item_database[selected_item_id].name
			
		var item_lbl = Label.new()
		item_lbl.text = "Item: " + item_name
		item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_lbl.add_theme_font_size_override("font_size", 11)
		item_lbl.modulate = Color(0.9, 0.9, 0.4)
		content_area.add_child(item_lbl)
		
		var slider = HSlider.new()
		slider.min_value = 1
		slider.max_value = 100
		slider.step = 1
		slider.value = 20
		slider.custom_minimum_size = Vector2(240, 20)
		slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_ALL
		content_area.add_child(slider)
		
		var qty_lbl = Label.new()
		qty_lbl.text = "Quantity: 20 units"
		qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_lbl.add_theme_font_size_override("font_size", 12)
		content_area.add_child(qty_lbl)
		
		slider.value_changed.connect(func(val):
			qty_lbl.text = "Quantity: %d units" % int(val)
		)
		
		var price_slider: HSlider = null
		var price_val_lbl: Label = null
		
		# Show minimum sales price slider if doing SELL/UNLOAD at a market stall
		if selected_action == "SELL" or (selected_action == "UNLOAD" and is_stall):
			var sep = HSeparator.new()
			content_area.add_child(sep)
			
			var price_prompt = Label.new()
			price_prompt.text = "Minimum Sales Price (A/D):"
			price_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			price_prompt.add_theme_font_size_override("font_size", 12)
			content_area.add_child(price_prompt)
			
			price_slider = HSlider.new()
			price_slider.min_value = 0
			price_slider.max_value = 100
			price_slider.step = 1
			price_slider.value = 0
			price_slider.custom_minimum_size = Vector2(240, 20)
			price_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			price_slider.focus_mode = Control.FOCUS_ALL
			content_area.add_child(price_slider)
			
			price_val_lbl = Label.new()
			price_val_lbl.text = "Price: $0 (No minimum)"
			price_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			price_val_lbl.add_theme_font_size_override("font_size", 11)
			price_val_lbl.modulate = Color(0.5, 0.9, 0.5)
			content_area.add_child(price_val_lbl)
			
			price_slider.value_changed.connect(func(val):
				if val == 0:
					price_val_lbl.text = "Price: $0 (No minimum)"
				else:
					price_val_lbl.text = "Price: $%d" % int(val)
			)
			
		var confirm_btn = Button.new()
		confirm_btn.text = "Confirm"
		confirm_btn.custom_minimum_size = Vector2(90, 30)
		confirm_btn.focus_mode = Control.FOCUS_ALL
		
		var cancel_btn = Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.custom_minimum_size = Vector2(90, 30)
		cancel_btn.focus_mode = Control.FOCUS_ALL
		
		var btn_hbox = HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 16)
		btn_hbox.add_child(confirm_btn)
		btn_hbox.add_child(cancel_btn)
		content_area.add_child(btn_hbox)
		
		_setup_button_effects(confirm_btn)
		_setup_button_effects(cancel_btn)
		
		confirm_btn.pressed.connect(func():
			var min_price = int(price_slider.value) if price_slider else 0
			_confirm_popup_stop(building, int(slider.value), min_price)
		)
		cancel_btn.pressed.connect(func():
			_close_popup(building)
		)
		
		slider.call_deferred("grab_focus")
		
	var footer_hbox = HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(footer_hbox)
	
	if popup_step > 0:
		if not (is_stall and popup_step == 1):
			var back_btn = Button.new()
			back_btn.text = "< Back"
			back_btn.add_theme_font_size_override("font_size", 10)
			back_btn.custom_minimum_size = Vector2(60, 24)
			back_btn.focus_mode = Control.FOCUS_ALL
			_setup_button_effects(back_btn)
			footer_hbox.add_child(back_btn)
			back_btn.pressed.connect(func():
				popup_step -= 1
				_render_popup_step(building)
			)
		
	var close_btn = Button.new()
	close_btn.text = "Cancel Stop"
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.custom_minimum_size = Vector2(80, 24)
	close_btn.focus_mode = Control.FOCUS_ALL
	_setup_button_effects(close_btn)
	footer_hbox.add_child(close_btn)
	close_btn.pressed.connect(func():
		_close_popup(building)
	)
	
	_position_popup_next_to_node(building)

func _confirm_popup_stop(building: Node2D, qty: int, min_price: int) -> void:
	selected_waypoints.append({
		"building": building,
		"action": selected_action,
		"item_id": selected_item_id,
		"quantity": qty,
		"minimum_sell_price": min_price
	})
	_refresh_waypoints_list()
	_validate_route_stops()
	_update_metrics()
	if route_map_control:
		route_map_control.queue_redraw()
	_close_popup(building)

func _close_popup(building: Node2D) -> void:
	if popup:
		popup.queue_free()
		popup = null
		
	var target = building
	if not is_instance_valid(target):
		target = _current_configuring_building
		
	if is_instance_valid(target) and map_buttons.has(target):
		var btn = map_buttons[target]
		if is_instance_valid(btn):
			btn.grab_focus()
			
	_current_configuring_building = null

# --- Employee Selection Popup ---

func _show_employee_selection_popup() -> void:
	if employee_popup:
		employee_popup.queue_free()
		
	employee_popup = PanelContainer.new()
	employee_popup.name = "EmployeeSelectionPopup"
	employee_popup.custom_minimum_size = Vector2(420, 360)
	employee_popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	employee_popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	style.border_color = Color(0.88, 0.73, 0.23, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	employee_popup.add_theme_stylebox_override("panel", style)
	
	add_child(employee_popup)
	employee_popup.set_as_top_level(true)
	employee_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	employee_popup.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "Select Carrier Employee"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31, 1))
	vbox.add_child(title_lbl)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var emp_vbox = VBoxContainer.new()
	emp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emp_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(emp_vbox)
	
	var emps_list = []
	var hireable_list = []
	var buildings = get_tree().get_nodes_in_group("production_buildings")
	for b in buildings:
		if is_instance_valid(b) and b.ownership_type == "Player":
			var hired = b.get("hired_employees")
			if hired:
				for emp in hired:
					emps_list.append({
						"emp": emp,
						"workshop": b
					})
					
			var max_emp = b.get("max_employees") if "max_employees" in b else 3
			var current_emp_count = hired.size() if hired else 0
			if current_emp_count < max_emp:
				if b.has_method("ensure_spouse_candidate"):
					b.ensure_spouse_candidate()
				if b.has_method("_populate_candidates") and (not b.get("hireable_candidates") or b.hireable_candidates.size() == 0):
					b._populate_candidates()
					
				var cands = b.get("hireable_candidates")
				if cands:
					for cand_idx in range(cands.size()):
						var cand = cands[cand_idx]
						if is_instance_valid(cand):
							hireable_list.append({
								"candidate": cand,
								"cand_idx": cand_idx,
								"workshop": b
							})
							
	var focus_btn: Button = null
	
	# Section 1: Hired Employees
	if not emps_list.is_empty():
		var hired_header = Label.new()
		hired_header.text = "Hired Employees"
		hired_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hired_header.add_theme_font_size_override("font_size", 11)
		hired_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
		emp_vbox.add_child(hired_header)
		
		for emp_data in emps_list:
			var emp = emp_data["emp"]
			var ws = emp_data["workshop"]
			var ws_name = ws.custom_name if (ws.get("custom_name") != "" and "custom_name" in ws) else ws.name
			ws_name = ws_name.replace("Interior_", "")
			
			var state_str = "Idle"
			if emp.get("active_commercial_route") != null:
				state_str = "On Route"
			elif emp.get("active_recipe_path") != "":
				state_str = "Crafting"
			elif str(emp.get("active_gathering_node_path", "")) != "":
				state_str = "Gathering"
				
			var emp_btn = Button.new()
			emp_btn.text = "%s (%s) - %s" % [emp.get("name", "Worker"), ws_name, state_str]
			emp_btn.focus_mode = Control.FOCUS_ALL
			_setup_button_effects(emp_btn)
			emp_vbox.add_child(emp_btn)
			
			emp_btn.pressed.connect(_assign_route_to_employee.bind(emp_data))
			
			if not focus_btn:
				focus_btn = emp_btn
				
	# Section 2: Hireable Candidates
	if not hireable_list.is_empty():
		var cand_header = Label.new()
		cand_header.text = "Hire & Assign Candidates"
		cand_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cand_header.add_theme_font_size_override("font_size", 11)
		cand_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4, 1))
		
		if not emps_list.is_empty():
			var spacing = Control.new()
			spacing.custom_minimum_size = Vector2(0, 8)
			emp_vbox.add_child(spacing)
			
		emp_vbox.add_child(cand_header)
		
		for cand_data in hireable_list:
			var cand = cand_data["candidate"]
			var ws = cand_data["workshop"]
			var ws_name = ws.custom_name if (ws.get("custom_name") != "" and "custom_name" in ws) else ws.name
			ws_name = ws_name.replace("Interior_", "")
			
			var cand_name = cand.npc_name if "npc_name" in cand else cand.name
			var cand_salary = cand.salary if "salary" in cand else 15
			var cand_career = cand.career if "career" in cand else "patreon"
			
			var cand_btn = Button.new()
			cand_btn.text = "Hire %s (%s) - %s (Sal: %dG/d)" % [cand_name, ws_name, cand_career.capitalize(), cand_salary]
			cand_btn.focus_mode = Control.FOCUS_ALL
			_setup_button_effects(cand_btn)
			emp_vbox.add_child(cand_btn)
			
			cand_btn.pressed.connect(_hire_and_assign_candidate.bind(cand_data))
			
			if not focus_btn:
				focus_btn = cand_btn
				
	if emps_list.is_empty() and hireable_list.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No hired employees or candidates available.\nBuild workshops first!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		emp_vbox.add_child(empty_lbl)
		
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 30)
	cancel_btn.focus_mode = Control.FOCUS_ALL
	_setup_button_effects(cancel_btn)
	vbox.add_child(cancel_btn)
	cancel_btn.pressed.connect(func():
		_close_employee_popup()
	)
	
	if focus_btn:
		focus_btn.grab_focus()
	else:
		cancel_btn.grab_focus()

func _hire_and_assign_candidate(cand_data: Dictionary) -> void:
	var cand = cand_data["candidate"]
	var ws = cand_data["workshop"]
	var cand_idx = cand_data["cand_idx"]
	
	if not is_instance_valid(cand) or not is_instance_valid(ws):
		GameState.spawn_ui_floating_text("Invalid workshop or candidate!")
		_close_employee_popup()
		_show_employee_selection_popup()
		return
		
	var cands = ws.get("hireable_candidates")
	var hired = ws.get("hired_employees")
	var max_emp = ws.get("max_employees") if "max_employees" in ws else 3
	
	if not cands or cand_idx >= cands.size() or cands[cand_idx] != cand:
		cand_idx = cands.find(cand)
		if cand_idx == -1:
			GameState.spawn_ui_floating_text("Candidate is no longer available!")
			_close_employee_popup()
			_show_employee_selection_popup()
			return
			
	if hired.size() >= max_emp:
		GameState.spawn_ui_floating_text("Workshop is already full!")
		_close_employee_popup()
		_show_employee_selection_popup()
		return
		
	cands.remove_at(cand_idx)
	cand.go_to_workshop(ws)
	
	var emp_dict = {
		"npc_ref": cand,
		"name": cand.npc_name if "npc_name" in cand else cand.name,
		"salary": cand.salary if "salary" in cand else 15,
		"career": cand.career if "career" in cand else "patreon",
		"levels": {
			"patreon": cand.patreon_level if "patreon_level" in cand else 1,
			"scholar": cand.scholar_level if "scholar_level" in cand else 1,
			"craftsman": cand.craftsman_level if "craftsman_level" in cand else 1,
			"tailor": cand.tailor_level if "tailor_level" in cand else 1
		},
		"active_recipe_path": "",
		"craft_timer": 0.0,
		"craft_total_time": 0.0,
		"is_repeating": true,
		"auto_gather_on_shortage": false,
		"is_paused": false
	}
	hired.append(emp_dict)
	
	var emp_data = {
		"emp": emp_dict,
		"workshop": ws
	}
	_assign_route_to_employee(emp_data)

func _assign_route_to_employee(emp_data: Dictionary) -> void:
	_close_employee_popup()
	route_save_committed.emit(emp_data, selected_waypoints, true)

func _close_employee_popup() -> void:
	if employee_popup:
		employee_popup.queue_free()
		employee_popup = null

func _setup_button_effects(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	btn.mouse_entered.connect(func(): create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08))
	btn.mouse_exited.connect(func(): create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08))

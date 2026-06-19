extends PanelContainer

@onready var close_button: Button = %CloseButton
@onready var source_dropdown: OptionButton = %SourceDropdown
@onready var carrier_dropdown: OptionButton = %CarrierDropdown
@onready var cargo_dropdown: OptionButton = %CargoDropdown
@onready var amount_edit: LineEdit = %AmountEdit
@onready var price_edit: LineEdit = %PriceEdit
@onready var waypoints_list: VBoxContainer = %WaypointsList
@onready var stalls_list: VBoxContainer = %StallsList
@onready var distance_label: Label = %DistanceLabel
@onready var time_label: Label = %TimeLabel
@onready var clear_route_button: Button = %ClearRouteButton
@onready var start_route_button: Button = %StartRouteButton

var player_owned_buildings: Array = []
var selected_source_building: Node2D = null
var selected_employee_dict: Dictionary = {}
var selected_waypoints: Array = [] # Array of Dictionary Stop rows

var _warning_label: Label = null

var is_commerce_route: bool = false
var mode_selection_panel: PanelContainer = null
var popup: PanelContainer = null
var popup_step: int = 0
var selected_action: String = "LOAD"
var selected_item_id: String = ""
var _current_configuring_building: Node2D = null

# Province Zoom and Selection
var current_view_province: String = ""
var _prev_view_province: String = ""

func _ready() -> void:
	# Rename Title
	var title = get_node_or_null("Margin/VBox/TitleBar/TitleLabel")
	if title:
		title.text = "Global Logistics & Trade Console"
		
	# Hide legacy single-item cargo elements & dropdown configs
	var grid = get_node_or_null("Margin/VBox/Columns/LeftColumn/Grid")
	if grid:
		grid.visible = false
		
	var route_config_label = get_node_or_null("Margin/VBox/Columns/LeftColumn/RouteConfigLabel")
	if route_config_label:
		route_config_label.visible = false
		
	var separator = get_node_or_null("Margin/VBox/Columns/LeftColumn/HSeparator")
	if separator:
		separator.visible = false
		
	# Adjust stretch ratios of columns to make map column larger
	var left_col = get_node_or_null("Margin/VBox/Columns/LeftColumn")
	if left_col:
		left_col.size_flags_stretch_ratio = 0.6
	var right_col_node = get_node_or_null("Margin/VBox/Columns/RightColumn")
	if right_col_node:
		right_col_node.size_flags_stretch_ratio = 1.4
		
	# Swap Columns: Map (RightColumn) to the left, configuration list (LeftColumn) to the right
	var columns_container = get_node_or_null("Margin/VBox/Columns")
	if columns_container and right_col_node:
		columns_container.move_child(right_col_node, 0)
				
	# Warning label setup
	_warning_label = Label.new()
	_warning_label.add_theme_font_size_override("font_size", 11)
	_warning_label.add_theme_color_override("font_color", Color.RED)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.visible = false
	
	var vbox = get_node_or_null("Margin/VBox")
	if vbox:
		var footer = get_node_or_null("Margin/VBox/FooterBar")
		vbox.add_child(_warning_label)
		if footer:
			vbox.move_child(_warning_label, footer.get_index())
			
	# UI Hooks
	close_button.pressed.connect(close)
	clear_route_button.pressed.connect(clear_waypoints)
	start_route_button.pressed.connect(start_commercial_route)
	
	source_dropdown.item_selected.connect(_on_source_selected)
	carrier_dropdown.item_selected.connect(_on_carrier_selected)
	
	# Load data
	_populate_sources()
	if is_instance_valid(selected_source_building):
		current_view_province = GameState.get_province_of_node(selected_source_building)
	else:
		current_view_province = "Valley Province"
	_prev_view_province = current_view_province
	
	if stalls_list:
		var right_col = stalls_list.get_parent().get_parent() as VBoxContainer
		if right_col:
			_setup_route_map(right_col)
	_update_metrics()
	_show_mode_selection()

func close() -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("close_commercial_routes_ui"):
		hud.close_commercial_routes_ui()
	else:
		queue_free()

func _populate_sources() -> void:
	source_dropdown.clear()
	player_owned_buildings.clear()
	
	var buildings = get_tree().get_nodes_in_group("production_buildings")
	for b in buildings:
		if is_instance_valid(b) and b.ownership_type == "Player":
			player_owned_buildings.append(b)
			var b_name = b.custom_name if (b.get("custom_name") != "" and "custom_name" in b) else b.name
			source_dropdown.add_item(b_name.replace("Interior_", ""))
			
	if player_owned_buildings.size() > 0:
		_on_source_selected(0)
	else:
		carrier_dropdown.clear()

func _on_source_selected(index: int) -> void:
	if index < 0 or index >= player_owned_buildings.size():
		return
		
	selected_source_building = player_owned_buildings[index]
	if is_instance_valid(selected_source_building):
		var new_prov = GameState.get_province_of_node(selected_source_building)
		if new_prov != "":
			current_view_province = new_prov
			_prev_view_province = new_prov
			if is_instance_valid(route_map_control):
				_recreate_map_buttons()
				route_map_control.queue_redraw()
	
	# Populate employees
	carrier_dropdown.clear()
	selected_employee_dict = {}
	
	var emps = selected_source_building.get("hired_employees")
	if emps and emps.size() > 0:
		for i in range(emps.size()):
			var emp = emps[i]
			var active_route = emp.get("active_commercial_route")
			var route_info = " (Idle)"
			if active_route:
				route_info = " (On Route: " + active_route.route_name + ")"
			elif emp.get("active_recipe_path") != "":
				route_info = " (Crafting)"
			elif str(emp.get("active_gathering_node_path", "")) != "":
				route_info = " (Gathering)"
				
			carrier_dropdown.add_item(emp.get("name", "Worker") + route_info)
		_on_carrier_selected(0)
	else:
		carrier_dropdown.add_item("No hired workers available")

func _on_carrier_selected(index: int) -> void:
	var emps = selected_source_building.get("hired_employees")
	if emps and index >= 0 and index < emps.size():
		selected_employee_dict = emps[index]
	else:
		selected_employee_dict = {}
	_update_metrics()

func _populate_public_stalls() -> void:
	pass

func add_waypoint(building: Node2D) -> void:
	var default_item_id = ""
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	if econ_mgr and not econ_mgr.item_database.is_empty():
		default_item_id = econ_mgr.item_database.keys()[0]
		
	selected_waypoints.append({
		"building": building,
		"action": "LOAD",
		"item_id": default_item_id,
		"quantity": 20
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
			
		var desc_lbl = Label.new()
		desc_lbl.text = "%d. %s (%s: %d %s)" % [(i + 1), b_name, stop_data.action, stop_data.quantity, item_name]
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
		
	var childs = waypoints_list.get_children()
	for idx in range(childs.size()):
		var row = childs[idx]
		var del_btn = row.get_child(row.get_child_count() - 1) as Button
		if idx > 0:
			var prev_row = childs[idx - 1]
			var prev_btn = prev_row.get_child(prev_row.get_child_count() - 1) as Button
			prev_btn.focus_neighbor_bottom = del_btn.get_path()
			del_btn.focus_neighbor_top = prev_btn.get_path()

func _validate_route_stops() -> bool:
	var error_msg = ""
	var is_valid = true
	
	for i in range(selected_waypoints.size()):
		var stop_data = selected_waypoints[i]
		var building = stop_data.building
		var action = stop_data.action
		var item_id = stop_data.item_id
		
		if action == "UNLOAD" and is_instance_valid(building):
			var consumed_ingredients = {}
			var bench = building.get_node_or_null("CraftingBench")
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
		_warning_label.visible = true
	else:
		start_route_button.disabled = false
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

func start_commercial_route() -> void:
	if selected_waypoints.is_empty():
		GameState.spawn_ui_floating_text("Select at least one stop!")
		return
		
	if not _validate_route_stops():
		return
		
	_show_employee_selection_popup()

# --- Visual Route Planning Map ---

var route_map_control: Control = null
var map_buttons: Dictionary = {}
var employee_popup: PanelContainer = null

func _setup_route_map(container: VBoxContainer) -> void:
	if stalls_list and stalls_list.get_parent():
		stalls_list.get_parent().visible = false
		
	var title = container.get_node_or_null("StallsLabel")
	if title:
		title.text = "Select Route Waypoints on Map:"
		
	var map_panel = PanelContainer.new()
	map_panel.custom_minimum_size = Vector2(500, 420)
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
	
	# Generate building buttons
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
	if is_commerce_route:
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
			btn_style_normal.bg_color = Color(0.18, 0.24, 0.35, 0.85) # Slate blue-gray
			btn_style_normal.set_border_width_all(2)
			btn_style_normal.border_color = Color(0.88, 0.73, 0.23, 0.5)
			btn_style_normal.set_corner_radius_all(10)
			
			var btn_style_hover = btn_style_normal.duplicate() as StyleBoxFlat
			btn_style_hover.bg_color = Color(0.24, 0.32, 0.45, 0.95)
			btn_style_hover.border_color = Color(0.88, 0.73, 0.23, 1.0)
			btn_style_hover.set_border_width_all(3)
			
			var btn_style_focused = btn_style_hover.duplicate() as StyleBoxFlat
			
			btn.add_theme_stylebox_override("normal", btn_style_normal)
			btn.add_theme_stylebox_override("hover", btn_style_hover)
			btn.add_theme_stylebox_override("focus", btn_style_focused)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_font_size_override("font_size", 12)
			
			btn.pressed.connect(func():
				_zoom_into_province(p)
			)
			
			route_map_control.add_child(btn)
			map_buttons[p] = btn
			_setup_button_effects(btn)
			
		var valley_btn = map_buttons["Valley Province"]
		var oak_btn = map_buttons["Oakhaven Province"]
		valley_btn.focus_neighbor_right = oak_btn.get_path()
		oak_btn.focus_neighbor_left = valley_btn.get_path()
		
		var default_p = "Valley Province"
		if is_instance_valid(selected_source_building):
			var src_prov = GameState.get_province_of_node(selected_source_building)
			if src_prov in map_buttons:
				default_p = src_prov
		map_buttons[default_p].call_deferred("grab_focus")
		
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
				btn_style_normal.bg_color = Color(0.2, 0.62, 0.36, 0.8) # Green
			elif ownership == "NPC":
				btn_style_normal.bg_color = Color(0.7, 0.3, 0.2, 0.8) # Red/brown
			else:
				btn_style_normal.bg_color = Color(0.2, 0.5, 0.7, 0.8) # Blue/teal
		else:
			btn_style_normal.bg_color = Color(0.2, 0.62, 0.36, 0.8) # Green for Player owned
			
		btn_style_normal.set_border_width_all(1)
		btn_style_normal.border_color = Color(1.0, 1.0, 1.0, 0.4)
		btn_style_normal.set_corner_radius_all(6)
		
		var btn_style_hover = btn_style_normal.duplicate() as StyleBoxFlat
		btn_style_hover.bg_color = Color(0.25, 0.75, 0.45, 1.0) if not is_stall else (btn_style_normal.bg_color + Color(0.1, 0.1, 0.1))
		btn_style_hover.border_color = Color(0.9, 0.77, 0.31, 1.0)
		btn_style_hover.set_border_width_all(2)
		
		var btn_style_focused = btn_style_hover.duplicate() as StyleBoxFlat
		
		btn.add_theme_stylebox_override("normal", btn_style_normal)
		btn.add_theme_stylebox_override("hover", btn_style_hover)
		btn.add_theme_stylebox_override("focus", btn_style_focused)
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
		
	if map_buttons.size() > 0:
		map_buttons.values()[0].call_deferred("grab_focus")
		
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

func _on_map_draw() -> void:
	if not is_instance_valid(route_map_control):
		return
		
	var bounds = get_world_bounds()
	var size_map = route_map_control.size
	
	var scale_factor = min(size_map.x / bounds.size.x, size_map.y / bounds.size.y)
	var offset = (size_map - bounds.size * scale_factor) / 2.0
	
	var to_map = func(world_pos: Vector2) -> Vector2:
		return offset + (world_pos - bounds.position) * scale_factor
		
	# Draw territory boxes when in selection mode
	if current_view_province == "":
		var raw_nodes = []
		var groups = ["Roads", "Plazas", "Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Houses", "MarketStall"]
		for g in groups:
			raw_nodes.append_array(get_tree().get_nodes_in_group(g))
			
		var draw_territory = func(prov_name: String, color: Color):
			var min_x = INF
			var min_y = INF
			var max_x = -INF
			var max_y = -INF
			for n in raw_nodes:
				if is_instance_valid(n) and GameState.get_province_of_node(n) == prov_name:
					var pos = n.global_position
					if pos.x < min_x: min_x = pos.x
					if pos.y < min_y: min_y = pos.y
					if pos.x > max_x: max_x = pos.x
					if pos.y > max_y: max_y = pos.y
			if min_x != INF:
				min_x -= 100
				min_y -= 100
				max_x += 100
				max_y += 100
				var p1 = to_map.call(Vector2(min_x, min_y))
				var p2 = to_map.call(Vector2(max_x, max_y))
				var rect = Rect2(p1, p2 - p1)
				
				# Semi-transparent background fill
				route_map_control.draw_rect(rect, Color(color.r, color.g, color.b, 0.08))
				# Colored border outline
				route_map_control.draw_rect(rect, Color(color.r, color.g, color.b, 0.4), false, 1.5)
				
		draw_territory.call("Valley Province", Color(0.2, 0.6, 0.85))
		draw_territory.call("Oakhaven Province", Color(0.85, 0.55, 0.2))
		
	# Draw plazas
	for plaza in get_tree().get_nodes_in_group("Plazas"):
		if is_instance_valid(plaza) and "size" in plaza:
			if current_view_province != "" and GameState.get_province_of_node(plaza) != current_view_province:
				continue
			var center = to_map.call(plaza.global_position)
			var p_size = plaza.size * scale_factor
			route_map_control.draw_rect(Rect2(center - p_size / 2.0, p_size), Color(0.5, 0.46, 0.42, 1.0)) # paved plaza
			route_map_control.draw_rect(Rect2(center - p_size / 2.0, p_size), Color(0.4, 0.36, 0.32, 0.5), false, 1.0)
			
	# Draw markets ColorRects
	for city in get_tree().get_nodes_in_group("Cities") + get_tree().get_nodes_in_group("Towns"):
		if current_view_province != "" and GameState.get_province_of_node(city) != current_view_province:
			continue
		var m_path = city.get("market_node_path")
		if m_path:
			var market = city.get_node_or_null(m_path)
			if is_instance_valid(market) and market is ColorRect:
				var center = to_map.call(market.global_position + market.size / 2.0)
				var m_size = market.size * scale_factor
				route_map_control.draw_rect(Rect2(center - m_size / 2.0, m_size), Color(0.5, 0.46, 0.42, 1.0)) # brick paved market
				route_map_control.draw_rect(Rect2(center - m_size / 2.0, m_size), Color(0.4, 0.36, 0.32, 0.5), false, 1.0)
			
	# Draw roads
	for road in get_tree().get_nodes_in_group("Roads"):
		if is_instance_valid(road) and "size" in road:
			if current_view_province != "" and GameState.get_province_of_node(road) != current_view_province:
				continue
			var center = to_map.call(road.global_position)
			var r_size = road.size * scale_factor
			route_map_control.draw_rect(Rect2(center - r_size / 2.0, r_size), Color(0.4, 0.4, 0.42, 1.0)) # stone gray road
			
	# Draw route connections with gold lines connecting source building -> stops -> source loop
	var route_points = []
	if is_instance_valid(selected_source_building):
		route_points.append(selected_source_building)
	for wp_data in selected_waypoints:
		var wp = wp_data.building
		if is_instance_valid(wp):
			route_points.append(wp)
	if is_instance_valid(selected_source_building) and route_points.size() > 1:
		route_points.append(selected_source_building) # complete the loop back to source
		
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

func _setup_button_effects(btn: Button) -> void:
	if not btn.is_node_ready():
		btn.ready.connect(func(): btn.pivot_offset = btn.size / 2.0)
	else:
		btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	
	btn.mouse_entered.connect(func():
		if not btn.disabled:
			create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
	)
	btn.mouse_exited.connect(func():
		create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)
	btn.focus_entered.connect(func():
		if not btn.disabled:
			create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
	)
	btn.focus_exited.connect(func():
		create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)

func _show_mode_selection() -> void:
	var columns = get_node_or_null("Margin/VBox/Columns")
	var footer = get_node_or_null("Margin/VBox/FooterBar")
	if columns: columns.visible = false
	if footer: footer.visible = false
	
	if mode_selection_panel:
		mode_selection_panel.queue_free()
		
	mode_selection_panel = PanelContainer.new()
	mode_selection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_selection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.96)
	style.set_corner_radius_all(8)
	mode_selection_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	mode_selection_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Select Logistics Operation Mode"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31, 1))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = "Establish an automated route for internal workshop resource supply or sell directly to market stalls."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(desc)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 32)
	vbox.add_child(hbox)
	
	# Option 1: Trade Route
	var o1_vbox = VBoxContainer.new()
	o1_vbox.custom_minimum_size = Vector2(240, 140)
	o1_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(o1_vbox)
	
	var trade_btn = Button.new()
	trade_btn.text = "Internal Trade Route"
	trade_btn.custom_minimum_size = Vector2(220, 50)
	trade_btn.focus_mode = Control.FOCUS_ALL
	o1_vbox.add_child(trade_btn)
	
	var t_desc = Label.new()
	t_desc.text = "Connects player workshops and houses sequentially to balance production. No markets."
	t_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	t_desc.add_theme_font_size_override("font_size", 10)
	t_desc.modulate = Color(0.7, 0.7, 0.7)
	o1_vbox.add_child(t_desc)
	
	# Option 2: Commerce Route
	var o2_vbox = VBoxContainer.new()
	o2_vbox.custom_minimum_size = Vector2(240, 140)
	o2_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(o2_vbox)
	
	var comm_btn = Button.new()
	comm_btn.text = "Commercial Route"
	comm_btn.custom_minimum_size = Vector2(220, 50)
	comm_btn.focus_mode = Control.FOCUS_ALL
	o2_vbox.add_child(comm_btn)
	
	var c_desc = Label.new()
	c_desc.text = "Includes market stalls for selling finished goods or buying ingredients."
	c_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	c_desc.add_theme_font_size_override("font_size", 10)
	c_desc.modulate = Color(0.7, 0.7, 0.7)
	o2_vbox.add_child(c_desc)
	
	var main_vbox = get_node_or_null("Margin/VBox")
	if main_vbox:
		main_vbox.add_child(mode_selection_panel)
		main_vbox.move_child(mode_selection_panel, 1)
		
	trade_btn.pressed.connect(func():
		is_commerce_route = false
		_start_configuration()
	)
	comm_btn.pressed.connect(func():
		is_commerce_route = true
		_start_configuration()
	)
	
	_setup_button_effects(trade_btn)
	_setup_button_effects(comm_btn)
	
	trade_btn.focus_neighbor_right = comm_btn.get_path()
	comm_btn.focus_neighbor_left = trade_btn.get_path()
	trade_btn.call_deferred("grab_focus")

func _start_configuration() -> void:
	if mode_selection_panel:
		mode_selection_panel.queue_free()
		mode_selection_panel = null
		
	var columns = get_node_or_null("Margin/VBox/Columns")
	var footer = get_node_or_null("Margin/VBox/FooterBar")
	if columns: columns.visible = true
	if footer: footer.visible = true
	
	_recreate_map_buttons()
	_update_metrics()
	
	# Focus first map button or source dropdown
	if map_buttons.size() > 0:
		map_buttons.values()[0].call_deferred("grab_focus")

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
	popup.custom_minimum_size = Vector2(400, 360)
	popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	style.border_color = Color(0.88, 0.73, 0.23, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	popup.add_theme_stylebox_override("panel", style)
	
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
	popup.position.x -= 30
	
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
		load_btn.text = "LOAD"
		load_btn.custom_minimum_size = Vector2(100, 40)
		load_btn.focus_mode = Control.FOCUS_ALL
		action_hbox.add_child(load_btn)
		
		var unload_btn = Button.new()
		unload_btn.text = "UNLOAD"
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
		var prompt = Label.new()
		prompt.text = "Select Item to %s:" % selected_action
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.add_theme_font_size_override("font_size", 12)
		content_area.add_child(prompt)
		
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 180)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_area.add_child(scroll)
		
		var items_grid = GridContainer.new()
		items_grid.columns = 6
		items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_grid.add_theme_constant_override("h_separation", 6)
		items_grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(items_grid)
		
		var possible_items = []
		var econ_mgr = get_node_or_null("/root/EconomyManager")
		var db_items = econ_mgr.item_database if econ_mgr else {}
		
		if building.is_in_group("production_buildings"):
			var bench = building.get_node_or_null("CraftingBench")
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
			
			var card_style_hover = card_style_normal.duplicate() as StyleBoxFlat
			card_style_hover.bg_color = Color(0.2, 0.24, 0.3, 0.9)
			card_style_hover.border_color = Color(0.88, 0.73, 0.23, 0.8)
			card_style_hover.set_border_width_all(1.2)
			
			var card_style_focused = card_style_hover.duplicate() as StyleBoxFlat
			card_style_focused.border_color = Color(0.88, 0.73, 0.23, 1.0)
			card_style_focused.set_border_width_all(1.5)
			
			card_btn.add_theme_stylebox_override("normal", card_style_normal)
			card_btn.add_theme_stylebox_override("hover", card_style_hover)
			card_btn.add_theme_stylebox_override("focus", card_style_focused)
			
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
			art_lbl.text = "[Art]"
			art_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			art_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			art_lbl.add_theme_font_size_override("font_size", 6)
			art_lbl.modulate = Color(0.5, 0.5, 0.5)
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
		
		slider.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed:
				if event.keycode == KEY_A:
					slider.value = max(slider.min_value, slider.value - 1)
					get_viewport().set_input_as_handled()
				elif event.keycode == KEY_D:
					slider.value = min(slider.max_value, slider.value + 1)
					get_viewport().set_input_as_handled()
				elif event.is_action_pressed("ui_accept") or event.keycode == KEY_F:
					_confirm_popup_stop(building, int(slider.value))
					get_viewport().set_input_as_handled()
		)
		
		var btn_hbox = HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 16)
		content_area.add_child(btn_hbox)
		
		var confirm_btn = Button.new()
		confirm_btn.text = "Confirm"
		confirm_btn.custom_minimum_size = Vector2(90, 30)
		confirm_btn.focus_mode = Control.FOCUS_ALL
		btn_hbox.add_child(confirm_btn)
		
		var cancel_btn = Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.custom_minimum_size = Vector2(90, 30)
		cancel_btn.focus_mode = Control.FOCUS_ALL
		btn_hbox.add_child(cancel_btn)
		
		_setup_button_effects(confirm_btn)
		_setup_button_effects(cancel_btn)
		
		slider.focus_neighbor_bottom = confirm_btn.get_path()
		confirm_btn.focus_neighbor_top = slider.get_path()
		confirm_btn.focus_neighbor_right = cancel_btn.get_path()
		cancel_btn.focus_neighbor_left = confirm_btn.get_path()
		cancel_btn.focus_neighbor_top = slider.get_path()
		
		confirm_btn.pressed.connect(func():
			_confirm_popup_stop(building, int(slider.value))
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

func _confirm_popup_stop(building: Node2D, qty: int) -> void:
	selected_waypoints.append({
		"building": building,
		"action": selected_action,
		"item_id": selected_item_id,
		"quantity": qty
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

func _show_employee_selection_popup() -> void:
	if employee_popup:
		employee_popup.queue_free()
		
	employee_popup = PanelContainer.new()
	employee_popup.name = "EmployeeSelectionPopup"
	employee_popup.custom_minimum_size = Vector2(380, 320)
	employee_popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	employee_popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	style.border_color = Color(0.88, 0.73, 0.23, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	employee_popup.add_theme_stylebox_override("panel", style)
	
	add_child(employee_popup)
	employee_popup.anchors_preset = Control.PRESET_CENTER
	
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
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var emp_vbox = VBoxContainer.new()
	emp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emp_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(emp_vbox)
	
	var emps_list = []
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
					
	var emp_buttons = []
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
		emp_buttons.append(emp_btn)
		
		emp_btn.pressed.connect(func():
			_assign_route_to_employee(emp_data)
		)
		
	if emp_buttons.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No hired employees available.\nHire workers in workshops first!"
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
	
	for idx in range(emp_buttons.size()):
		var btn = emp_buttons[idx]
		if idx > 0:
			btn.focus_neighbor_top = emp_buttons[idx - 1].get_path()
		if idx < emp_buttons.size() - 1:
			btn.focus_neighbor_bottom = emp_buttons[idx + 1].get_path()
		else:
			btn.focus_neighbor_bottom = cancel_btn.get_path()
			cancel_btn.focus_neighbor_top = btn.get_path()
			
	if emp_buttons.size() > 0:
		emp_buttons[0].call_deferred("grab_focus")
		cancel_btn.focus_neighbor_bottom = emp_buttons[0].get_path()
		emp_buttons[0].focus_neighbor_top = cancel_btn.get_path()
	else:
		cancel_btn.call_deferred("grab_focus")

func _assign_route_to_employee(emp_data: Dictionary) -> void:
	var emp = emp_data["emp"]
	var ws = emp_data["workshop"]
	
	selected_employee_dict = emp
	selected_source_building = ws
	
	_close_employee_popup()
	_execute_start_route()

func _execute_start_route() -> void:
	var route = load("res://components/production/global_logistics_route.gd").new()
	route.route_name = "Route for " + selected_employee_dict.get("name", "Worker")
	
	var stops: Array[Resource] = []
	for wp_data in selected_waypoints:
		var stop = load("res://components/production/trade_route_stop.gd").new()
		stop.target_building = wp_data.building
		stop.action_type = wp_data.action
		stop.item_id = wp_data.item_id
		stop.target_quantity = wp_data.quantity
		stops.append(stop)
		
	route.route_stops = stops
	
	var npc = selected_employee_dict.get("npc_ref")
	route.carrier_npc_ref = npc
	
	selected_employee_dict["active_recipe_path"] = ""
	selected_employee_dict["active_gathering_node_path"] = ""
	selected_employee_dict["active_commercial_route"] = route
	selected_employee_dict["is_paused"] = false
	
	if is_instance_valid(npc):
		npc.active_commercial_route = route
		npc.current_stop_index = 0
		npc.worker_state = "internal_route_transit"
		npc.commercial_route_current_waypoint_index = 0
		npc.commercial_route_cargo_item_id = ""
		npc.commercial_route_cargo_amount = 0
		npc.commercial_route_gold_carried = 0
		npc.cargo_inventory.clear()
		
		npc.call("_start_transit_to_stop", 0)
		
	GameState.spawn_ui_floating_text("Logistics route started for %s!" % selected_employee_dict.get("name", "Worker"))
	close()

func _close_employee_popup() -> void:
	if employee_popup:
		employee_popup.queue_free()
		employee_popup = null
	start_route_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# Handle interact key (F) or interact action on focused buttons
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and is_instance_valid(focused) and is_ancestor_of(focused):
				if focused is Button:
					focused.pressed.emit()
					get_viewport().set_input_as_handled()
					return
					
		# Intercept TAB key for province selection toggling
		elif event is InputEventKey and event.keycode == KEY_TAB:
			if not popup and not employee_popup and not mode_selection_panel:
				get_viewport().set_input_as_handled()
				if current_view_province != "":
					_zoom_out_to_selection()
				else:
					var target_p = _prev_view_province if _prev_view_province != "" else "Valley Province"
					_zoom_into_province(target_p)
				return
				
	if event.is_action_pressed("ui_cancel"):
		if employee_popup:
			_close_employee_popup()
			get_viewport().set_input_as_handled()
		elif popup:
			_close_popup(_current_configuring_building)
			get_viewport().set_input_as_handled()
		else:
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_ENTER):
		if not popup and not employee_popup and not mode_selection_panel:
			var focused = get_viewport().gui_get_focus_owner()
			if focused != close_button and focused != clear_route_button and focused != start_route_button and not focused in map_buttons.values():
				start_commercial_route()
				get_viewport().set_input_as_handled()

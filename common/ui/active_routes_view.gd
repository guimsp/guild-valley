extends VBoxContainer

signal modify_route_requested(emp_data: Dictionary, route: Resource)

@onready var routes_list: VBoxContainer = %RoutesList

func _ready() -> void:
	refresh_routes()

func refresh_routes() -> void:
	for child in routes_list.get_children():
		child.queue_free()
		
	var emps_list = []
	var buildings = get_tree().get_nodes_in_group("production_buildings")
	for b in buildings:
		if is_instance_valid(b) and b.ownership_type == "Player":
			var hired = b.get("hired_employees")
			if hired:
				for emp in hired:
					if emp.get("active_commercial_route") != null:
						emps_list.append({
							"emp": emp,
							"workshop": b
						})
						
	if emps_list.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No active logistics routes running."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		routes_list.add_child(empty_lbl)
		return
		
	for data in emps_list:
		var emp = data["emp"]
		var ws = data["workshop"]
		var route = emp["active_commercial_route"]
		
		# Row PanelContainer
		var row = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.15, 0.2, 0.8)
		style.set_border_width_all(1)
		style.border_color = Color(0.2, 0.25, 0.3, 0.6)
		style.set_corner_radius_all(6)
		row.add_theme_stylebox_override("panel", style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		row.add_child(margin)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		margin.add_child(hbox)
		
		# Info VBox
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		
		var emp_name = emp.get("name", "Worker")
		var ws_name = ws.custom_name if (ws.get("custom_name") != "" and "custom_name" in ws) else ws.name
		ws_name = ws_name.replace("Interior_", "")
		
		var name_lbl = Label.new()
		name_lbl.text = "%s (%s) - %s" % [emp_name, ws_name, route.route_name]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31, 1))
		info_vbox.add_child(name_lbl)
		
		# Stop Details
		var stop_names = []
		for stop in route.route_stops:
			if is_instance_valid(stop) and is_instance_valid(stop.target_building):
				var b_name = stop.target_building.custom_name if (stop.target_building.get("custom_name") != "" and "custom_name" in stop.target_building) else stop.target_building.name
				b_name = b_name.replace("Interior_", "")
				var min_price_str = ""
				var is_market = stop.target_building.is_in_group("MarketStall")
				var act_label = "SELL" if is_market and stop.action_type == "UNLOAD" else stop.action_type
				if (stop.action_type == "UNLOAD" or stop.action_type == "SELL") and stop.get("minimum_sell_price") > 0:
					min_price_str = " (min $%d)" % stop.minimum_sell_price
				stop_names.append("%s %d %s at %s%s" % [act_label, stop.target_quantity, stop.item_id.capitalize(), b_name, min_price_str])
		var stops_lbl = Label.new()
		stops_lbl.text = " -> ".join(stop_names) if not stop_names.is_empty() else "No Stops Configured"
		stops_lbl.add_theme_font_size_override("font_size", 11)
		stops_lbl.modulate = Color(0.8, 0.8, 0.8)
		stops_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		info_vbox.add_child(stops_lbl)
		
		# Buttons
		var btn_hbox = HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 8)
		hbox.add_child(btn_hbox)
		
		var modify_btn = Button.new()
		modify_btn.text = "Modify"
		modify_btn.custom_minimum_size = Vector2(80, 28)
		modify_btn.add_theme_font_size_override("font_size", 11)
		btn_hbox.add_child(modify_btn)
		modify_btn.pressed.connect(func():
			modify_route_requested.emit(data, route)
		)
		
		var cancel_btn = Button.new()
		cancel_btn.text = "Stop"
		cancel_btn.custom_minimum_size = Vector2(80, 28)
		cancel_btn.add_theme_font_size_override("font_size", 11)
		btn_hbox.add_child(cancel_btn)
		cancel_btn.pressed.connect(func():
			_cancel_route(data)
		)
		
		_setup_button_effects(modify_btn)
		_setup_button_effects(cancel_btn)
		
		routes_list.add_child(row)

func _cancel_route(data: Dictionary) -> void:
	var emp = data["emp"]
	var npc = emp.get("npc_ref")
	emp["active_commercial_route"] = null
	if is_instance_valid(npc):
		npc.active_commercial_route = null
		npc.worker_state = "idle_at_workshop"
		npc.current_stop_index = 0
		npc.cargo_inventory.clear()
		if is_instance_valid(npc.hired_by_building):
			var target_pos = npc.hired_by_building.get_interaction_position() if npc.hired_by_building.has_method("get_interaction_position") else npc.hired_by_building.global_position
			npc.navigation.generate_path(target_pos)
	refresh_routes()

func _setup_button_effects(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	btn.mouse_entered.connect(func(): create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08))
	btn.mouse_exited.connect(func(): create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08))

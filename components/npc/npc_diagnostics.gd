class_name NPCDiagnostics
extends Object

static func log_employee(npc: CharacterBody2D, delta: float, debug_timer: float) -> float:
	var next_timer = debug_timer - delta
	if next_timer <= 0.0:
		next_timer = 5.0
		if not is_instance_valid(npc):
			return next_timer
			
		var emp_data = null
		if is_instance_valid(npc.hired_by_building):
			for emp in npc.hired_by_building.hired_employees:
				if emp.get("npc_ref") == npc:
					emp_data = emp
					break
					
		var building_name = npc.hired_by_building.name if is_instance_valid(npc.hired_by_building) else "None"
		var target_pos = Vector2.ZERO
		var target_dist = -1.0
		var nav_finished = false
		var path_pending = false
		var target_pos_str = "None"
		
		if npc.nav_motor and npc.nav_motor.nav_agent:
			target_pos = npc.nav_motor.nav_agent.target_position
			target_pos_str = str(target_pos)
			target_dist = npc.global_position.distance_to(target_pos)
			nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
			path_pending = npc.nav_motor.path_pending if "path_pending" in npc.nav_motor else false
			
		var eq = npc.get_node_or_null("EquipmentComponent")
		var equipped_tool = "None"
		if eq:
			var current_tool = eq.get_equipped_item("tool")
			if current_tool:
				equipped_tool = current_tool.id
				
		var is_paused = emp_data.get("is_paused", false) if emp_data else false
		var active_recipe = emp_data.get("active_recipe_path", "") if emp_data else ""
		var active_node = emp_data.get("active_gathering_node_path", "") if emp_data else ""
		
		var doorstep_pos = npc.hired_by_building.get_interaction_position() if is_instance_valid(npc.hired_by_building) else Vector2.ZERO
		var doorstep_dist = npc.global_position.distance_to(doorstep_pos) if is_instance_valid(npc.hired_by_building) else -1.0
		
		var show_emotes = true
		var econ = Engine.get_main_loop().root.get_node_or_null("EconomyManager")
		if econ:
			show_emotes = econ.show_debug_emotes
			
		if show_emotes:
			print("[Employee Diagnostics] Name: %s | State: %s | Pos: %s | Hired By: %s | Doorstep: %s (Dist: %.1f) | Nav Target: %s (Dist: %.1f, Finished: %s, Pending: %s) | Paused: %s | Recipe: %s | Node: %s | Tool: %s | Velocity: %s | Shift Active: %s" % [
				npc.npc_name,
				npc.worker_state,
				str(npc.global_position),
				building_name,
				str(doorstep_pos),
				doorstep_dist,
				target_pos_str,
				target_dist,
				str(nav_finished),
				str(path_pending),
				str(is_paused),
				active_recipe,
				active_node,
				equipped_tool,
				str(npc.velocity),
				str(npc.is_shift_active())
			])
	return next_timer

static func update_action_label(npc: CharacterBody2D) -> void:
	if not is_instance_valid(npc) or not is_instance_valid(npc.action_label):
		return
		
	action_label_setup(npc)

static func action_label_setup(npc: CharacterBody2D) -> void:
	# Apply rank color
	npc.action_label.add_theme_color_override("font_color", npc.rank_color)
	
	var show_emotes = true
	if npc._economy_manager:
		show_emotes = npc._economy_manager.show_debug_emotes
	npc.action_label.visible = show_emotes
	
	if not show_emotes:
		return
		
	if npc.roams_interior_only:
		var display_rank = npc.npc_rank if npc.npc_rank != "" else "City Council"
		npc.action_label.text = "%s\n%s" % [npc.npc_name, display_rank]
		return
		
	var state_str = "Unknown"
	var target_item = npc.target_item_id
	var target_stall_node = npc.target_stall
	
	var item_name = ""
	if target_item != "":
		item_name = target_item.capitalize()
		if npc._economy_manager and npc._economy_manager.item_database.has(target_item):
			item_name = npc._economy_manager.item_database[target_item].name
			
	var shop_info = ""
	if is_instance_valid(target_stall_node):
		var s_name = ""
		var building = null
		var building_type = ""
		
		if target_stall_node.get("parent_building") != null:
			building = target_stall_node.parent_building
			s_name = target_stall_node.market_name
		else:
			if target_stall_node.get("custom_name") != null and target_stall_node.custom_name != "":
				s_name = target_stall_node.custom_name
			elif target_stall_node.get("market_name") != null and target_stall_node.market_name != "":
				s_name = target_stall_node.market_name
			else:
				s_name = target_stall_node.name
				
			var building_groups = ["Bakeries", "Smelters", "Inns", "Looms", "Mills", "PaperMakers", "PrintingPresses", "Banks", "Houses"]
			for grp in building_groups:
				if target_stall_node.is_in_group(grp):
					building = target_stall_node
					break
		
		if is_instance_valid(building):
			s_name = building.custom_name if ("custom_name" in building and building.custom_name != "") else building.name
			if building.is_in_group("Bakeries"): building_type = "Bakery"
			elif building.is_in_group("Smelters"): building_type = "Smelter"
			elif building.is_in_group("Inns"): building_type = "Inn"
			elif building.is_in_group("Looms"): building_type = "Loom"
			elif building.is_in_group("Mills"): building_type = "Mill"
			elif building.is_in_group("PaperMakers"): building_type = "Paper Maker"
			elif building.is_in_group("PrintingPresses"): building_type = "Printing Press"
			elif building.is_in_group("Banks"): building_type = "Bank"
			elif building.is_in_group("Houses"): building_type = "House"
		
		if building_type != "":
			shop_info = "%s (%s)" % [s_name, building_type]
		else:
			shop_info = s_name

	if npc.is_hired:
		if not npc.is_shift_active():
			state_str = "Off-Duty (Resting)"
			if npc.is_leisure_consuming:
				if is_instance_valid(npc.leisure_spot_building):
					state_str = "Off-Duty (Relaxing at %s)" % (npc.leisure_spot_building.custom_name if ("custom_name" in npc.leisure_spot_building and npc.leisure_spot_building.custom_name != "") else npc.leisure_spot_building.name)
				else:
					state_str = "Off-Duty (Relaxing)"
			elif is_instance_valid(npc.leisure_spot_building):
				state_str = "Off-Duty (Going to %s)" % (npc.leisure_spot_building.custom_name if ("custom_name" in npc.leisure_spot_building and npc.leisure_spot_building.custom_name != "") else npc.leisure_spot_building.name)
			else:
				state_str = "Off-Duty (Wandering)"
		elif npc.active_commercial_route != null:
			if npc.active_commercial_route.get("route_stops") != null:
				match npc.worker_state:
					"internal_route_transit":
						var stop_idx = npc.current_stop_index
						var stops_count = npc.active_commercial_route.route_stops.size()
						state_str = "Logistics Stop %d/%d (Transit)" % [stop_idx + 1, stops_count]
					"internal_route_action":
						state_str = "Logistics Stop %d (Executing)" % (npc.current_stop_index + 1)
					_:
						state_str = "Logistics: " + npc.worker_state.capitalize()
			else:
				var cargo_name = npc.commercial_route_cargo_item_id.capitalize() if npc.commercial_route_cargo_item_id != "" else "Cargo"
				match npc.worker_state:
					"commercial_route_loading":
						state_str = "Logistics: Loading " + cargo_name
					"commercial_route_transit":
						state_str = "Logistics: Waypoint %d/%d" % [npc.commercial_route_current_waypoint_index + 1, npc.active_commercial_route.market_waypoints.size()]
					"commercial_route_returning":
						state_str = "Logistics: Returning to Workshop"
					_:
						state_str = "Logistics: " + npc.worker_state.capitalize()
		else:
			match npc.worker_state:
				"traveling_to_workshop":
					state_str = "Traveling to Workshop"
				"idle_at_workshop":
					state_str = "Idle at Workshop"
				"traveling_to_node":
					var node_name = npc.target_mega_node.node_name if is_instance_valid(npc.target_mega_node) else "Mega-Node"
					state_str = "Traveling to %s" % node_name
				"gathering_at_node":
					var node_name = npc.target_mega_node.node_name if is_instance_valid(npc.target_mega_node) else "Mega-Node"
					state_str = "Gathering at %s" % node_name
				"returning_to_workshop":
					state_str = "Returning with Cargo"
				"traveling_to_workbench":
					state_str = "Going to workbench"
				"producing_goods":
					var has_recipe = false
					var is_paused = false
					if is_instance_valid(npc.hired_by_building):
						for emp in npc.hired_by_building.hired_employees:
							if emp.get("npc_ref") == npc:
								if emp.get("active_recipe_path") != "":
									has_recipe = true
								is_paused = emp.get("is_paused", false)
								break
					if has_recipe:
						if is_paused:
							state_str = "Waiting for Materials"
						else:
							state_str = "Producing Goods"
					else:
						state_str = "Idle at Workbench"
				_:
					state_str = npc.worker_state.capitalize()
	else:
		match npc.current_state:
			0: # State.IDLE_HOME
				state_str = "Idle"
			1: # State.SEARCH_CHOOSE
				if target_item != "":
					state_str = "Searching for %s" % item_name
				else:
					state_str = "Searching"
			2: # State.TRAVEL
				if npc.return_home_requested:
					state_str = "Returning Home"
				elif target_item != "" and shop_info != "":
					state_str = "Traveling to buy %s at %s" % [item_name, shop_info]
				else:
					state_str = "Traveling"
			3: # State.TRANSACT
				if target_item != "" and shop_info != "":
					state_str = "Buying %s at %s" % [item_name, shop_info]
				else:
					state_str = "Buying"
				
	npc.action_label.text = "%s\n(%s)" % [npc.npc_name, state_str]

static func spawn_debug_emote(npc: CharacterBody2D, text: String, color: Color) -> void:
	var show_emotes = true
	if npc._economy_manager:
		show_emotes = npc._economy_manager.show_debug_emotes
	if not show_emotes:
		return
		
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.custom_minimum_size = Vector2(100, 20)
	label.position = Vector2(-50, -45)
	label.z_index = 15
	npc.add_child(label)
	
	var tween = npc.create_tween()
	tween.tween_property(label, "position:y", -75.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 3.0)
	tween.tween_callback(label.queue_free)

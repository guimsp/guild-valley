extends RefCounted

func update_career_tabs(hud: GameHUD, ledger_panel: ScrollContainer, modifier_panel: ScrollContainer, employee_panel: ScrollContainer) -> void:
	if not hud.career_tab_container:
		return
		
	var char_title = hud.get_node_or_null("Control/Control_Windows/CharacterScreen_Window/VBox/Header/Title") as Label
	if char_title and GameState:
		char_title.text = "%s's Careers & Milestones (F1)" % GameState.player_name
		
	var careers: Array[String] = ["patreon", "craftsman", "tailor", "scholar"]
	
	for i in range(careers.size()):
		var career: String = careers[i]
		var panel: Control = hud.career_tab_container.get_child(i) as Control
		if panel and panel.has_method("update_panel"):
			panel.call("update_panel")
		var lvl: int = GameState.career_levels.get(career, 1)
		hud.career_tab_container.set_tab_title(i, "%s (Lv. %d)" % [career.capitalize(), lvl])
		
	hud.career_tab_container.set_tab_title(careers.size(), "Wealth Ledger")
	hud.career_tab_container.set_tab_title(careers.size() + 1, "Global Modifiers")
	hud.career_tab_container.set_tab_title(careers.size() + 2, "Employees Status")
	
	if ledger_panel:
		_populate_wealth_ledger_tab(hud, ledger_panel)
	if modifier_panel:
		_populate_global_modifiers_tab(hud, modifier_panel)
	if employee_panel:
		_populate_employees_status_tab(hud, employee_panel)

func _populate_wealth_ledger_tab(hud: GameHUD, ledger_panel: ScrollContainer) -> void:
	var vbox = ledger_panel.get_node_or_null("VBox") as VBoxContainer
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 6)
		ledger_panel.add_child(vbox)
		
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
		
	# Header Row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)
	
	var h_time = Label.new()
	h_time.text = "Time"
	h_time.custom_minimum_size = Vector2(140, 0)
	h_time.add_theme_font_size_override("font_size", 10)
	h_time.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(h_time)
	
	var h_reason = Label.new()
	h_reason.text = "Transaction Reason"
	h_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_reason.add_theme_font_size_override("font_size", 10)
	h_reason.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(h_reason)
	
	var h_amount = Label.new()
	h_amount.text = "Amount"
	h_amount.custom_minimum_size = Vector2(80, 0)
	h_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_amount.add_theme_font_size_override("font_size", 10)
	h_amount.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(h_amount)
	
	var h_balance = Label.new()
	h_balance.text = "New Gold"
	h_balance.custom_minimum_size = Vector2(80, 0)
	h_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_balance.add_theme_font_size_override("font_size", 10)
	h_balance.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(h_balance)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	if GameState.wealth_ledger.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No wealth transactions recorded yet."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(empty_lbl)
	else:
		var entries = GameState.wealth_ledger.duplicate()
		entries.reverse()
		
		for entry in entries:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			vbox.add_child(row)
			
			var t_lbl = Label.new()
			t_lbl.text = entry["timestamp"]
			t_lbl.custom_minimum_size = Vector2(140, 0)
			t_lbl.add_theme_font_size_override("font_size", 10)
			t_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			row.add_child(t_lbl)
			
			var r_lbl = Label.new()
			var detail_text: String = entry["detail"]
			if detail_text != "":
				r_lbl.text = "%s (%s)" % [entry["reason"], detail_text]
			else:
				r_lbl.text = entry["reason"]
			r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			r_lbl.add_theme_font_size_override("font_size", 10)
			r_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
			row.add_child(r_lbl)
			
			var a_lbl = Label.new()
			var amt: int = entry["amount"]
			if amt > 0:
				a_lbl.text = "+%d G" % amt
				a_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			else:
				a_lbl.text = "%d G" % amt
				a_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			a_lbl.custom_minimum_size = Vector2(80, 0)
			a_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			a_lbl.add_theme_font_size_override("font_size", 10)
			row.add_child(a_lbl)
			
			var b_lbl = Label.new()
			b_lbl.text = "%d G" % entry["new_total"]
			b_lbl.custom_minimum_size = Vector2(80, 0)
			b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			b_lbl.add_theme_font_size_override("font_size", 10)
			b_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
			row.add_child(b_lbl)

func _populate_global_modifiers_tab(hud: GameHUD, scroll: ScrollContainer) -> void:
	var vbox = scroll.get_node_or_null("VBox") as VBoxContainer
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 10)
		scroll.add_child(vbox)
		
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
		
	var player = hud.get_tree().get_first_node_in_group("Player")
	var current_province: String = "Unknown Province"
	var nearest_settlement: Node2D = null
	if player and is_instance_valid(player):
		current_province = GameState.get_province_of_node(player)
		nearest_settlement = GameState.get_nearest_settlement(player)
		
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 14)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content_vbox)

	var gp = hud.get_node_or_null("/root/GlobalProfile")
	_render_modifier_section(content_vbox, "Global Modifiers (Map-Wide)", gp.global_modifiers if gp else [], "No global event modifiers are currently active.")
	
	var pmd = hud.get_node_or_null("/root/ProvinceMasterData")
	var prov_mods: Array = []
	if pmd and current_province != "Unknown Province" and current_province != "":
		prov_mods = pmd.province_modifiers.get(current_province, [])
	var prov_section_title: String = "Province Modifiers (%s)" % current_province if current_province != "Unknown Province" else "Province Modifiers"
	_render_modifier_section(content_vbox, prov_section_title, prov_mods, "No provincial laws or regional events are active in this province.")
	
	var sett_mods: Array = []
	var show_settlement: bool = false
	var sett_title: String = "Local Settlement Modifiers"
	if is_instance_valid(nearest_settlement):
		var dist: float = 0.0
		if player:
			dist = player.global_position.distance_to(nearest_settlement.global_position)
		var radius = nearest_settlement.get("radius_of_influence")
		if radius == null:
			radius = 800.0
		if dist <= radius:
			show_settlement = true
			var s_name = nearest_settlement.get("city_name")
			if s_name == null or str(s_name) == "":
				s_name = nearest_settlement.name
			sett_title = "Local Modifiers (%s - within %.0fpx)" % [s_name, radius]
			if "modifiers" in nearest_settlement and nearest_settlement.modifiers is Dictionary:
				for k in nearest_settlement.modifiers:
					sett_mods.append({
						"key": k,
						"value": nearest_settlement.modifiers[k],
						"source": "Local Infrastructure"
					})
	if show_settlement:
		_render_modifier_section(content_vbox, sett_title, sett_mods, "No civic improvements or local bonuses are currently active in this settlement area.")
	else:
		var section_panel = _create_section_panel(sett_title)
		content_vbox.add_child(section_panel)
		var inner_vbox = section_panel.get_child(0) as VBoxContainer
		var empty_lbl = Label.new()
		empty_lbl.text = "You are currently outside any settlement's radius of influence."
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		inner_vbox.add_child(empty_lbl)

func _create_section_panel(title_text: String) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.6)
	style.border_color = Color(0.24, 0.52, 0.85, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	return panel

func _render_modifier_section(parent: Control, title_text: String, modifiers: Array, empty_text: String) -> void:
	var section_panel = _create_section_panel(title_text)
	parent.add_child(section_panel)
	var vbox = section_panel.get_child(0) as VBoxContainer
	
	if modifiers.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = empty_text
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		vbox.add_child(empty_lbl)
		return
		
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)
	
	var h_key = Label.new()
	h_key.text = "Attribute"
	h_key.add_theme_font_size_override("font_size", 9)
	h_key.modulate = Color(0.6, 0.6, 0.6)
	grid.add_child(h_key)
	
	var h_val = Label.new()
	h_val.text = "Modifier"
	h_val.add_theme_font_size_override("font_size", 9)
	h_val.modulate = Color(0.6, 0.6, 0.6)
	grid.add_child(h_val)
	
	var h_src = Label.new()
	h_src.text = "Source"
	h_src.add_theme_font_size_override("font_size", 9)
	h_src.modulate = Color(0.6, 0.6, 0.6)
	grid.add_child(h_src)
	
	for mod in modifiers:
		var key: String = mod.get("key", "")
		var val: float = mod.get("value", 0.0)
		var source: String = mod.get("source", "Unknown")
		
		var key_lbl = Label.new()
		key_lbl.text = key.replace("_", " ").capitalize()
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.modulate = Color(0.9, 0.9, 0.95)
		grid.add_child(key_lbl)
		
		var val_lbl = Label.new()
		var is_time: bool = key.ends_with("_time") or key.ends_with("_duration")
		var sign_str: String = "+" if val >= 0 else ""
		
		if is_time:
			val_lbl.text = "%s%d%% duration" % [sign_str, int(val * 100)]
			if val <= 0:
				val_lbl.modulate = Color(0.3, 0.9, 0.3)
			else:
				val_lbl.modulate = Color(0.9, 0.3, 0.3)
		else:
			val_lbl.text = "%s%d%%" % [sign_str, int(val * 100)]
			if val >= 0:
				val_lbl.modulate = Color(0.3, 0.9, 0.3)
			else:
				val_lbl.modulate = Color(0.9, 0.3, 0.3)
		val_lbl.add_theme_font_size_override("font_size", 10)
		grid.add_child(val_lbl)
		
		var src_lbl = Label.new()
		src_lbl.text = source
		src_lbl.add_theme_font_size_override("font_size", 10)
		src_lbl.modulate = Color(0.8, 0.7, 0.5)
		grid.add_child(src_lbl)

func _populate_employees_status_tab(hud: GameHUD, scroll: ScrollContainer) -> void:
	var vbox = scroll.get_node_or_null("VBox") as VBoxContainer
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 12)
		scroll.add_child(vbox)
		
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
		
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)
	
	var list_vbox = VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 14)
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(list_vbox)
	
	var all_hired: Array = []
	for b in hud.get_tree().get_nodes_in_group("production_buildings"):
		if is_instance_valid(b) and "hired_employees" in b:
			var is_player_building: bool = false
			if "ownership_type" in b:
				if b.ownership_type == "Player" or b.ownership_type == "Rented":
					is_player_building = true
			if is_player_building:
				for emp in b.hired_employees:
					var npc = emp.get("npc_ref") as Node
					if is_instance_valid(npc):
						all_hired.append({
							"emp_dict": emp,
							"npc": npc,
							"building": b
						})
						
	if all_hired.is_empty():
		var empty_panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.14, 0.14, 0.18, 0.4)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 20
		style.content_margin_bottom = 20
		empty_panel.add_theme_stylebox_override("panel", style)
		list_vbox.add_child(empty_panel)
		
		var empty_lbl = Label.new()
		empty_lbl.text = "You have no active employees hired at your workshops.\nVisit your production buildings to recruit candidates."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		empty_panel.add_child(empty_lbl)
		return
		
	for item in all_hired:
		var emp_dict: Dictionary = item["emp_dict"]
		var npc: Node = item["npc"]
		var building: Node = item["building"]
		
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.14, 0.15, 0.20, 0.8)
		style.border_color = Color(0.24, 0.52, 0.85, 0.2)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", style)
		list_vbox.add_child(panel)
		
		var main_vbox = VBoxContainer.new()
		main_vbox.add_theme_constant_override("separation", 6)
		panel.add_child(main_vbox)
		
		var header_hbox = HBoxContainer.new()
		header_hbox.add_theme_constant_override("separation", 10)
		main_vbox.add_child(header_hbox)
		
		var name_lbl = Label.new()
		name_lbl.text = npc.get("npc_name") if npc.get("npc_name") != null else npc.name
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		header_hbox.add_child(name_lbl)
		
		var career_lbl = Label.new()
		var display_career: String = String(npc.get("career")).capitalize()
		var max_lvl: int = npc.get("skills_data").get(npc.get("career"), {}).get("level", 1) if npc.get("skills_data") != null else 1
		career_lbl.text = "Lvl %d %s" % [max_lvl, display_career]
		career_lbl.add_theme_font_size_override("font_size", 10)
		career_lbl.modulate = Color(0.24, 0.6, 0.86)
		header_hbox.add_child(career_lbl)
		
		var building_lbl = Label.new()
		var b_name: String = building.get("custom_name") if building.get("custom_name") != null and building.get("custom_name") != "" else building.name
		if building.get("market_name") != null and b_name == building.name:
			b_name = building.get("market_name")
		var at_idx: int = b_name.find("@")
		if at_idx != -1:
			b_name = b_name.substr(0, at_idx)
		b_name = b_name.strip_edges()
		building_lbl.text = "@ %s" % b_name
		building_lbl.add_theme_font_size_override("font_size", 10)
		building_lbl.modulate = Color(0.5, 0.75, 1.0)
		building_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		building_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header_hbox.add_child(building_lbl)
		
		var sep = HSeparator.new()
		main_vbox.add_child(sep)
		
		var status_hbox = HBoxContainer.new()
		status_hbox.add_theme_constant_override("separation", 20)
		main_vbox.add_child(status_hbox)
		
		var task_text: String = "Idle"
		if emp_dict.get("active_recipe_path") != "":
			var recipe = load(emp_dict["active_recipe_path"])
			if recipe and recipe.get("output_item"):
				task_text = "Crafting: %s" % recipe.output_item.name
				var total_t: float = emp_dict.get("craft_total_time", 0.0)
				var cur_t: float = emp_dict.get("craft_timer", 0.0)
				if total_t > 0.0:
					task_text += " (%.1fs / %.1fs)" % [cur_t, total_t]
		elif emp_dict.get("active_gathering_node_path") != "" and emp_dict.get("active_gathering_node_path") != null:
			task_text = "Gathering Resources"
		elif emp_dict.get("active_commercial_route") != null:
			task_text = "Commercial Route Delivery"
		if emp_dict.get("is_paused") == true:
			task_text += " (Paused / short of inputs)"
			
		var status_lbl = Label.new()
		status_lbl.text = "Activity: %s" % task_text
		status_lbl.add_theme_font_size_override("font_size", 10)
		status_lbl.modulate = Color(0.8, 0.8, 0.8)
		status_hbox.add_child(status_lbl)
		
		var wage_lbl = Label.new()
		var daily_w: int = npc.get("character_resource").daily_wage if npc.get("character_resource") != null else int(npc.get("salary"))
		wage_lbl.text = "Wage: %d Gold/day" % daily_w
		wage_lbl.add_theme_font_size_override("font_size", 10)
		wage_lbl.modulate = Color(0.9, 0.85, 0.5)
		wage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_hbox.add_child(wage_lbl)
		
		var stats_panel = PanelContainer.new()
		var sp_style = StyleBoxFlat.new()
		sp_style.bg_color = Color(0.1, 0.1, 0.13, 0.4)
		sp_style.set_corner_radius_all(4)
		sp_style.content_margin_left = 8
		sp_style.content_margin_right = 8
		sp_style.content_margin_top = 6
		sp_style.content_margin_bottom = 6
		stats_panel.add_theme_stylebox_override("panel", sp_style)
		main_vbox.add_child(stats_panel)
		
		var stats_grid = GridContainer.new()
		stats_grid.columns = 2
		stats_grid.add_theme_constant_override("h_separation", 24)
		stats_grid.add_theme_constant_override("v_separation", 6)
		stats_panel.add_child(stats_grid)
		
		var char_speed_base: float = npc.get("character_resource").walking_speed if npc.get("character_resource") != null else 4.0
		var final_speed: float = npc.get("speed")
		var speed_trait_bonus: float = 0.0
		if npc.get("character_resource") != null:
			for trait_id in npc.get("character_resource").active_mods:
				if trait_id.begins_with("Fleet-Footed_Lvl"):
					var lvl_mod: int = int(trait_id.replace("Fleet-Footed_Lvl", ""))
					if lvl_mod == 1: speed_trait_bonus = 0.05
					elif lvl_mod == 2: speed_trait_bonus = 0.10
					elif lvl_mod == 3: speed_trait_bonus = 0.15
					break
		var speed_eq_bonus: float = 0.0
		var eq = npc.get_node_or_null("EquipmentComponent")
		if eq:
			speed_eq_bonus = eq.call("get_total_speed_bonus")
		var speed_macro_factor: float = 1.0
		if GameState:
			speed_macro_factor = GameState.apply_macro_modifier(npc, "movement_speed", 1.0)
		var speed_macro_bonus: float = speed_macro_factor - 1.0
		
		var speed_text_lbl = Label.new()
		speed_text_lbl.text = "Movement Speed:"
		speed_text_lbl.add_theme_font_size_override("font_size", 10)
		speed_text_lbl.modulate = Color(0.7, 0.7, 0.7)
		stats_grid.add_child(speed_text_lbl)
		
		var speed_breakdown_lbl = Label.new()
		speed_breakdown_lbl.text = "%d (Base: %d | Traits: %+d%% | Macro Modifiers: %+d%% | Gear: %+d%%)" % [
			int(final_speed),
			int(char_speed_base * 20.0),
			int(speed_trait_bonus * 100),
			int(speed_macro_bonus * 100),
			int(speed_eq_bonus * 100)
		]
		speed_breakdown_lbl.add_theme_font_size_override("font_size", 10)
		speed_breakdown_lbl.modulate = Color(0.9, 0.9, 0.9)
		stats_grid.add_child(speed_breakdown_lbl)
		
		var final_prod: float = npc.get("productivity")
		var base_prod_factor: float = 1.0 + (max_lvl * 0.02)
		var prod_trait_bonus: float = 0.0
		if npc.get("character_resource") != null:
			for trait_id in npc.get("character_resource").active_mods:
				if trait_id.begins_with("Diligent Master_Lvl"):
					var lvl_mod: int = int(trait_id.replace("Diligent Master_Lvl", ""))
					if lvl_mod == 1: prod_trait_bonus = 0.03
					elif lvl_mod == 2: prod_trait_bonus = 0.06
					elif lvl_mod == 3: prod_trait_bonus = 0.10
					break
		var prod_macro_factor: float = 1.0
		if GameState:
			prod_macro_factor = GameState.apply_macro_modifier(npc, "productivity", 1.0)
		var prod_macro_bonus: float = prod_macro_factor - 1.0
		
		var prod_text_lbl = Label.new()
		prod_text_lbl.text = "Productivity Multiplier:"
		prod_text_lbl.add_theme_font_size_override("font_size", 10)
		prod_text_lbl.modulate = Color(0.7, 0.7, 0.7)
		stats_grid.add_child(prod_text_lbl)
		
		var prod_breakdown_lbl = Label.new()
		prod_breakdown_lbl.text = "%d%% (Base Lvl: %d%% | Traits: %+d%% | Macro Modifiers: %+d%%)" % [
			int(final_prod * 100.0),
			int(base_prod_factor * 100.0),
			int(prod_trait_bonus * 100),
			int(prod_macro_bonus * 100)
		]
		prod_breakdown_lbl.add_theme_font_size_override("font_size", 10)
		prod_breakdown_lbl.modulate = Color(0.9, 0.9, 0.9)
		stats_grid.add_child(prod_breakdown_lbl)
		
		var traits_eq_hbox = HBoxContainer.new()
		traits_eq_hbox.add_theme_constant_override("separation", 20)
		main_vbox.add_child(traits_eq_hbox)
		
		var traits_vbox = VBoxContainer.new()
		traits_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		traits_eq_hbox.add_child(traits_vbox)
		
		var t_title = Label.new()
		t_title.text = "Active Traits:"
		t_title.add_theme_font_size_override("font_size", 9)
		t_title.modulate = Color(0.5, 0.5, 0.5)
		traits_vbox.add_child(t_title)
		
		var traits_list_hbox = HBoxContainer.new()
		traits_list_hbox.add_theme_constant_override("separation", 6)
		traits_vbox.add_child(traits_list_hbox)
		
		if npc.get("character_resource") != null and not npc.get("character_resource").active_mods.is_empty():
			for trait_id in npc.get("character_resource").active_mods:
				var tr_panel = PanelContainer.new()
				var tr_style = StyleBoxFlat.new()
				tr_style.bg_color = Color(0.18, 0.14, 0.05, 0.8)
				tr_style.border_color = Color(0.9, 0.75, 0.15, 0.8)
				tr_style.set_border_width_all(1)
				tr_style.set_corner_radius_all(4)
				tr_style.content_margin_left = 6
				tr_style.content_margin_right = 6
				tr_style.content_margin_top = 2
				tr_style.content_margin_bottom = 2
				tr_panel.add_theme_stylebox_override("panel", tr_style)
				
				var tr_lbl = Label.new()
				tr_lbl.text = trait_id.replace("_", " ")
				tr_lbl.add_theme_font_size_override("font_size", 9)
				tr_lbl.modulate = Color(1.0, 0.9, 0.5)
				tr_panel.add_child(tr_lbl)
				traits_list_hbox.add_child(tr_panel)
		else:
			var no_tr_lbl = Label.new()
			no_tr_lbl.text = "No active traits."
			no_tr_lbl.add_theme_font_size_override("font_size", 9)
			no_tr_lbl.modulate = Color(0.5, 0.5, 0.5)
			traits_list_hbox.add_child(no_tr_lbl)
			
		var gear_vbox = VBoxContainer.new()
		gear_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		traits_eq_hbox.add_child(gear_vbox)
		
		var g_title = Label.new()
		g_title.text = "Equipped Gear:"
		g_title.add_theme_font_size_override("font_size", 9)
		g_title.modulate = Color(0.5, 0.5, 0.5)
		gear_vbox.add_child(g_title)
		
		var gear_lbl = Label.new()
		var gear_text: String = "None"
		if eq:
			var items_list: Array[String] = []
			for slot_name in ["head", "body", "gloves", "weapon", "tool", "bag", "necklace", "ring", "transportation"]:
				var g_item = eq.call("get_equipped_item", slot_name) as ItemData
				if g_item:
					var item_info: String = g_item.name
					if g_item.is_tool:
						item_info += " (Dur: %d/%d)" % [g_item.durability, g_item.max_durability]
					items_list.append(item_info)
			if not items_list.is_empty():
				gear_text = ", ".join(items_list)
		gear_lbl.text = gear_text
		gear_lbl.add_theme_font_size_override("font_size", 9)
		gear_lbl.modulate = Color(0.8, 0.8, 0.85)
		gear_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		gear_vbox.add_child(gear_lbl)

	if hud._active_player:
		hud._active_player.freeze()

func toggle_wealth_ledger_tab(hud: GameHUD) -> void:
	if hud.character_window.visible and hud.career_tab_container.current_tab == 4:
		hud.character_window.hide()
		hud.windows_container.hide()
		if hud._active_player:
			hud._active_player.unfreeze()
	else:
		if hud.windows_container:
			hud.windows_container.show()
			for child in hud.windows_container.get_children():
				(child as Control).hide()
		hud.character_window.show()
		hud.update_career_tabs()
		hud.career_tab_container.current_tab = 4
		if hud._active_player:
			hud._active_player.freeze()

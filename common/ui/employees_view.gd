extends Control

var _building: Node2D = null
var _coordinator: Control = null
var _updating_ui: bool = false
var _transfer_mode_emp_idx: int = -1
var _last_pressed_hire_idx: int = -1
var _last_focused_meta: Dictionary = {}

# UI Elements
@onready var candidates_grid: GridContainer = $Columns/LeftColumn/CandidatesScroll/CandidatesGrid
@onready var workforce_list: VBoxContainer = $Columns/RightColumn/WorkforceScroll/WorkforceList

func setup(building: Node2D, coordinator: Control) -> void:
	_building = building
	_coordinator = coordinator
	_transfer_mode_emp_idx = -1

func update_view() -> void:
	if not _building:
		return
		
	_updating_ui = true
	_save_current_focus()
	
	# Clear containers
	for child in candidates_grid.get_children():
		child.queue_free()
	for child in workforce_list.get_children():
		child.queue_free()
		
	_populate_candidates()
	_populate_workforce()
	
	_updating_ui = false
	_restore_saved_focus()

# --- CANDIDATES ---
func _populate_candidates() -> void:
	if not _building.get("hireable_candidates"):
		return
		
	if _building.has_method("ensure_spouse_candidate"):
		_building.ensure_spouse_candidate()
		
	if _building.hireable_candidates.size() == 0:
		_building._populate_candidates()
		
	for i in range(_building.hireable_candidates.size()):
		var cand = _building.hireable_candidates[i]
		if not is_instance_valid(cand):
			continue
			
		var cand_name = cand.npc_name if "npc_name" in cand else cand.name
		var cand_salary = cand.salary if "salary" in cand else 15
		var cand_career = cand.career if "career" in cand else "patreon"
		
		var speed_val = cand.speed if "speed" in cand else 50.0
		var prod_val = cand.productivity if "productivity" in cand else 1.0
		var p_lvl = cand.patreon_level if "patreon_level" in cand else 1
		var s_lvl = cand.scholar_level if "scholar_level" in cand else 1
		var c_lvl = cand.craftsman_level if "craftsman_level" in cand else 1
		var t_lvl = cand.tailor_level if "tailor_level" in cand else 1
		var max_lvl = max(p_lvl, max(s_lvl, max(c_lvl, t_lvl)))
		
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(180, 95)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.15, 0.7)
		style.border_color = Color(0.24, 0.52, 0.85, 0.3)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		
		var hover_style = style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.24, 0.52, 0.85, 0.8)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)
		
		var header_hbox = HBoxContainer.new()
		vbox.add_child(header_hbox)
		
		var name_lbl = Label.new()
		name_lbl.text = cand_name
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(name_lbl)
		
		var career_lbl = Label.new()
		career_lbl.text = cand_career.capitalize()
		career_lbl.add_theme_font_size_override("font_size", 9)
		career_lbl.modulate = Color(0.5, 0.75, 1.0)
		header_hbox.add_child(career_lbl)
		
		var stats_lbl = Label.new()
		stats_lbl.text = "Spd: %d | Prod: %d%% | %d G/d" % [int(speed_val), int(prod_val * 100.0), cand_salary]
		stats_lbl.add_theme_font_size_override("font_size", 9)
		stats_lbl.modulate = Color(0.8, 0.8, 0.85)
		vbox.add_child(stats_lbl)
		
		var levels_lbl = Label.new()
		levels_lbl.text = "P:%d  S:%d  C:%d  T:%d" % [p_lvl, s_lvl, c_lvl, t_lvl]
		levels_lbl.add_theme_font_size_override("font_size", 9)
		levels_lbl.modulate = Color(0.6, 0.7, 0.8)
		vbox.add_child(levels_lbl)
		
		var bottom_hbox = HBoxContainer.new()
		vbox.add_child(bottom_hbox)
		
		var traits_lbl = Label.new()
		traits_lbl.add_theme_font_size_override("font_size", 8)
		traits_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		traits_lbl.modulate = Color(1.0, 0.85, 0.4)
		if max_lvl >= 8:
			traits_lbl.text = "★ Double Output, Fast Craft"
		elif max_lvl >= 5:
			traits_lbl.text = "★ Double Output"
		bottom_hbox.add_child(traits_lbl)
		
		var hire_btn = Button.new()
		hire_btn.text = "Hire"
		hire_btn.add_theme_font_size_override("font_size", 10)
		hire_btn.custom_minimum_size = Vector2(45, 18)
		hire_btn.set_meta("type", "candidate_hire")
		hire_btn.set_meta("index", i)
		
		if _building.hired_employees.size() >= _building.max_employees:
			hire_btn.disabled = true
			hire_btn.tooltip_text = "Full"
			
		var idx = i
		hire_btn.pressed.connect(func(): _hire_candidate(idx))
		_coordinator._setup_button_hover(hire_btn)
		bottom_hbox.add_child(hire_btn)
		
		panel.mouse_entered.connect(func():
			panel.add_theme_stylebox_override("panel", hover_style)
		)
		panel.mouse_exited.connect(func():
			panel.add_theme_stylebox_override("panel", style)
		)
		candidates_grid.add_child(panel)

func _hire_candidate(idx: int) -> void:
	if _building.hired_employees.size() < _building.max_employees:
		_last_pressed_hire_idx = idx
		var cand = _building.hireable_candidates[idx]
		_building.hireable_candidates.remove_at(idx)
		
		if is_instance_valid(cand):
			cand.go_to_workshop(_building)
			
			_building.hired_employees.append({
				"npc_ref": cand,
				"name": cand.npc_name,
				"salary": cand.salary,
				"career": cand.career,
				"levels": {
					"patreon": cand.patreon_level,
					"scholar": cand.scholar_level,
					"craftsman": cand.craftsman_level,
					"tailor": cand.tailor_level
				},
				"active_recipe_path": "",
				"craft_timer": 0.0,
				"craft_total_time": 0.0,
				"is_repeating": true,
				"auto_gather_on_shortage": false,
				"is_paused": false
			})
		update_view()
		_restore_employees_focus()

# --- WORKFORCE PROFILES ---
func _populate_workforce() -> void:
	if not _building.get("hired_employees") or _building.hired_employees.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No workers currently hired."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		workforce_list.add_child(empty_lbl)
		return
		
	for i in range(_building.hired_employees.size()):
		var emp = _building.hired_employees[i]
		
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.17, 0.22, 0.9)
		style.set_border_width_all(1)
		style.border_color = Color(0.24, 0.52, 0.85, 0.3)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		panel.add_child(hbox)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		
		var name_lbl = Label.new()
		var name_text = "%s (%s)" % [emp.get("name", "Worker"), emp.get("career", "Patreon").capitalize()]
		var is_route = emp.get("active_commercial_route") != null
		if is_route:
			name_text += " - [On Commercial Route]"
		name_lbl.text = name_text
		name_lbl.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(name_lbl)
		
		# Stats Row
		var cols_hbox = HBoxContainer.new()
		cols_hbox.add_theme_constant_override("separation", 12)
		info_vbox.add_child(cols_hbox)
		
		var npc = emp.get("npc_ref")
		var emp_speed = emp.get("speed", 50.0)
		var emp_prod = emp.get("productivity", 1.0)
		if is_instance_valid(npc):
			emp_speed = npc.speed
			emp_prod = npc.productivity
			
		var speed_lbl = Label.new()
		speed_lbl.text = "Speed: %d" % int(emp_speed)
		speed_lbl.add_theme_font_size_override("font_size", 10)
		speed_lbl.modulate = Color(0.8, 0.8, 0.8)
		cols_hbox.add_child(speed_lbl)
		
		var prod_lbl = Label.new()
		prod_lbl.text = "Prod: %d%%" % int(emp_prod * 100.0)
		prod_lbl.add_theme_font_size_override("font_size", 10)
		prod_lbl.modulate = Color(0.8, 0.8, 0.8)
		cols_hbox.add_child(prod_lbl)
		
		if emp_prod > 1.0:
			var train_indicator = Label.new()
			train_indicator.text = "▲ Training"
			train_indicator.add_theme_font_size_override("font_size", 10)
			train_indicator.modulate = Color(0.2, 0.8, 0.2)
			cols_hbox.add_child(train_indicator)
			
		var sal_lbl = Label.new()
		sal_lbl.text = "Salary: %d G/day" % emp.get("salary", 15)
		sal_lbl.add_theme_font_size_override("font_size", 10)
		sal_lbl.modulate = Color(0.9, 0.8, 0.4)
		cols_hbox.add_child(sal_lbl)
		
		# Career levels
		var levels = emp.get("levels")
		if not levels:
			levels = {"patreon": 1, "scholar": 1, "craftsman": 1, "tailor": 1}
			emp["levels"] = levels
			
		var p_lvl = levels.get("patreon", 1)
		var s_lvl = levels.get("scholar", 1)
		var c_lvl = levels.get("craftsman", 1)
		var t_lvl = levels.get("tailor", 1)
		
		var levels_lbl = Label.new()
		levels_lbl.text = "Patreon: Lvl %d | Scholar: Lvl %d | Craftsman: Lvl %d | Tailor: Lvl %d" % [p_lvl, s_lvl, c_lvl, t_lvl]
		levels_lbl.add_theme_font_size_override("font_size", 10)
		levels_lbl.modulate = Color(0.65, 0.75, 0.9)
		info_vbox.add_child(levels_lbl)
		
		# Traits
		var max_lvl = max(p_lvl, max(s_lvl, max(c_lvl, t_lvl)))
		if max_lvl >= 5:
			var traits_hbox = HBoxContainer.new()
			traits_hbox.add_theme_constant_override("separation", 6)
			info_vbox.add_child(traits_hbox)
			
			var trait1 = PanelContainer.new()
			var style_t1 = StyleBoxFlat.new()
			style_t1.bg_color = Color(0.18, 0.14, 0.05, 0.8)
			style_t1.border_color = Color(0.9, 0.75, 0.15, 1.0)
			style_t1.set_border_width_all(1)
			style_t1.set_corner_radius_all(4)
			style_t1.content_margin_left = 6
			style_t1.content_margin_right = 6
			style_t1.content_margin_top = 2
			style_t1.content_margin_bottom = 2
			trait1.add_theme_stylebox_override("panel", style_t1)
			
			var lbl_t1 = Label.new()
			if max_lvl >= 8:
				lbl_t1.text = "Bountiful Harvest (35% Double Output)"
			else:
				lbl_t1.text = "Bountiful Harvest (20% Double Output)"
			lbl_t1.add_theme_font_size_override("font_size", 9)
			lbl_t1.modulate = Color(1.0, 0.9, 0.5)
			trait1.add_child(lbl_t1)
			traits_hbox.add_child(trait1)
			
			if max_lvl >= 8:
				var trait2 = PanelContainer.new()
				var style_t2 = StyleBoxFlat.new()
				style_t2.bg_color = Color(0.18, 0.14, 0.05, 0.8)
				style_t2.border_color = Color(0.9, 0.75, 0.15, 1.0)
				style_t2.set_border_width_all(1)
				style_t2.set_corner_radius_all(4)
				style_t2.content_margin_left = 6
				style_t2.content_margin_right = 6
				style_t2.content_margin_top = 2
				style_t2.content_margin_bottom = 2
				trait2.add_theme_stylebox_override("panel", style_t2)
				
				var lbl_t2 = Label.new()
				lbl_t2.text = "Artisan's Efficiency (Luxury -15% craft time)"
				lbl_t2.add_theme_font_size_override("font_size", 9)
				lbl_t2.modulate = Color(1.0, 0.9, 0.5)
				trait2.add_child(lbl_t2)
				traits_hbox.add_child(trait2)

		workforce_list.add_child(panel)

func _restore_employees_focus() -> void:
	# Wait a frame or two for reconstruction
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_inside_tree() or not visible:
		return
		
	# Find all hire buttons in candidates grid
	var hire_buttons: Array[Button] = []
	for card in candidates_grid.get_children():
		if card is PanelContainer:
			var hire_btn = _find_button_in_hierarchy(card, "Hire")
			if hire_btn:
				hire_buttons.append(hire_btn)
				
	# If we have buttons, try to focus the one at _last_pressed_hire_idx (or clamp to valid range)
	if hire_buttons.size() > 0:
		var target_idx = clamp(_last_pressed_hire_idx, 0, hire_buttons.size() - 1)
		var btn = hire_buttons[target_idx]
		if btn and is_instance_valid(btn) and not btn.disabled and btn.focus_mode == Control.FOCUS_ALL:
			btn.grab_focus()
			_last_pressed_hire_idx = -1
			return
			
	# Fallback to the close button
	if _coordinator and _coordinator.bottom_close_button:
		_coordinator.bottom_close_button.grab_focus()
	_last_pressed_hire_idx = -1

func _find_button_in_hierarchy(node: Node, text_to_match: String = "") -> Button:
	if node is Button:
		if text_to_match == "" or node.text == text_to_match:
			return node
	for child in node.get_children():
		var found = _find_button_in_hierarchy(child, text_to_match)
		if found:
			return found
	return null

func _save_current_focus() -> void:
	_last_focused_meta.clear()
	var focused = get_viewport().gui_get_focus_owner()
	if focused and is_instance_valid(focused) and is_ancestor_of(focused):
		if focused.has_meta("type"):
			_last_focused_meta["type"] = focused.get_meta("type")
		if focused.has_meta("index"):
			_last_focused_meta["index"] = focused.get_meta("index")

func _restore_saved_focus() -> void:
	if _last_focused_meta.is_empty():
		return
		
	# Wait a frame or two for layout/children reconstruction to finish
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_inside_tree() or not visible:
		return
		
	var target_btn: Control = null
	var all_focusables = _find_all_focusable_controls(self)
	
	var type = _last_focused_meta.get("type", "")
	var index = _last_focused_meta.get("index", -1)
	
	if type != "":
		for ctrl in all_focusables:
			if ctrl.get_meta("type", "") == type:
				if index != -1 and ctrl.get_meta("index", -1) == index:
					target_btn = ctrl
					break
					
		if not target_btn:
			for ctrl in all_focusables:
				if ctrl.get_meta("type", "") == type:
					target_btn = ctrl
					break
					
	if target_btn and is_instance_valid(target_btn) and target_btn.is_inside_tree() and not target_btn.get("disabled") == true:
		target_btn.grab_focus()
	else:
		if _coordinator and _coordinator.bottom_close_button:
			_coordinator.bottom_close_button.grab_focus()
			
	_last_focused_meta.clear()

func _find_all_focusable_controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Control and node.visible and node.focus_mode == Control.FOCUS_ALL:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_focusable_controls(child))
	return result

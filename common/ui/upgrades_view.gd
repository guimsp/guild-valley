extends Control

var _building: Node2D = null
var _coordinator: Control = null
var _mode: String = "leveling" # "leveling" or "improvements"
var _last_pressed_imp_id: String = ""
var _last_focused_meta: Dictionary = {}

# UI Containers
@onready var leveling_left: VBoxContainer = $Columns/LeftColumn/LevelingLeft
@onready var leveling_right: VBoxContainer = $Columns/RightColumn/LevelingRight
@onready var improvements_left: VBoxContainer = $Columns/LeftColumn/ImprovementsLeft
@onready var improvements_right: VBoxContainer = $Columns/RightColumn/ImprovementsRight

# Leveling Nodes
@onready var current_level_label: Label = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/CurrentLevelLabel
@onready var upgrading_label: Label = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/UpgradingLabel
@onready var renovation_pbar: ProgressBar = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/RenovationPbar
@onready var renovation_label: Label = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/RenovationLabel
@onready var requirements_vbox: VBoxContainer = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/RequirementsVBox
@onready var gold_cost_label: Label = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/RequirementsVBox/GoldCostLabel
@onready var career_req_label: Label = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/RequirementsVBox/CareerReqLabel
@onready var downtime_label: Label = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/RequirementsVBox/DowntimeLabel
@onready var max_level_label: Label = $Columns/LeftColumn/LevelingLeft/InfoPanel/VBox/MaxLevelLabel

@onready var begin_upgrade_btn: Button = $Columns/RightColumn/LevelingRight/RunPanel/VBox/BeginUpgradeButton

# Improvements Nodes
@onready var imp_list_left: VBoxContainer = $Columns/LeftColumn/ImprovementsLeft/Scroll/List
@onready var imp_list_right: VBoxContainer = $Columns/RightColumn/ImprovementsRight/Scroll/List

func setup(building: Node2D, coordinator: Control) -> void:
	_building = building
	_coordinator = coordinator
	
	begin_upgrade_btn.set_meta("type", "begin_upgrade")
	if begin_upgrade_btn.pressed.is_connected(_on_begin_upgrade_pressed):
		begin_upgrade_btn.pressed.disconnect(_on_begin_upgrade_pressed)
	begin_upgrade_btn.pressed.connect(_on_begin_upgrade_pressed)
	_coordinator._setup_button_hover(begin_upgrade_btn)

func update_view(mode: String = "leveling") -> void:
	_mode = mode
	if not _building:
		return
		
	_save_current_focus()
	
	if _mode == "leveling":
		improvements_left.hide()
		improvements_right.hide()
		leveling_left.show()
		leveling_right.show()
		_populate_leveling()
	else:
		leveling_left.hide()
		leveling_right.hide()
		improvements_left.show()
		improvements_right.show()
		_populate_improvements()
		
	_restore_saved_focus()

func _process(_delta: float) -> void:
	if not visible or not _building or _mode != "leveling":
		return
		
	# Update structural upgrade renovation progress
	if _building.is_upgrading:
		upgrading_label.show()
		renovation_pbar.show()
		renovation_label.show()
		requirements_vbox.hide()
		
		var timer = _building.upgrade_timer
		var next_lvl = _building.building_level + 1
		var req = _building.UPGRADE_REQUIREMENTS.get(next_lvl)
		if req:
			var total = req.time
			var pct = ((total - timer) / total) * 100.0
			renovation_pbar.value = pct
			renovation_label.text = "Renovation... %.1fs remaining" % timer
		else:
			renovation_pbar.value = 100.0
			renovation_label.text = "Completing upgrade..."
			
		begin_upgrade_btn.disabled = true
		begin_upgrade_btn.text = "Renovation in Progress..."
	else:
		upgrading_label.hide()
		renovation_pbar.hide()
		renovation_label.hide()

# --- LEVELING LOGIC ---
func _populate_leveling() -> void:
	current_level_label.text = "Current Building Level: Level %d" % _building.building_level
	
	var next_lvl = _building.building_level + 1
	var has_next = _building.UPGRADE_REQUIREMENTS.has(next_lvl)
	
	if _building.is_upgrading:
		# Process will handle active bar
		pass
	else:
		if has_next:
			requirements_vbox.show()
			max_level_label.hide()
			
			var req = _building.UPGRADE_REQUIREMENTS[next_lvl]
			
			# Gold Cost
			var meets_gold = GameState.gold >= req.gold_cost
			gold_cost_label.text = " • Gold Cost: %d G (Current: %d G)" % [req.gold_cost, GameState.gold]
			gold_cost_label.modulate = Color(0.2, 0.8, 0.4) if meets_gold else Color(0.9, 0.3, 0.3)
			
			# Career level
			var career_id = "craftsman"
			if _building.building_data and _building.building_data.career != "":
				career_id = _building.building_data.career
			var p_lvl = GameState.career_levels.get(career_id, 1)
			var meets_lvl = p_lvl >= req.profession_level
			career_req_label.text = " • Player %s Level: %d (Current: %d)" % [career_id.capitalize(), req.profession_level, p_lvl]
			career_req_label.modulate = Color(0.2, 0.8, 0.4) if meets_lvl else Color(0.9, 0.3, 0.3)
			
			# Architectural Blueprint requirement
			var meets_bp = true
			var bp_label = requirements_vbox.get_node_or_null("BlueprintCostLabel")
			if next_lvl >= 3:
				var bp_count = 0
				if GameState.player_inventory:
					bp_count += GameState.player_inventory.get_item_amount("architectural_blueprint")
				var target_b_storage = _building.get("building_storage") if "building_storage" in _building else null
				if not target_b_storage and "inventory" in _building:
					target_b_storage = _building.inventory
				if target_b_storage:
					bp_count += target_b_storage.get_item_amount("architectural_blueprint")
				
				if not bp_label:
					bp_label = Label.new()
					bp_label.name = "BlueprintCostLabel"
					bp_label.add_theme_font_size_override("font_size", 10)
					requirements_vbox.add_child(bp_label)
					requirements_vbox.move_child(bp_label, downtime_label.get_index())
				
				meets_bp = bp_count >= 1
				bp_label.text = " • Architectural Blueprint: 1 (Current: %d)" % bp_count
				bp_label.modulate = Color(0.2, 0.8, 0.4) if meets_bp else Color(0.9, 0.3, 0.3)
				bp_label.show()
			else:
				if bp_label:
					bp_label.hide()
			
			# Downtime
			downtime_label.text = " • Construction Downtime: %d seconds" % int(req.time)
			
			var meets_req = meets_gold and meets_lvl and meets_bp
			begin_upgrade_btn.show()
			begin_upgrade_btn.disabled = not meets_req
			if not meets_req:
				begin_upgrade_btn.text = "Requirements Not Met"
			else:
				begin_upgrade_btn.text = "Begin Renovation"
		else:
			requirements_vbox.hide()
			max_level_label.show()
			max_level_label.text = "Structure is at maximum level (Level %d)." % _building.building_level
			begin_upgrade_btn.hide()

func _on_begin_upgrade_pressed() -> void:
	var next_lvl = _building.building_level + 1
	var has_next = _building.UPGRADE_REQUIREMENTS.has(next_lvl)
	if has_next:
		_building.initiate_level_upgrade()
		update_view("leveling")

# --- IMPROVEMENTS LOGIC ---
func _populate_improvements() -> void:
	for child in imp_list_left.get_children():
		child.queue_free()
	for child in imp_list_right.get_children():
		child.queue_free()
		
	var list_left = ["storage_vault", "deep_shelving", "extra_workbench", "strongbox_vault"]
	var list_right = ["bunkhouse", "iron_reinforcements", "ornate_facade"]
	if _building and _building.has_method("produces_using_only_raw_materials") and _building.produces_using_only_raw_materials():
		list_right.append("auto_gathering")
		
	for id in list_left:
		_draw_improvement_card(id, imp_list_left)
	for id in list_right:
		_draw_improvement_card(id, imp_list_right)

func _draw_improvement_card(id: String, container: VBoxContainer) -> void:
	var def = _building.IMPROVEMENT_DEFINITIONS.get(id)
	if not def:
		return
		
	var cur_lvl = _building.improvements.get(id, 0)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.13, 0.18, 0.8)
	style.set_border_width_all(1)
	style.border_color = Color(0.58, 0.34, 0.75, 0.25)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	var title_hbox = HBoxContainer.new()
	vbox.add_child(title_hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = def.name
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(name_lbl)
	
	var pips_str = ""
	for l in range(def.max_level):
		if l < cur_lvl:
			pips_str += "● "
		else:
			pips_str += "○ "
	var pips_lbl = Label.new()
	pips_lbl.text = pips_str.strip_edges()
	pips_lbl.add_theme_font_size_override("font_size", 10)
	pips_lbl.modulate = Color(0.58, 0.34, 0.75)
	title_hbox.add_child(pips_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = def.description
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.modulate = Color(0.75, 0.75, 0.8)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)
	
	var buy_btn = Button.new()
	buy_btn.focus_mode = Control.FOCUS_ALL
	buy_btn.add_theme_font_size_override("font_size", 9)
	buy_btn.set_meta("type", "purchase_improvement")
	buy_btn.set_meta("imp_id", id)
	_coordinator._setup_button_hover(buy_btn)
	vbox.add_child(buy_btn)
	
	if cur_lvl >= def.max_level:
		buy_btn.disabled = true
		buy_btn.text = "Max Level Reached"
	else:
		buy_btn.text = "Purchase Upgrade (%d G)" % def.cost
		if GameState.gold < def.cost:
			buy_btn.disabled = true
		else:
			buy_btn.pressed.connect(func():
				_last_pressed_imp_id = id
				_building.purchase_improvement(id)
				_populate_improvements()
				_restore_improvement_focus()
			)
			
	container.add_child(panel)

func _restore_improvement_focus() -> void:
	if _last_pressed_imp_id == "":
		return
		
	# Wait a frame or two for layout/children reconstruction to finish
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_inside_tree() or not visible:
		return
		
	var target_btn: Button = null
	var fallback_btn: Button = null
	
	# Gather all buttons from Left and Right columns
	var all_buttons: Array[Button] = []
	for container in [imp_list_left, imp_list_right]:
		for card in container.get_children():
			if card is PanelContainer:
				var vbox = card.get_child(0)
				if vbox:
					for child in vbox.get_children():
						if child is Button:
							all_buttons.append(child)
							
	for btn in all_buttons:
		if btn.get_meta("imp_id", "") == _last_pressed_imp_id:
			if not btn.disabled and btn.focus_mode == Control.FOCUS_ALL:
				target_btn = btn
				break
				
	# If the target button is found and focusable, focus it!
	if target_btn and is_instance_valid(target_btn) and target_btn.is_inside_tree():
		target_btn.grab_focus()
		_last_pressed_imp_id = ""
		return
		
	# Fallback: find the first focusable button in all_buttons
	for btn in all_buttons:
		if btn and is_instance_valid(btn) and not btn.disabled and btn.focus_mode == Control.FOCUS_ALL:
			fallback_btn = btn
			break
			
	if fallback_btn and is_instance_valid(fallback_btn) and fallback_btn.is_inside_tree():
		fallback_btn.grab_focus()
		
	_last_pressed_imp_id = ""

func _save_current_focus() -> void:
	_last_focused_meta.clear()
	var focused = get_viewport().gui_get_focus_owner()
	if focused and is_instance_valid(focused) and is_ancestor_of(focused):
		if focused.has_meta("type"):
			_last_focused_meta["type"] = focused.get_meta("type")
		if focused.has_meta("imp_id"):
			_last_focused_meta["imp_id"] = focused.get_meta("imp_id")

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
	var imp_id = _last_focused_meta.get("imp_id", "")
	
	if type != "":
		for ctrl in all_focusables:
			if ctrl.get_meta("type", "") == type:
				if imp_id != "" and ctrl.get_meta("imp_id", "") == imp_id:
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

extends HBoxContainer

var _main_view: Control = null
var _building: Node2D = null

@onready var queue_list: VBoxContainer = $WorkshopLeft/QueueScroll/QueueList
@onready var b_storage_grid: GridContainer = $WorkshopRight/RightScroll/ScrollContent/StorageGrid
@onready var stall_vbox: VBoxContainer = $WorkshopRight/RightScroll/ScrollContent/StallVBox
@onready var player_inv_list: VBoxContainer = $WorkshopRight/RightScroll/ScrollContent/PlayerInvList
@onready var no_stall_label: Label = $WorkshopRight/RightScroll/ScrollContent/NoStallLabel
@onready var storage_lbl: Label = $WorkshopRight/RightScroll/ScrollContent/StorageLabel
@onready var stall_lbl: Label = $WorkshopRight/RightScroll/ScrollContent/StallLabel
@onready var player_inv_lbl: Label = $WorkshopRight/RightScroll/ScrollContent/PlayerInvLabel

const InventorySlotScene = preload("res://common/ui/inventory_slot.tscn")
const StallSlotRowScene = preload("res://common/ui/stall_slot_row.tscn")

var _progress_bars: Dictionary = {}
var _timer_labels: Dictionary = {}
var _employee_status_labels: Dictionary = {}
var _player_status_lbl: Label = null
var _player_detail_lbl: Label = null

func setup(p_view: Control) -> void:
	_main_view = p_view

func refresh(building: Node2D) -> void:
	_building = building
	_render_workshop_view()

func update_live_progress() -> void:
	if not visible or not _building:
		return
	if is_instance_valid(_player_status_lbl) and is_instance_valid(_player_detail_lbl):
		var p_active_path = _building.get("player_crafting_recipe_path") if _building.get("player_crafting_recipe_path") else ""
		if p_active_path != "":
			var recipe = load(p_active_path)
			if recipe and recipe.get("is_service") == true:
				var active_slots = _building.player_service_slots
				_player_detail_lbl.text = "Status: Busy (Serving: %s)\nContinuous service offering." % ", ".join(active_slots.map(func(t): return "%.1fs" % t)) if active_slots.size() > 0 else "Status: Ready (0/3 slots active)\nContinuous service offering."
	if _building.get("hired_employees") == null:
		return
	for i in range(_building.hired_employees.size()):
		var emp = _building.hired_employees[i]
		var pbar = _progress_bars.get(i)
		var label = _timer_labels.get(i)
		if not pbar or not label or not is_instance_valid(pbar) or not is_instance_valid(label):
			continue
		var route = emp.get("active_commercial_route")
		if route != null:
			var npc = emp.get("npc_ref")
			var state_str = "On Commercial Route"
			if is_instance_valid(npc):
				var w_state = npc.get("worker_state")
				var cargo = npc.commercial_route_cargo_item_id.capitalize() if npc.commercial_route_cargo_item_id != "" else "Cargo"
				match w_state:
					"commercial_route_loading": state_str = "Loading: %s (%d/%d)" % [cargo, npc.commercial_route_cargo_amount, route.target_amount]
					"commercial_route_transit": state_str = "Logistics: Waypoint %d/%d (Carrying %d %s)" % [npc.commercial_route_current_waypoint_index + 1, route.market_waypoints.size(), npc.commercial_route_cargo_amount, cargo]
					"commercial_route_returning": state_str = "Returning with revenue/unsold items"
			pbar.value = 100.0
			label.text = state_str
			continue
		var recipe_path = emp.get("active_recipe_path", "")
		var node_path = str(emp.get("active_gathering_node_path", ""))
		if recipe_path != "":
			var recipe = load(recipe_path)
			if recipe and recipe.get("is_service") == true:
				pbar.value = 0.0
				var active_slots = emp.get("service_slots", [])
				label.text = "Busy (Serving: %s)" % ", ".join(active_slots.map(func(t): return "%.1fs" % t)) if active_slots.size() > 0 else "Ready (0/3 slots active)"
				var emp_status_lbl = _employee_status_labels.get(i)
				if is_instance_valid(emp_status_lbl):
					emp_status_lbl.text = "Task: Offering %s" % recipe.recipe_name
				continue
			var timer = emp.get("craft_timer", 0.0)
			var total = emp.get("craft_total_time", 5.0)
			var worker = emp.get("npc_ref")
			var is_off_duty = is_instance_valid(worker) and worker.has_method("is_shift_active") and not worker.is_shift_active()
			if is_off_duty:
				pbar.value = 0.0
				label.text = "Off-Duty (Resting)"
			elif emp.get("is_paused", false):
				pbar.value = 0.0
				if node_path != "":
					var gathering_worker = emp.get("shift_worker_ref")
					if not is_instance_valid(gathering_worker):
						gathering_worker = worker
					if is_instance_valid(gathering_worker):
						var w_state = gathering_worker.get("worker_state")
						if w_state == "returning_to_workshop":
							var amount = 0
							var lm = get_node_or_null("/root/LogisticsManager")
							if lm and gathering_worker in lm.gathered_buffer:
								amount = int(floor(lm.gathered_buffer[gathering_worker]["amount"]))
							label.text = "Shortage: Returning with %d items..." % amount
						elif w_state == "gathering_at_node":
							var shift_timer = gathering_worker.get("shift_timer") if "shift_timer" in gathering_worker else 120.0
							label.text = "Shortage: Gathering... %.1fs remaining" % shift_timer
						elif w_state == "traveling_to_node":
							label.text = "Shortage: Traveling to node..."
						elif w_state == "traveling_to_workshop":
							label.text = "Shortage: Traveling to workshop..."
						else:
							label.text = "Shortage: Waiting for Materials"
					else:
						label.text = "Shortage: Waiting for Materials"
				else:
					label.text = "Waiting for Materials"
			elif is_instance_valid(worker) and worker.get("worker_state") == "traveling_to_workbench":
				pbar.value = 0.0
				label.text = "Traveling to workbench..."
			else:
				pbar.value = ((total - timer) / total) * 100.0 if total > 0.0 else 0.0
				label.text = "Crafting... %.1fs remaining" % timer if total > 0.0 else "Starting..."
		elif node_path != "":
			var worker = emp.get("shift_worker_ref")
			if not is_instance_valid(worker):
				worker = emp.get("npc_ref")
			var is_off_duty = is_instance_valid(worker) and worker.has_method("is_shift_active") and not worker.is_shift_active()
			if is_off_duty:
				pbar.value = 0.0
				label.text = "Off-Duty (Resting)"
			elif is_instance_valid(worker):
				var w_state = worker.get("worker_state")
				if w_state == "returning_to_workshop":
					pbar.value = 100.0
					var amount = 20
					var lm = get_node_or_null("/root/LogisticsManager")
					if lm and worker in lm.gathered_buffer:
						amount = int(floor(lm.gathered_buffer[worker]["amount"]))
					label.text = "Returning with %d items..." % amount
				elif w_state == "gathering_at_node":
					var timer = worker.get("shift_timer") if "shift_timer" in worker else 120.0
					pbar.value = ((120.0 - timer) / 120.0) * 100.0
					label.text = "Gathering... %.1fs remaining" % timer
				elif w_state == "traveling_to_node":
					pbar.value = 0.0
					label.text = "Traveling to node..."
				else:
					pbar.value = 0.0
					label.text = "Ready to start shift"
			else:
				pbar.value = 0.0
				label.text = "Completed!" if emp.get("shift_status") == "returning" else "Ready to start shift"
		else:
			pbar.value = 0.0
			label.text = "Idle"

func _render_workshop_view() -> void:
	for child in queue_list.get_children(): child.queue_free()
	for child in b_storage_grid.get_children(): child.queue_free()
	for child in stall_vbox.get_children(): child.queue_free()
	for child in player_inv_list.get_children(): child.queue_free()
	_progress_bars.clear()
	_timer_labels.clear()
	_employee_status_labels.clear()
	_player_status_lbl = null
	_player_detail_lbl = null
	_populate_production_queue()
	var target_b_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	if target_b_inv:
		if storage_lbl:
			storage_lbl.text = "Building Storage (%d/%d Slots)" % [target_b_inv.slots.size(), target_b_inv.max_slots]
		for i in range(8):
			var slot_panel = InventorySlotScene.instantiate()
			b_storage_grid.add_child(slot_panel)
			if i < target_b_inv.slots.size():
				var slot = target_b_inv.slots[i]
				slot_panel.set_item(slot["item"], slot["amount"], "building", _is_produced_here(slot["item"]))
				slot_panel.slot_pressed.connect(_on_slot_pressed)
				slot_panel.slot_accepted.connect(_on_slot_accepted)
				slot_panel.set_meta("type", "building_storage_slot")
				slot_panel.set_meta("item_id", slot["item"].id)
				slot_panel.set_meta("index", i)
			else:
				slot_panel.set_empty()
	var stall_inv = _building.inventory
	if stall_inv and _building.get("building_storage") != null:
		no_stall_label.hide()
		stall_vbox.show()
		if stall_lbl:
			stall_lbl.text = "Stall Storefront (%d/%d Slots)" % [stall_inv.slots.size(), stall_inv.max_slots]
		for i in range(4):
			var row_panel = StallSlotRowScene.instantiate()
			stall_vbox.add_child(row_panel)
			if i < stall_inv.slots.size():
				var slot = stall_inv.slots[i]
				var price = _building.custom_prices.get(slot["item"].id, slot["item"].base_value)
				row_panel.set_item(slot["item"], slot["amount"], price)
				row_panel.withdraw_button.set_meta("type", "stall_withdraw")
				row_panel.withdraw_button.set_meta("item_id", slot["item"].id)
				row_panel.withdraw_button.set_meta("index", i)
				row_panel.minus_button.set_meta("type", "stall_minus")
				row_panel.minus_button.set_meta("item_id", slot["item"].id)
				row_panel.minus_button.set_meta("index", i)
				row_panel.plus_button.set_meta("type", "stall_plus")
				row_panel.plus_button.set_meta("item_id", slot["item"].id)
				row_panel.plus_button.set_meta("index", i)
				row_panel.price_changed.connect(func(item, new_price): _building.custom_prices[item.id] = new_price)
				row_panel.withdraw_pressed.connect(func(item): _move_item_stall_to_building(item, false))
				row_panel.row_clicked.connect(func(item, is_shift): _move_item_stall_to_building(item, is_shift))
			else:
				row_panel.set_empty()
	else:
		stall_vbox.hide()
		no_stall_label.show()
	_populate_player_inventory_list()

func _populate_production_queue() -> void:
	if _building.get("hired_employees") == null:
		var no_workers = Label.new()
		no_workers.text = "No employee tracking on this building."
		no_workers.add_theme_font_size_override("font_size", 11)
		no_workers.modulate = Color(0.5, 0.5, 0.5)
		queue_list.add_child(no_workers)
		return
	var p_panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.18, 0.16, 0.22, 0.9)
	p_style.set_border_width_all(1)
	p_style.border_color = Color(0.58, 0.34, 0.75, 0.5)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 8
	p_style.content_margin_bottom = 8
	p_panel.add_theme_stylebox_override("panel", p_style)
	
	var p_vbox = VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 4)
	p_panel.add_child(p_vbox)
	
	var p_title_hbox = HBoxContainer.new()
	p_vbox.add_child(p_title_hbox)
	
	var p_name_lbl = Label.new()
	p_name_lbl.text = "Your Work (Player)"
	p_name_lbl.add_theme_font_size_override("font_size", 12)
	p_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_title_hbox.add_child(p_name_lbl)
	
	var p_status_lbl = Label.new()
	p_status_lbl.add_theme_font_size_override("font_size", 10)
	p_vbox.add_child(p_status_lbl)
	_player_status_lbl = p_status_lbl
	
	var p_detail_lbl = Label.new()
	p_detail_lbl.add_theme_font_size_override("font_size", 9)
	p_detail_lbl.modulate = Color(0.8, 0.75, 0.9)
	p_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	p_vbox.add_child(p_detail_lbl)
	_player_detail_lbl = p_detail_lbl
	
	var p_active_path = _building.get("player_crafting_recipe_path") if _building.get("player_crafting_recipe_path") else ""
	if p_active_path != "":
		var recipe = load(p_active_path)
		if recipe:
			var is_srv = recipe.get("is_service") == true
			var name_to_display = recipe.recipe_name if is_srv else (recipe.output_item.name if recipe.output_item else recipe.recipe_name)
			if is_srv:
				p_status_lbl.text = "Task: Offering %s" % name_to_display
				var active_slots = _building.player_service_slots
				p_detail_lbl.text = "Status: Busy (Serving: %s)\nContinuous service offering." % ", ".join(active_slots.map(func(t): return "%.1fs" % t)) if active_slots.size() > 0 else "Status: Ready (0/3 slots active)\nContinuous service offering."
			else:
				p_status_lbl.text = "Task: Produce %s" % name_to_display
				var inputs_txt = ", ".join(recipe.inputs.keys().map(func(i): return "%dx %s" % [recipe.inputs[i], i.name]))
				var player = get_tree().get_first_node_in_group("Player")
				var prod = player.get("productivity") if player else 1.0
				var craft_time = float(recipe.required_level * 5.0)
				if prod > 0.0: craft_time /= prod
				var p_level = GameState.career_levels.get(recipe.required_career, 1)
				if p_level >= 8 and recipe.output_item and recipe.output_item.get("is_luxury_product") == true:
					craft_time *= 0.85
				p_detail_lbl.text = "Req: %s\nYield: %d %s | Time: %.1fs" % [inputs_txt, recipe.output_amount, recipe.output_item.name if recipe.output_item else "Item", craft_time]
	else:
		p_status_lbl.text = "Task: Idle"
		p_detail_lbl.text = "You are currently idle."
		
	var start_craft_btn = Button.new()
	start_craft_btn.text = "Assign"
	start_craft_btn.focus_mode = Control.FOCUS_ALL
	start_craft_btn.add_theme_font_size_override("font_size", 10)
	start_craft_btn.set_meta("type", "player_assign")
	start_craft_btn.set_meta("index", -1)
	_main_view._coordinator._setup_button_hover(start_craft_btn)
	if _building.get("is_player_working_here"):
		start_craft_btn.text = "Stop"
		start_craft_btn.pressed.connect(func():
			_building.stop_player_crafting()
			_main_view.update_view()
		)
	else:
		start_craft_btn.pressed.connect(func(): _main_view.modal_manager.open_player_assign_popup())
	p_title_hbox.add_child(start_craft_btn)
	queue_list.add_child(p_panel)
	
	for i in range(_building.max_employees):
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.16, 0.20, 0.9)
		style.set_border_width_all(1)
		style.border_color = Color(0.24, 0.52, 0.85, 0.4)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)
		
		if i < _building.hired_employees.size():
			var emp = _building.hired_employees[i]
			var title_hbox = HBoxContainer.new()
			vbox.add_child(title_hbox)
			
			var name_lbl = Label.new()
			var npc = emp.get("npc_ref")
			var emp_prod = emp.get("productivity", 1.0)
			if is_instance_valid(npc): emp_prod = npc.productivity
			var prod_suffix = " (Prod: %d%%)" % int(emp_prod * 100.0)
			if emp_prod > 1.0: prod_suffix += " ▲"
			name_lbl.text = emp.get("name", "Worker") + prod_suffix
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title_hbox.add_child(name_lbl)
			
			var emp_status_lbl = Label.new()
			emp_status_lbl.add_theme_font_size_override("font_size", 10)
			emp_status_lbl.modulate = Color(0.7, 0.75, 0.9)
			vbox.add_child(emp_status_lbl)
			_employee_status_labels[i] = emp_status_lbl
			
			var emp_detail_lbl = Label.new()
			emp_detail_lbl.add_theme_font_size_override("font_size", 9)
			emp_detail_lbl.modulate = Color(0.8, 0.75, 0.9)
			emp_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			vbox.add_child(emp_detail_lbl)
			
			var active_route = emp.get("active_commercial_route")
			var active_path = emp.get("active_recipe_path", "")
			var active_node_path = str(emp.get("active_gathering_node_path", ""))
			
			if not active_route:
				var action_hbox = HBoxContainer.new()
				action_hbox.add_theme_constant_override("separation", 4)
				title_hbox.add_child(action_hbox)
				
				var emp_assign_btn = Button.new()
				emp_assign_btn.text = "Change" if (active_path != "" or active_node_path != "") else "Assign"
				emp_assign_btn.add_theme_font_size_override("font_size", 10)
				emp_assign_btn.focus_mode = Control.FOCUS_ALL
				emp_assign_btn.set_meta("type", "queue_assign")
				emp_assign_btn.set_meta("index", i)
				var emp_idx = i
				emp_assign_btn.pressed.connect(func(): _main_view.modal_manager.open_employee_assign_popup(emp_idx))
				_main_view._coordinator._setup_button_hover(emp_assign_btn)
				action_hbox.add_child(emp_assign_btn)
				
				if active_path != "" or active_node_path != "":
					var stop_btn = Button.new()
					stop_btn.text = "Stop"
					stop_btn.add_theme_font_size_override("font_size", 10)
					stop_btn.focus_mode = Control.FOCUS_ALL
					stop_btn.set_meta("type", "queue_stop")
					stop_btn.set_meta("index", i)
					stop_btn.pressed.connect(func():
						_main_view.modal_manager._on_job_selected_direct(emp_idx, null, false, 0)
						_main_view.update_view()
					)
					_main_view._coordinator._setup_button_hover(stop_btn)
					action_hbox.add_child(stop_btn)
					
			if active_route:
				emp_status_lbl.text = "Task: On Route (" + active_route.route_name + ")"
				emp_status_lbl.modulate = Color(0.9, 0.75, 0.15)
				if active_route.get("item_id") != null and active_route.get("item_id") != "":
					var item_data = EconomyManager.item_database.get(active_route.item_id)
					var item_name = item_data.name if item_data else active_route.item_id.capitalize()
					emp_detail_lbl.text = "Transporting: %s (Target: %d)" % [item_name, active_route.target_amount]
				else:
					emp_detail_lbl.text = ""
			else:
				if active_path != "":
					var recipe = load(active_path)
					if recipe:
						if recipe.get("is_service") == true:
							emp_status_lbl.text = "Task: Offering %s" % recipe.recipe_name
							emp_detail_lbl.text = "Continuous service offering."
						else:
							var name_to_display = recipe.output_item.name if recipe.output_item else recipe.recipe_name
							var repeat_info = "Continuous" if emp.get("is_repeating", true) else ("Limit: %d remaining" % emp.get("production_amount_limit", 1))
							emp_status_lbl.text = "Task: Produce %s (%s)" % [name_to_display, repeat_info]
							
							var inputs_txt = ", ".join(recipe.inputs.keys().map(func(i): return "%dx %s" % [recipe.inputs[i], i.name]))
							var craft_time = _building.get_employee_craft_time(emp, recipe)
							emp_detail_lbl.text = "Req: %s\nYield: %d %s | Time: %.1fs" % [inputs_txt, recipe.output_amount, recipe.output_item.name if recipe.output_item else "Item", craft_time]
				elif active_node_path != "":
					var node = get_node_or_null(active_node_path)
					if node:
						emp_status_lbl.text = "Task: Harvest %s" % node.resource_type_id.capitalize()
						var item_data = EconomyManager.item_database.get(node.resource_type_id)
						if item_data:
							emp_detail_lbl.text = "Yield: %s" % item_data.name
						else:
							emp_detail_lbl.text = ""
				else:
					emp_status_lbl.text = "Task: Idle"
					emp_detail_lbl.text = "Worker is currently idle."
					
			var pbar = ProgressBar.new()
			pbar.custom_minimum_size = Vector2(0, 12)
			pbar.show_percentage = false
			vbox.add_child(pbar)
			_progress_bars[i] = pbar
			
			var timer_lbl = Label.new()
			timer_lbl.add_theme_font_size_override("font_size", 10)
			timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(timer_lbl)
			_timer_labels[i] = timer_lbl
		else:
			var empty_lbl = Label.new()
			empty_lbl.text = "Slot Vacant"
			empty_lbl.add_theme_font_size_override("font_size", 11)
			empty_lbl.modulate = Color(0.4, 0.4, 0.4)
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(empty_lbl)
		queue_list.add_child(panel)

func _populate_player_inventory_list() -> void:
	var player_inv = GameState.player_inventory
	if player_inv_lbl and player_inv:
		player_inv_lbl.text = "Your Inventory (%d/%d Slots)" % [player_inv.slots.size(), player_inv.max_slots]
	if not player_inv or player_inv.slots.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No items in inventory."
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		player_inv_list.add_child(empty_lbl)
		return
	for slot in player_inv.slots:
		var item = slot["item"]
		var amount = slot["amount"]
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.18, 0.22, 0.4)
		style.set_corner_radius_all(4)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", style)
		var hover_style = style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.24, 0.52, 0.85, 0.7)
		hover_style.set_border_width_all(1)
		var hbox = HBoxContainer.new()
		panel.add_child(hbox)
		var label = Label.new()
		label.text = "%s (x%d)" % [item.name, amount]
		label.add_theme_font_size_override("font_size", 11)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		var put_btn = Button.new()
		put_btn.text = "Put"
		put_btn.add_theme_font_size_override("font_size", 10)
		put_btn.set_meta("type", "player_inv_put")
		put_btn.set_meta("item_id", item.id)
		put_btn.pressed.connect(func(): _move_item_player_to_building(item, false))
		hbox.add_child(put_btn)
		panel.gui_input.connect(func(event): _on_slot_gui_input(event, item, "player"))
		panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", hover_style))
		panel.mouse_exited.connect(func(): panel.add_theme_stylebox_override("panel", style))
		player_inv_list.add_child(panel)

func _on_slot_pressed(item: ItemData, source_type: String, is_shift: bool) -> void:
	if source_type == "building": _main_view.modal_manager.open_building_transfer_options(item, is_shift)
	elif source_type == "player": _move_item_player_to_building(item, is_shift)
	elif source_type == "stall": _move_item_stall_to_building(item, is_shift)

func _on_slot_accepted(item: ItemData, source_type: String) -> void:
	if source_type == "building": _main_view.modal_manager.open_building_transfer_options(item, false)
	elif source_type == "player": _move_item_player_to_building(item, false)
	elif source_type == "stall": _move_item_stall_to_building(item, false)

func _on_slot_gui_input(event: InputEvent, item: ItemData, source: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		var is_shift = event.shift_pressed
		if source == "building": _main_view.modal_manager.open_building_transfer_options(item, is_shift)
		elif source == "stall" and event.button_index == MOUSE_BUTTON_LEFT: _move_item_stall_to_building(item, is_shift)
		elif source == "player" and event.button_index == MOUSE_BUTTON_LEFT: _move_item_player_to_building(item, is_shift)

func _move_item_player_to_building(item: ItemData, all_stack: bool) -> void:
	var source_inv = GameState.player_inventory
	if not source_inv: return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0: return
	if amt == 1:
		_move_item_player_to_building_action(item, 1)
		_main_view.update_view()
	else:
		_main_view._coordinator.open_quantity_slider(item, "player_to_building", amt, amt if all_stack else 1, func(amount):
			_move_item_player_to_building_action(item, amount)
			_main_view.update_view()
		)

func _move_item_stall_to_building(item: ItemData, all_stack: bool) -> void:
	var source_inv = _building.inventory
	if not source_inv: return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0: return
	if amt == 1:
		_move_item_stall_to_building_action(item, 1)
		_main_view.update_view()
	else:
		_main_view._coordinator.open_quantity_slider(item, "stall_to_building", amt, amt if all_stack else 1, func(amount):
			_move_item_stall_to_building_action(item, amount)
			_main_view.update_view()
		)

func _move_item_player_to_building_action(item: ItemData, transfer_qty: int) -> void:
	var source_inv = GameState.player_inventory
	var target_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	if not source_inv or not target_inv: return
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Building storage is full!", _building.global_position)
		return
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Storage is full!", _building.global_position)

func _move_item_stall_to_building_action(item: ItemData, transfer_qty: int) -> void:
	var source_inv = _building.inventory
	var target_inv = _building.building_storage
	if not source_inv or not target_inv: return
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Building storage is full!", _building.global_position)
		return
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Storage is full!", _building.global_position)

func _is_produced_here(item: ItemData) -> bool:
	var recipes = _get_recipes()
	for recipe in recipes:
		if recipe and recipe.output_item and recipe.output_item.id == item.id:
			return true
	return false

func _get_recipes() -> Array:
	if not _building: return []
	var bench = _building.get_node_or_null("CraftingBench")
	if not bench and is_instance_valid(_building.get("instanced_interior")):
		bench = _building.instanced_interior.get_node_or_null("CraftingBench")
	if not bench or not ("recipes" in bench): return []
	var list = bench.recipes.duplicate()
	if _building.get("building_level") != null and _building.building_level >= 2:
		var building_career = ""
		if _building.get("building_data") != null and _building.building_data and _building.building_data.get("career") != "":
			building_career = _building.building_data.career
		else:
			for r in bench.recipes:
				if r and r.required_career != "":
					building_career = r.required_career
					break
		if building_career != "":
			for path in GameState.active_trial_recipes:
				var trial_res = load(path)
				if trial_res and trial_res.required_career == building_career:
					list.append(trial_res)
	return list

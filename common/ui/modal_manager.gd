extends ColorRect

var _main_view: Control = null
var _building: Node2D = null
var _last_focused_trigger_button: Control = null
var _last_valid_popup_focus: Control = null

@onready var transfer_options_modal: PanelContainer = $TransferOptionsModal
@onready var transfer_title: Label = $TransferOptionsModal/VBox/TitleLabel
@onready var transfer_amount_lbl: Label = $TransferOptionsModal/VBox/AmountLabel
@onready var to_player_btn: Button = $TransferOptionsModal/VBox/Buttons/ToPlayerButton
@onready var to_stall_btn: Button = $TransferOptionsModal/VBox/Buttons/ToStallButton
@onready var transfer_cancel_btn: Button = $TransferOptionsModal/VBox/Buttons/CancelButton

@onready var player_assign_modal: PanelContainer = $PlayerAssignModal
@onready var player_assign_list: VBoxContainer = $PlayerAssignModal/VBox/Scroll/List
@onready var player_assign_cancel: Button = $PlayerAssignModal/VBox/CancelButton

@onready var emp_assign_modal: PanelContainer = $EmpAssignModal
@onready var emp_assign_title: Label = $EmpAssignModal/VBox/TitleLabel
@onready var emp_assign_list: VBoxContainer = $EmpAssignModal/VBox/Content/Left/Scroll/List
@onready var emp_qty_vbox: VBoxContainer = $EmpAssignModal/VBox/Content/Right
@onready var emp_qty_buttons: VBoxContainer = $EmpAssignModal/VBox/Content/Right/QtyButtons
@onready var emp_assign_cancel: Button = $EmpAssignModal/VBox/CancelButton

func setup(p_view: Control) -> void:
	_main_view = p_view
	if get_viewport() and not get_viewport().gui_focus_changed.is_connected(_on_viewport_focus_changed):
		get_viewport().gui_focus_changed.connect(_on_viewport_focus_changed)

func refresh(building: Node2D) -> void:
	_building = building

func close_all_popups() -> void:
	hide()
	transfer_options_modal.hide()
	player_assign_modal.hide()
	emp_assign_modal.hide()
	_last_valid_popup_focus = null
	if _last_focused_trigger_button and is_instance_valid(_last_focused_trigger_button) and _last_focused_trigger_button.is_inside_tree() and _last_focused_trigger_button.visible:
		_last_focused_trigger_button.grab_focus()
	_last_focused_trigger_button = null

func open_building_transfer_options(item: ItemData, is_shift: bool) -> void:
	var target_b_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	if not target_b_inv: return
	var amt = target_b_inv.get_item_amount(item.id)
	if amt <= 0: return
	var focused = get_viewport().gui_get_focus_owner()
	if focused: _last_focused_trigger_button = focused
	transfer_title.text = "Transfer Options: " + item.name
	transfer_amount_lbl.text = "Quantity in storage: %d" % amt
	var has_stall = _building.inventory != null and _building.get("building_storage") != null
	var is_produced = _is_produced_here(item)
	for conn in to_player_btn.pressed.get_connections(): to_player_btn.pressed.disconnect(conn.callable)
	to_player_btn.pressed.connect(func(): _on_transfer_to_player(item, is_shift))
	for conn in to_stall_btn.pressed.get_connections(): to_stall_btn.pressed.disconnect(conn.callable)
	to_stall_btn.pressed.connect(func(): _on_transfer_to_stall(item, is_shift))
	if not has_stall:
		to_stall_btn.disabled = true
		to_stall_btn.text = "Transfer to Stall Storefront (No Storefront)"
	elif not is_produced:
		to_stall_btn.disabled = true
		to_stall_btn.text = "Transfer to Stall Storefront (Not Produced Here)"
	else:
		to_stall_btn.disabled = false
		to_stall_btn.text = "Transfer to Stall Storefront"
	if transfer_cancel_btn.pressed.is_connected(close_all_popups): transfer_cancel_btn.pressed.disconnect(close_all_popups)
	transfer_cancel_btn.pressed.connect(close_all_popups)
	show()
	transfer_options_modal.show()
	to_player_btn.grab_focus()
	_last_valid_popup_focus = to_player_btn

func _on_transfer_to_player(item: ItemData, is_shift: bool) -> void:
	close_all_popups()
	_move_item_building_to_player(item, is_shift)

func _on_transfer_to_stall(item: ItemData, is_shift: bool) -> void:
	close_all_popups()
	_move_item_building_to_stall(item, is_shift)

func _move_item_building_to_player(item: ItemData, all_stack: bool) -> void:
	var source_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	if not source_inv: return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0: return
	if amt == 1:
		_move_item_building_to_player_action(item, 1)
		_main_view.update_view()
	else:
		_main_view._coordinator.open_quantity_slider(item, "building_to_player", amt, amt if all_stack else 1, func(amount):
			_move_item_building_to_player_action(item, amount)
			_main_view.update_view()
		)

func _move_item_building_to_stall(item: ItemData, all_stack: bool) -> void:
	if not _is_produced_here(item): return
	var source_inv = _building.building_storage
	if not source_inv: return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0: return
	if amt == 1:
		_move_item_building_to_stall_action(item, 1)
		_main_view.update_view()
	else:
		_main_view._coordinator.open_quantity_slider(item, "building_to_stall", amt, amt if all_stack else 1, func(amount):
			_move_item_building_to_stall_action(item, amount)
			_main_view.update_view()
		)

func _move_item_building_to_player_action(item: ItemData, transfer_qty: int) -> void:
	var source_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	var target_inv = GameState.player_inventory
	if not source_inv or not target_inv: return
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Your inventory is full!", _building.global_position)
		return
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Your inventory is full!", _building.global_position)

func _move_item_building_to_stall_action(item: ItemData, transfer_qty: int) -> void:
	if not _is_produced_here(item): return
	var source_inv = _building.building_storage
	var target_inv = _building.inventory
	if not source_inv or not target_inv: return
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Stall is full (max 4 goods)!", _building.global_position)
		return
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Stall storage is full!", _building.global_position)

func open_player_assign_popup() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused: _last_focused_trigger_button = focused
	for child in player_assign_list.get_children(): child.queue_free()
	var first_focus_btn = null
	var recipes = _get_recipes()
	var prod_recipes = recipes.filter(func(r): return r and r.get("is_service") != true)
	var service_recipes = recipes.filter(func(r): return r and r.get("is_service") == true)
	if not prod_recipes.is_empty():
		var prod_title = Label.new()
		prod_title.text = "Production Tasks"
		prod_title.add_theme_font_size_override("font_size", 11)
		prod_title.modulate = Color(0.24, 0.52, 0.85, 1.0)
		player_assign_list.add_child(prod_title)
		var items_grid = GridContainer.new()
		items_grid.columns = 4
		items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_grid.add_theme_constant_override("h_separation", 8)
		items_grid.add_theme_constant_override("v_separation", 8)
		player_assign_list.add_child(items_grid)
		for recipe in prod_recipes:
			var name_to_display = recipe.output_item.name if recipe.output_item else recipe.recipe_name
			var card = _main_view._coordinator._create_task_card(name_to_display, "🔨", func():
				close_all_popups()
				_building.start_player_crafting(recipe.resource_path)
				_main_view.update_view()
			)
			items_grid.add_child(card)
			if not first_focus_btn: first_focus_btn = card
	if not service_recipes.is_empty():
		var srv_title = Label.new()
		srv_title.text = "Services"
		srv_title.add_theme_font_size_override("font_size", 11)
		srv_title.modulate = Color(0.85, 0.35, 0.24, 1.0)
		player_assign_list.add_child(srv_title)
		var srv_grid = GridContainer.new()
		srv_grid.columns = 4
		srv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srv_grid.add_theme_constant_override("h_separation", 8)
		srv_grid.add_theme_constant_override("v_separation", 8)
		player_assign_list.add_child(srv_grid)
		for recipe in service_recipes:
			var is_occupied = _building.hired_employees.any(func(emp): return emp.get("active_recipe_path", "") == recipe.resource_path)
			var card_name = recipe.recipe_name + ("\n(Occupied)" if is_occupied else "")
			var card = _main_view._coordinator._create_task_card(card_name, "🛎️", func():
				close_all_popups()
				_building.start_player_crafting(recipe.resource_path)
				_main_view.update_view()
			)
			if is_occupied:
				card.disabled = true
				card.tooltip_text = "Already assigned to another worker"
				card.modulate = Color(0.5, 0.5, 0.5, 0.7)
			srv_grid.add_child(card)
			if not first_focus_btn and not is_occupied: first_focus_btn = card
	if player_assign_cancel.pressed.is_connected(close_all_popups): player_assign_cancel.pressed.disconnect(close_all_popups)
	player_assign_cancel.pressed.connect(close_all_popups)
	show()
	player_assign_modal.show()
	if first_focus_btn:
		first_focus_btn.grab_focus()
		_last_valid_popup_focus = first_focus_btn
	else:
		player_assign_cancel.grab_focus()
		_last_valid_popup_focus = player_assign_cancel

func open_employee_assign_popup(emp_idx: int) -> void:
	if not _building.get("hired_employees") or emp_idx >= _building.hired_employees.size(): return
	var focused = get_viewport().gui_get_focus_owner()
	if focused: _last_focused_trigger_button = focused
	var emp = _building.hired_employees[emp_idx]
	emp_assign_title.text = "Assign Task - %s" % emp.get("name", "Employee")
	for child in emp_assign_list.get_children(): child.queue_free()
	emp_qty_vbox.hide()
	var first_focus_btn = null
	var recipes = _get_recipes()
	var prod_recipes = recipes.filter(func(r): return r and r.get("is_service") != true)
	var service_recipes = recipes.filter(func(r): return r and r.get("is_service") == true)
	if not prod_recipes.is_empty():
		var prod_title = Label.new()
		prod_title.text = "Production Tasks"
		prod_title.add_theme_font_size_override("font_size", 11)
		prod_title.modulate = Color(0.24, 0.52, 0.85, 1.0)
		emp_assign_list.add_child(prod_title)
		var prod_grid = GridContainer.new()
		prod_grid.columns = 4
		prod_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prod_grid.add_theme_constant_override("h_separation", 8)
		prod_grid.add_theme_constant_override("v_separation", 8)
		emp_assign_list.add_child(prod_grid)
		for recipe in prod_recipes:
			var name_to_display = recipe.output_item.name if recipe.output_item else recipe.recipe_name
			var card = _main_view._coordinator._create_task_card(name_to_display, "🔨", func():
				emp_qty_vbox.show()
				for child in emp_qty_buttons.get_children(): child.queue_free()
				var qty_buttons_array = []
				
				var indef_btn = Button.new()
				indef_btn.text = "Continuous (Indefinite)"
				indef_btn.add_theme_font_size_override("font_size", 10)
				_main_view._coordinator._setup_button_hover(indef_btn)
				indef_btn.pressed.connect(func():
					_on_job_selected_direct(emp_idx, recipe, true, 0)
					close_all_popups()
					_main_view.update_view()
				)
				emp_qty_buttons.add_child(indef_btn)
				qty_buttons_array.append(indef_btn)

				var quantities = [1, 5, 10, 25]
				for qty in quantities:
					var q_btn = Button.new()
					q_btn.text = "Limit to %d" % qty
					q_btn.add_theme_font_size_override("font_size", 10)
					_main_view._coordinator._setup_button_hover(q_btn)
					q_btn.pressed.connect(func():
						_on_job_selected_direct(emp_idx, recipe, false, qty)
						close_all_popups()
						_main_view.update_view()
					)
					emp_qty_buttons.add_child(q_btn)
					qty_buttons_array.append(q_btn)
					
				for i in range(qty_buttons_array.size()):
					var btn = qty_buttons_array[i]
					var prev_btn = qty_buttons_array[(i - 1 + qty_buttons_array.size()) % qty_buttons_array.size()]
					var next_btn = qty_buttons_array[(i + 1) % qty_buttons_array.size()]
					btn.focus_neighbor_top = prev_btn.get_path()
					btn.focus_neighbor_bottom = next_btn.get_path()
					
				if not qty_buttons_array.is_empty():
					var first_btn = qty_buttons_array[0]
					first_btn.grab_focus()
					_last_valid_popup_focus = first_btn
			)
			prod_grid.add_child(card)
			if not first_focus_btn: first_focus_btn = card
	if not service_recipes.is_empty():
		var srv_title = Label.new()
		srv_title.text = "Services"
		srv_title.add_theme_font_size_override("font_size", 11)
		srv_title.modulate = Color(0.85, 0.35, 0.24, 1.0)
		emp_assign_list.add_child(srv_title)
		var srv_grid = GridContainer.new()
		srv_grid.columns = 4
		srv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srv_grid.add_theme_constant_override("h_separation", 8)
		srv_grid.add_theme_constant_override("v_separation", 8)
		emp_assign_list.add_child(srv_grid)
		for recipe in service_recipes:
			var is_occupied = false
			if _building.get("is_player_working_here") == true and _building.get("player_crafting_recipe_path") == recipe.resource_path:
				is_occupied = true
			else:
				is_occupied = _building.hired_employees.any(func(other_emp): return other_emp != emp and other_emp.get("active_recipe_path", "") == recipe.resource_path)
			var card_name = recipe.recipe_name + ("\n(Occupied)" if is_occupied else "")
			var card = _main_view._coordinator._create_task_card(card_name, "🛎️", func():
				_on_job_selected_direct(emp_idx, recipe, true, 0)
				close_all_popups()
				_main_view.update_view()
			)
			if is_occupied:
				card.disabled = true
				card.tooltip_text = "Already assigned to another worker"
				card.modulate = Color(0.5, 0.5, 0.5, 0.7)
			srv_grid.add_child(card)
			if not first_focus_btn and not is_occupied: first_focus_btn = card
	var comp_nodes = _get_compatible_nodes()
	if not comp_nodes.is_empty():
		var gather_title = Label.new()
		gather_title.text = "Gathering Tasks"
		gather_title.add_theme_font_size_override("font_size", 11)
		gather_title.modulate = Color(0.4, 0.85, 0.4, 1.0)
		emp_assign_list.add_child(gather_title)
		var gather_grid = GridContainer.new()
		gather_grid.columns = 4
		gather_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gather_grid.add_theme_constant_override("h_separation", 8)
		gather_grid.add_theme_constant_override("v_separation", 8)
		emp_assign_list.add_child(gather_grid)
		var added_node_types = {}
		for node in comp_nodes:
			if node:
				var node_name = node.resource_type_id.capitalize()
				if added_node_types.has(node_name): continue
				added_node_types[node_name] = true
				var card = _main_view._coordinator._create_task_card(node_name, "⛏️", func():
					_on_job_selected_direct(emp_idx, node, true, 0)
					close_all_popups()
					_main_view.update_view()
				)
				gather_grid.add_child(card)
				if not first_focus_btn: first_focus_btn = card
	if emp_assign_cancel.pressed.is_connected(close_all_popups): emp_assign_cancel.pressed.disconnect(close_all_popups)
	emp_assign_cancel.pressed.connect(close_all_popups)
	show()
	emp_assign_modal.show()
	if first_focus_btn:
		first_focus_btn.grab_focus()
		_last_valid_popup_focus = first_focus_btn
	else:
		emp_assign_cancel.grab_focus()
		_last_valid_popup_focus = emp_assign_cancel

func _on_job_selected_direct(emp_idx: int, task: Object, is_indefinite: bool, amount: int) -> void:
	var emp = _building.hired_employees[emp_idx]
	var npc = emp.get("npc_ref")
	emp["active_recipe_path"] = ""
	emp["active_gathering_node_path"] = ""
	emp["shift_status"] = "idle"
	emp["is_repeating"] = is_indefinite
	emp["production_amount_limit"] = amount
	var worker = emp.get("shift_worker_ref") if is_instance_valid(emp.get("shift_worker_ref")) else emp.get("npc_ref")
	if is_instance_valid(worker):
		if worker.get("is_gathering") or worker.get("worker_state") in ["traveling_to_node", "gathering_at_node", "returning_to_workshop"]:
			worker.set("is_gathering", false)
			if is_instance_valid(worker.get("target_mega_node")): worker.target_mega_node._on_body_exited(worker)
			worker.set("worker_state", "traveling_to_workshop")
			var target_pos = _building.get_interaction_position()
			if worker.has_method("_generate_path"): worker.call("_generate_path", target_pos)
		emp["shift_worker_ref"] = null
	if task == null:
		emp["craft_timer"] = 0.0
		emp["craft_total_time"] = 0.0
		if is_instance_valid(npc):
			npc.set("worker_state", "traveling_to_workshop")
			npc.call("_generate_path", _building.get_interaction_position())
		return
	if task is Recipe:
		if not task.is_service and not _building.is_recipe_permitted(task):
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud: hud._spawn_floating_text("Complexity requires Building Level 2!", _building.global_position)
			return
		if task.get("is_service") == true:
			var active_crafters = 0
			if _building.get("is_player_working_here") == true: active_crafters += 1
			for other_idx in range(_building.hired_employees.size()):
				if other_idx != emp_idx and _building.hired_employees[other_idx].get("active_recipe_path", "") != "": active_crafters += 1
			var bench_limit = 1 + (_building.improvements.get("extra_workbench", 0) if typeof(_building.improvements) == TYPE_DICTIONARY else 0)
			if active_crafters >= bench_limit:
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud: hud._spawn_floating_text("All crafting benches are occupied!", _building.global_position)
				return
			emp["active_recipe_path"] = task.resource_path
			emp["craft_timer"] = 0.0
			emp["craft_total_time"] = 0.0
			emp["is_paused"] = false
			if is_instance_valid(npc):
				npc.set("worker_state", "traveling_to_workbench")
				if npc.global_position.y < 9000.0 and is_instance_valid(_building.instanced_interior):
					npc.call("_teleport", _building.instanced_interior.global_position + Vector2(0, 40))
				if is_instance_valid(_building.instanced_interior) and is_instance_valid(_building.instanced_interior.crafting_bench):
					npc.call("_generate_path", _building.instanced_interior.crafting_bench.global_position)
			return
		var pm = get_node_or_null("/root/PoliticsManager")
		var b_prov = GameState.get_province_of_node(_building) if GameState else ""
		if pm and b_prov != "":
			if pm.is_law_active("metallurgical_monopoly", b_prov) and _building.is_in_group("Smelters"):
				var sett = GameState.get_nearest_settlement(_building)
				if sett and not sett.is_in_group("Cities"):
					var hud = get_tree().get_first_node_in_group("PlayerHUD")
					if hud: hud._spawn_floating_text("Illegal! Smelting outside city walls is banned.", _building.global_position)
					return
		var active_crafters = 0
		if _building.get("is_player_working_here") == true: active_crafters += 1
		for other_idx in range(_building.hired_employees.size()):
			if other_idx != emp_idx and _building.hired_employees[other_idx].get("active_recipe_path", "") != "": active_crafters += 1
		var bench_limit = 1 + (_building.improvements.get("extra_workbench", 0) if typeof(_building.improvements) == TYPE_DICTIONARY else 0)
		if active_crafters >= bench_limit:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud: hud._spawn_floating_text("All crafting benches are occupied!", _building.global_position)
			return
		var target_b_storage = _building.building_storage if _building.get("building_storage") else _building.inventory
		var inputs_ok = true
		for item in task.inputs:
			if target_b_storage.get_item_amount(item.id) < task.inputs[item]:
				inputs_ok = false
				break
		var missing_raw_material = null
		if not inputs_ok and (_building.improvements.get("auto_gathering", 0) > 0):
			for item in task.inputs:
				if target_b_storage.get_item_amount(item.id) < task.inputs[item] and item.is_raw_material:
					missing_raw_material = item
					break
		if missing_raw_material != null and pm and b_prov != "":
			if pm.is_law_active("crown_forestry_protection", b_prov) and missing_raw_material.id == "standard_timber":
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud: hud._spawn_floating_text("Illegal! Auto-gathering timber is banned.", _building.global_position)
				return
			if pm.is_law_active("noble_game_preservation", b_prov) and missing_raw_material.id == "venison":
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud: hud._spawn_floating_text("Illegal! Auto-gathering venison is banned.", _building.global_position)
				return
		if inputs_ok or missing_raw_material != null:
			if inputs_ok:
				for item in task.inputs: target_b_storage.remove_item(item.id, task.inputs[item])
				var craft_time = 5.0
				if _building.has_method("get_employee_craft_time"):
					craft_time = _building.get_employee_craft_time(emp, task)
				else:
					craft_time = float(task.required_level * 5.0)
					var prod = npc.get("productivity") if is_instance_valid(npc) else 1.0
					if prod > 0.0: craft_time /= prod
				emp["active_recipe_path"] = task.resource_path
				emp["craft_timer"] = craft_time
				emp["craft_total_time"] = craft_time
				emp["is_paused"] = false
				if is_instance_valid(npc):
					npc.set("worker_state", "traveling_to_workbench")
					if npc.global_position.y < 9000.0 and is_instance_valid(_building.instanced_interior):
						npc.call("_teleport", _building.instanced_interior.global_position + Vector2(0, 40))
					if is_instance_valid(_building.instanced_interior) and is_instance_valid(_building.instanced_interior.crafting_bench):
						npc.call("_generate_path", _building.instanced_interior.crafting_bench.global_position)
			else:
				emp["active_recipe_path"] = task.resource_path
				emp["craft_timer"] = 0.0
				emp["craft_total_time"] = 0.0
				emp["is_paused"] = true
				if is_instance_valid(npc):
					var nearest = _building.get_nearest_mega_node_for_resource(missing_raw_material.id)
					if nearest:
						npc.start_gathering_shift(nearest)
						emp["active_gathering_node_path"] = nearest.get_path()
		else:
			emp["active_recipe_path"] = task.resource_path
			emp["craft_timer"] = 0.0
			emp["craft_total_time"] = 0.0
			emp["is_paused"] = true
			emp["shortage_alert_sent"] = true
			if is_instance_valid(npc):
				var target_pos = _building.get_interaction_position()
				npc.set("worker_state", "traveling_to_workbench")
				if npc.global_position.y < 9000.0 and is_instance_valid(_building.instanced_interior):
					npc.call("_teleport", _building.instanced_interior.global_position + Vector2(0, 40))
				if is_instance_valid(_building.instanced_interior) and is_instance_valid(_building.instanced_interior.crafting_bench):
					target_pos = _building.instanced_interior.crafting_bench.global_position
				npc.call("_generate_path", target_pos)
			if GameState.has_method("add_alert"):
				var msg = "%s cannot start producing %s: Missing inputs." % [emp.get("name", "Employee"), task.output_item.name]
				AlertManager.add_alert("Production Blocked", msg, "warning", _building)
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud: hud._spawn_floating_text("Employee assigned (Paused: Missing materials)", _building.global_position)
	elif task is Area2D:
		var node = task
		var res_id = node.resource_type_id
		var pm_res = get_node_or_null("/root/PoliticsManager")
		var b_prov_res = GameState.get_province_of_node(_building) if GameState else ""
		if pm_res and b_prov_res != "":
			if pm_res.is_law_active("crown_forestry_protection", b_prov_res) and res_id == "standard_timber":
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud: hud._spawn_floating_text("Illegal! Timber harvesting is banned.", _building.global_position)
				return
			if pm_res.is_law_active("noble_game_preservation", b_prov_res) and res_id == "venison":
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud: hud._spawn_floating_text("Illegal! Hunting is banned.", _building.global_position)
				return
		var econ_mgr = get_node_or_null("/root/EconomyManager")
		var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
		var b_storage = _building.building_storage
		var has_space = b_storage.get_free_space_for_item(item_res) >= 20 if (b_storage and item_res) else false
		if not has_space:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud: hud._spawn_floating_text("Insufficient warehouse capacity (Requires 20 slots).", _building.global_position)
			return
		var fee = node.get_entry_fee()
		if GameState.gold < fee:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud: hud._spawn_floating_text("Cannot afford permit fee!", _building.global_position)
			return
		GameState.gold -= fee
		emp["active_gathering_node_path"] = node.get_path()
		emp["shift_status"] = "traveling"
		emp["is_paused"] = false
		if is_instance_valid(npc):
			npc.start_gathering_shift(node)
			emp["shift_worker_ref"] = npc

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

func _get_compatible_nodes() -> Array:
	var compatible = []
	var recipes = _get_recipes()
	var required_inputs = {}
	for recipe in recipes:
		if recipe:
			for input_item in recipe.inputs: required_inputs[input_item.id] = true
	var nodes = get_tree().get_nodes_in_group("MegaNodes")
	for node in nodes:
		if node.resource_type_id in required_inputs: compatible.append(node)
	return compatible

func _on_viewport_focus_changed(control: Control) -> void:
	if visible: # ModalManager is visible/active
		if control:
			if is_ancestor_of(control):
				_last_valid_popup_focus = control
			else:
				# Focus attempted to escape outside ModalManager! Intercept and snap back.
				if _last_valid_popup_focus and is_instance_valid(_last_valid_popup_focus) and _last_valid_popup_focus.is_inside_tree() and _last_valid_popup_focus.visible:
					_last_valid_popup_focus.call_deferred("grab_focus")
				else:
					var fallback = _find_first_focusable_in_popup(self)
					if fallback:
						_last_valid_popup_focus = fallback
						fallback.call_deferred("grab_focus")

func _find_first_focusable_in_popup(node: Node) -> Control:
	if node is Control and node.visible and node.focus_mode != Control.FOCUS_NONE:
		if node is Button and not node.disabled:
			return node
		elif not node is Button:
			return node
	for child in node.get_children():
		var found = _find_first_focusable_in_popup(child)
		if found:
			return found
	return null

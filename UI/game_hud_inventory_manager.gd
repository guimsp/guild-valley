extends RefCounted

var confirm_popup: PanelContainer = null
var context_popup: PanelContainer = null
var employee_popup: PanelContainer = null
var trait_replacement_popup: PanelContainer = null
var _popup_confirm_callback: Callable = Callable()
var _selected_skill_book: SkillBook = null

func update_inventory_panel(hud: GameHUD, grid_container: GridContainer) -> void:
	hud.update_hud_values()
	if not grid_container:
		return
		
	# Clear previous inventory nodes
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
		
	var slots: Array = GameState.player_inventory.slots
	var max_slots: int = GameState.player_inventory.max_slots
	
	for slot in slots:
		var item: ItemData = slot["item"] as ItemData
		var amount: int = slot["amount"]
		
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(64, 64)
		slot_panel.focus_mode = Control.FOCUS_ALL
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.22, 0.8)
		style.set_border_width_all(2)
		style.border_color = Color(0.35, 0.35, 0.45, 0.8)
		style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", style)
		
		var hover_style = style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.88, 0.73, 0.23, 0.9) # Gold accent border
		
		slot_panel.focus_entered.connect(func():
			slot_panel.add_theme_stylebox_override("panel", hover_style)
		)
		slot_panel.focus_exited.connect(func():
			slot_panel.add_theme_stylebox_override("panel", style)
		)
		slot_panel.mouse_entered.connect(func():
			slot_panel.add_theme_stylebox_override("panel", hover_style)
		)
		slot_panel.mouse_exited.connect(func():
			if not slot_panel.has_focus():
				slot_panel.add_theme_stylebox_override("panel", style)
		)
		
		slot_panel.gui_input.connect(func(event: InputEvent):
			var is_interact = event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F and event.pressed)
			var is_accept = event.is_action_pressed("ui_accept")
			var is_click = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
			if is_interact or is_accept or is_click:
				slot_panel.get_viewport().set_input_as_handled()
				on_inventory_slot_interacted(hud, item, slot_panel)
		)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_panel.add_child(vbox)
		
		var name_lbl = Label.new()
		name_lbl.text = item.name.substr(0, 8)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		vbox.add_child(name_lbl)
		
		var amt_lbl = Label.new()
		amt_lbl.text = "x%d" % amount
		amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(amt_lbl)
		
		var tooltip_str: String = "%s\nCategory: %s\nValue: %d Gold" % [item.name, item.category, item.base_value]
		if item.equipment_slot != "None":
			tooltip_str += "\nSlot: %s" % item.equipment_slot
			if item.armor_stat > 0: tooltip_str += "\nArmor: +%d" % item.armor_stat
			if item.attack_stat > 0: tooltip_str += "\nAttack: +%d" % item.attack_stat
			if item.speed_bonus > 0: tooltip_str += "\nSpeed: +%d%%" % int(item.speed_bonus * 100)
			if item.capacity_bonus > 0: tooltip_str += "\nCapacity: +%d slots" % item.capacity_bonus
			if item.gathering_multiplier_bonus > 0: tooltip_str += "\nGathering Bonus: +%d%%" % int(item.gathering_multiplier_bonus * 100)
			if item.is_tool: tooltip_str += "\nDurability: %d/%d" % [item.durability, item.max_durability]
		
		slot_panel.tooltip_text = tooltip_str
		grid_container.add_child(slot_panel)
		
	# Fill in blank spots
	var empty_slots: int = max_slots - slots.size()
	for i in range(empty_slots):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(64, 64)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.16, 0.5)
		style.set_border_width_all(1)
		style.border_color = Color(0.24, 0.24, 0.3, 0.5)
		style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", style)
		
		grid_container.add_child(slot_panel)
		
	update_player_equipment_ui(hud)
	link_inventory_grid_focus(hud, grid_container)

func update_player_equipment_ui(hud: GameHUD) -> void:
	if not hud._active_player or not hud._active_player.has_node("EquipmentComponent"):
		return
		
	var eq = hud._active_player.get_node("EquipmentComponent")
	
	hud.armor_label.text = "Armor: %d" % eq.call("get_total_armor")
	hud.attack_label.text = "Attack: %d" % eq.call("get_total_attack")
	hud.speed_label.text = "Speed Bonus: +%d%%" % int(eq.call("get_total_speed_bonus") * 100)
	hud.capacity_label.text = "Capacity Bonus: %+d slots" % eq.call("get_total_capacity_bonus")
	
	# Update each Slot Button
	var slot_buttons: Dictionary = {
		"head": hud.head_slot,
		"body": hud.body_slot,
		"gloves": hud.gloves_slot,
		"weapon": hud.weapon_slot,
		"tool": hud.tool_slot,
		"bag": hud.bag_slot,
		"necklace": hud.necklace_slot,
		"ring": hud.ring_slot,
		"transportation": hud.trans_slot
	}
	
	var slot_friendly_names: Dictionary = {
		"head": "Head",
		"body": "Body",
		"gloves": "Gloves",
		"weapon": "Weapon",
		"tool": "Tool",
		"bag": "Bag",
		"necklace": "Necklace",
		"ring": "Ring",
		"transportation": "Trans"
	}
	
	for slot_name in slot_buttons:
		var btn = slot_buttons[slot_name] as Button
		var item = eq.call("get_equipped_item", slot_name) as ItemData
		if item:
			var btn_text: String = item.name
			if item.is_tool:
				btn_text += " (%d/%d)" % [item.durability, item.max_durability]
			btn.text = btn_text
			btn.icon = item.icon
			btn.tooltip_text = "%s (%s)\nClick to unequip" % [item.name, slot_friendly_names[slot_name]]
		else:
			btn.text = "%s: Empty" % slot_friendly_names[slot_name]
			btn.icon = null
			btn.tooltip_text = "Empty %s slot" % slot_friendly_names[slot_name]

func on_equipment_slot_pressed(hud: GameHUD, slot_name: String) -> void:
	if not hud._active_player or not hud._active_player.has_node("EquipmentComponent"):
		return
		
	var eq = hud._active_player.get_node("EquipmentComponent")
	var item = eq.call("get_equipped_item", slot_name) as ItemData
	if not item:
		return
		
	# Safe Capacity Reduction Guard
	if item.capacity_bonus > 0:
		var new_capacity: int = GameState.player_inventory.max_slots - item.capacity_bonus
		if GameState.player_inventory.slots.size() > new_capacity:
			hud.spawn_floating_text("Inventory too full to unequip!", hud.inventory_window.global_position + hud.inventory_window.size / 2.0)
			return
			
	open_confirm_prompt(hud, "Unequip Item", "Unequip %s?" % item.name, func():
		eq.call("unequip_item", slot_name)
		GameState.player_inventory.add_item(item, 1)
		hud._active_player.recalculate_equipment_stats()
		hud.update_inventory_panel()
	)

func on_inventory_slot_interacted(hud: GameHUD, item: ItemData, slot_panel: PanelContainer = null) -> void:
	if not item:
		return
	_show_slot_context_popup(hud, item, slot_panel)

func _init_context_popup(hud: GameHUD) -> void:
	if context_popup:
		return
		
	var popup = PanelContainer.new()
	popup.name = "SlotContextPopup"
	popup.custom_minimum_size = Vector2(120, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.24, 0.52, 0.85, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	popup.add_child(vbox)
	
	hud.add_child(popup)
	popup.hide()
	context_popup = popup

func _show_slot_context_popup(hud: GameHUD, item: ItemData, slot_panel: PanelContainer) -> void:
	if not context_popup:
		_init_context_popup(hud)
		
	var vbox = context_popup.get_node("VBox") as VBoxContainer
	for child in vbox.get_children():
		child.queue_free()
		
	var is_equipable = item.equipment_slot != "None"
	var is_skill_book = item is SkillBook
	var is_consumable = item.get_item_category() == 4
	
	var first_focus_btn = null
	
	if is_skill_book:
		var use_btn = Button.new()
		use_btn.text = "Read Book"
		use_btn.pressed.connect(func():
			context_popup.hide()
			_use_skill_book(hud, item as SkillBook)
		)
		vbox.add_child(use_btn)
		first_focus_btn = use_btn
	elif is_equipable:
		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.pressed.connect(func():
			context_popup.hide()
			_equip_item(hud, item)
		)
		vbox.add_child(equip_btn)
		first_focus_btn = equip_btn
	elif is_consumable:
		var consume_btn = Button.new()
		consume_btn.text = "Consume"
		consume_btn.pressed.connect(func():
			context_popup.hide()
			_consume_item(hud, item)
		)
		vbox.add_child(consume_btn)
		first_focus_btn = consume_btn
		
	var more_data_btn = Button.new()
	more_data_btn.text = "More Data"
	more_data_btn.pressed.connect(func():
		context_popup.hide()
		_show_more_data_dialog(hud, item)
	)
	vbox.add_child(more_data_btn)
	if not first_focus_btn:
		first_focus_btn = more_data_btn
		
	var delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(func():
		context_popup.hide()
		open_confirm_prompt(hud, "Delete Item", "Permanently delete 1 unit of %s?" % item.name, func():
			GameState.player_inventory.remove_item(item.id, 1)
		)
	)
	vbox.add_child(delete_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func():
		context_popup.hide()
	)
	vbox.add_child(cancel_btn)
	
	# Style buttons
	for child in vbox.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(100, 24)
			child.add_theme_font_size_override("font_size", 9)
			hud.call("_setup_button_hover", child)
			
	context_popup.show()
	
	var target_panel = slot_panel
	if not target_panel:
		var focused = hud.get_viewport().gui_get_focus_owner()
		if focused is PanelContainer:
			target_panel = focused
			
	if target_panel:
		context_popup.global_position = target_panel.global_position + Vector2(72, 0)
	else:
		context_popup.global_position = hud.inventory_window.global_position + (hud.inventory_window.size / 2.0) - (context_popup.size / 2.0)
		
	var screen_size = hud.get_viewport_rect().size
	if context_popup.global_position.x + context_popup.size.x > screen_size.x:
		if target_panel:
			context_popup.global_position.x = target_panel.global_position.x - context_popup.size.x - 8
	if context_popup.global_position.y + context_popup.size.y > screen_size.y:
		context_popup.global_position.y = screen_size.y - context_popup.size.y - 8
		
	if first_focus_btn:
		first_focus_btn.grab_focus()

func _equip_item(hud: GameHUD, item: ItemData) -> void:
	if not hud._active_player:
		return
	var eq = hud._active_player.get_node_or_null("EquipmentComponent")
	if not eq:
		return
		
	var slot_name = item.equipment_slot.to_lower()
	var prev_equipped = eq.call("get_equipped_item", slot_name) as ItemData
	if prev_equipped:
		var would_free_slot = (GameState.player_inventory.get_item_amount(item.id) == 1)
		if not would_free_slot:
			if GameState.player_inventory.get_free_space_for_item(prev_equipped) <= 0:
				hud.spawn_floating_text("Bag is full, cannot swap!", hud._active_player.global_position)
				return
				
	open_confirm_prompt(hud, "Equip Item", "Equip %s?" % item.name, func():
		GameState.player_inventory.remove_item(item.id, 1)
		var prev = eq.call("equip_item", slot_name, item) as ItemData
		if prev:
			GameState.player_inventory.add_item(prev, 1)
		hud._active_player.recalculate_equipment_stats()
	)

func _consume_item(hud: GameHUD, item: ItemData) -> void:
	GameState.player_inventory.remove_item(item.id, 1)
	var spawn_pos = hud._active_player.global_position if hud._active_player else hud.inventory_window.global_position
	hud.spawn_floating_text("Consumed 1 %s" % item.name, spawn_pos)
	hud.update_inventory_panel()

func _show_more_data_dialog(hud: GameHUD, item: ItemData) -> void:
	var desc_text = "Category: %s\n" % item.category
	desc_text += "Base Value: %d Gold\n" % item.base_value
	if item.description != "":
		desc_text += "Description: %s\n" % item.description
	if item.equipment_slot != "None":
		desc_text += "Equipment Slot: %s\n" % item.equipment_slot
		if item.attack_stat != 0:
			desc_text += "Attack Bonus: %+d\n" % item.attack_stat
		if item.armor_stat != 0:
			desc_text += "Armor Bonus: %+d\n" % item.armor_stat
		if item.speed_bonus != 0.0:
			desc_text += "Speed Bonus: %+d%%\n" % int(item.speed_bonus * 100)
		if item.gathering_multiplier_bonus != 0.0:
			desc_text += "Gathering Bonus: %+d%%\n" % int(item.gathering_multiplier_bonus * 100)
			
	open_confirm_prompt(hud, item.name + " Specifications", desc_text, func(): pass, "Close", "")

func _init_confirm_popup(hud: GameHUD) -> void:
	if confirm_popup:
		return
		
	var popup = PanelContainer.new()
	popup.name = "ConfirmPopup"
	popup.custom_minimum_size = Vector2(250, 120)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_color = Color(0.24, 0.52, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)
	
	var title = Label.new()
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.name = "DescLabel"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 10)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	var buttons = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)
	
	var yes_btn = Button.new()
	yes_btn.name = "YesButton"
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(60, 24)
	yes_btn.add_theme_font_size_override("font_size", 10)
	yes_btn.focus_mode = Control.FOCUS_ALL
	buttons.add_child(yes_btn)
	hud.call("_setup_button_hover", yes_btn)
	
	var no_btn = Button.new()
	no_btn.name = "NoButton"
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(60, 24)
	no_btn.add_theme_font_size_override("font_size", 10)
	no_btn.focus_mode = Control.FOCUS_ALL
	buttons.add_child(no_btn)
	hud.call("_setup_button_hover", no_btn)
	
	hud.add_child(popup)
	popup.hide()
	confirm_popup = popup

func open_confirm_prompt(hud: GameHUD, title_text: String, desc_text: String, confirm_callback: Callable, yes_text: String = "Yes", no_text: String = "No") -> void:
	if not confirm_popup:
		_init_confirm_popup(hud)
	if not confirm_popup:
		return
		
	var title_lbl = confirm_popup.find_child("TitleLabel", true, false) as Label
	var desc_lbl = confirm_popup.find_child("DescLabel", true, false) as Label
	var yes_btn = confirm_popup.find_child("YesButton", true, false) as Button
	var no_btn = confirm_popup.find_child("NoButton", true, false) as Button
	
	title_lbl.text = title_text
	desc_lbl.text = desc_text
	yes_btn.text = yes_text
	no_btn.text = no_text
	no_btn.visible = (no_text != "")
	_popup_confirm_callback = confirm_callback
	
	for conn in yes_btn.pressed.get_connections():
		yes_btn.pressed.disconnect(conn.callable)
	for conn in no_btn.pressed.get_connections():
		no_btn.pressed.disconnect(conn.callable)
		
	yes_btn.pressed.connect(func():
		confirm_popup.hide()
		_popup_confirm_callback.call()
		hud.update_inventory_panel()
	)
	no_btn.pressed.connect(func():
		confirm_popup.hide()
		hud.update_inventory_panel()
	)
	
	confirm_popup.show()
	confirm_popup.global_position = hud.inventory_window.global_position + (hud.inventory_window.size / 2.0) - (confirm_popup.size / 2.0)
	yes_btn.grab_focus()

func _init_employee_selection_popup(hud: GameHUD) -> void:
	if employee_popup:
		return
		
	var popup = PanelContainer.new()
	popup.name = "EmployeeSelectionPopup"
	popup.custom_minimum_size = Vector2(320, 240)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_color = Color(0.24, 0.52, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "Select Employee to Train"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(scroll)
	
	var list = VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Cancel"
	close_btn.custom_minimum_size = Vector2(80, 24)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): popup.hide())
	vbox.add_child(close_btn)
	hud.call("_setup_button_hover", close_btn)
	
	hud.add_child(popup)
	popup.hide()
	employee_popup = popup

func _init_trait_replacement_popup(hud: GameHUD) -> void:
	if trait_replacement_popup:
		return
		
	var popup = PanelContainer.new()
	popup.name = "TraitReplacementPopup"
	popup.custom_minimum_size = Vector2(300, 180)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_color = Color(0.85, 0.24, 0.24, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "Max Traits Reached"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.name = "DescLabel"
	desc.text = "Select which active trait to permanently replace:"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 10)
	vbox.add_child(desc)
	
	var button_container = VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.add_theme_constant_override("separation", 6)
	vbox.add_child(button_container)
	
	var cancel_btn = Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 24)
	cancel_btn.add_theme_font_size_override("font_size", 10)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(func(): popup.hide())
	vbox.add_child(cancel_btn)
	hud.call("_setup_button_hover", cancel_btn)
	
	hud.add_child(popup)
	popup.hide()
	trait_replacement_popup = popup

func _use_skill_book(hud: GameHUD, book: SkillBook) -> void:
	if not employee_popup:
		_init_employee_selection_popup(hud)
		
	_selected_skill_book = book
	
	var list = employee_popup.find_child("List", true, false) as VBoxContainer
	for child in list.get_children():
		child.queue_free()
		
	var all_hired_employees = []
	var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	for grp in production_groups:
		for node in hud.get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and "hired_employees" in node:
				for emp in node.hired_employees:
					var npc = emp.get("npc_ref")
					if is_instance_valid(npc) and "character_resource" in npc and npc.character_resource:
						all_hired_employees.append({
							"emp_dict": emp,
							"npc": npc,
							"building": node
						})
						
	if all_hired_employees.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No hired employees to apply book to."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 10)
		list.add_child(empty_lbl)
	else:
		for item in all_hired_employees:
			var emp_dict = item["emp_dict"]
			var npc = item["npc"]
			var building = item["building"]
			
			var btn = Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 30)
			
			var char_res = npc.character_resource as CharacterResource
			var workshop_id = char_res.assigned_workshop_id
			if workshop_id == "":
				workshop_id = building.name
				
			btn.text = "%s (Workshop: %s)" % [emp_dict.get("name", "Worker"), workshop_id]
			btn.add_theme_font_size_override("font_size", 10)
			
			btn.pressed.connect(func():
				employee_popup.hide()
				_apply_skill_book_to_employee(hud, npc, book)
			)
			list.add_child(btn)
			hud.call("_setup_button_hover", btn)
			
	employee_popup.show()
	employee_popup.global_position = hud.inventory_window.global_position + (hud.inventory_window.size / 2.0) - (employee_popup.size / 2.0)
	
	var close_btn = employee_popup.find_child("CloseButton", true, false) as Button
	close_btn.grab_focus()

func _apply_skill_book_to_employee(hud: GameHUD, npc: Node, book: SkillBook) -> void:
	var char_res = npc.character_resource as CharacterResource
	if not char_res:
		return
		
	if char_res.active_mods.size() < 2:
		char_res.active_mods.append(book.trait_id)
		char_res.update_daily_wage()
		_sync_npc_wage_to_building(npc)
		GameState.player_inventory.remove_item(book.id, 1)
		
		hud.spawn_floating_text("Applied %s to %s" % [book.name, npc.npc_name], npc.global_position)
		hud.update_inventory_panel()
	else:
		_show_trait_replacement_panel(hud, npc, book)

func _show_trait_replacement_panel(hud: GameHUD, npc: Node, book: SkillBook) -> void:
	if not trait_replacement_popup:
		_init_trait_replacement_popup(hud)
		
	var char_res = npc.character_resource as CharacterResource
	if not char_res:
		return
		
	var button_container = trait_replacement_popup.find_child("ButtonContainer", true, false) as VBoxContainer
	for child in button_container.get_children():
		child.queue_free()
		
	for i in range(char_res.active_mods.size()):
		var trait_id = char_res.active_mods[i]
		var btn = Button.new()
		btn.text = "Replace: %s" % trait_id
		btn.add_theme_font_size_override("font_size", 10)
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var idx = i
		btn.pressed.connect(func():
			trait_replacement_popup.hide()
			char_res.active_mods[idx] = book.trait_id
			char_res.update_daily_wage()
			_sync_npc_wage_to_building(npc)
			GameState.player_inventory.remove_item(book.id, 1)
			
			hud.spawn_floating_text("Replaced trait with %s for %s" % [book.name, npc.npc_name], npc.global_position)
			hud.update_inventory_panel()
		)
		button_container.add_child(btn)
		hud.call("_setup_button_hover", btn)
		
	trait_replacement_popup.show()
	trait_replacement_popup.global_position = hud.inventory_window.global_position + (hud.inventory_window.size / 2.0) - (trait_replacement_popup.size / 2.0)
	
	if button_container.get_child_count() > 0:
		button_container.get_child(0).grab_focus()

func _sync_npc_wage_to_building(npc: Node) -> void:
	if not is_instance_valid(npc): return
	var char_res = npc.character_resource as CharacterResource
	if not char_res: return
	
	if is_instance_valid(npc.get("hired_by_building")):
		var b = npc.hired_by_building
		if "hired_employees" in b:
			for emp in b.hired_employees:
				if emp.get("npc_ref") == npc:
					emp["salary"] = char_res.daily_wage
					emp["wage"] = char_res.daily_wage
					break

func link_inventory_grid_focus(hud: GameHUD, grid_container: GridContainer) -> void:
	if not grid_container:
		return
	var childs: Array = grid_container.get_children()
	var slots_count: int = childs.size()
	if slots_count == 0:
		return
		
	var cols: int = grid_container.columns
	var eq_slots: Array[Button] = [hud.head_slot, hud.body_slot, hud.gloves_slot, hud.weapon_slot, hud.tool_slot, hud.bag_slot, hud.necklace_slot, hud.ring_slot, hud.trans_slot]
	
	for i in range(slots_count):
		var slot = childs[i] as Control
		if slot and slot.focus_mode == Control.FOCUS_ALL:
			# Left neighbor
			if i % cols > 0:
				slot.focus_neighbor_left = slot.get_path_to(childs[i - 1])
			else:
				slot.focus_neighbor_left = slot.get_path()
			# Right neighbor
			if i % cols < cols - 1 and i + 1 < slots_count:
				slot.focus_neighbor_right = slot.get_path_to(childs[i + 1])
			else:
				# Rightmost column routes to equipment grid
				var row: int = i / cols
				var target_btn = eq_slots[min(row, eq_slots.size() - 1)]
				slot.focus_neighbor_right = slot.get_path_to(target_btn)
			# Top neighbor
			if i - cols >= 0:
				slot.focus_neighbor_top = slot.get_path_to(childs[i - cols])
			else:
				slot.focus_neighbor_top = slot.get_path()
			# Bottom neighbor
			if i + cols < slots_count:
				slot.focus_neighbor_bottom = slot.get_path_to(childs[i + cols])
			else:
				slot.focus_neighbor_bottom = slot.get_path()
				
	# Link equipment slots back to inventory grid and between themselves
	var eq_left: Array[Button] = [hud.head_slot, hud.gloves_slot, hud.tool_slot, hud.necklace_slot, hud.trans_slot]
	var eq_right: Array[Button] = [hud.body_slot, hud.weapon_slot, hud.bag_slot, hud.ring_slot]
	
	for row in range(eq_left.size()):
		var left_btn: Button = eq_left[row]
		var right_btn: Button = eq_right[row] if row < eq_right.size() else null
		
		var target_inv_idx: int = min(row * cols + 4, slots_count - 1)
		var target_inv_slot = childs[target_inv_idx] as Control
		if target_inv_slot and is_instance_valid(target_inv_slot):
			left_btn.focus_neighbor_left = left_btn.get_path_to(target_inv_slot)
			if right_btn:
				right_btn.focus_neighbor_left = right_btn.get_path_to(left_btn)
				left_btn.focus_neighbor_right = left_btn.get_path_to(right_btn)
			else:
				left_btn.focus_neighbor_right = left_btn.get_path()
				
		# Top & Bottom neighbors inside equipment grid
		if row > 0:
			left_btn.focus_neighbor_top = left_btn.get_path_to(eq_left[row - 1])
			if right_btn:
				var prev_right = eq_right[row - 1]
				if prev_right:
					right_btn.focus_neighbor_top = right_btn.get_path_to(prev_right)
		else:
			left_btn.focus_neighbor_top = left_btn.get_path()
			if right_btn:
				right_btn.focus_neighbor_top = right_btn.get_path()
				
		if row < eq_left.size() - 1:
			left_btn.focus_neighbor_bottom = left_btn.get_path_to(eq_left[row + 1])
			if right_btn:
				var next_right = eq_right[row + 1] if row + 1 < eq_right.size() else null
				if next_right:
					right_btn.focus_neighbor_bottom = right_btn.get_path_to(next_right)
				else:
					right_btn.focus_neighbor_bottom = right_btn.get_path_to(eq_left[row + 1])
		else:
			left_btn.focus_neighbor_bottom = left_btn.get_path()
			if right_btn:
				right_btn.focus_neighbor_bottom = right_btn.get_path()

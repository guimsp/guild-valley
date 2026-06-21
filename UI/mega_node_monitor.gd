extends PanelContainer

var target_node: Area2D = null

@onready var title_lbl: Label = %Title
@onready var resource_lbl: Label = %ResourceLbl
@onready var occupancy_lbl: Label = %OccupancyLbl
@onready var fee_lbl: Label = %FeeLbl
@onready var congestion_lbl: Label = %CongestionLbl
@onready var slots_container: VBoxContainer = %SlotsContainer
@onready var close_btn: Button = %CloseButton
@onready var gather_self_btn: Button = %GatherSelfBtn

var _update_timer: float = 0.5
var _style_slot: StyleBoxFlat

# Dynamic Gathering Popup
var gather_popup: PanelContainer = null
var gather_popup_step: int = 0
var selected_gather_item_id: String = ""

func _ready() -> void:
	_init_styles()
	close_btn.pressed.connect(_on_close_pressed)
	gather_self_btn.pressed.connect(_on_gather_self_pressed)
	
	# Apply micro-animation hover scaling to buttons
	_setup_button_effects(close_btn)
	_setup_button_effects(gather_self_btn)
	
	# Connect resized signals for correct scaling pivot
	resized.connect(func(): pivot_offset = size / 2.0)
	
	set_process(true)
	update_ui()

func _init_styles() -> void:
	_style_slot = StyleBoxFlat.new()
	_style_slot.bg_color = Color(0.16, 0.16, 0.22, 0.75)
	_style_slot.set_border_width_all(1)
	_style_slot.border_color = Color(0.35, 0.35, 0.45, 0.4)
	_style_slot.set_corner_radius_all(6)
	_style_slot.content_margin_left = 12
	_style_slot.content_margin_right = 12
	_style_slot.content_margin_top = 8
	_style_slot.content_margin_bottom = 8

func _process(delta: float) -> void:
	if not visible or not target_node:
		return
		
	_update_timer -= delta
	
	var player = get_tree().get_first_node_in_group("Player")
	var fast_update = player and player.get("is_harvesting") == true
	var rate = 0.1 if fast_update else 0.5
	
	if _update_timer <= 0.0:
		_update_timer = rate
		update_ui()

func update_ui() -> void:
	if not target_node:
		return
		
	title_lbl.text = target_node.node_name
	
	# Display mapped resource name
	var item_id = target_node.resource_type_id
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	var item_res = econ_mgr.item_database.get(item_id) if econ_mgr else null
	resource_lbl.text = "Resource: " + (item_res.name if item_res else item_id.capitalize())
	
	var occ = target_node.active_gatherers.size()
	var max_s = target_node.max_slots
	occupancy_lbl.text = "Occupancy: %d/%d" % [occ, max_s]
	
	var fee = target_node.get_entry_fee()
	fee_lbl.text = "Permit Fee: %d Gold" % fee
	
	var eff = int(target_node.get_congestion_factor() * 100.0)
	congestion_lbl.text = "Efficiency: %d%%" % eff
	
	# Recall Self vs Gather Personally
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		if player.get("is_harvesting") == true:
			var time_left_str = ""
			if player.has_meta("gather_time_left"):
				var seconds = int(ceil(player.get_meta("gather_time_left")))
				time_left_str = " (%ds left" % seconds
				var lm = get_node_or_null("/root/LogisticsManager")
				if lm:
					var amount = lm.get_buffer_amount(player)
					time_left_str += ", %d units" % amount
				time_left_str += ")"
			gather_self_btn.text = "Stop Gathering" + time_left_str
		else:
			gather_self_btn.text = "Gather Personally"
			
	# Update slots list
	_populate_slots()
	
	# Enforce WASD Directional Focus Bridges
	_wire_focus_neighbors()

func _populate_slots() -> void:
	# Keep track of focused index to restore focus after repopulation
	var focused_control = get_viewport().gui_get_focus_owner()
	var focused_slot_index = -1
	var focused_close = (focused_control == close_btn)
	var focused_gather = (focused_control == gather_self_btn)
	
	if focused_control and focused_control.get_parent() and focused_control.get_parent().get_parent() == slots_container:
		focused_slot_index = focused_control.get_parent().get_index()
		
	for child in slots_container.get_children():
		child.queue_free()
		
	var lm = get_node_or_null("/root/LogisticsManager")
	var occupants = target_node.active_gatherers
	
	for i in range(5):
		var slot_panel = PanelContainer.new()
		slot_panel.add_theme_stylebox_override("panel", _style_slot)
		
		var hbox = HBoxContainer.new()
		slot_panel.add_child(hbox)
		
		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12)
		hbox.add_child(label)
		
		if i < occupants.size():
			var occ = occupants[i]
			if not is_instance_valid(occ):
				label.text = "Empty Slot"
			else:
				var char_name = ""
				var owner_type = ""
				if occ.is_in_group("Player"):
					char_name = GameState.player_name
					owner_type = "Player"
				elif occ.is_in_group("Rivals"):
					char_name = occ.get("family_name") if occ.get("family_name") else "Rival Competitor"
					owner_type = "Rival"
				elif occ.is_in_group("GatheringWorkers"):
					char_name = occ.get("worker_name")
					owner_type = occ.get("owner_id")
					
				var amount = lm.get_buffer_amount(occ) if lm else 0
				label.text = "%s (%s) - Yielded: %d units" % [char_name, owner_type, amount]
				
				# Add recall/cancel button for player-owned characters
				if owner_type == "Player":
					var recall_btn = Button.new()
					recall_btn.text = "Recall & Collect"
					recall_btn.add_theme_font_size_override("font_size", 10)
					recall_btn.focus_mode = Control.FOCUS_ALL
					_setup_button_effects(recall_btn)
					
					recall_btn.pressed.connect(func():
						_recall_occupant(occ)
					)
					hbox.add_child(recall_btn)
		else:
			label.text = "Empty Slot"
			label.modulate = Color(0.6, 0.6, 0.6, 0.6)
			
		slots_container.add_child(slot_panel)
		
	# Restore focus safely
	if focused_slot_index != -1 and slots_container.get_child_count() > focused_slot_index:
		var slot_node = slots_container.get_child(focused_slot_index)
		var btn = slot_node.get_child(0).get_node_or_null("Button")
		if btn and btn.visible:
			btn.grab_focus()
	elif focused_close:
		close_btn.grab_focus()
	elif focused_gather:
		gather_self_btn.grab_focus()

func _recall_occupant(occupant: Node2D) -> void:
	if not is_instance_valid(occupant):
		return
		
	var lm = get_node_or_null("/root/LogisticsManager")
	if occupant.is_in_group("Player"):
		# Recall self
		occupant.set("is_harvesting", false)
		if target_node:
			target_node._on_body_exited(occupant)
		if lm:
			lm.collect_player_yield(occupant, target_node)
	elif occupant.is_in_group("GatheringWorkers"):
		# Recall hired employee
		if lm:
			lm.collect_worker_yield(occupant)
			# Safe cleanup: erase from buffer immediately before queue_free
			lm.erase_buffer(occupant)
		if occupant.has_method("recall"):
			occupant.recall()
			
	update_ui()

func _on_close_pressed() -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("toggle_window"):
		hud.toggle_window(self)

func _on_gather_self_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not target_node:
		return
		
	if player.get("is_harvesting") == true:
		# Stop personal harvesting
		player.set("is_harvesting", false)
		if player.has_meta("gather_time_left"):
			player.remove_meta("gather_time_left")
		target_node._on_body_exited(player)
		var lm = get_node_or_null("/root/LogisticsManager")
		if lm:
			lm.collect_player_yield(player, target_node)
	else:
		_open_gather_popup()
			
	update_ui()

func _open_gather_popup() -> void:
	if gather_popup:
		gather_popup.queue_free()
		
	gather_popup = PanelContainer.new()
	gather_popup.name = "GatherPopup"
	gather_popup.custom_minimum_size = Vector2(400, 320)
	gather_popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gather_popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	style.border_color = Color(0.24, 0.6, 0.86, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	gather_popup.add_theme_stylebox_override("panel", style)
	
	add_child(gather_popup)
	gather_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	gather_popup_step = 0
	_render_gather_popup_step()

func _render_gather_popup_step() -> void:
	if not gather_popup or not is_instance_valid(gather_popup):
		return
		
	for child in gather_popup.get_children():
		child.queue_free()
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	gather_popup.add_child(vbox)
	
	var title_lbl_pop = Label.new()
	title_lbl_pop.text = "Start Gathering Session"
	title_lbl_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl_pop.add_theme_font_size_override("font_size", 14)
	title_lbl_pop.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86, 1))
	vbox.add_child(title_lbl_pop)
	
	var content_area = VBoxContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_area)
	
	if gather_popup_step == 0:
		var prompt = Label.new()
		prompt.text = "Select Resource to Gather:"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.add_theme_font_size_override("font_size", 12)
		content_area.add_child(prompt)
		
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 160)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_area.add_child(scroll)
		
		var items_grid = GridContainer.new()
		items_grid.columns = 5
		items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_grid.add_theme_constant_override("h_separation", 6)
		items_grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(items_grid)
		
		var node_type = target_node.resource_type_id if target_node else "wheat"
		var items = []
		if node_type == "wheat":
			items = [
				{"id": "wheat", "name": "Wheat"},
				{"id": "sunflower", "name": "Sunflower"},
				{"id": "barley_and_hops", "name": "Barley & Hops"},
				{"id": "grapes", "name": "Grapes"},
				{"id": "apple", "name": "Apple"}
			]
		elif node_type == "iron_ore":
			items = [
				{"id": "iron_ore", "name": "Iron Ore"}
			]
		elif node_type == "cotton":
			items = [
				{"id": "cotton", "name": "Cotton"},
				{"id": "berries", "name": "Berries"},
				{"id": "honey", "name": "Honey"},
				{"id": "venison", "name": "Venison"}
			]
			
		var item_buttons = []
		for item in items:
			var card_btn = Button.new()
			card_btn.custom_minimum_size = Vector2(54, 60)
			card_btn.focus_mode = Control.FOCUS_ALL
			_setup_button_effects(card_btn)
			
			var card_style_normal = StyleBoxFlat.new()
			card_style_normal.bg_color = Color(0.14, 0.16, 0.20, 0.8)
			card_style_normal.border_color = Color(0.3, 0.35, 0.4, 0.6)
			card_style_normal.set_border_width_all(1)
			card_style_normal.set_corner_radius_all(4)
			
			var card_style_hover = card_style_normal.duplicate() as StyleBoxFlat
			card_style_hover.bg_color = Color(0.2, 0.24, 0.3, 0.9)
			card_style_hover.border_color = Color(0.24, 0.6, 0.86, 0.8)
			card_style_hover.set_border_width_all(1.2)
			
			var card_style_focused = card_style_hover.duplicate() as StyleBoxFlat
			card_style_focused.border_color = Color(0.24, 0.6, 0.86, 1.0)
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
			name_lbl.text = item["name"]
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			name_lbl.add_theme_font_size_override("font_size", 7)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_vbox.add_child(name_lbl)
			
			items_grid.add_child(card_btn)
			item_buttons.append(card_btn)
			
			card_btn.pressed.connect(func():
				selected_gather_item_id = item["id"]
				gather_popup_step = 1
				_render_gather_popup_step()
			)
			
		if item_buttons.size() > 0:
			item_buttons[0].call_deferred("grab_focus")
			
	elif gather_popup_step == 1:
		var prompt = Label.new()
		prompt.text = "Select Duration using A/D:"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.add_theme_font_size_override("font_size", 12)
		content_area.add_child(prompt)
		
		var econ_mgr = get_node_or_null("/root/EconomyManager")
		var item_name = selected_gather_item_id.capitalize()
		if econ_mgr and econ_mgr.item_database.has(selected_gather_item_id):
			item_name = econ_mgr.item_database[selected_gather_item_id].name
			
		var item_lbl = Label.new()
		item_lbl.text = "Target Resource: " + item_name
		item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_lbl.add_theme_font_size_override("font_size", 11)
		item_lbl.modulate = Color(0.4, 0.8, 1.0)
		content_area.add_child(item_lbl)
		
		var slider = HSlider.new()
		slider.min_value = 10
		slider.max_value = 60
		slider.step = 10
		slider.value = 30
		slider.custom_minimum_size = Vector2(240, 20)
		slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_ALL
		content_area.add_child(slider)
		
		var info_lbl = Label.new()
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.add_theme_font_size_override("font_size", 11)
		content_area.add_child(info_lbl)
		
		var update_yield_info = func(val: float):
			var duration = int(val)
			var ticks = duration / 3.0
			var congestion = target_node.get_congestion_factor() if target_node else 1.0
			var base_y = target_node.base_yield if target_node else 1.0
			var est_yield = int(floor(ticks * base_y * congestion))
			var fee = target_node.get_entry_fee() if target_node else 50
			info_lbl.text = "Duration: %d seconds\nEst. Yield: %d units\nPermit Fee: %d Gold" % [duration, est_yield, fee]
			
		update_yield_info.call(slider.value)
		slider.value_changed.connect(func(val):
			update_yield_info.call(val)
		)
		
		slider.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed:
				if event.keycode == KEY_A:
					slider.value = max(slider.min_value, slider.value - 10)
					get_viewport().set_input_as_handled()
				elif event.keycode == KEY_D:
					slider.value = min(slider.max_value, slider.value + 10)
					get_viewport().set_input_as_handled()
				elif event.is_action_pressed("ui_accept") or event.keycode == KEY_F:
					_confirm_gather_popup_stop(int(slider.value))
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
			_confirm_gather_popup_stop(int(slider.value))
		)
		cancel_btn.pressed.connect(func():
			_close_gather_popup()
		)
		
		slider.call_deferred("grab_focus")
		
	var footer_hbox = HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(footer_hbox)
	
	if gather_popup_step > 0:
		var back_btn = Button.new()
		back_btn.text = "< Back"
		back_btn.add_theme_font_size_override("font_size", 10)
		back_btn.custom_minimum_size = Vector2(60, 24)
		back_btn.focus_mode = Control.FOCUS_ALL
		_setup_button_effects(back_btn)
		footer_hbox.add_child(back_btn)
		back_btn.pressed.connect(func():
			gather_popup_step -= 1
			_render_gather_popup_step()
		)
		
	var close_btn_pop = Button.new()
	close_btn_pop.text = "Cancel"
	close_btn_pop.add_theme_font_size_override("font_size", 10)
	close_btn_pop.custom_minimum_size = Vector2(80, 24)
	close_btn_pop.focus_mode = Control.FOCUS_ALL
	_setup_button_effects(close_btn_pop)
	footer_hbox.add_child(close_btn_pop)
	close_btn_pop.pressed.connect(func():
		_close_gather_popup()
	)

func _confirm_gather_popup_stop(duration: int) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not target_node:
		_close_gather_popup()
		return
		
	if target_node.active_gatherers.size() >= target_node.max_slots:
		_shake_ui()
		_close_gather_popup()
		return
		
	var fee = target_node.get_entry_fee()
	if GameState.gold >= fee:
		GameState.gold -= fee
		player.set_meta("selected_gather_resource", selected_gather_item_id)
		player.set_meta("gather_duration", float(duration))
		player.set_meta("gather_time_left", float(duration))
		player.set("is_harvesting", true)
		target_node._on_body_entered(player)
		GameState.spawn_ui_floating_text("Paid Permit: -%d Gold!" % fee)
	else:
		_shake_ui()
		
	_close_gather_popup()
	update_ui()

func _close_gather_popup() -> void:
	if gather_popup:
		gather_popup.queue_free()
		gather_popup = null
	gather_self_btn.grab_focus()

# Hired employee deployment from mega nodes has been disabled per player feedback

func _setup_button_effects(btn: Button) -> void:
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.mouse_entered.connect(func():
		if not btn.disabled:
			create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
	)
	btn.mouse_exited.connect(func():
		create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)

func _shake_ui() -> void:
	modulate = Color(1.0, 0.4, 0.4)
	var orig_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position:x", orig_pos.x - 5, 0.05)
	tween.tween_property(self, "position:x", orig_pos.x + 5, 0.05)
	tween.tween_property(self, "position:x", orig_pos.x - 5, 0.05)
	tween.tween_property(self, "position:x", orig_pos.x, 0.05)
	
	await tween.finished
	modulate = Color(1.0, 1.0, 1.0)

func _wire_focus_neighbors() -> void:
	if is_instance_valid(close_btn) and close_btn.visible:
		gather_self_btn.focus_neighbor_right = close_btn.get_path()
		close_btn.focus_neighbor_left = gather_self_btn.get_path()
		close_btn.focus_neighbor_bottom = gather_self_btn.get_path()
		gather_self_btn.focus_neighbor_top = close_btn.get_path()
	
	var last_recall_path = NodePath()
	for child in slots_container.get_children():
		var btn = child.get_child(0).get_node_or_null("Button")
		if btn and btn.visible:
			if last_recall_path:
				var last_btn = get_node(last_recall_path)
				last_btn.focus_neighbor_bottom = btn.get_path()
				btn.focus_neighbor_top = last_recall_path
			else:
				btn.focus_neighbor_top = gather_self_btn.get_path()
			last_recall_path = btn.get_path()
			
	if last_recall_path:
		var last_btn = get_node(last_recall_path)
		last_btn.focus_neighbor_bottom = gather_self_btn.get_path()
		gather_self_btn.focus_neighbor_top = last_recall_path
		if is_instance_valid(close_btn) and close_btn.visible:
			close_btn.focus_neighbor_top = last_recall_path

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and is_instance_valid(focused) and is_ancestor_of(focused):
				if focused is Button:
					focused.pressed.emit()
					get_viewport().set_input_as_handled()
					return
					
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if gather_popup:
			_close_gather_popup()
		else:
			_on_close_pressed()

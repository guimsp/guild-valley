extends RefCounted

func open_rental_ui(hud: GameHUD, house: Node2D, detail_overlay: Control) -> void:
	if hud.windows_container:
		hud.windows_container.show()
		for child in hud.windows_container.get_children():
			(child as Control).hide()
			
	# Set size and styling on detail_overlay
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.24, 0.52, 0.85, 0.8) # Blue premium border
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	detail_overlay.add_theme_stylebox_override("panel", style)
	
	# Centering in windows_container
	detail_overlay.custom_minimum_size = Vector2(360, 240)
	detail_overlay.anchors_preset = Control.PRESET_CENTER
	detail_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	detail_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Clear children of detail_overlay and build
	for child in detail_overlay.get_children():
		detail_overlay.remove_child(child)
		child.queue_free()
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	detail_overlay.add_child(vbox)
	
	# Header Title
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var title = Label.new()
	var house_name: String = String(house.get("custom_name")) if house.get("custom_name") != null and String(house.get("custom_name")) != "" else "Rental House"
	title.text = "%s Status" % house_name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4)) # Gold title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	
	# Content Panel
	var content_panel = PanelContainer.new()
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(0.07, 0.08, 0.11, 0.8)
	content_style.set_corner_radius_all(6)
	content_style.content_margin_left = 12
	content_style.content_margin_right = 12
	content_style.content_margin_top = 10
	content_style.content_margin_bottom = 10
	content_panel.add_theme_stylebox_override("panel", content_style)
	vbox.add_child(content_panel)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 6)
	content_panel.add_child(content_vbox)
	
	# Status Row
	var status_label = Label.new()
	status_label.text = "Occupancy Status: "
	status_label.add_theme_font_size_override("font_size", 11)
	
	var is_occupied: bool = house.get("is_occupied") if house.get("is_occupied") != null else false
	var status_val = Label.new()
	status_val.text = "Occupied" if is_occupied else "Vacant"
	status_val.add_theme_font_size_override("font_size", 11)
	if is_occupied:
		status_val.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3)) # Green
	else:
		status_val.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2)) # Orange
		
	var status_row = HBoxContainer.new()
	status_row.add_child(status_label)
	status_row.add_child(status_val)
	content_vbox.add_child(status_row)
	
	# Tenant Row
	var tenant_label = Label.new()
	tenant_label.text = "Tenant: "
	tenant_label.add_theme_font_size_override("font_size", 11)
	
	var tenant_val = Label.new()
	tenant_val.text = "Simulated Resident" if is_occupied else "None (Looking for Tenant)"
	tenant_val.add_theme_font_size_override("font_size", 11)
	tenant_val.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	
	var tenant_row = HBoxContainer.new()
	tenant_row.add_child(tenant_label)
	tenant_row.add_child(tenant_val)
	content_vbox.add_child(tenant_row)
	
	# Rent Rate Row
	var rate_label = Label.new()
	rate_label.text = "Daily Rent Income: "
	rate_label.add_theme_font_size_override("font_size", 11)
	
	var rent_cost: int = int(house.get("rent_cost")) if house.get("rent_cost") != null else 0
	var rate_val = Label.new()
	rate_val.text = "%d Gold / day" % rent_cost if is_occupied else "N/A"
	rate_val.add_theme_font_size_override("font_size", 11)
	rate_val.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	
	var rate_row = HBoxContainer.new()
	rate_row.add_child(rate_label)
	rate_row.add_child(rate_val)
	content_vbox.add_child(rate_row)
	
	# Days Remaining Row
	var lease_label = Label.new()
	lease_label.text = "Lease Remaining: "
	lease_label.add_theme_font_size_override("font_size", 11)
	
	var rent_days_remaining: int = int(house.get("rent_days_remaining")) if house.get("rent_days_remaining") != null else 0
	var lease_val = Label.new()
	lease_val.text = "%d days" % rent_days_remaining if is_occupied else "N/A"
	lease_val.add_theme_font_size_override("font_size", 11)
	lease_val.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	
	var lease_row = HBoxContainer.new()
	lease_row.add_child(lease_label)
	lease_row.add_child(lease_val)
	content_vbox.add_child(lease_row)
	
	# Total Revenue Row
	var rev_label = Label.new()
	rev_label.text = "Total Rent Collected: "
	rev_label.add_theme_font_size_override("font_size", 11)
	
	var total_income_generated: int = int(house.get("total_income_generated")) if house.get("total_income_generated") != null else 0
	var rev_val = Label.new()
	rev_val.text = "%d Gold" % total_income_generated
	rev_val.add_theme_font_size_override("font_size", 11)
	rev_val.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	
	var rev_row = HBoxContainer.new()
	rev_row.add_child(rev_label)
	rev_row.add_child(rev_val)
	content_vbox.add_child(rev_row)
	
	# Buttons/Actions Container
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(buttons_hbox)
	
	var first_focused_btn: Button = null
	
	if not is_occupied:
		var enter_btn = Button.new()
		enter_btn.text = "Enter Property"
		enter_btn.focus_mode = Control.FOCUS_ALL
		enter_btn.add_theme_font_size_override("font_size", 11)
		buttons_hbox.add_child(enter_btn)
		hud._setup_button_hover(enter_btn)
		first_focused_btn = enter_btn
		
		enter_btn.pressed.connect(func():
			hud.windows_container.hide()
			detail_overlay.hide()
			if hud._active_player:
				hud._active_player.unfreeze()
			var entry_door = house.get("entry_door") as Node
			if entry_door and entry_door.has_method("_teleport"):
				entry_door.call("_teleport")
		)
		
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.add_theme_font_size_override("font_size", 11)
	buttons_hbox.add_child(close_btn)
	hud._setup_button_hover(close_btn)
	
	if not first_focused_btn:
		first_focused_btn = close_btn
		
	close_btn.pressed.connect(func():
		hud.windows_container.hide()
		detail_overlay.hide()
		if hud._active_player:
			hud._active_player.unfreeze()
	)
	
	detail_overlay.show()
	if hud._active_player:
		hud._active_player.freeze()
	if hud.interact_prompt:
		hud.interact_prompt.hide()
		
	# Scale animation
	detail_overlay.pivot_offset = detail_overlay.size / 2.0
	detail_overlay.scale = Vector2(0.9, 0.9)
	detail_overlay.modulate.a = 0.0
	var tween = hud.create_tween().set_parallel(true)
	tween.tween_property(detail_overlay, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(detail_overlay, "modulate:a", 1.0, 0.1)
	
	await hud.get_tree().process_frame
	if first_focused_btn:
		first_focused_btn.grab_focus()

extends PanelContainer

var current_province: String = "Valley Province"
var active_tab: String = "Elections"
var is_single_window: bool = false
var _countdown_labels: Array[Label] = []
var active_npc: Node2D = null

func set_active_npc(npc: Node2D) -> void:
	active_npc = npc

# References to UI elements
var title_lbl: Label
var status_lbl: Label
var main_content_hbox: HBoxContainer
var details_pane: PanelContainer
var tab_elections_btn: Button
var tab_donations_btn: Button
var tab_wholesalers_btn: Button
var tab_audits_btn: Button
var tabs_hbox: HBoxContainer

func _ready() -> void:
	add_to_group("GuildPanel")
	custom_minimum_size = Vector2(720, 520)
	
	# Apply glass blue style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.94)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.24, 0.60, 0.86, 0.75)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	add_theme_stylebox_override("panel", style)
	
	_build_ui_nodes()

func open(province_name: String, tab_name: String = "") -> void:
	current_province = province_name
	if tab_name != "":
		active_tab = tab_name
		is_single_window = true
		if is_instance_valid(tabs_hbox):
			tabs_hbox.hide()
	else:
		is_single_window = false
		if is_instance_valid(tabs_hbox):
			tabs_hbox.show()
		
	# Freeze player
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.freeze()
		
	show()
	_refresh_display()
	call_deferred("_focus_first_element")

func _on_close_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.unfreeze()
	queue_free()

func _build_ui_nodes() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(content_vbox)
	
	# Header
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(header)
	
	title_lbl = Label.new()
	title_lbl.text = "Seasonal Guild Conclave - " + current_province
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.60, 0.86))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)
	
	status_lbl = Label.new()
	status_lbl.text = "Conclave Loop"
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	header.add_child(status_lbl)
	
	var sep = HSeparator.new()
	content_vbox.add_child(sep)
	
	# Tabs
	tabs_hbox = HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 10)
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(tabs_hbox)
	
	tab_elections_btn = Button.new()
	tab_elections_btn.text = "Elections"
	_style_tab_btn(tab_elections_btn)
	tab_elections_btn.pressed.connect(func(): _switch_tab("Elections"))
	tabs_hbox.add_child(tab_elections_btn)
	
	tab_donations_btn = Button.new()
	tab_donations_btn.text = "Donations"
	_style_tab_btn(tab_donations_btn)
	tab_donations_btn.pressed.connect(func(): _switch_tab("Donations"))
	tabs_hbox.add_child(tab_donations_btn)
	
	tab_wholesalers_btn = Button.new()
	tab_wholesalers_btn.text = "Wholesaler Store"
	_style_tab_btn(tab_wholesalers_btn)
	tab_wholesalers_btn.pressed.connect(func(): _switch_tab("Wholesalers"))
	tabs_hbox.add_child(tab_wholesalers_btn)
	
	tab_audits_btn = Button.new()
	tab_audits_btn.text = "Audits / Edicts"
	_style_tab_btn(tab_audits_btn)
	tab_audits_btn.pressed.connect(func(): _switch_tab("Audits"))
	tabs_hbox.add_child(tab_audits_btn)
	
	# Main Content layout
	main_content_hbox = HBoxContainer.new()
	main_content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_content_hbox.add_theme_constant_override("separation", 16)
	content_vbox.add_child(main_content_hbox)
	
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# Centered Close Button at the bottom
	var footer_hbox = CenterContainer.new()
	footer_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(footer_hbox)
	
	var footer_close_btn = Button.new()
	footer_close_btn.text = "Close"
	footer_close_btn.custom_minimum_size = Vector2(120, 32)
	footer_close_btn.focus_mode = Control.FOCUS_NONE
	_setup_button_hover(footer_close_btn)
	footer_close_btn.pressed.connect(self._on_close_pressed)
	footer_hbox.add_child(footer_close_btn)

func _style_tab_btn(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(120, 32)
	btn.focus_mode = Control.FOCUS_NONE
	_setup_button_hover(btn)

func _setup_button_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.06)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.06)
	)

func _switch_tab(tab_name: String) -> void:
	active_tab = tab_name
	_refresh_display()
	call_deferred("_focus_first_element")

func _setup_two_pane_layout() -> GridContainer:
	# 1. Left VBox
	var left_vbox = VBoxContainer.new()
	left_vbox.name = "left_vbox"
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 10)
	main_content_hbox.add_child(left_vbox)
	
	# GridContainer for cards
	var grid = GridContainer.new()
	grid.name = "GridContainer"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(grid)
	
	# 2. Right Pane (Details Panel)
	details_pane = PanelContainer.new()
	details_pane.name = "details_pane"
	details_pane.custom_minimum_size = Vector2(300, 320)
	details_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var r_style = StyleBoxFlat.new()
	r_style.bg_color = Color(0.12, 0.16, 0.24, 0.6)
	r_style.set_corner_radius_all(8)
	r_style.set_border_width_all(1)
	r_style.border_color = Color(0.24, 0.60, 0.86, 0.4)
	r_style.content_margin_left = 14
	r_style.content_margin_right = 14
	r_style.content_margin_top = 14
	r_style.content_margin_bottom = 14
	details_pane.add_theme_stylebox_override("panel", r_style)
	
	main_content_hbox.add_child(details_pane)
	
	return grid

func _show_details_pane(title_text: String, desc_text: String, status_text: String, status_color: Color, action_callback: Callable = Callable()) -> void:
	# Prune any countdown labels that are about to be freed
	var active_countdown_labels: Array[Label] = []
	for lbl in _countdown_labels:
		if is_instance_valid(lbl) and not details_pane.is_ancestor_of(lbl):
			active_countdown_labels.append(lbl)
	_countdown_labels = active_countdown_labels

	for child in details_pane.get_children():
		child.queue_free()
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_pane.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)
	
	# Status Pill
	var pill = PanelContainer.new()
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = status_color
	pill_style.set_corner_radius_all(4)
	pill_style.content_margin_left = 8
	pill_style.content_margin_right = 8
	pill_style.content_margin_top = 4
	pill_style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", pill_style)
	
	var pill_lbl = Label.new()
	pill_lbl.text = status_text
	pill_lbl.add_theme_font_size_override("font_size", 9)
	pill_lbl.add_theme_color_override("font_color", Color.WHITE)
	pill.add_child(pill_lbl)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(pill)
	
	# Description
	var desc = Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)
	
	# Actions Container
	if action_callback.is_valid():
		var actions_vbox = VBoxContainer.new()
		actions_vbox.add_theme_constant_override("separation", 8)
		actions_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(actions_vbox)
		action_callback.call(actions_vbox)

func _refresh_display() -> void:
	# Save current focus if it belongs to the left grid
	var saved_focus_index = -1
	var in_left_grid = false
	var cur_focus = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if is_instance_valid(cur_focus) and is_instance_valid(main_content_hbox):
		var grid = main_content_hbox.get_node_or_null("left_vbox/GridContainer")
		if grid and grid.is_ancestor_of(cur_focus):
			saved_focus_index = cur_focus.get_index()
			in_left_grid = true

	if is_instance_valid(title_lbl):
		if is_single_window:
			match active_tab:
				"Elections":
					title_lbl.text = "Conclave Elections - " + current_province
				"Donations":
					title_lbl.text = "Province Donations - " + current_province
				"Wholesalers":
					title_lbl.text = "Wholesale Timed Bundles - " + current_province
				"Audits":
					title_lbl.text = "Edicts & Audits - " + current_province
		else:
			title_lbl.text = "Seasonal Guild Conclave - " + current_province

	# Style active button
	var active_color = Color(1.0, 0.85, 0.4) # Warm gold for active tab
	var inactive_color = Color(0.9, 0.9, 0.95)
	
	tab_elections_btn.add_theme_color_override("font_color", active_color if active_tab == "Elections" else inactive_color)
	tab_donations_btn.add_theme_color_override("font_color", active_color if active_tab == "Donations" else inactive_color)
	tab_wholesalers_btn.add_theme_color_override("font_color", active_color if active_tab == "Wholesalers" else inactive_color)
	tab_audits_btn.add_theme_color_override("font_color", active_color if active_tab == "Audits" else inactive_color)
	
	var conclave_day = ((TimeManager.time_days - 1) % 4) + 1
	status_lbl.text = "Day %d (Phase: %s)" % [conclave_day, "Campaigning" if conclave_day == 1 else "Office Active"]
	
	# Clear main_content_hbox
	if main_content_hbox.get_child_count() > 0:
		for child in main_content_hbox.get_children():
			main_content_hbox.remove_child(child)
			child.queue_free()
			
	# Render active tab
	match active_tab:
		"Elections":
			_render_elections()
		"Donations":
			_render_donations()
		"Wholesalers":
			_render_wholesalers()
		"Audits":
			_render_audits()

	# Restore focus if appropriate
	if in_left_grid and saved_focus_index != -1:
		await get_tree().process_frame
		var grid = main_content_hbox.get_node_or_null("left_vbox/GridContainer")
		if grid and saved_focus_index < grid.get_child_count():
			grid.get_child(saved_focus_index).grab_focus()

func _render_elections() -> void:
	var grid = _setup_two_pane_layout()
	var left_vbox = grid.get_parent() as VBoxContainer
	
	var gc = get_node_or_null("/root/GuildController")
	if not gc:
		return
		
	var info_lbl = Label.new()
	info_lbl.text = "Influence: %d | Prestige multiplier scales election votes." % GameState.influence
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	left_vbox.add_child(info_lbl)
	left_vbox.move_child(info_lbl, 0)
	
	var conclave_day = ((TimeManager.time_days - 1) % 4) + 1
	
	var bidding_callback = func(actions_vbox: VBoxContainer, off: String):
		var inf_lbl = Label.new()
		inf_lbl.text = "Available Influence: %d" % GameState.influence
		inf_lbl.add_theme_font_size_override("font_size", 10)
		inf_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		actions_vbox.add_child(inf_lbl)
		
		if conclave_day == 1:
			var candidates = gc.current_candidates[current_province][off]
			var player_is_cand = false
			for c in candidates:
				if c.name == "Player":
					player_is_cand = true
					break
			if player_is_cand:
				var your_bid = gc.active_bids[current_province][off].get("Player", 0)
				var bid_lbl = Label.new()
				bid_lbl.text = "Your Bid: %d Influence" % your_bid
				bid_lbl.add_theme_font_size_override("font_size", 10)
				actions_vbox.add_child(bid_lbl)
				
				var btn_hbox = HBoxContainer.new()
				btn_hbox.add_theme_constant_override("separation", 10)
				actions_vbox.add_child(btn_hbox)
				
				var bid_10_btn = Button.new()
				bid_10_btn.text = "+10 Inf"
				bid_10_btn.custom_minimum_size = Vector2(70, 26)
				_setup_button_hover(bid_10_btn)
				bid_10_btn.pressed.connect(func():
					if gc.place_player_bid(current_province, off, 10):
						_refresh_display()
						call_deferred("_focus_action_button", "+10 Inf")
				)
				btn_hbox.add_child(bid_10_btn)
				
				var bid_50_btn = Button.new()
				bid_50_btn.text = "+50 Inf"
				bid_50_btn.custom_minimum_size = Vector2(70, 26)
				_setup_button_hover(bid_50_btn)
				bid_50_btn.pressed.connect(func():
					if gc.place_player_bid(current_province, off, 50):
						_refresh_display()
						call_deferred("_focus_action_button", "+50 Inf")
				)
				btn_hbox.add_child(bid_50_btn)
			else:
				var req_lbl = Label.new()
				req_lbl.text = "Not eligible (check tier locks)"
				req_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
				req_lbl.add_theme_font_size_override("font_size", 10)
				actions_vbox.add_child(req_lbl)
		else:
			var status_desc = Label.new()
			status_desc.text = "Conclave resolved. Next campaigning open in %d days." % (5 - conclave_day)
			status_desc.add_theme_font_size_override("font_size", 10)
			status_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			status_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			actions_vbox.add_child(status_desc)
			
	var offices = ["Grand Chairman", "Logistics Overseer", "Materials Steward"]
	for i in range(offices.size()):
		var off = offices[i]
		var card_btn = Button.new()
		card_btn.text = off
		card_btn.add_theme_font_size_override("font_size", 9)
		card_btn.custom_minimum_size = Vector2(170, 36)
		card_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1, 0.14, 0.2, 0.7)
		btn_style.set_corner_radius_all(6)
		btn_style.set_border_width_all(1)
		btn_style.border_color = Color(0.24, 0.60, 0.86, 0.4)
		card_btn.add_theme_stylebox_override("normal", btn_style)
		card_btn.add_theme_stylebox_override("hover", btn_style)
		card_btn.add_theme_stylebox_override("focus", btn_style)
		
		card_btn.focus_entered.connect(func():
			var holder = gc.call("get_office_holder", current_province, off)
			var career = gc.call("get_office_career", current_province, off)
			var desc_text = ""
			match off:
				"Grand Chairman":
					desc_text = "• Guild Subsidy Edict: Reduces property tax by 15% for allied workshops; +5% competitors trade levy."
				"Logistics Overseer":
					desc_text = "• Transit Credentials: +5% speed to all automated cargo carts and couriers."
				"Materials Steward":
					desc_text = "• Materials Stewardship: 10% chance to refund 100% inputs upon workshop crafting."
			_show_details_pane(off, desc_text, "HOLDER: %s (%s)" % [holder, career.capitalize()], Color(0.9, 0.8, 0.4), bidding_callback.bind(off))
		)
		
		grid.add_child(card_btn)
		
	_focus_first_element()

func _render_donations() -> void:
	var grid = _setup_two_pane_layout()
	var left_vbox = grid.get_parent() as VBoxContainer
	
	var pm = get_node_or_null("/root/ProsperityManager")
	if not pm:
		return
		
	var current_prosperity = pm.province_prosperity.get(current_province, 100.0)
	var status = Label.new()
	status.text = "Prosperity: %.1f | Milestones unlock wholesaler store." % current_prosperity
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	left_vbox.add_child(status)
	left_vbox.move_child(status, 0)
	
	# Donation card list: Gold 100, Gold 500, Wheat, Cotton, Iron Ore
	var donations_list = [
		{ "type": "gold", "amount": 100, "prosperity": 5.0, "name": "Donate 100 Gold", "desc": "Donate 100 Gold to help Valley Province grow." },
		{ "type": "gold", "amount": 500, "prosperity": 25.0, "name": "Donate 500 Gold", "desc": "Donate 500 Gold to help Valley Province grow." },
		{ "type": "commodity", "id": "wheat", "amount": 5, "prosperity": 2.5, "name": "Donate 5 Wheat", "desc": "Donate 5 units of Wheat from your inventory." },
		{ "type": "commodity", "id": "cotton", "amount": 5, "prosperity": 2.5, "name": "Donate 5 Cotton", "desc": "Donate 5 units of Cotton from your inventory." },
		{ "type": "commodity", "id": "iron_ore", "amount": 5, "prosperity": 2.5, "name": "Donate 5 Iron Ore", "desc": "Donate 5 units of Iron Ore from your inventory." }
	]
	
	for i in range(donations_list.size()):
		var don = donations_list[i]
		var card_btn = Button.new()
		card_btn.text = don.name
		card_btn.add_theme_font_size_override("font_size", 9)
		card_btn.custom_minimum_size = Vector2(170, 36)
		card_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1, 0.14, 0.2, 0.7)
		btn_style.set_corner_radius_all(6)
		btn_style.set_border_width_all(1)
		btn_style.border_color = Color(0.24, 0.60, 0.86, 0.4)
		card_btn.add_theme_stylebox_override("normal", btn_style)
		card_btn.add_theme_stylebox_override("hover", btn_style)
		card_btn.add_theme_stylebox_override("focus", btn_style)
		
		card_btn.focus_entered.connect(func():
			var action_cb = func(actions_vbox: VBoxContainer):
				var donate_btn = Button.new()
				donate_btn.text = "Confirm Donation"
				donate_btn.custom_minimum_size = Vector2(160, 26)
				_setup_button_hover(donate_btn)
				
				# Check cost validation
				var can_afford = false
				if don.type == "gold":
					can_afford = GameState.gold >= don.amount
				else:
					can_afford = GameState.player_inventory.get_item_amount(don.id) >= don.amount
				
				if not can_afford:
					donate_btn.disabled = true
					
				donate_btn.pressed.connect(func():
					if don.type == "gold":
						if GameState.gold >= don.amount:
							GameState.gold -= don.amount
							pm.add_prosperity(current_province, don.prosperity)
							if is_instance_valid(active_npc) and active_npc.get("npc_runtime_state"):
								var local_state = active_npc.npc_runtime_state.local_state
								local_state["total_donated"] = local_state.get("total_donated", 0.0) + don.prosperity
							_refresh_display()
							call_deferred("_focus_action_button", "Confirm Donation")
						else:
							GameState.spawn_ui_floating_text("Insufficient Gold!")
					else:
						var has_qty = GameState.player_inventory.get_item_amount(don.id)
						if has_qty >= don.amount:
							GameState.player_inventory.remove_item(don.id, don.amount)
							pm.add_prosperity(current_province, don.prosperity)
							if is_instance_valid(active_npc) and active_npc.get("npc_runtime_state"):
								var local_state = active_npc.npc_runtime_state.local_state
								local_state["total_donated"] = local_state.get("total_donated", 0.0) + don.prosperity
							_refresh_display()
							call_deferred("_focus_action_button", "Confirm Donation")
						else:
							GameState.spawn_ui_floating_text("Insufficient quantity!")
				)
				actions_vbox.add_child(donate_btn)
				
			var cost_str = ""
			var status_color = Color(0.24, 0.60, 0.86)
			if don.type == "gold":
				cost_str = "COST: %d GOLD (You have: %d)" % [don.amount, GameState.gold]
			else:
				var has_qty = GameState.player_inventory.get_item_amount(don.id)
				cost_str = "INVENTORY: %d / %d %s" % [has_qty, don.amount, don.id.capitalize()]
				
			var details_desc = don.desc + "\n\nGain +%.1f Province Prosperity." % don.prosperity
			_show_details_pane(don.name, details_desc, cost_str, status_color, action_cb)
		)
		
		grid.add_child(card_btn)
		
	_focus_first_element()

func _render_wholesalers() -> void:
	var grid = _setup_two_pane_layout()
	var left_vbox = grid.get_parent() as VBoxContainer
	
	var pm = get_node_or_null("/root/ProsperityManager")
	var gc = get_node_or_null("/root/GuildController")
	if not pm or not gc:
		return
		
	var current_prosperity = pm.province_prosperity.get(current_province, 100.0)
	
	_countdown_labels.clear()
	
	var time_left_str = _format_time(gc.bundle_refresh_time_left)
	var timer_lbl = Label.new()
	timer_lbl.text = "Refreshes in: %s" % time_left_str
	timer_lbl.add_theme_font_size_override("font_size", 10)
	timer_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	left_vbox.add_child(timer_lbl)
	left_vbox.move_child(timer_lbl, 0)
	timer_lbl.set_meta("format_prefix", "Refreshes in: ")
	_countdown_labels.append(timer_lbl)
	
	var bundles_fallback = [
		{ "id": "iron_ore", "name": "Wholesale Iron Ore", "req": 30, "gold": 80, "influence": 5, "path": "Raw Materials" },
		{ "id": "iron_ingot", "name": "Wholesale Iron Ingot", "req": 60, "gold": 200, "influence": 15, "path": "Semi-Elaborate" },
		{ "id": "cloth", "name": "Wholesale Cloth", "req": 100, "gold": 350, "influence": 30, "path": "Semi-Elaborate" }
	]
	var bundles = bundles_fallback
	if is_instance_valid(active_npc) and active_npc.get("npc_runtime_state"):
		bundles = active_npc.npc_runtime_state.local_state.get("bundles_list", bundles_fallback)
	
	for i in range(bundles.size()):
		var b = bundles[i]
		var card_btn = Button.new()
		card_btn.text = b.name
		card_btn.add_theme_font_size_override("font_size", 9)
		card_btn.custom_minimum_size = Vector2(170, 36)
		card_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1, 0.14, 0.2, 0.7)
		btn_style.set_corner_radius_all(6)
		btn_style.set_border_width_all(1)
		
		var is_purchased = false
		if is_instance_valid(active_npc) and active_npc.get("npc_runtime_state"):
			is_purchased = active_npc.npc_runtime_state.local_state.get("purchased_bundles", {}).get(b.id, false)
		else:
			is_purchased = gc.purchased_bundles.get(b.id, false)
			
		var is_locked = current_prosperity < b.req
		if is_locked:
			btn_style.border_color = Color(0.6, 0.2, 0.2, 0.4)
		elif is_purchased:
			btn_style.border_color = Color(0.5, 0.5, 0.5, 0.4)
		else:
			btn_style.border_color = Color(0.2, 0.6, 0.3, 0.6)
			
		card_btn.add_theme_stylebox_override("normal", btn_style)
		card_btn.add_theme_stylebox_override("hover", btn_style)
		card_btn.add_theme_stylebox_override("focus", btn_style)
		
		card_btn.focus_entered.connect(func():
			var action_cb = func(actions_vbox: VBoxContainer):
				if is_locked:
					var lock_lbl = Label.new()
					lock_lbl.text = "Locked (Requires %d Prosperity)" % b.req
					lock_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
					lock_lbl.add_theme_font_size_override("font_size", 10)
					actions_vbox.add_child(lock_lbl)
				elif is_purchased:
					var sold_lbl = Label.new()
					sold_lbl.text = "Sold Out (Refreshes in %s)" % _format_time(gc.bundle_refresh_time_left)
					sold_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
					sold_lbl.add_theme_font_size_override("font_size", 10)
					actions_vbox.add_child(sold_lbl)
					sold_lbl.set_meta("format_prefix", "Sold Out (Refreshes in ")
					sold_lbl.set_meta("format_suffix", ")")
					_countdown_labels.append(sold_lbl)
				else:
					var buy_btn = Button.new()
					buy_btn.text = "Purchase Bundle"
					buy_btn.custom_minimum_size = Vector2(160, 26)
					_setup_button_hover(buy_btn)
					if GameState.gold < b.gold or GameState.influence < b.influence:
						buy_btn.disabled = true
					buy_btn.pressed.connect(func():
						if GameState.gold >= b.gold and GameState.influence >= b.influence:
							var item_res = load("res://common/items/instances/" + b.path + "/" + b.id + ".tres")
							if item_res:
								GameState.gold -= b.gold
								GameState.influence -= b.influence
								GameState.player_inventory.add_item(item_res, 10)
								if is_instance_valid(active_npc) and active_npc.get("npc_runtime_state"):
									var local_state = active_npc.npc_runtime_state.local_state
									if not local_state.has("purchased_bundles"):
										local_state["purchased_bundles"] = {}
									local_state["purchased_bundles"][b.id] = true
								else:
									gc.purchased_bundles[b.id] = true
								GameState.spawn_ui_floating_text("Purchased %s!" % b.name)
								_refresh_display()
								call_deferred("_focus_action_button", "Purchase Bundle")
						else:
							GameState.spawn_ui_floating_text("Cannot afford purchase!")
					)
					actions_vbox.add_child(buy_btn)
					
			var status_text = "AVAILABLE"
			var status_color = Color(0.2, 0.6, 0.3)
			if is_locked:
				status_text = "LOCKED"
				status_color = Color(0.6, 0.2, 0.2)
			elif is_purchased:
				status_text = "SOLD OUT"
				status_color = Color(0.5, 0.5, 0.5)
				
			var details_desc = b.name + " (x10) package.\nRequires %d Province Prosperity.\nCost: %d Gold + %d Influence." % [b.req, b.gold, b.influence]
			_show_details_pane(b.name, details_desc, status_text, status_color, action_cb)
		)
		
		grid.add_child(card_btn)
		
	_focus_first_element()

func _render_audits() -> void:
	var grid = _setup_two_pane_layout()
	var left_vbox = grid.get_parent() as VBoxContainer
	
	var gc = get_node_or_null("/root/GuildController")
	if not gc:
		return
		
	var status = Label.new()
	if gc.guild_audit_cooldown > 0.0:
		status.text = "Audit Cooldown: %.1f days." % gc.guild_audit_cooldown
		status.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	else:
		status.text = "Inspectors ready (Cost: 50 Influence)."
		status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	status.add_theme_font_size_override("font_size", 10)
	left_vbox.add_child(status)
	left_vbox.move_child(status, 0)
	
	var workshops = get_tree().get_nodes_in_group("production_buildings")
	var rival_workshops = []
	for w in workshops:
		if is_instance_valid(w) and w.ownership_type == "NPC" and w.owner_id == "Rival":
			var prov = GameState.get_province_of_node(w)
			if prov == current_province:
				rival_workshops.append(w)
				
	if rival_workshops.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No rival competitor workshops."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.add_theme_font_size_override("font_size", 10)
		grid.add_child(empty_lbl)
	else:
		for i in range(rival_workshops.size()):
			var w = rival_workshops[i]
			var card_btn = Button.new()
			card_btn.text = w.name.replace("Interior_", "")
			card_btn.add_theme_font_size_override("font_size", 9)
			card_btn.custom_minimum_size = Vector2(170, 36)
			card_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.1, 0.14, 0.2, 0.7)
			btn_style.set_corner_radius_all(6)
			btn_style.set_border_width_all(1)
			
			var is_audited = w.get("is_under_audit") == true
			if is_audited:
				btn_style.border_color = Color(0.9, 0.77, 0.31, 0.6)
			else:
				btn_style.border_color = Color(0.24, 0.60, 0.86, 0.4)
				
			card_btn.add_theme_stylebox_override("normal", btn_style)
			card_btn.add_theme_stylebox_override("hover", btn_style)
			card_btn.add_theme_stylebox_override("focus", btn_style)
			
			card_btn.focus_entered.connect(func():
				var action_cb = func(actions_vbox: VBoxContainer):
					if is_audited:
						var audit_lbl = Label.new()
						audit_lbl.text = "Audit in progress."
						audit_lbl.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31))
						audit_lbl.add_theme_font_size_override("font_size", 10)
						actions_vbox.add_child(audit_lbl)
					else:
						var audit_btn = Button.new()
						audit_btn.text = "Summon Inspector"
						audit_btn.custom_minimum_size = Vector2(160, 26)
						_setup_button_hover(audit_btn)
						if gc.guild_audit_cooldown > 0.0 or GameState.influence < 50:
							audit_btn.disabled = true
						audit_btn.pressed.connect(func():
							if GameState.influence >= 50:
								GameState.influence -= 50
								gc.summon_guild_inspector(w)
								_refresh_display()
								call_deferred("_focus_action_button", "Summon Inspector")
						)
						actions_vbox.add_child(audit_btn)
						
				var status_text = "READY"
				var status_color = Color(0.2, 0.6, 0.3)
				var details_desc = "Rival competitor: %s.\n\nSummoning an inspector costs 50 Influence, putting the workshop under audit for 12 hours (halting production and clearing storefront stock)." % w.name.replace("Interior_", "")
				if is_audited:
					status_text = "AUDITED"
					status_color = Color(0.9, 0.77, 0.31)
					details_desc += "\n\nRemaining time: %.1f hours." % w.audit_timer
				_show_details_pane(w.name.replace("Interior_", ""), details_desc, status_text, status_color, action_cb)
			)
			
			grid.add_child(card_btn)
			
	_focus_first_element()

func _focus_first_element() -> void:
	await get_tree().process_frame
	var grid = main_content_hbox.get_node_or_null("left_vbox/GridContainer")
	if grid and grid.get_child_count() > 0:
		var first = grid.get_child(0)
		if first is Control and first.focus_mode != Control.FOCUS_NONE:
			first.grab_focus()

func _focus_action_button(btn_text: String) -> void:
	var found = _find_button_by_text(details_pane, btn_text)
	if found:
		found.grab_focus()

func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found = _find_button_by_text(child, text)
		if found:
			return found
	return null

const TABS = ["Elections", "Donations", "Wholesalers", "Audits"]

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
		return
		
	if event.is_pressed() and not event.is_echo():
		if not is_single_window:
			if event.is_action_pressed("ui_page_up") or (event is InputEventKey and event.keycode == KEY_Q):
				var idx = TABS.find(active_tab)
				var next_idx = (idx - 1 + TABS.size()) % TABS.size()
				_switch_tab(TABS[next_idx])
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("ui_page_down") or (event is InputEventKey and event.keycode == KEY_E):
				var idx = TABS.find(active_tab)
				var next_idx = (idx + 1) % TABS.size()
				_switch_tab(TABS[next_idx])
				get_viewport().set_input_as_handled()
				return
				
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and is_instance_valid(focused) and is_ancestor_of(focused):
				if focused is Button:
					focused.pressed.emit()
					get_viewport().set_input_as_handled()
					return
					
		if event is InputEventKey:
			var key = event.keycode
			if key == KEY_W or key == KEY_S or key == KEY_A or key == KEY_D:
				var focused = get_viewport().gui_get_focus_owner()
				if not focused or not is_ancestor_of(focused):
					_focus_first_element()
					get_viewport().set_input_as_handled()
					return
					
				var action_name = ""
				match key:
					KEY_W: action_name = "ui_up"
					KEY_S: action_name = "ui_down"
					KEY_A: action_name = "ui_left"
					KEY_D: action_name = "ui_right"
					
				if action_name != "":
					var ev = InputEventAction.new()
					ev.action = action_name
					ev.pressed = true
					Input.parse_input_event(ev)
					get_viewport().set_input_as_handled()
					return

var _refresh_timer: float = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	if active_tab == "Wholesalers":
		_refresh_timer += delta
		if _refresh_timer >= 1.0:
			_refresh_timer = 0.0
			var gc = get_node_or_null("/root/GuildController")
			if gc:
				var time_left_str = _format_time(gc.bundle_refresh_time_left)
				for lbl in _countdown_labels:
					if is_instance_valid(lbl):
						var prefix = lbl.get_meta("format_prefix") if lbl.has_meta("format_prefix") else ""
						var suffix = lbl.get_meta("format_suffix") if lbl.has_meta("format_suffix") else ""
						lbl.text = prefix + time_left_str + suffix

func _format_time(seconds: float) -> String:
	var total_sec = int(max(0.0, seconds))
	var mins = total_sec / 60
	var secs = total_sec % 60
	return "%02d:%02d" % [mins, secs]

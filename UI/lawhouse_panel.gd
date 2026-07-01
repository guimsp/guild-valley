extends PanelContainer

var current_province: String = "Valley Province"
var active_tab: String = "ActiveLaws"
var active_npc: Node2D = null

func set_active_npc(npc: Node2D) -> void:
	active_npc = npc

# References to UI elements
var title_lbl: Label
var status_lbl: Label
var main_content_hbox: HBoxContainer
var details_pane: PanelContainer
var tab_active_btn: Button
var tab_sponsor_btn: Button
var tab_ballot_btn: Button
var tab_vote_btn: Button

# State variables for voting tab
var player_votes: Dictionary = {} # law_id -> bool (true = Pass, false = Fail)
var player_influence_spent: Dictionary = {} # law_id -> int

func _ready() -> void:
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
	_update_tabs_visibility()

func open(province_name: String) -> void:
	current_province = province_name
	player_votes.clear()
	player_influence_spent.clear()
	
	# Freeze player
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.freeze()
		
	show()
	_refresh_display()
	_focus_first_element()

func _on_close_pressed() -> void:
	hide()
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.unfreeze()

func _build_ui_nodes() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	# Margin Container for inner padding
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
	
	# 1. Header
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(header)
	
	title_lbl = Label.new()
	title_lbl.text = "Lawhouse Politics - " + current_province
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.60, 0.86))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)
	
	status_lbl = Label.new()
	status_lbl.text = "Phase: Idle"
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	header.add_child(status_lbl)
	
	# HSeparator
	var sep1 = HSeparator.new()
	content_vbox.add_child(sep1)
	
	# 2. Tabs
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 10)
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(tabs_hbox)
	
	tab_active_btn = Button.new()
	tab_active_btn.text = "Active Laws"
	_style_tab_btn(tab_active_btn)
	tab_active_btn.pressed.connect(func(): _switch_tab("ActiveLaws"))
	tabs_hbox.add_child(tab_active_btn)
	
	tab_sponsor_btn = Button.new()
	tab_sponsor_btn.text = "Sponsor Law"
	_style_tab_btn(tab_sponsor_btn)
	tab_sponsor_btn.pressed.connect(func(): _switch_tab("SponsorLaw"))
	tabs_hbox.add_child(tab_sponsor_btn)
	
	tab_ballot_btn = Button.new()
	tab_ballot_btn.text = "Current Ballot"
	_style_tab_btn(tab_ballot_btn)
	tab_ballot_btn.pressed.connect(func(): _switch_tab("CurrentBallot"))
	tabs_hbox.add_child(tab_ballot_btn)
	
	tab_vote_btn = Button.new()
	tab_vote_btn.text = "Cast Votes"
	_style_tab_btn(tab_vote_btn)
	tab_vote_btn.pressed.connect(func(): _switch_tab("CastVotes"))
	tabs_hbox.add_child(tab_vote_btn)
	
	# 3. Main Content Layout
	main_content_hbox = HBoxContainer.new()
	main_content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_content_hbox.add_theme_constant_override("separation", 16)
	content_vbox.add_child(main_content_hbox)
	
	# HSeparator
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# 4. Footer Close Button
	var close_btn = Button.new()
	close_btn.text = "Exit Chamber"
	close_btn.custom_minimum_size = Vector2(160, 34)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.focus_mode = Control.FOCUS_NONE
	_setup_button_hover(close_btn)
	close_btn.pressed.connect(_on_close_pressed)
	content_vbox.add_child(close_btn)

func _style_tab_btn(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(120, 30)
	btn.add_theme_font_size_override("font_size", 12)
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
	_update_tabs_visibility()
	_refresh_display()
	_focus_first_element()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
		
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
		return
		
	if event.is_pressed() and not event.is_echo():
		const TABS = ["ActiveLaws", "SponsorLaw", "CurrentBallot", "CastVotes"]
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

func _focus_first_element() -> void:
	await get_tree().process_frame
	var grid = main_content_hbox.get_node_or_null("left_vbox/GridContainer")
	if grid and grid.get_child_count() > 0:
		grid.get_child(0).grab_focus()

func _update_tabs_visibility() -> void:
	var active_color = Color(1.0, 0.85, 0.4) # Warm gold for active tab
	var inactive_color = Color(0.9, 0.9, 0.95)
	
	tab_active_btn.add_theme_color_override("font_color", active_color if active_tab == "ActiveLaws" else inactive_color)
	tab_sponsor_btn.add_theme_color_override("font_color", active_color if active_tab == "SponsorLaw" else inactive_color)
	tab_ballot_btn.add_theme_color_override("font_color", active_color if active_tab == "CurrentBallot" else inactive_color)
	tab_vote_btn.add_theme_color_override("font_color", active_color if active_tab == "CastVotes" else inactive_color)

func _refresh_display() -> void:
	title_lbl.text = "Lawhouse Politics - " + current_province
	
	var pm = get_node_or_null("/root/PoliticsManager")
	if not pm:
		status_lbl.text = "Politics Engine Offline"
		return
		
	var state = pm.province_states.get(current_province, {})
	var phase_id = state.get("current_phase", 0)
	
	var phase_str = "Idle"
	if phase_id == 1:
		phase_str = "Sponsorship Phase (Day 4 - Morning)"
	elif phase_id == 2:
		phase_str = "Ballot Assembly Phase (Day 4 - Midday)"
	elif phase_id == 3:
		phase_str = "Voting Phase (Day 4 - Evening)"
		
	status_lbl.text = "Current State: " + phase_str
	
	# Cache focus index before clearing
	var focused = get_viewport().gui_get_focus_owner()
	var focused_index = -1
	var in_left_grid = false
	if focused and is_instance_valid(focused) and main_content_hbox.is_ancestor_of(focused):
		var grid = main_content_hbox.get_node_or_null("left_vbox/GridContainer")
		if grid and grid.is_ancestor_of(focused):
			focused_index = focused.get_index()
			in_left_grid = true
			
	# Clear main_content_hbox
	for child in main_content_hbox.get_children():
		child.queue_free()
		
	# Clear any previous warning banner
	var content_vbox = main_content_hbox.get_parent()
	if content_vbox:
		var old_banner = content_vbox.get_node_or_null("TaxBanner")
		if old_banner:
			old_banner.queue_free()
			
	# Render the active tab
	match active_tab:
		"ActiveLaws":
			_render_active_laws_tab(pm)
		"SponsorLaw":
			_render_sponsor_tab(pm, phase_id, state)
		"CurrentBallot":
			_render_ballot_tab(pm, phase_id, state)
		"CastVotes":
			_render_voting_tab(pm, phase_id, state)
			
	# Restore focus if we were on the left grid
	if in_left_grid and focused_index != -1:
		await get_tree().process_frame
		var grid = main_content_hbox.get_node_or_null("left_vbox/GridContainer")
		if grid and focused_index < grid.get_child_count():
			grid.get_child(focused_index).grab_focus()

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

func _show_law_details(law_name: String, law_desc: String, status_text: String, status_color: Color, action_callback: Callable = Callable()) -> void:
	for child in details_pane.get_children():
		child.queue_free()
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_pane.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = law_name
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
	desc.text = law_desc
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

func _show_info_details(title_text: String, desc_text: String) -> void:
	var info_lbl = Label.new()
	info_lbl.text = desc_text
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_content_hbox.add_child(info_lbl)

func _show_tax_warning_banner(backlog: int, is_delinquent: bool, pm: Node) -> void:
	var content_vbox = main_content_hbox.get_parent()
	if not content_vbox:
		return
		
	var banner = PanelContainer.new()
	banner.name = "TaxBanner"
	var banner_style = StyleBoxFlat.new()
	banner_style.bg_color = Color(0.35, 0.08, 0.08, 0.9) if is_delinquent else Color(0.25, 0.18, 0.08, 0.9)
	banner_style.border_color = Color(0.8, 0.2, 0.2, 0.7) if is_delinquent else Color(0.7, 0.5, 0.2, 0.7)
	banner_style.set_border_width_all(1)
	banner_style.set_corner_radius_all(6)
	banner_style.content_margin_left = 12
	banner_style.content_margin_right = 12
	banner_style.content_margin_top = 8
	banner_style.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", banner_style)
	
	var banner_hbox = HBoxContainer.new()
	banner_hbox.add_theme_constant_override("separation", 10)
	banner_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.add_child(banner_hbox)
	
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_hbox.add_child(text_vbox)
	
	var banner_title = Label.new()
	banner_title.text = "⚠️ TAX DELINQUENCY WARNING" if is_delinquent else "⚠️ OUTSTANDING TAX BACKLOG"
	banner_title.add_theme_font_size_override("font_size", 11)
	banner_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8) if is_delinquent else Color(1.0, 0.9, 0.7))
	text_vbox.add_child(banner_title)
	
	var banner_desc = Label.new()
	banner_desc.text = "You owe %d Gold in seasonal taxes. " % backlog
	if is_delinquent:
		banner_desc.text += "Your structures in this province suffer -50% Attractiveness and -20% Productivity penalties!"
	else:
		banner_desc.text += "Pay this backlog to avoid delinquency penalties."
	banner_desc.add_theme_font_size_override("font_size", 10)
	banner_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(banner_desc)
	
	var pay_btn = Button.new()
	pay_btn.text = "Pay Backlog (%d Gold)" % backlog
	pay_btn.custom_minimum_size = Vector2(160, 24)
	pay_btn.add_theme_font_size_override("font_size", 10)
	pay_btn.focus_mode = Control.FOCUS_NONE
	_setup_button_hover(pay_btn)
	
	if GameState.gold < backlog:
		pay_btn.disabled = true
		
	pay_btn.pressed.connect(func():
		if pm.pay_player_backlog(current_province):
			_refresh_display()
	)
	banner_hbox.add_child(pay_btn)
	
	content_vbox.add_child(banner)
	content_vbox.move_child(banner, 2)

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

func _render_active_laws_tab(pm: Node) -> void:
	var grid = _setup_two_pane_layout()
	var state = pm.province_states.get(current_province, {})
	var active_laws = state.get("active_laws", {})
	
	var is_delinquent = pm.is_faction_delinquent("Player", current_province)
	var backlog = pm.tax_backlog.get(current_province, {}).get("Player", 0)
	if is_delinquent or backlog > 0:
		_show_tax_warning_banner(backlog, is_delinquent, pm)
		
	var active_list = []
	if active_laws.get("real_estate_levy_inc", false):
		active_list.append(pm.laws_db["real_estate_levy_inc"])
	elif active_laws.get("real_estate_levy_dec", false):
		active_list.append(pm.laws_db["real_estate_levy_dec"])
	else:
		active_list.append({"id": "real_estate_levy_default", "name": "Regular Real Estate Levy", "description": "Residential housing units pay standard flat-rate seasonal property taxes.", "is_default": true})
		
	if active_laws.get("hospitality_excise_tax", false):
		active_list.append(pm.laws_db["hospitality_excise_tax"])
	else:
		active_list.append({"id": "hospitality_excise_tax_default", "name": "Regular Production Tax 10%", "description": "Workshops, taverns, and inns pay the standard flat production tax shift rates.", "is_default": true})
		
	if active_laws.get("crown_forestry_protection", false):
		active_list.append(pm.laws_db["crown_forestry_protection"])
	else:
		active_list.append({"id": "forestry_default", "name": "Legal Logging", "description": "Timber harvesting is permitted on all public forest grounds without crown penalties.", "is_default": true})
		
	if active_laws.get("noble_game_preservation", false):
		active_list.append(pm.laws_db["noble_game_preservation"])
	else:
		active_list.append({"id": "hunting_default", "name": "Legal Hunting", "description": "Citizens are free to hunt wild game (venison) in designated forest regions.", "is_default": true})
		
	if active_laws.get("metallurgical_monopoly", false):
		active_list.append(pm.laws_db["metallurgical_monopoly"])
	else:
		active_list.append({"id": "mining_default", "name": "Legal Mining", "description": "Smelting and mineral refining are permitted throughout the province, including outposts and rural workshops.", "is_default": true})
		
	if active_laws.get("courier_curfew", false):
		active_list.append(pm.laws_db["courier_curfew"])
	else:
		active_list.append({"id": "curfew_default", "name": "Unrestricted Night Travel", "description": "No courier curfew is active. Commercial routes operate 24 hours a day without penalty.", "is_default": true})
		
	if active_laws.get("martial_carriage_ban", false):
		active_list.append(pm.laws_db["martial_carriage_ban"])
	else:
		active_list.append({"id": "carriage_default", "name": "Free Carriage of Arms", "description": "No ban on carrying swords outdoors is active. Carriage speed is normal.", "is_default": true})
		
	if active_laws.get("labor_welfare_mandate", false):
		active_list.append(pm.laws_db["labor_welfare_mandate"])
	else:
		active_list.append({"id": "labor_default", "name": "Unregulated Labor Market", "description": "Wages and working conditions are set by market rate. No welfare productivity penalties apply.", "is_default": true})
		
	if active_laws.get("usury_prohibition", false):
		active_list.append(pm.laws_db["usury_prohibition"])
	else:
		active_list.append({"id": "usury_default", "name": "Unregulated Interest Rates", "description": "Interest rates on bank loans are determined by bank operators without local caps.", "is_default": true})
		
	if active_laws.get("garrison_allocation_inc", false):
		active_list.append(pm.laws_db["garrison_allocation_inc"])
	elif active_laws.get("garrison_allocation_dec", false):
		active_list.append(pm.laws_db["garrison_allocation_dec"])
	else:
		active_list.append({"id": "garrison_default", "name": "Regular Garrison Patrols", "description": "Guards scan for active law violations with a standard 50% detection probability.", "is_default": true})

	for i in range(active_list.size()):
		var law = active_list[i]
		var card_btn = Button.new()
		card_btn.text = law.name
		card_btn.add_theme_font_size_override("font_size", 9)
		card_btn.custom_minimum_size = Vector2(170, 36)
		card_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1, 0.14, 0.2, 0.7)
		btn_style.set_corner_radius_all(6)
		btn_style.set_border_width_all(1)
		btn_style.border_color = Color(0.2, 0.8, 0.3, 0.6) if not law.get("is_default", false) else Color(0.24, 0.60, 0.86, 0.4)
		card_btn.add_theme_stylebox_override("normal", btn_style)
		card_btn.add_theme_stylebox_override("hover", btn_style)
		card_btn.add_theme_stylebox_override("focus", btn_style)
		
		card_btn.focus_entered.connect(func():
			_show_law_details(law.name, law.description, "ACTIVE", Color(0.1, 0.4, 0.15))
		)
		
		grid.add_child(card_btn)
		
	_focus_first_element()

func _render_sponsor_tab(pm: Node, phase: int, state: Dictionary) -> void:
	var grid = _setup_two_pane_layout()
	var active_laws = state.get("active_laws", {})
	var sponsored_law = state.get("sponsored_law")
	
	var sponsor_callback = func(actions_vbox: VBoxContainer, law: Dictionary):
		if sponsored_law != null:
			var info_lbl = Label.new()
			info_lbl.text = "Another bill is already sponsored for this session."
			info_lbl.add_theme_font_size_override("font_size", 10)
			info_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			actions_vbox.add_child(info_lbl)
			return
			
		if phase != 1:
			var locked_lbl = Label.new()
			locked_lbl.text = "Sponsorship is only open during the Morning (6:00 AM - 12:00 PM) of Legislative Day 4."
			locked_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			locked_lbl.add_theme_font_size_override("font_size", 10)
			locked_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			actions_vbox.add_child(locked_lbl)
			return
			
		var sponsor_btn = Button.new()
		sponsor_btn.text = "Sponsor Bill (-%d Influence)" % law.influence_cost
		sponsor_btn.add_theme_font_size_override("font_size", 11)
		sponsor_btn.custom_minimum_size = Vector2(180, 28)
		_setup_button_hover(sponsor_btn)
		
		if GameState.influence < law.influence_cost:
			sponsor_btn.disabled = true
			
		sponsor_btn.pressed.connect(func():
			if GameState.influence >= law.influence_cost:
				GameState.influence -= law.influence_cost
				pm.register_sponsored_law(current_province, law)
				_refresh_display()
		)
		actions_vbox.add_child(sponsor_btn)

	var eligible_laws = []
	for law_id in pm.laws_db:
		if not active_laws.get(law_id, false):
			eligible_laws.append(pm.laws_db[law_id])
			
	for i in range(eligible_laws.size()):
		var law = eligible_laws[i]
		var card_btn = Button.new()
		card_btn.text = law.name
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
		
		var is_currently_sponsored = (sponsored_law != null and sponsored_law.id == law.id)
		
		card_btn.focus_entered.connect(func():
			var status_text = "ELIGIBLE"
			var status_color = Color(0.24, 0.52, 0.85)
			if is_currently_sponsored:
				status_text = "SPONSORED BY YOU"
				status_color = Color(0.9, 0.77, 0.31)
			_show_law_details(law.name, law.description, status_text, status_color, sponsor_callback.bind(law))
		)
		
		grid.add_child(card_btn)
		
	_focus_first_element()

func _render_ballot_tab(pm: Node, phase: int, state: Dictionary) -> void:
	var grid = _setup_two_pane_layout()
	var ballot = state.get("current_ballot", [])
	
	if phase < 2:
		_show_info_details("Legislative Ballot", "The ballot has not been assembled yet. It will be built at Midday (12:00 PM).")
		return
		
	if ballot.is_empty():
		_show_info_details("Legislative Ballot", "No bills are sponsored for this session.")
		return
		
	for i in range(ballot.size()):
		var law = ballot[i]
		var card_btn = Button.new()
		card_btn.text = law.name
		card_btn.add_theme_font_size_override("font_size", 9)
		card_btn.custom_minimum_size = Vector2(170, 36)
		card_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1, 0.14, 0.2, 0.7)
		btn_style.set_corner_radius_all(6)
		btn_style.set_border_width_all(1)
		btn_style.border_color = Color(0.9, 0.77, 0.31, 0.6)
		card_btn.add_theme_stylebox_override("normal", btn_style)
		card_btn.add_theme_stylebox_override("hover", btn_style)
		card_btn.add_theme_stylebox_override("focus", btn_style)
		
		card_btn.focus_entered.connect(func():
			_show_law_details(law.name, law.description, "BALLOT", Color(0.9, 0.77, 0.31))
		)
		
		grid.add_child(card_btn)
		
	_focus_first_element()

func _render_voting_tab(pm: Node, phase: int, state: Dictionary) -> void:
	var ballot = state.get("current_ballot", [])
	
	if phase != 3:
		var history = state.get("votes_history", [])
		var history_text = ""
		if not history.is_empty():
			var last_vote = history[history.size() - 1]
			history_text = "Last Vote Results (Day %d):\n" % last_vote["day"]
			for l_id in last_vote["results"]:
				var res = last_vote["results"][l_id]
				history_text += "- %s: %s (Pass %d, Fail %d)\n" % [
					res["law_name"],
					"PASSED" if res["passed"] else "FAILED",
					res["pass_weight"],
					res["fail_weight"]
				]
		
		_show_info_details("Voting Session Closed", "Voting only takes place during the Evening (6:00 PM to 12:00 AM) of Legislative Day 4.\n\n" + history_text)
		return
		
	if ballot.is_empty():
		_show_info_details("Voting Session", "No bills on the ballot to vote for.")
		return
		
	var grid = _setup_two_pane_layout()
	var left_vbox = grid.get_parent() as VBoxContainer
	
	var sep = HSeparator.new()
	left_vbox.add_child(sep)
	
	var submit_btn = Button.new()
	submit_btn.text = "Cast Ballots & Resolve Session"
	submit_btn.custom_minimum_size = Vector2(240, 32)
	submit_btn.add_theme_font_size_override("font_size", 11)
	submit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_setup_button_hover(submit_btn)
	left_vbox.add_child(submit_btn)
	
	submit_btn.focus_entered.connect(func():
		var summary_text = "Summary of configured votes:\n\n"
		for b_law in ballot:
			var vote_choice = player_votes.get(b_law.id, true)
			var vote_inf = player_influence_spent.get(b_law.id, 0)
			var weight = 1 + int(vote_inf / 10)
			summary_text += "- %s: %s (Weight: %d, Influence: %d)\n" % [
				b_law.name,
				"PASS" if vote_choice else "FAIL",
				weight,
				vote_inf
			]
		_show_law_details("Resolve Voting Session", summary_text, "BALLOT READY", Color(0.9, 0.77, 0.31))
	)
	
	submit_btn.pressed.connect(func():
		var results = pm.resolve_voting_session(current_province, player_votes, player_influence_spent)
		player_votes.clear()
		player_influence_spent.clear()
		_switch_tab("ActiveLaws")
	)

	var vote_action_callback = func(actions_vbox: VBoxContainer, law: Dictionary):
		var inf_lbl = Label.new()
		inf_lbl.text = "Available Influence: %d" % GameState.influence
		inf_lbl.add_theme_font_size_override("font_size", 10)
		inf_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		actions_vbox.add_child(inf_lbl)
		
		var choice_hbox = HBoxContainer.new()
		choice_hbox.add_theme_constant_override("separation", 10)
		actions_vbox.add_child(choice_hbox)
		
		var pass_fail = player_votes.get(law.id, true)
		
		var pass_btn = Button.new()
		pass_btn.text = "PASS"
		pass_btn.custom_minimum_size = Vector2(70, 26)
		_setup_button_hover(pass_btn)
		choice_hbox.add_child(pass_btn)
		
		var fail_btn = Button.new()
		fail_btn.text = "FAIL"
		fail_btn.custom_minimum_size = Vector2(70, 26)
		_setup_button_hover(fail_btn)
		choice_hbox.add_child(fail_btn)
		
		if pass_fail:
			pass_btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			fail_btn.add_theme_color_override("font_color", Color.RED)
			
		pass_btn.pressed.connect(func():
			player_votes[law.id] = true
			_refresh_display()
			call_deferred("_focus_action_button", "PASS")
		)
		fail_btn.pressed.connect(func():
			player_votes[law.id] = false
			_refresh_display()
			call_deferred("_focus_action_button", "FAIL")
		)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		actions_vbox.add_child(spacer)
		
		var slider_hbox = HBoxContainer.new()
		slider_hbox.add_theme_constant_override("separation", 8)
		actions_vbox.add_child(slider_hbox)
		
		var inf_spent = player_influence_spent.get(law.id, 0)
		var weight_lbl = Label.new()
		weight_lbl.text = "Weight: %d (+%d Inf)" % [1 + int(inf_spent / 10), inf_spent]
		weight_lbl.add_theme_font_size_override("font_size", 10)
		slider_hbox.add_child(weight_lbl)
		
		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(22, 22)
		_setup_button_hover(minus_btn)
		slider_hbox.add_child(minus_btn)
		
		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(22, 22)
		_setup_button_hover(plus_btn)
		slider_hbox.add_child(plus_btn)
		
		minus_btn.pressed.connect(func():
			if inf_spent >= 10:
				GameState.influence += 10
				player_influence_spent[law.id] = inf_spent - 10
				_refresh_display()
				call_deferred("_focus_action_button", "-")
		)
		plus_btn.pressed.connect(func():
			if GameState.influence >= 10:
				GameState.influence -= 10
				player_influence_spent[law.id] = inf_spent + 10
				_refresh_display()
				call_deferred("_focus_action_button", "+")
		)

	for i in range(ballot.size()):
		var law = ballot[i]
		var card_btn = Button.new()
		card_btn.text = law.name
		card_btn.add_theme_font_size_override("font_size", 9)
		card_btn.custom_minimum_size = Vector2(170, 36)
		card_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1, 0.14, 0.2, 0.7)
		btn_style.set_corner_radius_all(6)
		btn_style.set_border_width_all(1)
		btn_style.border_color = Color(0.9, 0.77, 0.31, 0.6)
		card_btn.add_theme_stylebox_override("normal", btn_style)
		card_btn.add_theme_stylebox_override("hover", btn_style)
		card_btn.add_theme_stylebox_override("focus", btn_style)
		
		card_btn.focus_entered.connect(func():
			_show_law_details(law.name, law.description, "BALLOT", Color(0.9, 0.77, 0.31), vote_action_callback.bind(law))
		)
		
		grid.add_child(card_btn)
		
	_focus_first_element()

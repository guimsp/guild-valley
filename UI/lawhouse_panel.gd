extends PanelContainer

var current_province: String = "Valley Province"
var active_tab: String = "ActiveLaws"

# References to UI elements
var title_lbl: Label
var status_lbl: Label
var content_container: ScrollContainer
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
	
	# 3. Main Content Scroll
	content_container = ScrollContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_vbox.add_child(content_container)
	
	# HSeparator
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# 4. Footer Close Button
	var close_btn = Button.new()
	close_btn.text = "Exit Chamber"
	close_btn.custom_minimum_size = Vector2(160, 34)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_setup_button_hover(close_btn)
	close_btn.pressed.connect(_on_close_pressed)
	content_vbox.add_child(close_btn)

func _style_tab_btn(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(120, 30)
	btn.add_theme_font_size_override("font_size", 12)
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
	
	# Clear scroll container child
	for child in content_container.get_children():
		child.queue_free()
		
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 10)
	content_container.add_child(scroll_vbox)
	
	match active_tab:
		"ActiveLaws":
			_render_active_laws(scroll_vbox, pm)
		"SponsorLaw":
			_render_sponsor_tab(scroll_vbox, pm, phase_id, state)
		"CurrentBallot":
			_render_ballot_tab(scroll_vbox, pm, phase_id, state)
		"CastVotes":
			_render_voting_tab(scroll_vbox, pm, phase_id, state)

func _render_active_laws(parent: VBoxContainer, pm: Node) -> void:
	var state = pm.province_states.get(current_province, {})
	var active_laws = state.get("active_laws", {})
	
	# Delinquency status check
	var is_delinquent = pm.is_faction_delinquent("Player", current_province)
	var backlog = pm.tax_backlog.get(current_province, {}).get("Player", 0)
	
	if is_delinquent or backlog > 0:
		var banner = PanelContainer.new()
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
		
		var banner_vbox = VBoxContainer.new()
		banner_vbox.add_theme_constant_override("separation", 4)
		banner.add_child(banner_vbox)
		
		var banner_title = Label.new()
		banner_title.text = "⚠️ TAX DELINQUENCY WARNING" if is_delinquent else "⚠️ OUTSTANDING TAX BACKLOG"
		banner_title.add_theme_font_size_override("font_size", 12)
		banner_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8) if is_delinquent else Color(1.0, 0.9, 0.7))
		banner_vbox.add_child(banner_title)
		
		var banner_desc = Label.new()
		banner_desc.text = "You owe %d Gold in seasonal taxes. " % backlog
		if is_delinquent:
			banner_desc.text += "Your structures in this province suffer -50% Attractiveness and -20% Productivity penalties!"
		else:
			banner_desc.text += "Pay this backlog to avoid delinquency penalties at the next seasonal shift."
		banner_desc.add_theme_font_size_override("font_size", 11)
		banner_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner_vbox.add_child(banner_desc)
		
		var pay_btn = Button.new()
		pay_btn.text = "Pay Backlog (%d Gold)" % backlog
		pay_btn.custom_minimum_size = Vector2(160, 24)
		pay_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		pay_btn.add_theme_font_size_override("font_size", 10)
		_setup_button_hover(pay_btn)
		
		if GameState.gold < backlog:
			pay_btn.disabled = true
			
		pay_btn.pressed.connect(func():
			if pm.pay_player_backlog(current_province):
				_refresh_display()
		)
		banner_vbox.add_child(pay_btn)
		
		parent.add_child(banner)
		
		# Spacing
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		parent.add_child(spacer)
		
	var active_lbl = Label.new()
	active_lbl.text = "Enforced Laws & Policies:"
	active_lbl.add_theme_font_size_override("font_size", 13)
	active_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
	parent.add_child(active_lbl)
	
	# Grouped logic for Enforced Laws (combining active custom laws and default common laws)
	# 1. Real Estate Tax
	if active_laws.get("real_estate_levy_inc", false):
		parent.add_child(_create_law_card(pm.laws_db["real_estate_levy_inc"].name, pm.laws_db["real_estate_levy_inc"].description, true))
	elif active_laws.get("real_estate_levy_dec", false):
		parent.add_child(_create_law_card(pm.laws_db["real_estate_levy_dec"].name, pm.laws_db["real_estate_levy_dec"].description, true))
	else:
		parent.add_child(_create_law_card("Regular Real Estate Levy", "Residential housing units pay standard flat-rate seasonal property taxes.", true))
		
	# 2. Production Building Tax
	if active_laws.get("hospitality_excise_tax", false):
		parent.add_child(_create_law_card(pm.laws_db["hospitality_excise_tax"].name, pm.laws_db["hospitality_excise_tax"].description, true))
	else:
		parent.add_child(_create_law_card("Regular production building tax 10%", "Workshops, taverns, and inns pay the standard flat production tax shift rates.", true))
		
	# 3. Logging
	if active_laws.get("crown_forestry_protection", false):
		parent.add_child(_create_law_card(pm.laws_db["crown_forestry_protection"].name, pm.laws_db["crown_forestry_protection"].description, true))
	else:
		parent.add_child(_create_law_card("Legal Logging", "Timber harvesting is permitted on all public forest grounds without crown penalties.", true))
		
	# 4. Hunting
	if active_laws.get("noble_game_preservation", false):
		parent.add_child(_create_law_card(pm.laws_db["noble_game_preservation"].name, pm.laws_db["noble_game_preservation"].description, true))
	else:
		parent.add_child(_create_law_card("Legal hunting", "Citizens are free to hunt wild game (venison) in designated forest regions.", true))
		
	# 5. Mining
	if active_laws.get("metallurgical_monopoly", false):
		parent.add_child(_create_law_card(pm.laws_db["metallurgical_monopoly"].name, pm.laws_db["metallurgical_monopoly"].description, true))
	else:
		parent.add_child(_create_law_card("Legal mining", "Smelting and mineral refining are permitted throughout the province, including outposts and rural workshops.", true))
		
	# 6. Curfew
	if active_laws.get("courier_curfew", false):
		parent.add_child(_create_law_card(pm.laws_db["courier_curfew"].name, pm.laws_db["courier_curfew"].description, true))
	else:
		parent.add_child(_create_law_card("Unrestricted Night Travel", "No courier curfew is active. Commercial routes operate 24 hours a day without penalty.", true))
		
	# 7. Carriage Ban
	if active_laws.get("martial_carriage_ban", false):
		parent.add_child(_create_law_card(pm.laws_db["martial_carriage_ban"].name, pm.laws_db["martial_carriage_ban"].description, true))
	else:
		parent.add_child(_create_law_card("Free Carriage of Arms", "No ban on carrying swords outdoors is active. Carriage speed is normal.", true))
		
	# 8. Labor Welfare
	if active_laws.get("labor_welfare_mandate", false):
		parent.add_child(_create_law_card(pm.laws_db["labor_welfare_mandate"].name, pm.laws_db["labor_welfare_mandate"].description, true))
	else:
		parent.add_child(_create_law_card("Unregulated Labor Market", "Wages and working conditions are set by market rate. No welfare productivity penalties apply.", true))
		
	# 9. Usury
	if active_laws.get("usury_prohibition", false):
		parent.add_child(_create_law_card(pm.laws_db["usury_prohibition"].name, pm.laws_db["usury_prohibition"].description, true))
	else:
		parent.add_child(_create_law_card("Unregulated Interest Rates", "Interest rates on bank loans are determined by bank operators without local caps.", true))
		
	# 10. Garrison Allocation
	if active_laws.get("garrison_allocation_inc", false):
		parent.add_child(_create_law_card(pm.laws_db["garrison_allocation_inc"].name, pm.laws_db["garrison_allocation_inc"].description, true))
	elif active_laws.get("garrison_allocation_dec", false):
		parent.add_child(_create_law_card(pm.laws_db["garrison_allocation_dec"].name, pm.laws_db["garrison_allocation_dec"].description, true))
	else:
		parent.add_child(_create_law_card("Regular Garrison Patrols", "Guards scan for active law violations with a standard 50% detection probability.", true))
		
	# Spacing
	var sep = HSeparator.new()
	parent.add_child(sep)
	
	var inactive_lbl = Label.new()
	inactive_lbl.text = "Inactive Custom Laws / Bills:"
	inactive_lbl.add_theme_font_size_override("font_size", 13)
	inactive_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	parent.add_child(inactive_lbl)
	
	for law_id in pm.laws_db:
		if active_laws.get(law_id, false) == false:
			var law = pm.laws_db[law_id]
			var card = _create_law_card(law.name, law.description, false)
			parent.add_child(card)

func _render_sponsor_tab(parent: VBoxContainer, pm: Node, phase: int, state: Dictionary) -> void:
	var sponsored_law = state.get("sponsored_law")
	
	if sponsored_law != null:
		var lbl = Label.new()
		lbl.text = "Your Sponsored Bill for this session:"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.24, 0.60, 0.86))
		parent.add_child(lbl)
		
		var card = _create_law_card(sponsored_law.name, sponsored_law.description, false)
		parent.add_child(card)
		
		var info_lbl = Label.new()
		info_lbl.text = "The bill has been registered and will appear on the ballot during Ballot Assembly at midday."
		info_lbl.add_theme_font_size_override("font_size", 11)
		info_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		parent.add_child(info_lbl)
		return
		
	if phase != 1:
		var locked_lbl = Label.new()
		locked_lbl.text = "Sponsorship is only open during the Morning (6:00 AM to 12:00 PM) of the Legislative Day (Day 4 of the cycle)."
		locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		locked_lbl.add_theme_font_size_override("font_size", 12)
		parent.add_child(locked_lbl)
		return
		
	var lbl = Label.new()
	lbl.text = "Select a law to sponsor. Sponsoring requires Influence. (Available Influence: %d)" % GameState.influence
	lbl.add_theme_font_size_override("font_size", 13)
	parent.add_child(lbl)
	
	for law_id in pm.laws_db:
		var law = pm.laws_db[law_id]
		# Check if already active
		if state.get("active_laws", {}).get(law_id, false):
			continue
			
		var card = _create_law_card(law.name, law.description, false)
		var btn = Button.new()
		btn.text = "Sponsor Bill (-%d Influence)" % law.influence_cost
		btn.add_theme_font_size_override("font_size", 11)
		btn.custom_minimum_size = Vector2(180, 26)
		_setup_button_hover(btn)
		
		if GameState.influence < law.influence_cost:
			btn.disabled = true
			
		btn.pressed.connect(func():
			if GameState.influence >= law.influence_cost:
				GameState.influence -= law.influence_cost
				pm.register_sponsored_law(current_province, law)
				_refresh_display()
		)
		
		card.get_child(0).add_child(btn) # Add button to the HBox of the card
		parent.add_child(card)

func _render_ballot_tab(parent: VBoxContainer, pm: Node, phase: int, state: Dictionary) -> void:
	var ballot = state.get("current_ballot", [])
	
	if phase < 2:
		var info_lbl = Label.new()
		info_lbl.text = "The legislative ballot has not been assembled yet. It will be built at Midday (12:00 PM)."
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		parent.add_child(info_lbl)
		return
		
	var lbl = Label.new()
	lbl.text = "Ballot Bills Up for Vote in this session:"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31))
	parent.add_child(lbl)
	
	for law in ballot:
		var card = _create_law_card(law.name, law.description, false)
		parent.add_child(card)

func _render_voting_tab(parent: VBoxContainer, pm: Node, phase: int, state: Dictionary) -> void:
	var ballot = state.get("current_ballot", [])
	
	if phase != 3:
		# Check if we have voting history to show
		var history = state.get("votes_history", [])
		if not history.is_empty():
			var last_vote = history[history.size() - 1]
			var hist_lbl = Label.new()
			hist_lbl.text = "Last Vote Results (Day %d):" % last_vote["day"]
			hist_lbl.add_theme_font_size_override("font_size", 14)
			hist_lbl.add_theme_color_override("font_color", Color(0.24, 0.60, 0.86))
			parent.add_child(hist_lbl)
			
			for l_id in last_vote["results"]:
				var res = last_vote["results"][l_id]
				var r_lbl = Label.new()
				r_lbl.text = "Bill: %s - %s (Pass Weight: %d, Fail Weight: %d)" % [
					res["law_name"],
					"PASSED" if res["passed"] else "FAILED",
					res["pass_weight"],
					res["fail_weight"]
				]
				r_lbl.add_theme_font_size_override("font_size", 12)
				r_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4) if res["passed"] else Color(0.9, 0.4, 0.2))
				parent.add_child(r_lbl)
				
		var info_lbl = Label.new()
		info_lbl.text = "\nVoting only takes place during the Evening (6:00 PM to 12:00 AM) of the Legislative Day."
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		parent.add_child(info_lbl)
		return
		
	var lbl = Label.new()
	lbl.text = "Configure and Cast Votes. (Available Influence: %d)" % GameState.influence
	lbl.add_theme_font_size_override("font_size", 14)
	parent.add_child(lbl)
	
	for law in ballot:
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.12, 0.16, 0.24, 0.6)
		card_style.set_corner_radius_all(6)
		card_style.set_border_width_all(1)
		card_style.border_color = Color(0.2, 0.35, 0.5)
		card.add_theme_stylebox_override("panel", card_style)
		
		var inner_vbox = VBoxContainer.new()
		inner_vbox.add_theme_constant_override("separation", 8)
		card.add_child(inner_vbox)
		
		var title = Label.new()
		title.text = law.name
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		inner_vbox.add_child(title)
		
		var desc = Label.new()
		desc.text = law.description
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner_vbox.add_child(desc)
		
		var controls = HBoxContainer.new()
		controls.add_theme_constant_override("separation", 16)
		inner_vbox.add_child(controls)
		
		# Choice Yes/No Buttons
		var pass_fail = player_votes.get(law.id, true)
		
		var pass_btn = Button.new()
		pass_btn.text = "PASS"
		pass_btn.custom_minimum_size = Vector2(80, 26)
		_setup_button_hover(pass_btn)
		pass_btn.pressed.connect(func():
			player_votes[law.id] = true
			_refresh_display()
		)
		controls.add_child(pass_btn)
		
		var fail_btn = Button.new()
		fail_btn.text = "FAIL"
		fail_btn.custom_minimum_size = Vector2(80, 26)
		_setup_button_hover(fail_btn)
		fail_btn.pressed.connect(func():
			player_votes[law.id] = false
			_refresh_display()
		)
		controls.add_child(fail_btn)
		
		# Styling selected choices
		if pass_fail:
			pass_btn.add_theme_color_override("font_color", Color.GREEN)
			fail_btn.remove_theme_color_override("font_color")
		else:
			fail_btn.add_theme_color_override("font_color", Color.RED)
			pass_btn.remove_theme_color_override("font_color")
			
		# Influence Buy Weight Slider/Controls
		var inf_spent = player_influence_spent.get(law.id, 0)
		
		var weight_lbl = Label.new()
		weight_lbl.text = "Vote Weight: %d (+%d Influence)" % [1 + int(inf_spent / 10), inf_spent]
		weight_lbl.add_theme_font_size_override("font_size", 11)
		controls.add_child(weight_lbl)
		
		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(24, 24)
		minus_btn.pressed.connect(func():
			if inf_spent >= 10:
				GameState.influence += 10
				player_influence_spent[law.id] = inf_spent - 10
				_refresh_display()
		)
		controls.add_child(minus_btn)
		
		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(24, 24)
		plus_btn.pressed.connect(func():
			if GameState.influence >= 10:
				GameState.influence -= 10
				player_influence_spent[law.id] = inf_spent + 10
				_refresh_display()
		)
		controls.add_child(plus_btn)
		
		parent.add_child(card)
		
	# Submit Button
	var submit_btn = Button.new()
	submit_btn.text = "Cast Ballots & Resolve Session"
	submit_btn.custom_minimum_size = Vector2(240, 36)
	submit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_setup_button_hover(submit_btn)
	submit_btn.pressed.connect(func():
		var results = pm.resolve_voting_session(current_province, player_votes, player_influence_spent)
		player_votes.clear()
		player_influence_spent.clear()
		_switch_tab("ActiveLaws")
	)
	parent.add_child(submit_btn)

func _create_law_card(law_name: String, law_desc: String, is_active: bool) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.16, 0.24, 0.5)
	card_style.set_corner_radius_all(6)
	card_style.set_border_width_all(1)
	card_style.border_color = Color(0.24, 0.60, 0.86, 0.3)
	card.add_theme_stylebox_override("panel", card_style)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var title = Label.new()
	title.text = law_name
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = law_desc
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	
	# Status Pill on the right
	var pill = PanelContainer.new()
	var pill_style = StyleBoxFlat.new()
	pill_style.set_corner_radius_all(4)
	pill_style.content_margin_left = 8
	pill_style.content_margin_right = 8
	pill_style.content_margin_top = 4
	pill_style.content_margin_bottom = 4
	
	var pill_lbl = Label.new()
	pill_lbl.add_theme_font_size_override("font_size", 10)
	
	if is_active:
		pill_style.bg_color = Color(0.1, 0.4, 0.15, 0.8) # Green
		pill_style.border_color = Color(0.2, 0.8, 0.3, 0.6)
		pill_style.set_border_width_all(1)
		pill_lbl.text = "ACTIVE"
		pill_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	else:
		pill_style.bg_color = Color(0.2, 0.2, 0.25, 0.6) # Gray/Dark Blue
		pill_style.border_color = Color(0.4, 0.4, 0.45, 0.4)
		pill_style.set_border_width_all(1)
		pill_lbl.text = "INACTIVE"
		pill_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.add_child(pill_lbl)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(pill)
	
	return card

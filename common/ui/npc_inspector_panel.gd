extends PanelContainer

# UI Node Outlets
var npc_list_vbox: VBoxContainer
var _card_outlets: Dictionary = {}
var _last_settlement: Node2D = null
var _last_npc_count: int = -1

func _ready() -> void:
	# Add to group so HUD can reference it
	add_to_group("NPCInspector")
	
	# Connect to visibility/viewport resize to keep panel aligned dynamically
	visibility_changed.connect(_on_visibility_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Initial alignment
	_align_panel()
	
	# Style the panel (Glassmorphism dark theme)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.94) # Dark transparent background
	style.border_width_left = 2
	style.border_color = Color(0.24, 0.65, 0.44) # Neon Emerald left border
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_left = 8
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.4)
	add_theme_stylebox_override("panel", style)
	
	# Root container
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_top", 12)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	add_child(margin_container)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin_container.add_child(main_vbox)
	
	# Header title
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title = Label.new()
	title.text = "NPC Economic Inspector"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.24, 0.65, 0.44))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	
	# Scroll area for NPCs
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var bottom_close_btn = Button.new()
	bottom_close_btn.text = "Close"
	bottom_close_btn.pressed.connect(hide)
	bottom_close_btn.custom_minimum_size = Vector2(100, 32)
	bottom_close_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	bottom_close_btn.focus_mode = Control.FOCUS_ALL
	main_vbox.add_child(bottom_close_btn)
	
	npc_list_vbox = VBoxContainer.new()
	npc_list_vbox.add_theme_constant_override("separation", 16)
	npc_list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(npc_list_vbox)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U:
			# Toggle
			if visible:
				hide()
			else:
				# Open and populate
				_populate_npc_list()
				show()
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible:
		return
		
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
		
	var player_settlement = GameState.get_nearest_settlement(player)
	var npcs = get_tree().get_nodes_in_group("NPCs")
	var current_settlement_npcs = []
	
	for npc in npcs:
		if is_instance_valid(npc) and "profile" in npc and npc.profile:
			var npc_settlement = GameState.get_nearest_settlement(npc)
			if npc_settlement == player_settlement:
				current_settlement_npcs.append(npc)
				
	if player_settlement != _last_settlement or current_settlement_npcs.size() != _last_npc_count:
		_last_settlement = player_settlement
		_last_npc_count = current_settlement_npcs.size()
		_populate_npc_list(current_settlement_npcs)
		
	_update_npc_cards(current_settlement_npcs)

func _populate_npc_list(npcs: Array = []) -> void:
	if npcs.is_empty():
		# Query NPCs in current settlement
		var player = get_tree().get_first_node_in_group("Player")
		if not player:
			return
			
		var player_settlement = GameState.get_nearest_settlement(player)
		var all_npcs = get_tree().get_nodes_in_group("NPCs")
		for npc in all_npcs:
			if is_instance_valid(npc) and "profile" in npc and npc.profile:
				var npc_settlement = GameState.get_nearest_settlement(npc)
				if npc_settlement == player_settlement:
					npcs.append(npc)
					
	# Clear old nodes
	for child in npc_list_vbox.get_children():
		child.queue_free()
		
	_card_outlets.clear()
	
	if npcs.size() == 0:
		var lbl = Label.new()
		lbl.text = "No NPCs in this settlement."
		lbl.add_theme_color_override("font_color", Color.GRAY)
		npc_list_vbox.add_child(lbl)
		return
		
	for npc in npcs:
		var card = _create_npc_card(npc)
		npc_list_vbox.add_child(card)

func _create_npc_card(npc: CharacterBody2D) -> PanelContainer:
	var card = PanelContainer.new()
	
	# Premium glass card style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.6)
	style.border_width_bottom = 1
	style.border_color = Color(0.24, 0.65, 0.44, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# 1. Title Row: NPC Name (Class)
	var title_lbl = Label.new()
	var name_str = npc.get("npc_name") if npc.get("npc_name") != "" else npc.name
	var class_str = npc.profile.get_class_string()
	title_lbl.text = "%s (%s)" % [name_str, class_str]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(title_lbl)
	
	# 2. State Row
	var state_lbl = Label.new()
	state_lbl.text = "State: Loading..."
	state_lbl.add_theme_font_size_override("font_size", 11)
	state_lbl.add_theme_color_override("font_color", Color.AQUAMARINE)
	vbox.add_child(state_lbl)
	
	# 3. Consumption Timers Section
	var timers_title = Label.new()
	timers_title.text = "Consumption Timers:"
	timers_title.add_theme_color_override("font_color", Color.GRAY)
	timers_title.add_theme_font_size_override("font_size", 10)
	vbox.add_child(timers_title)
	
	var timers_vbox = VBoxContainer.new()
	timers_vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(timers_vbox)
	
	var timer_bars = {}
	var demand_profiles = npc.profile.demand_profiles
	for item_id in demand_profiles:
		var item_hbox = HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 6)
		timers_vbox.add_child(item_hbox)
		
		var item_name = item_id.capitalize()
		var econ_mgr = get_node_or_null("/root/EconomyManager")
		if econ_mgr and econ_mgr.item_database.has(item_id):
			item_name = econ_mgr.item_database[item_id].name
			
		var item_lbl = Label.new()
		item_lbl.text = item_name + ":"
		item_lbl.custom_minimum_size = Vector2(80, 0)
		item_lbl.add_theme_font_size_override("font_size", 10)
		item_hbox.add_child(item_lbl)
		
		var progress = ProgressBar.new()
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.show_percentage = false
		progress.custom_minimum_size = Vector2(0, 10)
		item_hbox.add_child(progress)
		
		var status_lbl = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 9)
		status_lbl.custom_minimum_size = Vector2(100, 0)
		item_hbox.add_child(status_lbl)
		
		timer_bars[item_id] = {
			"bar": progress,
			"status": status_lbl
		}
		
	# 4. Last Decisions Section
	var dec_title = Label.new()
	dec_title.text = "Last 2 Decisions:"
	dec_title.add_theme_color_override("font_color", Color.GRAY)
	dec_title.add_theme_font_size_override("font_size", 10)
	vbox.add_child(dec_title)
	
	var decisions_vbox = VBoxContainer.new()
	decisions_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(decisions_vbox)
	
	# Register outlets for dynamic live updates
	_card_outlets[npc] = {
		"state_lbl": state_lbl,
		"timer_bars": timer_bars,
		"decisions_vbox": decisions_vbox
	}
	
	return card

func _update_npc_cards(npcs: Array) -> void:
	for npc in npcs:
		if not _card_outlets.has(npc) or not is_instance_valid(npc) or not npc.profile:
			continue
			
		var outlets = _card_outlets[npc]
		
		# 1. Update State Label
		var state_lbl = outlets["state_lbl"]
		var state_str = "Idle / Wandering"
		if "current_state" in npc:
			var target_item = npc.get("target_item_id")
			var target_stall = npc.get("target_stall")
			
			# Resolve item name
			var item_name = ""
			if target_item != "":
				item_name = target_item.capitalize()
				var econ_mgr = get_node_or_null("/root/EconomyManager")
				if econ_mgr and econ_mgr.item_database.has(target_item):
					item_name = econ_mgr.item_database[target_item].name
			
			# Resolve shop name and type
			var shop_info = ""
			if is_instance_valid(target_stall):
				var shop_name = target_stall.market_name
				var building = target_stall.get("parent_building")
				var building_type = ""
				if is_instance_valid(building):
					if "custom_name" in building and building.custom_name != "":
						shop_name = building.custom_name
					else:
						shop_name = building.name
					if building.is_in_group("Bakeries"): building_type = "Bakery"
					elif building.is_in_group("Smelters"): building_type = "Smelter"
					elif building.is_in_group("Inns"): building_type = "Inn"
					elif building.is_in_group("Looms"): building_type = "Loom"
					elif building.is_in_group("Mills"): building_type = "Mill"
					elif building.is_in_group("PaperMakers"): building_type = "Paper Maker"
					elif building.is_in_group("PrintingPresses"): building_type = "Printing Press"
					elif building.is_in_group("Banks"): building_type = "Bank"
					elif building.is_in_group("Houses"): building_type = "House"
				
				if building_type != "":
					shop_info = "%s (%s)" % [shop_name, building_type]
				else:
					shop_info = shop_name
					
			match npc.current_state:
				0: # State.IDLE_HOME
					state_str = "Idle / Wandering"
				1: # State.SEARCH_CHOOSE
					if target_item != "":
						state_str = "Searching for %s" % item_name
					else:
						state_str = "Search & Choose"
				2: # State.TRAVEL
					var going_home = npc.get("return_home_requested")
					if going_home:
						state_str = "Returning Home"
					elif target_item != "" and shop_info != "":
						state_str = "Traveling to buy %s at %s" % [item_name, shop_info]
					else:
						state_str = "Traveling"
				3: # State.TRANSACT
					if target_item != "" and shop_info != "":
						state_str = "Buying %s at %s" % [item_name, shop_info]
					else:
						state_str = "Transacting"
		state_lbl.text = "State: %s" % state_str
		
		# 2. Update Timer Progress Bars and Status Labels
		var timer_bars = outlets["timer_bars"]
		var demand_profiles = npc.profile.demand_profiles
		for item_id in timer_bars:
			if not demand_profiles.has(item_id): continue
			var profile = demand_profiles[item_id]
			var timer = profile.get("timer", 0.0)
			var total = profile.get("cooldown_total", 60.0)
			if total <= 0.0: total = 60.0
			
			var data = timer_bars[item_id]
			var progress = data["bar"]
			var status = data["status"]
			
			progress.max_value = total
			progress.value = max(0.0, total - timer)
			
			if timer <= 0.0 or item_id in npc.profile.shopping_queue:
				status.text = "Triggered / Shopping"
				status.add_theme_color_override("font_color", Color.GREEN)
			else:
				status.text = "Cooldown: %d s" % int(timer)
				status.add_theme_color_override("font_color", Color.LIGHT_GRAY)
				
		# 3. Update Decision History (Redraw only if changed to avoid flicker)
		var decisions_vbox = outlets["decisions_vbox"]
		var history = npc.get("decision_history") if npc.get("decision_history") != null else []
		
		var draw_history = false
		if decisions_vbox.get_child_count() != history.size():
			draw_history = true
		else:
			for i in range(history.size()):
				var cached_lbl = decisions_vbox.get_child(i).get_node_or_null("TimeLabel")
				if cached_lbl:
					var dec = history[i]
					var expected_text = "Decided: %s (Day %d - %02d:%02d)" % [
						dec.get("item_id", "").capitalize(),
						dec.get("timestamp_days", 1),
						dec.get("timestamp_hours", 0),
						dec.get("timestamp_minutes", 0)
					]
					if cached_lbl.text != expected_text:
						draw_history = true
						break
						
		if draw_history or history.size() == 0:
			# Clear old history nodes
			for child in decisions_vbox.get_children():
				child.queue_free()
				
			if history.size() == 0:
				var no_dec = Label.new()
				no_dec.text = "No shopping decisions logged yet."
				no_dec.add_theme_color_override("font_color", Color.GRAY)
				no_dec.add_theme_font_size_override("font_size", 9)
				decisions_vbox.add_child(no_dec)
			else:
				for dec in history:
					var dec_box = VBoxContainer.new()
					dec_box.add_theme_constant_override("separation", 2)
					decisions_vbox.add_child(dec_box)
					
					var time_lbl = Label.new()
					time_lbl.name = "TimeLabel"
					time_lbl.text = "Decided: %s (Day %d - %02d:%02d)" % [
						dec.get("item_id", "").capitalize(),
						dec.get("timestamp_days", 1),
						dec.get("timestamp_hours", 0),
						dec.get("timestamp_minutes", 0)
					]
					time_lbl.add_theme_font_size_override("font_size", 10)
					time_lbl.add_theme_color_override("font_color", Color.LIGHT_BLUE)
					dec_box.add_child(time_lbl)
					
					var candidates_list = dec.get("candidates", [])
					if candidates_list.is_empty():
						var no_cand = Label.new()
						no_cand.text = "  No candidates stock this item."
						no_cand.add_theme_color_override("font_color", Color.DARK_GRAY)
						no_cand.add_theme_font_size_override("font_size", 9)
						dec_box.add_child(no_cand)
					else:
						for candidate in candidates_list:
							var cand_lbl = Label.new()
							var is_win = candidate.get("is_winner", false)
							var prefix = "★ " if is_win else "- "
							cand_lbl.text = "  %s%s (Utility: %.2f, Price: $%d, Dist: %dpx)" % [
								prefix,
								candidate["shop_name"],
								candidate["utility"],
								candidate["price"],
								int(candidate["distance"])
							]
							cand_lbl.add_theme_font_size_override("font_size", 9)
							if is_win:
								cand_lbl.add_theme_color_override("font_color", Color.GREEN)
							else:
								cand_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
							dec_box.add_child(cand_lbl)

func _on_visibility_changed() -> void:
	if visible:
		_align_panel()

func _on_viewport_size_changed() -> void:
	if visible:
		_align_panel()

func _align_panel() -> void:
	var parent_size = Vector2(1152, 648)
	if get_parent() is Control:
		parent_size = get_parent().size
	else:
		parent_size = get_viewport_rect().size
		
	var panel_width = clamp(parent_size.x / 3.0, 360.0, 500.0)
	custom_minimum_size = Vector2(panel_width, parent_size.y)
	size = custom_minimum_size
	position = Vector2(parent_size.x - panel_width, 0.0)

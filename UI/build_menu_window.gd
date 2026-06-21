extends PanelContainer

var _main_hud: CanvasLayer = null
var _filter_only_buildable: bool = false
var _last_focused_card: Control = null

var all_list: VBoxContainer = null
var patreon_list: VBoxContainer = null
var scholar_list: VBoxContainer = null
var craftsman_list: VBoxContainer = null
var tailor_list: VBoxContainer = null

var legend_lbl: Label = null
var levels_overlay: PanelContainer = null

@onready var build_tab_container: TabContainer = $VBox/BuildTabContainer

func setup(p_hud: CanvasLayer) -> void:
	_main_hud = p_hud
	
	if get_viewport() and not get_viewport().gui_focus_changed.is_connected(_on_viewport_focus_changed):
		get_viewport().gui_focus_changed.connect(_on_viewport_focus_changed)
		
	if GameState.has_signal("gold_changed") and not GameState.gold_changed.is_connected(_on_gold_changed):
		GameState.gold_changed.connect(_on_gold_changed)
	
	if build_tab_container:
		build_tab_container.tabs_visible = false
		
		# Clear existing tabs in build_tab_container
		for child in build_tab_container.get_children():
			build_tab_container.remove_child(child)
			child.queue_free()
			
		# Create the 5 lists dynamically
		var lists = []
		var tab_names = ["General", "Patreon", "Scholar", "Craftsman", "Tailor"]
		for tab_name in tab_names:
			var margin_container = MarginContainer.new()
			margin_container.name = tab_name
			margin_container.add_theme_constant_override("margin_left", 20)
			margin_container.add_theme_constant_override("margin_right", 20)
			margin_container.add_theme_constant_override("margin_top", 16)
			margin_container.add_theme_constant_override("margin_bottom", 16)
			
			var scroll_container = ScrollContainer.new()
			scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			margin_container.add_child(scroll_container)
			
			var vbox = VBoxContainer.new()
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.add_child(vbox)
			
			build_tab_container.add_child(margin_container)
			lists.append(vbox)
			
		all_list = lists[0]
		patreon_list = lists[1]
		scholar_list = lists[2]
		craftsman_list = lists[3]
		tailor_list = lists[4]
		
		build_tab_container.focus_mode = Control.FOCUS_NONE
		build_tab_container.tab_changed.connect(func(tab_idx):
			_update_category_bar_highlight()
			_focus_first_card_in_active_tab()
		)
		
		# Category Bar with small window icons/buttons in a line
		var main_layout = get_node("VBox")
		var category_hbox = HBoxContainer.new()
		category_hbox.name = "CategoryBar"
		category_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		category_hbox.add_theme_constant_override("separation", 16)
		main_layout.add_child(category_hbox)
		main_layout.move_child(category_hbox, 1) # between Header and BuildTabContainer
		
		var categories = [
			{"name": "General", "icon": "🏠"},
			{"name": "Patreon", "icon": "🌾"},
			{"name": "Scholar", "icon": "📜"},
			{"name": "Craftsman", "icon": "⚒️"},
			{"name": "Tailor", "icon": "🧵"}
		]
		
		for i in range(categories.size()):
			var cat = categories[i]
			var btn = Button.new()
			btn.text = cat["icon"] + " " + cat["name"]
			btn.custom_minimum_size = Vector2(90, 28)
			btn.add_theme_font_size_override("font_size", 11)
			btn.focus_mode = Control.FOCUS_NONE
			if _main_hud and _main_hud.has_method("_setup_button_hover"):
				_main_hud._setup_button_hover(btn)
			btn.pressed.connect(func():
				_switch_build_tab(i)
			)
			category_hbox.add_child(btn)
			
		# Legend label just above CloseButton
		legend_lbl = Label.new()
		legend_lbl.name = "LegendLabel"
		legend_lbl.text = ""
		legend_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legend_lbl.add_theme_font_size_override("font_size", 11)
		legend_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		main_layout.add_child(legend_lbl)
		main_layout.move_child(legend_lbl, main_layout.get_child_count() - 2)

	# Time changed updates are bypassed to prevent card recreation flickering

func refresh() -> void:
	if not visible:
		return
	_update_build_menu_title()
	refresh_build_menu()

func _update_build_menu_title() -> void:
	var title_lbl = get_node_or_null("VBox/Header/BuildTitle")
	if title_lbl:
		if _filter_only_buildable:
			title_lbl.text = "Construction Menu (Filter: Buildable - [Tab] to toggle)"
		else:
			title_lbl.text = "Construction Menu (Filter: All - [Tab] to toggle)"

func refresh_build_menu() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	var focused_family = ""
	var focused_tab_idx = build_tab_container.current_tab if build_tab_container else 0
	if focused and is_instance_valid(focused) and is_ancestor_of(focused):
		focused_family = focused.get_meta("building_family", "")

	_populate_general_tab()
	_populate_profession_tab(1, "patreon")
	_populate_profession_tab(2, "scholar")
	_populate_profession_tab(3, "craftsman")
	_populate_profession_tab(4, "tailor")
	_update_category_bar_highlight()

	if focused_family != "":
		# Wait for layout updates to complete
		await get_tree().process_frame
		if not visible:
			return
		var active_control = build_tab_container.get_child(focused_tab_idx)
		if active_control:
			var target_card = _find_card_by_family(active_control, focused_family)
			if target_card and is_instance_valid(target_card) and target_card.visible:
				target_card.grab_focus()
				return

	_focus_first_card_in_active_tab()

func _switch_build_tab(idx: int) -> void:
	if build_tab_container:
		build_tab_container.current_tab = idx

func _update_category_bar_highlight() -> void:
	var category_hbox = get_node_or_null("VBox/CategoryBar")
	if not category_hbox:
		return
	var active_idx = build_tab_container.current_tab
	var active_color = Color(1.0, 0.85, 0.4) # Warm gold
	var inactive_color = Color(0.9, 0.9, 0.95)
	
	for i in category_hbox.get_child_count():
		var btn = category_hbox.get_child(i) as Button
		if btn:
			btn.add_theme_color_override("font_color", active_color if i == active_idx else inactive_color)

func _populate_general_tab() -> void:
	if not all_list:
		return
	var items = []
	for item in GameState.build_database:
		if item.career == "":
			if item.type == "home" or item.type == "renting" or item.type == "warehouse":
				if not _filter_only_buildable or _is_building_buildable(item):
					items.append(item)
	_populate_grid_tab(all_list, items)

func _populate_profession_tab(tab_idx: int, career_name: String) -> void:
	var list_node: VBoxContainer = null
	match tab_idx:
		1: list_node = patreon_list
		2: list_node = scholar_list
		3: list_node = craftsman_list
		4: list_node = tailor_list
		
	if not list_node:
		return
		
	var items = []
	for item in GameState.build_database:
		if item.career == career_name:
			if not _filter_only_buildable or _is_building_buildable(item):
				items.append(item)
				
	_populate_grid_tab(list_node, items)

func _populate_grid_tab(list_node: VBoxContainer, items: Array) -> void:
	for child in list_node.get_children():
		list_node.remove_child(child)
		child.queue_free()
		
	var grid = GridContainer.new()
	grid.name = "GridContainer"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_node.add_child(grid)
	
	var scroll = list_node.get_parent() as ScrollContainer
	if scroll:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		
	# Group items by family
	var families = {}
	for item in items:
		if not families.has(item.family):
			families[item.family] = []
		families[item.family].append(item)
		
	# Sort each family items by building_level
	for fam in families:
		families[fam].sort_custom(func(a, b):
			return a.building_level < b.building_level
		)
		
	var family_names = families.keys()
	# Sort families by the cost of their first building
	family_names.sort_custom(func(a, b):
		return families[a][0].cost < families[b][0].cost
	)
	
	for fam in family_names:
		var family_items = families[fam]
		var base_item = family_items[0]
		
		var card = _create_premium_card(base_item, true)
		card.set_meta("building_family", fam)
		card.set_meta("building_levels", family_items)
		card.set_meta("building_name", base_item.name)
		grid.add_child(card)
		
	_link_grid_focus_neighbors(grid)

func _link_grid_focus_neighbors(grid: GridContainer) -> void:
	if not grid or grid.get_child_count() == 0:
		return
		
	var cols = grid.columns
	var child_count = grid.get_child_count()
	
	for i in range(child_count):
		var child = grid.get_child(i) as Control
		if not child:
			continue
			
		var r = i / cols
		var c = i % cols
		
		# Left neighbor
		if c > 0:
			child.focus_neighbor_left = grid.get_child(i - 1).get_path()
		else:
			child.focus_neighbor_left = child.get_path()
			
		# Right neighbor
		if c < cols - 1 and i < child_count - 1:
			child.focus_neighbor_right = grid.get_child(i + 1).get_path()
		else:
			child.focus_neighbor_right = child.get_path()
			
		# Top neighbor
		if r > 0:
			child.focus_neighbor_top = grid.get_child(i - cols).get_path()
		else:
			child.focus_neighbor_top = child.get_path()
				
		# Bottom neighbor
		var next_row_idx = i + cols
		if next_row_idx < child_count:
			child.focus_neighbor_bottom = grid.get_child(next_row_idx).get_path()
		else:
			child.focus_neighbor_bottom = child.get_path()
			
		if not child.focus_entered.is_connected(_on_card_focused.bind(child)):
			child.focus_entered.connect(_on_card_focused.bind(child))

func _ensure_card_visible(card: Control, main_scroll: ScrollContainer) -> void:
	if not main_scroll or not is_instance_valid(main_scroll):
		return
	await card.get_tree().process_frame
	if not is_instance_valid(card) or not is_instance_valid(main_scroll):
		return
		
	var card_rect = card.get_global_rect()
	var scroll_rect = main_scroll.get_global_rect()
	var padding = 12.0
	
	if main_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		if card_rect.position.x < scroll_rect.position.x + padding:
			var diff = (scroll_rect.position.x + padding) - card_rect.position.x
			main_scroll.scroll_horizontal -= int(diff)
		elif card_rect.end.x > scroll_rect.end.x - padding:
			var diff = card_rect.end.x - (scroll_rect.end.x - padding)
			main_scroll.scroll_horizontal += int(diff)
			
	if main_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		if card_rect.position.y < scroll_rect.position.y + padding:
			var diff = (scroll_rect.position.y + padding) - card_rect.position.y
			main_scroll.scroll_vertical -= int(diff)
		elif card_rect.end.y > scroll_rect.end.y - padding:
			var diff = card_rect.end.y - (scroll_rect.end.y - padding)
			main_scroll.scroll_vertical += int(diff)

func _on_card_focused(card: Control) -> void:
	_last_focused_card = card
	var grid = card.get_parent()
	if grid:
		var scroll = grid.get_parent() as ScrollContainer
		if scroll:
			_ensure_card_visible(card, scroll)
		
	if is_instance_valid(legend_lbl):
		if card.has_meta("building_levels"):
			var levels = card.get_meta("building_levels") as Array
			if levels.size() > 1:
				legend_lbl.text = "[R] Touch to view all %d Levels for %s" % [levels.size(), card.get_meta("building_name")]
			else:
				legend_lbl.text = ""
		else:
			legend_lbl.text = ""

func _toggle_levels_overlay() -> void:
	if is_instance_valid(levels_overlay):
		_close_levels_overlay()
		return
		
	var focused = get_viewport().gui_get_focus_owner()
	if not focused or not is_ancestor_of(focused) or not focused.has_meta("building_levels"):
		return
		
	var levels = focused.get_meta("building_levels") as Array
	if levels.size() <= 1:
		return
		
	_open_levels_overlay(levels, focused)

func _open_levels_overlay(levels: Array, origin_card: Control) -> void:
	var center_container = CenterContainer.new()
	center_container.name = "LevelsOverlayCentering"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var hud_control = _main_hud.get_node("Control")
	if hud_control:
		hud_control.add_child(center_container)

	levels_overlay = PanelContainer.new()
	levels_overlay.name = "LevelsOverlay"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.16, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.24, 0.65, 0.44, 0.8)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 16
	levels_overlay.add_theme_stylebox_override("panel", style)
	
	center_container.add_child(levels_overlay)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	levels_overlay.add_child(vbox)
	
	var title = Label.new()
	title.text = "Select Level for: " + origin_card.get_meta("building_name")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.24, 0.65, 0.44))
	vbox.add_child(title)
	
	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 14)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_hbox)
	
	var first_card = null
	var level_cards = []
	for i in range(levels.size()):
		var building = levels[i]
		var card = _create_premium_card(building, false)
		cards_hbox.add_child(card)
		level_cards.append(card)
		if not first_card:
			first_card = card
			
	for i in range(level_cards.size()):
		var card = level_cards[i]
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_bottom = card.get_path()
		if i > 0:
			card.focus_neighbor_left = level_cards[i - 1].get_path()
		else:
			card.focus_neighbor_left = card.get_path()
		if i < level_cards.size() - 1:
			card.focus_neighbor_right = level_cards[i + 1].get_path()
		else:
			card.focus_neighbor_right = card.get_path()
			
	var hint = Label.new()
	hint.text = "[R] or [Esc] Back to main menu | [F] Confirm selection"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(hint)
	
	levels_overlay.set_meta("origin_card", origin_card)
	
	if first_card:
		first_card.grab_focus()

func _close_levels_overlay() -> void:
	if is_instance_valid(levels_overlay):
		var origin = levels_overlay.get_meta("origin_card")
		_safe_free_levels_overlay()
		if is_instance_valid(origin):
			origin.grab_focus()

func _safe_free_levels_overlay() -> void:
	if is_instance_valid(levels_overlay):
		var parent = levels_overlay.get_parent()
		levels_overlay.queue_free()
		levels_overlay = null
		if parent and parent.name == "LevelsOverlayCentering":
			parent.queue_free()

func _is_building_buildable(building: BuildingData) -> bool:
	var career = building.career
	var req_lvl = building.level
	var player_lvl = 1
	if career != "":
		player_lvl = GameState.career_levels.get(career, 1)
	var is_level_locked = player_lvl < req_lvl
	var is_locked_placeholder = building.scene_path == ""
	var is_title_locked = building.tier > GameState.title_level
	return not is_level_locked and not is_locked_placeholder and not is_title_locked

func _create_premium_card(building: BuildingData, compact: bool) -> PanelContainer:
	var career = building.career
	var req_lvl = building.level
	var type = building.type
	
	var player_lvl = 1
	if career != "":
		player_lvl = GameState.career_levels.get(career, 1)
		
	var is_level_locked = player_lvl < req_lvl
	var is_gold_locked = GameState.gold < building.cost
	var is_locked_placeholder = building.scene_path == ""
	var is_title_locked = building.tier > GameState.title_level
	
	var is_disabled = is_level_locked or is_locked_placeholder or is_title_locked
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(90, 95)
		
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	
	var base_color = Color(0.16, 0.16, 0.22, 0.8)
	var border_color = Color(0.35, 0.35, 0.45, 0.6)
	
	if not is_disabled:
		if career == "patreon":
			base_color = Color(0.12, 0.28, 0.18, 0.8)
			border_color = Color(0.24, 0.56, 0.36, 0.6)
		elif career == "craftsman":
			base_color = Color(0.25, 0.2, 0.15, 0.8)
			border_color = Color(0.55, 0.44, 0.32, 0.6)
		elif career == "tailor":
			base_color = Color(0.24, 0.14, 0.28, 0.8)
			border_color = Color(0.52, 0.32, 0.62, 0.6)
		elif career == "scholar":
			base_color = Color(0.12, 0.2, 0.3, 0.8)
			border_color = Color(0.24, 0.44, 0.66, 0.6)
		elif type == "home":
			base_color = Color(0.24, 0.12, 0.12, 0.8)
			border_color = Color(0.65, 0.24, 0.24, 0.6)
		elif type == "renting":
			base_color = Color(0.12, 0.24, 0.24, 0.8)
			border_color = Color(0.24, 0.65, 0.65, 0.6)
	else:
		base_color = Color(0.1, 0.1, 0.12, 0.45)
		border_color = Color(0.2, 0.2, 0.22, 0.3)
		
	style.bg_color = base_color
	style.border_color = border_color
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 2)
	main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_child(main_vbox)
	
	var initials = ""
	var words = building.name.split(" ")
	for word in words:
		if word.length() > 0:
			initials += word[0].to_upper()
	if initials.length() > 3:
		initials = initials.substr(0, 3)
		
	var icon_container = PanelContainer.new()
	var icon_size = 36
	icon_container.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var icon_style = StyleBoxFlat.new()
	icon_style.set_corner_radius_all(6)
	
	var icon_color = Color(0.3, 0.3, 0.35)
	if not is_disabled:
		if career == "patreon":
			icon_color = Color(0.2, 0.6, 0.3)
		elif career == "craftsman":
			icon_color = Color(0.7, 0.45, 0.2)
		elif career == "tailor":
			icon_color = Color(0.6, 0.25, 0.7)
		elif career == "scholar":
			icon_color = Color(0.2, 0.45, 0.7)
		elif type == "home":
			icon_color = Color(0.8, 0.3, 0.3)
		elif type == "renting":
			icon_color = Color(0.3, 0.7, 0.7)
	else:
		icon_color = Color(0.15, 0.15, 0.18)
		
	icon_style.bg_color = icon_color
	icon_container.add_theme_stylebox_override("panel", icon_style)
	
	var icon_label = Label.new()
	icon_label.text = initials
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 11)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_label.add_theme_constant_override("outline_size", 2)
	icon_label.add_theme_color_override("font_outline_color", Color.BLACK)
	icon_container.add_child(icon_label)
	main_vbox.add_child(icon_container)
	
	var card_title_lbl = Label.new()
	var title_text = building.name
	if building.building_level > 1 and not ("Lv." in title_text):
		title_text += " Lv. %d" % building.building_level
		
	card_title_lbl.text = title_text
	card_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title_lbl.add_theme_font_size_override("font_size", 9)
	card_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_title_lbl.max_lines_visible = 2
	
	if is_disabled:
		card_title_lbl.modulate = Color(0.5, 0.5, 0.5, 0.8)
	else:
		card_title_lbl.modulate = Color(0.9, 0.95, 0.9, 1)
	main_vbox.add_child(card_title_lbl)
	
	var info_lbl = Label.new()
	info_lbl.add_theme_font_size_override("font_size", 8)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if is_locked_placeholder:
		info_lbl.text = "Coming Soon"
		info_lbl.modulate = Color(0.6, 0.6, 0.6, 0.8)
	elif is_title_locked:
		info_lbl.text = "T%d Title Req" % building.tier
		info_lbl.modulate = Color(0.9, 0.35, 0.35, 1)
	elif is_level_locked:
		info_lbl.text = "Lv. %d Req" % req_lvl
		info_lbl.modulate = Color(0.9, 0.35, 0.35, 1)
	else:
		info_lbl.text = "%d G" % building.cost
		if is_gold_locked:
			info_lbl.modulate = Color(0.9, 0.45, 0.45, 0.9)
		else:
			info_lbl.modulate = Color(0.85, 0.85, 0.4, 0.9)
			
	main_vbox.add_child(info_lbl)
	
	card.focus_mode = Control.FOCUS_ALL
	
	card.set_meta("building_data", building)
	card.set_meta("style_box", style)
	card.set_meta("base_color", base_color)
	card.set_meta("border_color", border_color)
	card.set_meta("title_label", card_title_lbl)
	card.set_meta("info_label", info_lbl)
	card.set_meta("icon_container", icon_container)
	card.set_meta("icon_style", icon_style)
	card.set_meta("is_disabled", is_disabled)
	card.set_meta("is_gold_locked", is_gold_locked)
	card.set_meta("is_title_locked", is_title_locked)
	
	card.focus_entered.connect(func():
		var b_col = card.get_meta("base_color")
		var brd_col = card.get_meta("border_color")
		var s_box = card.get_meta("style_box") as StyleBoxFlat
		var bright_style = s_box.duplicate() as StyleBoxFlat
		bright_style.border_color = brd_col.lightened(0.3)
		bright_style.bg_color = b_col.lightened(0.1)
		card.add_theme_stylebox_override("panel", bright_style)
		
		card.pivot_offset = card.size / 2.0
		var tween = card.create_tween()
		tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08)
	)
	
	card.focus_exited.connect(func():
		var s_box = card.get_meta("style_box") as StyleBoxFlat
		card.add_theme_stylebox_override("panel", s_box)
		
		var tween = card.create_tween()
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08)
	)
	
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not is_disabled else Control.CURSOR_ARROW
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	card.mouse_entered.connect(func():
		if not card.get_meta("is_disabled", false):
			var b_col = card.get_meta("base_color")
			var brd_col = card.get_meta("border_color")
			var s_box = card.get_meta("style_box") as StyleBoxFlat
			var bright_style = s_box.duplicate() as StyleBoxFlat
			bright_style.border_color = brd_col.lightened(0.3)
			bright_style.bg_color = b_col.lightened(0.1)
			card.add_theme_stylebox_override("panel", bright_style)
			
			card.pivot_offset = card.size / 2.0
			var tween = card.create_tween()
			tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08)
	)
	
	card.mouse_exited.connect(func():
		if not card.get_meta("is_disabled", false):
			var s_box = card.get_meta("style_box") as StyleBoxFlat
			card.add_theme_stylebox_override("panel", s_box)
			
			var tween = card.create_tween()
			tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08)
	)
	
	card.gui_input.connect(func(event: InputEvent):
		var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		var is_accept = event.is_action_pressed("ui_accept")
		if is_click or is_accept:
			card.get_viewport().set_input_as_handled()
			if card.get_meta("is_disabled", false):
				_shake_card_node(card)
				
				if card.get_meta("is_title_locked", false):
					var title_name = GameState.get_title_name(building.tier)
					_spawn_floating_text_via_hud("Requires Title: %s" % title_name, card.global_position + card.size / 2.0)
				else:
					_spawn_floating_text_via_hud("Locked!", card.global_position + card.size / 2.0)
				return
				
			if card.get_meta("is_gold_locked", false):
				_shake_card_node(card)
				
				_spawn_floating_text_via_hud("Need Gold!", card.global_position + card.size / 2.0)
				return
				
			var click_tween = card.create_tween()
			click_tween.tween_property(card, "scale", Vector2(0.96, 0.96), 0.05)
			click_tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.05)
			await click_tween.finished
			
			if is_instance_valid(levels_overlay):
				_safe_free_levels_overlay()
			if _main_hud and _main_hud.windows_container:
				_main_hud.windows_container.hide()
			self.hide()
			if _main_hud and _main_hud._active_player:
				_main_hud._active_player.unfreeze()
			var focused = get_viewport().gui_get_focus_owner()
			if focused:
				focused.release_focus()
			if _main_hud:
				_main_hud.build_requested.emit(building)
	)
	
	return card

func _shake_card_node(node: Control) -> void:
	var baseline_x = node.position.x
	var tween = node.create_tween()
	tween.tween_property(node, "position:x", baseline_x - 5, 0.05)
	tween.tween_property(node, "position:x", baseline_x + 5, 0.05)
	tween.tween_property(node, "position:x", baseline_x - 3, 0.05)
	tween.tween_property(node, "position:x", baseline_x, 0.05)

func _spawn_floating_text_via_hud(sn_text: String, pos: Vector2) -> void:
	if _main_hud:
		if _main_hud.has_method("spawn_floating_text"):
			_main_hud.spawn_floating_text(sn_text, pos)
		elif _main_hud.has_method("_spawn_floating_text"):
			_main_hud._spawn_floating_text(sn_text, pos)

func _focus_first_card_in_active_tab() -> void:
	if not build_tab_container:
		return
	var active_tab_index = build_tab_container.current_tab
	var active_control = build_tab_container.get_child(active_tab_index)
	if active_control:
		var card = _find_first_focusable_card(active_control)
		if card:
			_grab_focus_deferred(card)
			build_tab_container.focus_neighbor_bottom = card.get_path()

func _grab_focus_deferred(control: Control) -> void:
	if not control.is_inside_tree():
		await control.ready
	await get_tree().process_frame
	if is_instance_valid(control) and control.is_inside_tree() and control.visible:
		control.grab_focus()

func _find_first_focusable_card(node: Node) -> Control:
	if node is PanelContainer and node.focus_mode == Control.FOCUS_ALL and node.visible:
		if not node.name.ends_with("_Window"):
			return node
	for child in node.get_children():
		var found = _find_first_focusable_card(child)
		if found:
			return found
	return null

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.is_action_pressed("ui_cancel") and is_instance_valid(levels_overlay):
			_close_levels_overlay()
			get_viewport().set_input_as_handled()
			return
			
		var key = event.keycode
		if key == KEY_W or key == KEY_S or key == KEY_A or key == KEY_D:
			if not is_instance_valid(levels_overlay):
				var focused = get_viewport().gui_get_focus_owner()
				if focused and is_instance_valid(focused) and is_ancestor_of(focused):
					var neighbor_path = NodePath()
					match key:
						KEY_W: neighbor_path = focused.focus_neighbor_top
						KEY_S: neighbor_path = focused.focus_neighbor_bottom
						KEY_A: neighbor_path = focused.focus_neighbor_left
						KEY_D: neighbor_path = focused.focus_neighbor_right
					
					if neighbor_path and neighbor_path != NodePath(""):
						var neighbor = focused.get_node_or_null(neighbor_path)
						if neighbor and neighbor is Control and neighbor.focus_mode != Control.FOCUS_NONE:
							neighbor.grab_focus()
							get_viewport().set_input_as_handled()
							return
		elif key == KEY_R:
			_toggle_levels_overlay()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_TAB:
			get_viewport().set_input_as_handled()
			_filter_only_buildable = not _filter_only_buildable
			refresh()

func _find_card_by_family(node: Node, family: String) -> Control:
	if node is PanelContainer and node.get_meta("building_family", "") == family:
		return node
	for child in node.get_children():
		var found = _find_card_by_family(child, family)
		if found:
			return found
	return null

func _on_viewport_focus_changed(control: Control) -> void:
	if is_inside_tree() and visible:
		if control and is_ancestor_of(control) and not (control == self or control.name == "BuildTabContainer" or control.name == "CategoryBar"):
			_last_focused_card = control
			
		if is_instance_valid(levels_overlay) and levels_overlay.visible:
			if control and (levels_overlay.is_ancestor_of(control) or is_ancestor_of(control)):
				return
			# If focus left both levels_overlay and build_menu, grab focus to first card in levels_overlay
			var first_card = _find_first_focusable_card(levels_overlay)
			if first_card:
				first_card.call_deferred("grab_focus")
				return
		
		if not control or not is_ancestor_of(control):
			if is_instance_valid(_last_focused_card) and _last_focused_card.is_inside_tree() and _last_focused_card.visible:
				_last_focused_card.call_deferred("grab_focus")
			else:
				_focus_first_card_in_active_tab()

func _on_gold_changed(_new_gold: int) -> void:
	if visible:
		_update_all_card_states()

func _update_all_card_states() -> void:
	for list_node in [all_list, patreon_list, scholar_list, craftsman_list, tailor_list]:
		if list_node:
			var grid = list_node.get_node_or_null("GridContainer")
			if grid:
				for card in grid.get_children():
					if card is PanelContainer:
						_update_card_style_and_state(card)

func _update_card_style_and_state(card: PanelContainer) -> void:
	var building = card.get_meta("building_data") as BuildingData
	if not building:
		return
		
	var career = building.career
	var req_lvl = building.level
	var player_lvl = 1
	if career != "":
		player_lvl = GameState.career_levels.get(career, 1)
		
	var is_level_locked = player_lvl < req_lvl
	var is_gold_locked = GameState.gold < building.cost
	var is_locked_placeholder = building.scene_path == ""
	var is_title_locked = building.tier > GameState.title_level
	var is_disabled = is_level_locked or is_locked_placeholder or is_title_locked
	
	var base_color = Color(0.16, 0.16, 0.22, 0.8)
	var border_color = Color(0.35, 0.35, 0.45, 0.6)
	var icon_color = Color(0.3, 0.3, 0.35)
	
	if not is_disabled:
		if career == "patreon":
			base_color = Color(0.12, 0.28, 0.18, 0.8)
			border_color = Color(0.24, 0.56, 0.36, 0.6)
			icon_color = Color(0.2, 0.6, 0.3)
		elif career == "craftsman":
			base_color = Color(0.25, 0.2, 0.15, 0.8)
			border_color = Color(0.55, 0.44, 0.32, 0.6)
			icon_color = Color(0.7, 0.45, 0.2)
		elif career == "tailor":
			base_color = Color(0.24, 0.14, 0.28, 0.8)
			border_color = Color(0.52, 0.32, 0.62, 0.6)
			icon_color = Color(0.6, 0.25, 0.7)
		elif career == "scholar":
			base_color = Color(0.12, 0.2, 0.3, 0.8)
			border_color = Color(0.24, 0.44, 0.66, 0.6)
			icon_color = Color(0.2, 0.45, 0.7)
		elif building.type == "home":
			base_color = Color(0.24, 0.12, 0.12, 0.8)
			border_color = Color(0.65, 0.24, 0.24, 0.6)
			icon_color = Color(0.8, 0.3, 0.3)
		elif building.type == "renting":
			base_color = Color(0.12, 0.24, 0.24, 0.8)
			border_color = Color(0.24, 0.65, 0.65, 0.6)
			icon_color = Color(0.3, 0.7, 0.7)
	else:
		base_color = Color(0.1, 0.1, 0.12, 0.45)
		border_color = Color(0.2, 0.2, 0.22, 0.3)
		icon_color = Color(0.15, 0.15, 0.18)
		
	var style = card.get_meta("style_box") as StyleBoxFlat
	if style:
		style.bg_color = base_color
		style.border_color = border_color
		
	var icon_style = card.get_meta("icon_style") as StyleBoxFlat
	if icon_style:
		icon_style.bg_color = icon_color
		
	card.set_meta("base_color", base_color)
	card.set_meta("border_color", border_color)
	card.set_meta("is_disabled", is_disabled)
	card.set_meta("is_gold_locked", is_gold_locked)
	card.set_meta("is_title_locked", is_title_locked)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not is_disabled else Control.CURSOR_ARROW
	
	var title_lbl = card.get_meta("title_label") as Label
	if title_lbl:
		if is_disabled:
			title_lbl.modulate = Color(0.5, 0.5, 0.5, 0.8)
		else:
			title_lbl.modulate = Color(0.9, 0.95, 0.9, 1)
			
	var info_lbl = card.get_meta("info_label") as Label
	if info_lbl:
		if is_locked_placeholder:
			info_lbl.text = "Coming Soon"
			info_lbl.modulate = Color(0.6, 0.6, 0.6, 0.8)
		elif is_title_locked:
			info_lbl.text = "T%d Title Req" % building.tier
			info_lbl.modulate = Color(0.9, 0.35, 0.35, 1)
		elif is_level_locked:
			info_lbl.text = "Lv. %d Req" % req_lvl
			info_lbl.modulate = Color(0.9, 0.35, 0.35, 1)
		else:
			info_lbl.text = "%d G" % building.cost
			if is_gold_locked:
				info_lbl.modulate = Color(0.9, 0.45, 0.45, 0.9)
			else:
				info_lbl.modulate = Color(0.85, 0.85, 0.4, 0.9)

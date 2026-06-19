extends PanelContainer

# UI Elements
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var bottom_close_button: Button = %BottomCloseButton

@onready var left_column: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/Columns/LeftColumn")
@onready var right_column: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/Columns/RightColumn")

var _building: Node2D = null
var _updating_ui: bool = false
var _option_buttons: Dictionary = {} # maps employee index -> OptionButton
var _progress_bars: Dictionary = {}  # maps employee index -> ProgressBar
var _timer_labels: Dictionary = {}   # maps employee index -> Label

const CATEGORIES = ["Main Data", "Employees", "Ledger", "Management"]
var _active_category_idx: int = 0
var _category_tab_container: HBoxContainer = null
var _subtab_container: HBoxContainer = null
var _active_management_subtab: int = 0
var _renovation_pbar: ProgressBar = null
var _renovation_lbl: Label = null

var _slider_overlay: ColorRect = null
var _last_focused_trigger_button: Control = null
var _transfer_mode_emp_idx: int = -1

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(close)
		_setup_button_hover(close_button)
		close_button.focus_mode = Control.FOCUS_NONE
	if bottom_close_button:
		bottom_close_button.pressed.connect(close)
		_setup_button_hover(bottom_close_button)
		bottom_close_button.focus_mode = Control.FOCUS_ALL

	# Instantiating categories tab container at the top of Title/Columns
	var main_vbox = get_node_or_null("MarginContainer/VBoxContainer")
	if main_vbox:
		_category_tab_container = HBoxContainer.new()
		_category_tab_container.name = "CategoryTabs"
		_category_tab_container.add_theme_constant_override("separation", 8)
		_category_tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
		main_vbox.add_child(_category_tab_container)
		# Place after the TitleBar and before Columns
		main_vbox.move_child(_category_tab_container, 1)
		
		_subtab_container = HBoxContainer.new()
		_subtab_container.name = "ManagementSubtabs"
		_subtab_container.add_theme_constant_override("separation", 12)
		_subtab_container.alignment = BoxContainer.ALIGNMENT_CENTER
		main_vbox.add_child(_subtab_container)
		main_vbox.move_child(_subtab_container, 2)
		_subtab_container.hide()

	add_to_group("BuildingUIs")

	# Create slider overlay backdrop
	_slider_overlay = ColorRect.new()
	_slider_overlay.color = Color(0.08, 0.08, 0.12, 0.65) # Dimming
	_slider_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_slider_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider_overlay.hide()
	add_child(_slider_overlay)

func open(building: Node2D) -> void:
	_building = building
	_updating_ui = false
	_active_category_idx = 0
	_transfer_mode_emp_idx = -1
	_close_slider_popup()
	
	if _building:
		if _building.inventory and not _building.inventory.inventory_changed.is_connected(refresh):
			_building.inventory.inventory_changed.connect(refresh)
		if _building.get("building_storage") and not _building.building_storage.inventory_changed.is_connected(refresh):
			_building.building_storage.inventory_changed.connect(refresh)
			
	if GameState.player_inventory:
		if not GameState.player_inventory.inventory_changed.is_connected(refresh):
			GameState.player_inventory.inventory_changed.connect(refresh)
			
	show()
	
	pivot_offset = size / 2.0
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	
	refresh()
	_focus_first_button()

func close() -> void:
	_close_slider_popup()
	if _building:
		if _building.inventory and _building.inventory.inventory_changed.is_connected(refresh):
			_building.inventory.inventory_changed.disconnect(refresh)
		if _building.get("building_storage") and _building.building_storage.inventory_changed.is_connected(refresh):
			_building.building_storage.inventory_changed.disconnect(refresh)
			
	if GameState.player_inventory:
		if GameState.player_inventory.inventory_changed.is_connected(refresh):
			GameState.player_inventory.inventory_changed.disconnect(refresh)
			
	hide()
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("close_building_ui"):
		hud.close_building_ui()
	else:
		queue_free()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if _slider_overlay and _slider_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_slider_popup()
			get_viewport().set_input_as_handled()
			return
			
		if event.is_pressed() and not event.is_echo():
			var slider = _find_slider_in_node(_slider_overlay)
			if slider and is_instance_valid(slider):
				if event.is_action_pressed("move_left") or (event is InputEventKey and event.keycode == KEY_A):
					slider.value = max(slider.min_value, slider.value - 1)
					get_viewport().set_input_as_handled()
					return
				elif event.is_action_pressed("move_right") or (event is InputEventKey and event.keycode == KEY_D):
					slider.value = min(slider.max_value, slider.value + 1)
					get_viewport().set_input_as_handled()
					return
					
			if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
				var confirm_btn = _find_confirm_button_in_node(_slider_overlay)
				if confirm_btn and is_instance_valid(confirm_btn) and not confirm_btn.disabled:
					confirm_btn.pressed.emit()
					get_viewport().set_input_as_handled()
					return
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
		
	# Q/E category tab cycle
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("ui_page_up") or (event is InputEventKey and event.keycode == KEY_Q):
			_active_category_idx = (_active_category_idx - 1 + CATEGORIES.size()) % CATEGORIES.size()
			refresh()
			_focus_first_button()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_page_down") or (event is InputEventKey and event.keycode == KEY_E):
			_active_category_idx = (_active_category_idx + 1) % CATEGORIES.size()
			refresh()
			_focus_first_button()
			get_viewport().set_input_as_handled()
			return
			
		# F key selection override
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and focused is Button and is_instance_valid(focused) and is_ancestor_of(focused):
				if focused is OptionButton:
					focused.show_popup()
				else:
					focused.pressed.emit()
				get_viewport().set_input_as_handled()
				return

func _process(_delta: float) -> void:
	if not visible or not _building:
		return
	_update_progress_bars()

func refresh() -> void:
	if not _building:
		return
		
	_updating_ui = true
	
	if title_label:
		title_label.text = "%s Management Ledger" % _building.name.replace("Interior_", "")
		
	_update_category_tabs()
	
	# Clear both columns completely for tab-specific layouts
	if left_column:
		for child in left_column.get_children():
			child.queue_free()
	if right_column:
		for child in right_column.get_children():
			child.queue_free()
			
	if _subtab_container:
		_subtab_container.hide()
		
	if _active_category_idx == 0:
		if left_column: left_column.show()
		if right_column: right_column.show()
		_render_main_data_tab()
	elif _active_category_idx == 1:
		if left_column: left_column.show()
		if right_column: right_column.hide()
		_render_employees_tab()
	elif _active_category_idx == 2:
		if left_column: left_column.show()
		if right_column: right_column.show()
		_render_ledger_tab()
	else:
		if left_column: left_column.show()
		if right_column: right_column.show()
		if _subtab_container:
			_subtab_container.show()
		_render_management_tab()
		
	_updating_ui = false

func _update_category_tabs() -> void:
	if not _category_tab_container:
		return
		
	for child in _category_tab_container.get_children():
		_category_tab_container.remove_child(child)
		child.queue_free()
		
	for i in range(CATEGORIES.size()):
		var cat_name = CATEGORIES[i]
		var tab_btn = Button.new()
		tab_btn.text = cat_name
		tab_btn.flat = true
		tab_btn.focus_mode = Control.FOCUS_NONE
		tab_btn.add_theme_font_size_override("font_size", 11)
		
		var normal_style = StyleBoxFlat.new()
		normal_style.content_margin_left = 12
		normal_style.content_margin_right = 12
		normal_style.content_margin_top = 4
		normal_style.content_margin_bottom = 4
		normal_style.set_corner_radius_all(4)
		
		if i == _active_category_idx:
			normal_style.bg_color = Color(0.24, 0.52, 0.85, 0.9) # highlighted blue
			tab_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			tab_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		else:
			normal_style.bg_color = Color(0.12, 0.12, 0.16, 0.5)
			tab_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
			tab_btn.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.95))
			
		tab_btn.add_theme_stylebox_override("normal", normal_style)
		tab_btn.add_theme_stylebox_override("hover", normal_style)
		tab_btn.add_theme_stylebox_override("pressed", normal_style)
		tab_btn.add_theme_stylebox_override("focus", normal_style)
		
		var idx = i
		tab_btn.pressed.connect(func():
			_active_category_idx = idx
			refresh()
			_focus_first_button()
		)
		
		_category_tab_container.add_child(tab_btn)

# --- TAB RENDERING LOGIC ---

# 1. Main Data: storage grids, player inventory, and active employee production queue rows
func _render_main_data_tab() -> void:
	if _building.get("is_warehouse"):
		_render_warehouse_main_data()
		return
		
	# Left Column: Employee Task Delegation (Production Queue)
	var queue_lbl = Label.new()
	queue_lbl.text = "Employee Task Delegation"
	queue_lbl.add_theme_font_size_override("font_size", 14)
	left_column.add_child(queue_lbl)
	
	var queue_scroll = ScrollContainer.new()
	queue_scroll.custom_minimum_size = Vector2(0, 320)
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(queue_scroll)
	
	var queue_vbox = VBoxContainer.new()
	queue_vbox.add_theme_constant_override("separation", 8)
	queue_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.add_child(queue_vbox)
	_populate_production_queue(queue_vbox)
	
	# Shortcut guide at the bottom of the left column
	var shortcut_info = Label.new()
	shortcut_info.text = "Storage Shortcuts:\n • Building Storage: [Left-Click] to Player | [Right-Click] to Stall\n • Stall & Player: [Left-Click] to Building | [Shift + Click] transfers Full Stack"
	shortcut_info.add_theme_font_size_override("font_size", 10)
	shortcut_info.modulate = Color(0.7, 0.75, 0.85, 0.85)
	left_column.add_child(shortcut_info)
	
	# Right Column: Building Storage, Stall Storefront, and Player Inventory (all scrolled together)
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_column.add_child(right_scroll)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_vbox)
	
	# 1. Building Storage (much smaller)
	var b_storage_lbl = Label.new()
	b_storage_lbl.text = "Building Storage (8 Slots)"
	b_storage_lbl.add_theme_font_size_override("font_size", 12)
	right_vbox.add_child(b_storage_lbl)
	
	var b_storage_grid = GridContainer.new()
	b_storage_grid.columns = 4
	b_storage_grid.add_theme_constant_override("h_separation", 6)
	b_storage_grid.add_theme_constant_override("v_separation", 6)
	right_vbox.add_child(b_storage_grid)
	
	var target_b_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	if target_b_inv:
		for i in range(8):
			var slot_panel = _create_slot_panel("building", target_b_inv, i)
			b_storage_grid.add_child(slot_panel)
			
	# 2. Stall Storefront (if applicable)
	var stall_lbl = Label.new()
	stall_lbl.text = "Stall Storefront (4 Slots)"
	stall_lbl.add_theme_font_size_override("font_size", 12)
	right_vbox.add_child(stall_lbl)
	
	var stall_vbox = VBoxContainer.new()
	stall_vbox.add_theme_constant_override("separation", 4)
	right_vbox.add_child(stall_vbox)
	
	var stall_inv = _building.inventory
	if stall_inv and _building.get("building_storage") != null:
		for i in range(4):
			var slot_panel = _create_stall_row_panel(stall_inv, i)
			stall_vbox.add_child(slot_panel)
	else:
		var no_stall_lbl = Label.new()
		no_stall_lbl.text = "Not applicable."
		no_stall_lbl.add_theme_font_size_override("font_size", 10)
		no_stall_lbl.modulate = Color(0.5, 0.5, 0.5)
		stall_vbox.add_child(no_stall_lbl)
		
	# 3. Your Inventory
	var p_inv_lbl = Label.new()
	p_inv_lbl.text = "Your Inventory"
	p_inv_lbl.add_theme_font_size_override("font_size", 12)
	right_vbox.add_child(p_inv_lbl)
	
	var p_inv_list = VBoxContainer.new()
	p_inv_list.add_theme_constant_override("separation", 4)
	right_vbox.add_child(p_inv_list)
	_populate_player_inventory_list(p_inv_list)


# 2. Employees: management, skills/career levels, candidates hiring
func _render_employees_tab() -> void:
	var employees_lbl = Label.new()
	employees_lbl.text = "Hired Workers & Careers"
	employees_lbl.add_theme_font_size_override("font_size", 14)
	left_column.add_child(employees_lbl)
	
	var emp_scroll = ScrollContainer.new()
	emp_scroll.custom_minimum_size = Vector2(0, 180)
	emp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(emp_scroll)
	
	var emp_vbox = VBoxContainer.new()
	emp_vbox.add_theme_constant_override("separation", 8)
	emp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emp_scroll.add_child(emp_vbox)
	_populate_hired_employees_list(emp_vbox)
	
	var candidates_lbl = Label.new()
	candidates_lbl.text = "Available Candidates for Hire"
	candidates_lbl.add_theme_font_size_override("font_size", 14)
	left_column.add_child(candidates_lbl)
	
	var cand_scroll = ScrollContainer.new()
	cand_scroll.custom_minimum_size = Vector2(0, 180)
	cand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(cand_scroll)
	
	var cand_vbox = VBoxContainer.new()
	cand_vbox.add_theme_constant_override("separation", 6)
	cand_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cand_scroll.add_child(cand_vbox)
	_populate_candidates_list(cand_vbox)

# 3. Ledger: goods produced stats, strongbox vault retrieve, transactions log
func _render_ledger_tab() -> void:
	# Left Column: Production Stats Table
	var stats_lbl = Label.new()
	stats_lbl.text = "Goods Production Summary"
	stats_lbl.add_theme_font_size_override("font_size", 14)
	left_column.add_child(stats_lbl)
	
	var table_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.8)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	table_panel.add_theme_stylebox_override("panel", style)
	left_column.add_child(table_panel)
	
	var table_grid = GridContainer.new()
	table_grid.columns = 3
	table_grid.add_theme_constant_override("h_separation", 32)
	table_grid.add_theme_constant_override("v_separation", 10)
	table_panel.add_child(table_grid)
	
	# Table Headers
	var h_good = Label.new()
	h_good.text = "Product Name"
	h_good.add_theme_font_size_override("font_size", 12)
	h_good.add_theme_color_override("font_color", Color(0.24, 0.52, 0.85, 1))
	table_grid.add_child(h_good)
	
	var h_lifetime = Label.new()
	h_lifetime.text = "Lifetime"
	h_lifetime.add_theme_font_size_override("font_size", 12)
	h_lifetime.add_theme_color_override("font_color", Color(0.24, 0.52, 0.85, 1))
	table_grid.add_child(h_lifetime)
	
	var h_today = Label.new()
	h_today.text = "Today"
	h_today.add_theme_font_size_override("font_size", 12)
	h_today.add_theme_color_override("font_color", Color(0.24, 0.52, 0.85, 1))
	table_grid.add_child(h_today)
	
	var recipes = _get_recipes()
	if recipes.size() > 0:
		var lifetime_dict = _building.get("lifetime_production") if "lifetime_production" in _building else {}
		var daily_dict = _building.get("daily_production") if "daily_production" in _building else {}
		
		for recipe in recipes:
			if not recipe or not recipe.output_item:
				continue
			var item = recipe.output_item
			var life_qty = lifetime_dict.get(item.id, 0)
			var day_qty = daily_dict.get(item.id, 0)
			
			var l_name = Label.new()
			l_name.text = item.name
			l_name.add_theme_font_size_override("font_size", 11)
			table_grid.add_child(l_name)
			
			var l_life = Label.new()
			l_life.text = "%d" % life_qty
			l_life.add_theme_font_size_override("font_size", 11)
			l_life.modulate = Color(0.85, 0.85, 0.95)
			table_grid.add_child(l_life)
			
			var l_day = Label.new()
			l_day.text = "%d" % day_qty
			l_day.add_theme_font_size_override("font_size", 11)
			l_day.modulate = Color(0.2, 0.8, 0.5) if day_qty > 0 else Color(0.5, 0.5, 0.5)
			table_grid.add_child(l_day)
	else:
		var empty_lbl = Label.new()
		empty_lbl.text = "No production recipes"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		table_grid.add_child(empty_lbl)
		table_grid.add_child(Label.new())
		table_grid.add_child(Label.new())

	# Right Column: Vault Gold and Transaction logs
	var vault_lbl = Label.new()
	vault_lbl.text = "Strongbox Cash Vault"
	vault_lbl.add_theme_font_size_override("font_size", 14)
	right_column.add_child(vault_lbl)
	
	var strongbox = _building.get_node_or_null("StrongboxComponent")
	var balance = strongbox.strongbox_gold if strongbox else 0
	
	var vault_panel = PanelContainer.new()
	var style_vault = StyleBoxFlat.new()
	style_vault.bg_color = Color(0.12, 0.12, 0.16, 0.9)
	style_vault.border_width_left = 1
	style_vault.border_width_top = 1
	style_vault.border_width_right = 1
	style_vault.border_width_bottom = 1
	style_vault.border_color = Color(0.88, 0.73, 0.23, 0.5)
	style_vault.set_corner_radius_all(8)
	style_vault.content_margin_left = 16
	style_vault.content_margin_right = 16
	style_vault.content_margin_top = 12
	style_vault.content_margin_bottom = 12
	vault_panel.add_theme_stylebox_override("panel", style_vault)
	right_column.add_child(vault_panel)
	
	var vault_hbox = HBoxContainer.new()
	vault_panel.add_child(vault_hbox)
	
	var balance_lbl = Label.new()
	var max_cap = strongbox.max_gold_capacity if (strongbox and "max_gold_capacity" in strongbox) else 1500
	balance_lbl.text = "Vault Gold: %d / %d G" % [balance, max_cap]
	balance_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_lbl.add_theme_font_size_override("font_size", 14)
	balance_lbl.add_theme_color_override("font_color", Color(0.88, 0.73, 0.23, 1))
	vault_hbox.add_child(balance_lbl)
	
	var retrieve_btn = Button.new()
	retrieve_btn.text = "Withdraw All"
	retrieve_btn.add_theme_font_size_override("font_size", 11)
	retrieve_btn.custom_minimum_size = Vector2(100, 26)
	if balance <= 0:
		retrieve_btn.disabled = true
	retrieve_btn.pressed.connect(func():
		var sbox = _building.get_node_or_null("StrongboxComponent")
		if sbox and sbox.strongbox_gold > 0:
			var gold_to_withdraw = sbox.withdraw_all()
			GameState.gold += gold_to_withdraw
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud:
				hud._spawn_floating_text("+%d Gold Retrieved!" % gold_to_withdraw, _building.global_position)
				if hud.has_method("update_hud_values"):
					hud.update_hud_values()
			refresh()
	)
	_setup_button_hover(retrieve_btn)
	vault_hbox.add_child(retrieve_btn)
	
	# Recent Sales Ledger
	var log_lbl = Label.new()
	log_lbl.text = "Recent Sales Ledger (Max 30 Entries)"
	log_lbl.add_theme_font_size_override("font_size", 14)
	right_column.add_child(log_lbl)
	
	var log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(log_scroll)
	
	var log_vbox = VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 4)
	log_scroll.add_child(log_vbox)
	
	if strongbox and strongbox.transaction_ledger.size() > 0:
		for entry in strongbox.transaction_ledger:
			var item_lbl = Label.new()
			var buyer = entry.get("buyer_name", "Customer")
			item_lbl.text = " • Sold %d %s to %s for %d Gold (%s)" % [entry["amount"], entry["item_name"], buyer, entry["price"], entry["timestamp"]]
			item_lbl.add_theme_font_size_override("font_size", 11)
			item_lbl.modulate = Color(0.8, 0.8, 0.85, 0.95)
			log_vbox.add_child(item_lbl)
	else:
		var no_trans = Label.new()
		no_trans.text = " No sales recorded yet."
		no_trans.add_theme_font_size_override("font_size", 11)
		no_trans.modulate = Color(0.5, 0.5, 0.5, 0.8)
		log_vbox.add_child(no_trans)

# --- PANEL CREATION / STORAGE HELPERS ---

func _create_slot_panel(source_type: String, inv: Node, slot_idx: int) -> PanelContainer:
	var slot_panel = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(48, 48)
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	normal_style.set_border_width_all(1)
	normal_style.border_color = Color(0.3, 0.35, 0.45, 0.6)
	normal_style.set_corner_radius_all(4)
	slot_panel.add_theme_stylebox_override("panel", normal_style)
	
	var hover_style = normal_style.duplicate() as StyleBoxFlat
	hover_style.border_color = Color(0.24, 0.52, 0.85, 0.9)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	slot_panel.add_child(vbox)
	
	if slot_idx < inv.slots.size():
		var slot = inv.slots[slot_idx]
		var item = slot["item"]
		var amount = slot["amount"]
		
		var name_lbl = Label.new()
		name_lbl.text = item.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(name_lbl)
		
		var qty_lbl = Label.new()
		qty_lbl.text = "x%d" % amount
		qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_lbl.add_theme_font_size_override("font_size", 8)
		qty_lbl.modulate = Color(0.35, 0.75, 1.0)
		vbox.add_child(qty_lbl)
		
		# For Building Storage, display green colored name if it's produced here
		if source_type == "building" and _is_produced_here(item):
			name_lbl.modulate = Color(0.3, 0.9, 0.4)
			
		# Connect Mouse Click Event
		slot_panel.gui_input.connect(func(event):
			_on_slot_gui_input(event, item, source_type)
		)
		
		slot_panel.mouse_entered.connect(func():
			slot_panel.add_theme_stylebox_override("panel", hover_style)
		)
		slot_panel.mouse_exited.connect(func():
			slot_panel.add_theme_stylebox_override("panel", normal_style)
		)
	else:
		var empty_lbl = Label.new()
		empty_lbl.text = "-"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.modulate = Color(0.3, 0.3, 0.3)
		vbox.add_child(empty_lbl)
		
	return slot_panel


func _create_stall_row_panel(inv: Node, slot_idx: int) -> PanelContainer:
	var row_panel = PanelContainer.new()
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.16, 0.20, 0.8)
	normal_style.set_border_width_all(1)
	normal_style.border_color = Color(0.3, 0.35, 0.45, 0.4)
	normal_style.set_corner_radius_all(6)
	normal_style.content_margin_left = 8
	normal_style.content_margin_right = 8
	normal_style.content_margin_top = 4
	normal_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", normal_style)
	
	var hover_style = normal_style.duplicate() as StyleBoxFlat
	hover_style.border_color = Color(0.24, 0.52, 0.85, 0.8)
	
	var hbox = HBoxContainer.new()
	row_panel.add_child(hbox)
	
	if slot_idx < inv.slots.size():
		var slot = inv.slots[slot_idx]
		var item = slot["item"]
		var amount = slot["amount"]
		
		var name_lbl = Label.new()
		name_lbl.text = "%s (x%d)" % [item.name, amount]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		# Sell Price Controls
		var price = _building.custom_prices.get(item.id, item.base_value)
		
		var price_lbl = Label.new()
		price_lbl.text = "%d G" % price
		price_lbl.add_theme_font_size_override("font_size", 11)
		price_lbl.add_theme_color_override("font_color", Color(0.88, 0.73, 0.23, 1))
		
		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.add_theme_font_size_override("font_size", 10)
		minus_btn.custom_minimum_size = Vector2(20, 20)
		minus_btn.pressed.connect(func():
			var cur_price = _building.custom_prices.get(item.id, item.base_value)
			var min_p = item.min_price if "min_price" in item else 1
			_building.custom_prices[item.id] = max(min_p, cur_price - 1)
			price_lbl.text = "%d G" % _building.custom_prices[item.id]
		)
		
		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.add_theme_font_size_override("font_size", 10)
		plus_btn.custom_minimum_size = Vector2(20, 20)
		plus_btn.pressed.connect(func():
			var cur_price = _building.custom_prices.get(item.id, item.base_value)
			var max_p = item.max_price if "max_price" in item else 999
			_building.custom_prices[item.id] = min(max_p, cur_price + 1)
			price_lbl.text = "%d G" % _building.custom_prices[item.id]
		)
		
		hbox.add_child(minus_btn)
		hbox.add_child(price_lbl)
		hbox.add_child(plus_btn)
		
		var withdraw_btn = Button.new()
		withdraw_btn.text = "Withdraw"
		withdraw_btn.add_theme_font_size_override("font_size", 10)
		withdraw_btn.pressed.connect(func():
			_move_item_stall_to_building(item, false)
		)
		hbox.add_child(withdraw_btn)
		
		# Connect click event on row panel for Left-Click shortcut withdrawal
		row_panel.gui_input.connect(func(event):
			_on_slot_gui_input(event, item, "stall")
		)
		row_panel.mouse_entered.connect(func():
			row_panel.add_theme_stylebox_override("panel", hover_style)
		)
		row_panel.mouse_exited.connect(func():
			row_panel.add_theme_stylebox_override("panel", normal_style)
		)
	else:
		var empty_lbl = Label.new()
		empty_lbl.text = "Vacant Stall Slot"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.modulate = Color(0.4, 0.4, 0.4)
		hbox.add_child(empty_lbl)
		
	return row_panel

func _populate_player_inventory_list(container: VBoxContainer) -> void:
	var player_inv = GameState.player_inventory
	if not player_inv or player_inv.slots.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No items in inventory."
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		container.add_child(empty_lbl)
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
		put_btn.pressed.connect(func():
			_move_item_player_to_building(item, false)
		)
		hbox.add_child(put_btn)
		
		panel.gui_input.connect(func(event):
			_on_slot_gui_input(event, item, "player")
		)
		panel.mouse_entered.connect(func():
			panel.add_theme_stylebox_override("panel", hover_style)
		)
		panel.mouse_exited.connect(func():
			panel.add_theme_stylebox_override("panel", style)
		)
		
		container.add_child(panel)

func _populate_production_queue(container: VBoxContainer) -> void:
	_option_buttons.clear()
	_progress_bars.clear()
	_timer_labels.clear()
	
	if _building.get("hired_employees") == null:
		var no_workers = Label.new()
		no_workers.text = "No employee tracking on this building."
		no_workers.add_theme_font_size_override("font_size", 11)
		no_workers.modulate = Color(0.5, 0.5, 0.5)
		container.add_child(no_workers)
		return
		
	# Prepend Player Card
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
	
	var p_detail_lbl = Label.new()
	p_detail_lbl.add_theme_font_size_override("font_size", 9)
	p_detail_lbl.modulate = Color(0.8, 0.75, 0.9)
	p_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	p_vbox.add_child(p_detail_lbl)
	
	var p_active_path = _building.get("player_crafting_recipe_path") if _building.get("player_crafting_recipe_path") else ""
	if p_active_path != "":
		var recipe = load(p_active_path)
		if recipe:
			var name_to_display = recipe.output_item.name if recipe.output_item else recipe.recipe_name
			p_status_lbl.text = "Task: Produce %s" % name_to_display
			
			var input_strs = []
			for input_item in recipe.inputs:
				input_strs.append("%dx %s" % [recipe.inputs[input_item], input_item.name])
			var inputs_txt = ", ".join(input_strs)
			
			var player = get_tree().get_first_node_in_group("Player")
			var prod = player.get("productivity") if player else 1.0
			var craft_time = float(recipe.required_level * 5.0)
			if prod > 0.0:
				craft_time /= prod
			var p_level = GameState.career_levels.get(recipe.required_career, 1)
			if p_level >= 8 and recipe.output_item.get("is_luxury_product") == true:
				craft_time *= 0.85
				
			p_detail_lbl.text = "Req: %s\nYield: %d %s | Time: %.1fs" % [
				inputs_txt,
				recipe.output_amount,
				recipe.output_item.name,
				craft_time
			]
	else:
		p_status_lbl.text = "Task: Idle"
		p_detail_lbl.text = "You are currently idle."
		
	var start_craft_btn = Button.new()
	start_craft_btn.text = "Assign Task"
	start_craft_btn.focus_mode = Control.FOCUS_ALL
	start_craft_btn.add_theme_font_size_override("font_size", 11)
	p_vbox.add_child(start_craft_btn)
	_setup_button_hover(start_craft_btn)
	
	if _building.get("is_player_working_here"):
		start_craft_btn.text = "Stop Work (Player)"
		start_craft_btn.pressed.connect(func():
			_building.stop_player_crafting()
			refresh()
		)
	else:
		start_craft_btn.pressed.connect(func():
			_open_player_assign_popup()
		)
	
	container.add_child(p_panel)
		
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
			if is_instance_valid(npc):
				emp_prod = npc.productivity
			var prod_suffix = " (Prod: %d%%)" % int(emp_prod * 100.0)
			if emp_prod > 1.0:
				prod_suffix += " ▲"
			name_lbl.text = emp.get("name", "Worker") + prod_suffix
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title_hbox.add_child(name_lbl)
			var emp_status_lbl = Label.new()
			emp_status_lbl.add_theme_font_size_override("font_size", 10)
			emp_status_lbl.modulate = Color(0.7, 0.75, 0.9)
			vbox.add_child(emp_status_lbl)
			
			var active_route = emp.get("active_commercial_route")
			var comp_nodes = _get_compatible_nodes()
			var active_node_path = ""
			
			if active_route:
				emp_status_lbl.text = "Task: On Route (" + active_route.route_name + ")"
				emp_status_lbl.modulate = Color(0.9, 0.75, 0.15)
			else:
				var active_path = emp.get("active_recipe_path", "")
				active_node_path = str(emp.get("active_gathering_node_path", ""))
				
				if active_path != "":
					var recipe = load(active_path)
					if recipe:
						var name_to_display = recipe.output_item.name if recipe.output_item else recipe.recipe_name
						var repeat_info = "Continuous" if emp.get("is_repeating", true) else ("Limit: %d remaining" % emp.get("production_amount_limit", 1))
						emp_status_lbl.text = "Task: Produce %s (%s)" % [name_to_display, repeat_info]
				elif active_node_path != "":
					var node = get_node_or_null(active_node_path)
					if node:
						emp_status_lbl.text = "Task: Harvest %s" % node.resource_type_id.capitalize()
				else:
					emp_status_lbl.text = "Task: Idle"
					
				if active_path != "" or active_node_path != "":
					var buttons_hbox = HBoxContainer.new()
					buttons_hbox.add_theme_constant_override("separation", 6)
					vbox.add_child(buttons_hbox)
					
					var emp_assign_btn = Button.new()
					emp_assign_btn.text = "Change Task"
					emp_assign_btn.add_theme_font_size_override("font_size", 11)
					emp_assign_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					emp_assign_btn.focus_mode = Control.FOCUS_ALL
					emp_assign_btn.pressed.connect(func(): _open_employee_assign_popup(i))
					_setup_button_hover(emp_assign_btn)
					buttons_hbox.add_child(emp_assign_btn)
					
					var stop_btn = Button.new()
					stop_btn.text = "Stop Work"
					stop_btn.add_theme_font_size_override("font_size", 11)
					stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					stop_btn.focus_mode = Control.FOCUS_ALL
					stop_btn.pressed.connect(func():
						_on_job_selected_direct(i, null, false, 0)
						refresh()
					)
					_setup_button_hover(stop_btn)
					buttons_hbox.add_child(stop_btn)
				else:
					var emp_assign_btn = Button.new()
					emp_assign_btn.text = "Assign Task"
					emp_assign_btn.add_theme_font_size_override("font_size", 11)
					emp_assign_btn.focus_mode = Control.FOCUS_ALL
					emp_assign_btn.pressed.connect(func(): _open_employee_assign_popup(i))
					_setup_button_hover(emp_assign_btn)
					vbox.add_child(emp_assign_btn)
			

			
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
			
		container.add_child(panel)

# --- 2. EMPLOYEES LISTS RENDERING ---

func _populate_hired_employees_list(container: VBoxContainer) -> void:
	if not _building.get("hired_employees") or _building.hired_employees.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No workers currently hired."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		container.add_child(empty_lbl)
		return
		
	for i in range(_building.hired_employees.size()):
		var emp = _building.hired_employees[i]
		
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.17, 0.22, 0.9)
		style.set_border_width_all(1)
		style.border_color = Color(0.24, 0.52, 0.85, 0.3)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		panel.add_child(hbox)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		
		var name_lbl = Label.new()
		var name_text = "%s (%s)" % [emp.get("name", "Worker"), emp.get("career", "Patreon").capitalize()]
		var is_route = emp.get("active_commercial_route") != null
		if is_route:
			name_text += " - [On Commercial Route]"
		name_lbl.text = name_text
		name_lbl.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(name_lbl)
		
		# Columns for Speed, Productivity, Salary
		var cols_hbox = HBoxContainer.new()
		cols_hbox.add_theme_constant_override("separation", 12)
		info_vbox.add_child(cols_hbox)
		
		var npc = emp.get("npc_ref")
		var emp_speed = emp.get("speed", 50.0)
		var emp_prod = emp.get("productivity", 1.0)
		if is_instance_valid(npc):
			emp_speed = npc.speed
			emp_prod = npc.productivity
			
		var speed_lbl = Label.new()
		speed_lbl.text = "Speed: %d" % int(emp_speed)
		speed_lbl.add_theme_font_size_override("font_size", 10)
		speed_lbl.modulate = Color(0.8, 0.8, 0.8)
		cols_hbox.add_child(speed_lbl)
		
		var prod_lbl = Label.new()
		prod_lbl.text = "Prod: %d%%" % int(emp_prod * 100.0)
		prod_lbl.add_theme_font_size_override("font_size", 10)
		prod_lbl.modulate = Color(0.8, 0.8, 0.8)
		cols_hbox.add_child(prod_lbl)
		
		if emp_prod > 1.0:
			var train_indicator = Label.new()
			train_indicator.text = "▲ Training"
			train_indicator.add_theme_font_size_override("font_size", 10)
			train_indicator.modulate = Color(0.2, 0.8, 0.2)
			cols_hbox.add_child(train_indicator)
			
		var sal_lbl = Label.new()
		sal_lbl.text = "Salary: %d G/day" % emp.get("salary", 15)
		sal_lbl.add_theme_font_size_override("font_size", 10)
		sal_lbl.modulate = Color(0.9, 0.8, 0.4)
		cols_hbox.add_child(sal_lbl)
		
		# Generate levels if missing, or retrieve
		var levels = emp.get("levels")
		if not levels:
			levels = {
				"patreon": 1,
				"scholar": 1,
				"craftsman": 1,
				"tailor": 1
			}
			emp["levels"] = levels
			
		var p_lvl = levels.get("patreon", 1)
		var s_lvl = levels.get("scholar", 1)
		var c_lvl = levels.get("craftsman", 1)
		var t_lvl = levels.get("tailor", 1)
		
		var levels_lbl = Label.new()
		levels_lbl.text = "Patreon: Lvl %d | Scholar: Lvl %d | Craftsman: Lvl %d | Tailor: Lvl %d" % [p_lvl, s_lvl, c_lvl, t_lvl]
		levels_lbl.add_theme_font_size_override("font_size", 10)
		levels_lbl.modulate = Color(0.65, 0.75, 0.9)
		info_vbox.add_child(levels_lbl)
		
		# Draw active gold-bordered traits for employee
		var max_lvl = max(p_lvl, max(s_lvl, max(c_lvl, t_lvl)))
		if max_lvl >= 5:
			var traits_hbox = HBoxContainer.new()
			traits_hbox.add_theme_constant_override("separation", 6)
			info_vbox.add_child(traits_hbox)
			
			var trait1 = PanelContainer.new()
			var style_t1 = StyleBoxFlat.new()
			style_t1.bg_color = Color(0.18, 0.14, 0.05, 0.8)
			style_t1.border_color = Color(0.9, 0.75, 0.15, 1.0)
			style_t1.set_border_width_all(1)
			style_t1.set_corner_radius_all(4)
			style_t1.content_margin_left = 6
			style_t1.content_margin_right = 6
			style_t1.content_margin_top = 2
			style_t1.content_margin_bottom = 2
			trait1.add_theme_stylebox_override("panel", style_t1)
			
			var lbl_t1 = Label.new()
			if max_lvl >= 8:
				lbl_t1.text = "Bountiful Harvest (35% Double Output)"
			else:
				lbl_t1.text = "Bountiful Harvest (20% Double Output)"
			lbl_t1.add_theme_font_size_override("font_size", 9)
			lbl_t1.modulate = Color(1.0, 0.9, 0.5)
			trait1.add_child(lbl_t1)
			traits_hbox.add_child(trait1)
			
			if max_lvl >= 8:
				var trait2 = PanelContainer.new()
				var style_t2 = StyleBoxFlat.new()
				style_t2.bg_color = Color(0.18, 0.14, 0.05, 0.8)
				style_t2.border_color = Color(0.9, 0.75, 0.15, 1.0)
				style_t2.set_border_width_all(1)
				style_t2.set_corner_radius_all(4)
				style_t2.content_margin_left = 6
				style_t2.content_margin_right = 6
				style_t2.content_margin_top = 2
				style_t2.content_margin_bottom = 2
				trait2.add_theme_stylebox_override("panel", style_t2)
				
				var lbl_t2 = Label.new()
				lbl_t2.text = "Artisan's Efficiency (Luxury -15% craft time)"
				lbl_t2.add_theme_font_size_override("font_size", 9)
				lbl_t2.modulate = Color(1.0, 0.9, 0.5)
				trait2.add_child(lbl_t2)
				traits_hbox.add_child(trait2)
		


		if _transfer_mode_emp_idx == i:
			var transfer_hbox = HBoxContainer.new()
			transfer_hbox.add_theme_constant_override("separation", 6)
			
			var dest_opt = OptionButton.new()
			dest_opt.add_theme_font_size_override("font_size", 10)
			
			var buildings = get_tree().get_nodes_in_group("production_buildings")
			var target_buildings = []
			for b in buildings:
				if is_instance_valid(b) and b.ownership_type == "Player" and b != _building:
					var hired = b.get("hired_employees")
					var max_emp = b.get("max_employees")
					if hired != null and max_emp != null and hired.size() < max_emp:
						target_buildings.append(b)
						
			if target_buildings.is_empty():
				dest_opt.add_item("No free workshops")
				dest_opt.disabled = true
			else:
				for b in target_buildings:
					var b_name = b.custom_name if (b.get("custom_name") != "" and "custom_name" in b) else b.name
					dest_opt.add_item(b_name.replace("Interior_", ""))
					
			transfer_hbox.add_child(dest_opt)
			
			var confirm_btn = Button.new()
			confirm_btn.text = "OK"
			confirm_btn.add_theme_font_size_override("font_size", 10)
			confirm_btn.disabled = target_buildings.is_empty()
			confirm_btn.pressed.connect(func():
				var sel_idx = dest_opt.selected
				if sel_idx >= 0 and sel_idx < target_buildings.size():
					var dest_building = target_buildings[sel_idx]
					var transfer_npc = emp.get("npc_ref")
					if is_instance_valid(transfer_npc) and transfer_npc.has_method("transfer_to_building"):
						transfer_npc.transfer_to_building(dest_building)
				_transfer_mode_emp_idx = -1
				refresh()
			)
			_setup_button_hover(confirm_btn)
			transfer_hbox.add_child(confirm_btn)
			
			var cancel_btn = Button.new()
			cancel_btn.text = "X"
			cancel_btn.add_theme_font_size_override("font_size", 10)
			cancel_btn.pressed.connect(func():
				_transfer_mode_emp_idx = -1
				refresh()
			)
			_setup_button_hover(cancel_btn)
			transfer_hbox.add_child(cancel_btn)
			
			hbox.add_child(transfer_hbox)
		else:
			var equip_btn = Button.new()
			equip_btn.text = "Equipment"
			equip_btn.add_theme_font_size_override("font_size", 11)
			equip_btn.pressed.connect(func(): _open_employee_equipment_popup(i))
			_setup_button_hover(equip_btn)
			hbox.add_child(equip_btn)
			
			var fire_btn = Button.new()
			fire_btn.text = "Fire"
			fire_btn.add_theme_font_size_override("font_size", 11)
			fire_btn.pressed.connect(func(): _fire_employee(i))
			_setup_button_hover(fire_btn)
			if is_route:
				fire_btn.disabled = true
				fire_btn.modulate = Color(0.6, 0.6, 0.6, 0.8)
			hbox.add_child(fire_btn)
			
			var transfer_btn = Button.new()
			transfer_btn.text = "Transfer"
			transfer_btn.add_theme_font_size_override("font_size", 11)
			transfer_btn.pressed.connect(func():
				_transfer_mode_emp_idx = i
				refresh()
			)
			_setup_button_hover(transfer_btn)
			if is_route:
				transfer_btn.disabled = true
				transfer_btn.modulate = Color(0.6, 0.6, 0.6, 0.8)
			hbox.add_child(transfer_btn)
		
		container.add_child(panel)

func _populate_candidates_list(container: VBoxContainer) -> void:
	if not _building.get("hireable_candidates"):
		return
		
	if _building.has_method("ensure_spouse_candidate"):
		_building.ensure_spouse_candidate()
		
	if _building.hireable_candidates.size() == 0:
		_building._populate_candidates()
		
	for i in range(_building.hireable_candidates.size()):
		var cand = _building.hireable_candidates[i]
		if not is_instance_valid(cand):
			continue
			
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.15, 0.6)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		panel.add_child(hbox)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		
		var cand_name = cand.npc_name if "npc_name" in cand else cand.name
		var cand_salary = cand.salary if "salary" in cand else 15
		var cand_career = cand.career if "career" in cand else "patreon"
		
		var name_lbl = Label.new()
		name_lbl.text = "%s (%s)" % [cand_name, cand_career.capitalize()]
		name_lbl.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(name_lbl)
		
		# Columns for Speed, Productivity, Salary
		var cols_hbox = HBoxContainer.new()
		cols_hbox.add_theme_constant_override("separation", 12)
		info_vbox.add_child(cols_hbox)
		
		var speed_val = cand.speed if "speed" in cand else 50.0
		var speed_lbl = Label.new()
		speed_lbl.text = "Speed: %d" % int(speed_val)
		speed_lbl.add_theme_font_size_override("font_size", 10)
		speed_lbl.modulate = Color(0.8, 0.8, 0.8)
		cols_hbox.add_child(speed_lbl)
		
		var prod_val = cand.productivity if "productivity" in cand else 1.0
		var prod_lbl = Label.new()
		prod_lbl.text = "Prod: %d%%" % int(prod_val * 100.0)
		prod_lbl.add_theme_font_size_override("font_size", 10)
		prod_lbl.modulate = Color(0.8, 0.8, 0.8)
		cols_hbox.add_child(prod_lbl)
		
		if prod_val > 1.0:
			var train_indicator = Label.new()
			train_indicator.text = "▲ Training"
			train_indicator.add_theme_font_size_override("font_size", 10)
			train_indicator.modulate = Color(0.2, 0.8, 0.2)
			cols_hbox.add_child(train_indicator)
			
		var sal_lbl = Label.new()
		sal_lbl.text = "Salary: %d G/day" % cand_salary
		sal_lbl.add_theme_font_size_override("font_size", 10)
		sal_lbl.modulate = Color(0.9, 0.8, 0.4)
		cols_hbox.add_child(sal_lbl)
		
		var p_lvl = cand.patreon_level if "patreon_level" in cand else 1
		var s_lvl = cand.scholar_level if "scholar_level" in cand else 1
		var c_lvl = cand.craftsman_level if "craftsman_level" in cand else 1
		var t_lvl = cand.tailor_level if "tailor_level" in cand else 1
		
		var levels_lbl = Label.new()
		levels_lbl.text = "Patreon: Lvl %d | Scholar: Lvl %d | Craftsman: Lvl %d | Tailor: Lvl %d" % [p_lvl, s_lvl, c_lvl, t_lvl]
		levels_lbl.add_theme_font_size_override("font_size", 10)
		levels_lbl.modulate = Color(0.65, 0.75, 0.9)
		info_vbox.add_child(levels_lbl)
		
		# Draw active gold-bordered traits for candidate
		var max_lvl = max(p_lvl, max(s_lvl, max(c_lvl, t_lvl)))
		if max_lvl >= 5:
			var traits_hbox = HBoxContainer.new()
			traits_hbox.add_theme_constant_override("separation", 6)
			info_vbox.add_child(traits_hbox)
			
			var trait1 = PanelContainer.new()
			var style_t1 = StyleBoxFlat.new()
			style_t1.bg_color = Color(0.18, 0.14, 0.05, 0.8)
			style_t1.border_color = Color(0.9, 0.75, 0.15, 1.0)
			style_t1.set_border_width_all(1)
			style_t1.set_corner_radius_all(4)
			style_t1.content_margin_left = 6
			style_t1.content_margin_right = 6
			style_t1.content_margin_top = 2
			style_t1.content_margin_bottom = 2
			trait1.add_theme_stylebox_override("panel", style_t1)
			
			var lbl_t1 = Label.new()
			if max_lvl >= 8:
				lbl_t1.text = "Bountiful Harvest (35% Double Output)"
			else:
				lbl_t1.text = "Bountiful Harvest (20% Double Output)"
			lbl_t1.add_theme_font_size_override("font_size", 9)
			lbl_t1.modulate = Color(1.0, 0.9, 0.5)
			trait1.add_child(lbl_t1)
			traits_hbox.add_child(trait1)
			
			if max_lvl >= 8:
				var trait2 = PanelContainer.new()
				var style_t2 = StyleBoxFlat.new()
				style_t2.bg_color = Color(0.18, 0.14, 0.05, 0.8)
				style_t2.border_color = Color(0.9, 0.75, 0.15, 1.0)
				style_t2.set_border_width_all(1)
				style_t2.set_corner_radius_all(4)
				style_t2.content_margin_left = 6
				style_t2.content_margin_right = 6
				style_t2.content_margin_top = 2
				style_t2.content_margin_bottom = 2
				trait2.add_theme_stylebox_override("panel", style_t2)
				
				var lbl_t2 = Label.new()
				lbl_t2.text = "Artisan's Efficiency (Luxury -15% craft time)"
				lbl_t2.add_theme_font_size_override("font_size", 9)
				lbl_t2.modulate = Color(1.0, 0.9, 0.5)
				trait2.add_child(lbl_t2)
				traits_hbox.add_child(trait2)
		
		var hire_btn = Button.new()
		hire_btn.text = "Hire"
		hire_btn.add_theme_font_size_override("font_size", 11)
		
		if _building.hired_employees.size() >= _building.max_employees:
			hire_btn.disabled = true
			hire_btn.tooltip_text = "Building at Max Capacity!"
			
		hire_btn.pressed.connect(func(): _hire_candidate(i))
		_setup_button_hover(hire_btn)
		hbox.add_child(hire_btn)
		
		container.add_child(panel)

# --- TRANSACTION SHORTCUT INPUT LOGIC ---

func _on_slot_gui_input(event: InputEvent, item: ItemData, source: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		var is_shift = event.shift_pressed
		var button = event.button_index
		
		if source == "building":
			if button == MOUSE_BUTTON_LEFT:
				# Left-Click: Transfer to Player Inventory
				_move_item_building_to_player(item, is_shift)
			elif button == MOUSE_BUTTON_RIGHT:
				# Right-Click: Transfer to Stall Storage (if produced here)
				_move_item_building_to_stall(item, is_shift)
				
		elif source == "stall":
			if button == MOUSE_BUTTON_LEFT:
				# Left-Click: Transfer back to Building Storage
				_move_item_stall_to_building(item, is_shift)
				
		elif source == "player":
			if button == MOUSE_BUTTON_LEFT:
				# Left-Click: Transfer to Building Storage
				_move_item_player_to_building(item, is_shift)

# --- TRANSFER CORE IMPLEMENTATIONS ---

func _move_item_player_to_building(item: ItemData, all_stack: bool) -> void:
	var source_inv = GameState.player_inventory
	if not source_inv:
		return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0:
		return
	if amt == 1:
		_move_item_player_to_building_action(item, 1)
	else:
		_open_quantity_slider(item, "player_to_building", amt, amt if all_stack else 1)

func _move_item_stall_to_building(item: ItemData, all_stack: bool) -> void:
	var source_inv = _building.inventory
	if not source_inv:
		return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0:
		return
	if amt == 1:
		_move_item_stall_to_building_action(item, 1)
	else:
		_open_quantity_slider(item, "stall_to_building", amt, amt if all_stack else 1)

func _move_item_building_to_player(item: ItemData, all_stack: bool) -> void:
	var source_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	if not source_inv:
		return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0:
		return
	if amt == 1:
		_move_item_building_to_player_action(item, 1)
	else:
		_open_quantity_slider(item, "building_to_player", amt, amt if all_stack else 1)

func _move_item_building_to_stall(item: ItemData, all_stack: bool) -> void:
	if not _is_produced_here(item):
		return
	var source_inv = _building.building_storage
	if not source_inv:
		return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0:
		return
	if amt == 1:
		_move_item_building_to_stall_action(item, 1)
	else:
		_open_quantity_slider(item, "building_to_stall", amt, amt if all_stack else 1)

# --- TRANSFER ACTION IMPLEMENTATIONS ---

func _move_item_player_to_building_action(item: ItemData, transfer_qty: int) -> void:
	var source_inv = GameState.player_inventory
	var target_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	if not source_inv or not target_inv:
		return
		
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Building storage is full!", _building.global_position)
		return
		
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Storage is full!", _building.global_position)

func _move_item_stall_to_building_action(item: ItemData, transfer_qty: int) -> void:
	var source_inv = _building.inventory
	var target_inv = _building.building_storage
	if not source_inv or not target_inv:
		return
		
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Building storage is full!", _building.global_position)
		return
		
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Storage is full!", _building.global_position)

func _move_item_building_to_player_action(item: ItemData, transfer_qty: int) -> void:
	var source_inv = _building.building_storage if _building.get("building_storage") else _building.inventory
	var target_inv = GameState.player_inventory
	if not source_inv or not target_inv:
		return
		
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Your inventory is full!", _building.global_position)
		return
		
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Your inventory is full!", _building.global_position)

func _move_item_building_to_stall_action(item: ItemData, transfer_qty: int) -> void:
	if not _is_produced_here(item):
		return
		
	var source_inv = _building.building_storage
	var target_inv = _building.inventory
	if not source_inv or not target_inv:
		return
		
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Stall is full (max 4 goods)!", _building.global_position)
		return
		
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Stall storage is full!", _building.global_position)

# --- QUANTITY SLIDER OVERLAY HELPERS ---

func _open_quantity_slider(item: ItemData, mode: String, max_limit: int, default_val: int = 1) -> void:
	if max_limit <= 0:
		return
		
	var focused = get_viewport().gui_get_focus_owner()
	if focused is Button:
		_last_focused_trigger_button = focused
	else:
		_last_focused_trigger_button = null
		
	for child in _slider_overlay.get_children():
		child.queue_free()
		
	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(320, 180)
	
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.offset_left = -160
	popup_panel.offset_right = 160
	popup_panel.offset_top = -90
	popup_panel.offset_bottom = 90
	
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	popup_style.set_border_width_all(2)
	popup_style.border_color = Color(0.24, 0.52, 0.85, 0.9)
	popup_style.set_corner_radius_all(10)
	popup_style.content_margin_left = 16
	popup_style.content_margin_right = 16
	popup_style.content_margin_top = 16
	popup_style.content_margin_bottom = 16
	popup_panel.add_theme_stylebox_override("panel", popup_style)
	
	_slider_overlay.add_child(popup_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup_panel.add_child(vbox)
	
	var title_lbl = Label.new()
	var mode_title = mode.replace("_", " ").capitalize()
	title_lbl.text = "[%s] %s" % [mode_title, item.name]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.52, 0.85, 1))
	vbox.add_child(title_lbl)
	
	var prompt_lbl = Label.new()
	prompt_lbl.text = "Select quantity (Max: %d):" % max_limit
	prompt_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(prompt_lbl)
	
	var slider = HSlider.new()
	slider.min_value = 1
	slider.max_value = max_limit
	slider.step = 1
	slider.value = clamp(default_val, 1, max_limit)
	vbox.add_child(slider)
	
	var display_lbl = Label.new()
	display_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(display_lbl)
	
	var update_display = func(val: float):
		display_lbl.text = "Amount: %d" % int(val)
			
	slider.value_changed.connect(update_display)
	update_display.call(slider.value)
	
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 16)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons_hbox)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(85, 28)
	cancel_btn.pressed.connect(_close_slider_popup)
	_setup_button_hover(cancel_btn)
	buttons_hbox.add_child(cancel_btn)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(85, 28)
	confirm_btn.pressed.connect(func():
		var amt = int(slider.value)
		_close_slider_popup()
		_execute_transfer(item, mode, amt)
	)
	_setup_button_hover(confirm_btn)
	buttons_hbox.add_child(confirm_btn)
	
	_slider_overlay.show()
	confirm_btn.grab_focus()

func _close_slider_popup() -> void:
	if _slider_overlay:
		for child in _slider_overlay.get_children():
			child.queue_free()
		_slider_overlay.hide()
		
	var focus_restored = false
	if _last_focused_trigger_button and is_instance_valid(_last_focused_trigger_button) and _last_focused_trigger_button.is_inside_tree() and not _last_focused_trigger_button.disabled and _last_focused_trigger_button.visible:
		_last_focused_trigger_button.grab_focus()
		focus_restored = true
		
	if not focus_restored:
		_focus_first_button()

func _execute_transfer(item: ItemData, mode: String, amount: int) -> void:
	if mode == "player_to_building":
		_move_item_player_to_building_action(item, amount)
	elif mode == "building_to_player":
		_move_item_building_to_player_action(item, amount)
	elif mode == "building_to_stall":
		_move_item_building_to_stall_action(item, amount)
	elif mode == "stall_to_building":
		_move_item_stall_to_building_action(item, amount)

func _find_slider_in_node(node: Node) -> HSlider:
	if node is HSlider:
		return node
	for child in node.get_children():
		var found = _find_slider_in_node(child)
		if found:
			return found
	return null

func _find_confirm_button_in_node(node: Node) -> Button:
	if node is Button and node.text == "Confirm":
		return node
	for child in node.get_children():
		var found = _find_confirm_button_in_node(child)
		if found:
			return found
	return null

# --- SYSTEM HELPERS ---

func _is_produced_here(item: ItemData) -> bool:
	var recipes = _get_recipes()
	for recipe in recipes:
		if recipe and recipe.output_item and recipe.output_item.id == item.id:
			return true
	return false

func _get_recipes() -> Array:
	if not _building:
		return []
	var bench = _building.get_node_or_null("CraftingBench")
	if bench and "recipes" in bench:
		return bench.recipes
	return []

func _get_compatible_nodes() -> Array:
	var compatible = []
	var recipes = _get_recipes()
	var required_inputs = {}
	for recipe in recipes:
		if recipe:
			for input_item in recipe.inputs:
				required_inputs[input_item.id] = true
				
	var nodes = get_tree().get_nodes_in_group("MegaNodes")
	for node in nodes:
		if node.resource_type_id in required_inputs:
			compatible.append(node)
	return compatible

func _start_gathering_shift(emp_idx: int, node: Area2D) -> void:
	var emp = _building.hired_employees[emp_idx]
	var fee = node.get_entry_fee()
	if GameState.gold >= fee:
		GameState.gold -= fee
		GameState.spawn_ui_floating_text("Paid Permit: -%d Gold!" % fee)
		if _building.has_method("_spawn_shift_worker"):
			_building._spawn_shift_worker(emp, node)
		refresh()
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Cannot afford permit fee!", _building.global_position)

func _update_progress_bars() -> void:
	if _updating_ui:
		return
		
	# Update structural upgrade renovation progress
	if _renovation_pbar and _renovation_lbl and is_instance_valid(_renovation_pbar) and is_instance_valid(_renovation_lbl) and _building.is_upgrading:
		var timer = _building.upgrade_timer
		var next_lvl = _building.building_level + 1
		var req = _building.UPGRADE_REQUIREMENTS.get(next_lvl)
		if req:
			var total = req.time
			var pct = ((total - timer) / total) * 100.0
			_renovation_pbar.value = pct
			_renovation_lbl.text = "Renovation... %.1fs remaining" % timer
		else:
			_renovation_pbar.value = 100.0
			_renovation_lbl.text = "Completing upgrade..."
			
	if not _building.get("hired_employees"):
		return
		
	for i in range(_building.hired_employees.size()):
		var emp = _building.hired_employees[i]
		var pbar = _progress_bars.get(i)
		var label = _timer_labels.get(i)
		
		if not pbar or not label:
			continue
			
		var route = emp.get("active_commercial_route")
		if route != null:
			var npc = emp.get("npc_ref")
			var state_str = "On Commercial Route"
			if is_instance_valid(npc):
				var w_state = npc.get("worker_state")
				var cargo_name = npc.commercial_route_cargo_item_id.capitalize() if npc.commercial_route_cargo_item_id != "" else "Cargo"
				match w_state:
					"commercial_route_loading":
						state_str = "Loading: %s (%d/%d)" % [cargo_name, npc.commercial_route_cargo_amount, route.target_amount]
					"commercial_route_transit":
						state_str = "Logistics: Waypoint %d/%d (Carrying %d %s)" % [npc.commercial_route_current_waypoint_index + 1, route.market_waypoints.size(), npc.commercial_route_cargo_amount, cargo_name]
					"commercial_route_returning":
						state_str = "Returning with revenue/unsold items"
			pbar.value = 100.0
			label.text = state_str
			continue
			
		var recipe_path = emp.get("active_recipe_path", "")
		var node_path = str(emp.get("active_gathering_node_path", ""))
		
		if recipe_path != "":
			var timer = emp.get("craft_timer", 0.0)
			var total = emp.get("craft_total_time", 5.0)
			var worker = emp.get("npc_ref")
			
			if is_instance_valid(worker) and worker.get("worker_state") == "traveling_to_workbench":
				pbar.value = 0.0
				label.text = "Traveling to workbench..."
			else:
				if total > 0.0:
					var pct = ((total - timer) / total) * 100.0
					pbar.value = pct
					label.text = "Crafting... %.1fs remaining" % timer
				else:
					pbar.value = 0.0
					label.text = "Starting..."
		elif node_path != "":
			var worker = emp.get("shift_worker_ref")
			if is_instance_valid(worker):
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
					var pct = ((120.0 - timer) / 120.0) * 100.0
					pbar.value = pct
					label.text = "Gathering... %.1fs remaining" % timer
				elif w_state == "traveling_to_node":
					pbar.value = 0.0
					label.text = "Traveling to node..."
				else:
					pbar.value = 0.0
					label.text = "Ready to start shift"
			else:
				pbar.value = 0.0
				if emp.get("shift_status") == "returning":
					label.text = "Completed!"
				else:
					label.text = "Ready to start shift"
		else:
			pbar.value = 0.0
			label.text = "Idle"

func _on_job_selected_direct(emp_idx: int, task: Object, is_indefinite: bool, amount: int) -> void:
	var emp = _building.hired_employees[emp_idx]
	
	# Cancel active state safely
	emp["active_recipe_path"] = ""
	emp["active_gathering_node_path"] = ""
	emp["shift_status"] = "idle"
	emp["is_repeating"] = is_indefinite
	emp["production_amount_limit"] = amount
	
	var worker = emp.get("shift_worker_ref")
	if not is_instance_valid(worker):
		worker = emp.get("npc_ref")
		
	if is_instance_valid(worker):
		if worker.get("is_gathering") or worker.get("worker_state") in ["traveling_to_node", "gathering_at_node", "returning_to_workshop"]:
			worker.set("is_gathering", false)
			if is_instance_valid(worker.get("target_mega_node")):
				worker.target_mega_node._on_body_exited(worker)
			worker.set("worker_state", "traveling_to_workshop")
			var target_pos = _building.get_interaction_position()
			if worker.has_method("_generate_path"):
				worker.call("_generate_path", target_pos)
		emp["shift_worker_ref"] = null
		
	if task == null:
		emp["craft_timer"] = 0.0
		emp["craft_total_time"] = 0.0
		var npc = emp.get("npc_ref")
		if is_instance_valid(npc):
			npc.set("worker_state", "traveling_to_workshop")
			var target_pos = _building.get_interaction_position()
			npc.call("_generate_path", target_pos)
		_close_slider_popup()
		refresh()
		return
		
	if task is Recipe:
		# Check Metallurgical Monopoly (smelting outside city walls)
		var pm = get_node_or_null("/root/PoliticsManager")
		var b_prov = GameState.get_province_of_node(_building) if GameState else ""
		if pm and b_prov != "":
			if pm.is_law_active("metallurgical_monopoly", b_prov) and _building.is_in_group("Smelters"):
				var sett = GameState.get_nearest_settlement(_building)
				if sett and not sett.is_in_group("Cities"):
					var hud = get_tree().get_first_node_in_group("PlayerHUD")
					if hud:
						hud._spawn_floating_text("Illegal! Smelting outside city walls is banned in this province.", _building.global_position)
					_close_slider_popup()
					refresh()
					return

		var active_crafters = 0
		if _building.get("is_player_working_here") == true:
			active_crafters += 1
		for other_idx in range(_building.hired_employees.size()):
			if other_idx != emp_idx:
				if _building.hired_employees[other_idx].get("active_recipe_path", "") != "":
					active_crafters += 1
		var limit = 1 + (_building.improvements.get("extra_workbench", 0) if typeof(_building.improvements) == TYPE_DICTIONARY else 0)
		if active_crafters >= limit:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = get_tree().get_first_node_in_group("game_hud")
			if hud:
				hud._spawn_floating_text("All crafting benches are occupied!", _building.global_position)
			_close_slider_popup()
			refresh()
			return
			
		var target_b_storage = _building.building_storage if _building.get("building_storage") else _building.inventory
		var inputs_ok = true
		for item in task.inputs:
			var qty = task.inputs[item]
			if target_b_storage.get_item_amount(item.id) < qty:
				inputs_ok = false
				break
				
		var missing_raw_material = null
		if not inputs_ok and (_building.improvements.get("auto_gathering", 0) > 0):
			for item in task.inputs:
				var qty = task.inputs[item]
				if target_b_storage.get_item_amount(item.id) < qty:
					if item.is_raw_material:
						missing_raw_material = item
						break
						
		if missing_raw_material != null and pm and b_prov != "":
			if pm.is_law_active("crown_forestry_protection", b_prov) and missing_raw_material.id == "standard_timber":
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud:
					hud._spawn_floating_text("Illegal! Auto-gathering timber is banned by law.", _building.global_position)
				_close_slider_popup()
				refresh()
				return
			if pm.is_law_active("noble_game_preservation", b_prov) and missing_raw_material.id == "venison":
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud:
					hud._spawn_floating_text("Illegal! Auto-gathering venison is banned by law.", _building.global_position)
				_close_slider_popup()
				refresh()
				return

		var npc = emp.get("npc_ref")
		if inputs_ok or missing_raw_material != null:
			if inputs_ok:
				for item in task.inputs:
					var qty = task.inputs[item]
					target_b_storage.remove_item(item.id, qty)
					
				var craft_time = 5.0
				if _building.has_method("get_employee_craft_time"):
					craft_time = _building.get_employee_craft_time(emp, task)
				else:
					craft_time = float(task.required_level * 5.0)
					var prod = npc.get("productivity") if is_instance_valid(npc) else 1.0
					if prod > 0.0:
						craft_time /= prod
						
				emp["active_recipe_path"] = task.resource_path
				emp["craft_timer"] = craft_time
				emp["craft_total_time"] = craft_time
				emp["is_paused"] = false
				
				if is_instance_valid(npc):
					npc.set("worker_state", "traveling_to_workbench")
					if npc.global_position.y < 9000.0 and is_instance_valid(_building.instanced_interior):
						npc.call("_teleport", _building.instanced_interior.global_position + Vector2(0, 40))
					if is_instance_valid(_building.instanced_interior) and is_instance_valid(_building.instanced_interior.crafting_bench):
						var bench_pos = _building.instanced_interior.crafting_bench.global_position
						npc.call("_generate_path", bench_pos)
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
				var b_name = _building.name.replace("Interior_", "")
				var msg = "%s cannot start producing %s at %s: Insufficient inputs in storage." % [emp.get("name", "Employee"), task.output_item.name, b_name]
				GameState.add_alert("Production Blocked", msg, "warning", _building)
				
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud:
				hud._spawn_floating_text("Employee assigned (Paused: Missing materials)", _building.global_position)
				
	elif task is Area2D:
		var node = task
		var res_id = node.resource_type_id
		
		# Check if the resource type is illegal in this province due to laws
		var pm_res = get_node_or_null("/root/PoliticsManager")
		var b_prov_res = GameState.get_province_of_node(_building) if GameState else ""
		if pm_res and b_prov_res != "":
			if pm_res.is_law_active("crown_forestry_protection", b_prov_res) and res_id == "standard_timber":
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud:
					hud._spawn_floating_text("Illegal! Harvesting timber is banned in this province.", _building.global_position)
				_close_slider_popup()
				refresh()
				return
			if pm_res.is_law_active("noble_game_preservation", b_prov_res) and res_id == "venison":
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud:
					hud._spawn_floating_text("Illegal! Hunting venison is banned in this province.", _building.global_position)
				_close_slider_popup()
				refresh()
				return
				
		var econ_mgr = get_node_or_null("/root/EconomyManager")
		var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
		var b_storage = _building.building_storage
		var has_space = false
		if b_storage and item_res:
			has_space = b_storage.get_free_space_for_item(item_res) >= 20
			
		if not has_space:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud:
				hud._spawn_floating_text("Insufficient warehouse capacity (Requires 20 slots).", _building.global_position)
			_close_slider_popup()
			refresh()
			return
			
		var fee = node.get_entry_fee()
		if GameState.gold < fee:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud:
				hud._spawn_floating_text("Cannot afford permit fee!", _building.global_position)
			_close_slider_popup()
			refresh()
			return
			
		GameState.gold -= fee
		var npc = emp.get("npc_ref")
		emp["active_gathering_node_path"] = node.get_path()
		emp["shift_status"] = "traveling"
		
		if is_instance_valid(npc):
			npc.start_gathering_shift(node)
			emp["shift_worker_ref"] = npc
			
	_close_slider_popup()
	refresh()

func _create_task_card(name_text: String, art_label_text: String, pressed_callback: Callable) -> Button:
	var card_btn = Button.new()
	card_btn.custom_minimum_size = Vector2(76, 82)
	card_btn.focus_mode = Control.FOCUS_ALL
	_setup_button_hover(card_btn)
	
	var card_style_normal = StyleBoxFlat.new()
	card_style_normal.bg_color = Color(0.12, 0.15, 0.22, 0.6)
	card_style_normal.border_color = Color(0.24, 0.52, 0.85, 0.4)
	card_style_normal.set_border_width_all(1)
	card_style_normal.set_corner_radius_all(6)
	
	var card_style_hover = card_style_normal.duplicate() as StyleBoxFlat
	card_style_hover.bg_color = Color(0.16, 0.20, 0.30, 0.85)
	card_style_hover.border_color = Color(0.24, 0.52, 0.85, 0.9)
	card_style_hover.set_border_width_all(1.2)
	
	var card_style_focused = card_style_hover.duplicate() as StyleBoxFlat
	card_style_focused.border_color = Color(0.24, 0.52, 0.85, 1.0)
	card_style_focused.set_border_width_all(1.5)
	
	card_btn.add_theme_stylebox_override("normal", card_style_normal)
	card_btn.add_theme_stylebox_override("hover", card_style_hover)
	card_btn.add_theme_stylebox_override("focus", card_style_focused)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 4)
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_btn.add_child(card_vbox)
	card_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var art_placeholder = Panel.new()
	art_placeholder.custom_minimum_size = Vector2(32, 32)
	art_placeholder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var art_style = StyleBoxFlat.new()
	art_style.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	art_style.border_color = Color(0.4, 0.45, 0.5, 0.3)
	art_style.set_border_width_all(1)
	art_style.set_corner_radius_all(4)
	art_placeholder.add_theme_stylebox_override("panel", art_style)
	
	var art_lbl = Label.new()
	art_lbl.text = art_label_text
	art_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_lbl.add_theme_font_size_override("font_size", 12)
	art_lbl.modulate = Color(0.6, 0.7, 0.8)
	art_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_placeholder.add_child(art_lbl)
	card_vbox.add_child(art_placeholder)
	
	var name_lbl = Label.new()
	name_lbl.text = name_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(name_lbl)
	
	card_btn.pressed.connect(pressed_callback)
	return card_btn

func _open_player_assign_popup() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused is Button:
		_last_focused_trigger_button = focused
	else:
		_last_focused_trigger_button = null
		
	_close_slider_popup()
	
	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(400, 300)
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.offset_left = -200
	popup_panel.offset_right = 200
	popup_panel.offset_top = -150
	popup_panel.offset_bottom = 150
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.24, 0.52, 0.85, 0.8)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	popup_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Assign Task - Player"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.24, 0.52, 0.85, 1.0))
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.add_theme_constant_override("separation", 16)
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_vbox)
	
	var first_focus_btn = null
	
	var recipes = _get_recipes()
	if not recipes.is_empty():
		var prod_title = Label.new()
		prod_title.text = "Production Tasks"
		prod_title.add_theme_font_size_override("font_size", 11)
		prod_title.modulate = Color(0.24, 0.52, 0.85, 1.0)
		scroll_vbox.add_child(prod_title)
		
		var items_grid = GridContainer.new()
		items_grid.columns = 4
		items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_grid.add_theme_constant_override("h_separation", 8)
		items_grid.add_theme_constant_override("v_separation", 8)
		scroll_vbox.add_child(items_grid)
		
		for recipe in recipes:
			if recipe:
				var name_to_display = recipe.output_item.name if recipe.output_item else recipe.recipe_name
				var card = _create_task_card(name_to_display, "🔨", func():
					_close_slider_popup()
					_building.start_player_crafting(recipe.resource_path)
					refresh()
				)
				items_grid.add_child(card)
				if not first_focus_btn:
					first_focus_btn = card
			
	var close_btn = Button.new()
	close_btn.text = "Cancel"
	close_btn.custom_minimum_size = Vector2(90, 26)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		_close_slider_popup()
	)
	_setup_button_hover(close_btn)
	vbox.add_child(close_btn)
	
	_slider_overlay.add_child(popup_panel)
	_slider_overlay.show()
	
	if first_focus_btn:
		first_focus_btn.grab_focus()
	else:
		close_btn.grab_focus()

func _open_employee_assign_popup(emp_idx: int) -> void:
	if not _building.get("hired_employees") or emp_idx >= _building.hired_employees.size():
		return
		
	var focused = get_viewport().gui_get_focus_owner()
	if focused is Button:
		_last_focused_trigger_button = focused
	else:
		_last_focused_trigger_button = null
		
	var emp = _building.hired_employees[emp_idx]
	_close_slider_popup()
	
	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(580, 360)
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.offset_left = -290
	popup_panel.offset_right = 290
	popup_panel.offset_top = -180
	popup_panel.offset_bottom = 180
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.24, 0.52, 0.85, 0.8)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	popup_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Assign Task - %s" % emp.get("name", "Employee")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.24, 0.52, 0.85, 1.0))
	vbox.add_child(title)
	
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_hbox)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(left_vbox)
	
	var select_lbl = Label.new()
	select_lbl.text = "Select a task:"
	select_lbl.add_theme_font_size_override("font_size", 11)
	select_lbl.modulate = Color(0.7, 0.7, 0.7)
	left_vbox.add_child(select_lbl)
	
	var task_scroll = ScrollContainer.new()
	task_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(task_scroll)
	
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.add_theme_constant_override("separation", 16)
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_scroll.add_child(scroll_vbox)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(200, 0)
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.visible = false
	content_hbox.add_child(right_vbox)
	
	var qty_lbl = Label.new()
	qty_lbl.text = "Select Quantity:"
	qty_lbl.add_theme_font_size_override("font_size", 11)
	qty_lbl.modulate = Color(0.7, 0.7, 0.7)
	right_vbox.add_child(qty_lbl)
	
	var qty_buttons_vbox = VBoxContainer.new()
	qty_buttons_vbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(qty_buttons_vbox)
	
	var first_focus_btn = null
	
	var recipes = _get_recipes()
	if not recipes.is_empty():
		var prod_title = Label.new()
		prod_title.text = "Production Tasks"
		prod_title.add_theme_font_size_override("font_size", 11)
		prod_title.modulate = Color(0.24, 0.52, 0.85, 1.0)
		scroll_vbox.add_child(prod_title)
		
		var prod_grid = GridContainer.new()
		prod_grid.columns = 4
		prod_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prod_grid.add_theme_constant_override("h_separation", 8)
		prod_grid.add_theme_constant_override("v_separation", 8)
		scroll_vbox.add_child(prod_grid)
		
		for recipe in recipes:
			if recipe:
				var name_to_display = recipe.output_item.name if recipe.output_item else recipe.recipe_name
				var card = _create_task_card(name_to_display, "🔨", func():
					right_vbox.visible = true
					for child in qty_buttons_vbox.get_children():
						child.queue_free()
						
					var quantities = [1, 5, 10, 25]
					var first_q_btn = null
					for qty in quantities:
						var q_btn = Button.new()
						q_btn.text = "Limit to %d" % qty
						q_btn.add_theme_font_size_override("font_size", 10)
						_setup_button_hover(q_btn)
						q_btn.pressed.connect(func():
							_on_job_selected_direct(emp_idx, recipe, false, qty)
						)
						qty_buttons_vbox.add_child(q_btn)
						if not first_q_btn:
							first_q_btn = q_btn
							
					var indef_btn = Button.new()
					indef_btn.text = "Continuous (Indefinite)"
					indef_btn.add_theme_font_size_override("font_size", 10)
					_setup_button_hover(indef_btn)
					indef_btn.pressed.connect(func():
						_on_job_selected_direct(emp_idx, recipe, true, 0)
					)
					qty_buttons_vbox.add_child(indef_btn)
					
					if first_q_btn:
						first_q_btn.grab_focus()
				)
				prod_grid.add_child(card)
				if not first_focus_btn:
					first_focus_btn = card
			
	var comp_nodes = _get_compatible_nodes()
	if not comp_nodes.is_empty():
		var gather_title = Label.new()
		gather_title.text = "Gathering Tasks"
		gather_title.add_theme_font_size_override("font_size", 11)
		gather_title.modulate = Color(0.4, 0.85, 0.4, 1.0)
		scroll_vbox.add_child(gather_title)
		
		var gather_grid = GridContainer.new()
		gather_grid.columns = 4
		gather_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gather_grid.add_theme_constant_override("h_separation", 8)
		gather_grid.add_theme_constant_override("v_separation", 8)
		scroll_vbox.add_child(gather_grid)
		
		var added_node_types = {}
		for node in comp_nodes:
			if node:
				var node_name = node.resource_type_id.capitalize()
				if added_node_types.has(node_name):
					continue
				added_node_types[node_name] = true
				
				var card = _create_task_card(node_name, "⛏️", func():
					_on_job_selected_direct(emp_idx, node, true, 0)
				)
				gather_grid.add_child(card)
				if not first_focus_btn:
					first_focus_btn = card
			
	var close_btn = Button.new()
	close_btn.text = "Cancel"
	close_btn.custom_minimum_size = Vector2(90, 26)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		_close_slider_popup()
	)
	_setup_button_hover(close_btn)
	vbox.add_child(close_btn)
	
	_slider_overlay.add_child(popup_panel)
	_slider_overlay.show()
	
	if first_focus_btn:
		first_focus_btn.grab_focus()
	else:
		close_btn.grab_focus()

func _fire_employee(idx: int) -> void:
	if idx < _building.hired_employees.size():
		var emp = _building.hired_employees[idx]
		_building.hired_employees.remove_at(idx)
		
		var npc = emp.get("npc_ref")
		if is_instance_valid(npc):
			npc.resume_normal_behavior()
			
		refresh()

func _hire_candidate(idx: int) -> void:
	if _building.hired_employees.size() < _building.max_employees:
		var cand = _building.hireable_candidates[idx]
		_building.hireable_candidates.remove_at(idx)
		
		if is_instance_valid(cand):
			cand.go_to_workshop(_building)
			
			_building.hired_employees.append({
				"npc_ref": cand,
				"name": cand.npc_name,
				"salary": cand.salary,
				"career": cand.career,
				"levels": {
					"patreon": cand.patreon_level,
					"scholar": cand.scholar_level,
					"craftsman": cand.craftsman_level,
					"tailor": cand.tailor_level
				},
				"active_recipe_path": "",
				"craft_timer": 0.0,
				"craft_total_time": 0.0,
				"is_repeating": true,
				"auto_gather_on_shortage": false,
				"is_paused": false
			})
		refresh()

func _setup_button_hover(button: Button) -> void:
	var update_pivot = func():
		button.pivot_offset = button.size / 2.0
	update_pivot.call()
	if not button.resized.is_connected(update_pivot):
		button.resized.connect(update_pivot)
		
	button.mouse_entered.connect(func():
		if not button.disabled:
			var tween = create_tween()
			tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.08)
	)
	button.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
	)

func _focus_first_button() -> void:
	if not is_inside_tree() or not visible:
		return
	# Wait two process frames to guarantee tree visibility propagation and UI rendering are fully complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_inside_tree() or not visible:
		return
	
	# Attempt to find first focusable button inside columns
	if left_column.get_child_count() > 0:
		var btn = _find_first_focusable_button(left_column)
		if btn and is_instance_valid(btn) and btn.is_inside_tree() and btn.visible:
			btn.grab_focus()
			return
			
	if right_column.get_child_count() > 0:
		var btn = _find_first_focusable_button(right_column)
		if btn and is_instance_valid(btn) and btn.is_inside_tree() and btn.visible:
			btn.grab_focus()
			return
			
	if bottom_close_button:
		bottom_close_button.grab_focus()

func _find_first_focusable_button(node: Node) -> Button:
	if node is Button and node.focus_mode == Control.FOCUS_ALL and not node.disabled and node.visible:
		return node
	for child in node.get_children():
		var found = _find_first_focusable_button(child)
		if found:
			return found
	return null

func _render_management_tab() -> void:
	# Populate sub-tabs container
	if _subtab_container:
		for child in _subtab_container.get_children():
			_subtab_container.remove_child(child)
			child.queue_free()
			
		var subtab_names = ["Structure Upgrade", "Upgrades & Renovations"]
		for i in range(subtab_names.size()):
			var sub_btn = Button.new()
			sub_btn.text = subtab_names[i]
			sub_btn.flat = true
			sub_btn.focus_mode = Control.FOCUS_NONE
			sub_btn.add_theme_font_size_override("font_size", 11)
			
			var style = StyleBoxFlat.new()
			style.content_margin_left = 16
			style.content_margin_right = 16
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			style.set_corner_radius_all(4)
			
			if i == _active_management_subtab:
				style.bg_color = Color(0.58, 0.34, 0.75, 0.9) # highlighted purple
				sub_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			else:
				style.bg_color = Color(0.16, 0.14, 0.20, 0.6)
				sub_btn.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
				
			sub_btn.add_theme_stylebox_override("normal", style)
			sub_btn.add_theme_stylebox_override("hover", style)
			sub_btn.add_theme_stylebox_override("pressed", style)
			sub_btn.add_theme_stylebox_override("focus", style)
			
			var idx = i
			sub_btn.pressed.connect(func():
				_active_management_subtab = idx
				refresh()
				_focus_first_button()
			)
			_subtab_container.add_child(sub_btn)
			
	if _active_management_subtab == 0:
		_render_structure_upgrade_view()
	else:
		_render_improvements_view()

func _render_structure_upgrade_view() -> void:
	# Left Column: Level and Requirements
	var header_lbl = Label.new()
	header_lbl.text = "Structure Renovation"
	header_lbl.add_theme_font_size_override("font_size", 14)
	left_column.add_child(header_lbl)
	
	var info_panel = PanelContainer.new()
	var style_info = StyleBoxFlat.new()
	style_info.bg_color = Color(0.14, 0.12, 0.18, 0.8)
	style_info.set_corner_radius_all(6)
	style_info.content_margin_left = 12
	style_info.content_margin_right = 12
	style_info.content_margin_top = 10
	style_info.content_margin_bottom = 10
	info_panel.add_theme_stylebox_override("panel", style_info)
	left_column.add_child(info_panel)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_vbox)
	
	var lvl_lbl = Label.new()
	lvl_lbl.text = "Current Building Level: Level %d" % _building.building_level
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.modulate = Color(0.75, 0.85, 1.0)
	info_vbox.add_child(lvl_lbl)
	
	var next_lvl = _building.building_level + 1
	var has_next = _building.UPGRADE_REQUIREMENTS.has(next_lvl)
	
	if _building.is_upgrading:
		var upgrading_lbl = Label.new()
		upgrading_lbl.text = "Status: Renovating Structure..."
		upgrading_lbl.add_theme_font_size_override("font_size", 12)
		upgrading_lbl.modulate = Color(0.95, 0.8, 0.2)
		info_vbox.add_child(upgrading_lbl)
		
		# Giant progress bar
		_renovation_pbar = ProgressBar.new()
		_renovation_pbar.custom_minimum_size = Vector2(0, 20)
		_renovation_pbar.show_percentage = true
		info_vbox.add_child(_renovation_pbar)
		
		_renovation_lbl = Label.new()
		_renovation_lbl.add_theme_font_size_override("font_size", 10)
		_renovation_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(_renovation_lbl)
	else:
		_renovation_pbar = null
		_renovation_lbl = null
		
		if has_next:
			var req = _building.UPGRADE_REQUIREMENTS[next_lvl]
			
			var req_lbl = Label.new()
			req_lbl.text = "Requirements for Level %d:" % next_lvl
			req_lbl.add_theme_font_size_override("font_size", 12)
			info_vbox.add_child(req_lbl)
			
			# Gold requirement
			var gold_lbl = Label.new()
			var meets_gold = GameState.gold >= req.gold_cost
			gold_lbl.text = " • Gold Cost: %d G (Current: %d G)" % [req.gold_cost, GameState.gold]
			gold_lbl.add_theme_font_size_override("font_size", 11)
			gold_lbl.modulate = Color(0.2, 0.8, 0.4) if meets_gold else Color(0.9, 0.3, 0.3)
			info_vbox.add_child(gold_lbl)
			
			# Career level requirement
			var career_id = "craftsman"
			if _building.building_data and _building.building_data.career != "":
				career_id = _building.building_data.career
			var p_lvl = GameState.career_levels.get(career_id, 1)
			var meets_lvl = p_lvl >= req.profession_level
			var lvl_text = " • Player %s Level: %d (Current: %d)" % [career_id.capitalize(), req.profession_level, p_lvl]
			var career_lbl = Label.new()
			career_lbl.text = lvl_text
			career_lbl.add_theme_font_size_override("font_size", 11)
			career_lbl.modulate = Color(0.2, 0.8, 0.4) if meets_lvl else Color(0.9, 0.3, 0.3)
			info_vbox.add_child(career_lbl)
			
			# Construction downtime
			var time_lbl = Label.new()
			time_lbl.text = " • Construction Downtime: %d seconds" % int(req.time)
			time_lbl.add_theme_font_size_override("font_size", 11)
			time_lbl.modulate = Color(0.7, 0.75, 0.85)
			info_vbox.add_child(time_lbl)
		else:
			var max_lbl = Label.new()
			max_lbl.text = "Structure is at maximum level (Level %d)." % _building.building_level
			max_lbl.add_theme_font_size_override("font_size", 12)
			max_lbl.modulate = Color(0.58, 0.34, 0.75)
			info_vbox.add_child(max_lbl)
			
	# Right Column: Buff details and Renovation button
	var upgrade_title = Label.new()
	upgrade_title.text = "Renovation Buffs & Execution"
	upgrade_title.add_theme_font_size_override("font_size", 14)
	right_column.add_child(upgrade_title)
	
	var run_panel = PanelContainer.new()
	var style_run = StyleBoxFlat.new()
	style_run.bg_color = Color(0.14, 0.12, 0.18, 0.8)
	style_run.set_corner_radius_all(6)
	style_run.content_margin_left = 12
	style_run.content_margin_right = 12
	style_run.content_margin_top = 10
	style_run.content_margin_bottom = 10
	run_panel.add_theme_stylebox_override("panel", style_run)
	right_column.add_child(run_panel)
	
	var run_vbox = VBoxContainer.new()
	run_vbox.add_theme_constant_override("separation", 10)
	run_panel.add_child(run_vbox)
	
	var buff_desc = Label.new()
	buff_desc.text = "Upgrading the building advances its structural capacity:\n • Increases base employee crafting slot capacity.\n • Unlocks high-tier recipe categories inside the building.\n • Increases maximum income parameters."
	buff_desc.add_theme_font_size_override("font_size", 11)
	buff_desc.modulate = Color(0.8, 0.85, 0.9)
	buff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	run_vbox.add_child(buff_desc)
	
	var upgrade_btn = Button.new()
	upgrade_btn.text = "Begin Renovation"
	upgrade_btn.focus_mode = Control.FOCUS_ALL
	upgrade_btn.add_theme_font_size_override("font_size", 12)
	_setup_button_hover(upgrade_btn)
	run_vbox.add_child(upgrade_btn)
	
	if _building.is_upgrading:
		upgrade_btn.disabled = true
		upgrade_btn.text = "Renovation in Progress..."
	elif has_next:
		var req = _building.UPGRADE_REQUIREMENTS[next_lvl]
		var career_id = "craftsman"
		if _building.building_data and _building.building_data.career != "":
			career_id = _building.building_data.career
		var p_lvl = GameState.career_levels.get(career_id, 1)
		
		var meets_req = (GameState.gold >= req.gold_cost) and (p_lvl >= req.profession_level)
		if not meets_req:
			upgrade_btn.disabled = true
			upgrade_btn.text = "Requirements Not Met"
		else:
			upgrade_btn.pressed.connect(func():
				_building.initiate_level_upgrade()
				refresh()
			)
	else:
		upgrade_btn.visible = false

func _render_improvements_view() -> void:
	var imp_left_lbl = Label.new()
	imp_left_lbl.text = "Warehouse & Crafting Improvements"
	imp_left_lbl.add_theme_font_size_override("font_size", 14)
	left_column.add_child(imp_left_lbl)
	
	var imp_right_lbl = Label.new()
	imp_right_lbl.text = "Workforce & Security Improvements"
	imp_right_lbl.add_theme_font_size_override("font_size", 14)
	right_column.add_child(imp_right_lbl)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_column.add_child(left_vbox)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_column.add_child(right_vbox)
	
	var list_left = ["storage_vault", "deep_shelving", "extra_workbench", "strongbox_vault"]
	var list_right = ["bunkhouse", "iron_reinforcements", "ornate_facade"]
	if _building and _building.has_method("produces_using_only_raw_materials") and _building.produces_using_only_raw_materials():
		list_right.append("auto_gathering")
	
	# Helper lambda to render each improvement
	var draw_imp_card = func(id: String, container: VBoxContainer):
		var def = _building.IMPROVEMENT_DEFINITIONS[id]
		var cur_lvl = _building.improvements.get(id, 0)
		
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.14, 0.13, 0.18, 0.8)
		style.set_border_width_all(1)
		style.border_color = Color(0.58, 0.34, 0.75, 0.25)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		container.add_child(panel)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)
		
		var title_hbox = HBoxContainer.new()
		vbox.add_child(title_hbox)
		
		var name_lbl = Label.new()
		name_lbl.text = def.name
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_hbox.add_child(name_lbl)
		
		var pips_str = ""
		for l in range(def.max_level):
			if l < cur_lvl:
				pips_str += "● "
			else:
				pips_str += "○ "
		var pips_lbl = Label.new()
		pips_lbl.text = pips_str.strip_edges()
		pips_lbl.add_theme_font_size_override("font_size", 12)
		pips_lbl.modulate = Color(0.58, 0.34, 0.75)
		title_hbox.add_child(pips_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = def.description
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.modulate = Color(0.75, 0.75, 0.8)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc_lbl)
		
		var buy_btn = Button.new()
		buy_btn.focus_mode = Control.FOCUS_ALL
		buy_btn.add_theme_font_size_override("font_size", 10)
		_setup_button_hover(buy_btn)
		vbox.add_child(buy_btn)
		
		if cur_lvl >= def.max_level:
			buy_btn.disabled = true
			buy_btn.text = "Max Level Reached"
		else:
			buy_btn.text = "Purchase Upgrade (%d G)" % def.cost
			if GameState.gold < def.cost:
				buy_btn.disabled = true
			else:
				buy_btn.pressed.connect(func():
					_building.purchase_improvement(id)
					refresh()
				)
				
	for id in list_left:
		draw_imp_card.call(id, left_vbox)
		
	for id in list_right:
		draw_imp_card.call(id, right_vbox)


func _open_employee_equipment_popup(emp_idx: int) -> void:
	if not _building.get("hired_employees") or emp_idx >= _building.hired_employees.size():
		return
		
	var emp = _building.hired_employees[emp_idx]
	var npc = emp.get("npc_ref")
	if not is_instance_valid(npc) or not npc.has_node("EquipmentComponent"):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("Employee is busy or not ready!", _building.global_position)
		return
		
	_close_slider_popup()
	
	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(580, 360)
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.offset_left = -290
	popup_panel.offset_right = 290
	popup_panel.offset_top = -180
	popup_panel.offset_bottom = 180
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.24, 0.52, 0.85, 0.8)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	popup_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Equipment - %s" % emp.get("name", "Employee")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.24, 0.52, 0.85, 1.0))
	vbox.add_child(title)
	
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_hbox)
	
	var inv_vbox = VBoxContainer.new()
	inv_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(inv_vbox)
	
	var inv_title = Label.new()
	inv_title.text = "Your Inventory (Equipable)"
	inv_title.add_theme_font_size_override("font_size", 11)
	inv_title.modulate = Color(0.7, 0.7, 0.7)
	inv_vbox.add_child(inv_title)
	
	var inv_scroll = ScrollContainer.new()
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_vbox.add_child(inv_scroll)
	
	var inv_list = VBoxContainer.new()
	inv_list.add_theme_constant_override("separation", 6)
	inv_scroll.add_child(inv_list)
	
	var p_inv = GameState.player_inventory
	
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(260, 0)
	right_vbox.add_theme_constant_override("separation", 8)
	content_hbox.add_child(right_vbox)
	
	var stats_lbl = Label.new()
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.modulate = Color(0.9, 0.9, 0.9)
	right_vbox.add_child(stats_lbl)
	
	var slots_grid = GridContainer.new()
	slots_grid.columns = 2
	slots_grid.add_theme_constant_override("h_separation", 8)
	slots_grid.add_theme_constant_override("v_separation", 8)
	slots_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(slots_grid)
	
	var update_popup_ui = [null]
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 26)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		_close_slider_popup()
		refresh()
	)
	_setup_button_hover(close_btn)
	vbox.add_child(close_btn)
	
	update_popup_ui[0] = func():
		var eq = npc.get_node("EquipmentComponent")
		stats_lbl.text = "Armor: %d | Attack: %d\nSpeed: +%d%% | Capacity: %+d slots" % [
			eq.get_total_armor(),
			eq.get_total_attack(),
			int(eq.get_total_speed_bonus() * 100),
			eq.get_total_capacity_bonus()
		]
		
		for child in inv_list.get_children():
			child.queue_free()
			
		var has_any = false
		for slot in p_inv.slots:
			var item: ItemData = slot["item"]
			if item and item.equipment_slot != "None":
				has_any = true
				var item_btn = Button.new()
				item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				
				var desc = "%s (%s)" % [item.name, item.equipment_slot]
				if item.armor_stat > 0: desc += " [Arm: +%d]" % item.armor_stat
				if item.attack_stat > 0: desc += " [Att: +%d]" % item.attack_stat
				if item.speed_bonus > 0: desc += " [Spd: +%d%%]" % int(item.speed_bonus * 100)
				if item.capacity_bonus > 0: desc += " [Cap: +%d]" % item.capacity_bonus
				if item.is_tool: desc += " [Dur: %d/100]" % item.durability
				
				item_btn.text = desc
				item_btn.add_theme_font_size_override("font_size", 9)
				_setup_button_hover(item_btn)
				
				item_btn.pressed.connect(func():
					var slot_name = ""
					match item.equipment_slot:
						"Head": slot_name = "head"
						"Body": slot_name = "body"
						"Gloves": slot_name = "gloves"
						"Weapon": slot_name = "weapon"
						"Tool": slot_name = "tool"
						"Bag": slot_name = "bag"
						"Necklace": slot_name = "necklace"
						"Ring": slot_name = "ring"
						"Transportation": slot_name = "transportation"
						
					if slot_name != "":
						var current_equipped = eq.get_equipped_item(slot_name)
						var current_bonus = current_equipped.capacity_bonus if current_equipped else 0
						var new_bonus = item.capacity_bonus
						var net_diff = new_bonus - current_bonus
						if net_diff < 0:
							var new_capacity = npc.cargo_inventory.max_slots + net_diff
							if npc.cargo_inventory.slots.size() > new_capacity:
								var hud = get_tree().get_first_node_in_group("PlayerHUD")
								if hud:
									hud._spawn_floating_text("Worker cargo full! Cannot swap.", npc.global_position)
								return
								
						var item_to_equip = item.duplicate()
						p_inv.remove_item(item.id, 1)
						var swapped_item = eq.equip_item(slot_name, item_to_equip)
						if swapped_item:
							p_inv.add_item(swapped_item, 1)
							
						npc.recalculate_equipment_stats()
						update_popup_ui[0].call()
				)
				inv_list.add_child(item_btn)
				
		if not has_any:
			var empty_lbl = Label.new()
			empty_lbl.text = "No equipable items in inventory."
			empty_lbl.add_theme_font_size_override("font_size", 9)
			empty_lbl.modulate = Color(0.5, 0.5, 0.5)
			inv_list.add_child(empty_lbl)
			
		for child in slots_grid.get_children():
			child.queue_free()
			
		var slot_buttons = {
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
			var slot_lbl = slot_buttons[slot_name]
			var slot_btn = Button.new()
			slot_btn.custom_minimum_size = Vector2(120, 36)
			slot_btn.add_theme_font_size_override("font_size", 9)
			_setup_button_hover(slot_btn)
			
			var eq_item = eq.get_equipped_item(slot_name)
			if eq_item:
				var label_text = eq_item.name
				if eq_item.is_tool:
					label_text += " (%d/%d)" % [eq_item.durability, eq_item.max_durability]
				slot_btn.text = label_text
				slot_btn.icon = eq_item.icon
				slot_btn.tooltip_text = "%s (%s)\nClick to unequip" % [eq_item.name, slot_lbl]
				
				slot_btn.pressed.connect(func():
					if eq_item.capacity_bonus > 0:
						var new_capacity = npc.cargo_inventory.max_slots - eq_item.capacity_bonus
						if npc.cargo_inventory.slots.size() > new_capacity:
							var hud = get_tree().get_first_node_in_group("PlayerHUD")
							if hud:
								hud._spawn_floating_text("Worker cargo full! Cannot unequip.", npc.global_position)
							return
							
					eq.unequip_item(slot_name)
					p_inv.add_item(eq_item, 1)
					npc.recalculate_equipment_stats()
					update_popup_ui[0].call()
				)
			else:
				slot_btn.text = "%s: Empty" % slot_lbl
				slot_btn.icon = null
				slot_btn.tooltip_text = "Empty %s slot" % slot_lbl
				
			slots_grid.add_child(slot_btn)
			
	update_popup_ui[0].call()
	
	_slider_overlay.add_child(popup_panel)
	_slider_overlay.show()
	close_btn.grab_focus()

func _render_warehouse_main_data() -> void:
	# Left Column: Warehouse Logistics (Minimum Retained Stock)
	var title_lbl = Label.new()
	title_lbl.text = "Logistics: Min Retained Stock"
	title_lbl.add_theme_font_size_override("font_size", 14)
	left_column.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "Couriers will not pull items out if stock is at or below this value."
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.modulate = Color(0.7, 0.75, 0.85, 0.8)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	left_column.add_child(desc_lbl)
	
	var threshold_scroll = ScrollContainer.new()
	threshold_scroll.custom_minimum_size = Vector2(0, 320)
	threshold_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	threshold_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(threshold_scroll)
	
	var threshold_vbox = VBoxContainer.new()
	threshold_vbox.add_theme_constant_override("separation", 8)
	threshold_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	threshold_scroll.add_child(threshold_vbox)
	
	# Populate with items from EconomyManager database
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	if econ_mgr:
		var items = []
		for id in econ_mgr.item_database:
			var item = econ_mgr.item_database[id]
			if item.is_tradable:
				items.append(item)
		items.sort_custom(func(a, b): return a.name < b.name)
		
		for item in items:
			var row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			if item.icon:
				var rect = TextureRect.new()
				rect.texture = item.icon
				rect.custom_minimum_size = Vector2(24, 24)
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row.add_child(rect)
				
			var name_lbl = Label.new()
			name_lbl.text = item.name
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.add_theme_font_size_override("font_size", 12)
			row.add_child(name_lbl)
			
			var val_edit = LineEdit.new()
			val_edit.text = str(_building.min_retained_stock.get(item.id, 0))
			val_edit.custom_minimum_size = Vector2(60, 24)
			val_edit.add_theme_font_size_override("font_size", 12)
			val_edit.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(val_edit)
			
			var sanitize_func = func(text: String):
				var val = 0
				if text.is_valid_int():
					val = max(0, text.to_int())
				val_edit.text = str(val)
				_building.min_retained_stock[item.id] = val
				
			val_edit.text_submitted.connect(sanitize_func)
			val_edit.focus_exited.connect(func():
				sanitize_func.call(val_edit.text)
			)
			val_edit.text_changed.connect(func(new_text: String):
				var cleaned = ""
				for i in range(new_text.length()):
					var c = new_text[i]
					if c >= '0' and c <= '9':
						cleaned += c
				var val = 0
				if cleaned.is_valid_int():
					val = max(0, cleaned.to_int())
				_building.min_retained_stock[item.id] = val
				if new_text != cleaned:
					var old_caret = val_edit.caret_column
					val_edit.text = cleaned
					val_edit.caret_column = min(old_caret, cleaned.length())
			)
			
			threshold_vbox.add_child(row)
			
	# Right Column: Warehouse Storage and Player Inventory
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_column.add_child(right_scroll)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_vbox)
	
	var target_b_inv = _building.inventory
	if target_b_inv:
		var w_storage_lbl = Label.new()
		w_storage_lbl.text = "Warehouse Storage (%d Slots)" % target_b_inv.max_slots
		w_storage_lbl.add_theme_font_size_override("font_size", 12)
		right_vbox.add_child(w_storage_lbl)
		
		var w_storage_grid = GridContainer.new()
		w_storage_grid.columns = 6
		w_storage_grid.add_theme_constant_override("h_separation", 6)
		w_storage_grid.add_theme_constant_override("v_separation", 6)
		right_vbox.add_child(w_storage_grid)
		
		for i in range(target_b_inv.max_slots):
			var slot_panel = _create_slot_panel("building", target_b_inv, i)
			w_storage_grid.add_child(slot_panel)
			
	var p_inv_lbl = Label.new()
	p_inv_lbl.text = "Player Inventory (%d Slots)" % GameState.player_inventory.max_slots if GameState.player_inventory else 24
	p_inv_lbl.add_theme_font_size_override("font_size", 12)
	right_vbox.add_child(p_inv_lbl)
	
	var p_inv_grid = GridContainer.new()
	p_inv_grid.columns = 6
	p_inv_grid.add_theme_constant_override("h_separation", 6)
	p_inv_grid.add_theme_constant_override("v_separation", 6)
	right_vbox.add_child(p_inv_grid)
	
	if GameState.player_inventory:
		for i in range(GameState.player_inventory.max_slots):
			var slot_panel = _create_slot_panel("player", GameState.player_inventory, i)
			p_inv_grid.add_child(slot_panel)

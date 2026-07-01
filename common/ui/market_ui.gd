extends PanelContainer

@onready var market_name_label: Label = %MarketNameLabel
@onready var market_list: VBoxContainer = %MarketList
@onready var player_gold_label: Label = %PlayerGoldLabel
@onready var player_list: VBoxContainer = %PlayerList
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var bottom_close_button: Button = %BottomCloseButton
@onready var description_label: Label = %DescriptionLabel

var _current_stall: CollisionObject2D = null

# Standard wheat/flour/bread resources to trade
var _items: Array[ItemData] = []
var _grid_container: GridContainer = null
var _slider_overlay: ColorRect = null
var _last_traded_item_id: String = ""
var _last_traded_mode: String = ""
var _last_focused_trigger_button: Button = null
var _last_valid_popup_focus: Control = null
var _is_initial_open: bool = false

const CATEGORIES = ["Raw Materials", "Semi-Elaborate", "Finished Goods", "Consumables", "Equipment", "Skill Items"]
var _active_category_idx: int = 0
var _category_tab_container: HBoxContainer = null

func _load_items_recursively(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_load_items_recursively(dir_path + file_name + "/")
			else:
				var clean_name = file_name
				if clean_name.ends_with(".remap"):
					clean_name = clean_name.replace(".remap", "")
				if clean_name.ends_with(".tres"):
					var item = load(dir_path + clean_name)
					if item and item is ItemData:
						_items.append(item)
			file_name = dir.get_next()
		dir.list_dir_end()

func _ready() -> void:
	# Load all item resources dynamically from subfolders recursively
	_load_items_recursively("res://common/items/instances/")
	
	var market_scroll = get_node_or_null("MarginContainer/VBoxContainer/Columns/MarketColumn/ScrollContainer") as ScrollContainer
	if market_scroll:
		UIFocusHelper.register_scroll_container(market_scroll)
	var player_scroll = get_node_or_null("MarginContainer/VBoxContainer/Columns/PlayerColumn/ScrollContainer") as ScrollContainer
	if player_scroll:
		UIFocusHelper.register_scroll_container(player_scroll)
	
	if close_button:
		close_button.pressed.connect(close)
		_setup_button_hover(close_button)
		close_button.focus_mode = Control.FOCUS_NONE
		
	if bottom_close_button:
		bottom_close_button.pressed.connect(close)
		_setup_button_hover(bottom_close_button)
		bottom_close_button.focus_mode = Control.FOCUS_ALL

	get_viewport().gui_focus_changed.connect(_on_viewport_focus_changed)

	# Dynamic UI Restructuring:
	# Hide PlayerColumn and make MarketColumn occupy full width
	var player_col = $MarginContainer/VBoxContainer/Columns/PlayerColumn
	if player_col:
		player_col.hide()
	
	var market_col = $MarginContainer/VBoxContainer/Columns/MarketColumn
	if market_col:
		market_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var market_col_label = market_col.get_child(0)
		if market_col_label is Label:
			market_col_label.text = "Market Stall Goods"
			
		# Create the Category Tabs HBox Container
		_category_tab_container = HBoxContainer.new()
		_category_tab_container.name = "CategoryTabs"
		_category_tab_container.add_theme_constant_override("separation", 6)
		_category_tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
		# Insert it as the second child, after the label and before the ScrollContainer
		market_col.add_child(_category_tab_container)
		market_col.move_child(_category_tab_container, 1)
			
	# Instantiating the new 5-column GridContainer inside the ScrollContainer
	if market_list:
		_grid_container = GridContainer.new()
		_grid_container.columns = 5
		_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid_container.add_theme_constant_override("h_separation", 8)
		_grid_container.add_theme_constant_override("v_separation", 8)
		market_list.add_child(_grid_container)

	# Create slider overlay backdrop
	_slider_overlay = ColorRect.new()
	_slider_overlay.color = Color(0.08, 0.08, 0.12, 0.65) # Dimming
	_slider_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_slider_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider_overlay.hide()
	add_child(_slider_overlay)

	# Style description panel
	var desc_panel = get_node_or_null("MarginContainer/VBoxContainer/DescriptionPanel")
	if desc_panel:
		var desc_style = StyleBoxFlat.new()
		desc_style.bg_color = Color(0.08, 0.08, 0.1, 0.6)
		desc_style.border_color = Color(0.22, 0.22, 0.32, 0.5)
		desc_style.set_border_width_all(1)
		desc_style.set_corner_radius_all(6)
		desc_style.content_margin_left = 12
		desc_style.content_margin_right = 12
		desc_style.content_margin_top = 8
		desc_style.content_margin_bottom = 8
		desc_panel.add_theme_stylebox_override("panel", desc_style)

func open(stall: CollisionObject2D) -> void:
	_is_initial_open = true
	_current_stall = stall
	if is_instance_valid(description_label):
		description_label.text = "Select an item to see its description."
	if market_name_label:
		if stall.ownership_type == "Player" or (stall.ownership_type == "Rented" and stall.owner_id == "Player"):
			market_name_label.text = stall.market_name + " (Storefront)"
		else:
			market_name_label.text = stall.market_name
	
	# Connect to stall's inventory change signals to update in real-time
	if stall.inventory:
		if not stall.inventory.inventory_changed.is_connected(refresh):
			stall.inventory.inventory_changed.connect(refresh)
			
	if GameState.player_inventory:
		if not GameState.player_inventory.inventory_changed.is_connected(refresh):
			GameState.player_inventory.inventory_changed.connect(refresh)
			
	refresh()
	show()
	
	# Slide/fade in animation
	pivot_offset = size / 2.0
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	
	_focus_first_market_button()
	_is_initial_open = false

func close() -> void:
	# Disconnect signals
	if _current_stall and _current_stall.inventory:
		if _current_stall.inventory.inventory_changed.is_connected(refresh):
			_current_stall.inventory.inventory_changed.disconnect(refresh)
	if GameState.player_inventory:
		if GameState.player_inventory.inventory_changed.is_connected(refresh):
			GameState.player_inventory.inventory_changed.disconnect(refresh)
			
	hide()
	# Notify HUD that we closed
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud:
		hud.close_market()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		if _slider_overlay and _slider_overlay.visible:
			_close_slider_popup()
		else:
			close()
		get_viewport().set_input_as_handled()
		return

	var is_popup_visible = (_slider_overlay and _slider_overlay.visible)

	# Handle slider navigation using A/D keys
	if is_popup_visible and event.is_pressed():
		var slider = _find_slider_in_node(_slider_overlay)
		if slider and is_instance_valid(slider):
			var focused = get_viewport().gui_get_focus_owner()
			if focused == slider:
				if event.is_action_pressed("move_left", true) or (event is InputEventKey and event.keycode == KEY_A):
					slider.value = max(slider.min_value, slider.value - 1)
					get_viewport().set_input_as_handled()
					return
				elif event.is_action_pressed("move_right", true) or (event is InputEventKey and event.keycode == KEY_D):
					slider.value = min(slider.max_value, slider.value + 1)
					get_viewport().set_input_as_handled()
					return
			
			if event is InputEventKey and event.keycode == KEY_R and not event.is_echo():
				var confirm_btn = _find_confirm_button_in_node(_slider_overlay)
				if confirm_btn and is_instance_valid(confirm_btn):
					slider.value = slider.max_value
					confirm_btn.pressed.emit()
					get_viewport().set_input_as_handled()
					return

	# Handle F / interact / ui_accept confirming focused buttons
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and focused is Button and is_instance_valid(focused) and is_ancestor_of(focused):
				focused.pressed.emit()
				get_viewport().set_input_as_handled()
				return
			
			# Fallback when slider/popup is active but HSlider is focused
			if is_popup_visible:
				var confirm_btn = _find_confirm_button_in_node(_slider_overlay)
				if confirm_btn and is_instance_valid(confirm_btn):
					confirm_btn.pressed.emit()
					get_viewport().set_input_as_handled()
					return

	# Handle category tabs scrolling via Q/E
	if not is_popup_visible and event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("ui_page_up") or (event is InputEventKey and event.keycode == KEY_Q):
			_active_category_idx = (_active_category_idx - 1 + CATEGORIES.size()) % CATEGORIES.size()
			refresh()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_page_down") or (event is InputEventKey and event.keycode == KEY_E):
			_active_category_idx = (_active_category_idx + 1) % CATEGORIES.size()
			refresh()
			get_viewport().set_input_as_handled()
			return

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

func _update_category_tabs() -> void:
	if not _category_tab_container:
		return
		
	# Clear
	for child in _category_tab_container.get_children():
		_category_tab_container.remove_child(child)
		child.queue_free()
		
	for i in range(CATEGORIES.size()):
		var cat_name = CATEGORIES[i]
		var tab_btn = Button.new()
		tab_btn.text = cat_name
		tab_btn.flat = true
		tab_btn.focus_mode = Control.FOCUS_NONE # Key nav goes directly to items
		tab_btn.add_theme_font_size_override("font_size", 11)
		
		var normal_style = StyleBoxFlat.new()
		normal_style.content_margin_left = 10
		normal_style.content_margin_right = 10
		normal_style.content_margin_top = 4
		normal_style.content_margin_bottom = 4
		normal_style.set_corner_radius_all(4)
		
		if i == _active_category_idx:
			normal_style.bg_color = Color(0.25, 0.25, 0.38, 0.9)
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
		)
		
		_category_tab_container.add_child(tab_btn)

func refresh() -> void:
	if not _current_stall:
		return
		
	if player_gold_label:
		player_gold_label.text = "Your Gold: %d Gold" % GameState.gold
		
	var display_items = []
	var parent_b = _current_stall
	if "parent_building" in _current_stall and _current_stall.parent_building != null:
		parent_b = _current_stall.parent_building
		
	if parent_b:
		var bench = parent_b.get_node_or_null("CraftingBench")
		if not bench and is_instance_valid(parent_b.get("instanced_interior")):
			bench = parent_b.instanced_interior.get_node_or_null("CraftingBench")
		if bench and "recipes" in bench:
			for recipe in bench.recipes:
				if recipe and recipe.get("output_item") and not display_items.has(recipe.output_item):
					display_items.append(recipe.output_item)
					
	if display_items.is_empty():
		display_items = _items
		
	# Filter display_items by active category and ensure they are tradable
	var active_cat = CATEGORIES[_active_category_idx]
	var filtered_items = []
	for item in display_items:
		if item.market_category == active_cat and item.is_tradable:
			filtered_items.append(item)
			
	# Update tabs
	_update_category_tabs()
	
	_refresh_trade_grid(filtered_items)

func _refresh_trade_grid(display_items: Array) -> void:
	if not _grid_container:
		return
		
	var previously_focused_id = ""
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner and is_instance_valid(focus_owner) and focus_owner.name.begins_with("Card_"):
		previously_focused_id = focus_owner.name.replace("Card_", "")
		
	# Clear
	for child in _grid_container.get_children():
		_grid_container.remove_child(child)
		child.queue_free()
		
	# Rebuild
	for item in display_items:
		if not item:
			continue
			
		var stall_stock = _current_stall.inventory.get_item_amount(item.id)
		var player_stock = GameState.player_inventory.get_item_amount(item.id)
		
		# Build a single focusable Button card
		var card = Button.new()
		card.name = "Card_" + item.id
		card.custom_minimum_size = Vector2(136, 42)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Theme override styles for card
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.14, 0.14, 0.18, 0.85)
		normal_style.set_border_width_all(2)
		normal_style.border_color = Color(0.22, 0.22, 0.32, 0.7)
		normal_style.set_corner_radius_all(6)
		normal_style.content_margin_left = 4
		normal_style.content_margin_right = 4
		normal_style.content_margin_top = 2
		normal_style.content_margin_bottom = 2
		
		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.18, 0.18, 0.24, 0.9)
		hover_style.border_color = Color(0.4, 0.4, 0.65, 0.9)
		
		var pressed_style = normal_style.duplicate()
		pressed_style.bg_color = Color(0.1, 0.1, 0.13, 0.95)
		pressed_style.border_color = Color(0.3, 0.3, 0.5, 0.8)
		
		var disabled_style = normal_style.duplicate()
		disabled_style.bg_color = Color(0.08, 0.08, 0.1, 0.3)
		disabled_style.border_color = Color(0.15, 0.15, 0.2, 0.2)
		
		card.add_theme_stylebox_override("normal", normal_style)
		card.add_theme_stylebox_override("hover", hover_style)
		card.add_theme_stylebox_override("pressed", pressed_style)
		card.add_theme_stylebox_override("focus", hover_style)
		card.add_theme_stylebox_override("disabled", disabled_style)
		
		# Inner vbox with proper anchors to fill button and padding
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.anchor_left = 0.0
		vbox.anchor_right = 1.0
		vbox.anchor_top = 0.0
		vbox.anchor_bottom = 1.0
		vbox.offset_left = 6
		vbox.offset_right = -6
		vbox.offset_top = 2
		vbox.offset_bottom = -2
		card.add_child(vbox)
		
		# Name
		var name_lbl = Label.new()
		name_lbl.text = item.name
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(name_lbl)
		
		# Stock
		var stock_lbl = Label.new()
		stock_lbl.text = "Stall: %d  |  Own: %d" % [stall_stock, player_stock]
		stock_lbl.add_theme_font_size_override("font_size", 8)
		stock_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
		stock_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(stock_lbl)
		
		# Price info
		var price_lbl = Label.new()
		price_lbl.add_theme_font_size_override("font_size", 8)
		price_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
		price_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var is_owner = (_current_stall.ownership_type == "Player" or (_current_stall.ownership_type == "Rented" and _current_stall.owner_id == "Player"))
		if is_owner:
			price_lbl.text = "Price: %d G" % _current_stall.get_custom_price(item)
		else:
			price_lbl.text = "Buy: %d G | Sell: %d G" % [_current_stall.get_buy_price(item), _current_stall.get_sell_price(item)]
		vbox.add_child(price_lbl)
		
		# Enable clicking
		card.disabled = not item.is_tradable
		card.pressed.connect(func():
			_open_transaction_prompt(item, card)
		)
		card.focus_entered.connect(func():
			_update_description(item)
		)
		card.mouse_entered.connect(func():
			_update_description(item)
		)
		
		_setup_button_hover(card)
		_grid_container.add_child(card)
		
	_link_market_grid_focus()
	
	if previously_focused_id != "":
		var target_card = _find_card_by_item_id(previously_focused_id)
		if target_card and target_card is Button and not target_card.disabled and target_card.visible:
			target_card.grab_focus()
			return
		else:
			_focus_first_market_button()
			return
			
	if _last_traded_item_id != "":
		var target_card = _find_card_by_item_id(_last_traded_item_id)
		if target_card and target_card is Button and not target_card.disabled and target_card.visible:
			target_card.grab_focus()
			_last_traded_item_id = ""
			return
		_last_traded_item_id = ""
		
	if _is_initial_open:
		_focus_first_market_button()

func _get_player_inventory_space(item: ItemData) -> int:
	if not GameState.player_inventory:
		return 0
	return GameState.player_inventory.get_free_space_for_item(item)

func _get_stall_inventory_space(item: ItemData) -> int:
	if not _current_stall or not _current_stall.inventory:
		return 0
	return _current_stall.inventory.get_free_space_for_item(item)

func _calculate_max_affordable(item: ItemData) -> int:
	if not _current_stall or not _current_stall.inventory:
		return 0
	var price = _current_stall.get_buy_price(item)
	if price <= 0:
		return _current_stall.inventory.get_item_amount(item.id)
	return int(GameState.gold / price)

func _open_transaction_prompt(item: ItemData, card_node: Control) -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused is Button:
		_last_focused_trigger_button = focused
	else:
		_last_focused_trigger_button = null
		
	# Clear overlay
	for child in _slider_overlay.get_children():
		child.queue_free()
		
	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(300, 150)
	
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.offset_left = -150
	popup_panel.offset_right = 150
	popup_panel.offset_top = -75
	popup_panel.offset_bottom = 75
	
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	popup_style.set_border_width_all(2)
	popup_style.border_color = Color(0.35, 0.35, 0.5, 0.9)
	popup_style.set_corner_radius_all(10)
	popup_style.content_margin_left = 16
	popup_style.content_margin_right = 16
	popup_style.content_margin_top = 16
	popup_style.content_margin_bottom = 16
	popup_panel.add_theme_stylebox_override("panel", popup_style)
	
	_slider_overlay.add_child(popup_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup_panel.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = item.name
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(title_lbl)
	
	var prompt_lbl = Label.new()
	prompt_lbl.text = "Choose action:"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 12)
	prompt_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(prompt_lbl)
	
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 12)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons_hbox)
	
	var is_owner = (_current_stall.ownership_type == "Player" or (_current_stall.ownership_type == "Rented" and _current_stall.owner_id == "Player"))
	var stall_stock = _current_stall.inventory.get_item_amount(item.id)
	var player_stock = GameState.player_inventory.get_item_amount(item.id)
	var player_space = _get_player_inventory_space(item)
	var stall_space = _get_stall_inventory_space(item)
	
	var first_focus_btn = null
	
	if is_owner:
		var withdraw_btn = Button.new()
		withdraw_btn.text = "Withdraw"
		withdraw_btn.custom_minimum_size = Vector2(85, 30)
		withdraw_btn.disabled = (stall_stock <= 0 or player_space <= 0)
		withdraw_btn.pressed.connect(func():
			var limit = min(stall_stock, player_space)
			_open_quantity_slider(item, "withdraw", limit, card_node)
		)
		_setup_button_hover(withdraw_btn)
		buttons_hbox.add_child(withdraw_btn)
		if not withdraw_btn.disabled:
			first_focus_btn = withdraw_btn
			
		var deposit_btn = Button.new()
		deposit_btn.text = "Deposit"
		deposit_btn.custom_minimum_size = Vector2(85, 30)
		deposit_btn.disabled = (player_stock <= 0 or stall_space <= 0)
		deposit_btn.pressed.connect(func():
			var limit = min(player_stock, stall_space)
			_open_quantity_slider(item, "deposit", limit, card_node)
		)
		_setup_button_hover(deposit_btn)
		buttons_hbox.add_child(deposit_btn)
		if not deposit_btn.disabled and not first_focus_btn:
			first_focus_btn = deposit_btn
			
		var price_btn = Button.new()
		price_btn.text = "Set Price"
		price_btn.custom_minimum_size = Vector2(85, 30)
		price_btn.pressed.connect(func():
			_open_price_adjuster_prompt(item, card_node)
		)
		_setup_button_hover(price_btn)
		buttons_hbox.add_child(price_btn)
		if not first_focus_btn:
			first_focus_btn = price_btn
			
	else:
		var buy_btn = Button.new()
		buy_btn.text = "Buy..."
		buy_btn.custom_minimum_size = Vector2(85, 30)
		var max_afford = _calculate_max_affordable(item)
		buy_btn.disabled = (stall_stock <= 0 or max_afford <= 0)
		buy_btn.pressed.connect(func():
			if player_space <= 0:
				AlertManager.add_alert("Inventory Full", "Your inventory is full! Purchase bags to expand capacity.", "warning", null, true)
				return
			var limit = min(stall_stock, min(max_afford, player_space))
			_open_quantity_slider(item, "buy", limit, card_node)
		)
		_setup_button_hover(buy_btn)
		buttons_hbox.add_child(buy_btn)
		if not buy_btn.disabled:
			first_focus_btn = buy_btn
			
		var sell_btn = Button.new()
		sell_btn.text = "Sell..."
		sell_btn.custom_minimum_size = Vector2(85, 30)
		sell_btn.disabled = (player_stock <= 0 or stall_space <= 0)
		sell_btn.pressed.connect(func():
			var limit = min(player_stock, stall_space)
			_open_quantity_slider(item, "sell", limit, card_node)
		)
		_setup_button_hover(sell_btn)
		buttons_hbox.add_child(sell_btn)
		if not sell_btn.disabled and not first_focus_btn:
			first_focus_btn = sell_btn
			
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(85, 30)
	cancel_btn.pressed.connect(_close_slider_popup)
	_setup_button_hover(cancel_btn)
	buttons_hbox.add_child(cancel_btn)
	if not first_focus_btn:
		first_focus_btn = cancel_btn
		
	# Wire focus neighbors within the dialog
	var active_btns = []
	for child in buttons_hbox.get_children():
		if child is Button and not child.disabled and child.visible:
			active_btns.append(child)
			
	for i in range(active_btns.size() - 1):
		active_btns[i].focus_neighbor_right = active_btns[i+1].get_path()
		active_btns[i+1].focus_neighbor_left = active_btns[i].get_path()
		
	if not active_btns.is_empty():
		active_btns[0].focus_neighbor_left = active_btns[0].get_path()
		active_btns[-1].focus_neighbor_right = active_btns[-1].get_path()
		for btn in active_btns:
			btn.focus_neighbor_top = btn.get_path()
			btn.focus_neighbor_bottom = btn.get_path()
		
	_slider_overlay.show()
	first_focus_btn.grab_focus()

func _open_price_adjuster_prompt(item: ItemData, card_node: Control) -> void:
	for child in _slider_overlay.get_children():
		child.queue_free()
		
	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(300, 160)
	
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.offset_left = -150
	popup_panel.offset_right = 150
	popup_panel.offset_top = -80
	popup_panel.offset_bottom = 80
	
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	popup_style.set_border_width_all(2)
	popup_style.border_color = Color(0.35, 0.35, 0.5, 0.9)
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
	title_lbl.text = "Set Price for %s" % item.name
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_lbl)
	
	var adjust_hbox = HBoxContainer.new()
	adjust_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	adjust_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(adjust_hbox)
	
	var dec_btn = Button.new()
	dec_btn.text = "-"
	dec_btn.custom_minimum_size = Vector2(30, 30)
	_setup_button_hover(dec_btn)
	adjust_hbox.add_child(dec_btn)
	
	var price_lbl = Label.new()
	var current_price = _current_stall.get_custom_price(item)
	price_lbl.text = "%d Gold" % current_price
	price_lbl.add_theme_font_size_override("font_size", 16)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.custom_minimum_size = Vector2(80, 0)
	adjust_hbox.add_child(price_lbl)
	
	var inc_btn = Button.new()
	inc_btn.text = "+"
	inc_btn.custom_minimum_size = Vector2(30, 30)
	_setup_button_hover(inc_btn)
	adjust_hbox.add_child(inc_btn)
	
	var price_state = { "val": current_price }
	dec_btn.pressed.connect(func():
		var min_p = item.min_price if "min_price" in item else 1
		price_state.val = max(min_p, price_state.val - 1)
		price_lbl.text = "%d Gold" % price_state.val
	)
	inc_btn.pressed.connect(func():
		var max_p = item.max_price if "max_price" in item else 999
		price_state.val = min(max_p, price_state.val + 1)
		price_lbl.text = "%d Gold" % price_state.val
	)
	
	var actions_hbox = HBoxContainer.new()
	actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(actions_hbox)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	cancel_btn.pressed.connect(_close_slider_popup)
	_setup_button_hover(cancel_btn)
	actions_hbox.add_child(cancel_btn)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(80, 28)
	confirm_btn.pressed.connect(func():
		_current_stall.custom_prices[item.id] = price_state.val
		_close_slider_popup()
		refresh()
	)
	_setup_button_hover(confirm_btn)
	actions_hbox.add_child(confirm_btn)
	
	dec_btn.focus_neighbor_left = dec_btn.get_path()
	dec_btn.focus_neighbor_top = dec_btn.get_path()
	dec_btn.focus_neighbor_right = inc_btn.get_path()
	dec_btn.focus_neighbor_bottom = cancel_btn.get_path()
	
	inc_btn.focus_neighbor_left = dec_btn.get_path()
	inc_btn.focus_neighbor_right = inc_btn.get_path()
	inc_btn.focus_neighbor_top = inc_btn.get_path()
	inc_btn.focus_neighbor_bottom = confirm_btn.get_path()
	
	cancel_btn.focus_neighbor_left = cancel_btn.get_path()
	cancel_btn.focus_neighbor_right = confirm_btn.get_path()
	cancel_btn.focus_neighbor_top = dec_btn.get_path()
	cancel_btn.focus_neighbor_bottom = cancel_btn.get_path()
	
	confirm_btn.focus_neighbor_left = cancel_btn.get_path()
	confirm_btn.focus_neighbor_right = confirm_btn.get_path()
	confirm_btn.focus_neighbor_top = inc_btn.get_path()
	confirm_btn.focus_neighbor_bottom = confirm_btn.get_path()
	
	_slider_overlay.show()
	confirm_btn.grab_focus()

func _open_quantity_slider(item: ItemData, mode: String, max_limit: int, card_node: Control) -> void:
	if max_limit <= 0:
		return
		
	# Remember focus trigger button
	var focused = get_viewport().gui_get_focus_owner()
	if focused is Button:
		_last_focused_trigger_button = focused
	else:
		_last_focused_trigger_button = null
		
	# Clear overlay just in case
	for child in _slider_overlay.get_children():
		child.queue_free()
		
	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(320, 200)
	
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.offset_left = -160
	popup_panel.offset_right = 160
	popup_panel.offset_top = -100
	popup_panel.offset_bottom = 100
	
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	popup_style.set_border_width_all(2)
	popup_style.border_color = Color(0.35, 0.35, 0.5, 0.9)
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
	title_lbl.text = "[%s] %s" % [mode.capitalize(), item.name]
	title_lbl.add_theme_font_size_override("font_size", 16)
	if mode == "buy" or mode == "deposit":
		title_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2)) # gold
	else:
		title_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4)) # green
	vbox.add_child(title_lbl)
	
	var prompt_lbl = Label.new()
	prompt_lbl.text = "Select quantity (Max: %d):" % max_limit
	prompt_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(prompt_lbl)
	
	var slider = HSlider.new()
	slider.min_value = 1
	slider.max_value = max_limit
	slider.step = 1
	slider.value = 1
	vbox.add_child(slider)
	
	var display_lbl = Label.new()
	display_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(display_lbl)
	
	var update_display = func(val: float):
		var amount = int(val)
		if mode == "buy":
			var cost = _calculate_total_buy_cost(item, amount)
			display_lbl.text = "Amount: %d\nTotal Cost: %d Gold" % [amount, cost]
		elif mode == "sell":
			var revenue = _calculate_total_sell_revenue(item, amount)
			display_lbl.text = "Amount: %d\nTotal Revenue: %d Gold" % [amount, revenue]
		else:
			display_lbl.text = "Amount: %d" % amount
			
	slider.value_changed.connect(update_display)
	update_display.call(slider.value)
	
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 16)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons_hbox)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(85, 30)
	cancel_btn.pressed.connect(_close_slider_popup)
	_setup_button_hover(cancel_btn)
	buttons_hbox.add_child(cancel_btn)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(85, 30)
	confirm_btn.pressed.connect(func(): _on_slider_confirmed(item, mode, int(slider.value), card_node))
	_setup_button_hover(confirm_btn)
	buttons_hbox.add_child(confirm_btn)
	
	var all_btn = Button.new()
	all_btn.name = "AllButton"
	all_btn.text = "All (R)"
	all_btn.custom_minimum_size = Vector2(85, 30)
	all_btn.focus_mode = Control.FOCUS_ALL
	_setup_button_hover(all_btn)
	buttons_hbox.add_child(all_btn)
	buttons_hbox.move_child(all_btn, 1) # Insert between Cancel and Confirm
	all_btn.pressed.connect(func():
		slider.value = slider.max_value
		_on_slider_confirmed(item, mode, int(slider.value), card_node)
	)
	
	# Wire focus neighbors within the dialog to trap focus
	slider.focus_neighbor_left = slider.get_path()
	slider.focus_neighbor_right = slider.get_path()
	slider.focus_neighbor_top = slider.get_path()
	slider.focus_neighbor_bottom = all_btn.get_path()
	
	cancel_btn.focus_neighbor_left = cancel_btn.get_path()
	cancel_btn.focus_neighbor_right = all_btn.get_path()
	cancel_btn.focus_neighbor_top = slider.get_path()
	cancel_btn.focus_neighbor_bottom = cancel_btn.get_path()
	
	all_btn.focus_neighbor_left = cancel_btn.get_path()
	all_btn.focus_neighbor_right = confirm_btn.get_path()
	all_btn.focus_neighbor_top = slider.get_path()
	all_btn.focus_neighbor_bottom = all_btn.get_path()
	
	confirm_btn.focus_neighbor_left = all_btn.get_path()
	confirm_btn.focus_neighbor_right = confirm_btn.get_path()
	confirm_btn.focus_neighbor_top = slider.get_path()
	confirm_btn.focus_neighbor_bottom = confirm_btn.get_path()
	
	_slider_overlay.show()
	slider.grab_focus()

func _on_slider_confirmed(item: ItemData, mode: String, amount: int, card_node: Control) -> void:
	_last_traded_item_id = item.id
	_last_traded_mode = mode
	_close_slider_popup()
	if not _current_stall:
		return
		
	var success = false
	if mode == "buy" or mode == "withdraw":
		success = _current_stall.buy_item(item, amount)
	elif mode == "sell" or mode == "deposit":
		success = _current_stall.sell_item(item, amount)
		
	if success:
		_animate_success(card_node)
	else:
		_animate_failure(card_node)
		
	refresh()

func _close_slider_popup() -> void:
	_last_valid_popup_focus = null
	if _slider_overlay:
		for child in _slider_overlay.get_children():
			child.queue_free()
		_slider_overlay.hide()
		
	if _last_focused_trigger_button and is_instance_valid(_last_focused_trigger_button) and _last_focused_trigger_button.is_inside_tree() and not _last_focused_trigger_button.disabled and _last_focused_trigger_button.visible:
		_last_focused_trigger_button.grab_focus()
	else:
		_focus_first_market_button()

func _calculate_total_buy_cost(item: ItemData, amount: int) -> int:
	if not _current_stall:
		return 0
	return _current_stall.get_buy_price(item) * amount

func _calculate_total_sell_revenue(item: ItemData, amount: int) -> int:
	if not _current_stall:
		return 0
	return _current_stall.get_sell_price(item) * amount

func _animate_success(node: Control) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(0.4, 1.0, 0.4), 0.1)
	tween.tween_property(node, "modulate", Color(1, 1, 1), 0.1)

func _animate_failure(node: Control) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(1.0, 0.4, 0.4), 0.05)
	tween.tween_property(node, "modulate", Color(1, 1, 1), 0.1)

func _setup_button_hover(button: Button) -> void:
	var update_pivot = func():
		button.pivot_offset = button.size / 2.0
	update_pivot.call()
	if not button.resized.is_connected(update_pivot):
		button.resized.connect(update_pivot)
		
	button.mouse_entered.connect(func():
		if not button.disabled:
			var tween = create_tween()
			tween.tween_property(button, "scale", Vector2(1.03, 1.03), 0.08)
	)
	button.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
	)
	button.focus_entered.connect(func():
		if not button.disabled:
			var tween = create_tween()
			tween.tween_property(button, "scale", Vector2(1.03, 1.03), 0.08)
	)
	button.focus_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
	)

func _focus_first_market_button() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if _grid_container and _grid_container.get_child_count() > 0:
		var first_card = _grid_container.get_child(0)
		if is_instance_valid(first_card) and first_card is Button and not first_card.disabled and first_card.visible:
			first_card.grab_focus()

func _update_description(item: ItemData) -> void:
	if is_instance_valid(description_label):
		if item:
			description_label.text = item.description
		else:
			description_label.text = "Select an item to see its description."

func _on_market_element_focused(element: Control, card: Control) -> void:
	var scroll = _grid_container.get_parent()
	if scroll is ScrollContainer:
		_ensure_card_visible(card, scroll)

func _ensure_card_visible(card: Control, main_scroll: ScrollContainer) -> void:
	if not main_scroll or not is_instance_valid(main_scroll):
		return
	await card.get_tree().process_frame
	if not is_instance_valid(card) or not is_instance_valid(main_scroll):
		return
		
	var card_rect = card.get_global_rect()
	var scroll_rect = main_scroll.get_global_rect()
	var padding = 12.0
	
	if card_rect.position.y < scroll_rect.position.y + padding:
		var diff = (scroll_rect.position.y + padding) - card_rect.position.y
		main_scroll.scroll_vertical -= int(diff)
	elif card_rect.end.y > scroll_rect.end.y - padding:
		var diff = card_rect.end.y - (scroll_rect.end.y - padding)
		main_scroll.scroll_vertical += int(diff)

func _find_card_by_item_id(item_id: String) -> Control:
	if _grid_container:
		return _grid_container.get_node_or_null("Card_" + item_id)
	return null

func _link_market_grid_focus() -> void:
	if not _grid_container:
		return
		
	var card_count = _grid_container.get_child_count()
	if card_count == 0:
		return
		
	# Build a 2D grid of card buttons: rows of max 3 columns
	var cols_count = _grid_container.columns
	var rows = []
	var current_row = []
	for i in range(card_count):
		var card = _grid_container.get_child(i)
		if card is Button and not card.disabled and card.visible:
			current_row.append(card)
		if current_row.size() == cols_count or i == card_count - 1:
			if not current_row.is_empty():
				rows.append(current_row)
				current_row = []
				
	if rows.is_empty():
		return
		
	# Wire neighbors
	for r in range(rows.size()):
		for c in range(rows[r].size()):
			var btn = rows[r][c]
			
			# Connect focus entered to scroll view helper
			if not btn.focus_entered.is_connected(_on_market_element_focused.bind(btn, btn)):
				btn.focus_entered.connect(_on_market_element_focused.bind(btn, btn))
				
			# Left:
			if c > 0:
				btn.focus_neighbor_left = rows[r][c - 1].get_path()
			else:
				btn.focus_neighbor_left = btn.get_path() # lock
				
			# Right:
			if c < rows[r].size() - 1:
				btn.focus_neighbor_right = rows[r][c + 1].get_path()
			else:
				btn.focus_neighbor_right = btn.get_path() # lock
				
			# Top:
			if r > 0:
				var target_c = min(c, rows[r - 1].size() - 1)
				btn.focus_neighbor_top = rows[r - 1][target_c].get_path()
			else:
				btn.focus_neighbor_top = btn.get_path()
					
			# Bottom:
			if r < rows.size() - 1:
				var target_c = min(c, rows[r + 1].size() - 1)
				btn.focus_neighbor_bottom = rows[r + 1][target_c].get_path()
			else:
				btn.focus_neighbor_bottom = btn.get_path()

func _on_viewport_focus_changed(control: Control) -> void:
	if _slider_overlay and _slider_overlay.visible:
		if control:
			if _slider_overlay.is_ancestor_of(control):
				_last_valid_popup_focus = control
			else:
				if _last_valid_popup_focus and is_instance_valid(_last_valid_popup_focus) and _last_valid_popup_focus.is_inside_tree() and _last_valid_popup_focus.visible:
					_last_valid_popup_focus.call_deferred("grab_focus")
				else:
					var fallback = _find_first_focusable_in_popup(_slider_overlay)
					if fallback:
						_last_valid_popup_focus = fallback
						fallback.call_deferred("grab_focus")

func _find_first_focusable_in_popup(node: Node) -> Control:
	if node is Control and node.visible and node.focus_mode != Control.FOCUS_NONE:
		if node is HSlider or node is Button:
			return node
	for child in node.get_children():
		var found = _find_first_focusable_in_popup(child)
		if found:
			return found
	return null

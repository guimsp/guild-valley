extends PanelContainer

@onready var market_name_label: Label = %MarketNameLabel
@onready var market_list: VBoxContainer = %MarketList
@onready var player_gold_label: Label = %PlayerGoldLabel
@onready var player_list: VBoxContainer = %PlayerList
@onready var close_button: Button = %CloseButton
@onready var bottom_close_button: Button = %BottomCloseButton

var _current_stall: MarketStall = null

# Standard wheat/flour/bread resources to trade
var _items: Array[ItemData] = []

func _ready() -> void:
	# Load standard item resources
	_items.append(load("res://common/items/instances/wheat.tres"))
	_items.append(load("res://common/items/instances/flour.tres"))
	_items.append(load("res://common/items/instances/bread.tres"))
	_items.append(load("res://common/items/instances/cotton.tres"))
	_items.append(load("res://common/items/instances/cloth.tres"))
	_items.append(load("res://common/items/instances/iron_ore.tres"))
	_items.append(load("res://common/items/instances/iron_ingot.tres"))
	
	if close_button:
		close_button.pressed.connect(close)
		_setup_button_hover(close_button)
		
	if bottom_close_button:
		bottom_close_button.pressed.connect(close)
		_setup_button_hover(bottom_close_button)

func open(stall: MarketStall) -> void:
	_current_stall = stall
	if market_name_label:
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
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	if not _current_stall:
		return
		
	if player_gold_label:
		player_gold_label.text = "Your Gold: %d Gold" % GameState.gold
		
	_refresh_market_list()
	_refresh_player_list()

func _refresh_market_list() -> void:
	if not market_list:
		return
		
	# Clear
	for child in market_list.get_children():
		child.queue_free()
		
	# Rebuild
	for item in _items:
		if not item:
			continue
			
		var stock = _current_stall.inventory.get_item_amount(item.id)
		var price = _current_stall.get_buy_price(item)
		
		var row = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.18, 0.24, 0.7)
		style.set_border_width_all(1)
		style.border_color = Color(0.3, 0.3, 0.38, 0.7)
		style.set_corner_radius_all(4)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hbox)
		
		# Name & Stock
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		
		var name_label = Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(name_label)
		
		var stock_label = Label.new()
		stock_label.text = "Stock: %d" % stock
		stock_label.add_theme_font_size_override("font_size", 11)
		stock_label.modulate = Color(0.7, 0.7, 0.7)
		info_vbox.add_child(stock_label)
		
		# Price Label
		var price_label = Label.new()
		price_label.text = "%d Gold" % price
		price_label.add_theme_font_size_override("font_size", 13)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(price_label)
		
		# Action Buttons Container
		var btn_hbox = HBoxContainer.new()
		hbox.add_child(btn_hbox)
		
		# Buy 1 button
		var buy1_btn = Button.new()
		buy1_btn.text = "Buy 1"
		buy1_btn.custom_minimum_size = Vector2(60, 32)
		buy1_btn.disabled = (stock < 1 or GameState.gold < price)
		buy1_btn.pressed.connect(func(): _on_buy_clicked(item, 1, row))
		_setup_button_hover(buy1_btn)
		btn_hbox.add_child(buy1_btn)
		
		# Buy 5 button
		var buy5_btn = Button.new()
		buy5_btn.text = "Buy 5"
		buy5_btn.custom_minimum_size = Vector2(60, 32)
		buy5_btn.disabled = (stock < 5 or GameState.gold < price * 5)
		buy5_btn.pressed.connect(func(): _on_buy_clicked(item, 5, row))
		_setup_button_hover(buy5_btn)
		btn_hbox.add_child(buy5_btn)
		
		market_list.add_child(row)

func _refresh_player_list() -> void:
	if not player_list:
		return
		
	# Clear
	for child in player_list.get_children():
		child.queue_free()
		
	# Rebuild
	for item in _items:
		if not item:
			continue
			
		var stock = GameState.player_inventory.get_item_amount(item.id)
		var price = _current_stall.get_sell_price(item)
		
		var row = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.18, 0.24, 0.7)
		style.set_border_width_all(1)
		style.border_color = Color(0.3, 0.3, 0.38, 0.7)
		style.set_corner_radius_all(4)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hbox)
		
		# Name & Count
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		
		var name_label = Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(name_label)
		
		var stock_label = Label.new()
		stock_label.text = "Owned: %d" % stock
		stock_label.add_theme_font_size_override("font_size", 11)
		stock_label.modulate = Color(0.7, 0.7, 0.7)
		info_vbox.add_child(stock_label)
		
		# Price Label
		var price_label = Label.new()
		price_label.text = "%d Gold" % price
		price_label.add_theme_font_size_override("font_size", 13)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(price_label)
		
		# Action Buttons Container
		var btn_hbox = HBoxContainer.new()
		hbox.add_child(btn_hbox)
		
		# Sell 1 button
		var sell1_btn = Button.new()
		sell1_btn.text = "Sell 1"
		sell1_btn.custom_minimum_size = Vector2(60, 32)
		sell1_btn.disabled = (stock < 1)
		sell1_btn.pressed.connect(func(): _on_sell_clicked(item, 1, row))
		_setup_button_hover(sell1_btn)
		btn_hbox.add_child(sell1_btn)
		
		# Sell All button
		var sellall_btn = Button.new()
		sellall_btn.text = "Sell All"
		sellall_btn.custom_minimum_size = Vector2(60, 32)
		sellall_btn.disabled = (stock < 1)
		sellall_btn.pressed.connect(func(): _on_sell_clicked(item, stock, row))
		_setup_button_hover(sellall_btn)
		btn_hbox.add_child(sellall_btn)
		
		player_list.add_child(row)

func _on_buy_clicked(item: ItemData, amount: int, row_node: Control) -> void:
	if not _current_stall:
		return
		
	var success = _current_stall.buy_item(item, amount)
	if success:
		_animate_success(row_node)
	else:
		_animate_failure(row_node)

func _on_sell_clicked(item: ItemData, amount: int, row_node: Control) -> void:
	if not _current_stall:
		return
		
	var success = _current_stall.sell_item(item, amount)
	if success:
		_animate_success(row_node)
	else:
		_animate_failure(row_node)

func _animate_success(node: Control) -> void:
	# Flash the row green briefly
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(0.4, 1.0, 0.4), 0.1)
	tween.tween_property(node, "modulate", Color(1, 1, 1), 0.1)

func _animate_failure(node: Control) -> void:
	# Shake/Flash red
	var orig_pos = node.position
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(1.0, 0.4, 0.4), 0.05)
	# Simple shake
	var target_x = node.position.x
	tween.tween_property(node, "position:x", target_x - 5.0, 0.05)
	tween.tween_property(node, "position:x", target_x + 5.0, 0.05)
	tween.tween_property(node, "position:x", target_x - 5.0, 0.05)
	tween.tween_property(node, "position:x", target_x, 0.05)
	tween.tween_property(node, "modulate", Color(1, 1, 1), 0.1)

func _setup_button_hover(button: Button) -> void:
	# Add micro hover scaling animation
	button.pivot_offset = button.custom_minimum_size / 2.0
	button.mouse_entered.connect(func():
		if not button.disabled:
			var tween = create_tween()
			tween.tween_property(button, "scale", Vector2(1.06, 1.06), 0.08)
	)
	button.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
	)

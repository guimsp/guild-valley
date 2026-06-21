extends HBoxContainer

var _main_view: Control = null
var _building: Node2D = null

@onready var min_stock_list: VBoxContainer = $WarehouseLeft/StockScroll/MinStockList
@onready var w_storage_lbl: Label = $WarehouseRight/WarehouseScroll/WarehouseScrollContent/WarehouseStorageLabel
@onready var w_storage_grid: GridContainer = $WarehouseRight/WarehouseScroll/WarehouseScrollContent/WarehouseStorageGrid
@onready var w_player_lbl: Label = $WarehouseRight/WarehouseScroll/WarehouseScrollContent/WarehousePlayerLabel
@onready var w_player_inv_grid: GridContainer = $WarehouseRight/WarehouseScroll/WarehouseScrollContent/WarehousePlayerGrid

const InventorySlotScene = preload("res://common/ui/inventory_slot.tscn")

func setup(p_view: Control) -> void:
	_main_view = p_view

func refresh(building: Node2D) -> void:
	_building = building
	_render_warehouse_view()

func _render_warehouse_view() -> void:
	for child in min_stock_list.get_children(): child.queue_free()
	for child in w_storage_grid.get_children(): child.queue_free()
	for child in w_player_inv_grid.get_children(): child.queue_free()
	
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	if econ_mgr:
		var items = []
		for id in econ_mgr.item_database:
			var item = econ_mgr.item_database[id]
			if item.is_tradable: items.append(item)
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
			val_edit.set_meta("type", "min_stock_edit")
			val_edit.set_meta("item_id", item.id)
			row.add_child(val_edit)
			var sanitize_func = func(text: String):
				var val = 0
				if text.is_valid_int(): val = max(0, text.to_int())
				val_edit.text = str(val)
				_building.min_retained_stock[item.id] = val
			val_edit.text_submitted.connect(sanitize_func)
			val_edit.focus_exited.connect(func(): sanitize_func.call(val_edit.text))
			val_edit.text_changed.connect(func(new_text: String):
				var cleaned = ""
				for i in range(new_text.length()):
					var c = new_text[i]
					if c >= '0' and c <= '9': cleaned += c
				var val = 0
				if cleaned.is_valid_int(): val = max(0, cleaned.to_int())
				_building.min_retained_stock[item.id] = val
				if new_text != cleaned:
					var old_caret = val_edit.caret_column
					val_edit.text = cleaned
					val_edit.caret_column = min(old_caret, cleaned.length())
			)
			min_stock_list.add_child(row)
			
	var target_b_inv = _building.inventory
	if target_b_inv:
		w_storage_lbl.text = "Warehouse Storage (%d/%d Slots)" % [target_b_inv.slots.size(), target_b_inv.max_slots]
		for i in range(target_b_inv.max_slots):
			var slot_panel = InventorySlotScene.instantiate()
			w_storage_grid.add_child(slot_panel)
			if i < target_b_inv.slots.size():
				var slot = target_b_inv.slots[i]
				slot_panel.set_item(slot["item"], slot["amount"], "building", false)
				slot_panel.slot_pressed.connect(_on_slot_pressed)
				slot_panel.slot_accepted.connect(_on_slot_accepted)
				slot_panel.set_meta("type", "warehouse_storage_slot")
				slot_panel.set_meta("item_id", slot["item"].id)
				slot_panel.set_meta("index", i)
			else:
				slot_panel.set_empty()
				
	if GameState.player_inventory:
		w_player_lbl.text = "Player Inventory (%d/%d Slots)" % [GameState.player_inventory.slots.size(), GameState.player_inventory.max_slots]
		for i in range(GameState.player_inventory.max_slots):
			var slot_panel = InventorySlotScene.instantiate()
			w_player_inv_grid.add_child(slot_panel)
			if i < GameState.player_inventory.slots.size():
				var slot = GameState.player_inventory.slots[i]
				slot_panel.set_item(slot["item"], slot["amount"], "player", false)
				slot_panel.slot_pressed.connect(_on_slot_pressed)
				slot_panel.slot_accepted.connect(_on_slot_accepted)
				slot_panel.set_meta("type", "warehouse_player_slot")
				slot_panel.set_meta("item_id", slot["item"].id)
				slot_panel.set_meta("index", i)
			else:
				slot_panel.set_empty()

func _on_slot_pressed(item: ItemData, source_type: String, is_shift: bool) -> void:
	if source_type == "building": _main_view.modal_manager.open_building_transfer_options(item, is_shift)
	elif source_type == "player": _move_item_player_to_building(item, is_shift)

func _on_slot_accepted(item: ItemData, source_type: String) -> void:
	if source_type == "building": _main_view.modal_manager.open_building_transfer_options(item, false)
	elif source_type == "player": _move_item_player_to_building(item, false)

func _move_item_player_to_building(item: ItemData, all_stack: bool) -> void:
	var source_inv = GameState.player_inventory
	if not source_inv: return
	var amt = source_inv.get_item_amount(item.id)
	if amt <= 0: return
	if amt == 1:
		_move_item_player_to_building_action(item, 1)
		_main_view.update_view()
	else:
		_main_view._coordinator.open_quantity_slider(item, "player_to_building", amt, amt if all_stack else 1, func(amount):
			_move_item_player_to_building_action(item, amount)
			_main_view.update_view()
		)

func _move_item_player_to_building_action(item: ItemData, transfer_qty: int) -> void:
	var source_inv = GameState.player_inventory
	var target_inv = _building.inventory
	if not source_inv or not target_inv: return
	if target_inv.slots.size() >= target_inv.max_slots and not target_inv.has_item(item.id, 1):
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Building storage is full!", _building.global_position)
		return
	var remainder = target_inv.add_item(item, transfer_qty)
	var transferred = transfer_qty - remainder
	if transferred > 0:
		source_inv.remove_item(item.id, transferred)
	else:
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud: hud._spawn_floating_text("Storage is full!", _building.global_position)

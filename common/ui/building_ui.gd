extends PanelContainer

# UI Elements
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var bottom_close_button: Button = %BottomCloseButton

# Statically Configured Sub-Views
@onready var category_tab_container: HBoxContainer = %CategoryTabs
@onready var main_data_view: Control = %MainDataView
@onready var employees_view: Control = %EmployeesView
@onready var ledger_view: Control = %LedgerView
@onready var upgrades_view: Control = %UpgradesView

# Global Slider Overlay
@onready var slider_overlay: ColorRect = %SliderOverlay
@onready var quantity_slider_modal: Control = %QuantitySliderModal

var _building: Node2D = null
var _updating_ui: bool = false

const CATEGORIES = ["Main Data", "Employees", "Ledger", "Leveling", "Improvements"]
var _active_category_idx: int = 0
var _last_focused_trigger_button: Control = null
var _last_valid_popup_focus: Control = null
var _slider_confirm_callback: Callable = Callable()

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(close)
		_setup_button_hover(close_button)
		close_button.focus_mode = Control.FOCUS_NONE
	if bottom_close_button:
		bottom_close_button.pressed.connect(close)
		_setup_button_hover(bottom_close_button)
		bottom_close_button.focus_mode = Control.FOCUS_ALL

	add_to_group("BuildingUIs")
	slider_overlay.hide()
	quantity_slider_modal.hide()
	
	get_viewport().gui_focus_changed.connect(_on_viewport_focus_changed)

func open(building: Node2D) -> void:
	_building = building
	_updating_ui = false
	_active_category_idx = 0
	
	# Clear active callbacks
	_slider_confirm_callback = Callable()
	slider_overlay.hide()
	quantity_slider_modal.hide()
	
	# Setup all child views
	main_data_view.setup(_building, self)
	employees_view.setup(_building, self)
	ledger_view.setup(_building, self)
	upgrades_view.setup(_building, self)
	
	# Register signal connections
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
	_slider_confirm_callback = Callable()
	slider_overlay.hide()
	quantity_slider_modal.hide()
	
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
		
	if slider_overlay and slider_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_on_slider_cancelled()
			get_viewport().set_input_as_handled()
			return
			
		if event.is_pressed() and not event.is_echo():
			if event.is_action_pressed("move_left") or (event is InputEventKey and event.keycode == KEY_A):
				quantity_slider_modal.slider.value = max(quantity_slider_modal.slider.min_value, quantity_slider_modal.slider.value - 1)
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("move_right") or (event is InputEventKey and event.keycode == KEY_D):
				quantity_slider_modal.slider.value = min(quantity_slider_modal.slider.max_value, quantity_slider_modal.slider.value + 1)
				get_viewport().set_input_as_handled()
				return
			elif event is InputEventKey and event.keycode == KEY_R:
				quantity_slider_modal.slider.value = quantity_slider_modal.slider.max_value
				quantity_slider_modal.confirm_button.pressed.emit()
				get_viewport().set_input_as_handled()
				return
				
			if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
				quantity_slider_modal.confirm_button.pressed.emit()
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

func refresh() -> void:
	if not _building:
		return
		
	_updating_ui = true
	
	if title_label:
		title_label.text = "%s Management Ledger" % _building.name.replace("Interior_", "")
		
	_update_category_tabs()
	
	# Hide inactive views, keep the active one visible to preserve focus owner
	if _active_category_idx != 0:
		main_data_view.hide()
	if _active_category_idx != 1:
		employees_view.hide()
	if _active_category_idx != 2:
		ledger_view.hide()
	if _active_category_idx != 3 and _active_category_idx != 4:
		upgrades_view.hide()
	
	# Show & refresh the active one
	match _active_category_idx:
		0:
			main_data_view.show()
			main_data_view.update_view()
		1:
			employees_view.show()
			employees_view.update_view()
		2:
			ledger_view.show()
			ledger_view.update_view()
		3:
			upgrades_view.show()
			upgrades_view.update_view("leveling")
		4:
			upgrades_view.show()
			upgrades_view.update_view("improvements")
			
	_updating_ui = false

func _update_category_tabs() -> void:
	if not category_tab_container:
		return
		
	for child in category_tab_container.get_children():
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
			normal_style.bg_color = Color(0.24, 0.52, 0.85, 0.9)
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
		
		category_tab_container.add_child(tab_btn)

# --- COORDINATION QUANTITY SLIDER MODAL ---
func open_quantity_slider(item: ItemData, mode: String, max_limit: int, default_val: int, on_confirm: Callable) -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		_last_focused_trigger_button = focused
		
	# Safe disconnect
	if quantity_slider_modal.confirmed.is_connected(_on_slider_confirmed):
		quantity_slider_modal.confirmed.disconnect(_on_slider_confirmed)
	if quantity_slider_modal.cancelled.is_connected(_on_slider_cancelled):
		quantity_slider_modal.cancelled.disconnect(_on_slider_cancelled)
		
	_slider_confirm_callback = on_confirm
	quantity_slider_modal.confirmed.connect(_on_slider_confirmed)
	quantity_slider_modal.cancelled.connect(_on_slider_cancelled)
	
	slider_overlay.show()
	quantity_slider_modal.setup(item, mode, max_limit, default_val)

func _on_slider_confirmed(item: ItemData, mode: String, amount: int) -> void:
	slider_overlay.hide()
	if _slider_confirm_callback:
		_slider_confirm_callback.call(amount)
	_slider_confirm_callback = Callable()
	_restore_modal_focus()

func _on_slider_cancelled() -> void:
	slider_overlay.hide()
	_slider_confirm_callback = Callable()
	_restore_modal_focus()

func _restore_modal_focus() -> void:
	_last_valid_popup_focus = null
	
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus and is_instance_valid(current_focus) and current_focus.is_inside_tree():
		var active_view = null
		match _active_category_idx:
			0: active_view = main_data_view
			1: active_view = employees_view
			2: active_view = ledger_view
			3, 4: active_view = upgrades_view
		if active_view and active_view.is_ancestor_of(current_focus):
			return
			
	var focus_restored = false
	if _last_focused_trigger_button and is_instance_valid(_last_focused_trigger_button) and _last_focused_trigger_button.is_inside_tree() and _last_focused_trigger_button.get("disabled") != true and _last_focused_trigger_button.visible:
		_last_focused_trigger_button.grab_focus()
		focus_restored = true
		
	if not focus_restored:
		_focus_first_button()

# --- SYSTEM HELPERS ---
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

func _focus_first_button() -> void:
	if not is_inside_tree() or not visible:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_inside_tree() or not visible:
		return
		
	var active_view = _get_active_view()
	if active_view:
		var btn = _find_first_focusable_button(active_view)
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

func _get_active_view() -> Control:
	match _active_category_idx:
		0: return main_data_view
		1: return employees_view
		2: return ledger_view
		3, 4: return upgrades_view
	return null

func _on_viewport_focus_changed(control: Control) -> void:
	if slider_overlay and slider_overlay.visible:
		if control:
			if slider_overlay.is_ancestor_of(control):
				_last_valid_popup_focus = control
			else:
				if _last_valid_popup_focus and is_instance_valid(_last_valid_popup_focus) and _last_valid_popup_focus.is_inside_tree() and _last_valid_popup_focus.visible:
					_last_valid_popup_focus.call_deferred("grab_focus")
				else:
					var fallback = _find_first_focusable_in_popup(slider_overlay)
					if fallback:
						_last_valid_popup_focus = fallback
						fallback.call_deferred("grab_focus")

func _find_first_focusable_in_popup(node: Node) -> Control:
	if node is Control and node.visible and node.focus_mode != Control.FOCUS_NONE:
		return node
	for child in node.get_children():
		var found = _find_first_focusable_in_popup(child)
		if found:
			return found
	return null

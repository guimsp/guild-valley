extends Node

var _main_hud: CanvasLayer = null
var alert_cards_vbox: VBoxContainer = null
var alert_history_window: PanelContainer = null

func setup(p_hud: CanvasLayer) -> void:
	_main_hud = p_hud
	_create_alert_containers()
	
	# Connect signals for dynamic reactive refreshing
	AlertManager.alert_added.connect(_on_alert_added)
	AlertManager.alert_removed.connect(_on_alert_removed)
	
	# Initialize existing active alerts
	for alert in AlertManager.active_alerts:
		_on_alert_added(alert)

func refresh() -> void:
	populate_alert_history()

func _create_alert_containers() -> void:
	var alert_margin = MarginContainer.new()
	alert_margin.name = "AlertCards_Margin"
	alert_margin.layout_mode = 1
	alert_margin.anchor_left = 1.0
	alert_margin.anchor_top = 0.15
	alert_margin.anchor_right = 1.0
	alert_margin.anchor_bottom = 0.85
	alert_margin.offset_left = -300.0
	alert_margin.offset_top = 0.0
	alert_margin.offset_right = -16.0
	alert_margin.offset_bottom = 0.0
	alert_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	alert_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	alert_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	alert_cards_vbox = VBoxContainer.new()
	alert_cards_vbox.name = "AlertCards_VBox"
	alert_cards_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_cards_vbox.add_theme_constant_override("separation", 8)
	alert_margin.add_child(alert_cards_vbox)
	
	var hud_control = _main_hud.get_node("Control")
	if hud_control:
		hud_control.add_child(alert_margin)
		
	# Create Alert History Window dynamically
	alert_history_window = PanelContainer.new()
	alert_history_window.name = "AlertHistory_Window"
	alert_history_window.visible = false
	alert_history_window.custom_minimum_size = Vector2(640, 440)
	alert_history_window.layout_mode = 1
	alert_history_window.anchors_preset = Control.PRESET_CENTER
	alert_history_window.anchor_left = 0.5
	alert_history_window.anchor_top = 0.5
	alert_history_window.anchor_right = 0.5
	alert_history_window.anchor_bottom = 0.5
	alert_history_window.offset_left = -320.0
	alert_history_window.offset_top = -220.0
	alert_history_window.offset_right = 320.0
	alert_history_window.offset_bottom = 220.0
	alert_history_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert_history_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	if _main_hud.inventory_window:
		var window_style = _main_hud.inventory_window.get_theme_stylebox("panel")
		alert_history_window.add_theme_stylebox_override("panel", window_style)
		
	if _main_hud.windows_container:
		_main_hud.windows_container.add_child(alert_history_window)
		
	var history_vbox = VBoxContainer.new()
	history_vbox.name = "VBox"
	history_vbox.add_theme_constant_override("separation", 12)
	alert_history_window.add_child(history_vbox)
	
	# Header
	var header = HBoxContainer.new()
	header.name = "Header"
	history_vbox.add_child(header)
	
	var title = Label.new()
	title.name = "Title"
	title.text = "Alert History (F7)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.88, 0.55, 0.12, 1.0))
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	
	# Scroll area for history rows
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_vbox.add_child(scroll)
	
	var list = VBoxContainer.new()
	list.name = "HistoryList"
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	
	# Footer
	var footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 12)
	history_vbox.add_child(footer)
	
	var clear_btn = Button.new()
	clear_btn.name = "ClearButton"
	clear_btn.text = "Clear History"
	clear_btn.custom_minimum_size = Vector2(120, 32)
	clear_btn.pressed.connect(_on_clear_history_pressed)
	footer.add_child(clear_btn)
	if _main_hud.has_method("_setup_button_hover"):
		_main_hud._setup_button_hover(clear_btn)
		
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(func():
		_main_hud.toggle_window(alert_history_window)
	)
	footer.add_child(close_btn)
	if _main_hud.has_method("_setup_button_hover"):
		_main_hud._setup_button_hover(close_btn)

func _get_alert_stylebox(type: String) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.14, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	
	match type:
		"warning": style.border_color = Color(0.88, 0.55, 0.12, 0.85)
		"danger": style.border_color = Color(0.86, 0.24, 0.24, 0.85)
		_: style.border_color = Color(0.24, 0.6, 0.86, 0.85)
	return style

func _on_alert_added(alert_data: Dictionary) -> void:
	if not alert_cards_vbox or alert_cards_vbox.has_node(alert_data.id):
		return
		
	var card = PanelContainer.new()
	card.name = alert_data.id
	card.custom_minimum_size = Vector2(280, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _get_alert_stylebox(alert_data.type))
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = alert_data.title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	match alert_data.type:
		"warning": title.add_theme_color_override("font_color", Color(0.88, 0.55, 0.12))
		"danger": title.add_theme_color_override("font_color", Color(0.86, 0.24, 0.24))
		_: title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
	header.add_child(title)
	
	var y_label = Label.new()
	y_label.text = "[Y]"
	y_label.add_theme_font_size_override("font_size", 10)
	y_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	header.add_child(y_label)

	var timer_label = Label.new()
	timer_label.text = "10s"
	timer_label.add_theme_font_size_override("font_size", 10)
	timer_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(timer_label)

	var close_x = Button.new()
	close_x.text = "X"
	close_x.flat = true
	close_x.custom_minimum_size = Vector2(20, 20)
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.add_theme_font_size_override("font_size", 10)
	close_x.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	close_x.pressed.connect(func():
		AlertManager.remove_alert(alert_data.id)
	)
	header.add_child(close_x)
	if _main_hud.has_method("_setup_button_hover"):
		_main_hud._setup_button_hover(close_x)
	
	# Body
	var desc = Label.new()
	desc.text = alert_data.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(desc)
	
	# Footer
	var footer = HBoxContainer.new()
	vbox.add_child(footer)
	
	var time_lbl = Label.new()
	time_lbl.text = alert_data.time
	time_lbl.add_theme_font_size_override("font_size", 9)
	time_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	footer.add_child(time_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	
	if alert_data.get("building") != null and is_instance_valid(alert_data.building):
		var inspect = Button.new()
		inspect.text = "Inspect"
		inspect.custom_minimum_size = Vector2(60, 20)
		inspect.add_theme_font_size_override("font_size", 10)
		inspect.pressed.connect(func():
			_on_inspect_alert(alert_data)
		)
		footer.add_child(inspect)
		if _main_hud.has_method("_setup_button_hover"):
			_main_hud._setup_button_hover(inspect)
		
	alert_cards_vbox.add_child(card)
	_start_alert_timer(card, timer_label, alert_data.id)
	
	card.ready.connect(func():
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0
		var tween = card.create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.2)
	)

func _on_alert_removed(alert_id: String) -> void:
	if not alert_cards_vbox:
		return
	var card = alert_cards_vbox.get_node_or_null(alert_id)
	if card:
		_dismiss_card(card)

func _dismiss_card(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size / 2.0
	var tween = card.create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "modulate:a", 0.0, 0.15)
	tween.tween_property(card, "custom_minimum_size:y", 0.0, 0.15)
	tween.chain().tween_callback(card.queue_free)

func _start_alert_timer(card: Control, timer_label: Label, alert_id: String) -> void:
	var secs = 10
	while secs > 0:
		if not is_instance_valid(card) or not card.is_inside_tree():
			return
		timer_label.text = "%ds" % secs
		await card.get_tree().create_timer(1.0).timeout
		secs -= 1
	if is_instance_valid(card) and card.is_inside_tree():
		AlertManager.remove_alert(alert_id)

func open_alert_history_focusing_on(alert_id: String) -> void:
	if not alert_history_window.visible:
		_main_hud.toggle_window(alert_history_window)
	else:
		populate_alert_history()
		
	var list = alert_history_window.find_child("HistoryList", true, false) as VBoxContainer
	if list:
		var scroll = alert_history_window.find_child("ScrollContainer", true, false) as ScrollContainer
		for child in list.get_children():
			if child.name == alert_id:
				var inspect_btn = child.find_child("InspectButton", true, false) as Button
				if inspect_btn and is_instance_valid(inspect_btn):
					inspect_btn.grab_focus()
				else:
					child.grab_focus()
				if scroll:
					await _main_hud.get_tree().process_frame
					scroll.scroll_vertical = child.position.y
				break

func _on_inspect_alert(alert_data: Dictionary) -> void:
	var building = alert_data.get("building")
	if not is_instance_valid(building):
		return
	if _main_hud.windows_container:
		_main_hud.windows_container.hide()
		for child in _main_hud.windows_container.get_children():
			child.hide()
	if _main_hud.has_method("open_building_ui"):
		_main_hud.open_building_ui(building)

func populate_alert_history() -> void:
	if not alert_history_window:
		return
		
	var list = alert_history_window.find_child("HistoryList", true, false) as VBoxContainer
	if not list:
		return
		
	for child in list.get_children():
		child.queue_free()
		
	var past = AlertManager.past_alerts
	if past.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No alerts in history."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		list.add_child(empty_lbl)
		return
		
	for alert in past:
		var row = PanelContainer.new()
		row.name = alert.id
		row.focus_mode = Control.FOCUS_ALL
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var is_active = false
		for act in AlertManager.active_alerts:
			if act.id == alert.id:
				is_active = true
				break
				
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.14, 0.12, 0.16, 0.75)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		
		if is_active:
			match alert.type:
				"warning": style.border_color = Color(0.88, 0.55, 0.12, 0.8)
				"danger": style.border_color = Color(0.86, 0.24, 0.24, 0.8)
				_: style.border_color = Color(0.24, 0.6, 0.86, 0.8)
		else:
			style.border_color = Color(0.25, 0.25, 0.3, 0.5)
			
		row.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)
		
		var text_vbox = VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(text_vbox)
		
		var title = Label.new()
		var active_suffix = " (ACTIVE)" if is_active else " (Resolved)"
		title.text = alert.title + active_suffix
		title.add_theme_font_size_override("font_size", 12)
		if is_active:
			match alert.type:
				"warning": title.add_theme_color_override("font_color", Color(0.88, 0.55, 0.12))
				"danger": title.add_theme_color_override("font_color", Color(0.86, 0.24, 0.24))
				_: title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
		else:
			title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		text_vbox.add_child(title)
		
		var desc = Label.new()
		desc.text = alert.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85) if is_active else Color(0.6, 0.6, 0.6))
		text_vbox.add_child(desc)
		
		var time_lbl = Label.new()
		time_lbl.text = alert.time
		time_lbl.add_theme_font_size_override("font_size", 9)
		time_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		text_vbox.add_child(time_lbl)
		
		var btn_vbox = VBoxContainer.new()
		btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(btn_vbox)
		
		if alert.get("building") != null and is_instance_valid(alert.building):
			var inspect = Button.new()
			inspect.name = "InspectButton"
			inspect.text = "Inspect"
			inspect.custom_minimum_size = Vector2(80, 24)
			inspect.add_theme_font_size_override("font_size", 10)
			inspect.pressed.connect(func():
				_on_inspect_alert(alert)
			)
			btn_vbox.add_child(inspect)
			if _main_hud.has_method("_setup_button_hover"):
				_main_hud._setup_button_hover(inspect)
			
		list.add_child(row)

func _on_clear_history_pressed() -> void:
	AlertManager.past_alerts = AlertManager.active_alerts.duplicate()
	populate_alert_history()

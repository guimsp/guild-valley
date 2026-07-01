extends PanelContainer

@onready var close_button: Button = %CloseButton
@onready var active_tab_button: Button = %ActiveTabButton
@onready var editor_tab_button: Button = %EditorTabButton
@onready var content_area: PanelContainer = %ContentArea

var active_routes_view: Control = null
var route_editor_view: Control = null

func _ready() -> void:
	# Load and instantiate sub-views
	var active_scene = load("res://common/ui/active_routes_view.tscn")
	if active_scene:
		active_routes_view = active_scene.instantiate()
		content_area.add_child(active_routes_view)
		active_routes_view.modify_route_requested.connect(_on_modify_requested)
		
	var editor_scene = load("res://common/ui/route_editor_view.tscn")
	if editor_scene:
		route_editor_view = editor_scene.instantiate()
		content_area.add_child(route_editor_view)
		route_editor_view.route_save_committed.connect(_on_route_save_committed)
		
	active_tab_button.focus_mode = Control.FOCUS_NONE
	editor_tab_button.focus_mode = Control.FOCUS_NONE
	close_button.visible = false
	close_button.pressed.connect(close)
	active_tab_button.pressed.connect(func(): _switch_tab("active"))
	editor_tab_button.pressed.connect(func(): _switch_tab("editor"))
	
	# Determine default tab: if there are any active routes, open active routes list.
	var has_routes = false
	var buildings = get_tree().get_nodes_in_group("production_buildings")
	for b in buildings:
		if is_instance_valid(b) and b.ownership_type == "Player":
			var hired = b.get("hired_employees")
			if hired:
				for emp in hired:
					if emp.get("active_commercial_route") != null:
						has_routes = true
						break
	
	if has_routes:
		_switch_tab("active")
	else:
		_switch_tab("editor")

func close() -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("close_commercial_routes_ui"):
		hud.close_commercial_routes_ui()
	else:
		queue_free()

func _switch_tab(tab_name: String) -> void:
	if tab_name == "active":
		if active_routes_view:
			active_routes_view.visible = true
			active_routes_view.refresh_routes()
		if route_editor_view:
			route_editor_view.visible = false
			
		_set_tab_button_style(active_tab_button, true)
		_set_tab_button_style(editor_tab_button, false)
		editor_tab_button.text = "Route Editor"
	else:
		if active_routes_view:
			active_routes_view.visible = false
		if route_editor_view:
			route_editor_view.visible = true
			if not route_editor_view.is_modifying:
				route_editor_view.setup_new()
				
		_set_tab_button_style(active_tab_button, false)
		_set_tab_button_style(editor_tab_button, true)

func _set_tab_button_style(btn: Button, is_active: bool) -> void:
	var style = StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.18, 0.24, 0.35, 0.95)
		style.border_color = Color(0.88, 0.73, 0.23, 1.0)
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	else:
		style.bg_color = Color(0.1, 0.12, 0.16, 0.8)
		style.border_color = Color(0.3, 0.35, 0.4, 0.4)
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color.WHITE)
		
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("focus", style)

func _on_modify_requested(emp_data: Dictionary, route: Resource) -> void:
	if not route_editor_view:
		return
		
	# Enforce safety amendment #2: isolated deep copy
	var route_copy = route.duplicate(true)
	route_editor_view.setup_edit(emp_data, route_copy)
	
	_switch_tab("editor")
	editor_tab_button.text = "Modify Route"

func _on_route_save_committed(emp_data: Dictionary, selected_stops_data: Array, is_new: bool) -> void:
	var emp = emp_data["emp"]
	var ws = emp_data["workshop"]
	var npc = emp.get("npc_ref")
	
	if is_new:
		var route = load("res://components/production/global_logistics_route.gd").new()
		route.route_name = "Route for " + emp.get("name", "Worker")
		
		var stops: Array[Resource] = []
		for stop_data in selected_stops_data:
			var stop = load("res://components/production/trade_route_stop.gd").new()
			stop.target_building = stop_data.building
			stop.action_type = stop_data.action
			stop.item_id = stop_data.item_id
			stop.target_quantity = stop_data.quantity
			stop.minimum_sell_price = stop_data.minimum_sell_price
			stops.append(stop)
			
		route.route_stops = stops
		route.carrier_npc_ref = npc
		
		emp["active_recipe_path"] = ""
		emp["active_gathering_node_path"] = ""
		emp["active_commercial_route"] = route
		emp["is_paused"] = false
		
		if is_instance_valid(npc):
			npc.active_commercial_route = route
			npc.current_stop_index = 0
			npc.worker_state = "internal_route_transit"
			npc.commercial_route_current_waypoint_index = 0
			npc.commercial_route_cargo_item_id = ""
			npc.commercial_route_cargo_amount = 0
			npc.commercial_route_gold_carried = 0
			npc.cargo_inventory.clear()
			
			npc.set("route_sales_in_current_run", 0)
			npc.set("consecutive_no_sales_runs", 0)
			
			npc.econ_brain.start_transit_to_stop(0)
			
		GameState.spawn_ui_floating_text("Logistics route started for %s!" % emp.get("name", "Worker"))
	else:
		# Modifying: retrieve active background route and commit updates safely
		var route = emp.get("active_commercial_route")
		if route != null:
			route.route_stops.clear()
			for stop_data in selected_stops_data:
				var stop = load("res://components/production/trade_route_stop.gd").new()
				stop.target_building = stop_data.building
				stop.action_type = stop_data.action
				stop.item_id = stop_data.item_id
				stop.target_quantity = stop_data.quantity
				stop.minimum_sell_price = stop_data.minimum_sell_price
				route.route_stops.append(stop)
				
			if is_instance_valid(npc):
				npc.active_commercial_route = route
				if npc.current_stop_index >= route.route_stops.size():
					npc.current_stop_index = 0
				npc.econ_brain.start_transit_to_stop(npc.current_stop_index)
				
			GameState.spawn_ui_floating_text("Logistics route updated for %s!" % emp.get("name", "Worker"))
			
	# Reset editor state and return to Active list
	if route_editor_view:
		route_editor_view.is_modifying = false
		route_editor_view.setup_new()
	_switch_tab("active")

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		# Close when ESC is pressed
		close()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
			return
			
		if event.keycode == KEY_Q:
			_switch_tab("active")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			_switch_tab("editor")
			get_viewport().set_input_as_handled()

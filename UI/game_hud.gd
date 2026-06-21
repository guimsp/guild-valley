extends CanvasLayer

# Signals for construction and placement
signal build_requested(building_data: BuildingData)
signal move_requested()
signal demolish_requested()

# Outlets for UI children
@onready var gold_label: Label = %GoldLabel
@onready var influence_label: Label = %InfluenceLabel
@onready var time_label: Label = %TimeLabel
@onready var player_title_label: Label = %PlayerTitleLabel

# Windows
@onready var character_window: PanelContainer = %CharacterScreen_Window
@onready var inventory_window: PanelContainer = %Inventory_Window
@onready var build_window: PanelContainer = %BuildMenu_Window
@onready var business_window: PanelContainer = %BusinessList_Window
@onready var opponents_window: PanelContainer = %OpponentsList_Window
@onready var pause_window: PanelContainer = %PauseMenu_Window
@onready var map_window: PanelContainer = %GlobalMap_Window
@onready var windows_container: Control = %Control_Windows
@onready var title_upgrade_window: PanelContainer = %TitleUpgrade_Window
@onready var influence_broker_window: PanelContainer = %InfluenceBroker_Window

var quest_board_ui_scene = load("res://UI/quest_board_ui.tscn")
var quest_board_ui_instance: PanelContainer = null
var lawhouse_ui_scene = load("res://UI/lawhouse_panel.tscn")
var lawhouse_ui_instance: PanelContainer = null
var guild_ui_instance: PanelContainer = null

# Shortcut buttons
@onready var button_f1: Button = %Button_F1
@onready var button_f2: Button = %Button_F2
@onready var button_f3: Button = %Button_F3
@onready var button_f4: Button = %Button_F4
@onready var button_f5: Button = %Button_F5
@onready var button_f6: Button = %Button_F6
@onready var button_f10: Button = %Button_F10

# Overlay elements
@onready var interact_prompt: PanelContainer = %InteractPrompt
@onready var interact_label: Label = %InteractLabel
@onready var market_ui: Control = %MarketUI
@onready var crafting_ui: Control = %CraftingUI

# Inner layouts
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var career_tab_container: TabContainer = %CareerTabContainer

# Equipment Panel UI references
@onready var armor_label: Label = %ArmorLabel
@onready var attack_label: Label = %AttackLabel
@onready var speed_label: Label = %SpeedLabel
@onready var capacity_label: Label = %CapacityLabel

@onready var head_slot: Button = %HeadSlot
@onready var body_slot: Button = %BodySlot
@onready var gloves_slot: Button = %GlovesSlot
@onready var weapon_slot: Button = %WeaponSlot
@onready var tool_slot: Button = %ToolSlot
@onready var bag_slot: Button = %BagSlot
@onready var necklace_slot: Button = %NecklaceSlot
@onready var ring_slot: Button = %RingSlot
@onready var trans_slot: Button = %TransSlot

# Pause Menu overlay reference for GameState compatibility
var pause_menu: Control:
	get: return pause_window

var _active_player: Player = null
var _all_recipes: Array = []
var _building_ui_instance: Control = null
var _commercial_route_ui_instance: Control = null

var alert_history_window: PanelContainer = null
var alert_ui_manager: Node = null

func _ready() -> void:
	# Keep processing even when paused
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("PlayerHUD")
	
	# Register F1-F8, Escape, and M actions programmatically on frame 0
	_ensure_input_actions()
	
	# Load recipes once at startup
	_load_all_recipes()
	
	# Connect to player if already exists
	_find_player()
	
	# Instantiate alert UI manager
	alert_ui_manager = load("res://UI/alert_ui_manager.gd").new()
	add_child(alert_ui_manager)
	alert_ui_manager.setup(self)
	alert_history_window = alert_ui_manager.alert_history_window
	
	# Setup child scripts
	if title_upgrade_window:
		title_upgrade_window.setup(self)
	if influence_broker_window:
		influence_broker_window.setup(self)
	if build_window:
		build_window.setup(self)
	if business_window:
		business_window.setup(self)
	if opponents_window:
		opponents_window.setup(self)
		
	# Wire up equipment slots
	head_slot.pressed.connect(func(): _on_equipment_slot_pressed("head"))
	body_slot.pressed.connect(func(): _on_equipment_slot_pressed("body"))
	gloves_slot.pressed.connect(func(): _on_equipment_slot_pressed("gloves"))
	weapon_slot.pressed.connect(func(): _on_equipment_slot_pressed("weapon"))
	tool_slot.pressed.connect(func(): _on_equipment_slot_pressed("tool"))
	bag_slot.pressed.connect(func(): _on_equipment_slot_pressed("bag"))
	necklace_slot.pressed.connect(func(): _on_equipment_slot_pressed("necklace"))
	ring_slot.pressed.connect(func(): _on_equipment_slot_pressed("ring"))
	trans_slot.pressed.connect(func(): _on_equipment_slot_pressed("transportation"))

	_setup_button_hover(head_slot)
	_setup_button_hover(body_slot)
	_setup_button_hover(gloves_slot)
	_setup_button_hover(weapon_slot)
	_setup_button_hover(tool_slot)
	_setup_button_hover(bag_slot)
	_setup_button_hover(necklace_slot)
	_setup_button_hover(ring_slot)
	_setup_button_hover(trans_slot)
	
	# Hide all sub-menus and overlays initially
	interact_prompt.hide()
	windows_container.hide()
	for child in windows_container.get_children():
		child.hide()
	market_ui.hide()
	crafting_ui.hide()
	
	# Dynamic initialization of NPC Debug Inspector panel
	var inspector_script = load("res://common/ui/npc_inspector_panel.gd")
	if inspector_script:
		var inspector_instance = inspector_script.new()
		inspector_instance.name = "NPCInspectorPanel"
		add_child(inspector_instance)
		inspector_instance.hide()
		
	# Wire up buttons in shortcut bar
	_setup_shortcut_buttons()
	
	# Wire up buttons in Pause Menu
	var resume_btn = %ResumeButton
	var save_btn = %SaveButton
	var load_btn = %LoadButton
	var quit_btn = %QuitButton
	
	resume_btn.pressed.connect(toggle_pause_menu)
	save_btn.pressed.connect(func(): SaveLoadManager.save_game())
	load_btn.pressed.connect(func(): SaveLoadManager.load_game())
	quit_btn.pressed.connect(func(): get_tree().quit())
	
	# Lock Pause Menu buttons keyboard focus
	resume_btn.focus_neighbor_top = quit_btn.get_path()
	resume_btn.focus_neighbor_bottom = save_btn.get_path()
	resume_btn.focus_neighbor_left = resume_btn.get_path()
	resume_btn.focus_neighbor_right = resume_btn.get_path()
	
	save_btn.focus_neighbor_top = resume_btn.get_path()
	save_btn.focus_neighbor_bottom = load_btn.get_path()
	save_btn.focus_neighbor_left = save_btn.get_path()
	save_btn.focus_neighbor_right = save_btn.get_path()
	
	load_btn.focus_neighbor_top = save_btn.get_path()
	load_btn.focus_neighbor_bottom = quit_btn.get_path()
	load_btn.focus_neighbor_left = load_btn.get_path()
	load_btn.focus_neighbor_right = load_btn.get_path()
	
	quit_btn.focus_neighbor_top = load_btn.get_path()
	quit_btn.focus_neighbor_bottom = resume_btn.get_path()
	quit_btn.focus_neighbor_left = quit_btn.get_path()
	quit_btn.focus_neighbor_right = quit_btn.get_path()
	
	# Setup hover scaling on general window close buttons
	for btn in get_tree().get_nodes_in_group("HUDCloseButtons"):
		if btn is Button:
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(func():
				windows_container.hide()
				for child in windows_container.get_children():
					child.hide()
				if _active_player:
					_active_player.unfreeze()
				var focused = get_viewport().gui_get_focus_owner()
				if focused:
					focused.release_focus()
			)
			_setup_button_hover(btn)
			
	# Update values initially
	update_hud_values()
	
	# Connect GameState and inventory signals
	if GameState.has_signal("gold_changed"):
		GameState.gold_changed.connect(func(new_gold): update_hud_values())
		
	if GameState.player_inventory:
		GameState.player_inventory.inventory_changed.connect(update_inventory_panel)
		
	TimeManager.time_changed.connect(_on_time_changed)
	_on_time_changed(TimeManager.time_hours, int(TimeManager.time_minutes), TimeManager.time_days)

func _process(_delta: float) -> void:
	if not _active_player:
		_find_player()
	if map_window.visible and %MapGraphics:
		%MapGraphics.queue_redraw()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_active_player = players[0] as Player
		if not _active_player.interactables_changed.is_connected(update_interaction_prompt):
			_active_player.interactables_changed.connect(update_interaction_prompt)
		update_interaction_prompt()

func _ensure_input_actions() -> void:
	var actions: Dictionary = {
		"hud_character": [KEY_F1],
		"hud_inventory": [KEY_F2, KEY_I],
		"hud_build": [KEY_F3, KEY_B],
		"hud_business": [KEY_F4],
		"hud_opponents": [KEY_F5],
		"hud_title": [KEY_F6],
		"hud_alerts": [KEY_F7],
		"hud_pause": [KEY_F10],
		"hud_map": [KEY_M]
	}
	
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			# Erasure ensures we bind exactly our custom keys
			InputMap.action_erase_events(action)
			
		for key in actions[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
			
	# Ensure WASD is mapped to ui_left, ui_right, ui_up, ui_down for menu navigation
	var ui_mappings = {
		"ui_left": [KEY_A],
		"ui_right": [KEY_D],
		"ui_up": [KEY_W],
		"ui_down": [KEY_S]
	}
	
	for action in ui_mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		
		# Check existing mapped keys to avoid adding duplicates
		var existing_keys = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				existing_keys.append(event.physical_keycode)
				
		for key in ui_mappings[action]:
			if not (key in existing_keys):
				var event = InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)

func _load_all_recipes() -> void:
	_all_recipes.clear()
	var dir = DirAccess.open("res://common/items/recipes/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var recipe = load("res://common/items/recipes/" + file_name)
				if recipe:
					_all_recipes.append(recipe)
			file_name = dir.get_next()
		dir.list_dir_end()

func _setup_shortcut_buttons() -> void:
	# Dynamically duplicate Button_F6 for Button_F7 (Alerts History)
	var button_f7: Button = null
	if button_f6 and is_instance_valid(button_f6):
		button_f7 = button_f6.duplicate() as Button
		button_f7.name = "Button_F7"
		button_f7.text = "F7: Alerts"
		button_f6.get_parent().add_child(button_f7)
		if button_f10:
			button_f6.get_parent().move_child(button_f7, button_f10.get_index())

	var buttons = {
		button_f1: character_window,
		button_f2: inventory_window,
		button_f3: build_window,
		button_f4: business_window,
		button_f5: opponents_window,
		button_f6: title_upgrade_window,
		button_f7: alert_history_window,
		button_f10: pause_window
	}
	
	for btn in buttons:
		if btn:
			btn.focus_mode = Control.FOCUS_NONE
			_setup_button_hover(btn)
			var target_window = buttons[btn]
			btn.pressed.connect(func():
				toggle_window(target_window)
			)

func _setup_button_hover(btn: Button) -> void:
	# Wait for resized to center the pivot offset programmatically
	if not btn.is_node_ready():
		btn.ready.connect(func(): btn.pivot_offset = btn.size / 2.0)
	else:
		btn.pivot_offset = btn.size / 2.0
		
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	
	btn.mouse_entered.connect(func():
		if not btn.disabled:
			_animate_scale(btn, 1.05)
	)
	btn.mouse_exited.connect(func():
		if not btn.disabled:
			_animate_scale(btn, 1.0)
	)
	btn.focus_entered.connect(func():
		if not btn.disabled:
			_animate_scale(btn, 1.05)
	)
	btn.focus_exited.connect(func():
		if not btn.disabled:
			_animate_scale(btn, 1.0)
	)

func _animate_scale(node: Control, target_scale: float) -> void:
	var tween = create_tween()
	tween.tween_property(node, "scale", Vector2(target_scale, target_scale), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func toggle_window(window: PanelContainer) -> void:
	# If placement mode is active, do not allow menu toggle except pause menu and build menu (which cancels placement)
	var pm = get_tree().get_first_node_in_group("PlacementManager")
	var pm_active = pm and pm.is_placement_active()
	if pm_active and window != pause_window:
		if window == build_window:
			pm._spawn_floating_text("Cancel", pm._active_player.global_position if pm._active_player else Vector2.ZERO)
			var focused = get_viewport().gui_get_focus_owner()
			if focused:
				focused.release_focus()
			pm.exit_placement_mode()
		return

	if window.visible:
		# Close window
		if window.has_method("_close_levels_overlay"):
			window._close_levels_overlay()
		window.hide()
		windows_container.hide()
		get_tree().paused = false
		if _active_player:
			_active_player.unfreeze()
		
		# Explicitly release focus so that WASD keys are not captured by hidden controls
		var focused = get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
	else:
		# Hide others
		windows_container.show()
		for child in windows_container.get_children():
			child.hide()
			
		window.show()
		
		# Pause state management
		if window == pause_window:
			get_tree().paused = true
			if _active_player:
				_active_player.freeze()
		elif window == map_window:
			get_tree().paused = false
			if _active_player:
				_active_player.unfreeze()
		else:
			get_tree().paused = false
			if _active_player:
				_active_player.freeze()
				
		# Transition anim
		window.pivot_offset = window.size / 2.0
		window.scale = Vector2(0.9, 0.9)
		var tween = create_tween()
		tween.tween_property(window, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Populate contents
		if window.has_method("refresh"):
			window.refresh()
		elif window == alert_history_window and alert_ui_manager:
			alert_ui_manager.refresh()
		elif window == character_window:
			update_career_tabs()
		elif window == inventory_window:
			update_inventory_panel()
			
		# Sync Keyboard Focus
		call_deferred("_grab_focus_on_first_element", window)

func _grab_focus_on_first_element(window: Control) -> void:
	if window.has_method("_focus_first_card_in_active_tab"):
		window._focus_first_card_in_active_tab()
		return
	var target = _find_first_focusable(window)
	if target:
		target.grab_focus()

func _find_first_focusable(node: Node) -> Control:
	if node is Control and node.focus_mode == Control.FOCUS_ALL and node.visible and not (node is PanelContainer):
		# Avoid choosing the large window panels as focus focusable objects
		if not node.name.ends_with("_Window"):
			return node
			
	for child in node.get_children():
		var found = _find_first_focusable(child)
		if found:
			return found
	return null

func _input(event: InputEvent) -> void:
	# Dialogue bubbles and input shortcuts
	if event.is_action_pressed("ui_cancel"):
		var pm = get_tree().get_first_node_in_group("PlacementManager")
		var pm_active = pm and pm.is_placement_active()
		if pm_active:
			return
			
		var dialogue_bubbles = get_tree().get_nodes_in_group("DialogueBubble")
		if dialogue_bubbles.size() > 0:
			for bubble in dialogue_bubbles:
				if is_instance_valid(bubble) and bubble.visible:
					bubble._on_close_pressed()
			get_viewport().set_input_as_handled()
			return

		var rel_ui = get_tree().get_first_node_in_group("RelationshipUI")
		if rel_ui and rel_ui.visible:
			rel_ui._on_close_pressed()
			get_viewport().set_input_as_handled()
			return
			
		var bank_ui_inst = get_node_or_null("BankUI")
		if not bank_ui_inst:
			bank_ui_inst = get_node_or_null("HUDControl/BankUI")
		if bank_ui_inst and bank_ui_inst.visible:
			if bank_ui_inst.has_method("_on_close_pressed"):
				bank_ui_inst._on_close_pressed()
			else:
				bank_ui_inst.queue_free()
				if _active_player:
					_active_player.unfreeze()
			update_interaction_prompt()
			get_viewport().set_input_as_handled()
			return
			
		var npc_inspector = get_node_or_null("NPCInspectorPanel")
		if not npc_inspector:
			npc_inspector = get_node_or_null("HUDControl/NPCInspectorPanel")
		if npc_inspector and npc_inspector.visible:
			npc_inspector.hide()
			get_viewport().set_input_as_handled()
			return
			
		if _building_ui_instance and _building_ui_instance.visible:
			close_building_ui()
			get_viewport().set_input_as_handled()
			return

		if _commercial_route_ui_instance and _commercial_route_ui_instance.visible:
			if not _commercial_route_ui_instance.get("popup") and not _commercial_route_ui_instance.get("employee_popup"):
				close_commercial_routes_ui()
				get_viewport().set_input_as_handled()
				return

		if market_ui and market_ui.visible:
			market_ui.close()
			get_viewport().set_input_as_handled()
			return

		if crafting_ui and crafting_ui.visible:
			crafting_ui.close()
			get_viewport().set_input_as_handled()
			return

		if is_instance_valid(build_window) and build_window.visible and is_instance_valid(build_window.levels_overlay):
			build_window._close_levels_overlay()
			get_viewport().set_input_as_handled()
			return

		if windows_container.visible:
			if pause_window.visible:
				toggle_pause_menu()
			else:
				windows_container.hide()
				for child in windows_container.get_children():
					child.hide()
				if _active_player:
					_active_player.unfreeze()
				var focused = get_viewport().gui_get_focus_owner()
				if focused:
					focused.release_focus()
			get_viewport().set_input_as_handled()
			return

		toggle_pause_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Shortcut Key Toggles
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.is_action_pressed("hud_character"):
			toggle_window(character_window)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_inventory"):
			toggle_window(inventory_window)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_build"):
			toggle_window(build_window)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_business"):
			toggle_window(business_window)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_opponents"):
			toggle_window(opponents_window)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_title"):
			toggle_window(title_upgrade_window)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_alerts"):
			toggle_window(alert_history_window)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_pause"):
			var pm = get_tree().get_first_node_in_group("PlacementManager")
			if pm and pm.is_placement_active():
				pm._spawn_floating_text("Cancel", pm._active_player.global_position if pm._active_player else Vector2.ZERO)
				pm.exit_placement_mode()
			else:
				toggle_pause_menu()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_map"):
			toggle_window(map_window)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB and map_window.visible:
			if %MapGraphics and %MapGraphics.has_method("toggle_zoom"):
				%MapGraphics.toggle_zoom()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U: # NPC Inspector panel
			var inspector = get_node_or_null("NPCInspectorPanel")
			if inspector:
				if inspector.visible:
					inspector.hide()
				else:
					inspector._populate_npc_list()
					inspector.show()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:
			var focused = get_viewport().gui_get_focus_owner()
			if not (focused and (focused is LineEdit or focused is TextEdit)):
				if GameState and not AlertManager.active_alerts.is_empty():
					var recent_alert = AlertManager.active_alerts.back()
					_open_alert_history_focusing_on(recent_alert.id)
					get_viewport().set_input_as_handled()
				
		# Sub-Tabs swapping in build panel or careers (Q/E)
		elif event.keycode == KEY_Q or event.keycode == KEY_E:
			if build_window.visible and is_instance_valid(build_window.levels_overlay):
				get_viewport().set_input_as_handled()
				return
				
			var active_tab_container: TabContainer = null
			if build_window.visible:
				active_tab_container = build_window.build_tab_container
			elif character_window.visible:
				active_tab_container = career_tab_container
				
			if active_tab_container:
				var offset = -1 if event.keycode == KEY_Q else 1
				var next_tab = (active_tab_container.current_tab + offset + active_tab_container.get_tab_count()) % active_tab_container.get_tab_count()
				active_tab_container.current_tab = next_tab
				get_viewport().set_input_as_handled()

	# Intercept F / Interact key confirming buttons
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and is_instance_valid(focused) and is_ancestor_of(focused):
				if focused is Button:
					focused.pressed.emit()
					get_viewport().set_input_as_handled()
				elif focused is PanelContainer:
					# Emit ui_accept to trigger grid click event callback
					var event_accept = InputEventAction.new()
					event_accept.action = "ui_accept"
					event_accept.pressed = true
					focused.gui_input.emit(event_accept)
					get_viewport().set_input_as_handled()

func toggle_pause_menu() -> void:
	toggle_window(pause_window)

func open_quest_board_ui(region_name: String) -> void:
	if windows_container:
		windows_container.show()
		for child in windows_container.get_children():
			child.hide()
			
	if not quest_board_ui_instance:
		quest_board_ui_instance = quest_board_ui_scene.instantiate()
		windows_container.add_child(quest_board_ui_instance)
		
	quest_board_ui_instance.open(region_name)

func open_lawhouse_ui(province_name: String) -> void:
	if windows_container:
		windows_container.show()
		for child in windows_container.get_children():
			child.hide()
			
	if not lawhouse_ui_instance:
		lawhouse_ui_instance = lawhouse_ui_scene.instantiate()
		windows_container.add_child(lawhouse_ui_instance)
		
	lawhouse_ui_instance.open(province_name)

func open_guild_ui(province_name: String, tab_name: String = "") -> void:
	if windows_container:
		windows_container.show()
		for child in windows_container.get_children():
			child.hide()
			
	if not is_instance_valid(guild_ui_instance):
		guild_ui_instance = PanelContainer.new()
		guild_ui_instance.set_script(preload("res://UI/guild_panel.gd"))
		windows_container.add_child(guild_ui_instance)
		
	guild_ui_instance.open(province_name, tab_name)

func update_hud_values() -> void:
	if gold_label:
		gold_label.text = "%d Gold" % GameState.gold
	if influence_label:
		influence_label.text = "Influence: %d / %d (Permanent)" % [GameState.influence, GameState.permanent_influence]
	if player_title_label:
		var title_name = GameState.get_title_name(GameState.title_level)
		player_title_label.text = "%s - %s" % [GameState.player_name, title_name]
		
	if character_window.visible:
		update_career_tabs()
	if title_upgrade_window.visible and title_upgrade_window.has_method("refresh"):
		title_upgrade_window.refresh()
	if influence_broker_window.visible and influence_broker_window.has_method("refresh"):
		influence_broker_window.refresh()

func update_inventory_panel() -> void:
	update_hud_values()
	if not inventory_grid:
		return
		
	# Clear previous inventory nodes
	for child in inventory_grid.get_children():
		child.queue_free()
		
	var slots = GameState.player_inventory.slots
	var max_slots = GameState.player_inventory.max_slots
	
	for slot in slots:
		var item: ItemData = slot["item"]
		var amount: int = slot["amount"]
		
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(64, 64)
		slot_panel.focus_mode = Control.FOCUS_ALL
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.22, 0.8)
		style.set_border_width_all(2)
		style.border_color = Color(0.35, 0.35, 0.45, 0.8)
		style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", style)
		
		var hover_style = style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.88, 0.73, 0.23, 0.9) # Gold accent border
		
		slot_panel.focus_entered.connect(func():
			slot_panel.add_theme_stylebox_override("panel", hover_style)
		)
		slot_panel.focus_exited.connect(func():
			slot_panel.add_theme_stylebox_override("panel", style)
		)
		slot_panel.mouse_entered.connect(func():
			slot_panel.add_theme_stylebox_override("panel", hover_style)
		)
		slot_panel.mouse_exited.connect(func():
			if not slot_panel.has_focus():
				slot_panel.add_theme_stylebox_override("panel", style)
		)
		
		slot_panel.gui_input.connect(func(event: InputEvent):
			var is_interact = event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F and event.pressed)
			var is_accept = event.is_action_pressed("ui_accept")
			var is_click = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
			if is_interact or is_accept or is_click:
				slot_panel.get_viewport().set_input_as_handled()
				_on_inventory_slot_interacted(item)
		)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_panel.add_child(vbox)
		
		var name_lbl = Label.new()
		name_lbl.text = item.name.substr(0, 8)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		vbox.add_child(name_lbl)
		
		var amt_lbl = Label.new()
		amt_lbl.text = "x%d" % amount
		amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(amt_lbl)
		
		var tooltip_str = "%s\nCategory: %s\nValue: %d Gold" % [item.name, item.category, item.base_value]
		if item.equipment_slot != "None":
			tooltip_str += "\nSlot: %s" % item.equipment_slot
			if item.armor_stat > 0: tooltip_str += "\nArmor: +%d" % item.armor_stat
			if item.attack_stat > 0: tooltip_str += "\nAttack: +%d" % item.attack_stat
			if item.speed_bonus > 0: tooltip_str += "\nSpeed: +%d%%" % int(item.speed_bonus * 100)
			if item.capacity_bonus > 0: tooltip_str += "\nCapacity: +%d slots" % item.capacity_bonus
			if item.gathering_multiplier_bonus > 0: tooltip_str += "\nGathering Bonus: +%d%%" % int(item.gathering_multiplier_bonus * 100)
			if item.is_tool: tooltip_str += "\nDurability: %d/%d" % [item.durability, item.max_durability]
		
		slot_panel.tooltip_text = tooltip_str
		inventory_grid.add_child(slot_panel)
		
	# Fill in blank spots
	var empty_slots = max_slots - slots.size()
	for i in range(empty_slots):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(64, 64)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.16, 0.5)
		style.set_border_width_all(1)
		style.border_color = Color(0.24, 0.24, 0.3, 0.5)
		style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", style)
		
		inventory_grid.add_child(slot_panel)
		
	# Update player equipment stats and slots UI
	_update_player_equipment_ui()
	_link_inventory_grid_focus()

func _update_player_equipment_ui() -> void:
	if not _active_player or not _active_player.has_node("EquipmentComponent"):
		return
		
	var eq = _active_player.get_node("EquipmentComponent")
	
	# Update Stats labels
	armor_label.text = "Armor: %d" % eq.get_total_armor()
	attack_label.text = "Attack: %d" % eq.get_total_attack()
	speed_label.text = "Speed Bonus: +%d%%" % int(eq.get_total_speed_bonus() * 100)
	capacity_label.text = "Capacity Bonus: %+d slots" % eq.get_total_capacity_bonus()
	
	# Update each Slot Button
	var slot_buttons = {
		"head": head_slot,
		"body": body_slot,
		"gloves": gloves_slot,
		"weapon": weapon_slot,
		"tool": tool_slot,
		"bag": bag_slot,
		"necklace": necklace_slot,
		"ring": ring_slot,
		"transportation": trans_slot
	}
	
	var slot_friendly_names = {
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
		var btn = slot_buttons[slot_name]
		var item = eq.get_equipped_item(slot_name)
		if item:
			var btn_text = item.name
			if item.is_tool:
				btn_text += " (%d/%d)" % [item.durability, item.max_durability]
			btn.text = btn_text
			btn.icon = item.icon
			btn.tooltip_text = "%s (%s)\nClick to unequip" % [item.name, slot_friendly_names[slot_name]]
		else:
			btn.text = "%s: Empty" % slot_friendly_names[slot_name]
			btn.icon = null
			btn.tooltip_text = "Empty %s slot" % slot_friendly_names[slot_name]

func _on_equipment_slot_pressed(slot_name: String) -> void:
	if not _active_player or not _active_player.has_node("EquipmentComponent"):
		return
		
	var eq = _active_player.get_node("EquipmentComponent")
	var item = eq.get_equipped_item(slot_name)
	if not item:
		return
		
	# Safe Capacity Reduction Guard
	if item.capacity_bonus > 0:
		var new_capacity = GameState.player_inventory.max_slots - item.capacity_bonus
		if GameState.player_inventory.slots.size() > new_capacity:
			_spawn_floating_text("Inventory too full to unequip!", inventory_window.global_position + inventory_window.size / 2.0)
			return
			
	# Unequip and add back to inventory
	eq.unequip_item(slot_name)
	GameState.player_inventory.add_item(item, 1)
	_active_player.recalculate_equipment_stats()
	update_inventory_panel()

func _on_inventory_slot_interacted(item: ItemData) -> void:
	if not item:
		return
	if item.id.begins_with("book_"):
		var career = item.id.replace("book_", "")
		if GameState.career_levels.has(career):
			if GameState.career_levels[career] == 0:
				GameState.career_levels[career] = 1
				if GameState.career_xp.has(career):
					GameState.career_xp[career] = 0
				GameState.player_inventory.remove_item(item.id, 1)
				_spawn_floating_text("+ Career Unlocked!", inventory_window.global_position + inventory_window.size / 2.0)
				update_inventory_panel()
				if build_window.has_method("refresh"):
					build_window.refresh()
	elif item.equipment_slot != "None" and _active_player and _active_player.has_node("EquipmentComponent"):
		var eq = _active_player.get_node("EquipmentComponent")
		
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
			# Safe capacity swap check
			var current_equipped = eq.get_equipped_item(slot_name)
			var current_bonus = current_equipped.capacity_bonus if current_equipped else 0
			var new_bonus = item.capacity_bonus
			var net_diff = new_bonus - current_bonus
			if net_diff < 0:
				var new_capacity = GameState.player_inventory.max_slots + net_diff
				if GameState.player_inventory.slots.size() > new_capacity:
					_spawn_floating_text("Inventory too full to swap!", inventory_window.global_position + inventory_window.size / 2.0)
					return
					
			# Duplicate to make sure durability is separate instance
			var item_to_equip = item.duplicate()
			
			GameState.player_inventory.remove_item(item.id, 1)
			var swapped_item = eq.equip_item(slot_name, item_to_equip)
			if swapped_item:
				GameState.player_inventory.add_item(swapped_item, 1)
				
			_active_player.recalculate_equipment_stats()
			update_inventory_panel()

func _link_inventory_grid_focus() -> void:
	if not inventory_grid:
		return
	var childs = inventory_grid.get_children()
	var slots_count = childs.size()
	if slots_count == 0:
		return
		
	var cols = inventory_grid.columns
	var eq_slots = [head_slot, body_slot, gloves_slot, weapon_slot, tool_slot, bag_slot, necklace_slot, ring_slot, trans_slot]
	
	for i in range(slots_count):
		var slot = childs[i]
		if slot is PanelContainer and slot.focus_mode == Control.FOCUS_ALL:
			# Left neighbor
			if i % cols > 0:
				slot.focus_neighbor_left = slot.get_path_to(childs[i - 1])
			else:
				slot.focus_neighbor_left = slot.get_path()
			# Right neighbor
			if i % cols < cols - 1 and i + 1 < slots_count:
				slot.focus_neighbor_right = slot.get_path_to(childs[i + 1])
			else:
				# Rightmost column routes to equipment grid
				var row = i / cols
				var target_btn = eq_slots[min(row, eq_slots.size() - 1)]
				slot.focus_neighbor_right = slot.get_path_to(target_btn)
			# Top neighbor
			if i - cols >= 0:
				slot.focus_neighbor_top = slot.get_path_to(childs[i - cols])
			else:
				slot.focus_neighbor_top = slot.get_path()
			# Bottom neighbor
			if i + cols < slots_count:
				slot.focus_neighbor_bottom = slot.get_path_to(childs[i + cols])
			else:
				slot.focus_neighbor_bottom = slot.get_path()
				
	# Link equipment slots back to inventory grid and between themselves
	var eq_left = [head_slot, gloves_slot, tool_slot, necklace_slot, trans_slot]
	var eq_right = [body_slot, weapon_slot, bag_slot, ring_slot, null]
	
	for row in range(eq_left.size()):
		var left_btn = eq_left[row]
		var right_btn = eq_right[row]
		
		var target_inv_idx = min(row * cols + 4, slots_count - 1)
		var target_inv_slot = childs[target_inv_idx]
		if target_inv_slot and is_instance_valid(target_inv_slot):
			left_btn.focus_neighbor_left = left_btn.get_path_to(target_inv_slot)
			if right_btn:
				right_btn.focus_neighbor_left = right_btn.get_path_to(left_btn)
				left_btn.focus_neighbor_right = left_btn.get_path_to(right_btn)
			else:
				left_btn.focus_neighbor_right = left_btn.get_path()
				
		# Top & Bottom neighbors inside equipment grid
		if row > 0:
			left_btn.focus_neighbor_top = left_btn.get_path_to(eq_left[row - 1])
			if right_btn:
				var prev_right = eq_right[row - 1]
				if prev_right:
					right_btn.focus_neighbor_top = right_btn.get_path_to(prev_right)
		else:
			left_btn.focus_neighbor_top = left_btn.get_path()
			if right_btn:
				right_btn.focus_neighbor_top = right_btn.get_path()
				
		if row < eq_left.size() - 1:
			left_btn.focus_neighbor_bottom = left_btn.get_path_to(eq_left[row + 1])
			if right_btn:
				var next_right = eq_right[row + 1]
				if next_right:
					right_btn.focus_neighbor_bottom = right_btn.get_path_to(next_right)
				else:
					right_btn.focus_neighbor_bottom = right_btn.get_path_to(eq_left[row + 1])
		else:
			left_btn.focus_neighbor_bottom = left_btn.get_path()
			if right_btn:
				right_btn.focus_neighbor_bottom = right_btn.get_path()

func update_career_tabs() -> void:
	if not career_tab_container:
		return
		
	var char_title = get_node_or_null("Control/Control_Windows/CharacterScreen_Window/VBox/Header/Title")
	if char_title and GameState:
		char_title.text = "%s's Careers & Milestones (F1)" % GameState.player_name
		
	var careers = ["patreon", "craftsman", "tailor", "scholar"]
	
	if career_tab_container.get_child_count() != careers.size():
		for child in career_tab_container.get_children():
			child.queue_free()
			
		var skill_panel_scene = load("res://common/ui/skill_panel.tscn")
		if skill_panel_scene:
			for career in careers:
				var panel = skill_panel_scene.instantiate()
				career_tab_container.add_child(panel)
				panel.init_skill(career, _all_recipes)
				
	for i in range(careers.size()):
		var career = careers[i]
		var panel = career_tab_container.get_child(i)
		if panel and panel.has_method("update_panel"):
			panel.update_panel()
		var lvl = GameState.career_levels.get(career, 1)
		career_tab_container.set_tab_title(i, "%s (Lv. %d)" % [career.capitalize(), lvl])

# ----------------- COORDINATOR & HELPERS -----------------

func _spawn_floating_text(sn_text: String, pos: Vector2) -> void:
	var label = Label.new()
	label.text = sn_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	
	if "+" in sn_text:
		label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	elif "-" in sn_text:
		label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	
	# Add to main viewport layout node (parent of CanvasLayer)
	get_parent().add_child(label)
	label.global_position = pos + Vector2(-30, -20)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 40.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	
	await tween.finished
	label.queue_free()

func spawn_floating_text(sn_text: String, pos: Vector2) -> void:
	_spawn_floating_text(sn_text, pos)

func open_market(stall: CollisionObject2D) -> void:
	if market_ui and market_ui.has_method("open"):
		market_ui.open(stall)
		if _active_player:
			_active_player.freeze()
		interact_prompt.hide()

func close_market() -> void:
	if market_ui:
		market_ui.hide()
		if _active_player:
			_active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func open_crafting(bench: CraftingBench) -> void:
	if crafting_ui and crafting_ui.has_method("open"):
		crafting_ui.open(bench)
		if _active_player:
			_active_player.freeze()
		interact_prompt.hide()

func close_crafting() -> void:
	if crafting_ui:
		crafting_ui.hide()
		if _active_player:
			_active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func open_building_ui(building: Node2D) -> void:
	if _building_ui_instance:
		_building_ui_instance.queue_free()
		
	var building_ui_scene = load("res://common/ui/building_ui.tscn")
	if building_ui_scene:
		_building_ui_instance = building_ui_scene.instantiate() as Control
		add_child(_building_ui_instance)
		_building_ui_instance.open(building)
		if _active_player:
			_active_player.freeze()
		interact_prompt.hide()

func close_building_ui() -> void:
	if _building_ui_instance:
		var focused = get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
		_building_ui_instance.queue_free()
		_building_ui_instance = null
		if _active_player:
			_active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func set_placement_instruction(text: String) -> void:
	if interact_prompt and interact_label:
		interact_label.text = text
		interact_prompt.show()

func hide_placement_instruction() -> void:
	if interact_prompt:
		interact_prompt.hide()

func exit_placement_mode_external() -> void:
	var pm = get_tree().get_first_node_in_group("PlacementManager")
	if pm and pm.has_method("exit_placement_mode"):
		pm.exit_placement_mode()

func _on_time_changed(hours: int, minutes: int, days: int) -> void:
	if time_label:
		var ampm = "AM" if hours < 12 else "PM"
		var display_hours = hours % 12
		if display_hours == 0:
			display_hours = 12
		time_label.text = "Day %d - %02d:%02d %s" % [days, display_hours, minutes, ampm]

func update_interaction_prompt() -> void:
	var pm = get_tree().get_first_node_in_group("PlacementManager")
	var pm_active = pm and pm.is_placement_active()
	if not interact_prompt or not _active_player or pm_active:
		return
		
	# Check if player is currently manual crafting in any building
	var active_crafting_building: BaseProductionBuilding = null
	for building in get_tree().get_nodes_in_group("production_buildings"):
		if building.get("is_player_working_here"):
			active_crafting_building = building
			break
			
	if active_crafting_building:
		var recipe = load(active_crafting_building.player_crafting_recipe_path)
		var item_name = recipe.output_item.name if recipe else "Item"
		interact_label.text = "[F] Stop Crafting %s" % item_name
		interact_prompt.show()
		return
		
	var facing = _active_player.get_facing_interactables()
	if facing.size() > 0:
		var interactable = facing[0]
		var target = interactable
		var grid = _active_player._get_grid_for_crop(interactable)
		if grid:
			target = grid
			
		var text = ""
		if "ownership_type" in target:
			var ownership = target.ownership_type
			var is_buy = target.is_buyable if "is_buyable" in target else false
			var is_rent = target.is_rentable if "is_rentable" in target else false
			var buy_val = target.buy_cost if "buy_cost" in target else 0
			var rent_val = target.rent_cost if "rent_cost" in target else 0
			
			if ownership == "NPC":
				var npc_buy_cost = buy_val * 3
				if is_buy:
					text = "Locked (NPC Owned) | [R] Buy (%d G)" % npc_buy_cost
				else:
					text = "Locked. Opponent property."
				var is_workshop = interactable.is_in_group("Bakeries") or interactable.is_in_group("Smelters") or interactable.is_in_group("Inns") or interactable.is_in_group("Looms") or interactable.is_in_group("Mills") or interactable.is_in_group("PaperMakers") or interactable.is_in_group("PrintingPresses") or interactable.is_in_group("Banks") or interactable.is_in_group("MarketStall")
				if is_workshop and interactable.has_method("get_interaction_text"):
					var prompt_text = interactable.get_interaction_text()
					if prompt_text == "":
						text = ""
					elif "Buy" in prompt_text:
						text = "[F] %s" % prompt_text
					elif prompt_text == "Trade":
						text = "[F] Trade"
					elif prompt_text == "Locked" or "property" in prompt_text or "Opponent" in prompt_text:
						text = prompt_text
			elif ownership == "Player":
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text = interactable.get_interaction_text()
					if interact_prompt_text == "":
						text = ""
					else:
						normal_text = interact_prompt_text
						text = "[F] %s (Owned)" % normal_text
				else:
					text = "[F] %s (Owned)" % normal_text
					
				var db_item = target.building_data if "building_data" in target else (interactable.building_data if "building_data" in interactable else null)
				if not db_item and GameState.has_method("get_building_data_for_node"):
					db_item = GameState.get_building_data_for_node(target)
					if not db_item:
						db_item = GameState.get_building_data_for_node(interactable)
				if db_item:
					var demolish_refund = int(db_item.cost * 0.8)
					text += " | [V] Move | [X] Demolish (%d G Refund)" % demolish_refund
			elif ownership == "Rented":
				var current_rent_days = target.rent_days_remaining if "rent_days_remaining" in target else 0
				var max_rent_days = target.max_rent_days if "max_rent_days" in target else 5
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text = interactable.get_interaction_text()
					if interact_prompt_text != "":
						normal_text = interact_prompt_text
				text = "[F] %s" % normal_text
				if is_rent:
					text += " | [T] Extend (%d G, %d/%d days)" % [rent_val, current_rent_days, max_rent_days]
			else: # Public
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text = interactable.get_interaction_text()
					if interact_prompt_text != "":
						normal_text = interact_prompt_text
				text = "[F] %s" % normal_text
				if is_buy and target.ownership_type != "Public":
					text += " | [R] Buy (%d G)" % buy_val
				if is_rent:
					var max_rent_days = target.max_rent_days if "max_rent_days" in target else 5
					text += " | [T] Rent (%d G/day, max %d days)" % [rent_val, max_rent_days]
		else:
			var normal_text = "Interact"
			if interactable.has_method("get_interaction_text"):
				var interact_prompt_text = interactable.get_interaction_text()
				if interact_prompt_text != "":
					normal_text = interact_prompt_text
			text = "[F] %s" % normal_text
			
		if text == "":
			interact_prompt.hide()
		else:
			interact_label.text = text
			interact_prompt.show()
			
			var tween = create_tween()
			tween.tween_property(interact_prompt, "scale", Vector2(1.05, 1.05), 0.1)
			tween.tween_property(interact_prompt, "scale", Vector2(1.0, 1.0), 0.1)
	else:
		interact_prompt.hide()

var mega_node_monitor_window: PanelContainer = null

func open_mega_node_monitor(node: Area2D) -> void:
	if not mega_node_monitor_window:
		var scene = load("res://UI/mega_node_monitor.tscn")
		if scene:
			mega_node_monitor_window = scene.instantiate() as PanelContainer
			mega_node_monitor_window.name = "MegaNodeMonitor_Window"
			windows_container.add_child(mega_node_monitor_window)
			
	if mega_node_monitor_window:
		mega_node_monitor_window.target_node = node
		toggle_window(mega_node_monitor_window)

func open_commercial_routes_ui() -> void:
	if _commercial_route_ui_instance:
		_commercial_route_ui_instance.queue_free()
		
	var route_ui_scene = load("res://common/ui/commercial_route_panel.tscn")
	if route_ui_scene:
		_commercial_route_ui_instance = route_ui_scene.instantiate() as Control
		add_child(_commercial_route_ui_instance)
			
		if _active_player:
			_active_player.freeze()
		if interact_prompt:
			interact_prompt.hide()

func close_commercial_routes_ui() -> void:
	if _commercial_route_ui_instance:
		_commercial_route_ui_instance.queue_free()
		_commercial_route_ui_instance = null
		if _active_player:
			_active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func open_influence_broker_ui(_broker: Node2D) -> void:
	toggle_window(influence_broker_window)

func _open_alert_history_focusing_on(alert_id: String) -> void:
	if alert_ui_manager:
		alert_ui_manager.open_alert_history_focusing_on(alert_id)

# Micro-animation helper tweens
func _shake_element(node: Control) -> void:
	var start_pos = node.position
	var tween = create_tween()
	tween.tween_property(node, "position:x", start_pos.x - 6.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x + 6.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x - 4.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x + 4.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x, 0.05)

func shake_element(node: Control) -> void:
	_shake_element(node)

func _flash_element(node: Control, flash_color: Color) -> void:
	var orig_color = node.modulate
	var tween = create_tween()
	tween.tween_property(node, "modulate", flash_color, 0.1)
	tween.tween_property(node, "modulate", orig_color, 0.15)

func flash_element(node: Control, flash_color: Color) -> void:
	_flash_element(node, flash_color)

class_name GameHUD
extends CanvasLayer

# Signals for construction and placement
signal build_requested(building_data: BuildingData)
signal move_requested()
signal demolish_requested()

# Outlets for UI children
@onready var gold_label: Label = %GoldLabel
@onready var influence_label: Label = %GoldLabel.get_parent().get_node_or_null("InfluenceLabel") as Label if %GoldLabel else null
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

var quest_board_ui_scene: PackedScene = load("res://UI/quest_board_ui.tscn") as PackedScene
var quest_board_ui_instance: PanelContainer = null
var lawhouse_ui_scene: PackedScene = load("res://UI/lawhouse_panel.tscn") as PackedScene
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
var rental_window: PanelContainer = null
var rogue_mission_window: PanelContainer = null

# Dynamic Tab Panel references
var ledger_tab_panel: ScrollContainer = null
var modifiers_tab_panel: ScrollContainer = null
var employees_tab_panel: ScrollContainer = null

# Helper delegate classes
var character_tabs = preload("res://UI/game_hud_character_tabs.gd").new()
var inventory_manager = preload("res://UI/game_hud_inventory_manager.gd").new()
var rental_window_helper = preload("res://UI/game_hud_rental_window.gd").new()

func _ready() -> void:
	# Fallback for dynamic outlet reference issues
	if not influence_label:
		influence_label = get_node_or_null("Control/HUDControl/PermanentInfluenceLabel") as Label
	if not influence_label:
		influence_label = %InfluenceLabel
		
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
	alert_ui_manager = load("res://UI/alert_ui_manager.gd").new() as Node
	add_child(alert_ui_manager)
	alert_ui_manager.call("setup", self)
	alert_history_window = alert_ui_manager.get("alert_history_window") as PanelContainer
	
	# Setup child scripts
	if title_upgrade_window:
		title_upgrade_window.call("setup", self)
	if influence_broker_window:
		influence_broker_window.call("setup", self)
	if build_window:
		build_window.call("setup", self)
	if business_window:
		business_window.call("setup", self)
	if opponents_window:
		opponents_window.call("setup", self)
		
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
		(child as Control).hide()
	market_ui.hide()
	crafting_ui.hide()
	
	# Dynamic initialization of NPC Debug Inspector panel
	var inspector_script = load("res://common/ui/npc_inspector_panel.gd")
	if inspector_script:
		var inspector_instance = inspector_script.new() as Node
		inspector_instance.name = "NPCInspectorPanel"
		add_child(inspector_instance)
		inspector_instance.call("hide")
		
	# Wire up buttons in shortcut bar
	_setup_shortcut_buttons()
	
	# Wire up buttons in Pause Menu
	var resume_btn = %ResumeButton as Button
	var save_btn = %SaveButton as Button
	var load_btn = %LoadButton as Button
	var quit_btn = %QuitButton as Button
	
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
					(child as Control).hide()
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
		GameState.gold_changed.connect(func(new_gold: int): update_hud_values())
		
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
	var players: Array = get_tree().get_nodes_in_group("Player")
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
	var ui_mappings: Dictionary = {
		"ui_left": [KEY_A],
		"ui_right": [KEY_D],
		"ui_up": [KEY_W],
		"ui_down": [KEY_S]
	}
	
	for action in ui_mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		
		# Check existing mapped keys to avoid adding duplicates
		var existing_keys: Array[int] = []
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
		var file_name: String = dir.get_next()
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

	# Dynamically duplicate Button_F6 for Button_F8 (Wealth Ledger)
	var button_f8: Button = null
	if button_f6 and is_instance_valid(button_f6):
		button_f8 = button_f6.duplicate() as Button
		button_f8.name = "Button_F8"
		button_f8.text = "F8: Ledger"
		button_f6.get_parent().add_child(button_f8)
		if button_f10:
			button_f6.get_parent().move_child(button_f8, button_f10.get_index())

	var buttons: Dictionary = {
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
			var target_window: Control = buttons[btn] as Control
			btn.pressed.connect(func():
				toggle_window(target_window as PanelContainer)
			)
			
	if button_f8:
		button_f8.focus_mode = Control.FOCUS_NONE
		_setup_button_hover(button_f8)
		button_f8.pressed.connect(func():
			_toggle_wealth_ledger_tab()
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
	var pm = get_tree().get_first_node_in_group("PlacementManager") as Node2D
	var pm_active: bool = pm and pm.has_method("is_placement_active") and pm.call("is_placement_active")
	if pm_active and window != pause_window:
		if window == build_window:
			if pm.has_method("_spawn_floating_text"):
				pm.call("_spawn_floating_text", "Cancel", pm.get("_active_player").global_position if pm.get("_active_player") else Vector2.ZERO)
			var focused = get_viewport().gui_get_focus_owner()
			if focused:
				focused.release_focus()
			if pm.has_method("exit_placement_mode"):
				pm.call("exit_placement_mode")
		return

	if window.visible:
		# Close window
		if window.has_method("_close_levels_overlay"):
			window.call("_close_levels_overlay")
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
			(child as Control).hide()
			
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
			window.call("refresh")
		elif window == alert_history_window and alert_ui_manager:
			alert_ui_manager.call("refresh")
		elif window == character_window:
			update_career_tabs()
		elif window == inventory_window:
			update_inventory_panel()
			
		# Sync Keyboard Focus
		call_deferred("_grab_focus_on_first_element", window)

func _grab_focus_on_first_element(window: Control) -> void:
	if window.has_method("_focus_first_card_in_active_tab"):
		window.call("_focus_first_card_in_active_tab")
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
		var pm = get_tree().get_first_node_in_group("PlacementManager") as Node2D
		var pm_active: bool = pm and pm.has_method("is_placement_active") and pm.call("is_placement_active")
		if pm_active:
			return
			
		var dialogue_bubbles = get_tree().get_nodes_in_group("DialogueBubble")
		if dialogue_bubbles.size() > 0:
			for bubble in dialogue_bubbles:
				if is_instance_valid(bubble) and (bubble as Control).visible:
					bubble.call("_on_close_pressed")
			get_viewport().set_input_as_handled()
			return

		var rel_ui = get_tree().get_first_node_in_group("RelationshipUI") as Control
		if rel_ui and rel_ui.visible:
			rel_ui.call("_on_close_pressed")
			get_viewport().set_input_as_handled()
			return
			
		var bank_ui_inst = get_node_or_null("BankUI") as Control
		if not bank_ui_inst:
			bank_ui_inst = get_node_or_null("HUDControl/BankUI") as Control
		if bank_ui_inst and bank_ui_inst.visible:
			if bank_ui_inst.has_method("_on_close_pressed"):
				bank_ui_inst.call("_on_close_pressed")
			else:
				bank_ui_inst.queue_free()
				if _active_player:
					_active_player.unfreeze()
			update_interaction_prompt()
			get_viewport().set_input_as_handled()
			return
			
		var npc_inspector = get_node_or_null("NPCInspectorPanel") as Control
		if not npc_inspector:
			npc_inspector = get_node_or_null("HUDControl/NPCInspectorPanel") as Control
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
			market_ui.call("close")
			get_viewport().set_input_as_handled()
			return

		if crafting_ui and crafting_ui.visible:
			crafting_ui.call("close")
			get_viewport().set_input_as_handled()
			return

		if is_instance_valid(build_window) and build_window.visible and is_instance_valid(build_window.get("levels_overlay")):
			build_window.call("_close_levels_overlay")
			get_viewport().set_input_as_handled()
			return

		if windows_container.visible:
			if pause_window.visible:
				toggle_pause_menu()
			else:
				windows_container.hide()
				for child in windows_container.get_children():
					(child as Control).hide()
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
		elif event is InputEventKey and event.keycode == KEY_F8:
			_toggle_wealth_ledger_tab()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_pause"):
			var pm = get_tree().get_first_node_in_group("PlacementManager") as Node2D
			if pm and pm.has_method("is_placement_active") and pm.call("is_placement_active"):
				if pm.has_method("_spawn_floating_text"):
					pm.call("_spawn_floating_text", "Cancel", pm.get("_active_player").global_position if pm.get("_active_player") else Vector2.ZERO)
				if pm.has_method("exit_placement_mode"):
					pm.call("exit_placement_mode")
			else:
				toggle_pause_menu()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hud_map"):
			toggle_window(map_window)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB and map_window.visible:
			if %MapGraphics and %MapGraphics.has_method("toggle_zoom"):
				%MapGraphics.call("toggle_zoom")
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U: # NPC Inspector panel
			var inspector = get_node_or_null("NPCInspectorPanel") as Control
			if inspector:
				if inspector.visible:
					inspector.hide()
				else:
					inspector.call("_populate_npc_list")
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
			if build_window.visible and is_instance_valid(build_window.get("levels_overlay")):
				get_viewport().set_input_as_handled()
				return
				
			var active_tab_container: TabContainer = null
			if build_window.visible:
				active_tab_container = build_window.get("build_tab_container") as TabContainer
			elif character_window.visible:
				active_tab_container = career_tab_container
				
			if active_tab_container:
				var offset: int = -1 if event.keycode == KEY_Q else 1
				var next_tab: int = (active_tab_container.current_tab + offset + active_tab_container.get_tab_count()) % active_tab_container.get_tab_count()
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
			(child as Control).hide()
			
	if not quest_board_ui_instance:
		quest_board_ui_instance = quest_board_ui_scene.instantiate() as PanelContainer
		windows_container.add_child(quest_board_ui_instance)
		
	quest_board_ui_instance.call("open", region_name)

func open_lawhouse_ui(province_name: String) -> void:
	if windows_container:
		windows_container.show()
		for child in windows_container.get_children():
			(child as Control).hide()
			
	if not lawhouse_ui_instance:
		lawhouse_ui_instance = lawhouse_ui_scene.instantiate() as PanelContainer
		windows_container.add_child(lawhouse_ui_instance)
		
	lawhouse_ui_instance.call("open", province_name)

func open_guild_ui(province_name: String, tab_name: String = "") -> void:
	if windows_container:
		windows_container.show()
		for child in windows_container.get_children():
			(child as Control).hide()
			
	if not is_instance_valid(guild_ui_instance):
		guild_ui_instance = PanelContainer.new()
		guild_ui_instance.set_script(preload("res://UI/guild_panel.gd"))
		windows_container.add_child(guild_ui_instance)
		
	guild_ui_instance.call("open", province_name, tab_name)

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
		title_upgrade_window.call("refresh")
	if influence_broker_window.visible and influence_broker_window.has_method("refresh"):
		influence_broker_window.call("refresh")

func update_inventory_panel() -> void:
	inventory_manager.update_inventory_panel(self, inventory_grid)

func _update_player_equipment_ui() -> void:
	inventory_manager.update_player_equipment_ui(self)

func _on_equipment_slot_pressed(slot_name: String) -> void:
	inventory_manager.on_equipment_slot_pressed(self, slot_name)

func _on_inventory_slot_interacted(item: ItemData, slot_panel: PanelContainer = null) -> void:
	inventory_manager.on_inventory_slot_interacted(self, item, slot_panel)

func _link_inventory_grid_focus() -> void:
	inventory_manager.link_inventory_grid_focus(self, inventory_grid)

func update_career_tabs() -> void:
	if not career_tab_container:
		return
		
	var char_title = get_node_or_null("Control/Control_Windows/CharacterScreen_Window/VBox/Header/Title") as Label
	if char_title and GameState:
		char_title.text = "%s's Careers & Milestones (F1)" % GameState.player_name
		
	var careers: Array[String] = ["patreon", "craftsman", "tailor", "scholar"]
	
	if career_tab_container.get_child_count() != (careers.size() + 3):
		for child in career_tab_container.get_children():
			career_tab_container.remove_child(child)
			child.queue_free()
			
		var skill_panel_scene = load("res://common/ui/skill_panel.tscn") as PackedScene
		if skill_panel_scene:
			for career in careers:
				var panel = skill_panel_scene.instantiate() as Control
				career_tab_container.add_child(panel)
				panel.call("init_skill", career, _all_recipes)
				
		# Add Wealth Ledger panel
		var ledger_panel = ScrollContainer.new()
		ledger_panel.name = "WealthLedger"
		career_tab_container.add_child(ledger_panel)
		ledger_tab_panel = ledger_panel
		
		# Add Global Modifiers panel
		var modifiers_panel = ScrollContainer.new()
		modifiers_panel.name = "GlobalModifiers"
		career_tab_container.add_child(modifiers_panel)
		modifiers_tab_panel = modifiers_panel
		
		# Add Employees Status panel
		var employees_panel = ScrollContainer.new()
		employees_panel.name = "EmployeesStatus"
		career_tab_container.add_child(employees_panel)
		employees_tab_panel = employees_panel
	else:
		if not ledger_tab_panel:
			ledger_tab_panel = career_tab_container.get_node_or_null("WealthLedger") as ScrollContainer
		if not modifiers_tab_panel:
			modifiers_tab_panel = career_tab_container.get_node_or_null("GlobalModifiers") as ScrollContainer
		if not employees_tab_panel:
			employees_tab_panel = career_tab_container.get_node_or_null("EmployeesStatus") as ScrollContainer

	character_tabs.update_career_tabs(self, ledger_tab_panel, modifiers_tab_panel, employees_tab_panel)

func _toggle_wealth_ledger_tab() -> void:
	character_tabs.toggle_wealth_ledger_tab(self)

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
		market_ui.call("open", stall)
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
		crafting_ui.call("open", bench)
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
		
	var building_ui_scene = load("res://common/ui/building_ui.tscn") as PackedScene
	if building_ui_scene:
		_building_ui_instance = building_ui_scene.instantiate() as Control
		add_child(_building_ui_instance)
		_building_ui_instance.call("open", building)
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
	var pm = get_tree().get_first_node_in_group("PlacementManager") as Node2D
	if pm and pm.has_method("exit_placement_mode"):
		pm.call("exit_placement_mode")

func _on_time_changed(hours: int, minutes: int, days: int) -> void:
	if time_label:
		var ampm = "AM" if hours < 12 else "PM"
		var display_hours = hours % 12
		if display_hours == 0:
			display_hours = 12
		time_label.text = "Day %d - %02d:%02d %s" % [days, display_hours, minutes, ampm]

func update_interaction_prompt() -> void:
	var pm = get_tree().get_first_node_in_group("PlacementManager") as Node2D
	var pm_active: bool = pm and pm.has_method("is_placement_active") and pm.call("is_placement_active")
	if not interact_prompt or not _active_player or pm_active:
		return
		
	# Check if player is currently manual crafting in any building
	var active_crafting_building: BaseProductionBuilding = null
	for building in get_tree().get_nodes_in_group("production_buildings"):
		if building is BaseProductionBuilding and building.get("is_player_working_here"):
			active_crafting_building = building
			break
			
	if active_crafting_building:
		var recipe = load(active_crafting_building.player_crafting_recipe_path)
		var item_name: String = recipe.output_item.name if recipe and recipe.get("output_item") else "Item"
		interact_label.text = "[F] Stop Crafting %s" % item_name
		interact_prompt.show()
		return
		
	var facing: Array = _active_player.get_facing_interactables()
	if facing.size() > 0:
		var interactable = facing[0] as Node2D
		var target = interactable
		var grid = _active_player._get_grid_for_crop(interactable)
		if grid:
			target = grid
			
		var text: String = ""
		if "ownership_type" in target:
			var ownership = target.get("ownership_type")
			var is_buy: bool = target.get("is_buyable") if target.get("is_buyable") != null else false
			var is_rent: bool = target.get("is_rentable") if target.get("is_rentable") != null else false
			var buy_val: int = int(target.get("buy_cost")) if target.get("buy_cost") != null else 0
			var rent_val: int = int(target.get("rent_cost")) if target.get("rent_cost") != null else 0
			
			if ownership == "NPC":
				var npc_buy_cost: int = buy_val * 3
				if is_buy:
					text = "Locked (NPC Owned) | [R] Buy (%d G)" % npc_buy_cost
				else:
					text = "Locked. Opponent property."
				var is_workshop: bool = interactable.is_in_group("Bakeries") or interactable.is_in_group("Smelters") or interactable.is_in_group("Inns") or interactable.is_in_group("Looms") or interactable.is_in_group("Mills") or interactable.is_in_group("PaperMakers") or interactable.is_in_group("PrintingPresses") or interactable.is_in_group("Banks") or interactable.is_in_group("MarketStall")
				if is_workshop and interactable.has_method("get_interaction_text"):
					var prompt_text: String = interactable.call("get_interaction_text")
					if prompt_text == "":
						text = ""
					elif "Buy" in prompt_text:
						text = "[F] %s" % prompt_text
					elif prompt_text == "Trade":
						text = "[F] Trade"
					elif prompt_text == "Locked" or "property" in prompt_text or "Opponent" in prompt_text:
						text = prompt_text
				if GameState.player_inventory.has_item("squatters_writ", 1):
					text += " | [F] Audit (Squatter's Writ)"
			elif ownership == "Player":
				var normal_text: String = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text: String = interactable.call("get_interaction_text")
					if interact_prompt_text == "":
						text = ""
					else:
						normal_text = interact_prompt_text
						text = "[F] %s (Owned)" % normal_text
				else:
					text = "[F] %s (Owned)" % normal_text
					
				var db_item = target.get("building_data") if target.get("building_data") != null else (interactable.get("building_data") if interactable.get("building_data") != null else null)
				if not db_item and GameState.has_method("get_building_data_for_node"):
					db_item = GameState.call("get_building_data_for_node", target)
					if not db_item:
						db_item = GameState.call("get_building_data_for_node", interactable)
				if db_item:
					var demolish_refund: int = int(db_item.get("cost") * 0.8) if db_item.get("cost") != null else 0
					text += " | [V] Move | [X] Demolish (%d G Refund)" % demolish_refund
			elif ownership == "Rented":
				var current_rent_days: int = int(target.get("rent_days_remaining")) if target.get("rent_days_remaining") != null else 0
				var max_rent_days: int = int(target.get("max_rent_days")) if target.get("max_rent_days") != null else 5
				var normal_text: String = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text: String = interactable.call("get_interaction_text")
					if interact_prompt_text != "":
						normal_text = interact_prompt_text
				text = "[F] %s" % normal_text
				if is_rent:
					text += " | [T] Extend (%d G, %d/%d days)" % [rent_val, current_rent_days, max_rent_days]
			else: # Public
				var normal_text: String = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text: String = interactable.call("get_interaction_text")
					if interact_prompt_text != "":
						normal_text = interact_prompt_text
				text = "[F] %s" % normal_text
				if is_buy and target.get("ownership_type") != "Public":
					text += " | [R] Buy (%d G)" % buy_val
				if is_rent:
					var max_rent_days: int = int(target.get("max_rent_days")) if target.get("max_rent_days") != null else 5
					text += " | [T] Rent (%d G/day, max %d days)" % [rent_val, max_rent_days]
		else:
			var normal_text: String = "Interact"
			if interactable.has_method("get_interaction_text"):
				var interact_prompt_text: String = interactable.call("get_interaction_text")
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
		var scene = load("res://UI/mega_node_monitor.tscn") as PackedScene
		if scene:
			mega_node_monitor_window = scene.instantiate() as PanelContainer
			mega_node_monitor_window.name = "MegaNodeMonitor_Window"
			windows_container.add_child(mega_node_monitor_window)
			
	if mega_node_monitor_window:
		mega_node_monitor_window.set("target_node", node)
		toggle_window(mega_node_monitor_window)

func open_commercial_routes_ui() -> void:
	if _commercial_route_ui_instance:
		_commercial_route_ui_instance.queue_free()
		
	var route_ui_scene = load("res://common/ui/commercial_route_panel.tscn") as PackedScene
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
		alert_ui_manager.call("open_alert_history_focusing_on", alert_id)

# Micro-animation helper tweens
func _shake_element(node: Control) -> void:
	var start_pos: Vector2 = node.position
	var tween = create_tween()
	tween.tween_property(node, "position:x", start_pos.x - 6.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x + 6.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x - 4.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x + 4.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x, 0.05)

func shake_element(node: Control) -> void:
	_shake_element(node)

func _flash_element(node: Control, flash_color: Color) -> void:
	var orig_color: Color = node.modulate
	var tween = create_tween()
	tween.tween_property(node, "modulate", flash_color, 0.1)
	tween.tween_property(node, "modulate", orig_color, 0.15)

func flash_element(node: Control, flash_color: Color) -> void:
	_flash_element(node, flash_color)

func open_rental_ui(house: Node2D) -> void:
	if not is_instance_valid(rental_window):
		rental_window = PanelContainer.new()
		rental_window.name = "RentalStatus_Window"
		windows_container.add_child(rental_window)
		
	rental_window_helper.open_rental_ui(self, house, rental_window)

func open_rogue_mission_popup(settlement: Node2D) -> void:
	if not is_instance_valid(settlement):
		return
		
	var was_visible = false
	if is_instance_valid(rogue_mission_window):
		was_visible = rogue_mission_window.visible
		
	if not is_instance_valid(rogue_mission_window):
		rogue_mission_window = PanelContainer.new()
		rogue_mission_window.name = "RogueMission_Window"
		windows_container.add_child(rogue_mission_window)
		
	_rebuild_rogue_mission_window(settlement)
	
	if not was_visible:
		toggle_window(rogue_mission_window)
	else:
		rogue_mission_window.pivot_offset = rogue_mission_window.size / 2.0

func _rebuild_rogue_mission_window(settlement: Node2D) -> void:
	# Clear previous children
	for child in rogue_mission_window.get_children():
		rogue_mission_window.remove_child(child)
		child.queue_free()
		
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.border_color = Color(0.85, 0.3, 0.3, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	rogue_mission_window.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	rogue_mission_window.add_child(vbox)
	
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	var s_name = settlement.get("city_name") if "city_name" in settlement else settlement.get("town_name")
	if s_name == null or str(s_name) == "":
		s_name = settlement.name
	title.text = "Rogue Espionage Operations: %s" % s_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = " X "
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func():
		toggle_window(rogue_mission_window)
	)
	header.add_child(close_btn)
	_setup_button_hover(close_btn)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var info_panel = PanelContainer.new()
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	info_style.set_corner_radius_all(6)
	info_style.content_margin_left = 12
	info_style.content_margin_right = 12
	info_style.content_margin_top = 10
	info_style.content_margin_bottom = 10
	info_panel.add_theme_stylebox_override("panel", info_style)
	vbox.add_child(info_panel)
	
	var info_grid = GridContainer.new()
	info_grid.columns = 3
	info_grid.add_theme_constant_override("h_separation", 20)
	info_grid.add_theme_constant_override("v_separation", 8)
	info_panel.add_child(info_grid)
	
	var w = settlement.get("wealth_level") if "wealth_level" in settlement else 0.5
	var sec = settlement.get("security_level") if "security_level" in settlement else 0.8
	var h = settlement.get("criminal_heat") if "criminal_heat" in settlement else 0.0
	
	var w_label = Label.new()
	w_label.text = "Wealth Level: %.2f" % w
	w_label.add_theme_font_size_override("font_size", 12)
	w_label.modulate = Color(0.9, 0.85, 0.4)
	info_grid.add_child(w_label)
	
	var sec_label = Label.new()
	sec_label.text = "Security Level: %.2f" % sec
	sec_label.add_theme_font_size_override("font_size", 12)
	sec_label.modulate = Color(0.4, 0.7, 0.9)
	info_grid.add_child(sec_label)
	
	var h_label = Label.new()
	h_label.text = "Criminal Heat: %.2f" % h
	h_label.add_theme_font_size_override("font_size", 12)
	h_label.modulate = Color(0.9, 0.4, 0.4)
	info_grid.add_child(h_label)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 300)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var emp_vbox = VBoxContainer.new()
	emp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emp_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(emp_vbox)
	
	var all_hired: Array = []
	for b in get_tree().get_nodes_in_group("production_buildings"):
		if is_instance_valid(b) and "hired_employees" in b:
			var is_player_building: bool = false
			if "ownership_type" in b:
				if b.ownership_type == "Player" or b.ownership_type == "Rented":
					is_player_building = true
			if is_player_building:
				for emp in b.hired_employees:
					var npc = emp.get("npc_ref") as Node
					if is_instance_valid(npc):
						all_hired.append({
							"emp_dict": emp,
							"npc": npc,
							"building": b
						})
						
	if all_hired.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "You have no active employees hired.\nRecruit employees at your workshops first."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		emp_vbox.add_child(empty_lbl)
		return
		
	for item in all_hired:
		var emp_dict: Dictionary = item["emp_dict"]
		var npc = item["npc"]
		var building = item["building"]
		
		var emp_panel = PanelContainer.new()
		var emp_style = StyleBoxFlat.new()
		emp_style.bg_color = Color(0.14, 0.15, 0.2, 0.8)
		emp_style.border_color = Color(0.24, 0.52, 0.85, 0.2)
		emp_style.set_border_width_all(1)
		emp_style.set_corner_radius_all(8)
		emp_style.content_margin_left = 12
		emp_style.content_margin_right = 12
		emp_style.content_margin_top = 10
		emp_style.content_margin_bottom = 10
		emp_panel.add_theme_stylebox_override("panel", emp_style)
		emp_vbox.add_child(emp_panel)
		
		var emp_hbox = HBoxContainer.new()
		emp_hbox.add_theme_constant_override("separation", 15)
		emp_panel.add_child(emp_hbox)
		
		var name_vbox = VBoxContainer.new()
		name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		emp_hbox.add_child(name_vbox)
		
		var name_lbl = Label.new()
		name_lbl.text = npc.get("npc_name") if npc.get("npc_name") != null else npc.name
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		name_vbox.add_child(name_lbl)
		
		var career_lbl = Label.new()
		var display_career: String = String(npc.get("career")).capitalize()
		var max_lvl: int = npc.get("skills_data").get(npc.get("career"), {}).get("level", 1) if npc.get("skills_data") != null else 1
		career_lbl.text = "Lvl %d %s (@ %s)" % [max_lvl, display_career, building.name]
		career_lbl.add_theme_font_size_override("font_size", 10)
		career_lbl.modulate = Color(0.24, 0.6, 0.86)
		name_vbox.add_child(career_lbl)
		
		var eq = npc.get_node_or_null("EquipmentComponent")
		var has_cudgel = false
		if eq:
			var weapon_item = eq.call("get_equipped_item", "weapon")
			if weapon_item and weapon_item.id == "street_cudgel":
				has_cudgel = true
				
		var eq_label = Label.new()
		if has_cudgel:
			eq_label.text = "Cudgel: Equipped"
			eq_label.modulate = Color(0.3, 0.9, 0.3)
		else:
			eq_label.text = "Cudgel: None"
			eq_label.modulate = Color(0.9, 0.3, 0.3)
		eq_label.add_theme_font_size_override("font_size", 10)
		name_vbox.add_child(eq_label)
		
		var status_lbl = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 10)
		name_vbox.add_child(status_lbl)
		
		var is_jailed = emp_dict.get("is_arrested") == true
		var is_busy = false
		
		if is_jailed:
			var hours_left = emp_dict.get("arrest_timer", 0.0)
			status_lbl.text = "Status: Jailed (%.1fh left)" % hours_left
			status_lbl.modulate = Color(0.9, 0.3, 0.3)
			is_busy = true
		elif npc.worker_state == "traveling_to_pickpocket" or npc.worker_state == "pickpocketing":
			status_lbl.text = "Status: Pickpocketing"
			status_lbl.modulate = Color(0.95, 0.85, 0.4)
			is_busy = true
		elif emp_dict.get("active_recipe_path") != "":
			status_lbl.text = "Status: Busy Crafting"
			status_lbl.modulate = Color(0.5, 0.75, 1.0)
			is_busy = true
		elif emp_dict.get("active_gathering_node_path") != "" and emp_dict.get("active_gathering_node_path") != null:
			status_lbl.text = "Status: Busy Gathering"
			status_lbl.modulate = Color(0.5, 0.75, 1.0)
			is_busy = true
		elif emp_dict.get("active_commercial_route") != null:
			status_lbl.text = "Status: Logistics Route"
			status_lbl.modulate = Color(0.5, 0.75, 1.0)
			is_busy = true
		else:
			status_lbl.text = "Status: Idle"
			status_lbl.modulate = Color(0.6, 0.6, 0.6)
			
		var action_vbox = VBoxContainer.new()
		emp_hbox.add_child(action_vbox)
		
		var dispatch_btn = Button.new()
		dispatch_btn.text = "Dispatch"
		dispatch_btn.focus_mode = Control.FOCUS_NONE
		dispatch_btn.disabled = is_busy
		action_vbox.add_child(dispatch_btn)
		_setup_button_hover(dispatch_btn)
		
		dispatch_btn.pressed.connect(func():
			npc.set_meta("target_settlement", settlement)
			npc.worker_state = "traveling_to_pickpocket"
			if GameState:
				GameState.spawn_ui_floating_text("Dispatched %s!" % name_lbl.text)
			_rebuild_rogue_mission_window(settlement)
		)
		
		if npc.worker_state == "traveling_to_pickpocket" or npc.worker_state == "pickpocketing":
			var recall_btn = Button.new()
			recall_btn.text = "Recall"
			recall_btn.focus_mode = Control.FOCUS_NONE
			action_vbox.add_child(recall_btn)
			_setup_button_hover(recall_btn)
			
			recall_btn.pressed.connect(func():
				npc.worker_state = "traveling_to_workshop"
				if GameState:
					GameState.spawn_ui_floating_text("Recalled %s!" % name_lbl.text)
				_rebuild_rogue_mission_window(settlement)
			)

func show_squatters_writ_confirmation(target_workshop: Node2D) -> void:
	if not is_instance_valid(target_workshop):
		return
		
	var confirm = ConfirmationDialog.new()
	confirm.title = "Execute Squatter's Writ"
	confirm.dialog_text = "Are you sure you want to shut down this competitor workshop and all its related stalls for 48.0 hours using a Squatter's Writ?"
	confirm.ok_button_text = "Confirm Shutdown"
	confirm.cancel_button_text = "Cancel"
	
	add_child(confirm)
	confirm.popup_centered()
	
	if _active_player:
		_active_player.freeze()
		
	confirm.confirmed.connect(func():
		if GameState.player_inventory.has_item("squatters_writ", 1):
			GameState.player_inventory.remove_item("squatters_writ", 1)
			
			var target = target_workshop
			if "parent_building" in target and is_instance_valid(target.parent_building):
				target = target.parent_building
				
			target.set("is_under_audit", true)
			target.set("audit_timer", 48.0)
			
			if target.has_method("reset_all_workers"):
				target.call("reset_all_workers")
			if "inventory" in target and target.inventory:
				target.inventory.call("clear_inventory")
				
			for stall in get_tree().get_nodes_in_group("MarketStall"):
				if is_instance_valid(stall) and (stall == target or stall.get("parent_building") == target):
					stall.is_under_audit = true
					if "inventory" in stall and stall.inventory:
						stall.inventory.call("clear_inventory")
						
			AlertManager.add_alert(
				"Competitor Audited",
				"Competitor workshop %s has been shut down for 48 hours under a Squatter's Writ!" % target.name,
				"warning",
				target
			)
			if GameState:
				GameState.spawn_ui_floating_text("Squatter's Writ executed!")
		else:
			if GameState:
				GameState.spawn_ui_floating_text("No Squatter's Writ in inventory!")
		
		if _active_player:
			_active_player.unfreeze()
		confirm.queue_free()
	)
	
	confirm.canceled.connect(func():
		if _active_player:
			_active_player.unfreeze()
		confirm.queue_free()
	)

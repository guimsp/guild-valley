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


# Shortcut buttons
@onready var button_f1: Button = %Button_F1
@onready var button_f2: Button = %Button_F2
@onready var button_f3: Button = %Button_F3
@onready var button_f4: Button = %Button_F4
@onready var button_f5: Button = %Button_F5
@onready var button_f6: Button = %Button_F6
@onready var button_f10: Button = %Button_F10

# TitleUpgrade elements
@onready var titles_list_container: VBoxContainer = %TitlesList
@onready var selected_title_name_label: Label = %SelectedTitleName
@onready var selected_title_desc_label: Label = %SelectedTitleDesc
@onready var title_upgrade_cost_label: Label = %TitleUpgradeCostLabel
@onready var upgrade_title_button: Button = %UpgradeTitleButton

# InfluenceBroker elements
@onready var broker_gold_label: Label = %BrokerGoldLabel
@onready var broker_influence_label: Label = %BrokerInfluenceLabel
@onready var exchange_button: Button = %ExchangeButton

# Overlay elements
@onready var interact_prompt: PanelContainer = %InteractPrompt
@onready var interact_label: Label = %InteractLabel
@onready var market_ui: Control = %MarketUI
@onready var crafting_ui: Control = %CraftingUI

# Inner layouts
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var career_tab_container: TabContainer = %CareerTabContainer
@onready var build_tab_container: TabContainer = %BuildTabContainer
@onready var home_tab_list: VBoxContainer = %HomeTabList
@onready var business_tab_list: VBoxContainer = %BusinessTabList

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

# Business list & Opponents list outlets
@onready var business_scroll_list: VBoxContainer = %BusinessScrollList
@onready var opponents_scroll_list: VBoxContainer = %OpponentsScrollList

# Pause Menu overlay reference for GameState compatibility
var pause_menu: Control:
	get: return pause_window

var _active_player: Player = null
var _all_recipes: Array = []
var _building_ui_instance: Control = null
var _filter_only_buildable: bool = false
var _commercial_route_ui_instance: Control = null

var alert_history_window: PanelContainer = null
var alert_cards_vbox: VBoxContainer = null

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
	
	# Create Alert Card and History containers dynamically
	_create_alert_containers()
	
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
	save_btn.pressed.connect(func(): GameState.save_game())
	load_btn.pressed.connect(func(): GameState.load_game())
	quit_btn.pressed.connect(func(): get_tree().quit())
	
	# Wire up Title & Influence Broker buttons
	if upgrade_title_button:
		upgrade_title_button.pressed.connect(_on_upgrade_title_pressed)
		_setup_button_hover(upgrade_title_button)
	if exchange_button:
		exchange_button.pressed.connect(_on_exchange_influence_pressed)
		_setup_button_hover(exchange_button)
	
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
			)
			_setup_button_hover(btn)
	
	# Initialize tab containers focus modes
	if build_tab_container:
		build_tab_container.focus_mode = Control.FOCUS_NONE
		build_tab_container.tab_changed.connect(func(_tab_idx):
			_focus_first_card_in_active_tab()
		)
	if career_tab_container:
		career_tab_container.focus_mode = Control.FOCUS_NONE
		
	# Update values initially
	update_hud_values()
	
	# Connect GameState and inventory signals
	if GameState.player_inventory:
		GameState.player_inventory.inventory_changed.connect(update_inventory_panel)
		
	GameState.time_changed.connect(_on_time_changed)
	_on_time_changed(GameState.time_hours, int(GameState.time_minutes), GameState.time_days)
	
	# Connect alerts signals and initialize existing active alerts
	GameState.alert_added.connect(_on_alert_added)
	GameState.alert_removed.connect(_on_alert_removed)
	for alert in GameState.active_alerts:
		_on_alert_added(alert)
		
	# Connect to QuestManager to auto-refresh the ledger if open
	if QuestManager:
		QuestManager.quests_updated.connect(func():
			if business_window and business_window.visible:
				populate_business_ledger()
		)

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
	# If placement mode is active, do not allow menu toggle except pause menu
	var pm = get_tree().get_first_node_in_group("PlacementManager")
	var pm_active = pm and pm.is_placement_active()
	if pm_active and window != pause_window:
		return

	if window.visible:
		# Close window
		window.hide()
		windows_container.hide()
		get_tree().paused = false
		if _active_player:
			_active_player.unfreeze()
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
		if window == character_window:
			update_career_tabs()
		elif window == inventory_window:
			update_inventory_panel()
		elif window == build_window:
			refresh_build_menu()
		elif window == business_window:
			populate_business_ledger()
		elif window == opponents_window:
			populate_opponents_list()
		elif window == title_upgrade_window:
			update_title_upgrade_window()
		elif window == influence_broker_window:
			update_influence_broker_window()
		elif window == alert_history_window:
			populate_alert_history()
			
		# Sync Keyboard Focus
		call_deferred("_grab_focus_on_first_element", window)

func _grab_focus_on_first_element(window: Control) -> void:
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
				
		# Sub-Tabs swapping in build panel or careers (Q/E)
		elif event.keycode == KEY_Q or event.keycode == KEY_E:
			var active_tab_container: TabContainer = null
			if build_window.visible:
				active_tab_container = build_tab_container
			elif character_window.visible:
				active_tab_container = career_tab_container
				
			if active_tab_container:
				var offset = -1 if event.keycode == KEY_Q else 1
				var next_tab = (active_tab_container.current_tab + offset + active_tab_container.get_tab_count()) % active_tab_container.get_tab_count()
				active_tab_container.current_tab = next_tab
				get_viewport().set_input_as_handled()
				
		elif event.keycode == KEY_TAB and build_window.visible:
			_filter_only_buildable = not _filter_only_buildable
			refresh_build_menu()
			_update_build_menu_title()
			_focus_first_card_in_active_tab()
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

	# Handle UI close via cancel/escape
	if event.is_action_pressed("ui_cancel"):
		var pm = get_tree().get_first_node_in_group("PlacementManager")
		var pm_active = pm and pm.is_placement_active()
		if pm_active:
			return
			
		# 0. Dialogue Bubble
		var dialogue_bubbles = get_tree().get_nodes_in_group("DialogueBubble")
		if dialogue_bubbles.size() > 0:
			for bubble in dialogue_bubbles:
				if is_instance_valid(bubble) and bubble.visible:
					bubble._on_close_pressed()
			get_viewport().set_input_as_handled()
			return

		# 0.5. Relationship UI
		var rel_ui = get_tree().get_first_node_in_group("RelationshipUI")
		if rel_ui and rel_ui.visible:
			rel_ui._on_close_pressed()
			get_viewport().set_input_as_handled()
			return
			
		# 1. Bank UI
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
			
		# 2. NPC Inspector Panel
		var npc_inspector = get_node_or_null("NPCInspectorPanel")
		if not npc_inspector:
			npc_inspector = get_node_or_null("HUDControl/NPCInspectorPanel")
		if npc_inspector and npc_inspector.visible:
			npc_inspector.hide()
			get_viewport().set_input_as_handled()
			return
			
		# 3. Building UI (e.g. inspector of built properties/stalls)
		if _building_ui_instance and _building_ui_instance.visible:
			close_building_ui()
			get_viewport().set_input_as_handled()
			return

		# 4. Commercial Route Panel (Trade console)
		if _commercial_route_ui_instance and _commercial_route_ui_instance.visible:
			if not _commercial_route_ui_instance.get("popup") and not _commercial_route_ui_instance.get("employee_popup"):
				close_commercial_routes_ui()
				get_viewport().set_input_as_handled()
				return

		# 5. Market UI
		if market_ui and market_ui.visible:
			market_ui.close()
			get_viewport().set_input_as_handled()
			return

		# 6. Crafting UI
		if crafting_ui and crafting_ui.visible:
			crafting_ui.close()
			get_viewport().set_input_as_handled()
			return

		# 7. General Windows Container (Character, Inventory, Build, Business, Opponents, Map)
		if windows_container.visible:
			# If pause window is visible, calling toggle_pause_menu will unpause
			if pause_window.visible:
				toggle_pause_menu()
			else:
				windows_container.hide()
				for child in windows_container.get_children():
					child.hide()
				if _active_player:
					_active_player.unfreeze()
			get_viewport().set_input_as_handled()
			return

		# 8. Otherwise, toggle pause menu
		toggle_pause_menu()
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

# ----------------- BACKWARD COMPATIBLE & DYNAMIC LOOPS -----------------

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
	if title_upgrade_window.visible:
		_refresh_title_details()
	if influence_broker_window.visible:
		update_influence_broker_window()

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
				refresh_build_menu()
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

func _update_build_menu_title() -> void:
	var title_lbl = %BuildTitle
	if title_lbl:
		if _filter_only_buildable:
			title_lbl.text = "Construction Menu (Filter: Buildable - [Tab] to toggle)"
		else:
			title_lbl.text = "Construction Menu (Filter: All - [Tab] to toggle)"

func refresh_build_menu() -> void:
	_populate_personal_home_tab()
	_populate_business_tab()

func _create_vertical_connector() -> Control:
	var container = CenterContainer.new()
	container.custom_minimum_size = Vector2(0, 12)
	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(4, 12)
	line.color = Color(0.24, 0.65, 0.44, 0.6) # Sleek green/teal connector
	container.add_child(line)
	return container

func _populate_personal_home_tab() -> void:
	if not home_tab_list:
		return
		
	for child in home_tab_list.get_children():
		child.queue_free()
		
	var home_items = []
	for item in GameState.build_database:
		if item.family == "personal_home":
			if not _filter_only_buildable or _is_building_buildable(item):
				home_items.append(item)
			
	home_items.sort_custom(func(a, b):
		return a.building_level < b.building_level
	)
	
	var col_cards = []
	for i in range(home_items.size()):
		if i > 0:
			home_tab_list.add_child(_create_vertical_connector())
		var card = _create_building_card(home_items[i])
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		home_tab_list.add_child(card)
		col_cards.append(card)
		
	if not col_cards.is_empty():
		_link_tab_focus_neighbors([[col_cards]])

func _populate_business_tab() -> void:
	if not business_tab_list:
		return
		
	for child in business_tab_list.get_children():
		child.queue_free()
		
	var careers = ["patreon", "craftsman", "tailor", "scholar"]
	var tab_sections = []
	
	for career_name in careers:
		var section_items = []
		for item in GameState.build_database:
			if item.career == career_name:
				if not _filter_only_buildable or _is_building_buildable(item):
					section_items.append(item)
					
		if section_items.is_empty():
			continue
			
		var section_title = Label.new()
		section_title.text = career_name.capitalize() + " Profession"
		section_title.add_theme_font_size_override("font_size", 14)
		section_title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
		section_title.add_theme_constant_override("outline_size", 2)
		section_title.add_theme_color_override("font_outline_color", Color.BLACK)
		
		var title_margin = MarginContainer.new()
		title_margin.add_theme_constant_override("margin_top", 12)
		title_margin.add_theme_constant_override("margin_bottom", 6)
		title_margin.add_child(section_title)
		business_tab_list.add_child(title_margin)
		
		var families = []
		var family_names = []
		for item in section_items:
			var fam = item.family
			if not (fam in family_names):
				family_names.append(fam)
				families.append({
					"name": fam,
					"tier": item.tier
				})
					
		families.sort_custom(func(a, b):
			return a["tier"] < b["tier"]
		)
		
		var max_levels = 0
		var family_data = {}
		for fam_info in families:
			var fam_name = fam_info["name"]
			var fam_items = []
			for item in section_items:
				if item.family == fam_name:
					fam_items.append(item)
			fam_items.sort_custom(func(a, b):
				return a.building_level < b.building_level
			)
			family_data[fam_name] = fam_items
			if fam_items.size() > max_levels:
				max_levels = fam_items.size()
		
		var scroll = ScrollContainer.new()
		var scroll_height = 110 + (max_levels - 1) * 110 if max_levels > 0 else 110
		scroll.custom_minimum_size = Vector2(0, scroll_height)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		
		var columns_hbox = HBoxContainer.new()
		columns_hbox.add_theme_constant_override("separation", 16)
		columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(columns_hbox)
		
		business_tab_list.add_child(scroll)
		
		var section_cols = []
		for fam_info in families:
			var fam_name = fam_info["name"]
			var col_vbox = VBoxContainer.new()
			col_vbox.custom_minimum_size = Vector2(170, 0)
			col_vbox.add_theme_constant_override("separation", 4)
			columns_hbox.add_child(col_vbox)
			
			var fam_items = family_data[fam_name]
			var col_cards = []
			for i in range(fam_items.size()):
				if i > 0:
					col_vbox.add_child(_create_vertical_connector())
				var card = _create_building_card(fam_items[i])
				col_vbox.add_child(card)
				col_cards.append(card)
			section_cols.append(col_cards)
		tab_sections.append(section_cols)
		
	_link_tab_focus_neighbors(tab_sections)

func _is_building_buildable(building: BuildingData) -> bool:
	var career = building.career
	var req_lvl = building.level
	var player_lvl = 1
	if career != "":
		player_lvl = GameState.career_levels.get(career, 1)
	var is_level_locked = player_lvl < req_lvl
	var is_gold_locked = GameState.gold < building.cost
	var is_locked_placeholder = building.scene_path == ""
	var is_title_locked = building.tier > GameState.title_level
	return not is_level_locked and not is_gold_locked and not is_locked_placeholder and not is_title_locked

func _create_building_card(building: BuildingData) -> PanelContainer:
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
	card.custom_minimum_size = Vector2(170, 85)
	card.focus_mode = Control.FOCUS_ALL
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
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
	
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 8)
	card.add_child(main_hbox)
	
	var initials = ""
	var words = building.name.split(" ")
	for word in words:
		if word.length() > 0:
			initials += word[0].to_upper()
	if initials.length() > 3:
		initials = initials.substr(0, 3)
		
	var icon_container = PanelContainer.new()
	icon_container.custom_minimum_size = Vector2(32, 32)
	icon_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
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
	icon_label.add_theme_font_size_override("font_size", 10)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_label.add_theme_constant_override("outline_size", 2)
	icon_label.add_theme_color_override("font_outline_color", Color.BLACK)
	icon_container.add_child(icon_label)
	main_hbox.add_child(icon_container)
	
	var details_vbox = VBoxContainer.new()
	details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_vbox.add_theme_constant_override("separation", 2)
	main_hbox.add_child(details_vbox)
	
	var title_lbl = Label.new()
	var title_text = building.name
	if building.building_level > 1 and not ("Lv." in title_text):
		title_text += " Lv. %d" % building.building_level
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", 11)
	if is_disabled:
		title_lbl.modulate = Color(0.5, 0.5, 0.5, 0.8)
	else:
		title_lbl.modulate = Color(0.9, 0.95, 0.9, 1)
	details_vbox.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = building.description
	desc_lbl.add_theme_font_size_override("font_size", 8)
	desc_lbl.modulate = Color(0.65, 0.65, 0.7, 0.8)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.max_lines_visible = 2
	details_vbox.add_child(desc_lbl)
	
	var info_lbl = Label.new()
	info_lbl.add_theme_font_size_override("font_size", 8)
	if is_locked_placeholder:
		info_lbl.text = "T%d Coming Soon" % building.tier
		info_lbl.modulate = Color(0.6, 0.6, 0.6, 0.8)
	elif is_title_locked:
		var title_name = GameState.get_title_name(building.tier)
		info_lbl.text = "Requires Title: %s" % title_name
		info_lbl.modulate = Color(0.9, 0.35, 0.35, 1)
	elif is_level_locked:
		info_lbl.text = "Req. %s Lv. %d" % [career.capitalize(), req_lvl]
		info_lbl.modulate = Color(0.9, 0.35, 0.35, 1)
	else:
		info_lbl.text = "%d G | %.1fs" % [building.cost, building.time]
		if is_gold_locked:
			info_lbl.modulate = Color(0.9, 0.45, 0.45, 0.9)
		else:
			info_lbl.modulate = Color(0.85, 0.85, 0.4, 0.9)
	details_vbox.add_child(info_lbl)
	
	card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
	
	# Setup card scaling tweens on hover/focus
	card.focus_entered.connect(func():
		var bright = style.duplicate() as StyleBoxFlat
		bright.border_color = border_color.lightened(0.3)
		bright.bg_color = base_color.lightened(0.1)
		card.add_theme_stylebox_override("panel", bright)
		card.pivot_offset = card.size / 2.0
		_animate_scale(card, 1.03)
	)
	card.focus_exited.connect(func():
		card.add_theme_stylebox_override("panel", style)
		_animate_scale(card, 1.0)
	)
	card.mouse_entered.connect(func():
		if not is_disabled:
			var bright = style.duplicate() as StyleBoxFlat
			bright.border_color = border_color.lightened(0.3)
			bright.bg_color = base_color.lightened(0.1)
			card.add_theme_stylebox_override("panel", bright)
			card.pivot_offset = card.size / 2.0
			_animate_scale(card, 1.03)
	)
	card.mouse_exited.connect(func():
		if not is_disabled:
			card.add_theme_stylebox_override("panel", style)
			_animate_scale(card, 1.0)
	)
	
	card.gui_input.connect(func(event: InputEvent):
		var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		var is_accept = event.is_action_pressed("ui_accept")
		if is_click or is_accept:
			card.get_viewport().set_input_as_handled()
			if is_disabled:
				_shake_node(card)
				if is_title_locked:
					var title_name = GameState.get_title_name(building.tier)
					_spawn_floating_text("Requires Title: %s" % title_name, card.global_position + card.size / 2.0)
				else:
					_spawn_floating_text("Locked!", card.global_position + card.size / 2.0)
				return
			if is_gold_locked:
				_shake_node(card)
				_spawn_floating_text("Need Gold!", card.global_position + card.size / 2.0)
				return
				
			# Click animation before triggering build action
			var click_tween = card.create_tween()
			click_tween.tween_property(card, "scale", Vector2(0.96, 0.96), 0.05)
			click_tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.05)
			await click_tween.finished
			
			windows_container.hide()
			build_window.hide()
			if _active_player:
				_active_player.unfreeze()
			build_requested.emit(building)
	)
	
	return card

func _shake_node(node: Control) -> void:
	var baseline_x = node.position.x
	var tween = node.create_tween()
	tween.tween_property(node, "position:x", baseline_x - 5, 0.05)
	tween.tween_property(node, "position:x", baseline_x + 5, 0.05)
	tween.tween_property(node, "position:x", baseline_x - 3, 0.05)
	tween.tween_property(node, "position:x", baseline_x, 0.05)

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

func _link_tab_focus_neighbors(tab_sections: Array) -> void:
	for s_idx in range(tab_sections.size()):
		var cols = tab_sections[s_idx]
		for c_idx in range(cols.size()):
			var cards = cols[c_idx]
			for l_idx in range(cards.size()):
				var card = cards[l_idx]
				
				# Connect Left/Right
				if c_idx > 0:
					var prev_col = cols[c_idx - 1]
					var target_l = min(l_idx, prev_col.size() - 1)
					card.focus_neighbor_left = prev_col[target_l].get_path()
				else:
					card.focus_neighbor_left = card.get_path()
					
				if c_idx < cols.size() - 1:
					var next_col = cols[c_idx + 1]
					var target_l = min(l_idx, next_col.size() - 1)
					card.focus_neighbor_right = next_col[target_l].get_path()
				else:
					card.focus_neighbor_right = card.get_path()
				
				# Connect Up/Down
				if l_idx > 0:
					card.focus_neighbor_top = cards[l_idx - 1].get_path()
				else:
					if s_idx > 0:
						var prev_section_cols = tab_sections[s_idx - 1]
						var target_c = min(c_idx, prev_section_cols.size() - 1)
						var target_prev_col = prev_section_cols[target_c]
						card.focus_neighbor_top = target_prev_col[target_prev_col.size() - 1].get_path()
					else:
						card.focus_neighbor_top = card.get_path()
							
				if l_idx < cards.size() - 1:
					card.focus_neighbor_bottom = cards[l_idx + 1].get_path()
				else:
					if s_idx < tab_sections.size() - 1:
						var next_section_cols = tab_sections[s_idx + 1]
						var target_c = min(c_idx, next_section_cols.size() - 1)
						var target_next_col = next_section_cols[target_c]
						card.focus_neighbor_bottom = target_next_col[0].get_path()
					else:
						card.focus_neighbor_bottom = card.get_path()
				
				if not card.focus_entered.is_connected(_on_card_focused.bind(card)):
					card.focus_entered.connect(_on_card_focused.bind(card))

func _on_card_focused(card: Control) -> void:
	var main_scroll = _find_main_scroll_container(card)
	if main_scroll:
		_ensure_card_visible(card, main_scroll)

func _find_main_scroll_container(card: Control) -> ScrollContainer:
	var p = card.get_parent()
	while p:
		if p is ScrollContainer and p.get_parent().get_parent() == build_tab_container:
			return p
		p = p.get_parent()
	return null

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

# ----------------- BUSINESS LEDGER & RIVALS -----------------

func populate_business_ledger() -> void:
	if not business_scroll_list:
		return
		
	# Clear previous contents
	for child in business_scroll_list.get_children():
		child.queue_free()
		
	# 1. Businesses Section Title
	var biz_section_title = Label.new()
	biz_section_title.text = "Owned Businesses & Real Estate"
	biz_section_title.add_theme_font_size_override("font_size", 13)
	biz_section_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	biz_section_title.add_theme_constant_override("outline_size", 2)
	biz_section_title.add_theme_color_override("font_outline_color", Color.BLACK)
	business_scroll_list.add_child(biz_section_title)
	
	var groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Houses"]
	var player_owned: Array[Node2D] = []
	
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node) and node.get("ownership_type") == "Player":
				player_owned.append(node)
				
	if player_owned.is_empty():
		var label = Label.new()
		label.text = "  No owned businesses or real estate yet."
		label.add_theme_font_size_override("font_size", 11)
		label.modulate = Color(0.6, 0.6, 0.6, 0.8)
		business_scroll_list.add_child(label)
	else:
		# Group by Province and Settlement
		var hierarchy = {}
		for biz in player_owned:
			var settlement = GameState.get_nearest_settlement(biz)
			var prov_name = GameState.get_province_of_node(biz)
			var sett_name = "Rural Lot"
			
			if settlement:
				if settlement is City:
					sett_name = settlement.city_name
				elif settlement is Town:
					sett_name = settlement.town_name
					
			if not hierarchy.has(prov_name):
				hierarchy[prov_name] = {}
			if not hierarchy[prov_name].has(sett_name):
				hierarchy[prov_name][sett_name] = []
				
			hierarchy[prov_name][sett_name].append(biz)
			
		for prov in hierarchy:
			var prov_label = Label.new()
			prov_label.text = "  " + prov
			prov_label.add_theme_font_size_override("font_size", 12)
			prov_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.15))
			business_scroll_list.add_child(prov_label)
			
			for sett in hierarchy[prov]:
				var sett_box = VBoxContainer.new()
				sett_box.add_theme_constant_override("separation", 4)
				sett_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				business_scroll_list.add_child(sett_box)
				
				var sett_label = Label.new()
				sett_label.text = "    └─ " + sett
				sett_label.add_theme_font_size_override("font_size", 11)
				sett_label.add_theme_color_override("font_color", Color(0.25, 0.7, 0.8))
				sett_box.add_child(sett_label)
				
				for biz in hierarchy[prov][sett]:
					var card = PanelContainer.new()
					card.custom_minimum_size = Vector2(0, 36)
					
					var style = StyleBoxFlat.new()
					style.bg_color = Color(0.14, 0.15, 0.2, 0.6)
					style.set_corner_radius_all(4)
					style.content_margin_left = 16
					style.content_margin_right = 16
					card.add_theme_stylebox_override("panel", style)
					
					var hbox = HBoxContainer.new()
					card.add_child(hbox)
					
					var name_lbl = Label.new()
					name_lbl.text = biz.name
					if "building_name" in biz and biz.building_name != "":
						name_lbl.text = biz.building_name
					name_lbl.add_theme_font_size_override("font_size", 11)
					name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					hbox.add_child(name_lbl)
					
					var strongbox = biz.get_node_or_null("StrongboxComponent")
					var strongbox_txt = ""
					if strongbox:
						strongbox_txt = " (Vault: %d G)" % strongbox.strongbox_gold
					
					var status_lbl = Label.new()
					status_lbl.add_theme_font_size_override("font_size", 10)
					status_lbl.modulate = Color(0.4, 0.9, 0.4)
					
					if "hired_employees" in biz:
						status_lbl.text = ("Employees Hired: %d" % biz.hired_employees.size()) + strongbox_txt
					elif "is_occupied" in biz:
						status_lbl.text = "Occupied (Rent: %d G)" % biz.rent_cost if biz.is_occupied else "Vacant (Rental)"
					else:
						status_lbl.text = "Operational" + strongbox_txt
						
					hbox.add_child(status_lbl)
					sett_box.add_child(card)
					
					# Render Ledger History under the business
					if strongbox and strongbox.transaction_ledger.size() > 0:
						var ledger_vbox = VBoxContainer.new()
						ledger_vbox.add_theme_constant_override("separation", 2)
						
						var indent_margin = MarginContainer.new()
						indent_margin.add_theme_constant_override("margin_left", 24)
						indent_margin.add_theme_constant_override("margin_top", 2)
						indent_margin.add_theme_constant_override("margin_bottom", 6)
						indent_margin.add_child(ledger_vbox)
						
						# Only show last 5 transactions
						var start_idx = max(0, strongbox.transaction_ledger.size() - 5)
						for t_idx in range(start_idx, strongbox.transaction_ledger.size()):
							var entry = strongbox.transaction_ledger[t_idx]
							var t_lbl = Label.new()
							t_lbl.text = "• Sold %d %s for %d G (%s)" % [entry["amount"], entry["item_name"], entry["price"], entry["timestamp"]]
							t_lbl.add_theme_font_size_override("font_size", 9)
							t_lbl.modulate = Color(0.7, 0.7, 0.75, 0.8)
							ledger_vbox.add_child(t_lbl)
							
						sett_box.add_child(indent_margin)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	business_scroll_list.add_child(spacer)
	
	# 2. Active Quests Section Title
	var quests_section_title = Label.new()
	quests_section_title.text = "Active Quests"
	quests_section_title.add_theme_font_size_override("font_size", 13)
	quests_section_title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.5))
	quests_section_title.add_theme_constant_override("outline_size", 2)
	quests_section_title.add_theme_color_override("font_outline_color", Color.BLACK)
	business_scroll_list.add_child(quests_section_title)
	
	if QuestManager.accepted_quests.is_empty():
		var label = Label.new()
		label.text = "  No active quests."
		label.add_theme_font_size_override("font_size", 11)
		label.modulate = Color(0.6, 0.6, 0.6, 0.8)
		business_scroll_list.add_child(label)
	else:
		# Draw each accepted quest
		for quest in QuestManager.accepted_quests:
			var card = PanelContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.08, 0.14, 0.18, 0.75) # Deep teal tint for quests
			style.border_color = Color(0.15, 0.5, 0.4, 0.6) # Sleek teal/green border
			style.border_width_left = 2
			style.set_corner_radius_all(4)
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			card.add_theme_stylebox_override("panel", style)
			
			var main_vbox_q = VBoxContainer.new()
			main_vbox_q.add_theme_constant_override("separation", 4)
			card.add_child(main_vbox_q)
			
			# Header: Title + Reward on the right
			var q_header = HBoxContainer.new()
			q_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			main_vbox_q.add_child(q_header)
			
			var title_lbl = Label.new()
			title_lbl.text = quest.get("title", "Active Request")
			title_lbl.add_theme_font_size_override("font_size", 11)
			title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
			title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			q_header.add_child(title_lbl)
			
			var reward_lbl = Label.new()
			reward_lbl.text = "%d G" % quest.get("reward_gold", 0)
			reward_lbl.add_theme_font_size_override("font_size", 10)
			reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			q_header.add_child(reward_lbl)
			
			# Description
			var desc_lbl = Label.new()
			desc_lbl.text = quest.get("description", "")
			desc_lbl.add_theme_font_size_override("font_size", 9)
			desc_lbl.modulate = Color(0.75, 0.8, 0.85, 0.8)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			main_vbox_q.add_child(desc_lbl)
			
			# Footer: Progress / Due remaining
			var q_footer = HBoxContainer.new()
			q_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			main_vbox_q.add_child(q_footer)
			
			# Check progress
			var progress_text = ""
			var is_complete = false
			if quest.get("item_id") != "":
				var required = quest.get("item_amount", 1)
				var current = GameState.player_inventory.get_item_amount(quest["item_id"])
				progress_text = "Progress: %d/%d %s" % [current, required, quest.get("item_name", "Items")]
				if current >= required:
					is_complete = true
			else:
				progress_text = "Status: Ongoing"
				
			var progress_lbl = Label.new()
			progress_lbl.text = progress_text
			progress_lbl.add_theme_font_size_override("font_size", 9)
			if is_complete:
				progress_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4)) # green
			else:
				progress_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3)) # yellow
			progress_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			q_footer.add_child(progress_lbl)
			
			# Time limit
			var time_lbl_q = Label.new()
			time_lbl_q.add_theme_font_size_override("font_size", 9)
			
			var due_day = quest.get("due_day", -1)
			if due_day != -1:
				var current_day = GameState.time_days
				var days_left = due_day - current_day
				if days_left < 0:
					time_lbl_q.text = "Expired"
					time_lbl_q.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				elif days_left == 0:
					time_lbl_q.text = "Due Today!"
					time_lbl_q.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
				else:
					time_lbl_q.text = "Due in %d day(s)" % days_left
					time_lbl_q.modulate = Color(0.7, 0.7, 0.75, 0.8)
			else:
				time_lbl_q.text = "No Time Limit"
				time_lbl_q.modulate = Color(0.7, 0.7, 0.75, 0.8)
			q_footer.add_child(time_lbl_q)
			
			business_scroll_list.add_child(card)

func populate_opponents_list() -> void:
	if not opponents_scroll_list:
		return
		
	for child in opponents_scroll_list.get_children():
		child.queue_free()
		
	var rivals = get_tree().get_nodes_in_group("Rivals")
	if rivals.is_empty():
		var label = Label.new()
		label.text = "No opponent families detected in this region."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = Color(0.6, 0.6, 0.6, 0.8)
		opponents_scroll_list.add_child(label)
		return
		
	for rival in rivals:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 50)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.22, 0.75)
		style.set_border_width_all(1)
		style.border_color = Color(0.6, 0.3, 0.3, 0.5) # Reddish border for opponents
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		card.add_child(hbox)
		
		var name_lbl = Label.new()
		var rival_family = rival.get("family_name") if rival.get("family_name") else rival.name
		var rival_profession = rival.get("profession") if rival.get("profession") else ""
		var rival_level = rival.get("level") if rival.get("level") != null else 1
		if rival_profession != "":
			name_lbl.text = "%s (%s Lvl %d)" % [rival_family, rival_profession.capitalize(), rival_level]
		else:
			name_lbl.text = rival_family
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(vbox)
		
		var gold_lbl = Label.new()
		gold_lbl.text = "Wealth: %d Gold" % rival.gold
		gold_lbl.add_theme_font_size_override("font_size", 10)
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(gold_lbl)
		
		var standing_lbl = Label.new()
		var r_standing = rival.get("standing") if rival.get("standing") else "Competitor"
		standing_lbl.text = "Standing: " + r_standing
		standing_lbl.add_theme_font_size_override("font_size", 9)
		standing_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		standing_lbl.modulate = Color(0.9, 0.6, 0.6)
		vbox.add_child(standing_lbl)
		
		opponents_scroll_list.add_child(card)

# ----------------- OTHER INTERFACES & OVERLAYS -----------------

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
				var is_workshop = interactable.is_in_group("Bakeries") or interactable.is_in_group("Smelters") or interactable.is_in_group("Inns") or interactable.is_in_group("Looms") or interactable.is_in_group("Mills") or interactable.is_in_group("PaperMakers") or interactable.is_in_group("PrintingPresses") or interactable.is_in_group("Banks")
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
				if is_buy:
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


# Player Title Upgrade Window State
var _selected_title_index: int = 1

func update_title_upgrade_window() -> void:
	if not titles_list_container:
		return
		
	# Clear previous buttons
	for child in titles_list_container.get_children():
		child.queue_free()
		
	var active_title = GameState.title_level
	
	# Populate 5 titles
	var buttons = []
	for lvl in range(1, 6):
		var btn = Button.new()
		btn.text = GameState.get_title_name(lvl)
		if lvl == active_title:
			btn.text += " (Current)"
			btn.modulate = Color(0.4, 1.0, 0.4)
		elif lvl < active_title:
			btn.text += " (Unlocked)"
			btn.modulate = Color(0.7, 0.7, 0.8)
		else:
			btn.modulate = Color(1.0, 0.9, 0.6)
			
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(180, 32)
		_setup_button_hover(btn)
		
		# Hook up click
		var target_lvl = lvl
		btn.pressed.connect(func():
			_selected_title_index = target_lvl
			_refresh_title_details()
		)
		
		titles_list_container.add_child(btn)
		buttons.append(btn)
		
	# Set focus neighbors for title list buttons
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = upgrade_title_button.get_path() if upgrade_title_button else btn.get_path()
		btn.focus_neighbor_top = buttons[i - 1].get_path() if i > 0 else btn.get_path()
		btn.focus_neighbor_bottom = buttons[i + 1].get_path() if i < buttons.size() - 1 else btn.get_path()
		
	# Focus on current title button or previously selected one
	_refresh_title_details()

func _refresh_title_details() -> void:
	if not selected_title_name_label:
		return
		
	var lvl = _selected_title_index
	var title_name = GameState.get_title_name(lvl)
	selected_title_name_label.text = title_name
	
	var desc = ""
	match lvl:
		1:
			desc = "Apprentice Guildmaster status.\n\nBenefits:\n • Starting title. Allows construction of Tier 1 basic structures (plaza, beds, crafting benches, general stalls)."
		2:
			desc = "Journeyman status.\n\nBenefits:\n • Unlocks Tier 2 advanced production buildings: Mill, Smelter, Loom, Inn, Farmstead, Tavern."
		3:
			desc = "Guildmaster status.\n\nBenefits:\n • Unlocks Tier 3 premium shops: Bakery, Paper Maker, and Distillery.\n • Increases overnight crop regrowth speed by 15%."
		4:
			desc = "Patrician civic status.\n\nBenefits:\n • Unlocks Tier 4 administrative buildings: Printing Press, Event Hall, and Banks.\n • Reduces employee salary costs by 10%."
		5:
			desc = "Guild Baron status.\n\nBenefits:\n • Unlocks Tier 5 luxury upgrade improvements.\n • Passively generates +5 Influence overnight."
			
	selected_title_desc_label.text = desc
	
	var cost = GameState.get_title_upgrade_cost(lvl)
	var active_title = GameState.title_level
	
	if lvl == active_title:
		title_upgrade_cost_label.text = "You currently hold this title."
		title_upgrade_cost_label.modulate = Color(0.4, 1.0, 0.4)
		upgrade_title_button.disabled = true
		upgrade_title_button.text = "Current Title"
	elif lvl < active_title:
		title_upgrade_cost_label.text = "Already unlocked."
		title_upgrade_cost_label.modulate = Color(0.7, 0.7, 0.8)
		upgrade_title_button.disabled = true
		upgrade_title_button.text = "Unlocked"
	elif lvl > active_title + 1:
		title_upgrade_cost_label.text = "Must unlock previous titles first."
		title_upgrade_cost_label.modulate = Color(0.9, 0.4, 0.4)
		upgrade_title_button.disabled = true
		upgrade_title_button.text = "Locked"
	else:
		# Next title to unlock
		title_upgrade_cost_label.text = "Upgrade Cost: %d Gold, %d Influence" % [cost["gold"], cost["influence"]]
		var can_afford_gold = GameState.gold >= cost["gold"]
		var can_afford_influence = GameState.influence >= cost["influence"]
		
		if can_afford_gold and can_afford_influence:
			title_upgrade_cost_label.modulate = Color(0.4, 1.0, 0.4)
			upgrade_title_button.disabled = false
			upgrade_title_button.text = "Upgrade Title"
		else:
			title_upgrade_cost_label.modulate = Color(0.9, 0.4, 0.4)
			upgrade_title_button.disabled = true
			var reason = "Lacking: "
			if not can_afford_gold: reason += "Gold "
			if not can_afford_influence: reason += "Influence"
			upgrade_title_button.text = reason

func _on_upgrade_title_pressed() -> void:
	var target_lvl = GameState.title_level + 1
	if GameState.upgrade_title():
		_flash_element(title_upgrade_window, Color(0.4, 1.0, 0.4))
		_selected_title_index = target_lvl
		update_hud_values()
		update_title_upgrade_window()
	else:
		_shake_element(title_upgrade_window)
		_flash_element(title_upgrade_window, Color(1.0, 0.4, 0.4))

# Influence Broker Window State
func open_influence_broker_ui(_broker: Node2D) -> void:
	toggle_window(influence_broker_window)

func update_influence_broker_window() -> void:
	if not influence_broker_window or not influence_broker_window.visible:
		return
	if broker_gold_label:
		broker_gold_label.text = "Current Gold: %d G" % GameState.gold
	if broker_influence_label:
		broker_influence_label.text = "Current Influence: %d / %d (Permanent)" % [GameState.influence, GameState.permanent_influence]
	if exchange_button:
		var can_afford = GameState.gold >= 100
		exchange_button.disabled = not can_afford
		exchange_button.text = "Buy 10 Influence (100 Gold)" if can_afford else "Lacking Gold"

func _on_exchange_influence_pressed() -> void:
	if GameState.gold >= 100:
		GameState.gold -= 100
		GameState.influence += 10
		GameState.spawn_ui_floating_text("+10 Influence!")
		_flash_element(influence_broker_window, Color(0.4, 1.0, 0.4))
		update_hud_values()
		update_influence_broker_window()
	else:
		_shake_element(influence_broker_window)
		_flash_element(influence_broker_window, Color(1.0, 0.4, 0.4))

# Micro-animation helper tweens
func _shake_element(node: Control) -> void:
	var start_pos = node.position
	var tween = create_tween()
	tween.tween_property(node, "position:x", start_pos.x - 6.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x + 6.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x - 4.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x + 4.0, 0.05)
	tween.tween_property(node, "position:x", start_pos.x, 0.05)

func _flash_element(node: Control, flash_color: Color) -> void:
	var orig_color = node.modulate
	var tween = create_tween()
	tween.tween_property(node, "modulate", flash_color, 0.1)
	tween.tween_property(node, "modulate", orig_color, 0.15)


# ==========================================
# ALERTS & HISTORY WINDOW MANAGEMENT
# ==========================================

func _create_alert_containers() -> void:
	# 1. Create Alert Cards container on the right side of the screen
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
	
	var hud_control = get_node("Control")
	if hud_control:
		hud_control.add_child(alert_margin)
		
	# 2. Create Alert History Window dynamically
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
	
	if inventory_window:
		var window_style = inventory_window.get_theme_stylebox("panel")
		alert_history_window.add_theme_stylebox_override("panel", window_style)
		
	if windows_container:
		windows_container.add_child(alert_history_window)
		
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
	_setup_button_hover(clear_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(func():
		toggle_window(alert_history_window)
	)
	footer.add_child(close_btn)
	_setup_button_hover(close_btn)

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
		"warning":
			style.border_color = Color(0.88, 0.55, 0.12, 0.85)
		"danger":
			style.border_color = Color(0.86, 0.24, 0.24, 0.85)
		_:
			style.border_color = Color(0.24, 0.6, 0.86, 0.85)
			
	return style

func _on_alert_added(alert_data: Dictionary) -> void:
	if not alert_cards_vbox:
		return
		
	if alert_cards_vbox.has_node(alert_data.id):
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
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = alert_data.title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	match alert_data.type:
		"warning":
			title.add_theme_color_override("font_color", Color(0.88, 0.55, 0.12))
		"danger":
			title.add_theme_color_override("font_color", Color(0.86, 0.24, 0.24))
		_:
			title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
	header.add_child(title)
	
	var close_x = Button.new()
	close_x.text = "X"
	close_x.flat = true
	close_x.custom_minimum_size = Vector2(20, 20)
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.add_theme_font_size_override("font_size", 10)
	close_x.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	close_x.pressed.connect(func():
		GameState.remove_alert(alert_data.id)
	)
	header.add_child(close_x)
	_setup_button_hover(close_x)
	
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
		_setup_button_hover(inspect)
		
	alert_cards_vbox.add_child(card)
	
	card.ready.connect(func():
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0
		var tween = create_tween().set_parallel(true)
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
	var tween = create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "modulate:a", 0.0, 0.15)
	tween.tween_property(card, "custom_minimum_size:y", 0.0, 0.15)
	tween.chain().tween_callback(card.queue_free)

func _on_inspect_alert(alert_data: Dictionary) -> void:
	var building = alert_data.get("building")
	if not is_instance_valid(building):
		return
		
	windows_container.hide()
	for child in windows_container.get_children():
		child.hide()
		
	open_building_ui(building)

func populate_alert_history() -> void:
	if not alert_history_window:
		return
		
	var list = alert_history_window.find_child("HistoryList", true, false) as VBoxContainer
	if not list:
		return
		
	for child in list.get_children():
		child.queue_free()
		
	var past = GameState.past_alerts
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
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var is_active = false
		for act in GameState.active_alerts:
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
				"warning":
					style.border_color = Color(0.88, 0.55, 0.12, 0.8)
				"danger":
					style.border_color = Color(0.86, 0.24, 0.24, 0.8)
				_:
					style.border_color = Color(0.24, 0.6, 0.86, 0.8)
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
				"warning":
					title.add_theme_color_override("font_color", Color(0.88, 0.55, 0.12))
				"danger":
					title.add_theme_color_override("font_color", Color(0.86, 0.24, 0.24))
				_:
					title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
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
			inspect.text = "Inspect"
			inspect.custom_minimum_size = Vector2(80, 24)
			inspect.add_theme_font_size_override("font_size", 10)
			inspect.pressed.connect(func():
				_on_inspect_alert(alert)
			)
			btn_vbox.add_child(inspect)
			_setup_button_hover(inspect)
			
		list.add_child(row)

func _on_clear_history_pressed() -> void:
	GameState.past_alerts = GameState.active_alerts.duplicate()
	populate_alert_history()

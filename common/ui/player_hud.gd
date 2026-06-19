extends CanvasLayer

signal build_requested(building_data: BuildingData)
signal move_requested()
signal demolish_requested()

# Outlets to UI children
@onready var gold_label: Label = %GoldLabel
@onready var time_label: Label = %TimeLabel
@onready var patreon_level_label: Label = %PatreonLevelLabel
@onready var patreon_xp_bar: ProgressBar = %PatreonXPBar
@onready var scholar_level_label: Label = %ScholarLevelLabel
@onready var scholar_xp_bar: ProgressBar = %ScholarXPBar
@onready var craftsman_level_label: Label = %CraftsmanLevelLabel
@onready var craftsman_xp_bar: ProgressBar = %CraftsmanXPBar
@onready var tailor_level_label: Label = %TailorLevelLabel
@onready var tailor_xp_bar: ProgressBar = %TailorXPBar

@onready var interact_prompt: PanelContainer = %InteractPrompt
@onready var interact_label: Label = %InteractLabel

@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var panel_close_button: Button = %PanelCloseButton

@onready var market_ui: Control = %MarketUI
@onready var crafting_ui: Control = %CraftingUI

# Build Panel Outlets
@onready var build_panel: PanelContainer = %BuildPanel
@onready var move_tool_button: Button = %MoveToolButton
@onready var demolish_tool_button: Button = %DemolishToolButton
@onready var build_close_button: Button = %BuildCloseButton
@onready var build_tab_container: TabContainer = %BuildTabContainer
@onready var all_list: VBoxContainer = %AllList
@onready var patreon_list: VBoxContainer = %PatreonList
@onready var scholar_list: VBoxContainer = %ScholarList
@onready var craftsman_list: VBoxContainer = %CraftsmanList
@onready var tailor_list: VBoxContainer = %TailorList

# Left Column Profile Panel Outlets
@onready var profile_gold_label: Label = %ProfileGoldLabel
@onready var profile_time_label: Label = %ProfileTimeLabel

# Right Column TabContainer & Career Outlets
@onready var career_tab_container: TabContainer = %CareerTabContainer

var _active_player: Player = null
var _all_recipes: Array = []
var _building_ui_instance: Control = null
var _filter_only_buildable: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("PlayerHUD")
	
	# Load recipes once at startup
	_load_all_recipes()
	
	# Connect to player if already exists
	_find_player()
	
	# Hide overlays initially
	interact_prompt.hide()
	inventory_panel.hide()
	market_ui.hide()
	crafting_ui.hide()
	
	# Dynamic initialization of NPC Debug Inspector panel
	var inspector_script = load("res://common/ui/npc_inspector_panel.gd")
	if inspector_script:
		var inspector_instance = inspector_script.new()
		inspector_instance.name = "NPCInspectorPanel"
		var hud_control = get_node_or_null("HUDControl")
		if hud_control:
			hud_control.add_child(inspector_instance)
		else:
			add_child(inspector_instance)
		inspector_instance.hide()
	
	# Update top bar values
	update_hud_values()
	
	# Listen to inventory changes from GameState
	if GameState.player_inventory:
		GameState.player_inventory.inventory_changed.connect(update_inventory_panel)
		
	# Listen to time cycle changes
	GameState.time_changed.connect(_on_time_changed)
	_on_time_changed(GameState.time_hours, int(GameState.time_minutes), GameState.time_days)
	
	# Wire up close button
	if panel_close_button:
		panel_close_button.pressed.connect(toggle_inventory)
		_setup_button_hover(panel_close_button)
		panel_close_button.focus_mode = Control.FOCUS_NONE
		
	# Wire up Build Menu buttons
	if build_close_button:
		build_close_button.pressed.connect(toggle_build_menu)
		_setup_button_hover(build_close_button)
		build_close_button.focus_mode = Control.FOCUS_NONE
		
	if move_tool_button:
		move_tool_button.pressed.connect(func():
			build_panel.hide()
			move_requested.emit()
		)
		_setup_button_hover(move_tool_button)
		move_tool_button.focus_mode = Control.FOCUS_NONE
		
	if demolish_tool_button:
		demolish_tool_button.pressed.connect(func():
			build_panel.hide()
			demolish_requested.emit()
		)
		_setup_button_hover(demolish_tool_button)
		
	# Rename tabs to match new classifications (Personal Home and Business only)
	if build_tab_container:
		var all_tab = build_tab_container.get_node_or_null("All")
		if all_tab:
			build_tab_container.remove_child(all_tab)
			all_tab.queue_free()
		build_tab_container.set_tab_title(0, "General")
		build_tab_container.set_tab_title(1, "Business")
		while build_tab_container.get_tab_count() > 2:
			var tab_to_remove = build_tab_container.get_tab_control(2)
			build_tab_container.remove_child(tab_to_remove)
			tab_to_remove.queue_free()
		build_tab_container.focus_mode = Control.FOCUS_ALL
		build_tab_container.tab_changed.connect(func(_tab_idx):
			_focus_first_card_in_active_tab()
		)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
		
	if not _active_player:
		_find_player()
		
	# Check for build menu toggle input (B key)
	if Input.is_action_just_pressed("toggle_build_menu"):
		if not market_ui.visible and not crafting_ui.visible and not inventory_panel.visible:
			var pm = get_tree().get_first_node_in_group("PlacementManager")
			var pm_active = pm and pm.is_placement_active()
			if pm_active:
				pm.exit_placement_mode()
			else:
				toggle_build_menu()
				
	# Check for inventory toggle input (I key)
	if Input.is_action_just_pressed("toggle_inventory"):
		var pm = get_tree().get_first_node_in_group("PlacementManager")
		var pm_active = pm and pm.is_placement_active()
		if not market_ui.visible and not crafting_ui.visible and not build_panel.visible and not pm_active:
			toggle_inventory()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_active_player = players[0] as Player
		if not _active_player.interactables_changed.is_connected(update_interaction_prompt):
			_active_player.interactables_changed.connect(update_interaction_prompt)
		update_interaction_prompt()

func update_hud_values() -> void:
	if gold_label:
		gold_label.text = "%d Gold" % GameState.gold
	if profile_gold_label:
		profile_gold_label.text = "%d Gold" % GameState.gold
		
	# Patreon
	var p_lvl = GameState.career_levels.get("patreon", 1)
	var p_xp = GameState.career_xp.get("patreon", 0)
	var p_next = GameState.get_xp_for_level(p_lvl)
	if patreon_level_label:
		patreon_level_label.text = "Patreon Lv. %d" % p_lvl
	if patreon_xp_bar:
		patreon_xp_bar.max_value = p_next
		patreon_xp_bar.value = p_xp
		
	# Scholar
	var s_lvl = GameState.career_levels.get("scholar", 1)
	var s_xp = GameState.career_xp.get("scholar", 0)
	var s_next = GameState.get_xp_for_level(s_lvl)
	if scholar_level_label:
		scholar_level_label.text = "Scholar Lv. %d" % s_lvl
	if scholar_xp_bar:
		scholar_xp_bar.max_value = s_next
		scholar_xp_bar.value = s_xp
		
	# Craftsman
	var c_lvl = GameState.career_levels.get("craftsman", 1)
	var c_xp = GameState.career_xp.get("craftsman", 0)
	var c_next = GameState.get_xp_for_level(c_lvl)
	if craftsman_level_label:
		craftsman_level_label.text = "Craftsman Lv. %d" % c_lvl
	if craftsman_xp_bar:
		craftsman_xp_bar.max_value = c_next
		craftsman_xp_bar.value = c_xp
		
	# Tailor
	var t_lvl = GameState.career_levels.get("tailor", 1)
	var t_xp = GameState.career_xp.get("tailor", 0)
	var t_next = GameState.get_xp_for_level(t_lvl)
	if tailor_level_label:
		tailor_level_label.text = "Tailor Lv. %d" % t_lvl
	if tailor_xp_bar:
		tailor_xp_bar.max_value = t_next
		tailor_xp_bar.value = t_xp
		
	# Update Profile and Career tabs
	update_career_tabs()
	
	# Update dynamic traits list in Left Column Profile Panel
	if profile_gold_label:
		var profile_vbox = profile_gold_label.get_parent()
		if profile_vbox:
			var traits_container = profile_vbox.get_node_or_null("TraitsContainer")
			if traits_container:
				traits_container.queue_free()
				
			var max_lvl = 1
			for c in GameState.career_levels:
				max_lvl = max(max_lvl, GameState.career_levels[c])
				
			if max_lvl >= 5:
				traits_container = VBoxContainer.new()
				traits_container.name = "TraitsContainer"
				traits_container.add_theme_constant_override("separation", 4)
				profile_vbox.add_child(traits_container)
				
				var traits_title = Label.new()
				traits_title.text = "Active Mastery Traits"
				traits_title.add_theme_font_size_override("font_size", 12)
				traits_title.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31))
				traits_container.add_child(traits_title)
				
				# Gold-bordered icon/badge for Bountiful Harvest
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
				lbl_t1.add_theme_font_size_override("font_size", 10)
				lbl_t1.modulate = Color(1.0, 0.9, 0.5)
				trait1.add_child(lbl_t1)
				traits_container.add_child(trait1)
				
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
					lbl_t2.text = "Artisan's Efficiency (Luxury -15% time)"
					lbl_t2.add_theme_font_size_override("font_size", 10)
					lbl_t2.modulate = Color(1.0, 0.9, 0.5)
					trait2.add_child(lbl_t2)
					traits_container.add_child(trait2)

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
			
			# Micro animation: pulse scale slightly using a Tween
			var tween = create_tween()
			tween.tween_property(interact_prompt, "scale", Vector2(1.05, 1.05), 0.1)
			tween.tween_property(interact_prompt, "scale", Vector2(1.0, 1.0), 0.1)
	else:
		interact_prompt.hide()

func toggle_inventory() -> void:
	if inventory_panel.visible:
		inventory_panel.hide()
		if _active_player:
			_active_player.unfreeze()
	else:
		if _active_player:
			_active_player.freeze()
		update_inventory_panel()
		inventory_panel.show()
		inventory_panel.pivot_offset = inventory_panel.size / 2.0
		inventory_panel.scale = Vector2(0.9, 0.9)
		var tween = create_tween()
		tween.tween_property(inventory_panel, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if panel_close_button:
			panel_close_button.grab_focus()

func update_inventory_panel() -> void:
	update_hud_values()
	
	if not inventory_grid:
		return
		
	# Clear grid
	for child in inventory_grid.get_children():
		child.queue_free()
		
	# Fill grid slots
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
		
		var hover_style = style.duplicate()
		hover_style.border_color = Color(0.88, 0.73, 0.23, 0.9) # Gold highlight
		
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
		
		# Name Label
		var item_label = Label.new()
		item_label.text = item.name.substr(0, 8)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(item_label)
		
		# Amount Label
		var amount_label = Label.new()
		amount_label.text = "x%d" % amount
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(amount_label)
		
		# Tooltip
		slot_panel.tooltip_text = "%s\nCategory: %s\nValue: %d Gold" % [item.name, item.category, item.base_value]
		
		inventory_grid.add_child(slot_panel)
		
	# Fill remaining empty slots
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
		
	_link_inventory_grid_focus()

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
				print("[PlayerHUD] Unlocked career via book: ", career)
				update_inventory_panel()
				update_hud_values()
				refresh_build_menu()
			else:
				print("[PlayerHUD] Career %s is already unlocked!" % career)

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
		var hud_control = get_node_or_null("HUDControl")
		if hud_control:
			hud_control.add_child(_building_ui_instance)
		else:
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

var _commercial_route_ui_instance: Control = null

func open_commercial_routes_ui() -> void:
	if _commercial_route_ui_instance:
		_commercial_route_ui_instance.queue_free()
		
	var route_ui_scene = load("res://common/ui/commercial_route_panel.tscn")
	if route_ui_scene:
		_commercial_route_ui_instance = route_ui_scene.instantiate() as Control
		var hud_control = get_node_or_null("HUDControl")
		if hud_control:
			hud_control.add_child(_commercial_route_ui_instance)
		else:
			add_child(_commercial_route_ui_instance)
			
		if _active_player:
			_active_player.freeze()
		interact_prompt.hide()

func close_commercial_routes_ui() -> void:
	if _commercial_route_ui_instance:
		_commercial_route_ui_instance.queue_free()
		_commercial_route_ui_instance = null
		if _active_player:
			_active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func _on_time_changed(hours: int, minutes: int, days: int) -> void:
	if time_label:
		var ampm = "AM" if hours < 12 else "PM"
		var display_hours = hours % 12
		if display_hours == 0:
			display_hours = 12
		time_label.text = "Day %d - %02d:%02d %s" % [days, display_hours, minutes, ampm]
	if profile_time_label and time_label:
		profile_time_label.text = time_label.text

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

func update_career_tabs() -> void:
	if not career_tab_container:
		return
		
	var careers = ["patreon", "craftsman", "tailor", "scholar"]
	
	# Rebuild children if they don't exist
	if career_tab_container.get_child_count() != careers.size():
		for child in career_tab_container.get_children():
			child.queue_free()
			
		var skill_panel_scene = load("res://common/ui/skill_panel.tscn")
		if skill_panel_scene:
			for career in careers:
				var panel = skill_panel_scene.instantiate()
				career_tab_container.add_child(panel)
				panel.init_skill(career, _all_recipes)
				
	# Update existing panels
	for i in range(careers.size()):
		var career = careers[i]
		var panel = career_tab_container.get_child(i)
		if panel and panel.has_method("update_panel"):
			panel.update_panel()
		var lvl = GameState.career_levels.get(career, 1)
		career_tab_container.set_tab_title(i, "%s (Lv. %d)" % [career.capitalize(), lvl])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_U:
			var inspector = get_node_or_null("HUDControl/NPCInspectorPanel")
			if not inspector:
				inspector = get_node_or_null("NPCInspectorPanel")
			if inspector:
				if inspector.visible:
					inspector.hide()
				else:
					inspector._populate_npc_list()
					inspector.show()
				get_viewport().set_input_as_handled()
				return

	if build_panel and build_panel.visible:
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_TAB:
				_filter_only_buildable = not _filter_only_buildable
				refresh_build_menu()
				_update_build_menu_title()
				_focus_first_card_in_active_tab()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_Q:
				if build_tab_container:
					var new_tab = (build_tab_container.current_tab - 1 + build_tab_container.get_tab_count()) % build_tab_container.get_tab_count()
					build_tab_container.current_tab = new_tab
					get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_E:
				if build_tab_container:
					var new_tab = (build_tab_container.current_tab + 1) % build_tab_container.get_tab_count()
					build_tab_container.current_tab = new_tab
					get_viewport().set_input_as_handled()
				return
			
			var key = event.keycode
			if key == KEY_W or key == KEY_S or key == KEY_A or key == KEY_D:
				var focused = get_viewport().gui_get_focus_owner()
				if focused and is_instance_valid(focused) and is_ancestor_of(focused):
					var neighbor_path = NodePath()
					match key:
						KEY_W: neighbor_path = focused.focus_neighbor_top
						KEY_S: neighbor_path = focused.focus_neighbor_bottom
						KEY_A: neighbor_path = focused.focus_neighbor_left
						KEY_D: neighbor_path = focused.focus_neighbor_right
					
					if neighbor_path and neighbor_path != NodePath(""):
						var neighbor = focused.get_node_or_null(neighbor_path)
						if neighbor and neighbor is Control:
							neighbor.grab_focus()
							get_viewport().set_input_as_handled()
							return

	# Handle F / interact / ui_accept confirming focused buttons/cards inside HUD
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and is_instance_valid(focused) and is_ancestor_of(focused):
				if focused is Button:
					focused.pressed.emit()
					get_viewport().set_input_as_handled()
					return
				elif focused is PanelContainer and (focused.get_parent() == inventory_grid or (build_tab_container and build_tab_container.is_ancestor_of(focused))):
					var event_accept = InputEventAction.new()
					event_accept.action = "ui_accept"
					event_accept.pressed = true
					focused.gui_input.emit(event_accept)
					get_viewport().set_input_as_handled()
					return

	if event.is_action_pressed("ui_cancel"):
		var pm = get_tree().get_first_node_in_group("PlacementManager")
		var pm_active = pm and pm.is_placement_active()
		if pm_active:
			return
			
		var bank_ui = get_node_or_null("BankUI")
		if bank_ui and bank_ui.visible:
			if bank_ui.has_method("_on_close_pressed"):
				bank_ui._on_close_pressed()
			else:
				bank_ui.queue_free()
				if _active_player:
					_active_player.unfreeze()
			update_interaction_prompt()
			get_viewport().set_input_as_handled()
			return
			
		if build_panel.visible:
			toggle_build_menu()
			get_viewport().set_input_as_handled()
		elif inventory_panel.visible:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif market_ui.visible or crafting_ui.visible:
			# Let their own UI scripts handle closure
			pass
		else:
			toggle_pause_menu()
			get_viewport().set_input_as_handled()

func toggle_build_menu() -> void:
	if build_panel.visible:
		build_panel.hide()
		if _active_player:
			_active_player.unfreeze()
	else:
		inventory_panel.hide()
		market_ui.hide()
		crafting_ui.hide()
		
		refresh_build_menu()
		_update_build_menu_title()
			
		build_panel.show()
		if _active_player:
			_active_player.freeze()
			
		build_panel.pivot_offset = build_panel.size / 2.0
		build_panel.scale = Vector2(0.9, 0.9)
		var tween = create_tween()
		tween.tween_property(build_panel, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_focus_first_card_in_active_tab()

func _is_building_buildable(building: BuildingData) -> bool:
	var career = building.career
	var req_lvl = building.level
	var player_lvl = 1
	if career != "":
		player_lvl = GameState.career_levels.get(career, 1)
	var is_level_locked = player_lvl < req_lvl
	var is_locked_placeholder = building.scene_path == ""
	var is_title_locked = building.tier > GameState.title_level
	return not is_level_locked and not is_locked_placeholder and not is_title_locked

func _update_build_menu_title() -> void:
	if not build_panel:
		return
	var title_node = build_panel.get_node_or_null("MainLayout/Title")
	if title_node:
		if _filter_only_buildable:
			title_node.text = "Construction Menu (Filter: Buildable - [Tab] to toggle)"
		else:
			title_node.text = "Construction Menu (Filter: All - [Tab] to toggle)"

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

func _populate_all_tab() -> void:
	if not all_list:
		return
		
	for child in all_list.get_children():
		child.queue_free()
		
	var sections = [
		{"title": "Personal Home", "filter": func(item): return item.type == "home"},
		{"title": "General Business (Rentals)", "filter": func(item): return item.type == "renting"},
		{"title": "Patreon Business", "filter": func(item): return item.career == "patreon"},
		{"title": "Craftsman Business", "filter": func(item): return item.career == "craftsman"},
		{"title": "Tailor Business", "filter": func(item): return item.career == "tailor"},
		{"title": "Scholar Business", "filter": func(item): return item.career == "scholar"},
		{"title": "General Workstations", "filter": func(item): return item.career == "" and item.type != "home" and item.type != "renting"}
	]
	
	var tab_sections = []
	
	for section in sections:
		var section_items = []
		for item in GameState.build_database:
			if section["filter"].call(item):
				if not _filter_only_buildable or _is_building_buildable(item):
					section_items.append(item)
				
		if section_items.is_empty():
			continue
			
		var header_container = VBoxContainer.new()
		header_container.add_theme_constant_override("separation", 6)
		all_list.add_child(header_container)
		
		var sep = HSeparator.new()
		header_container.add_child(sep)
		
		var label = Label.new()
		label.text = section["title"]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.24, 0.65, 0.44))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		header_container.add_child(label)
		
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
		var scroll_height = 110 + (max_levels - 1) * 100 if max_levels > 0 else 110
		scroll.custom_minimum_size = Vector2(0, scroll_height)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		
		var columns_hbox = HBoxContainer.new()
		columns_hbox.add_theme_constant_override("separation", 16)
		columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(columns_hbox)
		
		header_container.add_child(scroll)
		
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
				var card = _create_premium_card(fam_items[i], true)
				col_vbox.add_child(card)
				col_cards.append(card)
			section_cols.append(col_cards)
		tab_sections.append(section_cols)
		
	_link_tab_focus_neighbors(tab_sections)

func _populate_personal_home_tab() -> void:
	if not patreon_list:
		return
		
	for child in patreon_list.get_children():
		patreon_list.remove_child(child)
		child.queue_free()
		
	var general_items = []
	for item in GameState.build_database:
		if item.family == "personal_home" or item.type == "renting" or item.family == "warehouse":
			if not _filter_only_buildable or _is_building_buildable(item):
				general_items.append(item)
			
	general_items.sort_custom(func(a, b):
		var score_a = 0
		if a.family == "personal_home": score_a = 1
		elif a.type == "renting": score_a = 2
		elif a.family == "warehouse": score_a = 3
		
		var score_b = 0
		if b.family == "personal_home": score_b = 1
		elif b.type == "renting": score_b = 2
		elif b.family == "warehouse": score_b = 3
		
		if score_a != score_b:
			return score_a < score_b
		return a.cost < b.cost
	)
	
	var col_cards = []
	for i in range(general_items.size()):
		if i > 0:
			patreon_list.add_child(_create_vertical_connector())
		var card = _create_premium_card(general_items[i], true)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		patreon_list.add_child(card)
		col_cards.append(card)
		
	if not col_cards.is_empty():
		_link_tab_focus_neighbors([[col_cards]])

func _populate_business_tab() -> void:
	if not scholar_list:
		return
		
	for child in scholar_list.get_children():
		scholar_list.remove_child(child)
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
		scholar_list.add_child(title_margin)
		
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
		var scroll_height = 110 + (max_levels - 1) * 106 if max_levels > 0 else 110
		scroll.custom_minimum_size = Vector2(0, scroll_height)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		
		var columns_hbox = HBoxContainer.new()
		columns_hbox.add_theme_constant_override("separation", 16)
		columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(columns_hbox)
		
		scholar_list.add_child(scroll)
		
		var section_cols = []
		for fam_info in families:
			var fam_name = fam_info["name"]
			var col_vbox = VBoxContainer.new()
			col_vbox.custom_minimum_size = Vector2(90, 0)
			col_vbox.add_theme_constant_override("separation", 4)
			columns_hbox.add_child(col_vbox)
			
			var fam_items = family_data[fam_name]
			var col_cards = []
			for i in range(fam_items.size()):
				if i > 0:
					col_vbox.add_child(_create_vertical_connector())
				var card = _create_premium_card(fam_items[i], true)
				col_vbox.add_child(card)
				col_cards.append(card)
			section_cols.append(col_cards)
		tab_sections.append(section_cols)
		
	_link_tab_focus_neighbors(tab_sections)

func _create_premium_card(building: BuildingData, compact: bool) -> PanelContainer:
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
	card.custom_minimum_size = Vector2(90, 95)
		
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
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
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 2)
	main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_child(main_vbox)
	
	var initials = ""
	var words = building.name.split(" ")
	for word in words:
		if word.length() > 0:
			initials += word[0].to_upper()
	if initials.length() > 3:
		initials = initials.substr(0, 3)
		
	var icon_container = PanelContainer.new()
	var icon_size = 36
	icon_container.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
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
	icon_label.add_theme_font_size_override("font_size", 11)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_label.add_theme_constant_override("outline_size", 2)
	icon_label.add_theme_color_override("font_outline_color", Color.BLACK)
	icon_container.add_child(icon_label)
	main_vbox.add_child(icon_container)
	
	var title_lbl = Label.new()
	var title_text = building.name
	if building.building_level > 1 and not ("Lv." in title_text):
		title_text += " Lv. %d" % building.building_level
		
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 9)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.max_lines_visible = 2
	
	if is_disabled:
		title_lbl.modulate = Color(0.5, 0.5, 0.5, 0.8)
	else:
		title_lbl.modulate = Color(0.9, 0.95, 0.9, 1)
	main_vbox.add_child(title_lbl)
	
	var info_lbl = Label.new()
	info_lbl.add_theme_font_size_override("font_size", 8)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if is_locked_placeholder:
		info_lbl.text = "Coming Soon"
		info_lbl.modulate = Color(0.6, 0.6, 0.6, 0.8)
	elif is_title_locked:
		info_lbl.text = "T%d Title Req" % building.tier
		info_lbl.modulate = Color(0.9, 0.35, 0.35, 1)
	elif is_level_locked:
		info_lbl.text = "Lv. %d Req" % req_lvl
		info_lbl.modulate = Color(0.9, 0.35, 0.35, 1)
	else:
		info_lbl.text = "%d G" % building.cost
		if is_gold_locked:
			info_lbl.modulate = Color(0.9, 0.45, 0.45, 0.9)
		else:
			info_lbl.modulate = Color(0.85, 0.85, 0.4, 0.9)
			
	main_vbox.add_child(info_lbl)
	
	card.focus_mode = Control.FOCUS_ALL
	
	card.focus_entered.connect(func():
		var bright_style = style.duplicate() as StyleBoxFlat
		bright_style.border_color = border_color.lightened(0.3)
		bright_style.bg_color = base_color.lightened(0.1)
		card.add_theme_stylebox_override("panel", bright_style)
		
		card.pivot_offset = card.size / 2.0
		var tween = card.create_tween()
		tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08)
	)
	
	card.focus_exited.connect(func():
		card.add_theme_stylebox_override("panel", style)
		
		var tween = card.create_tween()
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08)
	)
	
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not is_disabled else Control.CURSOR_ARROW
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	card.mouse_entered.connect(func():
		if not is_disabled:
			var bright_style = style.duplicate() as StyleBoxFlat
			bright_style.border_color = border_color.lightened(0.3)
			bright_style.bg_color = base_color.lightened(0.1)
			card.add_theme_stylebox_override("panel", bright_style)
			
			card.pivot_offset = card.size / 2.0
			var tween = card.create_tween()
			tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08)
	)
	
	card.mouse_exited.connect(func():
		if not is_disabled:
			card.add_theme_stylebox_override("panel", style)
			
			var tween = card.create_tween()
			tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08)
	)
	
	card.gui_input.connect(func(event: InputEvent):
		var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		var is_accept = event.is_action_pressed("ui_accept")
		if is_click or is_accept:
			card.get_viewport().set_input_as_handled()
			if is_disabled:
				var shake_tween = card.create_tween()
				shake_tween.tween_property(card, "position:x", card.position.x - 4, 0.05)
				shake_tween.tween_property(card, "position:x", card.position.x + 4, 0.05)
				shake_tween.tween_property(card, "position:x", card.position.x, 0.05)
				
				if is_title_locked:
					var title_name = GameState.get_title_name(building.tier)
					_spawn_floating_text("Requires Title: %s" % title_name, card.global_position + card.size / 2.0)
				else:
					_spawn_floating_text("Locked!", card.global_position + card.size / 2.0)
				return
				
			if is_gold_locked:
				var shake_tween = card.create_tween()
				shake_tween.tween_property(card, "position:x", card.position.x - 4, 0.05)
				shake_tween.tween_property(card, "position:x", card.position.x + 4, 0.05)
				shake_tween.tween_property(card, "position:x", card.position.x, 0.05)
				
				_spawn_floating_text("Need more Gold!", card.global_position + card.size / 2.0)
				return
				
			var click_tween = card.create_tween()
			click_tween.tween_property(card, "scale", Vector2(0.96, 0.96), 0.05)
			click_tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.05)
			await click_tween.finished
			
			build_panel.hide()
			build_requested.emit(building)
	)
	
	return card

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
	
	get_parent().add_child(label)
	label.global_position = pos + Vector2(-30, -20)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 32.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	
	await tween.finished
	label.queue_free()

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
	
	if main_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		if card_rect.position.x < scroll_rect.position.x + padding:
			var diff = (scroll_rect.position.x + padding) - card_rect.position.x
			main_scroll.scroll_horizontal -= int(diff)
		elif card_rect.end.x > scroll_rect.end.x - padding:
			var diff = card_rect.end.x - (scroll_rect.end.x - padding)
			main_scroll.scroll_horizontal += int(diff)
			
	if main_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		if card_rect.position.y < scroll_rect.position.y + padding:
			var diff = (scroll_rect.position.y + padding) - card_rect.position.y
			main_scroll.scroll_vertical -= int(diff)
		elif card_rect.end.y > scroll_rect.end.y - padding:
			var diff = card_rect.end.y - (scroll_rect.end.y - padding)
			main_scroll.scroll_vertical += int(diff)

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
						if build_tab_container:
							card.focus_neighbor_top = build_tab_container.get_path()
							
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
	var p = card.get_parent()
	while p:
		if p is ScrollContainer:
			_ensure_card_visible(card, p)
		p = p.get_parent()

func _setup_button_hover(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	button.mouse_entered.connect(func():
		if not button.disabled:
			button.pivot_offset = button.size / 2.0
			var tween = create_tween()
			tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.08)
	)
	button.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
	)

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
		return node
	for child in node.get_children():
		var found = _find_first_focusable_card(child)
		if found:
			return found
	return null

func open_bank(bank) -> void:
	if get_node_or_null("BankUI"):
		return
	if _active_player:
		_active_player.freeze()
	interact_prompt.hide()
	
	var bank_ui_scene = load("res://common/ui/bank_ui.tscn")
	if bank_ui_scene:
		var bank_ui = bank_ui_scene.instantiate()
		bank_ui.name = "BankUI"
		add_child(bank_ui)
		bank_ui.setup(bank, _active_player)
		bank_ui.closed.connect(func():
			update_interaction_prompt()
		)

func toggle_pause_menu() -> void:
	var pm = get_node_or_null("PauseMenu")
	if not pm:
		var hud_control = get_node_or_null("HUDControl")
		if hud_control:
			pm = hud_control.get_node_or_null("PauseMenu")
			
	if pm:
		get_tree().paused = false
		if _active_player:
			_active_player.unfreeze()
		pm.queue_free()
	else:
		inventory_panel.hide()
		build_panel.hide()
		market_ui.hide()
		crafting_ui.hide()
		
		var pm_scene = load("res://common/ui/pause_menu.tscn")
		if pm_scene:
			var inst = pm_scene.instantiate()
			inst.name = "PauseMenu"
			var hud_control = get_node_or_null("HUDControl")
			if hud_control:
				hud_control.add_child(inst)
			else:
				add_child(inst)
			get_tree().paused = true
			if _active_player:
				_active_player.freeze()

func _link_inventory_grid_focus() -> void:
	if not inventory_grid:
		return
	var slots_count = inventory_grid.get_child_count()
	if slots_count == 0:
		return
		
	var cols = 2
	var rows = []
	var current_row = []
	for i in range(slots_count):
		var slot = inventory_grid.get_child(i)
		if slot is PanelContainer and slot.focus_mode == Control.FOCUS_ALL:
			current_row.append(slot)
		if current_row.size() == cols or i == slots_count - 1:
			if not current_row.is_empty():
				rows.append(current_row)
				current_row = []
				
	if rows.is_empty():
		return
		
	for r in range(rows.size()):
		for c in range(rows[r].size()):
			var slot = rows[r][c]
			
			# Left:
			if c > 0:
				slot.focus_neighbor_left = rows[r][c - 1].get_path()
			else:
				slot.focus_neighbor_left = slot.get_path()
				
			# Right:
			if c < rows[r].size() - 1:
				slot.focus_neighbor_right = rows[r][c + 1].get_path()
			else:
				if career_tab_container:
					slot.focus_neighbor_right = career_tab_container.get_path()
				else:
					slot.focus_neighbor_right = slot.get_path()
					
			# Top:
			if r > 0:
				var target_c = min(c, rows[r - 1].size() - 1)
				slot.focus_neighbor_top = rows[r - 1][target_c].get_path()
			else:
				slot.focus_neighbor_top = slot.get_path()
				
			# Bottom:
			if r < rows.size() - 1:
				var target_c = min(c, rows[r + 1].size() - 1)
				slot.focus_neighbor_bottom = rows[r + 1][target_c].get_path()
			else:
				slot.focus_neighbor_bottom = slot.get_path()
		
	if career_tab_container and rows.size() > 0:
		career_tab_container.focus_neighbor_left = rows[0][0].get_path()

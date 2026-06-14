extends CanvasLayer

# Outlets to UI children
@onready var gold_label: Label = %GoldLabel
@onready var time_label: Label = %TimeLabel
@onready var farmer_level_label: Label = %FarmerLevelLabel
@onready var farmer_xp_bar: ProgressBar = %FarmerXPBar
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
@onready var farmer_list: VBoxContainer = %FarmerList
@onready var craftsman_list: VBoxContainer = %CraftsmanList
@onready var tailor_list: VBoxContainer = %TailorList

# Left Column Profile Panel Outlets
@onready var profile_gold_label: Label = %ProfileGoldLabel
@onready var profile_time_label: Label = %ProfileTimeLabel

# Right Column TabContainer & Career Outlets
@onready var career_tab_container: TabContainer = %CareerTabContainer

@onready var farmer_progress_label: Label = %FarmerProgressLabel
@onready var farmer_progress_bar: ProgressBar = %FarmerProgressBar
@onready var farmer_recipe_list: VBoxContainer = %FarmerRecipeList

@onready var craftsman_progress_label: Label = %CraftsmanProgressLabel
@onready var craftsman_progress_bar: ProgressBar = %CraftsmanProgressBar
@onready var craftsman_recipe_list: VBoxContainer = %CraftsmanRecipeList

@onready var tailor_progress_label: Label = %TailorProgressLabel
@onready var tailor_progress_bar: ProgressBar = %TailorProgressBar
@onready var tailor_recipe_list: VBoxContainer = %TailorRecipeList

var _active_player: Player = null
var _all_recipes: Array = []
var pause_menu: PanelContainer = null

# Placement State Variables
var _placement_active: bool = false
var _placement_mode: String = "" # "place", "move", "demolish"
var _placement_scene_path: String = ""
var _placement_gold_cost: int = 0
var _placement_build_time: float = 3.0
var _placement_building_name: String = ""
var _placement_ghost: Node2D = null
var _placement_ghost_shape: Shape2D = null
var _placement_original_pos: Vector2 = Vector2.ZERO
var _placement_moving_node: Node2D = null
var _hovered_workstation: Node2D = null
var _placement_position: Vector2 = Vector2.ZERO
var _key_repeat_delay: float = 0.12
var _key_repeat_timer: float = 0.0
var _original_camera_zoom: Vector2 = Vector2.ONE
var _camera_reference: Camera2D = null
var _placement_using_keyboard: bool = false
var _placement_foundation_fill: ColorRect = null
var _placement_foundation_outline: ReferenceRect = null
var _placement_active_lot: Node2D = null
var _placement_original_lot: Node2D = null
var _available_lots: Array = []
var _active_lot_index: int = 0
var _placement_building_db_item: Dictionary = {}
var _active_bank = null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("PlayerHUD")
	_create_pause_menu()
	
	# Load recipes once at startup
	_load_all_recipes()
	
	# Connect to player if already exists
	_find_player()
	
	# Hide overlays initially
	interact_prompt.hide()
	inventory_panel.hide()
	market_ui.hide()
	crafting_ui.hide()
	
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
		
	# Wire up Build Menu buttons
	if build_close_button:
		build_close_button.pressed.connect(toggle_build_menu)
		_setup_button_hover(build_close_button)
		
	if move_tool_button:
		move_tool_button.pressed.connect(func(): _start_placement("move", "", 0))
		_setup_button_hover(move_tool_button)
		
	if demolish_tool_button:
		demolish_tool_button.pressed.connect(func(): _start_placement("demolish", "", 0))
		_setup_button_hover(demolish_tool_button)
		
	# Rename tabs to match new classifications
	if build_tab_container:
		build_tab_container.set_tab_title(0, "All")
		build_tab_container.set_tab_title(1, "Home")
		build_tab_container.set_tab_title(2, "Production")
		build_tab_container.set_tab_title(3, "Renting")




func _process(delta: float) -> void:
	if get_tree().paused:
		return
		
	if not _active_player:
		_find_player()
		
	# Check for build menu toggle input (B key)
	if Input.is_action_just_pressed("toggle_build_menu"):
		if not market_ui.visible and not crafting_ui.visible and not inventory_panel.visible:
			if _placement_active:
				_exit_placement_mode()
			else:
				toggle_build_menu()
				
	# Check for inventory toggle input (I key)
	if Input.is_action_just_pressed("toggle_inventory"):
		if not market_ui.visible and not crafting_ui.visible and not build_panel.visible and not _placement_active:
			toggle_inventory()
			
	# Update active placement/move/demolish state
	if _placement_active:
		_process_placement_loop(delta)

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
		
	# Farmer
	var f_lvl = GameState.career_levels.get("farmer", 1)
	var f_xp = GameState.career_xp.get("farmer", 0)
	var f_next = GameState.get_xp_for_level(f_lvl)
	if farmer_level_label:
		farmer_level_label.text = "Farmer Lv. %d" % f_lvl
	if farmer_xp_bar:
		farmer_xp_bar.max_value = f_next
		farmer_xp_bar.value = f_xp
		
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

func update_interaction_prompt() -> void:
	if not interact_prompt or not _active_player or _placement_active:
		return
		
	var facing = _active_player.get_facing_interactables()
	if facing.size() > 0:
		var interactable = facing[0]
		var target = interactable
		var grid = _active_player._get_grid_for_crop(interactable)
		if grid:
			target = grid
			
		var text = ""
		
		# If the object has ownership variables
		if "ownership_type" in target:
			var ownership = target.ownership_type
			var is_buy = target.is_buyable if "is_buyable" in target else false
			var is_rent = target.is_rentable if "is_rentable" in target else false
			var buy_val = target.buy_cost if "buy_cost" in target else 0
			var rent_val = target.rent_cost if "rent_cost" in target else 0
			
			if ownership == "NPC":
				# NPC Owned buildings cost 3x premium
				var npc_buy_cost = buy_val * 3
				text = "Locked (NPC Owned) | [R] Buy (%d G)" % npc_buy_cost
			elif ownership == "Player":
				# Already player owned! Let's display the interaction prompt normally
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text = interactable.get_interaction_text()
					if interact_prompt_text != "":
						normal_text = interact_prompt_text
				text = "[E] %s (Owned)" % normal_text
			elif ownership == "Rented":
				var current_rent_days = target.rent_days_remaining if "rent_days_remaining" in target else 0
				var max_rent_days = target.max_rent_days if "max_rent_days" in target else 5
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text = interactable.get_interaction_text()
					if interact_prompt_text != "":
						normal_text = interact_prompt_text
				
				text = "[E] %s" % normal_text
				if is_rent:
					text += " | [T] Extend (%d G, %d/%d days)" % [rent_val, current_rent_days, max_rent_days]
			else: # Public
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var interact_prompt_text = interactable.get_interaction_text()
					if interact_prompt_text != "":
						normal_text = interact_prompt_text
				
				text = "[E] %s" % normal_text
				if is_buy:
					text += " | [R] Buy (%d G)" % buy_val
				if is_rent:
					var max_rent_days = target.max_rent_days if "max_rent_days" in target else 5
					text += " | [T] Rent (%d G/day, max %d days)" % [rent_val, max_rent_days]
		else:
			# Normal objects without ownership
			var normal_text = "Interact"
			if interactable.has_method("get_interaction_text"):
				var interact_prompt_text = interactable.get_interaction_text()
				if interact_prompt_text != "":
					normal_text = interact_prompt_text
			text = "[E] %s" % normal_text
			
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
	else:
		update_inventory_panel()
		inventory_panel.show()
		# Scale animation
		inventory_panel.pivot_offset = inventory_panel.size / 2.0
		inventory_panel.scale = Vector2(0.9, 0.9)
		var tween = create_tween()
		tween.tween_property(inventory_panel, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	
	# Draw active slots
	for slot in slots:
		var item: ItemData = slot["item"]
		var amount: int = slot["amount"]
		
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(64, 64)
		
		# Define styling
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.22, 0.8)
		style.set_border_width_all(2)
		style.border_color = Color(0.35, 0.35, 0.45, 0.8)
		style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", style)
		
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
		slot_panel.tooltip_text = "%s\nCategory: %s\nWeight: %.1f\nValue: %d Gold" % [item.name, item.category, item.weight, item.base_value]
		
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

# Market UI operations
func open_market(stall: MarketStall) -> void:
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

# Crafting UI operations
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
	# Check if career tab container is present
	if not career_tab_container:
		return
		
	# Update each career
	var careers = ["farmer", "craftsman", "tailor"]
	for i in range(careers.size()):
		var career = careers[i]
		var lvl = GameState.career_levels.get(career, 1)
		var xp = GameState.career_xp.get(career, 0)
		var next_xp = GameState.get_xp_for_level(lvl)
		
		# 1. Update Tab Title dynamically with level indicator
		career_tab_container.set_tab_title(i, "%s (Lv. %d)" % [career.capitalize(), lvl])
		
		# 2. Update Progress Bar & Label
		var progress_label: Label = null
		var progress_bar: ProgressBar = null
		var recipe_list_container: VBoxContainer = null
		
		match career:
			"farmer":
				progress_label = farmer_progress_label
				progress_bar = farmer_progress_bar
				recipe_list_container = farmer_recipe_list
			"craftsman":
				progress_label = craftsman_progress_label
				progress_bar = craftsman_progress_bar
				recipe_list_container = craftsman_recipe_list
			"tailor":
				progress_label = tailor_progress_label
				progress_bar = tailor_progress_bar
				recipe_list_container = tailor_recipe_list
				
		if progress_label:
			progress_label.text = "%d / %d XP" % [xp, next_xp]
		if progress_bar:
			progress_bar.max_value = next_xp
			progress_bar.value = xp
			
		# 3. Populate recipe cards
		if recipe_list_container:
			# Clear old cards
			for child in recipe_list_container.get_children():
				child.queue_free()
				
			var career_recipes = []
			for r in _all_recipes:
				if r.required_career == career:
					career_recipes.append(r)
					
			# Sort recipes by level requirement
			career_recipes.sort_custom(func(a, b):
				return a.required_level < b.required_level
			)
			
			if career_recipes.is_empty():
				var empty_label = Label.new()
				empty_label.text = "No recipes found for this career."
				empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				empty_label.add_theme_font_size_override("font_size", 12)
				empty_label.modulate = Color(0.6, 0.6, 0.6, 0.8)
				recipe_list_container.add_child(empty_label)
				continue
				
			for recipe in career_recipes:
				var is_locked = lvl < recipe.required_level
				
				var card = PanelContainer.new()
				card.custom_minimum_size = Vector2(0, 50)
				
				# Style card based on lock state
				var style = StyleBoxFlat.new()
				style.set_corner_radius_all(6)
				style.content_margin_left = 10
				style.content_margin_right = 10
				style.content_margin_top = 8
				style.content_margin_bottom = 8
				
				if is_locked:
					style.bg_color = Color(0.12, 0.12, 0.16, 0.4)
					style.border_color = Color(0.24, 0.24, 0.3, 0.3)
					style.set_border_width_all(1)
				else:
					style.bg_color = Color(0.16, 0.18, 0.24, 0.75)
					style.border_color = Color(0.28, 0.38, 0.52, 0.6)
					style.set_border_width_all(1)
					
				card.add_theme_stylebox_override("panel", style)
				
				var vbox = VBoxContainer.new()
				vbox.add_theme_constant_override("separation", 4)
				card.add_child(vbox)
				
				var hbox_title = HBoxContainer.new()
				vbox.add_child(hbox_title)
				
				# Recipe Name
				var name_lbl = Label.new()
				name_lbl.text = recipe.recipe_name
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_lbl.add_theme_font_size_override("font_size", 12)
				if is_locked:
					name_lbl.modulate = Color(0.6, 0.6, 0.6, 0.8)
				else:
					name_lbl.modulate = Color(0.9, 0.9, 0.95, 1)
				hbox_title.add_child(name_lbl)
				
				# Status label (Level Requirement / XP Reward)
				var status_lbl = Label.new()
				status_lbl.add_theme_font_size_override("font_size", 11)
				if is_locked:
					status_lbl.text = "Requires Lv. %d" % recipe.required_level
					status_lbl.modulate = Color(0.85, 0.35, 0.35, 1)
				else:
					status_lbl.text = "+%d XP" % recipe.xp_reward
					status_lbl.modulate = Color(0.35, 0.85, 0.35, 1)
				hbox_title.add_child(status_lbl)
				
				# Ingredients list
				var details_lbl = Label.new()
				details_lbl.add_theme_font_size_override("font_size", 10)
				details_lbl.modulate = Color(0.7, 0.7, 0.75, 0.8)
				
				var inputs_text = "Requires: "
				var inputs_list = []
				for input_item in recipe.inputs:
					var req = recipe.inputs[input_item]
					var owned = GameState.player_inventory.get_item_amount(input_item.id)
					inputs_list.append("%s (%d/%d)" % [input_item.name, owned, req])
				inputs_text += ", ".join(inputs_list)
				inputs_text += " | Yields: %d %s" % [recipe.output_amount, recipe.output_item.name]
				details_lbl.text = inputs_text
				vbox.add_child(details_lbl)
				
				recipe_list_container.add_child(card)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _placement_active:
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
			
		build_panel.show()
		if _active_player:
			_active_player.freeze()
			
		build_panel.pivot_offset = build_panel.size / 2.0
		build_panel.scale = Vector2(0.9, 0.9)
		var tween = create_tween()
		tween.tween_property(build_panel, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

const BUILD_DATABASE = [
	# --- Farmer ---
	{
		"id": "farmer_field",
		"name": "Wheat Field",
		"career": "farmer",
		"tier": 1,
		"level": 1,
		"cost": 20,
		"time": 3.0,
		"scene_path": "res://components/gathering/wheat_field_grid.tscn",
		"type": "gathering",
		"env": "outside",
		"description": "A 4x4 wheat crop plot grid to grow wheat."
	},
	{
		"id": "farmer_mill",
		"name": "Flour Mill",
		"career": "farmer",
		"tier": 1,
		"level": 1,
		"cost": 120,
		"time": 5.0,
		"scene_path": "res://components/production/mill.tscn",
		"type": "production",
		"env": "outside",
		"description": "Walk-in building with a mill station to grind wheat."
	},
	{
		"id": "farmer_field_t2",
		"name": "Advanced Field",
		"career": "farmer",
		"tier": 2,
		"level": 3,
		"cost": 250,
		"time": 6.0,
		"scene_path": "",
		"type": "gathering",
		"env": "outside",
		"description": "T2 Gathering: Yields richer wheat crops."
	},
	{
		"id": "farmer_mill_t2",
		"name": "Windmill",
		"career": "farmer",
		"tier": 2,
		"level": 3,
		"cost": 500,
		"time": 10.0,
		"scene_path": "",
		"type": "production",
		"env": "outside",
		"description": "T2 Production: Automatically processes flour."
	},
	{
		"id": "farmer_field_t3",
		"name": "Industrial Field",
		"career": "farmer",
		"tier": 3,
		"level": 5,
		"cost": 800,
		"time": 12.0,
		"scene_path": "",
		"type": "gathering",
		"env": "outside",
		"description": "T3 Gathering: Massive crop yields."
	},
	{
		"id": "farmer_mill_t3",
		"name": "Automated Bakery",
		"career": "farmer",
		"tier": 3,
		"level": 5,
		"cost": 1500,
		"time": 20.0,
		"scene_path": "",
		"type": "production",
		"env": "outside",
		"description": "T3 Production: Industrial-scale bread baking."
	},
	
	# --- Craftsman ---
	{
		"id": "craftsman_mine",
		"name": "Ore Mine",
		"career": "craftsman",
		"tier": 1,
		"level": 1,
		"cost": 40,
		"time": 4.0,
		"scene_path": "res://components/gathering/ore_mine.tscn",
		"type": "gathering",
		"env": "outside",
		"description": "A mining shaft yielding iron ore daily."
	},
	{
		"id": "craftsman_smelter",
		"name": "Smelter",
		"career": "craftsman",
		"tier": 1,
		"level": 1,
		"cost": 140,
		"time": 6.0,
		"scene_path": "res://components/production/smelter.tscn",
		"type": "production",
		"env": "outside",
		"description": "Walk-in smelter building to turn iron ore into ingots."
	},
	{
		"id": "craftsman_mine_t2",
		"name": "Deep Mine",
		"career": "craftsman",
		"tier": 2,
		"level": 3,
		"cost": 300,
		"time": 8.0,
		"scene_path": "",
		"type": "gathering",
		"env": "outside",
		"description": "T2 Gathering: Yields iron and coal."
	},
	{
		"id": "craftsman_smelter_t2",
		"name": "Blast Furnace",
		"career": "craftsman",
		"tier": 2,
		"level": 3,
		"cost": 600,
		"time": 12.0,
		"scene_path": "",
		"type": "production",
		"env": "outside",
		"description": "T2 Production: Speeds up iron ingot smelting."
	},
	{
		"id": "craftsman_mine_t3",
		"name": "Quarry",
		"career": "craftsman",
		"tier": 3,
		"level": 5,
		"cost": 900,
		"time": 15.0,
		"scene_path": "",
		"type": "gathering",
		"env": "outside",
		"description": "T3 Gathering: Yields high-tier gold and gems."
	},
	{
		"id": "craftsman_smelter_t3",
		"name": "Foundry",
		"career": "craftsman",
		"tier": 3,
		"level": 5,
		"cost": 1800,
		"time": 25.0,
		"scene_path": "",
		"type": "production",
		"env": "outside",
		"description": "T3 Production: Automatic alloy production."
	},

	# --- Tailor ---
	{
		"id": "tailor_patch",
		"name": "Cotton Patch",
		"career": "tailor",
		"tier": 1,
		"level": 1,
		"cost": 30,
		"time": 3.5,
		"scene_path": "res://components/gathering/cotton_patch_grid.tscn",
		"type": "gathering",
		"env": "outside",
		"description": "A 4x4 cotton field to gather raw cotton."
	},
	{
		"id": "tailor_loom",
		"name": "Loom & Table",
		"career": "tailor",
		"tier": 1,
		"level": 1,
		"cost": 130,
		"time": 5.5,
		"scene_path": "res://components/production/loom.tscn",
		"type": "production",
		"env": "outside",
		"description": "Walk-in workshop containing a weaving loom."
	},
	{
		"id": "tailor_patch_t2",
		"name": "Silk Orchard",
		"career": "tailor",
		"tier": 2,
		"level": 3,
		"cost": 280,
		"time": 7.0,
		"scene_path": "",
		"type": "gathering",
		"env": "outside",
		"description": "T2 Gathering: Yields raw silk fibers."
	},
	{
		"id": "tailor_loom_t2",
		"name": "Spinning Jenny",
		"career": "tailor",
		"tier": 2,
		"level": 3,
		"cost": 550,
		"time": 11.0,
		"scene_path": "",
		"type": "production",
		"env": "outside",
		"description": "T2 Production: Spins thread automatically."
	},
	{
		"id": "tailor_patch_t3",
		"name": "Velvet Plantation",
		"career": "tailor",
		"tier": 3,
		"level": 5,
		"cost": 850,
		"time": 14.0,
		"scene_path": "",
		"type": "gathering",
		"env": "outside",
		"description": "T3 Gathering: Rare crop yielding velvet threads."
	},
	{
		"id": "tailor_loom_t3",
		"name": "Textile Factory",
		"career": "tailor",
		"tier": 3,
		"level": 5,
		"cost": 1600,
		"time": 24.0,
		"scene_path": "",
		"type": "production",
		"env": "outside",
		"description": "T3 Production: Mass cloth weaving factory."
	},

	# --- General (Misc) ---
	{
		"id": "general_bench",
		"name": "Crafting Bench",
		"career": "",
		"tier": 1,
		"level": 1,
		"cost": 50,
		"time": 2.0,
		"scene_path": "res://components/crafting/crafting_bench.tscn",
		"type": "production",
		"env": "any",
		"description": "Standard crafting bench for flour and bread."
	},
	{
		"id": "general_stall",
		"name": "Market Stall",
		"career": "",
		"tier": 1,
		"level": 1,
		"cost": 150,
		"time": 4.0,
		"scene_path": "res://components/market/market_stall.tscn",
		"type": "production",
		"env": "outside",
		"description": "A trade stall to buy and sell goods."
	},
	{
		"id": "general_bed",
		"name": "Comfortable Bed",
		"career": "",
		"tier": 1,
		"level": 1,
		"cost": 80,
		"time": 3.0,
		"scene_path": "res://components/sleep/bed.tscn",
		"type": "production",
		"env": "inside",
		"description": "A bed to sleep in and advance to the next day."
	},
	
	# --- Real Estate and Utilities (Phase 8 additions) ---
	{
		"id": "general_house",
		"name": "Cozy House",
		"career": "",
		"tier": 1,
		"level": 1,
		"cost": 250,
		"time": 6.0,
		"scene_path": "res://components/buildings/house.tscn",
		"type": "home",
		"env": "outside",
		"description": "A personal home to sleep and store items."
	},
	{
		"id": "general_bank",
		"name": "Provincial Bank",
		"career": "banker",
		"tier": 1,
		"level": 1,
		"cost": 400,
		"time": 10.0,
		"scene_path": "res://components/production/bank.tscn",
		"type": "production",
		"env": "outside",
		"description": "Safely deposit gold and earn 5% daily interest."
	},
	{
		"id": "general_inn",
		"name": "Traveler's Inn",
		"career": "innkeeper",
		"tier": 1,
		"level": 1,
		"cost": 300,
		"time": 8.0,
		"scene_path": "res://components/production/inn.tscn",
		"type": "production",
		"env": "outside",
		"description": "Generates daily visitor revenue. Includes a free bed."
	},
	{
		"id": "rental_house",
		"name": "Rental House",
		"career": "",
		"tier": 1,
		"level": 1,
		"cost": 250,
		"time": 6.0,
		"scene_path": "res://components/buildings/house.tscn",
		"type": "renting",
		"env": "outside",
		"description": "A house to rent out to local residents for daily income."
	}
]

func _is_indoors(pos: Vector2) -> bool:
	return pos.x >= 3100.0 and pos.x <= 3400.0 and pos.y >= 3100.0 and pos.y <= 3300.0

func _get_building_info(node: Node2D) -> Dictionary:
	var name_lower = node.name.to_lower()
	var scene_path = ""
	var cost = 0
	var time = 0.0
	var db_name = ""
	
	if "mill" in name_lower:
		db_name = "Flour Mill"
		scene_path = "res://components/production/mill.tscn"
		cost = 120
		time = 5.0
	elif "smelter" in name_lower:
		db_name = "Smelter"
		scene_path = "res://components/production/smelter.tscn"
		cost = 140
		time = 6.0
	elif "loom" in name_lower:
		db_name = "Loom & Table"
		scene_path = "res://components/production/loom.tscn"
		cost = 130
		time = 5.5
	elif "wheat" in name_lower or "field" in name_lower:
		db_name = "Wheat Field"
		scene_path = "res://components/gathering/wheat_field_grid.tscn"
		cost = 20
		time = 3.0
	elif "cotton" in name_lower or "patch" in name_lower:
		db_name = "Cotton Patch"
		scene_path = "res://components/gathering/cotton_patch_grid.tscn"
		cost = 30
		time = 3.5
	elif "mine" in name_lower:
		db_name = "Ore Mine"
		scene_path = "res://components/gathering/ore_mine.tscn"
		cost = 40
		time = 4.0
	elif "bench" in name_lower:
		db_name = "Crafting Bench"
		scene_path = "res://components/crafting/crafting_bench.tscn"
		cost = 50
		time = 2.0
	elif "stall" in name_lower:
		db_name = "Market Stall"
		scene_path = "res://components/market/market_stall.tscn"
		cost = 150
		time = 4.0
	elif "bed" in name_lower:
		db_name = "Comfortable Bed"
		scene_path = "res://components/sleep/bed.tscn"
		cost = 80
		time = 3.0
	elif "bank" in name_lower:
		db_name = "Provincial Bank"
		scene_path = "res://components/production/bank.tscn"
		cost = 400
		time = 10.0
	elif "inn" in name_lower:
		db_name = "Traveler's Inn"
		scene_path = "res://components/production/inn.tscn"
		cost = 300
		time = 8.0
	elif "rental" in name_lower or "renting" in name_lower:
		db_name = "Rental House"
		scene_path = "res://components/buildings/house.tscn"
		cost = 250
		time = 6.0
	elif "house" in name_lower or "home" in name_lower:
		db_name = "Cozy House"
		scene_path = "res://components/buildings/house.tscn"
		cost = 250
		time = 6.0
		
	return {
		"name": db_name,
		"scene_path": scene_path,
		"cost": cost,
		"time": time
	}

func refresh_build_menu() -> void:
	var lists = [all_list, farmer_list, craftsman_list, tailor_list]
	for list in lists:
		if list:
			for child in list.get_children():
				child.queue_free()
				
	for building in BUILD_DATABASE:
		if all_list:
			_create_and_add_card(all_list, building)
			
		var type = building.get("type", "")
		if type == "home" and farmer_list:
			_create_and_add_card(farmer_list, building)
		elif (type == "production" or type == "gathering") and craftsman_list:
			_create_and_add_card(craftsman_list, building)
		elif type == "renting" and tailor_list:
			_create_and_add_card(tailor_list, building)

func _create_and_add_card(list: Control, building: Dictionary) -> void:
	var career = building["career"]
	var req_lvl = building["level"]
	
	var player_lvl = 1
	if career != "":
		player_lvl = GameState.career_levels.get(career, 1)
		
	var is_level_locked = player_lvl < req_lvl
	var is_gold_locked = GameState.gold < building["cost"]
	var is_locked_placeholder = building["scene_path"] == ""
	
	var is_disabled = is_level_locked or is_gold_locked or is_locked_placeholder
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	
	if is_disabled:
		style.bg_color = Color(0.12, 0.12, 0.16, 0.5)
		style.border_color = Color(0.24, 0.24, 0.3, 0.4)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.15, 0.18, 0.22, 0.85)
		style.border_color = Color(0.24, 0.65, 0.44, 0.7)
		style.set_border_width_all(1)
		
	card.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)
	
	var vbox_details = VBoxContainer.new()
	vbox_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_details.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox_details)
	
	var title_lbl = Label.new()
	var tier_suffix = " (Tier %d)" % building["tier"]
	title_lbl.text = building["name"] + tier_suffix
	title_lbl.add_theme_font_size_override("font_size", 13)
	if is_disabled:
		title_lbl.modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		title_lbl.modulate = Color(0.9, 0.95, 0.9, 1)
	vbox_details.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = building["description"]
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.modulate = Color(0.7, 0.7, 0.75, 0.8)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_details.add_child(desc_lbl)
	
	var info_lbl = Label.new()
	info_lbl.text = "Cost: %d Gold | Time: %.1fs" % [building["cost"], building["time"]]
	info_lbl.add_theme_font_size_override("font_size", 10)
	if is_gold_locked:
		info_lbl.modulate = Color(0.9, 0.5, 0.5, 0.9)
	else:
		info_lbl.modulate = Color(0.85, 0.85, 0.4, 0.9)
	vbox_details.add_child(info_lbl)
	
	var vbox_action = VBoxContainer.new()
	vbox_action.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_action.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(vbox_action)
	
	if is_locked_placeholder:
		var status_lbl = Label.new()
		status_lbl.text = "T%d Coming Soon" % building["tier"]
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.modulate = Color(0.6, 0.6, 0.6, 0.8)
		vbox_action.add_child(status_lbl)
	elif is_level_locked:
		var status_lbl = Label.new()
		status_lbl.text = "Req. %s Lv. %d" % [career.capitalize(), req_lvl]
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.modulate = Color(0.9, 0.4, 0.4, 1)
		vbox_action.add_child(status_lbl)
	else:
		var btn = Button.new()
		btn.text = "Build"
		btn.custom_minimum_size = Vector2(80, 28)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 12)
		
		var btn_style = StyleBoxFlat.new()
		btn_style.set_corner_radius_all(4)
		if is_gold_locked:
			btn.disabled = true
			btn.text = "Locked"
			btn_style.bg_color = Color(0.2, 0.12, 0.12, 0.6)
			btn_style.border_color = Color(0.4, 0.2, 0.2, 0.6)
			btn_style.set_border_width_all(1)
		else:
			btn_style.bg_color = Color(0.15, 0.45, 0.25, 0.8)
			btn_style.border_color = Color(0.3, 0.8, 0.5, 0.8)
			btn_style.set_border_width_all(1)
			
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("disabled", btn_style)
		
		btn.pressed.connect(func():
			_start_placement("place", building["scene_path"], building["cost"], building["time"], building["name"])
		)
		
		vbox_action.add_child(btn)
		_setup_button_hover(btn)
		
	list.add_child(card)

func _attach_foundation(parent_node: Node2D, size: Vector2) -> void:
	_cleanup_foundation()
	
	var foundation = Node2D.new()
	foundation.name = "FoundationHelper"
	
	_placement_foundation_fill = ColorRect.new()
	_placement_foundation_fill.size = size
	_placement_foundation_fill.position = -size / 2.0
	_placement_foundation_fill.color = Color(0.2, 0.8, 0.4, 0.3)
	_placement_foundation_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foundation.add_child(_placement_foundation_fill)
	
	_placement_foundation_outline = ReferenceRect.new()
	_placement_foundation_outline.size = size
	_placement_foundation_outline.position = -size / 2.0
	_placement_foundation_outline.border_color = Color(0.3, 0.9, 0.5, 0.9)
	_placement_foundation_outline.border_width = 2.0
	_placement_foundation_outline.editor_only = false
	_placement_foundation_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foundation.add_child(_placement_foundation_outline)
	
	parent_node.add_child(foundation)

func _cleanup_foundation() -> void:
	if _placement_foundation_fill and is_instance_valid(_placement_foundation_fill):
		var parent = _placement_foundation_fill.get_parent()
		if parent:
			parent.queue_free()
	_placement_foundation_fill = null
	_placement_foundation_outline = null

func _find_closest_settlement(pos: Vector2) -> Node2D:
	var min_dist: float = INF
	var closest: Node2D = null
	
	for city in get_tree().get_nodes_in_group("Cities"):
		var dist = pos.distance_to(city.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = city
			
	for town in get_tree().get_nodes_in_group("Towns"):
		var dist = pos.distance_to(town.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = town
			
	return closest

func _get_current_settlement(pos: Vector2) -> Node2D:
	var closest = _find_closest_settlement(pos)
	if closest:
		var radius = 600.0
		if "radius_of_influence" in closest:
			radius = closest.radius_of_influence
		if pos.distance_to(closest.global_position) <= radius:
			return closest
	return null

func _start_placement(mode: String, scene_path: String, cost: int, build_time: float = 3.0, building_name: String = "") -> void:
	build_panel.hide()
	
	_placement_active = true
	_placement_mode = mode
	_placement_scene_path = scene_path
	_placement_gold_cost = cost
	_placement_build_time = build_time
	_placement_building_name = building_name
	_placement_using_keyboard = true # default to keyboard mode for cycling
	
	_placement_building_db_item = {}
	for item in BUILD_DATABASE:
		if item["name"] == building_name and item["scene_path"] == scene_path:
			_placement_building_db_item = item
			break
			
	_available_lots.clear()
	_active_lot_index = 0
	_placement_active_lot = null
	
	if _active_player:
		_active_player.freeze()
		_placement_position = _active_player.global_position
		
		# Resolve current settlement context and available lots
		var player_settlement = _get_current_settlement(_active_player.global_position)
		if player_settlement:
			var player_pos = _active_player.global_position
			var all_lots = get_tree().get_nodes_in_group("BuildingLots")
			
			for lot in all_lots:
				if lot.has_method("calculate_lot_cost") and not lot.nearest_settlement:
					lot.calculate_lot_cost()
					
			for lot in all_lots:
				var is_vacant = not lot.is_occupied or (mode == "move" and lot == _placement_original_lot)
				if is_vacant and lot.nearest_settlement == player_settlement:
					_available_lots.append(lot)
					
			# Sort lots closest to player position first
			_available_lots.sort_custom(func(a, b):
				return player_pos.distance_to(a.global_position) < player_pos.distance_to(b.global_position)
			)
			
			if _available_lots.size() > 0:
				_placement_active_lot = _available_lots[0]
				_placement_position = _placement_active_lot.global_position
			else:
				_spawn_floating_text("No vacant lots in this settlement!", _active_player.global_position)
				_exit_placement_mode()
				return
		else:
			_spawn_floating_text("Must be inside a City or Town to build!", _active_player.global_position)
			_exit_placement_mode()
			return
				
		var camera = _active_player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			_camera_reference = camera
			_original_camera_zoom = camera.zoom
			camera.set_as_top_level(true)
			
			var tween = create_tween()
			tween.tween_property(camera, "zoom", Vector2(0.7, 0.7), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
	if mode == "place":
		var scene = load(scene_path)
		_placement_ghost = scene.instantiate()
		_placement_ghost.set_script(null)
		
		_disable_all_collisions(_placement_ghost)
		var interact = _placement_ghost.get_node_or_null("InteractionArea")
		if interact:
			interact.queue_free()
			
		_placement_ghost.modulate = Color(0.3, 0.9, 0.3, 0.6)
		_placement_ghost.global_position = _placement_position
		
		var temp_inst = scene.instantiate()
		var temp_col = temp_inst.get_node_or_null("CollisionShape2D")
		if temp_col:
			_placement_ghost_shape = temp_col.shape.duplicate()
		temp_inst.queue_free()
		
		get_parent().add_child(_placement_ghost)
		
		var rect_size = Vector2(64, 64)
		if _placement_ghost_shape is RectangleShape2D:
			rect_size = _placement_ghost_shape.size
		_attach_foundation(_placement_ghost, rect_size)

func _exit_placement_mode() -> void:
	_placement_active = false
	
	_placement_active_lot = null
	_placement_original_lot = null
	_available_lots.clear()
	_active_lot_index = 0
	for lot in get_tree().get_nodes_in_group("BuildingLots"):
		if lot.is_in_group("BuildingLots"):
			lot.is_highlighted = false
			lot.is_selected = false
			
	_cleanup_foundation()
	
	if _camera_reference and is_instance_valid(_camera_reference):
		_camera_reference.set_as_top_level(false)
		_camera_reference.position = Vector2.ZERO
		_camera_reference.zoom = _original_camera_zoom
	_camera_reference = null
	
	if _active_player:
		_active_player.unfreeze()
		
	if _placement_ghost and _placement_mode == "place":
		_placement_ghost.queue_free()
	_placement_ghost = null
	_placement_ghost_shape = null
	
	if _placement_moving_node and is_instance_valid(_placement_moving_node):
		_placement_moving_node.global_position = _placement_original_pos
		_placement_moving_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_placement_moving_node.show()
		
		_enable_all_collisions(_placement_moving_node)
			
	_placement_moving_node = null
	
	if _hovered_workstation and is_instance_valid(_hovered_workstation):
		_hovered_workstation.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_hovered_workstation = null
		
	_placement_mode = ""
	_placement_scene_path = ""
	_placement_gold_cost = 0
	_placement_build_time = 3.0
	_placement_building_name = ""
	
	update_interaction_prompt()

func _process_placement_loop(delta: float) -> void:
	# Keep active_lot synchronized
	var active_lot: Node2D = _placement_active_lot
	
	if active_lot:
		_placement_position = active_lot.global_position
		
	# Update all building lots highlight states
	for lot in get_tree().get_nodes_in_group("BuildingLots"):
		if lot.is_in_group("BuildingLots"):
			var is_available = lot in _available_lots
			if is_available:
				lot.is_highlighted = true
				lot.is_selected = (lot == active_lot)
			else:
				lot.is_highlighted = false
				lot.is_selected = false
				
	var camera_target = _placement_position
	if _camera_reference and is_instance_valid(_camera_reference):
		_camera_reference.global_position = _camera_reference.global_position.lerp(camera_target, delta * 8.0)
		
	if _placement_mode == "place":
		if _placement_ghost and is_instance_valid(_placement_ghost):
			if active_lot:
				_placement_ghost.global_position = active_lot.global_position
				_placement_ghost.show()
			else:
				_placement_ghost.hide()
			
		var distance = _active_player.global_position.distance_to(active_lot.global_position) if (_active_player and active_lot) else INF
		var is_range_valid = distance <= 250.0
		
		var is_env_valid = true
		if active_lot:
			var is_target_indoors = _is_indoors(active_lot.global_position)
			var db_item = null
			for item in BUILD_DATABASE:
				if item["scene_path"] == _placement_scene_path:
					db_item = item
					break
			if db_item:
				if db_item["env"] == "inside" and not is_target_indoors:
					is_env_valid = false
				elif db_item["env"] == "outside" and is_target_indoors:
					is_env_valid = false
		else:
			is_env_valid = false
				
		var is_collision_valid = true
		if active_lot and _placement_ghost_shape:
			is_collision_valid = _is_position_clear(active_lot.global_position, _placement_ghost_shape)
		else:
			is_collision_valid = false
			
		if active_lot and is_range_valid and is_env_valid and is_collision_valid:
			_placement_ghost.modulate = Color(0.3, 0.9, 0.3, 0.6)
			if _placement_foundation_fill:
				_placement_foundation_fill.color = Color(0.2, 0.8, 0.4, 0.35)
			if _placement_foundation_outline:
				_placement_foundation_outline.border_color = Color(0.3, 0.9, 0.5, 0.95)
		else:
			if _placement_ghost and is_instance_valid(_placement_ghost):
				_placement_ghost.modulate = Color(0.9, 0.3, 0.3, 0.6)
			if _placement_foundation_fill:
				_placement_foundation_fill.color = Color(0.9, 0.3, 0.3, 0.35)
			if _placement_foundation_outline:
				_placement_foundation_outline.border_color = Color(0.9, 0.4, 0.4, 0.95)
			
	elif _placement_mode == "move":
		if _placement_moving_node and is_instance_valid(_placement_moving_node):
			if active_lot:
				_placement_moving_node.global_position = active_lot.global_position
				_placement_moving_node.show()
			else:
				_placement_moving_node.hide()
			
			var distance = _active_player.global_position.distance_to(active_lot.global_position) if (_active_player and active_lot) else INF
			var is_range_valid = distance <= 250.0
			
			var is_env_valid = true
			if active_lot:
				var is_target_indoors = _is_indoors(active_lot.global_position)
				var info = _get_building_info(_placement_moving_node)
				var db_item = null
				for item in BUILD_DATABASE:
					if item["name"] == info.name:
						db_item = item
						break
				if db_item:
					if db_item["env"] == "inside" and not is_target_indoors:
						is_env_valid = false
					elif db_item["env"] == "outside" and is_target_indoors:
						is_env_valid = false
			else:
				is_env_valid = false
					
			var is_collision_valid = true
			if active_lot and _placement_ghost_shape:
				is_collision_valid = _is_position_clear(active_lot.global_position, _placement_ghost_shape)
			else:
				is_collision_valid = false
				
			if active_lot and is_range_valid and is_env_valid and is_collision_valid:
				_placement_moving_node.modulate = Color(0.3, 0.9, 0.3, 0.6)
				if _placement_foundation_fill:
					_placement_foundation_fill.color = Color(0.2, 0.8, 0.4, 0.35)
				if _placement_foundation_outline:
					_placement_foundation_outline.border_color = Color(0.3, 0.9, 0.5, 0.95)
			else:
				if _placement_moving_node and is_instance_valid(_placement_moving_node):
					_placement_moving_node.modulate = Color(0.9, 0.3, 0.3, 0.6)
				if _placement_foundation_fill:
					_placement_foundation_fill.color = Color(0.9, 0.3, 0.3, 0.35)
				if _placement_foundation_outline:
					_placement_foundation_outline.border_color = Color(0.9, 0.4, 0.4, 0.95)
		else:
			_process_workstation_hover()
			
	elif _placement_mode == "demolish":
		_process_workstation_hover()

	# Update HUD instruction prompt during placement/move/demolish modes
	if interact_prompt and interact_label:
		match _placement_mode:
			"place":
				var lot_cost = active_lot.calculate_lot_cost() if active_lot else 0
				var total_cost = lot_cost + _placement_gold_cost
				interact_label.text = "Press [E] or Left Click to Build %s (Lot %d + Workstation %d = %d Gold) | [ESC] or Right Click to Cancel" % [_placement_building_name, lot_cost, _placement_gold_cost, total_cost]
				interact_prompt.show()
			"move":
				if _placement_moving_node and is_instance_valid(_placement_moving_node):
					var info = _get_building_info(_placement_moving_node)
					var relocate_cost = int(info.cost * 0.75)
					var lot_cost = 0
					if active_lot and active_lot != _placement_original_lot:
						lot_cost = active_lot.calculate_lot_cost()
					var total_cost = lot_cost + relocate_cost
					interact_label.text = "Press [E] or Left Click to Place (Lot %d + Move %d = %d Gold) | [ESC] or Right Click to Cancel" % [lot_cost, relocate_cost, total_cost]
				else:
					interact_label.text = "Click on a workstation to move it | [ESC] to Cancel"
				interact_prompt.show()
			"demolish":
				interact_label.text = "Click on a workstation to demolish it (80% refund) | [ESC] to Cancel"
				interact_prompt.show()

func _process_workstation_hover() -> void:
	var global_mouse = get_parent().get_global_mouse_position()
	var found_workstation: Node2D = null
	
	var groups = ["CraftingBenches", "MarketStall", "WheatFields", "CottonPlants", "OreMines", "Beds"]
	for grp in groups:
		var nodes = get_tree().get_nodes_in_group(grp)
		for node in nodes:
			if node is CollisionObject2D:
				var col = node.get_node_or_null("CollisionShape2D")
				if col and col.shape is RectangleShape2D:
					var size = col.shape.size
					var rect = Rect2(node.global_position - size / 2.0, size)
					if rect.has_point(global_mouse):
						found_workstation = node
						break
		if found_workstation:
			break
			
	if found_workstation != _hovered_workstation:
		if _hovered_workstation and is_instance_valid(_hovered_workstation):
			_hovered_workstation.modulate = Color(1, 1, 1, 1)
		_hovered_workstation = found_workstation
		if _hovered_workstation:
			_hovered_workstation.modulate = Color(1.5, 1.5, 0.8, 1)

func _disable_all_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		node.set_meta("orig_layer", node.collision_layer)
		node.set_meta("orig_mask", node.collision_mask)
		node.collision_layer = 0
		node.collision_mask = 0
	if node is CollisionShape2D:
		node.disabled = true
	for child in node.get_children():
		_disable_all_collisions(child)

func _enable_all_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		if node.has_meta("orig_layer"):
			node.collision_layer = node.get_meta("orig_layer")
		else:
			node.collision_layer = 1
		if node.has_meta("orig_mask"):
			node.collision_mask = node.get_meta("orig_mask")
		else:
			node.collision_mask = 1
	if node is CollisionShape2D:
		var p_name = node.get_parent().name.to_lower()
		if node.name == "CollisionShape2D" and p_name.contains("grid"):
			node.disabled = true
		else:
			node.disabled = false
	for child in node.get_children():
		_enable_all_collisions(child)

func _collect_collision_rids(node: Node, rids: Array) -> void:
	if node is CollisionObject2D:
		rids.append(node.get_rid())
	for child in node.get_children():
		_collect_collision_rids(child, rids)

func _is_position_clear(pos: Vector2, shape: Shape2D) -> bool:
	var space_state = get_viewport().world_2d.direct_space_state
	if not space_state:
		return true
		
	var query_shape = shape
	if shape is RectangleShape2D:
		var dup = shape.duplicate() as RectangleShape2D
		dup.size += Vector2(8.0, 8.0)
		query_shape = dup
	elif shape is CircleShape2D:
		var dup = shape.duplicate() as CircleShape2D
		dup.radius += 4.0
		query_shape = dup
	elif shape is CapsuleShape2D:
		var dup = shape.duplicate() as CapsuleShape2D
		dup.radius += 4.0
		dup.height += 8.0
		query_shape = dup
		
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0, pos)
	query.collision_mask = 1
	
	var exclude_list = []
	if _placement_moving_node and is_instance_valid(_placement_moving_node):
		_collect_collision_rids(_placement_moving_node, exclude_list)
	if _placement_ghost and is_instance_valid(_placement_ghost):
		_collect_collision_rids(_placement_ghost, exclude_list)
		
	query.exclude = exclude_list
	
	var results = space_state.intersect_shape(query)
	return results.is_empty()

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

func _unhandled_input(event: InputEvent) -> void:
	if not _placement_active:
		return
		
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		_spawn_floating_text("Cancel", _active_player.global_position if _active_player else Vector2.ZERO)
		_exit_placement_mode()
		get_viewport().set_input_as_handled()
		return
		
	# Cycle available lots using A and D keys
	if _available_lots.size() > 0:
		var changed = false
		if event.is_action_pressed("move_left") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_A):
			_active_lot_index = (_active_lot_index - 1 + _available_lots.size()) % _available_lots.size()
			changed = true
		elif event.is_action_pressed("move_right") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_D):
			_active_lot_index = (_active_lot_index + 1) % _available_lots.size()
			changed = true
			
		if changed:
			_placement_active_lot = _available_lots[_active_lot_index]
			_placement_position = _placement_active_lot.global_position
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		if _placement_mode == "place":
			if not _placement_active_lot:
				_spawn_floating_text("No Lot Selected!", _placement_position)
				get_viewport().set_input_as_handled()
				return
				
			var target_pos = _placement_active_lot.global_position
			var is_range_valid = _placement_active_lot in _available_lots
			
			var is_env_valid = true
			var is_target_indoors = _is_indoors(target_pos)
			
			var db_item = null
			for item in BUILD_DATABASE:
				if item["scene_path"] == _placement_scene_path:
					db_item = item
					break
			if db_item:
				if db_item["env"] == "inside" and not is_target_indoors:
					is_env_valid = false
				elif db_item["env"] == "outside" and is_target_indoors:
					is_env_valid = false
					
			var is_collision_valid = true
			if _placement_ghost_shape:
				is_collision_valid = _is_position_clear(target_pos, _placement_ghost_shape)
				
			if is_range_valid and is_env_valid and is_collision_valid:
				var lot_price = _placement_active_lot.calculate_lot_cost()
				var total_cost = lot_price + _placement_gold_cost
				if GameState.gold < total_cost:
					_spawn_floating_text("Need %d Gold!" % total_cost, target_pos)
					return
					
				GameState.gold -= total_cost
				
				var const_site_scene = load("res://components/placement/construction_site.tscn")
				var const_site = const_site_scene.instantiate()
				const_site.global_position = target_pos
				const_site.target_scene_path = _placement_scene_path
				const_site.build_time = _placement_build_time
				const_site.building_name = _placement_building_name
				if "is_rental" in const_site:
					const_site.is_rental = _placement_building_db_item.get("type", "") == "renting"
				
				# Occupy lot immediately with the construction site
				_placement_active_lot.is_occupied = true
				_placement_active_lot.occupied_node = const_site
				
				get_parent().add_child(const_site)
				
				_spawn_floating_text("Building started! -%d Gold" % total_cost, target_pos)
				update_hud_values()
				_exit_placement_mode()
			else:
				_spawn_floating_text("Invalid Position!", target_pos)
			get_viewport().set_input_as_handled()
			
		elif _placement_mode == "move":
			if _placement_moving_node and is_instance_valid(_placement_moving_node):
				if not _placement_active_lot:
					_spawn_floating_text("No Lot Selected!", _placement_position)
					get_viewport().set_input_as_handled()
					return
					
				var target_pos = _placement_active_lot.global_position
				var is_range_valid = _placement_active_lot in _available_lots
				
				var is_env_valid = true
				var is_target_indoors = _is_indoors(target_pos)
				
				var info = _get_building_info(_placement_moving_node)
				var db_item = null
				for item in BUILD_DATABASE:
					if item["name"] == info.name:
						db_item = item
						break
				if db_item:
					if db_item["env"] == "inside" and not is_target_indoors:
						is_env_valid = false
					elif db_item["env"] == "outside" and is_target_indoors:
						is_env_valid = false
						
				var is_collision_valid = true
				if _placement_ghost_shape:
					is_collision_valid = _is_position_clear(target_pos, _placement_ghost_shape)
					
				if is_range_valid and is_env_valid and is_collision_valid:
					var relocate_cost = int(info.cost * 0.75)
					var lot_price = 0
					if _placement_active_lot != _placement_original_lot:
						lot_price = _placement_active_lot.calculate_lot_cost()
					var total_cost = relocate_cost + lot_price
					
					if GameState.gold < total_cost:
						_spawn_floating_text("Need %d Gold!" % total_cost, target_pos)
						return
						
					GameState.gold -= total_cost
					
					var const_site_scene = load("res://components/placement/construction_site.tscn")
					var const_site = const_site_scene.instantiate()
					const_site.global_position = target_pos
					const_site.target_scene_path = info.scene_path
					const_site.build_time = info.time
					const_site.building_name = info.name
					
					# Free old lot
					if _placement_original_lot and _placement_original_lot != _placement_active_lot:
						_placement_original_lot.is_occupied = false
						_placement_original_lot.occupied_node = null
						
					# Occupy new lot
					_placement_active_lot.is_occupied = true
					_placement_active_lot.occupied_node = const_site
					
					get_parent().add_child(const_site)
					
					_spawn_floating_text("Relocating! -%d Gold" % total_cost, target_pos)
					
					if _active_player:
						_active_player.unregister_interactable(_placement_moving_node)
						
					_placement_moving_node.remove_from_group("CraftingBenches")
					_placement_moving_node.remove_from_group("MarketStall")
					_placement_moving_node.remove_from_group("WheatFields")
					_placement_moving_node.remove_from_group("CottonPlants")
					_placement_moving_node.remove_from_group("OreMines")
					_placement_moving_node.remove_from_group("Beds")
					_placement_moving_node.queue_free()
					_placement_moving_node = null
					
					update_hud_values()
					_exit_placement_mode()
				else:
					_spawn_floating_text("Invalid Position!", target_pos)
				get_viewport().set_input_as_handled()
			else:
				if _hovered_workstation and is_instance_valid(_hovered_workstation):
					var distance = _active_player.global_position.distance_to(_hovered_workstation.global_position) if _active_player else 0.0
					if distance > 160.0:
						_spawn_floating_text("Too far!", _hovered_workstation.global_position)
						return
						
					_placement_moving_node = _hovered_workstation
					_placement_original_pos = _hovered_workstation.global_position
					
					_placement_original_lot = null
					for lot in get_tree().get_nodes_in_group("BuildingLots"):
						if lot.is_in_group("BuildingLots") and lot.occupied_node == _placement_moving_node:
							_placement_original_lot = lot
							break
							
					# Populate available lots for cycling in move mode
					_available_lots.clear()
					_active_lot_index = 0
					_placement_active_lot = null
					
					var player_settlement = _get_current_settlement(_active_player.global_position)
					if player_settlement:
						var player_pos = _active_player.global_position
						var all_lots = get_tree().get_nodes_in_group("BuildingLots")
						for lot in all_lots:
							if lot.has_method("calculate_lot_cost") and not lot.nearest_settlement:
								lot.calculate_lot_cost()
								
						for lot in all_lots:
							var is_vacant = not lot.is_occupied or lot == _placement_original_lot
							if is_vacant and lot.nearest_settlement == player_settlement:
								_available_lots.append(lot)
								
						# Sort closest first
						_available_lots.sort_custom(func(a, b):
							return player_pos.distance_to(a.global_position) < player_pos.distance_to(b.global_position)
						)
						
						if _available_lots.size() > 0:
							var orig_idx = _available_lots.find(_placement_original_lot)
							if orig_idx != -1:
								_active_lot_index = orig_idx
							_placement_active_lot = _available_lots[_active_lot_index]
							_placement_position = _placement_active_lot.global_position
						else:
							_spawn_floating_text("No vacant lots in this settlement!", _active_player.global_position)
							_exit_placement_mode()
							return
					else:
						_spawn_floating_text("Must be inside a City or Town to move buildings!", _active_player.global_position)
						_exit_placement_mode()
						return
					
					_disable_all_collisions(_placement_moving_node)
					var col = _placement_moving_node.get_node_or_null("CollisionShape2D")
					_placement_ghost_shape = col.shape.duplicate() if col else null
					_placement_moving_node.modulate = Color(0.3, 0.9, 0.3, 0.6)
					
					var rect_size = Vector2(64, 64)
					if _placement_ghost_shape is RectangleShape2D:
						rect_size = _placement_ghost_shape.size
					_attach_foundation(_placement_moving_node, rect_size)
					
					_hovered_workstation = null
					_spawn_floating_text("Moving...", _placement_position)
					get_viewport().set_input_as_handled()
					
		elif _placement_mode == "demolish":
			if _hovered_workstation and is_instance_valid(_hovered_workstation):
				var distance = _active_player.global_position.distance_to(_hovered_workstation.global_position) if _active_player else 0.0
				if distance > 160.0:
					_spawn_floating_text("Too far!", _hovered_workstation.global_position)
					return
					
				var info = _get_building_info(_hovered_workstation)
				var refund = int(info.cost * 0.8)
				
				GameState.gold += refund
				_spawn_floating_text("Demolished! +%d Gold" % refund, _hovered_workstation.global_position)
				
				# Free the lot occupied by this workstation
				for lot in get_tree().get_nodes_in_group("BuildingLots"):
					if lot.is_in_group("BuildingLots") and lot.occupied_node == _hovered_workstation:
						lot.is_occupied = false
						lot.occupied_node = null
						break
				
				if _active_player:
					_active_player.unregister_interactable(_hovered_workstation)
					
				_hovered_workstation.remove_from_group("CraftingBenches")
				_hovered_workstation.remove_from_group("MarketStall")
				_hovered_workstation.remove_from_group("WheatFields")
				_hovered_workstation.remove_from_group("CottonPlants")
				_hovered_workstation.remove_from_group("OreMines")
				_hovered_workstation.remove_from_group("Beds")
				_hovered_workstation.queue_free()
				_hovered_workstation = null
				
				update_hud_values()
				_exit_placement_mode()
				get_viewport().set_input_as_handled()

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


func exit_placement_mode_external() -> void:
	if _placement_active:
		_exit_placement_mode()


func _create_pause_menu() -> void:
	pause_menu = PanelContainer.new()
	pause_menu.name = "PauseMenu"
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.24, 0.6, 0.86, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	pause_menu.add_theme_stylebox_override("panel", style)
	
	pause_menu.custom_minimum_size = Vector2(280, 260)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	pause_menu.add_child(vbox)
	
	var title = Label.new()
	title.text = "Game Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 3)
	vbox.add_child(title)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)
	
	var resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(0, 36)
	var style_resume = StyleBoxFlat.new()
	style_resume.bg_color = Color(0.12, 0.44, 0.28, 0.8)
	style_resume.border_color = Color(0.2, 0.72, 0.44, 0.8)
	style_resume.set_border_width_all(1)
	style_resume.set_corner_radius_all(6)
	resume_btn.add_theme_stylebox_override("normal", style_resume)
	resume_btn.add_theme_stylebox_override("hover", style_resume)
	resume_btn.add_theme_stylebox_override("pressed", style_resume)
	resume_btn.pressed.connect(toggle_pause_menu)
	vbox.add_child(resume_btn)
	_setup_button_hover(resume_btn)
	
	var save_btn = Button.new()
	save_btn.text = "Save Game (F5)"
	save_btn.custom_minimum_size = Vector2(0, 36)
	var style_save = StyleBoxFlat.new()
	style_save.bg_color = Color(0.12, 0.36, 0.55, 0.8)
	style_save.border_color = Color(0.24, 0.6, 0.86, 0.8)
	style_save.set_border_width_all(1)
	style_save.set_corner_radius_all(6)
	save_btn.add_theme_stylebox_override("normal", style_save)
	save_btn.add_theme_stylebox_override("hover", style_save)
	save_btn.add_theme_stylebox_override("pressed", style_save)
	save_btn.pressed.connect(func():
		GameState.save_game()
	)
	vbox.add_child(save_btn)
	_setup_button_hover(save_btn)
	
	var load_btn = Button.new()
	load_btn.text = "Load Game (F9)"
	load_btn.custom_minimum_size = Vector2(0, 36)
	var style_load = StyleBoxFlat.new()
	style_load.bg_color = Color(0.28, 0.22, 0.46, 0.8)
	style_load.border_color = Color(0.48, 0.38, 0.74, 0.8)
	style_load.set_border_width_all(1)
	style_load.set_corner_radius_all(6)
	load_btn.add_theme_stylebox_override("normal", style_load)
	load_btn.add_theme_stylebox_override("hover", style_load)
	load_btn.add_theme_stylebox_override("pressed", style_load)
	load_btn.pressed.connect(func():
		GameState.load_game()
	)
	vbox.add_child(load_btn)
	_setup_button_hover(load_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "Quit to Desktop"
	quit_btn.custom_minimum_size = Vector2(0, 36)
	var style_quit = StyleBoxFlat.new()
	style_quit.bg_color = Color(0.36, 0.16, 0.16, 0.8)
	style_quit.border_color = Color(0.68, 0.24, 0.24, 0.8)
	style_quit.set_border_width_all(1)
	style_quit.set_corner_radius_all(6)
	quit_btn.add_theme_stylebox_override("normal", style_quit)
	quit_btn.add_theme_stylebox_override("hover", style_quit)
	quit_btn.add_theme_stylebox_override("pressed", style_quit)
	quit_btn.pressed.connect(func():
		get_tree().quit()
	)
	vbox.add_child(quit_btn)
	_setup_button_hover(quit_btn)
	
	var hud_control = get_node_or_null("HUDControl")
	if hud_control:
		hud_control.add_child(pause_menu)
		pause_menu.anchors_preset = Control.LayoutPreset.PRESET_CENTER
		pause_menu.grow_horizontal = Control.GrowDirection.GROW_DIRECTION_BOTH
		pause_menu.grow_vertical = Control.GrowDirection.GROW_DIRECTION_BOTH
		pause_menu.size = pause_menu.custom_minimum_size
		pause_menu.anchor_left = 0.5
		pause_menu.anchor_right = 0.5
		pause_menu.anchor_top = 0.5
		pause_menu.anchor_bottom = 0.5
		pause_menu.offset_left = -pause_menu.custom_minimum_size.x / 2.0
		pause_menu.offset_right = pause_menu.custom_minimum_size.x / 2.0
		pause_menu.offset_top = -pause_menu.custom_minimum_size.y / 2.0
		pause_menu.offset_bottom = pause_menu.custom_minimum_size.y / 2.0


func toggle_pause_menu() -> void:
	if not pause_menu:
		return
		
	if pause_menu.visible:
		pause_menu.hide()
		get_tree().paused = false
		if _active_player:
			_active_player.unfreeze()
	else:
		inventory_panel.hide()
		build_panel.hide()
		market_ui.hide()
		crafting_ui.hide()
		
		pause_menu.show()
		get_tree().paused = true
		if _active_player:
			_active_player.freeze()
			
		pause_menu.pivot_offset = pause_menu.size / 2.0
		pause_menu.scale = Vector2(0.9, 0.9)
		var tween = create_tween()
		tween.tween_property(pause_menu, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func open_bank(bank) -> void:
	if get_node_or_null("BankUI"):
		return
	_active_bank = bank
	if _active_player:
		_active_player.freeze()
	interact_prompt.hide()
	
	var bank_ui = PanelContainer.new()
	bank_ui.name = "BankUI"
	add_child(bank_ui)
	
	# Premium glassmorphic style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	style.border_color = Color(0.24, 0.52, 0.85, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	bank_ui.add_theme_stylebox_override("panel", style)
	
	# Set size and center
	bank_ui.custom_minimum_size = Vector2(320, 240)
	bank_ui.set_anchors_preset(Control.PRESET_CENTER)
	bank_ui.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bank_ui.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	bank_ui.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Provincial Bank"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.4, 0.75, 1.0, 1.0)
	vbox.add_child(title)
	
	# Subtitle/interest description
	var desc = Label.new()
	desc.text = "Earns 5% daily interest overnight."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 10)
	desc.modulate = Color(0.6, 0.6, 0.6, 0.8)
	vbox.add_child(desc)
	
	var hsep = HSeparator.new()
	vbox.add_child(hsep)
	
	# Balance info
	var balance_box = GridContainer.new()
	balance_box.columns = 2
	balance_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	balance_box.add_theme_constant_override("h_separation", 16)
	balance_box.add_theme_constant_override("v_separation", 6)
	vbox.add_child(balance_box)
	
	var wallet_lbl = Label.new()
	wallet_lbl.text = "Wallet:"
	wallet_lbl.add_theme_font_size_override("font_size", 12)
	balance_box.add_child(wallet_lbl)
	
	var wallet_val = Label.new()
	wallet_val.name = "WalletValue"
	wallet_val.text = "%d G" % GameState.gold
	wallet_val.add_theme_font_size_override("font_size", 12)
	wallet_val.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	balance_box.add_child(wallet_val)
	
	var bank_lbl = Label.new()
	bank_lbl.text = "Savings Balance:"
	bank_lbl.add_theme_font_size_override("font_size", 12)
	balance_box.add_child(bank_lbl)
	
	var bank_val = Label.new()
	bank_val.name = "BankValue"
	bank_val.text = "%d G" % GameState.bank_balance
	bank_val.add_theme_font_size_override("font_size", 12)
	bank_val.add_theme_color_override("font_color", Color(0.35, 0.85, 0.35))
	balance_box.add_child(bank_val)
	
	# Amount input
	var input_hbox = HBoxContainer.new()
	input_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(input_hbox)
	
	var amount_input = LineEdit.new()
	amount_input.name = "AmountInput"
	amount_input.placeholder_text = "Enter amount..."
	amount_input.custom_minimum_size = Vector2(140, 30)
	amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_input.add_theme_font_size_override("font_size", 12)
	input_hbox.add_child(amount_input)
	
	# Quick actions
	var quick_hbox = HBoxContainer.new()
	quick_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(quick_hbox)
	
	var dep_all_btn = Button.new()
	dep_all_btn.text = "Deposit All"
	dep_all_btn.add_theme_font_size_override("font_size", 11)
	quick_hbox.add_child(dep_all_btn)
	_setup_button_hover(dep_all_btn)
	
	var wd_all_btn = Button.new()
	wd_all_btn.text = "Withdraw All"
	wd_all_btn.add_theme_font_size_override("font_size", 11)
	quick_hbox.add_child(wd_all_btn)
	_setup_button_hover(wd_all_btn)
	
	# Main actions
	var action_hbox = HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(action_hbox)
	
	var dep_btn = Button.new()
	dep_btn.text = "Deposit"
	dep_btn.custom_minimum_size = Vector2(90, 32)
	dep_btn.add_theme_font_size_override("font_size", 12)
	action_hbox.add_child(dep_btn)
	_setup_button_hover(dep_btn)
	
	var wd_btn = Button.new()
	wd_btn.text = "Withdraw"
	wd_btn.custom_minimum_size = Vector2(90, 32)
	wd_btn.add_theme_font_size_override("font_size", 12)
	action_hbox.add_child(wd_btn)
	_setup_button_hover(wd_btn)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 28)
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_btn)
	_setup_button_hover(close_btn)
	
	# Logic connections
	var update_ui = func():
		wallet_val.text = "%d G" % GameState.gold
		bank_val.text = "%d G" % GameState.bank_balance
		amount_input.text = ""
		update_hud_values()
		
	dep_btn.pressed.connect(func():
		var amt = amount_input.text.to_int()
		if amt <= 0:
			_spawn_floating_text("Enter valid amount!", _active_player.global_position)
			return
		if GameState.gold < amt:
			_spawn_floating_text("Not enough gold!", _active_player.global_position)
			return
		GameState.gold -= amt
		GameState.bank_balance += amt
		update_ui.call()
		_spawn_floating_text("Deposited %d G" % amt, _active_player.global_position)
	)
	
	wd_btn.pressed.connect(func():
		var amt = amount_input.text.to_int()
		if amt <= 0:
			_spawn_floating_text("Enter valid amount!", _active_player.global_position)
			return
		if GameState.bank_balance < amt:
			_spawn_floating_text("Not enough in bank!", _active_player.global_position)
			return
		GameState.bank_balance -= amt
		GameState.gold += amt
		update_ui.call()
		_spawn_floating_text("Withdrew %d G" % amt, _active_player.global_position)
	)
	
	dep_all_btn.pressed.connect(func():
		var amt = GameState.gold
		if amt <= 0:
			_spawn_floating_text("No gold to deposit!", _active_player.global_position)
			return
		GameState.gold = 0
		GameState.bank_balance += amt
		update_ui.call()
		_spawn_floating_text("Deposited all %d G" % amt, _active_player.global_position)
	)
	
	wd_all_btn.pressed.connect(func():
		var amt = GameState.bank_balance
		if amt <= 0:
			_spawn_floating_text("No savings to withdraw!", _active_player.global_position)
			return
		GameState.bank_balance = 0
		GameState.gold += amt
		update_ui.call()
		_spawn_floating_text("Withdrew all %d G" % amt, _active_player.global_position)
	)
	
	close_btn.pressed.connect(func():
		bank_ui.queue_free()
		if _active_player:
			_active_player.unfreeze()
		_active_bank = null
		update_interaction_prompt()
	)
	
	# Scale animation on opening
	bank_ui.pivot_offset = Vector2(160, 120)
	bank_ui.scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.tween_property(bank_ui, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

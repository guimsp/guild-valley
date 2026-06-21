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
@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var market_ui: Control = %MarketUI
@onready var crafting_ui: Control = %CraftingUI

@onready var profile_gold_label: Label = %ProfileGoldLabel
@onready var profile_time_label: Label = %ProfileTimeLabel

var _active_player: Player = null
var _all_recipes: Array = []
var _building_ui_instance: Control = null
var _commercial_route_ui_instance: Control = null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("PlayerHUD")
	
	_load_all_recipes()
	_find_player()
	
	if interact_prompt:
		interact_prompt.setup(self)
		interact_prompt.set_prompt_text("")
	if inventory_panel:
		inventory_panel.setup(self)
		inventory_panel.hide()
		
	market_ui.hide()
	crafting_ui.hide()
	
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
	
	update_hud_values()
	
	if GameState.has_signal("gold_changed"):
		GameState.gold_changed.connect(func(new_gold): update_hud_values())
		
	if GameState.player_inventory and inventory_panel:
		GameState.player_inventory.inventory_changed.connect(inventory_panel.update_inventory_panel)
		
	TimeManager.time_changed.connect(_on_time_changed)
	_on_time_changed(TimeManager.time_hours, int(TimeManager.time_minutes), TimeManager.time_days)
	
	var panel_close_button = %PanelCloseButton
	if panel_close_button:
		panel_close_button.pressed.connect(toggle_inventory)
		_setup_button_hover(panel_close_button)
		panel_close_button.focus_mode = Control.FOCUS_NONE

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if not _active_player:
		_find_player()
		
	if Input.is_action_just_pressed("toggle_build_menu"):
		if not market_ui.visible and not crafting_ui.visible and not inventory_panel.visible:
			var pm = get_tree().get_first_node_in_group("PlacementManager")
			if pm and pm.is_placement_active():
				pm.exit_placement_mode()
			else:
				toggle_build_menu()
				
	if Input.is_action_just_pressed("toggle_inventory"):
		var pm = get_tree().get_first_node_in_group("PlacementManager")
		var pm_active = pm and pm.is_placement_active()
		if not market_ui.visible and not crafting_ui.visible and not pm_active:
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
		
	var careers = ["patreon", "scholar", "craftsman", "tailor"]
	var labels = [patreon_level_label, scholar_level_label, craftsman_level_label, tailor_level_label]
	var bars = [patreon_xp_bar, scholar_xp_bar, craftsman_xp_bar, tailor_xp_bar]
	
	for i in range(careers.size()):
		var c = careers[i]
		var lvl = GameState.career_levels.get(c, 1)
		var xp = GameState.career_xp.get(c, 0)
		var next_xp = GameState.get_xp_for_level(lvl)
		
		if labels[i]:
			labels[i].text = "%s Lv. %d" % [c.capitalize(), lvl]
		if bars[i]:
			bars[i].max_value = next_xp
			bars[i].value = xp
			
	if inventory_panel:
		inventory_panel.update_career_tabs()
		_update_mastery_traits()

func _update_mastery_traits() -> void:
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
				
				var title = Label.new()
				title.text = "Active Mastery Traits"
				title.add_theme_font_size_override("font_size", 12)
				title.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31))
				traits_container.add_child(title)
				
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
				lbl_t1.text = "Bountiful Harvest (%d%% Double Output)" % (35 if max_lvl >= 8 else 20)
				lbl_t1.add_theme_font_size_override("font_size", 10)
				lbl_t1.modulate = Color(1.0, 0.9, 0.5)
				trait1.add_child(lbl_t1)
				traits_container.add_child(trait1)
				
				if max_lvl >= 8:
					var trait2 = PanelContainer.new()
					var style_t2 = style_t1.duplicate()
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
		if interact_prompt:
			interact_prompt.set_prompt_text("")
		return
		
	var active_crafting_building: BaseProductionBuilding = null
	for building in get_tree().get_nodes_in_group("production_buildings"):
		if building.get("is_player_working_here"):
			active_crafting_building = building
			break
			
	if active_crafting_building:
		var recipe = load(active_crafting_building.player_crafting_recipe_path)
		var item_name = recipe.output_item.name if recipe else "Item"
		interact_prompt.set_prompt_text("[F] Stop Crafting %s" % item_name)
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
				text = "Locked (NPC Owned) | [R] Buy (%d G)" % npc_buy_cost if is_buy else "Locked. Opponent property."
				var is_workshop = interactable.is_in_group("Bakeries") or interactable.is_in_group("Smelters") or interactable.is_in_group("Inns") or interactable.is_in_group("Looms") or interactable.is_in_group("Mills") or interactable.is_in_group("PaperMakers") or interactable.is_in_group("PrintingPresses") or interactable.is_in_group("Banks") or interactable.is_in_group("MarketStall")
				if is_workshop and interactable.has_method("get_interaction_text"):
					var prompt_text = interactable.get_interaction_text()
					if prompt_text == "": text = ""
					elif "Buy" in prompt_text: text = "[F] %s" % prompt_text
					elif prompt_text == "Trade": text = "[F] Trade"
					elif prompt_text == "Locked" or "property" in prompt_text or "Opponent" in prompt_text: text = prompt_text
			elif ownership == "Player":
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var prompt_text = interactable.get_interaction_text()
					if prompt_text != "": normal_text = prompt_text
				text = "[F] %s (Owned)" % normal_text
			elif ownership == "Rented":
				var current_rent_days = target.rent_days_remaining if "rent_days_remaining" in target else 0
				var max_rent = target.max_rent_days if "max_rent_days" in target else 5
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var prompt_text = interactable.get_interaction_text()
					if prompt_text != "": normal_text = prompt_text
				text = "[F] %s" % normal_text
				if is_rent:
					text += " | [T] Extend (%d G, %d/%d days)" % [rent_val, current_rent_days, max_rent]
			else: # Public
				var normal_text = "Interact"
				if interactable.has_method("get_interaction_text"):
					var prompt_text = interactable.get_interaction_text()
					if prompt_text != "": normal_text = prompt_text
				text = "[F] %s" % normal_text
				if is_buy and target.ownership_type != "Public":
					text += " | [R] Buy (%d G)" % buy_val
				if is_rent:
					var max_rent = target.max_rent_days if "max_rent_days" in target else 5
					text += " | [T] Rent (%d G/day, max %d days)" % [rent_val, max_rent]
		else:
			var normal_text = "Interact"
			if interactable.has_method("get_interaction_text"):
				var prompt_text = interactable.get_interaction_text()
				if prompt_text != "": normal_text = prompt_text
			text = "[F] %s" % normal_text
			
		interact_prompt.set_prompt_text(text)
	else:
		interact_prompt.set_prompt_text("")

func toggle_inventory() -> void:
	if not inventory_panel:
		return
	if inventory_panel.visible:
		inventory_panel.hide()
		if _active_player:
			_active_player.unfreeze()
	else:
		if _active_player:
			_active_player.freeze()
		inventory_panel.update_inventory_panel()
		inventory_panel.show()
		inventory_panel.pivot_offset = inventory_panel.size / 2.0
		inventory_panel.scale = Vector2(0.9, 0.9)
		var tween = create_tween()
		tween.tween_property(inventory_panel, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var panel_close_button = %PanelCloseButton
		if panel_close_button:
			panel_close_button.grab_focus()

func toggle_build_menu() -> void:
	var main_hud = get_tree().get_first_node_in_group("game_hud")
	if not main_hud:
		var hud_nodes = get_tree().get_nodes_in_group("PlayerHUD")
		for node in hud_nodes:
			if node != self:
				main_hud = node
				break
	if main_hud and main_hud.has_method("toggle_window") and main_hud.get("build_window") != null:
		main_hud.toggle_window(main_hud.build_window)

func open_market(stall: CollisionObject2D) -> void:
	if market_ui and market_ui.has_method("open"):
		market_ui.open(stall)
		if _active_player: _active_player.freeze()
		if interact_prompt: interact_prompt.set_prompt_text("")

func close_market() -> void:
	if market_ui:
		market_ui.hide()
		if _active_player: _active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func open_crafting(bench: CraftingBench) -> void:
	if crafting_ui and crafting_ui.has_method("open"):
		crafting_ui.open(bench)
		if _active_player: _active_player.freeze()
		if interact_prompt: interact_prompt.set_prompt_text("")

func close_crafting() -> void:
	if crafting_ui:
		crafting_ui.hide()
		if _active_player: _active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func open_building_ui(building: Node2D) -> void:
	if _building_ui_instance:
		_building_ui_instance.queue_free()
	var building_ui_scene = load("res://common/ui/building_ui.tscn")
	if building_ui_scene:
		_building_ui_instance = building_ui_scene.instantiate() as Control
		var hud_control = get_node_or_null("HUDControl")
		if hud_control: hud_control.add_child(_building_ui_instance)
		else: add_child(_building_ui_instance)
		_building_ui_instance.open(building)
		if _active_player: _active_player.freeze()
		if interact_prompt: interact_prompt.set_prompt_text("")

func close_building_ui() -> void:
	if _building_ui_instance:
		_building_ui_instance.queue_free()
		_building_ui_instance = null
		if _active_player: _active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func open_commercial_routes_ui() -> void:
	if _commercial_route_ui_instance:
		_commercial_route_ui_instance.queue_free()
	var route_ui_scene = load("res://common/ui/commercial_route_panel.tscn")
	if route_ui_scene:
		_commercial_route_ui_instance = route_ui_scene.instantiate() as Control
		var hud_control = get_node_or_null("HUDControl")
		if hud_control: hud_control.add_child(_commercial_route_ui_instance)
		else: add_child(_commercial_route_ui_instance)
		if _active_player: _active_player.freeze()
		if interact_prompt: interact_prompt.set_prompt_text("")

func close_commercial_routes_ui() -> void:
	if _commercial_route_ui_instance:
		_commercial_route_ui_instance.queue_free()
		_commercial_route_ui_instance = null
		if _active_player: _active_player.unfreeze()
		update_interaction_prompt()
		update_hud_values()

func open_guild_ui(province_name: String, tab_name: String = "") -> void:
	var main_hud = get_tree().get_first_node_in_group("game_hud")
	if main_hud and main_hud.has_method("open_guild_ui") and main_hud != self:
		main_hud.call("open_guild_ui", province_name, tab_name)
		return
	var guild_ui = PanelContainer.new()
	guild_ui.set_script(preload("res://UI/guild_panel.gd"))
	add_child(guild_ui)
	guild_ui.open(province_name, tab_name)

func open_bank(bank) -> void:
	if get_node_or_null("BankUI"):
		return
	if _active_player: _active_player.freeze()
	if interact_prompt: interact_prompt.set_prompt_text("")
	var bank_ui_scene = load("res://common/ui/bank_ui.tscn")
	if bank_ui_scene:
		var bank_ui = bank_ui_scene.instantiate()
		bank_ui.name = "BankUI"
		add_child(bank_ui)
		bank_ui.setup(bank, _active_player)
		bank_ui.closed.connect(func(): update_interaction_prompt())

func toggle_pause_menu() -> void:
	var pm = get_node_or_null("PauseMenu") or get_node_or_null("HUDControl/PauseMenu")
	if pm:
		get_tree().paused = false
		if _active_player: _active_player.unfreeze()
		pm.queue_free()
	else:
		if inventory_panel: inventory_panel.hide()
		market_ui.hide()
		crafting_ui.hide()
		var pm_scene = load("res://common/ui/pause_menu.tscn")
		if pm_scene:
			var inst = pm_scene.instantiate()
			inst.name = "PauseMenu"
			var hud_control = get_node_or_null("HUDControl")
			if hud_control: hud_control.add_child(inst)
			else: add_child(inst)
			get_tree().paused = true
			if _active_player: _active_player.freeze()

func _on_time_changed(hours: int, minutes: int, days: int) -> void:
	if time_label:
		var ampm = "AM" if hours < 12 else "PM"
		var display_hours = hours % 12
		if display_hours == 0: display_hours = 12
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
				if recipe: _all_recipes.append(recipe)
			file_name = dir.get_next()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_U:
			var inspector = get_node_or_null("HUDControl/NPCInspectorPanel") or get_node_or_null("NPCInspectorPanel")
			if inspector:
				if inspector.visible: inspector.hide()
				else:
					inspector._populate_npc_list()
					inspector.show()
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("ui_cancel"):
		if inventory_panel and inventory_panel.visible:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif market_ui.visible or crafting_ui.visible:
			pass
		else:
			toggle_pause_menu()
			get_viewport().set_input_as_handled()

func _spawn_floating_text(sn_text: String, pos: Vector2) -> void:
	var label = Label.new()
	label.text = sn_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	if "+" in sn_text: label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	elif "-" in sn_text: label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else: label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	get_parent().add_child(label)
	label.global_position = pos + Vector2(-30, -20)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 32.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	await tween.finished
	label.queue_free()

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

func set_placement_instruction(text: String) -> void:
	if interact_prompt:
		interact_prompt.set_prompt_text(text)

func hide_placement_instruction() -> void:
	if interact_prompt:
		interact_prompt.set_prompt_text("")

func exit_placement_mode_external() -> void:
	var pm = get_tree().get_first_node_in_group("PlacementManager")
	if pm and pm.has_method("exit_placement_mode"):
		pm.exit_placement_mode()

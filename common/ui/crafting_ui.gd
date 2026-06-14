extends PanelContainer

@onready var recipe_list: VBoxContainer = %RecipeList
@onready var recipe_name_label: Label = %RecipeNameLabel
@onready var recipe_career_label: Label = %RecipeCareerLabel
@onready var ingredients_container: VBoxContainer = %IngredientsContainer
@onready var craft_button: Button = %CraftButton
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var xp_popup_label: Label = %XPPopupLabel
@onready var close_button: Button = %CloseButton
@onready var bottom_close_button: Button = %BottomCloseButton

var _current_bench: CraftingBench = null
var _selected_recipe: Recipe = null
var _is_crafting: bool = false

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(close)
		_setup_button_hover(close_button)
		
	if bottom_close_button:
		bottom_close_button.pressed.connect(close)
		_setup_button_hover(bottom_close_button)
		
	if craft_button:
		craft_button.pressed.connect(_on_craft_pressed)
		_setup_button_hover(craft_button)
		
	if progress_bar:
		progress_bar.value = 0.0
		
	if xp_popup_label:
		xp_popup_label.hide()

func open(bench: CraftingBench) -> void:
	_current_bench = bench
	_is_crafting = false
	
	if progress_bar:
		progress_bar.value = 0.0
		
	if xp_popup_label:
		xp_popup_label.hide()
		
	if GameState.player_inventory:
		if not GameState.player_inventory.inventory_changed.is_connected(refresh):
			GameState.player_inventory.inventory_changed.connect(refresh)
			
	show()
	
	# Slide/fade in animation
	pivot_offset = size / 2.0
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	
	refresh()
	
	# Select first recipe
	if bench.recipes.size() > 0:
		select_recipe(bench.recipes[0])

func close() -> void:
	if _is_crafting:
		return # Cannot close mid-crafting
		
	if GameState.player_inventory:
		if GameState.player_inventory.inventory_changed.is_connected(refresh):
			GameState.player_inventory.inventory_changed.disconnect(refresh)
			
	hide()
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud:
		hud.close_crafting()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if not _is_crafting:
			close()
			get_viewport().set_input_as_handled()

func refresh() -> void:
	if not _current_bench:
		return
		
	_refresh_recipe_list()
	if _selected_recipe:
		select_recipe(_selected_recipe)

func select_recipe(recipe: Recipe) -> void:
	_selected_recipe = recipe
	
	if recipe_name_label:
		recipe_name_label.text = recipe.recipe_name
		
	if recipe_career_label:
		recipe_career_label.text = "Required: %s Level %d" % [recipe.required_career.capitalize(), recipe.required_level]
		# Check if level matches
		var current_lvl = GameState.career_levels.get(recipe.required_career, 1)
		if current_lvl < recipe.required_level:
			recipe_career_label.modulate = Color(1.0, 0.4, 0.4)
		else:
			recipe_career_label.modulate = Color(0.4, 1.0, 0.4)
			
	# Update ingredients VBox
	if ingredients_container:
		for child in ingredients_container.get_children():
			child.queue_free()
			
		for item in recipe.inputs:
			var req_amount = recipe.inputs[item]
			var owned_amount = GameState.player_inventory.get_item_amount(item.id)
			
			var hbox = HBoxContainer.new()
			
			var name_lbl = Label.new()
			name_lbl.text = item.name
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.add_theme_font_size_override("font_size", 13)
			hbox.add_child(name_lbl)
			
			var qty_lbl = Label.new()
			qty_lbl.text = "%d / %d" % [owned_amount, req_amount]
			qty_lbl.add_theme_font_size_override("font_size", 13)
			if owned_amount >= req_amount:
				qty_lbl.modulate = Color(0.4, 1.0, 0.4)
			else:
				qty_lbl.modulate = Color(1.0, 0.4, 0.4)
			hbox.add_child(qty_lbl)
			
			ingredients_container.add_child(hbox)
			
	# Update craft button disabled state
	if craft_button:
		craft_button.disabled = _is_crafting or not GameState.can_craft_recipe(recipe)

func _refresh_recipe_list() -> void:
	if not recipe_list:
		return
		
	# Clear list
	for child in recipe_list.get_children():
		child.queue_free()
		
	# Populate list
	for recipe in _current_bench.recipes:
		if not recipe:
			continue
			
		var button = Button.new()
		button.text = recipe.recipe_name
		button.custom_minimum_size = Vector2(180, 40)
		
		# Stylize button based on level requirement
		var player_level = GameState.career_levels.get(recipe.required_career, 1)
		var is_locked = player_level < recipe.required_level
		
		if is_locked:
			button.text += " (Lv. %d)" % recipe.required_level
			button.modulate = Color(0.6, 0.6, 0.6, 0.8)
			
		button.pressed.connect(func(): select_recipe(recipe))
		_setup_button_hover(button)
		
		recipe_list.add_child(button)

func _on_craft_pressed() -> void:
	if _is_crafting or not _selected_recipe:
		return
		
	if not GameState.can_craft_recipe(_selected_recipe):
		return
		
	# Start Crafting Process
	_is_crafting = true
	if craft_button:
		craft_button.disabled = true
	if close_button:
		close_button.disabled = true
	if bottom_close_button:
		bottom_close_button.disabled = true
		
	# Animate Progress Bar (takes 1.2 seconds)
	if progress_bar:
		progress_bar.value = 0.0
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", 100.0, 1.2)
		await tween.finished
		
	# Execute Crafting
	var success = GameState.craft_recipe(_selected_recipe)
	
	_is_crafting = false
	if close_button:
		close_button.disabled = false
	if bottom_close_button:
		bottom_close_button.disabled = false
		
	if success:
		_show_xp_popup("+%d %s XP!" % [_selected_recipe.xp_reward, _selected_recipe.required_career.capitalize()])
	
	if progress_bar:
		progress_bar.value = 0.0
		
	# Refresh UI
	refresh()

func _show_xp_popup(text: String) -> void:
	if not xp_popup_label:
		return
		
	xp_popup_label.text = text
	xp_popup_label.modulate = Color(0.4, 1.0, 0.4, 1.0)
	xp_popup_label.show()
	xp_popup_label.position = Vector2(size.x / 2.0 - xp_popup_label.size.x / 2.0, size.y - 120.0)
	
	var orig_pos = xp_popup_label.position
	var tween = create_tween().set_parallel(true)
	tween.tween_property(xp_popup_label, "position:y", orig_pos.y - 40.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(xp_popup_label, "modulate:a", 0.0, 0.8)
	await tween.finished
	xp_popup_label.hide()

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

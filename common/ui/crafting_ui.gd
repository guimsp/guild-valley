extends PanelContainer

@onready var recipe_list: VBoxContainer = %RecipeList
@onready var recipe_name_label: Label = %RecipeNameLabel
@onready var recipe_career_label: Label = %RecipeCareerLabel
@onready var ingredients_container: VBoxContainer = %IngredientsContainer
@onready var craft_button: Button = %CraftButton
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var xp_popup_label: Label = %XPPopupLabel
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var bottom_close_button: Button = %BottomCloseButton

var _current_bench: CraftingBench = null
var _selected_recipe: Recipe = null
var _is_crafting: bool = false
var _continuous_crafting: bool = false

func _ready() -> void:
	var recipe_scroll = get_node_or_null("MarginContainer/VBoxContainer/Columns/RecipeSidebar/ScrollContainer") as ScrollContainer
	if recipe_scroll:
		UIFocusHelper.register_scroll_container(recipe_scroll)
		
	if close_button:
		close_button.pressed.connect(close)
		_setup_button_hover(close_button)
		close_button.focus_mode = Control.FOCUS_NONE
		
	if bottom_close_button:
		bottom_close_button.pressed.connect(close)
		_setup_button_hover(bottom_close_button)
		bottom_close_button.focus_mode = Control.FOCUS_ALL
		
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
	_continuous_crafting = false
	
	if progress_bar:
		progress_bar.value = 0.0
		
	if xp_popup_label:
		xp_popup_label.hide()
		
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
	
	refresh(true)
	
	if bench.recipes.size() > 0:
		select_recipe(bench.recipes[0])

func close() -> void:
	if _is_crafting:
		return
		
	if GameState.player_inventory:
		if GameState.player_inventory.inventory_changed.is_connected(refresh):
			GameState.player_inventory.inventory_changed.disconnect(refresh)
			
	hide()
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud:
		hud.close_crafting()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		if _is_crafting:
			_continuous_crafting = false
			get_viewport().set_input_as_handled()
		else:
			close()
			get_viewport().set_input_as_handled()
		return

	# Handle F / interact / ui_accept confirming focused buttons
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and focused is Button and is_instance_valid(focused) and is_ancestor_of(focused):
				# If we are already crafting, pressing F cancels continuous crafting
				if _is_crafting:
					_continuous_crafting = false
					get_viewport().set_input_as_handled()
					return
					
				# If we are focused on a recipe in the sidebar, press F to start continuous crafting directly
				if focused.get_parent() == recipe_list:
					_continuous_crafting = true
					_on_craft_pressed()
					get_viewport().set_input_as_handled()
					return
					
				# Otherwise standard click on focused button
				focused.pressed.emit()
				get_viewport().set_input_as_handled()
				return

func refresh(grab_initial_focus = false) -> void:
	if not _current_bench:
		return
		
	var do_focus = (grab_initial_focus == true)
	_refresh_recipe_list(do_focus)
	if _selected_recipe:
		select_recipe(_selected_recipe)

func select_recipe(recipe: Recipe) -> void:
	_selected_recipe = recipe
	
	if recipe_name_label:
		recipe_name_label.text = recipe.recipe_name
		
	if recipe_career_label:
		recipe_career_label.text = ""
			
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
			
	if craft_button:
		craft_button.disabled = _is_crafting or not GameState.can_craft_recipe(recipe)
		
	# Dynamically link CraftButton left neighbor to the selected recipe card
	if craft_button and recipe_list:
		for child in recipe_list.get_children():
			if child is Button and child.text.begins_with(recipe.recipe_name):
				craft_button.focus_neighbor_left = child.get_path()
				break

func _refresh_recipe_list(grab_initial_focus: bool = false) -> void:
	if not recipe_list:
		return
		
	for child in recipe_list.get_children():
		child.queue_free()
		
	for recipe in _current_bench.recipes:
		if not recipe:
			continue
			
		var button = Button.new()
		button.text = recipe.recipe_name
		button.custom_minimum_size = Vector2(180, 40)
		
		# Recipe level requirement check bypassed for item crafting
			
		button.pressed.connect(func(): select_recipe(recipe))
		button.focus_entered.connect(func(): select_recipe(recipe))
		_setup_button_hover(button)
		
		button.focus_neighbor_right = craft_button.get_path()
		
		recipe_list.add_child(button)

	var btn_count = recipe_list.get_child_count()
	if btn_count > 0:
		recipe_list.get_child(0).focus_neighbor_top = recipe_list.get_child(0).get_path()
		recipe_list.get_child(btn_count - 1).focus_neighbor_bottom = recipe_list.get_child(btn_count - 1).get_path()

	if grab_initial_focus and btn_count > 0:
		var first_button = recipe_list.get_child(0) as Button
		if first_button:
			_grab_focus_deferred(first_button)

func _grab_focus_deferred(control: Control) -> void:
	if not control.is_inside_tree():
		await control.ready
	await get_tree().process_frame
	if is_instance_valid(control) and control.is_inside_tree() and control.visible:
		control.grab_focus()

func _on_craft_pressed() -> void:
	if _is_crafting:
		return
		
	if not _selected_recipe or not GameState.can_craft_recipe(_selected_recipe):
		_continuous_crafting = false
		return
		
	_is_crafting = true
	_continuous_crafting = true
	
	while _is_crafting and _continuous_crafting and GameState.can_craft_recipe(_selected_recipe):
		if craft_button:
			craft_button.disabled = true
			craft_button.text = "Crafting... (Press F/ESC to Stop)"
		if close_button:
			close_button.disabled = true
		if bottom_close_button:
			bottom_close_button.disabled = true
			
		if progress_bar:
			progress_bar.value = 0.0
			var tween = create_tween()
			tween.tween_property(progress_bar, "value", 100.0, 1.2)
			await tween.finished
			
		if not _continuous_crafting:
			break
			
		var success = GameState.craft_recipe(_selected_recipe)
		if success:
			_show_xp_popup("+%d %s XP!" % [_selected_recipe.xp_reward, _selected_recipe.required_career.capitalize()])
			refresh()
		else:
			break
			
	_is_crafting = false
	_continuous_crafting = false
	
	if craft_button:
		craft_button.disabled = not GameState.can_craft_recipe(_selected_recipe)
		craft_button.text = "Craft Item"
	if close_button:
		close_button.disabled = false
	if bottom_close_button:
		bottom_close_button.disabled = false
		
	if progress_bar:
		progress_bar.value = 0.0
		
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

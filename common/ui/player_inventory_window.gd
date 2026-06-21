extends PanelContainer

var _main_hud: CanvasLayer = null

@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var career_tab_container: TabContainer = %CareerTabContainer
@onready var bag_label: Label = %BagLabel

var equipment_grid: GridContainer = null
var stats_labels: Dictionary = {}
var equip_panel: PanelContainer = null
var confirm_popup: PanelContainer = null
var _popup_confirm_callback: Callable = Callable()

const SLOT_LAYOUT = [
	"head", "necklace", "bag",
	"weapon", "body", "gloves",
	"ring", "tool", "transportation"
]

func setup(p_hud: CanvasLayer) -> void:
	_main_hud = p_hud
	_init_equipment_panel()

func _init_equipment_panel() -> void:
	var split_box = get_node_or_null("MainLayout/SplitBox")
	if not split_box:
		return
		
	if split_box.has_node("EquipmentPanel"):
		return
		
	var panel = PanelContainer.new()
	panel.name = "EquipmentPanel"
	panel.custom_minimum_size = Vector2(240, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.8)
	style.border_color = Color(0.24, 0.52, 0.85, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Player Equipment"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
	vbox.add_child(title)
	
	var grid = GridContainer.new()
	grid.name = "EquipmentGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)
	equipment_grid = grid
	
	for i in range(9):
		var slot_panel = PanelContainer.new()
		slot_panel.name = "Slot_" + str(i)
		slot_panel.custom_minimum_size = Vector2(60, 60)
		slot_panel.focus_mode = Control.FOCUS_ALL
		
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.16, 0.16, 0.22, 0.5)
		slot_style.set_border_width_all(1)
		slot_style.border_color = Color(0.3, 0.3, 0.42, 0.5)
		slot_style.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		
		grid.add_child(slot_panel)
		
	var stats_title = Label.new()
	stats_title.text = "Equipment Stats"
	stats_title.add_theme_font_size_override("font_size", 11)
	stats_title.add_theme_color_override("font_color", Color(0.9, 0.77, 0.31))
	vbox.add_child(stats_title)
	
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(stats_vbox)
	
	var stats_keys = ["Attack", "Armor", "Speed", "Capacity", "Gathering"]
	for s in stats_keys:
		var hbox = HBoxContainer.new()
		stats_vbox.add_child(hbox)
		
		var name_lbl = Label.new()
		name_lbl.text = s + ":"
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.modulate = Color(0.8, 0.8, 0.8)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var val_lbl = Label.new()
		val_lbl.text = "0"
		val_lbl.add_theme_font_size_override("font_size", 10)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(val_lbl)
		stats_labels[s] = val_lbl
		
	split_box.add_child(panel)
	split_box.move_child(panel, 1) # Insert as middle column
	equip_panel = panel
	
	_init_confirm_popup()

func _init_confirm_popup() -> void:
	if has_node("ConfirmPopup"):
		return
		
	var popup = PanelContainer.new()
	popup.name = "ConfirmPopup"
	popup.custom_minimum_size = Vector2(250, 120)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_color = Color(0.24, 0.52, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)
	
	var title = Label.new()
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.24, 0.6, 0.86))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.name = "DescLabel"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 10)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	var buttons = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)
	
	var yes_btn = Button.new()
	yes_btn.name = "YesButton"
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(60, 24)
	yes_btn.add_theme_font_size_override("font_size", 10)
	yes_btn.focus_mode = Control.FOCUS_ALL
	buttons.add_child(yes_btn)
	_main_hud._setup_button_hover(yes_btn)
	
	var no_btn = Button.new()
	no_btn.name = "NoButton"
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(60, 24)
	no_btn.add_theme_font_size_override("font_size", 10)
	no_btn.focus_mode = Control.FOCUS_ALL
	buttons.add_child(no_btn)
	_main_hud._setup_button_hover(no_btn)
	
	add_child(popup)
	popup.hide()
	confirm_popup = popup

func open_confirm_prompt(title_text: String, desc_text: String, confirm_callback: Callable) -> void:
	if not confirm_popup:
		return
	var title_lbl = confirm_popup.find_child("TitleLabel", true, false) as Label
	var desc_lbl = confirm_popup.find_child("DescLabel", true, false) as Label
	var yes_btn = confirm_popup.find_child("YesButton", true, false) as Button
	var no_btn = confirm_popup.find_child("NoButton", true, false) as Button
	
	title_lbl.text = title_text
	desc_lbl.text = desc_text
	_popup_confirm_callback = confirm_callback
	
	for conn in yes_btn.pressed.get_connections():
		yes_btn.pressed.disconnect(conn.callable)
	for conn in no_btn.pressed.get_connections():
		no_btn.pressed.disconnect(conn.callable)
		
	yes_btn.pressed.connect(func():
		confirm_popup.hide()
		_popup_confirm_callback.call()
		update_inventory_panel()
	)
	no_btn.pressed.connect(func():
		confirm_popup.hide()
		update_inventory_panel()
	)
	
	confirm_popup.show()
	confirm_popup.global_position = global_position + (size / 2.0) - (confirm_popup.size / 2.0)
	yes_btn.grab_focus()

func update_inventory_panel() -> void:
	if not inventory_grid:
		return
		
	for child in inventory_grid.get_children():
		child.queue_free()
		
	var slots = GameState.player_inventory.slots
	var max_slots = GameState.player_inventory.max_slots
	
	if bag_label:
		bag_label.text = "Bag Space: %d/%d Slots" % [slots.size(), max_slots]

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
		hover_style.border_color = Color(0.88, 0.73, 0.23, 0.9)
		
		slot_panel.focus_entered.connect(func(): slot_panel.add_theme_stylebox_override("panel", hover_style))
		slot_panel.focus_exited.connect(func(): slot_panel.add_theme_stylebox_override("panel", style))
		slot_panel.mouse_entered.connect(func(): slot_panel.add_theme_stylebox_override("panel", hover_style))
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
		
		if item.icon:
			var tr = TextureRect.new()
			tr.texture = item.icon
			tr.custom_minimum_size = Vector2(28, 28)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(tr)
			
		var item_label = Label.new()
		item_label.text = item.name.substr(0, 8)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(item_label)
		
		var amount_label = Label.new()
		amount_label.text = "x%d" % amount
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(amount_label)
		
		slot_panel.tooltip_text = "%s\nCategory: %s\nValue: %d Gold" % [item.name, item.category, item.base_value]
		if item.equipment_slot != "None":
			slot_panel.tooltip_text += "\n[Press Interact to Equip]"
		inventory_grid.add_child(slot_panel)
		
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
		
	_update_equipment_grid()
	_update_stats_panel()
	_link_inventory_grid_focus()

func _update_equipment_grid() -> void:
	if not equipment_grid:
		return
		
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
		
	var eq = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
	if not eq:
		return
		
	for i in range(9):
		var slot_name = SLOT_LAYOUT[i]
		var item = eq.get_equipped_item(slot_name)
		var slot_panel = equipment_grid.get_child(i) as PanelContainer
		
		for child in slot_panel.get_children():
			child.queue_free()
			
		var style = StyleBoxFlat.new()
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		
		var hover_style = style.duplicate()
		hover_style.border_color = Color(0.88, 0.73, 0.23, 0.9)
		
		if item:
			style.bg_color = Color(0.18, 0.24, 0.35, 0.8)
			style.border_color = Color(0.3, 0.5, 0.8, 0.8)
			
			var vbox = VBoxContainer.new()
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			slot_panel.add_child(vbox)
			
			if item.icon:
				var tr = TextureRect.new()
				tr.texture = item.icon
				tr.custom_minimum_size = Vector2(24, 24)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				vbox.add_child(tr)
				
			var lbl = Label.new()
			lbl.text = item.name.substr(0, 8)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 9)
			vbox.add_child(lbl)
			
			slot_panel.tooltip_text = "%s (%s Slot)\n[Interact to Unequip]" % [item.name, slot_name.capitalize()]
			slot_panel.focus_mode = Control.FOCUS_ALL
			
			for conn in slot_panel.gui_input.get_connections():
				slot_panel.gui_input.disconnect(conn.callable)
				
			slot_panel.gui_input.connect(func(event: InputEvent):
				var is_interact = event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F and event.pressed)
				var is_accept = event.is_action_pressed("ui_accept")
				var is_click = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
				if is_interact or is_accept or is_click:
					slot_panel.get_viewport().set_input_as_handled()
					_on_equipment_slot_interacted(slot_name, item)
			)
		else:
			style.bg_color = Color(0.12, 0.12, 0.16, 0.4)
			style.border_color = Color(0.24, 0.24, 0.3, 0.4)
			
			var lbl = Label.new()
			lbl.text = "[%s]" % slot_name.capitalize()
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.modulate = Color(0.5, 0.5, 0.5)
			slot_panel.add_child(lbl)
			
			slot_panel.tooltip_text = "Empty %s Slot" % slot_name.capitalize()
			slot_panel.focus_mode = Control.FOCUS_NONE
			
			for conn in slot_panel.gui_input.get_connections():
				slot_panel.gui_input.disconnect(conn.callable)
			
		slot_panel.add_theme_stylebox_override("panel", style)
		slot_panel.focus_entered.connect(func(): slot_panel.add_theme_stylebox_override("panel", hover_style))
		slot_panel.focus_exited.connect(func(): slot_panel.add_theme_stylebox_override("panel", style))
		slot_panel.mouse_entered.connect(func(): slot_panel.add_theme_stylebox_override("panel", hover_style))
		slot_panel.mouse_exited.connect(func():
			if not slot_panel.has_focus():
				slot_panel.add_theme_stylebox_override("panel", style)
		)

func _on_equipment_slot_interacted(slot_name: String, item: ItemData) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return
	
	open_confirm_prompt("Unequip Item", "Unequip %s?" % item.name, func():
		var eq = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
		if not eq: return
		
		if GameState.player_inventory.slots.size() >= GameState.player_inventory.max_slots:
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud: hud._spawn_floating_text("Bag is full!", player.global_position)
			return
			
		eq.unequip_item(slot_name)
		GameState.player_inventory.add_item(item, 1)
		player.recalculate_equipment_stats()
	)

func _update_stats_panel() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
		
	var eq = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
	if not eq:
		return
		
	if stats_labels.has("Attack"):
		stats_labels["Attack"].text = str(eq.get_total_attack())
	if stats_labels.has("Armor"):
		stats_labels["Armor"].text = str(eq.get_total_armor())
	if stats_labels.has("Speed"):
		stats_labels["Speed"].text = "%+d%%" % int(eq.get_total_speed_bonus() * 100)
	if stats_labels.has("Capacity"):
		stats_labels["Capacity"].text = "%+d slots" % eq.get_total_capacity_bonus()
	if stats_labels.has("Gathering"):
		stats_labels["Gathering"].text = "%+d%%" % int(eq.get_total_gathering_bonus() * 100)

func _on_inventory_slot_interacted(item: ItemData) -> void:
	if not item:
		return
	if item.equipment_slot != "None":
		var player = get_tree().get_first_node_in_group("Player")
		if not player: return
		var eq = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
		if not eq: return
		
		var slot_name = item.equipment_slot.to_lower()
		var prev_equipped = eq.get_equipped_item(slot_name)
		if prev_equipped:
			var would_free_slot = (GameState.player_inventory.get_item_amount(item.id) == 1)
			if not would_free_slot:
				if GameState.player_inventory.get_free_space_for_item(prev_equipped) <= 0:
					var hud = get_tree().get_first_node_in_group("PlayerHUD")
					if hud: hud._spawn_floating_text("Bag is full, cannot swap!", player.global_position)
					return
					
		open_confirm_prompt("Equip Item", "Equip %s?" % item.name, func():
			GameState.player_inventory.remove_item(item.id, 1)
			var prev = eq.equip_item(slot_name, item)
			if prev:
				GameState.player_inventory.add_item(prev, 1)
			player.recalculate_equipment_stats()
		)
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
				if _main_hud:
					_main_hud.update_hud_values()
			else:
				print("[PlayerHUD] Career %s is already unlocked!" % career)

func update_career_tabs() -> void:
	if not career_tab_container or not _main_hud:
		return
		
	var careers = ["patreon", "craftsman", "tailor", "scholar"]
	
	if career_tab_container.get_child_count() != careers.size():
		for child in career_tab_container.get_children():
			child.queue_free()
			
		var skill_panel_scene = load("res://common/ui/skill_panel.tscn")
		if skill_panel_scene:
			for career in careers:
				var panel = skill_panel_scene.instantiate()
				career_tab_container.add_child(panel)
				panel.init_skill(career, _main_hud._all_recipes)
				
	for i in range(careers.size()):
		var career = careers[i]
		var panel = career_tab_container.get_child(i)
		if panel and panel.has_method("update_panel"):
			panel.update_panel()
		var lvl = GameState.career_levels.get(career, 1)
		career_tab_container.set_tab_title(i, "%s (Lv. %d)" % [career.capitalize(), lvl])

func _link_inventory_grid_focus() -> void:
	if not inventory_grid:
		return
		
	var slots_count = inventory_grid.get_child_count()
	if slots_count == 0:
		return
		
	var inv_slots = []
	for slot in inventory_grid.get_children():
		if slot is PanelContainer and slot.focus_mode == Control.FOCUS_ALL:
			inv_slots.append(slot)
			
	var cols = 2
	var inv_rows = []
	var current_row = []
	for slot in inv_slots:
		current_row.append(slot)
		if current_row.size() == cols:
			inv_rows.append(current_row)
			current_row = []
	if not current_row.is_empty():
		inv_rows.append(current_row)
		
	var equip_slots = []
	if equipment_grid:
		for slot in equipment_grid.get_children():
			if slot is PanelContainer and slot.focus_mode == Control.FOCUS_ALL:
				equip_slots.append(slot)
				
	var equip_cols = 3
	var equip_rows = []
	var eq_row = []
	for slot in equip_slots:
		eq_row.append(slot)
		if eq_row.size() == equip_cols:
			equip_rows.append(eq_row)
			eq_row = []
	if not eq_row.is_empty():
		equip_rows.append(eq_row)
		
	for r in range(inv_rows.size()):
		for c in range(inv_rows[r].size()):
			var slot = inv_rows[r][c]
			slot.focus_neighbor_left = inv_rows[r][c - 1].get_path() if c > 0 else slot.get_path()
			
			if c < inv_rows[r].size() - 1:
				slot.focus_neighbor_right = inv_rows[r][c + 1].get_path()
			else:
				if not equip_rows.is_empty():
					var eq_target_r = clamp(r, 0, equip_rows.size() - 1)
					slot.focus_neighbor_right = equip_rows[eq_target_r][0].get_path()
				elif career_tab_container:
					slot.focus_neighbor_right = career_tab_container.get_path()
				else:
					slot.focus_neighbor_right = slot.get_path()
					
			slot.focus_neighbor_top = inv_rows[r - 1][min(c, inv_rows[r - 1].size() - 1)].get_path() if r > 0 else slot.get_path()
			slot.focus_neighbor_bottom = inv_rows[r + 1][min(c, inv_rows[r + 1].size() - 1)].get_path() if r < inv_rows.size() - 1 else slot.get_path()
			
	for r in range(equip_rows.size()):
		for c in range(equip_rows[r].size()):
			var slot = equip_rows[r][c]
			
			if c > 0:
				slot.focus_neighbor_left = equip_rows[r][c - 1].get_path()
			else:
				if not inv_rows.is_empty():
					var inv_target_r = clamp(r, 0, inv_rows.size() - 1)
					var last_c = inv_rows[inv_target_r].size() - 1
					slot.focus_neighbor_left = inv_rows[inv_target_r][last_c].get_path()
				else:
					slot.focus_neighbor_left = slot.get_path()
					
			if c < equip_rows[r].size() - 1:
				slot.focus_neighbor_right = equip_rows[r][c + 1].get_path()
			else:
				if career_tab_container:
					slot.focus_neighbor_right = career_tab_container.get_path()
				else:
					slot.focus_neighbor_right = slot.get_path()
					
			slot.focus_neighbor_top = equip_rows[r - 1][min(c, equip_rows[r - 1].size() - 1)].get_path() if r > 0 else slot.get_path()
			slot.focus_neighbor_bottom = equip_rows[r + 1][min(c, equip_rows[r + 1].size() - 1)].get_path() if r < equip_rows.size() - 1 else slot.get_path()
			
	if career_tab_container:
		if not equip_rows.is_empty():
			career_tab_container.focus_neighbor_left = equip_rows[0][equip_rows[0].size() - 1].get_path()
		elif not inv_rows.is_empty():
			career_tab_container.focus_neighbor_left = inv_rows[0][inv_rows[0].size() - 1].get_path()

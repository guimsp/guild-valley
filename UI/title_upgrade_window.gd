extends PanelContainer

var _main_hud: CanvasLayer = null
var _selected_title_index: int = 1

@onready var titles_list_container: VBoxContainer = $VBox/ContentHBox/TitleScroll/TitlesList
@onready var selected_title_name_label: Label = $VBox/ContentHBox/DetailsVBox/SelectedTitleName
@onready var selected_title_desc_label: Label = $VBox/ContentHBox/DetailsVBox/SelectedTitleDesc
@onready var title_upgrade_cost_label: Label = $VBox/ContentHBox/DetailsVBox/TitleUpgradeCostLabel
@onready var upgrade_title_button: Button = $VBox/ContentHBox/DetailsVBox/UpgradeTitleButton

func setup(p_hud: CanvasLayer) -> void:
	_main_hud = p_hud
	if upgrade_title_button:
		upgrade_title_button.pressed.connect(_on_upgrade_title_pressed)
		if _main_hud.has_method("_setup_button_hover"):
			_main_hud._setup_button_hover(upgrade_title_button)

func refresh() -> void:
	if not titles_list_container:
		return
		
	for child in titles_list_container.get_children():
		child.queue_free()
		
	var active_title = GameState.title_level
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
		if _main_hud and _main_hud.has_method("_setup_button_hover"):
			_main_hud._setup_button_hover(btn)
			
		var target_lvl = lvl
		btn.pressed.connect(func():
			_selected_title_index = target_lvl
			_refresh_title_details()
		)
		
		titles_list_container.add_child(btn)
		buttons.append(btn)
		
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = upgrade_title_button.get_path() if upgrade_title_button else btn.get_path()
		btn.focus_neighbor_top = buttons[i - 1].get_path() if i > 0 else btn.get_path()
		btn.focus_neighbor_bottom = buttons[i + 1].get_path() if i < buttons.size() - 1 else btn.get_path()
		
	_refresh_title_details()

func _refresh_title_details() -> void:
	if not selected_title_name_label:
		return
		
	var lvl = _selected_title_index
	selected_title_name_label.text = GameState.get_title_name(lvl)
	
	var desc = ""
	match lvl:
		1: desc = "Apprentice Guildmaster status.\n\nBenefits:\n • Starting title. Allows construction of Tier 1 basic structures (plaza, beds, crafting benches, general stalls)."
		2: desc = "Journeyman status.\n\nBenefits:\n • Unlocks Tier 2 advanced production buildings: Mill, Smelter, Loom, Inn, Farmstead, Tavern."
		3: desc = "Guildmaster status.\n\nBenefits:\n • Unlocks Tier 3 premium shops: Bakery, Paper Maker, and Distillery.\n • Increases overnight crop regrowth speed by 15%."
		4: desc = "Patrician civic status.\n\nBenefits:\n • Unlocks Tier 4 administrative buildings: Printing Press, Event Hall, and Banks.\n • Reduces employee salary costs by 10%."
		5: desc = "Guild Baron status.\n\nBenefits:\n • Unlocks Tier 5 luxury upgrade improvements.\n • Passively generates +5 Influence overnight."
			
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
		if _main_hud and _main_hud.has_method("flash_element"):
			_main_hud.flash_element(self, Color(0.4, 1.0, 0.4))
		_selected_title_index = target_lvl
		if _main_hud and _main_hud.has_method("update_hud_values"):
			_main_hud.update_hud_values()
		refresh()
	else:
		if _main_hud and _main_hud.has_method("shake_element"):
			_main_hud.shake_element(self)
		if _main_hud and _main_hud.has_method("flash_element"):
			_main_hud.flash_element(self, Color(1.0, 0.4, 0.4))

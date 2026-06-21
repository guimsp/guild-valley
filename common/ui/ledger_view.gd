extends Control

var _building: Node2D = null
var _coordinator: Control = null

# UI Elements
@onready var stats_grid: GridContainer = $Columns/LeftColumn/StatsTablePanel/StatsGrid
@onready var balance_label: Label = $Columns/RightColumn/VaultPanel/HBox/BalanceLabel
@onready var withdraw_button: Button = $Columns/RightColumn/VaultPanel/HBox/WithdrawButton
@onready var log_list: VBoxContainer = $Columns/RightColumn/SalesScroll/LogList

func setup(building: Node2D, coordinator: Control) -> void:
	_building = building
	_coordinator = coordinator
	if withdraw_button.pressed.is_connected(_on_withdraw_pressed):
		withdraw_button.pressed.disconnect(_on_withdraw_pressed)
	withdraw_button.pressed.connect(_on_withdraw_pressed)
	_coordinator._setup_button_hover(withdraw_button)

func update_view() -> void:
	if not _building:
		return
		
	# Clear tables/lists
	for child in stats_grid.get_children():
		# Skip headers
		if child.name.begins_with("Header"):
			continue
		child.queue_free()
		
	for child in log_list.get_children():
		child.queue_free()
		
	_populate_stats()
	_populate_vault()
	_populate_ledger_logs()

func _populate_stats() -> void:
	var recipes = _get_recipes()
	if recipes.size() > 0:
		var lifetime_dict = _building.get("lifetime_production") if "lifetime_production" in _building else {}
		var daily_dict = _building.get("daily_production") if "daily_production" in _building else {}
		
		for recipe in recipes:
			if not recipe or not recipe.output_item:
				continue
			var item = recipe.output_item
			var life_qty = lifetime_dict.get(item.id, 0)
			var day_qty = daily_dict.get(item.id, 0)
			
			var l_name = Label.new()
			l_name.text = item.name
			l_name.add_theme_font_size_override("font_size", 11)
			stats_grid.add_child(l_name)
			
			var l_life = Label.new()
			l_life.text = "%d" % life_qty
			l_life.add_theme_font_size_override("font_size", 11)
			l_life.modulate = Color(0.85, 0.85, 0.95)
			stats_grid.add_child(l_life)
			
			var l_day = Label.new()
			l_day.text = "%d" % day_qty
			l_day.add_theme_font_size_override("font_size", 11)
			l_day.modulate = Color(0.2, 0.8, 0.5) if day_qty > 0 else Color(0.5, 0.5, 0.5)
			stats_grid.add_child(l_day)
	else:
		var empty_lbl = Label.new()
		empty_lbl.text = "No production recipes"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		stats_grid.add_child(empty_lbl)
		stats_grid.add_child(Label.new())
		stats_grid.add_child(Label.new())

func _populate_vault() -> void:
	var strongbox = _building.get_node_or_null("StrongboxComponent")
	var balance = strongbox.strongbox_gold if strongbox else 0
	var max_cap = strongbox.max_gold_capacity if (strongbox and "max_gold_capacity" in strongbox) else 1500
	
	balance_label.text = "Vault Gold: %d / %d G" % [balance, max_cap]
	withdraw_button.disabled = (balance <= 0)

func _on_withdraw_pressed() -> void:
	var strongbox = _building.get_node_or_null("StrongboxComponent")
	if strongbox and strongbox.strongbox_gold > 0:
		var gold_to_withdraw = strongbox.withdraw_all()
		GameState.gold += gold_to_withdraw
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			hud._spawn_floating_text("+%d Gold Retrieved!" % gold_to_withdraw, _building.global_position)
			if hud.has_method("update_hud_values"):
				hud.update_hud_values()
		update_view()

func _populate_ledger_logs() -> void:
	var strongbox = _building.get_node_or_null("StrongboxComponent")
	if strongbox and strongbox.transaction_ledger.size() > 0:
		for entry in strongbox.transaction_ledger:
			var item_lbl = Label.new()
			var buyer = entry.get("buyer_name", "Customer")
			item_lbl.text = " • Sold %d %s to %s for %d Gold (%s)" % [entry["amount"], entry["item_name"], buyer, entry["price"], entry["timestamp"]]
			item_lbl.add_theme_font_size_override("font_size", 11)
			item_lbl.modulate = Color(0.8, 0.8, 0.85, 0.95)
			log_list.add_child(item_lbl)
	else:
		var no_trans = Label.new()
		no_trans.text = " No sales recorded yet."
		no_trans.add_theme_font_size_override("font_size", 11)
		no_trans.modulate = Color(0.5, 0.5, 0.5, 0.8)
		log_list.add_child(no_trans)

func _get_recipes() -> Array:
	if not _building:
		return []
	var bench = _building.get_node_or_null("CraftingBench")
	if not bench and is_instance_valid(_building.get("instanced_interior")):
		bench = _building.instanced_interior.get_node_or_null("CraftingBench")
	if not bench or not ("recipes" in bench):
		return []
		
	var list = bench.recipes.duplicate()
	if _building.get("building_level") != null and _building.building_level >= 2:
		var building_career = ""
		if _building.get("building_data") != null and _building.building_data and _building.building_data.get("career") != "":
			building_career = _building.building_data.career
		else:
			for r in bench.recipes:
				if r and r.required_career != "":
					building_career = r.required_career
					break
					
		if building_career != "":
			for path in GameState.active_trial_recipes:
				var trial_res = load(path)
				if trial_res and trial_res.required_career == building_career:
					list.append(trial_res)
	return list

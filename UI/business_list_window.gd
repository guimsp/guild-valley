extends PanelContainer

var _main_hud: CanvasLayer = null

@onready var business_scroll_list: VBoxContainer = $VBox/ScrollContainer/BusinessScrollList

func setup(p_hud: CanvasLayer) -> void:
	_main_hud = p_hud
	TimeManager.time_changed.connect(func(_h, _m, _d): refresh())
	QuestManager.quests_updated.connect(refresh)

func refresh() -> void:
	if not visible:
		return
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
				var current_day = TimeManager.time_days
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

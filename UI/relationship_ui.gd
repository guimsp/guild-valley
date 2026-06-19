extends PanelContainer

# UI nodes built programmatically
var main_vbox: VBoxContainer
var npc_name_lbl: Label
var npc_role_lbl: Label
var stage_lbl: Label
var affinity_bar: ProgressBar
var affinity_val_lbl: Label
var daily_lbl: Label
var likes_container: HBoxContainer
var dialog_lbl: Label

var btn_chat: Button
var btn_flirt: Button
var btn_gift: Button
var btn_quest: Button
var btn_marry: Button
var btn_close: Button

var gift_scroll: ScrollContainer
var gift_vbox: VBoxContainer
var btn_cancel_gift: Button

var target_npc: Node2D
var rel_component: Node

var quest_choice_hbox: HBoxContainer
var btn_accept_quest: Button
var btn_decline_quest: Button
var _offered_quest: Dictionary = {}

func _ready() -> void:
	# Enable processing in pause
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("RelationshipUI")
	
	# Apply glassmorphic flat style
	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color(0.08, 0.12, 0.22, 0.9) # Dark translucent blue
	style_panel.border_width_left = 2
	style_panel.border_width_right = 2
	style_panel.border_width_top = 2
	style_panel.border_width_bottom = 2
	style_panel.border_color = Color(0.2, 0.45, 0.85, 0.6) # Sleek blue border
	style_panel.corner_radius_top_left = 12
	style_panel.corner_radius_top_right = 12
	style_panel.corner_radius_bottom_left = 12
	style_panel.corner_radius_bottom_right = 12
	style_panel.shadow_color = Color(0, 0, 0, 0.5)
	style_panel.shadow_size = 8
	add_theme_stylebox_override("panel", style_panel)
	
	# Create Main Layout
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)
	
	# 1. Header Row
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_vbox)
	
	npc_name_lbl = Label.new()
	npc_name_lbl.text = "NPC Name"
	npc_name_lbl.add_theme_font_size_override("font_size", 16)
	npc_name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	name_vbox.add_child(npc_name_lbl)
	
	npc_role_lbl = Label.new()
	npc_role_lbl.text = "NPC Profession"
	npc_role_lbl.add_theme_font_size_override("font_size", 11)
	npc_role_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	name_vbox.add_child(npc_role_lbl)
	
	# 2. Stats Section (Glass Box Card)
	var stats_card = PanelContainer.new()
	var style_card = StyleBoxFlat.new()
	style_card.bg_color = Color(0.05, 0.08, 0.16, 0.75)
	style_card.corner_radius_top_left = 6
	style_card.corner_radius_top_right = 6
	style_card.corner_radius_bottom_left = 6
	style_card.corner_radius_bottom_right = 6
	style_card.border_width_left = 1
	style_card.border_width_top = 1
	style_card.border_color = Color(0.2, 0.35, 0.6, 0.3)
	stats_card.add_theme_stylebox_override("panel", style_card)
	main_vbox.add_child(stats_card)
	
	var stats_margin = MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 10)
	stats_margin.add_theme_constant_override("margin_right", 10)
	stats_margin.add_theme_constant_override("margin_top", 4)
	stats_margin.add_theme_constant_override("margin_bottom", 4)
	stats_card.add_child(stats_margin)
	
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_margin.add_child(stats_vbox)
	
	# Stage and daily slots row
	var row1 = HBoxContainer.new()
	stats_vbox.add_child(row1)
	
	stage_lbl = Label.new()
	stage_lbl.text = "Stage: Neutral"
	stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_lbl.add_theme_font_size_override("font_size", 12)
	stage_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	row1.add_child(stage_lbl)
	
	daily_lbl = Label.new()
	daily_lbl.text = "Daily Actions: 3/3"
	daily_lbl.add_theme_font_size_override("font_size", 11)
	daily_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
	row1.add_child(daily_lbl)
	
	# Progress bar row
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	stats_vbox.add_child(row2)
	
	affinity_bar = ProgressBar.new()
	affinity_bar.show_percentage = false
	affinity_bar.custom_minimum_size = Vector2(0, 10)
	affinity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	affinity_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(affinity_bar)
	
	affinity_val_lbl = Label.new()
	affinity_val_lbl.text = "0/100"
	affinity_val_lbl.custom_minimum_size = Vector2(50, 0)
	affinity_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	affinity_val_lbl.add_theme_font_size_override("font_size", 10)
	affinity_val_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	row2.add_child(affinity_val_lbl)
	
	# 3. Discovered Likes Panel
	var likes_hbox = HBoxContainer.new()
	likes_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(likes_hbox)
	
	var likes_title = Label.new()
	likes_title.text = "Known Likes:"
	likes_title.add_theme_font_size_override("font_size", 10)
	likes_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	likes_hbox.add_child(likes_title)
	
	likes_container = HBoxContainer.new()
	likes_container.add_theme_constant_override("separation", 4)
	likes_hbox.add_child(likes_container)
	
	# 4. Dialog Output Card
	var dialog_card = PanelContainer.new()
	var style_dlg = StyleBoxFlat.new()
	style_dlg.bg_color = Color(0.04, 0.06, 0.12, 0.8)
	style_dlg.corner_radius_top_left = 6
	style_dlg.corner_radius_top_right = 6
	style_dlg.corner_radius_bottom_left = 6
	style_dlg.corner_radius_bottom_right = 6
	style_dlg.border_width_left = 1
	style_dlg.border_width_top = 1
	style_dlg.border_width_right = 1
	style_dlg.border_width_bottom = 1
	style_dlg.border_color = Color(0.15, 0.25, 0.45, 0.5)
	dialog_card.add_theme_stylebox_override("panel", style_dlg)
	main_vbox.add_child(dialog_card)
	
	var dlg_margin = MarginContainer.new()
	dlg_margin.add_theme_constant_override("margin_left", 10)
	dlg_margin.add_theme_constant_override("margin_right", 10)
	dlg_margin.add_theme_constant_override("margin_top", 5)
	dlg_margin.add_theme_constant_override("margin_bottom", 5)
	dialog_card.add_child(dlg_margin)
	
	dialog_lbl = Label.new()
	dialog_lbl.text = "Select an option below to interact."
	dialog_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_lbl.custom_minimum_size = Vector2(0, 36)
	dialog_lbl.add_theme_font_size_override("font_size", 12)
	dialog_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	dlg_margin.add_child(dialog_lbl)
	
	# 5. Options Container (Main list)
	var options_vbox = VBoxContainer.new()
	options_vbox.name = "ActionsContainer"
	options_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(options_vbox)
	
	btn_chat = Button.new()
	btn_chat.text = "Chat"
	btn_chat.focus_mode = Control.FOCUS_ALL
	btn_chat.pressed.connect(_on_chat_pressed)
	options_vbox.add_child(btn_chat)
	
	btn_flirt = Button.new()
	btn_flirt.text = "Flirt"
	btn_flirt.focus_mode = Control.FOCUS_ALL
	btn_flirt.pressed.connect(_on_flirt_pressed)
	options_vbox.add_child(btn_flirt)
	
	btn_gift = Button.new()
	btn_gift.text = "Gift Item"
	btn_gift.focus_mode = Control.FOCUS_ALL
	btn_gift.pressed.connect(_on_gift_pressed)
	options_vbox.add_child(btn_gift)
	
	btn_quest = Button.new()
	btn_quest.text = "Relationship Quest"
	btn_quest.focus_mode = Control.FOCUS_ALL
	btn_quest.pressed.connect(_on_quest_pressed)
	options_vbox.add_child(btn_quest)
	
	btn_marry = Button.new()
	btn_marry.text = "Propose Marriage (Requires Ring)"
	btn_marry.focus_mode = Control.FOCUS_ALL
	btn_marry.pressed.connect(_on_marry_pressed)
	options_vbox.add_child(btn_marry)
	
	btn_close = Button.new()
	btn_close.text = "Leave Interaction"
	btn_close.focus_mode = Control.FOCUS_ALL
	btn_close.pressed.connect(_on_close_pressed)
	options_vbox.add_child(btn_close)
	
	# 6. Gifting Scroll View (Hidden initially)
	gift_scroll = ScrollContainer.new()
	gift_scroll.name = "GiftScroll"
	gift_scroll.custom_minimum_size = Vector2(0, 120)
	gift_scroll.visible = false
	main_vbox.add_child(gift_scroll)
	
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 4)
	gift_scroll.add_child(scroll_vbox)
	
	var gift_title = Label.new()
	gift_title.text = "Choose an item to offer:"
	gift_title.add_theme_font_size_override("font_size", 11)
	gift_title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	scroll_vbox.add_child(gift_title)
	
	gift_vbox = VBoxContainer.new()
	gift_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_child(gift_vbox)
	
	btn_cancel_gift = Button.new()
	btn_cancel_gift.text = "Cancel Gifting"
	btn_cancel_gift.focus_mode = Control.FOCUS_ALL
	btn_cancel_gift.pressed.connect(_on_cancel_gifting_pressed)
	scroll_vbox.add_child(btn_cancel_gift)
	
	# Yes/No Quest Offer Confirmation HBox (Hidden initially)
	quest_choice_hbox = HBoxContainer.new()
	quest_choice_hbox.name = "QuestChoiceContainer"
	quest_choice_hbox.add_theme_constant_override("separation", 10)
	quest_choice_hbox.visible = false
	main_vbox.add_child(quest_choice_hbox)
	
	btn_accept_quest = Button.new()
	btn_accept_quest.text = "Yes"
	btn_accept_quest.focus_mode = Control.FOCUS_ALL
	btn_accept_quest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_accept_quest.pressed.connect(_on_accept_quest_pressed)
	quest_choice_hbox.add_child(btn_accept_quest)
	
	btn_decline_quest = Button.new()
	btn_decline_quest.text = "No"
	btn_decline_quest.focus_mode = Control.FOCUS_ALL
	btn_decline_quest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_decline_quest.pressed.connect(_on_decline_quest_pressed)
	quest_choice_hbox.add_child(btn_decline_quest)
	
	# Setup animations for hover
	for btn in [btn_chat, btn_flirt, btn_gift, btn_quest, btn_marry, btn_close, btn_cancel_gift, btn_accept_quest, btn_decline_quest]:
		if btn:
			btn.mouse_entered.connect(func():
				var tween = create_tween()
				tween.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.06)
			)
			btn.mouse_exited.connect(func():
				var tween = create_tween()
				tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.06)
			)

func setup(npc: Node2D) -> void:
	target_npc = npc
	rel_component = npc.get_node("RelationshipComponent")
	
	# Turn NPC to player
	if target_npc and target_npc.has_method("look_at_player"):
		target_npc.call("look_at_player")
		
	# Setup text
	npc_name_lbl.text = npc.npc_name
	var career_name = npc.career.capitalize() if npc.career != "" else "Notable Citizen"
	npc_role_lbl.text = "%s (Level %d)" % [career_name, rel_component.profession_level]
	
	# Set spouse text if married
	if GameState.is_married and GameState.spouse_npc_id == target_npc.quest_npc_id:
		npc_role_lbl.text = "%s (Spouse)" % career_name
		btn_marry.visible = false
		
	if rel_component.has_method("get_custom_message"):
		dialog_lbl.text = rel_component.get_custom_message("greeting", "")
	else:
		dialog_lbl.text = "Greetings! It is good to see you today, %s. What is on your mind?" % GameState.player_name
	
	# Pause player movement
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		players[0].call("freeze")
		
	refresh()
	btn_chat.grab_focus()

func refresh() -> void:
	if not rel_component:
		return
		
	var val = rel_component.relationship_value
	var max_val = 100.0
	var stage = rel_component.get_relationship_stage()
	stage_lbl.text = "Stage: " + stage
	
	# Update colors based on stages
	match stage:
		"Spouse":
			stage_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.8)) # Pink
		"Dating":
			stage_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.9)) # Purple
		"Friend":
			stage_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9)) # Cyan
		"Neutral":
			stage_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5)) # Green
		_:
			stage_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8)) # Gray
			
	affinity_bar.max_value = max_val
	affinity_bar.value = val
	affinity_val_lbl.text = "%d / %d" % [int(val), int(max_val)]
	
	daily_lbl.text = "Daily Actions: %d/3" % rel_component.daily_interaction_slots
	if rel_component.daily_interaction_slots <= 0:
		daily_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		daily_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		
	# Setup likes list
	for child in likes_container.get_children():
		child.queue_free()
		
	if rel_component.discovered_likes.is_empty():
		var lbl = Label.new()
		lbl.text = "None discovered yet"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		likes_container.add_child(lbl)
	else:
		for like in rel_component.discovered_likes:
			var panel = PanelContainer.new()
			var p_style = StyleBoxFlat.new()
			p_style.bg_color = Color(0.1, 0.25, 0.4, 0.8)
			p_style.content_margin_left = 6
			p_style.content_margin_right = 6
			p_style.content_margin_top = 2
			p_style.content_margin_bottom = 2
			p_style.corner_radius_top_left = 4
			p_style.corner_radius_top_right = 4
			p_style.corner_radius_bottom_left = 4
			p_style.corner_radius_bottom_right = 4
			panel.add_theme_stylebox_override("panel", p_style)
			
			var lbl = Label.new()
			lbl.text = like.replace("_", " ").capitalize()
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
			panel.add_child(lbl)
			likes_container.add_child(panel)

	# Marriage button visibility
	if GameState.is_married:
		btn_marry.visible = false
	else:
		btn_marry.visible = (rel_component.relationship_value >= 80.0)

func _on_chat_pressed() -> void:
	if rel_component.daily_interaction_slots <= 0:
		dialog_lbl.text = "I'm a bit busy now, let's chat again tomorrow!"
		return
		
	var result = rel_component.chat()
	dialog_lbl.text = result["message"]
	
	var points = result.get("points", 0)
	if points > 0:
		GameState.spawn_ui_floating_text("+%d Affinity!" % points)
	elif points < 0:
		GameState.spawn_ui_floating_text("%d Affinity!" % points)
	refresh()

func _on_flirt_pressed() -> void:
	if rel_component.daily_interaction_slots <= 0:
		dialog_lbl.text = "I think we've socialized enough for today!"
		return
		
	var result = rel_component.flirt()
	dialog_lbl.text = result["message"]
	
	var points = result.get("points", 0)
	if points > 0:
		GameState.spawn_ui_floating_text("+%d Affinity!" % points)
	elif points < 0:
		GameState.spawn_ui_floating_text("%d Affinity!" % points)
	refresh()

func _on_gift_pressed() -> void:
	if rel_component.daily_interaction_slots <= 0:
		dialog_lbl.text = "I cannot accept any more gifts today!"
		return
		
	# Show gifting ScrollView, hide main options
	main_vbox.get_node("ActionsContainer").visible = false
	gift_scroll.visible = true
	
	# Rebuild gift items
	for child in gift_vbox.get_children():
		child.queue_free()
		
	var items_in_inv = []
	if GameState.player_inventory:
		for slot in GameState.player_inventory.slots:
			if slot.get("item"):
				items_in_inv.append(slot["item"])
				
	var first_btn = null
	for item in items_in_inv:
		var btn = Button.new()
		btn.text = "%s (x1)" % item.name
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(func():
			_gift_item(item)
		)
		
		btn.mouse_entered.connect(func():
			var tween = create_tween()
			tween.tween_property(btn, "scale", Vector2(1.01, 1.01), 0.06)
		)
		btn.mouse_exited.connect(func():
			var tween = create_tween()
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.06)
		)
		
		gift_vbox.add_child(btn)
		if not first_btn:
			first_btn = btn
			
	if items_in_inv.is_empty():
		var lbl = Label.new()
		lbl.text = "No items in inventory to gift."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		gift_vbox.add_child(lbl)
		btn_cancel_gift.grab_focus()
	elif first_btn:
		first_btn.grab_focus()

func _gift_item(item: Resource) -> void:
	# Hide gifting
	gift_scroll.visible = false
	main_vbox.get_node("ActionsContainer").visible = true
	btn_gift.grab_focus()
	
	# Consume item
	GameState.player_inventory.remove_item(item.id, 1)
	
	var result = rel_component.gift(item)
	dialog_lbl.text = result["message"]
	
	var points = result.get("points", 0)
	if points > 0:
		GameState.spawn_ui_floating_text("+%d Affinity!" % points)
	elif points < 0:
		GameState.spawn_ui_floating_text("%d Affinity!" % points)
		
	refresh()

func _on_cancel_gifting_pressed() -> void:
	gift_scroll.visible = false
	main_vbox.get_node("ActionsContainer").visible = true
	btn_gift.grab_focus()

func _on_quest_pressed() -> void:
	# Check for active accepted relationship quests
	var active_q = null
	for q in QuestManager.accepted_quests:
		if q.get("target_npc_id") == target_npc.quest_npc_id:
			active_q = q
			break
			
	if active_q:
		if active_q.type == "Supply":
			var has_items = GameState.player_inventory.get_item_amount(active_q.item_id) >= active_q.item_amount
			if has_items:
				# Hand in items
				GameState.player_inventory.remove_item(active_q.item_id, active_q.item_amount)
				QuestManager.complete_quest(active_q)
				dialog_lbl.text = "Incredible! You brought the %d %s! Here is your reward of %d Gold. Thank you so much!" % [active_q.item_amount, active_q.item_name, active_q.reward_gold]
				refresh()
			else:
				var current = GameState.player_inventory.get_item_amount(active_q.item_id)
				dialog_lbl.text = "I still need %d %s (You have %d/%d). Please let me know once you have them!" % [active_q.item_amount, active_q.item_name, current, active_q.item_amount]
		else:
			dialog_lbl.text = "Please deliver the %s to the %s! They are waiting for it." % [active_q.item_name, active_q.delivery_target_name]
	else:
		# Offer a quest if eligible
		var relation = rel_component.relationship_value
		var is_friend = relation >= 20.0
		
		var can_accept = false
		var quest_to_offer = null
		
		match target_npc.quest_npc_id:
			"elena":
				quest_to_offer = {
					"id": "quest_elena",
					"title": "Elena's Threads",
					"description": "Elena needs 3 Spools of Thread to complete a premium outfit.",
					"type": "Supply",
					"difficulty": "Easy",
					"item_id": "spool_thread",
					"item_name": "Spool of Thread",
					"item_amount": 3,
					"target_npc_id": "elena",
					"reward_gold": 120,
					"due_days": 3,
					"region": "Oakhaven Province"
				}
				can_accept = true
			"valeria":
				quest_to_offer = {
					"id": "quest_valeria",
					"title": "Valeria's Courier",
					"description": "Slip the Confidential Documents into the Rival Mailbox.",
					"type": "Delivery",
					"difficulty": "Medium",
					"item_id": "confidential_documents",
					"item_name": "Confidential Documents",
					"item_amount": 1,
					"target_npc_id": "valeria",
					"delivery_target_id": "rival_mailbox",
					"delivery_target_name": "Rival Mailbox",
					"reward_gold": 180,
					"due_days": 3,
					"region": "Valley Province"
				}
				can_accept = true
			"aldous":
				if is_friend:
					quest_to_offer = {
						"id": "quest_aldous",
						"title": "Aldous's Archive",
						"description": "Deliver the Ancient Manuscript to the Church Archive.",
						"type": "Delivery",
						"difficulty": "Medium",
						"item_id": "ancient_manuscript",
						"item_name": "Ancient Manuscript",
						"item_amount": 1,
						"target_npc_id": "aldous",
						"delivery_target_id": "church_archive",
						"delivery_target_name": "Church Archive",
						"reward_gold": 200,
						"due_days": 3,
						"region": "Valley Province"
					}
					can_accept = true
			"gideon":
				if is_friend:
					quest_to_offer = {
						"id": "quest_gideon",
						"title": "Gideon's Timber",
						"description": "Gideon needs 5 Standard Timber for a workshop project.",
						"type": "Supply",
						"difficulty": "Easy",
						"item_id": "standard_timber",
						"item_name": "Standard Timber",
						"item_amount": 5,
						"target_npc_id": "gideon",
						"reward_gold": 150,
						"due_days": 3,
						"region": "Valley Province"
					}
					can_accept = true
					
		if can_accept and quest_to_offer:
			# Verify if already completed
			if GameState.completed_relation_quests and GameState.completed_relation_quests.has(quest_to_offer.id):
				dialog_lbl.text = "Thank you again for helping me with that request! I don't have any other tasks right now."
				return
				
			_offered_quest = quest_to_offer
			
			var time_txt = "No limit"
			if quest_to_offer.get("due_days", 0) > 0:
				time_txt = "%d days" % quest_to_offer["due_days"]
			dialog_lbl.text = "I need help with '%s'.\n%s\nReward: %d G | Time Limit: %s\n\nWill you accept this quest?" % [quest_to_offer.title, quest_to_offer.description, quest_to_offer.reward_gold, time_txt]
			
			main_vbox.get_node("ActionsContainer").visible = false
			quest_choice_hbox.visible = true
			btn_accept_quest.grab_focus()
		else:
			if not is_friend:
				dialog_lbl.text = "I don't have any requests for you right now. Perhaps if we become closer friends (+20 Affinity), I will have some tasks!"
			else:
				dialog_lbl.text = "I don't have any tasks for you right now, but thank you for asking!"

func _on_accept_quest_pressed() -> void:
	if not _offered_quest.is_empty():
		QuestManager.accept_relationship_quest(_offered_quest)
		
		if _offered_quest.type == "Delivery":
			GameState.player_inventory.add_item(_offered_quest.item_id, 1)
			GameState.spawn_ui_floating_text("Received: %s" % _offered_quest.item_name)
			
		dialog_lbl.text = "Thank you! I knew I could rely on you. I appreciate your assistance!"
		
	_offered_quest = {}
	quest_choice_hbox.visible = false
	main_vbox.get_node("ActionsContainer").visible = true
	btn_quest.grab_focus()
	refresh()

func _on_decline_quest_pressed() -> void:
	dialog_lbl.text = "I see. Let me know if you change your mind, the offer is still open."
	_offered_quest = {}
	quest_choice_hbox.visible = false
	main_vbox.get_node("ActionsContainer").visible = true
	btn_quest.grab_focus()
	refresh()

func _on_marry_pressed() -> void:
	if GameState.is_married:
		dialog_lbl.text = "I am already married!"
		return
		
	# Check if player has a Gold Ring
	var has_ring = GameState.player_inventory.has_item("gold_ring", 1)
	if not has_ring:
		dialog_lbl.text = "A marriage proposal? That is very sudden... and you don't even have a Gold Ring to propose with!"
		return
		
	var val = rel_component.relationship_value
	if val >= 80.0:
		# Consume ring
		GameState.player_inventory.remove_item("gold_ring", 1)
		
		# Set marriage state
		GameState.is_married = true
		GameState.spouse_npc_id = target_npc.quest_npc_id
		rel_component.relationship_value = 100.0 # Max out!
		
		# Apply dynastic marriage speed buff (+15% movement speed)
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			player.speed_multiplier *= 1.15
			
		dialog_lbl.text = "Oh, heavens! Yes! Yes, a thousand times yes! I would be honored to marry you and combine our futures!"
		GameState.spawn_ui_floating_text("Married to %s! Dynastic Speed Buff Unlocked (+15% speed)" % target_npc.npc_name)
		refresh()
	else:
		dialog_lbl.text = "We are close associates, but I am not ready for such a lifetime commitment yet. Let's build our bond more first!"

func _on_close_pressed() -> void:
	# Unpause player
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		players[0].call("unfreeze")
		
	if target_npc and "is_talking" in target_npc:
		target_npc.is_talking = false
		
	queue_free()

extends PanelContainer

@onready var title_label: Label = $VBox/Header/Title
@onready var quest_list: VBoxContainer = %QuestList
@onready var detail_title: Label = %DetailTitle
@onready var difficulty_badge: Label = %DifficultyBadge
@onready var detail_desc: Label = %DetailDesc
@onready var objective_label: Label = %ObjectiveLabel
@onready var reward_label: Label = %RewardLabel
@onready var time_label: Label = %TimeLabel
@onready var action_button: Button = %ActionButton
@onready var close_button: Button = $VBox/CloseButton
@onready var tab_available: Button = %TabAvailable
@onready var tab_accepted: Button = %TabAccepted

var current_region: String = "Valley Province"
var selected_quest: Dictionary = {}
var show_accepted_tab: bool = false

var confirm_hbox: HBoxContainer
var btn_confirm_yes: Button
var btn_confirm_no: Button

func _ready() -> void:
	tab_available.pressed.connect(_on_tab_available_pressed)
	tab_accepted.pressed.connect(_on_tab_accepted_pressed)
	action_button.pressed.connect(_on_action_button_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	if QuestManager.has_signal("quests_updated"):
		QuestManager.quests_updated.connect(refresh)
		
	# Programmatically build Confirmation HBox
	confirm_hbox = HBoxContainer.new()
	confirm_hbox.name = "ConfirmChoiceContainer"
	confirm_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_hbox.add_theme_constant_override("separation", 10)
	confirm_hbox.visible = false
	action_button.get_parent().add_child(confirm_hbox)
	
	var confirm_lbl = Label.new()
	confirm_lbl.text = "Accept quest?"
	confirm_lbl.add_theme_font_size_override("font_size", 11)
	confirm_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	confirm_hbox.add_child(confirm_lbl)
	
	btn_confirm_yes = Button.new()
	btn_confirm_yes.text = "Yes"
	btn_confirm_yes.custom_minimum_size = Vector2(60, 28)
	btn_confirm_yes.focus_mode = Control.FOCUS_ALL
	btn_confirm_yes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_confirm_yes.pressed.connect(_on_confirm_yes_pressed)
	confirm_hbox.add_child(btn_confirm_yes)
	
	btn_confirm_no = Button.new()
	btn_confirm_no.text = "No"
	btn_confirm_no.custom_minimum_size = Vector2(60, 28)
	btn_confirm_no.focus_mode = Control.FOCUS_ALL
	btn_confirm_no.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_confirm_no.pressed.connect(_on_confirm_no_pressed)
	confirm_hbox.add_child(btn_confirm_no)
	
	# Hover/Focus micro-animations for Yes/No buttons
	for btn in [btn_confirm_yes, btn_confirm_no]:
		btn.mouse_entered.connect(func():
			var tween = create_tween()
			tween.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.06)
		)
		btn.mouse_exited.connect(func():
			var tween = create_tween()
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.06)
		)

func open(region: String) -> void:
	current_region = region
	show_accepted_tab = false
	show()
	
	get_tree().paused = false
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.freeze()
		
	refresh()

func _on_close_pressed() -> void:
	hide()
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.unfreeze()

func _on_tab_available_pressed() -> void:
	show_accepted_tab = false
	refresh()

func _on_tab_accepted_pressed() -> void:
	show_accepted_tab = true
	refresh()

func refresh() -> void:
	if not visible:
		return
		
	title_label.text = "Quest Board - " + current_region
	
	if show_accepted_tab:
		tab_accepted.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		tab_available.remove_theme_color_override("font_color")
	else:
		tab_available.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		tab_accepted.remove_theme_color_override("font_color")
		
	for child in quest_list.get_children():
		child.queue_free()
		
	var quests = []
	if show_accepted_tab:
		for q in QuestManager.accepted_quests:
			if q.region == current_region:
				quests.append(q)
	else:
		quests = QuestManager.active_quests.get(current_region, [])
		
	var first_btn = null
	for q in quests:
		var btn = Button.new()
		btn.text = q.title
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.focus_mode = Control.FOCUS_ALL
		
		btn.pressed.connect(func():
			_select_quest(q)
		)
		
		btn.mouse_entered.connect(func():
			var tween = create_tween()
			tween.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.08)
		)
		btn.mouse_exited.connect(func():
			var tween = create_tween()
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
		)
		
		quest_list.add_child(btn)
		if not first_btn:
			first_btn = btn
			
	if quests.is_empty():
		_clear_details()
		var empty_lbl = Label.new()
		empty_lbl.text = "No quests available."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		quest_list.add_child(empty_lbl)
	else:
		var still_valid = false
		for q in quests:
			if q.id == selected_quest.get("id"):
				_select_quest(q)
				still_valid = true
				break
		if not still_valid:
			_select_quest(quests[0])
			
	if first_btn:
		first_btn.grab_focus()

func _select_quest(quest: Dictionary) -> void:
	selected_quest = quest
	detail_title.text = quest.title
	
	difficulty_badge.text = "[" + quest.difficulty.to_upper() + "]"
	if quest.difficulty == "Easy":
		difficulty_badge.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
	elif quest.difficulty == "Medium":
		difficulty_badge.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	elif quest.difficulty == "Hard":
		difficulty_badge.add_theme_color_override("font_color", Color(0.9, 0.4, 0.2))
	elif quest.difficulty == "Expert":
		difficulty_badge.add_theme_color_override("font_color", Color(0.8, 0.3, 0.9))
	else:
		difficulty_badge.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

		
	detail_desc.text = quest.description
	
	var current = GameState.player_inventory.get_item_amount(quest.item_id)
	objective_label.text = "Objective: Deliver " + str(quest.item_amount) + " " + quest.item_name + "\n(Current: " + str(current) + "/" + str(quest.item_amount) + ")"
	
	reward_label.text = "Reward: " + str(quest.reward_gold) + " Gold"
	
	if confirm_hbox:
		confirm_hbox.visible = false
	
	if show_accepted_tab:
		var remaining_days = quest.due_day - TimeManager.time_days
		time_label.text = "Due in: " + str(remaining_days) + " Days (By Day " + str(quest.due_day) + ")"
		action_button.text = "Accepted"
		action_button.disabled = true
		action_button.visible = true
	else:
		time_label.text = "Due Limit: " + str(quest.due_days) + " Days"
		action_button.text = "Accept Quest"
		action_button.disabled = false
		action_button.visible = true

func _clear_details() -> void:
	selected_quest = {}
	detail_title.text = ""
	difficulty_badge.text = ""
	detail_desc.text = "Select a quest from the list to view its details."
	objective_label.text = ""
	reward_label.text = ""
	time_label.text = ""
	action_button.text = "Accept"
	action_button.disabled = true
	action_button.visible = true
	if confirm_hbox:
		confirm_hbox.visible = false

func _on_action_button_pressed() -> void:
	if not selected_quest.is_empty() and not show_accepted_tab:
		action_button.visible = false
		confirm_hbox.visible = true
		btn_confirm_yes.grab_focus()

func _on_confirm_yes_pressed() -> void:
	if not selected_quest.is_empty() and not show_accepted_tab:
		if QuestManager.accept_quest(selected_quest.id, current_region):
			confirm_hbox.visible = false
			action_button.visible = true
			_clear_details()
			refresh()

func _on_confirm_no_pressed() -> void:
	confirm_hbox.visible = false
	action_button.visible = true
	action_button.grab_focus()

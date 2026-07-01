extends PanelContainer

@onready var npc_name_label: Label = $VBox/NPCName
@onready var content_label: Label = $VBox/Content
@onready var page_indicator: Label = $VBox/HBox/PageIndicator
@onready var next_button: Button = $VBox/HBox/NextButton
@onready var close_button: Button = $VBox/HBox/CloseButton

var target_npc: Node2D
var messages: Array[String] = []
var current_page: int = 0
var completion_callback: Callable

func _ready() -> void:
	add_to_group("DialogueBubble")
	
	# Enforce correct non-stretching anchors and initial compact size
	anchors_preset = Control.PRESET_TOP_LEFT
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 280.0
	offset_bottom = 80.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	
	custom_minimum_size = Vector2(280, 80)
	size = Vector2(280, 80)
	
	if content_label:
		content_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		
	resized.connect(queue_redraw)
	next_button.pressed.connect(_on_next_pressed)
	close_button.pressed.connect(_on_close_pressed)

func start_dialogue(npc: Node2D, npc_name: String, msg_list: Array, on_complete: Callable = Callable()) -> void:
	target_npc = npc
	messages.clear()
	for m in msg_list:
		messages.append(str(m))
	completion_callback = on_complete
	current_page = 0
	
	if npc_name_label:
		npc_name_label.text = npc_name
	
	# Pause target NPC movement
	if target_npc and "is_talking" in target_npc:
		target_npc.is_talking = true
		
	# Turn NPC to face the player
	var player = get_tree().get_first_node_in_group("Player")
	if player and target_npc and "last_direction" in target_npc:
		var diff = player.global_position - target_npc.global_position
		if diff.length() > 5.0:
			var dir = "south"
			if abs(diff.x) > abs(diff.y):
				dir = "east" if diff.x > 0 else "west"
			else:
				dir = "south" if diff.y > 0 else "north"
			target_npc.last_direction = dir
			if target_npc.has_method("update_animation"):
				target_npc.update_animation(Vector2.ZERO)
		
	# Freeze player
	if player and player.has_method("freeze"):
		player.freeze()
	
	_show_page(0)
	
	# Update position immediately before showing
	_update_position()
	show()

func _show_page(page: int) -> void:
	current_page = page
	
	var raw_text = messages[page]
	if is_instance_valid(target_npc):
		var token_map = {
			"npc_name": target_npc.npc_name if "npc_name" in target_npc else target_npc.name,
			"npc_rank": target_npc.npc_rank if "npc_rank" in target_npc else "",
			"city_name": target_npc.hometown if "hometown" in target_npc else ""
		}
		raw_text = raw_text.format(token_map)
		
	content_label.text = raw_text
	
	var total_pages = messages.size()
	if total_pages > 1:
		page_indicator.show()
		page_indicator.text = "%d/%d" % [page + 1, total_pages]
	else:
		page_indicator.hide()
		
	if page < total_pages - 1:
		next_button.show()
		close_button.hide()
		next_button.grab_focus()
	else:
		next_button.hide()
		close_button.show()
		close_button.grab_focus()

func _on_next_pressed() -> void:
	if current_page < messages.size() - 1:
		_show_page(current_page + 1)

func _on_close_pressed() -> void:
	# Resume NPC movement
	if target_npc and "is_talking" in target_npc:
		target_npc.is_talking = false
	
	# Unfreeze player
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()
		
	# Trigger callback
	if completion_callback.is_valid():
		completion_callback.call()
		
	queue_free()

func _process(_delta: float) -> void:
	_update_position()

func _update_position() -> void:
	if not is_instance_valid(target_npc):
		# If the NPC became invalid (unloaded/freed), close dialogue
		var player = get_tree().get_first_node_in_group("Player")
		if player and player.has_method("unfreeze"):
			player.unfreeze()
		queue_free()
		return
		
	# Project NPC head position (using Vector2(0, -90) relative to NPC origin) to screen space
	var target_point = target_npc.get_global_transform_with_canvas() * Vector2(0, -90)
	
	# Centered horizontally, placed slightly above the target point
	var target_pos = target_point + Vector2(-size.x / 2.0, -size.y - 12)
	
	# Clamp to screen/viewport bounds with margins to prevent going off screen
	var viewport_rect = get_viewport_rect()
	var margin = 12.0
	target_pos.x = clamp(target_pos.x, margin, viewport_rect.size.x - size.x - margin)
	target_pos.y = clamp(target_pos.y, margin, viewport_rect.size.y - size.y - margin)
	
	global_position = target_pos
	
	# Force redraw so the dynamic tail adjusts to point to the character head
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(target_npc):
		return
		
	# Determine NPC head screen location relative to the bubble panel
	var target_point = target_npc.get_global_transform_with_canvas() * Vector2(0, -90)
	var local_target_x = target_point.x - global_position.x
	
	# Keep the tail within the rounded panel corners (15px margin from either side)
	var tail_x = clamp(local_target_x, 15.0, size.x - 15.0)
	var tail_base_y = size.y
	var tail_tip_y = size.y + 10.0
	
	var points = PackedVector2Array([
		Vector2(tail_x - 10, tail_base_y),
		Vector2(tail_x + 10, tail_base_y),
		Vector2(tail_x, tail_tip_y)
	])
	
	# Match colors with Panel's StyleBoxFlat border & background
	var bg_color = Color(0.08, 0.12, 0.18, 0.92)
	var border_color = Color(0.24, 0.6, 0.86, 0.75)
	
	# Draw background triangle
	draw_colored_polygon(points, bg_color)
	
	# Draw border lines on the sides of the triangle
	draw_line(points[0], points[2], border_color, 2.0)
	draw_line(points[2], points[1], border_color, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if has_node("VBox/ChoiceHBox"):
		return # Let the choice buttons handle input focus/events
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if next_button.visible:
			_on_next_pressed()
			get_viewport().set_input_as_handled()
		elif close_button.visible:
			_on_close_pressed()
			get_viewport().set_input_as_handled()

func show_choices(options: Array, callback: Callable) -> void:
	next_button.hide()
	close_button.hide()
	page_indicator.hide()
	
	var choice_hbox = HBoxContainer.new()
	choice_hbox.name = "ChoiceHBox"
	choice_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_hbox.add_theme_constant_override("separation", 12)
	$VBox.add_child(choice_hbox)
	
	for i in range(options.size()):
		var btn = Button.new()
		btn.text = options[i]
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", 10)
		btn.custom_minimum_size = Vector2(80, 24)
		
		# Setup hover zoom effects
		btn.pivot_offset = Vector2(40, 12)
		btn.mouse_entered.connect(func():
			create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
		)
		btn.mouse_exited.connect(func():
			create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
		)
		
		btn.pressed.connect(func():
			var selected_index = i
			choice_hbox.queue_free()
			callback.call(selected_index)
			# Do NOT call _on_close_pressed directly so the callback can decide if it closes or runs more dialogue
		)
		choice_hbox.add_child(btn)
		
	# Wire neighbor focus
	for i in range(choice_hbox.get_child_count()):
		var btn = choice_hbox.get_child(i) as Button
		if i > 0:
			btn.focus_neighbor_left = choice_hbox.get_child(i - 1).get_path()
		if i < choice_hbox.get_child_count() - 1:
			btn.focus_neighbor_right = choice_hbox.get_child(i + 1).get_path()
			
	# Grab focus on first choice button
	choice_hbox.get_child(0).call_deferred("grab_focus")

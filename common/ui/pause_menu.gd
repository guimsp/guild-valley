extends PanelContainer

@onready var resume_btn: Button = %ResumeButton
@onready var save_btn: Button = %SaveButton
@onready var load_btn: Button = %LoadButton
@onready var quit_btn: Button = %QuitButton

signal closed()

func _ready() -> void:
	resume_btn.pressed.connect(_on_resume_pressed)
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# Scale animation on opening
	pivot_offset = size / 2.0
	scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var first_btn = _find_first_focusable_button(self)
	if first_btn:
		first_btn.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_F) or event.is_action_pressed("ui_accept"):
			var focused = get_viewport().gui_get_focus_owner()
			if focused and is_instance_valid(focused) and is_ancestor_of(focused):
				if focused is Button:
					focused.pressed.emit()
					get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

func _on_save_pressed() -> void:
	GameState.save_game()

func _on_load_pressed() -> void:
	GameState.load_game()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _find_first_focusable_button(node: Node) -> Button:
	if node is Button and node.focus_mode == Control.FOCUS_ALL and not node.disabled and node.visible:
		return node
	for child in node.get_children():
		var found = _find_first_focusable_button(child)
		if found:
			return found
	return null

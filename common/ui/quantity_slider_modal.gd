extends PanelContainer

signal confirmed(item: ItemData, mode: String, amount: int)
signal cancelled()

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var prompt_label: Label = $VBoxContainer/PromptLabel
@onready var slider: HSlider = $VBoxContainer/HSlider
@onready var amount_label: Label = $VBoxContainer/AmountLabel
@onready var confirm_button: Button = $VBoxContainer/Buttons/ConfirmButton
@onready var cancel_button: Button = $VBoxContainer/Buttons/CancelButton

var _item: ItemData = null
var _mode: String = ""

func _ready() -> void:
	slider.value_changed.connect(_on_slider_value_changed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_setup_button_hover(confirm_button)
	_setup_button_hover(cancel_button)
	
	# Instantiate "All (R)" button dynamically
	var all_btn = Button.new()
	all_btn.name = "AllButton"
	all_btn.text = "All (R)"
	all_btn.custom_minimum_size = Vector2(85, 28)
	all_btn.add_theme_font_size_override("font_size", 11)
	all_btn.focus_mode = Control.FOCUS_ALL
	_setup_button_hover(all_btn)
	
	var buttons_container = $VBoxContainer/Buttons
	buttons_container.add_child(all_btn)
	buttons_container.move_child(all_btn, 1) # Insert between Cancel and Confirm
	all_btn.pressed.connect(func():
		slider.value = slider.max_value
		_on_confirm_pressed()
	)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_R:
			slider.value = slider.max_value
			_on_confirm_pressed()
			get_viewport().set_input_as_handled()

func setup(item: ItemData, mode: String, max_limit: int, default_val: int = 1) -> void:
	_item = item
	_mode = mode
	
	var mode_title = mode.replace("_", " ").capitalize()
	title_label.text = "[%s] %s" % [mode_title, item.name]
	prompt_label.text = "Select quantity (Max: %d):" % max_limit
	
	slider.min_value = 1
	slider.max_value = max_limit
	slider.step = 1
	slider.value = clamp(default_val, 1, max_limit)
	_on_slider_value_changed(slider.value)
	
	show()
	confirm_button.grab_focus()

func _on_slider_value_changed(val: float) -> void:
	amount_label.text = "Amount: %d" % int(val)

func _on_confirm_pressed() -> void:
	confirmed.emit(_item, _mode, int(slider.value))
	hide()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()

func _setup_button_hover(button: Button) -> void:
	var update_pivot = func():
		button.pivot_offset = button.size / 2.0
	update_pivot.call()
	if not button.resized.is_connected(update_pivot):
		button.resized.connect(update_pivot)
		
	button.mouse_entered.connect(func():
		if not button.disabled:
			var tween = create_tween()
			tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.08)
	)
	button.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
	)

extends PanelContainer

signal price_changed(item: ItemData, new_price: int)
signal withdraw_pressed(item: ItemData)
signal row_clicked(item: ItemData, is_shift: bool)

@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var price_label: Label = $HBoxContainer/PriceLabel
@onready var minus_button: Button = $HBoxContainer/MinusButton
@onready var plus_button: Button = $HBoxContainer/PlusButton
@onready var withdraw_button: Button = $HBoxContainer/WithdrawButton

var _item: ItemData = null
var _style_normal: StyleBoxFlat = null
var _style_hover: StyleBoxFlat = null

func _ready() -> void:
	_style_normal = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_style_hover = _style_normal.duplicate() as StyleBoxFlat
	_style_hover.border_color = Color(0.24, 0.52, 0.85, 0.8)
	
	minus_button.pressed.connect(_on_minus_pressed)
	plus_button.pressed.connect(_on_plus_pressed)
	withdraw_button.pressed.connect(_on_withdraw_pressed)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func set_empty() -> void:
	_item = null
	name_label.text = "Vacant Stall Slot"
	name_label.modulate = Color(0.4, 0.4, 0.4)
	price_label.text = ""
	minus_button.hide()
	plus_button.hide()
	withdraw_button.hide()

func set_item(item: ItemData, amount: int, current_price: int) -> void:
	_item = item
	name_label.text = "%s (x%d)" % [item.name, amount]
	name_label.modulate = Color(1, 1, 1)
	price_label.text = "%d G" % current_price
	price_label.add_theme_color_override("font_color", Color(0.88, 0.73, 0.23, 1))
	
	minus_button.show()
	plus_button.show()
	withdraw_button.show()

func _on_minus_pressed() -> void:
	if not _item: return
	var min_p = _item.min_price if "min_price" in _item else 1
	var current_price = price_label.text.to_int()
	var new_price = max(min_p, current_price - 1)
	price_label.text = "%d G" % new_price
	price_changed.emit(_item, new_price)

func _on_plus_pressed() -> void:
	if not _item: return
	var max_p = _item.max_price if "max_price" in _item else 999
	var current_price = price_label.text.to_int()
	var new_price = min(max_p, current_price + 1)
	price_label.text = "%d G" % new_price
	price_changed.emit(_item, new_price)

func _on_withdraw_pressed() -> void:
	if _item:
		withdraw_pressed.emit(_item)

func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", _style_hover)

func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", _style_normal)

func _on_gui_input(event: InputEvent) -> void:
	if not _item: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			row_clicked.emit(_item, event.shift_pressed)
			get_viewport().set_input_as_handled()

extends PanelContainer

signal slot_pressed(item: ItemData, source_type: String, is_shift: bool)
signal slot_accepted(item: ItemData, source_type: String)

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var quantity_label: Label = $VBoxContainer/QuantityLabel

var _item: ItemData = null
var _source_type: String = ""
var _style_normal: StyleBoxFlat = null
var _style_hover: StyleBoxFlat = null

func _ready() -> void:
	_style_normal = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_style_hover = _style_normal.duplicate() as StyleBoxFlat
	_style_hover.border_color = Color(0.24, 0.52, 0.85, 0.9)
	
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func set_empty() -> void:
	_item = null
	name_label.text = "-"
	name_label.modulate = Color(0.3, 0.3, 0.3)
	quantity_label.text = ""
	focus_mode = Control.FOCUS_NONE

func set_item(item: ItemData, amount: int, source_type: String, is_produced_here: bool = false) -> void:
	_item = item
	_source_type = source_type
	
	name_label.text = item.name
	name_label.modulate = Color(1, 1, 1)
	quantity_label.text = "x%d" % amount
	quantity_label.modulate = Color(0.35, 0.75, 1.0)
	
	if source_type == "building" and is_produced_here:
		name_label.modulate = Color(0.3, 0.9, 0.4)
		
	focus_mode = Control.FOCUS_ALL

func _on_focus_entered() -> void:
	add_theme_stylebox_override("panel", _style_hover)

func _on_focus_exited() -> void:
	add_theme_stylebox_override("panel", _style_normal)

func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", _style_hover)

func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", _style_normal)

func _on_gui_input(event: InputEvent) -> void:
	if not _item:
		return
		
	if event.is_action_pressed("ui_accept"):
		slot_accepted.emit(_item, _source_type)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var is_shift = event.shift_pressed
		slot_pressed.emit(_item, _source_type, is_shift)
		get_viewport().set_input_as_handled()

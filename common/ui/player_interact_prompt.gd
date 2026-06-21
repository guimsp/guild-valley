extends PanelContainer

var _main_hud: CanvasLayer = null
@onready var interact_label: Label = %InteractLabel

func setup(p_hud: CanvasLayer) -> void:
	_main_hud = p_hud

func set_prompt_text(text: String) -> void:
	set_text(text)

func set_text(string_payload: String) -> void:
	if string_payload == "":
		hide()
	else:
		if interact_label:
			interact_label.text = string_payload
		show()
		pivot_offset = size / 2.0
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

extends PanelContainer

var _main_hud: CanvasLayer = null

@onready var broker_gold_label: Label = $VBox/ContentVBox/BrokerGoldLabel
@onready var broker_influence_label: Label = $VBox/ContentVBox/BrokerInfluenceLabel
@onready var exchange_button: Button = $VBox/ContentVBox/ExchangeButton

func setup(p_hud: CanvasLayer) -> void:
	_main_hud = p_hud
	if exchange_button:
		exchange_button.pressed.connect(_on_exchange_influence_pressed)
		if _main_hud.has_method("_setup_button_hover"):
			_main_hud._setup_button_hover(exchange_button)

func refresh() -> void:
	if not visible:
		return
	if broker_gold_label:
		broker_gold_label.text = "Current Gold: %d G" % GameState.gold
	if broker_influence_label:
		broker_influence_label.text = "Current Influence: %d / %d (Permanent)" % [GameState.influence, GameState.permanent_influence]
	if exchange_button:
		var can_afford = GameState.gold >= 100
		exchange_button.disabled = not can_afford
		exchange_button.text = "Buy 4 Influence (100 Gold)" if can_afford else "Lacking Gold"

func _on_exchange_influence_pressed() -> void:
	if GameState.gold >= 100:
		GameState.gold -= 100
		GameState.influence += 4
		GameState.spawn_ui_floating_text("+4 Influence!")
		if _main_hud and _main_hud.has_method("flash_element"):
			_main_hud.flash_element(self, Color(0.4, 1.0, 0.4))
		if _main_hud and _main_hud.has_method("update_hud_values"):
			_main_hud.update_hud_values()
		refresh()
	else:
		if _main_hud and _main_hud.has_method("shake_element"):
			_main_hud.shake_element(self)
		if _main_hud and _main_hud.has_method("flash_element"):
			_main_hud.flash_element(self, Color(1.0, 0.4, 0.4))
